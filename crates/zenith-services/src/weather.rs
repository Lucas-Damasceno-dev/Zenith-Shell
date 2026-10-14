//! Weather telemetry service for Zenith Shell.
//!
//! Fetches ambient temperature and weather conditions with non-blocking caching.

use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};
use serde::{Deserialize, Serialize};

/// Weather condition snapshot.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct WeatherSnapshot {
    pub temp_c: f32,
    pub condition: String,
    pub icon: String,
    pub city: String,
}

impl Default for WeatherSnapshot {
    fn default() -> Self {
        Self {
            temp_c: 22.0,
            condition: "Clear".to_string(),
            icon: "󰖙".to_string(),
            city: "Local".to_string(),
        }
    }
}

struct WeatherCache {
    snapshot: WeatherSnapshot,
    last_fetch: Instant,
}

static CACHE: OnceLock<Arc<Mutex<WeatherCache>>> = OnceLock::new();

pub struct WeatherService;

impl WeatherService {
    fn cache() -> &'static Arc<Mutex<WeatherCache>> {
        CACHE.get_or_init(|| {
            Arc::new(Mutex::new(WeatherCache {
                snapshot: WeatherSnapshot::default(),
                last_fetch: Instant::now() - Duration::from_secs(3600),
            }))
        })
    }

    /// Retrieve current weather conditions with 10-minute cache TTL.
    pub fn snapshot() -> WeatherSnapshot {
        let cache_arc = Self::cache();
        let mut guard = cache_arc.lock().unwrap();

        if guard.last_fetch.elapsed() > Duration::from_secs(600) {
            guard.last_fetch = Instant::now();
            let c_clone = cache_arc.clone();
            std::thread::spawn(move || {
                if let Some(snap) = Self::fetch_remote() {
                    let mut g = c_clone.lock().unwrap();
                    g.snapshot = snap;
                }
            });
        }

        guard.snapshot.clone()
    }

    fn fetch_wttr_native() -> Option<String> {
        use std::io::{Read, Write};
        use std::net::{TcpStream, ToSocketAddrs};

        let addr = "wttr.in:80".to_socket_addrs().ok()?.next()?;
        let mut stream = TcpStream::connect_timeout(&addr, Duration::from_secs(3)).ok()?;
        let _ = stream.set_read_timeout(Some(Duration::from_secs(3)));
        let _ = stream.set_write_timeout(Some(Duration::from_secs(3)));

        let req = "GET /?format=%t+%C HTTP/1.1\r\nHost: wttr.in\r\nUser-Agent: Zenith-Shell\r\nConnection: close\r\n\r\n";
        stream.write_all(req.as_bytes()).ok()?;

        let mut resp = Vec::new();
        stream.read_to_end(&mut resp).ok()?;
        let resp_str = String::from_utf8_lossy(&resp);

        if let Some((_header, body)) = resp_str.split_once("\r\n\r\n") {
            let body_trimmed = body.trim();
            if !body_trimmed.is_empty() && (body_trimmed.starts_with('+') || body_trimmed.starts_with('-') || body_trimmed.contains("°C")) {
                return Some(body_trimmed.to_string());
            }
        }
        None
    }

    fn fetch_remote() -> Option<WeatherSnapshot> {
        let text = Self::fetch_wttr_native()?;

        // Format: "+23°C Clear"
        let parts: Vec<&str> = text.split_whitespace().collect();
        if !parts.is_empty() {
                let temp_str = parts[0].trim_end_matches("°C").trim_start_matches('+');
                let temp = temp_str.parse::<f32>().unwrap_or(22.0);
                let condition = if parts.len() > 1 { parts[1..].join(" ") } else { "Clear".to_string() };
                let icon = Self::resolve_icon(&condition);
                return Some(WeatherSnapshot {
                    temp_c: temp,
                    condition,
                    icon,
                    city: "Current".to_string(),
                });
            }

        None
    }

    fn resolve_icon(cond: &str) -> String {
        let c = cond.to_lowercase();
        if c.contains("sun") || c.contains("clear") {
            "󰖙".to_string()
        } else if c.contains("cloud") || c.contains("overcast") {
            "󰖐".to_string()
        } else if c.contains("rain") || c.contains("drizzle") {
            "󰖖".to_string()
        } else if c.contains("thunder") || c.contains("storm") {
            "󰖓".to_string()
        } else if c.contains("snow") || c.contains("ice") {
            "󰖘".to_string()
        } else if c.contains("fog") || c.contains("mist") {
            "󰖑".to_string()
        } else {
            "󰖐".to_string()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_weather_snapshot_fallback() {
        let snap = WeatherService::snapshot();
        assert!(!snap.icon.is_empty());
        assert!(!snap.condition.is_empty());
    }
}
