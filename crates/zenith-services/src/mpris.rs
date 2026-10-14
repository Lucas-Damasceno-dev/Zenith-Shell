//! MPRIS2 Media Player controller and metadata query service.
//!
//! Communicates with active media players (`org.mpris.MediaPlayer2.*`) over the
//! user D-Bus session bus, exposing metadata (title, artist, album, status) and
//! transport controls (play-pause, next, previous).

use std::path::PathBuf;
use std::sync::{Arc, OnceLock, RwLock};
use std::time::{Duration, Instant};

/// Snapshot of the current active media player state.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, PartialEq, Eq)]
pub struct MediaSnapshot {
    pub is_available: bool,
    pub player_name: String,
    pub status: String, // "Playing", "Paused", "Stopped"
    pub title: String,
    pub artist: String,
    pub album: String,
    pub art_url: String,
    pub length_seconds: u64,
}

impl Default for MediaSnapshot {
    fn default() -> Self {
        Self {
            is_available: false,
            player_name: String::new(),
            status: "Stopped".to_string(),
            title: "No Media Playing".to_string(),
            artist: "".to_string(),
            album: "".to_string(),
            art_url: "".to_string(),
            length_seconds: 0,
        }
    }
}

struct CachedState {
    last_query: Instant,
    snapshot: MediaSnapshot,
    active_bus_name: Option<String>,
}

static CACHE: OnceLock<Arc<RwLock<CachedState>>> = OnceLock::new();
static IS_QUERYING: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

/// MPRIS2 Media Controller service.
pub struct MprisService;

impl MprisService {
    /// Retrieve current media player snapshot, cached non-blockingly.
    pub fn snapshot() -> MediaSnapshot {
        let cache_arc = CACHE.get_or_init(|| {
            Arc::new(RwLock::new(CachedState {
                last_query: Instant::now() - Duration::from_secs(10),
                snapshot: MediaSnapshot::default(),
                active_bus_name: None,
            }))
        });

        let (snap, need_refresh) = {
            let r = cache_arc.read().unwrap();
            let threshold = if r.snapshot.is_available {
                Duration::from_millis(1500)
            } else {
                Duration::from_millis(3500)
            };
            (r.snapshot.clone(), r.last_query.elapsed() >= threshold)
        };

        if need_refresh && !IS_QUERYING.swap(true, std::sync::atomic::Ordering::SeqCst) {
            let mut w = cache_arc.write().unwrap();
            w.last_query = Instant::now();
            let c_arc = cache_arc.clone();
            std::thread::spawn(move || {
                let (fresh_snap, bus_name) = Self::query_active_player();
                if let Ok(mut writer) = c_arc.write() {
                    writer.snapshot = fresh_snap;
                    writer.active_bus_name = bus_name;
                    writer.last_query = Instant::now();
                }
                IS_QUERYING.store(false, std::sync::atomic::Ordering::SeqCst);
            });
        }

        snap
    }

    /// Dispatch media transport control command ("play-pause", "next", "prev").
    pub fn control(cmd: &str) -> std::io::Result<()> {
        let bus_name = {
            let cache_arc = CACHE.get_or_init(|| {
                Arc::new(RwLock::new(CachedState {
                    last_query: Instant::now() - Duration::from_secs(10),
                    snapshot: MediaSnapshot::default(),
                    active_bus_name: None,
                }))
            });
            let r = cache_arc.read().unwrap();
            r.active_bus_name.clone()
        };

        let target_bus = match bus_name {
            Some(b) => b,
            None => {
                // Discover active player if not cached yet
                let players = Self::find_mpris_players();
                match players.into_iter().next() {
                    Some(p) => p,
                    None => return Ok(()),
                }
            }
        };

        let dbus_method = match cmd.to_lowercase().as_str() {
            "play-pause" | "playpause" | "toggle" => "PlayPause",
            "next" => "Next",
            "prev" | "previous" => "Previous",
            "stop" => "Stop",
            "play" => "Play",
            "pause" => "Pause",
            _ => return Ok(()),
        };

        if let Some(conn) = Self::get_session_connection() {
            let _ = conn.call_method(
                Some(target_bus.as_str()),
                "/org/mpris/MediaPlayer2",
                Some("org.mpris.MediaPlayer2.Player"),
                dbus_method,
                &(),
            );
        }

        // Invalidate cache so next read updates immediately
        if let Some(c) = CACHE.get() {
            let mut w = c.write().unwrap();
            w.last_query = Instant::now() - Duration::from_secs(5);
        }

        Ok(())
    }

    fn resolve_dbus_address_arg() -> Option<String> {
        if let Ok(addr) = std::env::var("DBUS_SESSION_BUS_ADDRESS") {
            if !addr.is_empty() && addr != "disabled" {
                return Some(format!("--address={}", addr));
            }
        }

        // Try standard XDG runtime dir user bus socket
        if let Ok(xdg) = std::env::var("XDG_RUNTIME_DIR") {
            let path = PathBuf::from(xdg).join("bus");
            if path.exists() {
                return Some(format!("--address=unix:path={}", path.display()));
            }
        }

        // Fallback to /run/user/<uid>/bus
        let uid = unsafe { libc::getuid() };
        let direct_sock = format!("/run/user/{}/bus", uid);
        if std::path::Path::new(&direct_sock).exists() {
            return Some(format!("--address=unix:path={}", direct_sock));
        }

        None
    }

    fn get_session_connection() -> Option<zbus::blocking::Connection> {
        if let Ok(conn) = zbus::blocking::Connection::session() {
            return Some(conn);
        }

        let addr = Self::resolve_dbus_address_arg()?;
        let path = addr.strip_prefix("--address=")?;
        zbus::blocking::connection::Builder::address(path)
            .ok()?
            .build()
            .ok()
    }

    fn find_mpris_players() -> Vec<String> {
        if let Some(conn) = Self::get_session_connection() {
            if let Ok(dbus_proxy) = zbus::blocking::fdo::DBusProxy::new(&conn) {
                if let Ok(names) = dbus_proxy.list_names() {
                    return names
                        .into_iter()
                        .filter(|n| n.starts_with("org.mpris.MediaPlayer2."))
                        .map(|n| n.to_string())
                        .collect();
                }
            }
        }
        Vec::new()
    }

    fn extract_metadata_from_map(
        map: &std::collections::HashMap<String, zbus::zvariant::OwnedValue>,
    ) -> (String, String, String, String, u64) {
        let mut artist = String::new();
        let mut length_secs = 0;

        let get_str = |key: &str| -> String {
            if let Some(v) = map.get(key) {
                if let zbus::zvariant::Value::Str(s) = &**v {
                    return s.as_str().to_string();
                }
            }
            String::new()
        };

        let title = get_str("xesam:title");
        let album = get_str("xesam:album");
        let art_url = get_str("mpris:artUrl");

        if let Some(v) = map.get("xesam:artist") {
            match &**v {
                zbus::zvariant::Value::Str(s) => {
                    artist = s.as_str().to_string();
                }
                zbus::zvariant::Value::Array(arr) => {
                    let mut parts = Vec::new();
                    for item in arr.iter() {
                        if let zbus::zvariant::Value::Str(s) = item {
                            parts.push(s.as_str().to_string());
                        }
                    }
                    artist = parts.join(", ");
                }
                _ => {}
            }
        }

        if let Some(v) = map.get("mpris:length") {
            match &**v {
                zbus::zvariant::Value::U64(micro) => {
                    length_secs = micro / 1_000_000;
                }
                zbus::zvariant::Value::I64(micro) => {
                    length_secs = (micro.max(&0) / 1_000_000) as u64;
                }
                _ => {}
            }
        }

        (title, artist, album, art_url, length_secs)
    }

    fn query_active_player() -> (MediaSnapshot, Option<String>) {
        let players = Self::find_mpris_players();
        if players.is_empty() {
            return (MediaSnapshot::default(), None);
        }

        let conn = match Self::get_session_connection() {
            Some(c) => c,
            None => return (MediaSnapshot::default(), None),
        };

        let mut first_match = None;
        for player_bus in players {
            let proxy = match zbus::blocking::Proxy::new(
                &conn,
                player_bus.clone(),
                "/org/mpris/MediaPlayer2",
                "org.mpris.MediaPlayer2.Player",
            ) {
                Ok(p) => p,
                Err(_) => continue,
            };

            let status = proxy.get_property::<String>("PlaybackStatus").unwrap_or_else(|_| "Stopped".to_string());
            let metadata: std::collections::HashMap<String, zbus::zvariant::OwnedValue> =
                proxy.get_property("Metadata").unwrap_or_default();

            let (title, artist, album, art_url, length) = Self::extract_metadata_from_map(&metadata);

            let short_name = player_bus
                .trim_start_matches("org.mpris.MediaPlayer2.")
                .split('.')
                .next()
                .unwrap_or("Media")
                .to_string();

            let snapshot = MediaSnapshot {
                is_available: true,
                player_name: short_name,
                status: status.clone(),
                title: if title.is_empty() { "Unknown Title".to_string() } else { title },
                artist,
                album,
                art_url,
                length_seconds: length,
            };

            if status == "Playing" {
                return (snapshot, Some(player_bus));
            }
            if first_match.is_none() {
                first_match = Some((snapshot, Some(player_bus)));
            }
        }

        if let Some(m) = first_match {
            return m;
        }

        (MediaSnapshot::default(), None)
    }

    #[allow(dead_code)]
    fn get_player_property(bus: &str, prop: &str) -> Option<String> {
        let conn = Self::get_session_connection()?;
        let proxy = zbus::blocking::Proxy::new(
            &conn,
            bus,
            "/org/mpris/MediaPlayer2",
            "org.mpris.MediaPlayer2.Player",
        ).ok()?;
        proxy.get_property::<String>(prop).ok()
    }

    pub fn parse_metadata(raw: &str) -> (String, String, String, String, u64) {
        let mut title = String::new();
        let mut artist = String::new();
        let mut album = String::new();
        let mut art_url = String::new();
        let mut length_secs = 0;

        // Parse key-value strings from busctl get-property Metadata format
        // Example: a{sv} 6 "mpris:artUrl" s "file://..." "xesam:title" s "Song" "xesam:artist" as 1 "Artist"
        if let Some(pos) = raw.find("\"xesam:title\"") {
            title = Self::extract_string_after(&raw[pos..]);
        }

        if let Some(pos) = raw.find("\"xesam:artist\"") {
            artist = Self::extract_string_after(&raw[pos..]);
        }

        if let Some(pos) = raw.find("\"xesam:album\"") {
            album = Self::extract_string_after(&raw[pos..]);
        }

        if let Some(pos) = raw.find("\"mpris:artUrl\"") {
            art_url = Self::extract_string_after(&raw[pos..]);
        }

        if let Some(pos) = raw.find("\"mpris:length\"") {
            let slice = &raw[pos..];
            for part in slice.split_whitespace().skip(2) {
                if let Ok(microsecs) = part.parse::<u64>() {
                    length_secs = microsecs / 1_000_000;
                    break;
                }
            }
        }

        (title, artist, album, art_url, length_secs)
    }

    fn extract_string_after(slice: &str) -> String {
        let mut in_quotes = false;
        let mut quote_count = 0;
        let mut result = String::new();

        for c in slice.chars() {
            if c == '\"' {
                quote_count += 1;
                if quote_count == 3 {
                    in_quotes = true;
                    continue;
                } else if quote_count == 4 {
                    break;
                }
            } else if in_quotes {
                result.push(c);
            }
        }

        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_metadata() {
        let raw = r#"a{sv} 6 "mpris:artUrl" s "file:///tmp/art.png" "mpris:length" x 240000000 "xesam:album" s "Discovery" "xesam:artist" as 1 "Daft Punk" "xesam:title" s "One More Time""#;
        let (title, artist, album, art_url, len) = MprisService::parse_metadata(raw);
        assert_eq!(title, "One More Time");
        assert_eq!(artist, "Daft Punk");
        assert_eq!(album, "Discovery");
        assert_eq!(art_url, "file:///tmp/art.png");
        assert_eq!(len, 240);
    }

    #[test]
    fn test_fallback_snapshot() {
        let snap = MediaSnapshot::default();
        assert!(!snap.is_available);
        assert_eq!(snap.status, "Stopped");
        assert_eq!(snap.title, "No Media Playing");
    }
}
