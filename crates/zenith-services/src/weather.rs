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
static WEATHER_CONFIG: OnceLock<std::sync::RwLock<(String, String)>> = OnceLock::new();

pub struct WeatherService;

impl WeatherService {
    /// Configure city name and temperature unit ("metric" or "imperial").
    pub fn set_config(city: &str, units: &str) {
        let lock = WEATHER_CONFIG.get_or_init(|| std::sync::RwLock::new(("auto".into(), "metric".into())));
        if let Ok(mut g) = lock.write() {
            *g = (city.to_string(), units.to_string());
        }
    }

    fn get_config() -> (String, String) {
        let lock = WEATHER_CONFIG.get_or_init(|| std::sync::RwLock::new(("auto".into(), "metric".into())));
        lock.read()
            .map(|g| g.clone())
            .unwrap_or_else(|_| ("auto".into(), "metric".into()))
    }

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

    /// Decodes HTTP chunked transfer encoding payload.
    pub fn decode_chunked(raw: &str) -> String {
        let mut result = String::new();
        let mut remaining = raw;
        while !remaining.is_empty() {
            if let Some((size_line, rest)) = remaining.split_once("\r\n") {
                let size_str = size_line.trim().split(';').next().unwrap_or("").trim();
                if let Ok(size) = usize::from_str_radix(size_str, 16) {
                    if size == 0 {
                        break;
                    }
                    if rest.len() >= size {
                        result.push_str(&rest[..size]);
                        let after = &rest[size..];
                        remaining = after.strip_prefix("\r\n").unwrap_or(after);
                    } else {
                        result.push_str(rest);
                        break;
                    }
                } else {
                    result.push_str(remaining);
                    break;
                }
            } else {
                result.push_str(remaining);
                break;
            }
        }
        result
    }

    fn fetch_wttr_native(city: &str, units: &str) -> Option<String> {
        use std::io::{Read, Write};
        use std::net::{TcpStream, ToSocketAddrs};

        let addr = "wttr.in:80".to_socket_addrs().ok()?.next()?;
        let mut stream = TcpStream::connect_timeout(&addr, Duration::from_secs(3)).ok()?;
        let _ = stream.set_read_timeout(Some(Duration::from_secs(3)));
        let _ = stream.set_write_timeout(Some(Duration::from_secs(3)));

        let unit_param = if units.eq_ignore_ascii_case("imperial") { "u" } else { "m" };
        let path = if city.is_empty() || city.eq_ignore_ascii_case("auto") || city.eq_ignore_ascii_case("local") {
            format!("/?format=%t+%C&{}", unit_param)
        } else {
            let encoded_city = city.replace(' ', "+");
            format!("/{}?format=%t+%C&{}", encoded_city, unit_param)
        };

        let req = format!("GET {} HTTP/1.1\r\nHost: wttr.in\r\nUser-Agent: Zenith-Shell\r\nConnection: close\r\n\r\n", path);
        stream.write_all(req.as_bytes()).ok()?;

        let mut resp = Vec::new();
        stream.read_to_end(&mut resp).ok()?;
        let resp_str = String::from_utf8_lossy(&resp);

        // Validate HTTP 200 status code
        let status_line = resp_str.lines().next()?;
        if !status_line.contains(" 200 ") && !status_line.ends_with(" 200") {
            return None;
        }

        if let Some((header, body)) = resp_str.split_once("\r\n\r\n") {
            let decoded_body = if header.to_lowercase().contains("transfer-encoding: chunked") {
                Self::decode_chunked(body)
            } else {
                body.to_string()
            };

            let body_trimmed = decoded_body.trim();
            if !body_trimmed.is_empty()
                && (body_trimmed.starts_with('+') || body_trimmed.starts_with('-') || body_trimmed.contains('°'))
            {
                return Some(body_trimmed.to_string());
            }
        }
        None
    }

    fn fetch_remote() -> Option<WeatherSnapshot> {
        let (city_cfg, units_cfg) = Self::get_config();
        let text = Self::fetch_wttr_native(&city_cfg, &units_cfg)?;

        // Format: "+23°C Clear" or "+72°F Sunny"
        let parts: Vec<&str> = text.split_whitespace().collect();
        if !parts.is_empty() {
            let temp_str = parts[0]
                .trim_end_matches("°C")
                .trim_end_matches("°F")
                .trim_start_matches('+');
            let temp = temp_str.parse::<f32>().unwrap_or(22.0);
            let condition = if parts.len() > 1 { parts[1..].join(" ") } else { "Clear".to_string() };
            let icon = Self::resolve_icon(&condition);
            let display_city = if city_cfg.is_empty() || city_cfg.eq_ignore_ascii_case("auto") {
                "Local".to_string()
            } else {
                city_cfg
            };
            return Some(WeatherSnapshot {
                temp_c: temp,
                condition,
                icon,
                city: display_city,
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

    #[test]
    fn test_decode_chunked() {
        let chunked = "7\r\nMozilla\r\n9\r\nDeveloper\r\n7\r\nNetwork\r\n0\r\n\r\n";
        let decoded = WeatherService::decode_chunked(chunked);
        assert_eq!(decoded, "MozillaDeveloperNetwork");
    }

    #[test]
    fn test_set_config() {
        WeatherService::set_config("Tokyo", "imperial");
        let (city, units) = WeatherService::get_config();
        assert_eq!(city, "Tokyo");
        assert_eq!(units, "imperial");
    }
}
