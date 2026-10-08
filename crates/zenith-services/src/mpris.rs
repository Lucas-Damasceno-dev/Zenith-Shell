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

/// MPRIS2 Media Controller service.
pub struct MprisService;

impl MprisService {
    /// Retrieve current media player snapshot, cached for 1 second.
    pub fn snapshot() -> MediaSnapshot {
        let cache_arc = CACHE.get_or_init(|| {
            Arc::new(RwLock::new(CachedState {
                last_query: Instant::now() - Duration::from_secs(10),
                snapshot: MediaSnapshot::default(),
                active_bus_name: None,
            }))
        });

        {
            let r = cache_arc.read().unwrap();
            if r.last_query.elapsed() < Duration::from_millis(800) {
                return r.snapshot.clone();
            }
        }

        let (fresh_snap, bus_name) = Self::query_active_player();

        let mut w = cache_arc.write().unwrap();
        w.last_query = Instant::now();
        w.snapshot = fresh_snap.clone();
        w.active_bus_name = bus_name;

        fresh_snap
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

        let mut bus_cmd = Self::build_busctl_cmd();
        bus_cmd.args([
            "call",
            &target_bus,
            "/org/mpris/MediaPlayer2",
            "org.mpris.MediaPlayer2.Player",
            dbus_method,
        ]);

        let _ = bus_cmd.spawn();

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

    fn build_busctl_cmd() -> std::process::Command {
        let mut cmd = std::process::Command::new("busctl");
        if let Some(addr) = Self::resolve_dbus_address_arg() {
            cmd.arg(addr);
        } else {
            cmd.arg("--user");
        }
        cmd
    }

    fn find_mpris_players() -> Vec<String> {
        let mut cmd = Self::build_busctl_cmd();
        cmd.args(["list"]);

        let output = match cmd.output() {
            Ok(o) if o.status.success() => o.stdout,
            _ => return Vec::new(),
        };

        let text = String::from_utf8_lossy(&output);
        let mut players = Vec::new();

        for line in text.lines() {
            let first = line.split_whitespace().next().unwrap_or("");
            if first.starts_with("org.mpris.MediaPlayer2.") {
                players.push(first.to_string());
            }
        }

        players
    }

    fn query_active_player() -> (MediaSnapshot, Option<String>) {
        let players = Self::find_mpris_players();
        if players.is_empty() {
            return (MediaSnapshot::default(), None);
        }

        let mut first_match = None;
        for player_bus in players {
            let status = Self::get_player_property(&player_bus, "PlaybackStatus")
                .unwrap_or_else(|| "Stopped".to_string());

            let metadata_str = Self::get_player_property(&player_bus, "Metadata").unwrap_or_default();
            let (title, artist, album, art_url, length) = Self::parse_metadata(&metadata_str);

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

    fn get_player_property(bus: &str, prop: &str) -> Option<String> {
        let mut cmd = Self::build_busctl_cmd();
        cmd.args([
            "get-property",
            bus,
            "/org/mpris/MediaPlayer2",
            "org.mpris.MediaPlayer2.Player",
            prop,
        ]);

        let output = cmd.output().ok()?;
        if !output.status.success() {
            return None;
        }

        let raw = String::from_utf8_lossy(&output.stdout);
        let trimmed = raw.trim();

        // If string response formatted as `s "Content"`
        if trimmed.starts_with("s \"") && trimmed.ends_with('\"') {
            return Some(trimmed[3..trimmed.len() - 1].to_string());
        }

        Some(trimmed.to_string())
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
