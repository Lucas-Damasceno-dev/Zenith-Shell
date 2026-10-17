//! MPRIS2 Media Player controller and metadata query service.
//!
//! Communicates with active media players (`org.mpris.MediaPlayer2.*`) over the
//! user D-Bus session bus, exposing metadata (title, artist, album, status) and
//! transport controls (play-pause, next, previous).

use std::sync::{Arc, OnceLock, RwLock};
use std::time::{Duration, Instant};
use crate::error::MprisError;

/// Contract for MPRIS media player controller.
pub trait MprisController: Send + Sync {
    /// Retrieve snapshot of active media player state.
    fn snapshot(&self) -> Result<MediaSnapshot, MprisError>;

    /// Send playback transport control command ("play-pause", "next", "prev", "stop", etc.).
    fn control(&self, cmd: &str) -> Result<(), MprisError>;
}

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
    /// Retrieve current media player snapshot, returning MprisError if lock poisoned.
    pub fn try_snapshot() -> Result<MediaSnapshot, MprisError> {
        let cache_arc = CACHE.get_or_init(|| {
            Arc::new(RwLock::new(CachedState {
                last_query: Instant::now() - Duration::from_secs(10),
                snapshot: MediaSnapshot::default(),
                active_bus_name: None,
            }))
        });

        let (snap, need_refresh) = {
            let r = cache_arc.read().map_err(|e| MprisError::LockPoisoned(e.to_string()))?;
            let threshold = if r.snapshot.is_available {
                Duration::from_millis(1500)
            } else {
                Duration::from_millis(3500)
            };
            (r.snapshot.clone(), r.last_query.elapsed() >= threshold)
        };

        if need_refresh && !IS_QUERYING.swap(true, std::sync::atomic::Ordering::SeqCst) {
            if let Ok(mut w) = cache_arc.write() {
                w.last_query = Instant::now();
            }
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

        Ok(snap)
    }

    /// Retrieve current media player snapshot, cached non-blockingly.
    pub fn snapshot() -> MediaSnapshot {
        Self::try_snapshot().unwrap_or_default()
    }

    /// Dispatch media transport control command with rich error diagnostics.
    pub fn try_control(cmd: &str) -> Result<(), MprisError> {
        let dbus_method = match cmd.to_ascii_lowercase().as_str() {
            "play-pause" | "playpause" | "toggle" => "PlayPause",
            "next" => "Next",
            "prev" | "previous" => "Previous",
            "stop" => "Stop",
            "play" => "Play",
            "pause" => "Pause",
            _ => return Err(MprisError::UnknownCommand(cmd.to_string())),
        };

        let bus_name = {
            let cache_arc = CACHE.get_or_init(|| {
                Arc::new(RwLock::new(CachedState {
                    last_query: Instant::now() - Duration::from_secs(10),
                    snapshot: MediaSnapshot::default(),
                    active_bus_name: None,
                }))
            });
            let r = match cache_arc.read() {
                Ok(g) => g,
                Err(e) => e.into_inner(),
            };
            r.active_bus_name.clone()
        };

        let target_bus = match bus_name {
            Some(b) => b,
            None => {
                let players = Self::find_mpris_players();
                match players.into_iter().next() {
                    Some(p) => p,
                    None => return Err(MprisError::NoPlayerActive),
                }
            }
        };

        let conn = Self::get_session_connection()
            .ok_or_else(|| MprisError::Dbus(crate::error::DbusError::ServiceUnavailable("D-Bus session bus unavailable".into())))?;

        conn.call_method(
            Some(target_bus.as_str()),
            "/org/mpris/MediaPlayer2",
            Some("org.mpris.MediaPlayer2.Player"),
            dbus_method,
            &(),
        )?;

        // Invalidate cache so next read updates immediately
        if let Some(c) = CACHE.get() {
            if let Ok(mut w) = c.write() {
                w.last_query = Instant::now() - Duration::from_secs(5);
            }
        }

        Ok(())
    }

    /// Dispatch media transport control command ("play-pause", "next", "prev").
    pub fn control(cmd: &str) -> std::io::Result<()> {
        Self::try_control(cmd).map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))
    }

    #[allow(dead_code)]
    fn resolve_dbus_address_arg() -> Option<String> {
        crate::dbus::resolve_session_bus_address()
    }

    fn get_session_connection() -> Option<zbus::blocking::Connection> {
        crate::dbus::get_session_connection().ok()
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

impl MprisController for MprisService {
    fn snapshot(&self) -> Result<MediaSnapshot, MprisError> {
        Self::try_snapshot()
    }

    fn control(&self, cmd: &str) -> Result<(), MprisError> {
        Self::try_control(cmd)
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
