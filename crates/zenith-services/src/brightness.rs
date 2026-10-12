//! Zenith Services - Native display and keyboard brightness telemetry.

use std::fs;
use std::path::Path;
use std::sync::{OnceLock, RwLock};
use std::time::{Duration, Instant};

static BRIGHTNESS_CACHE: OnceLock<RwLock<(BrightnessSnapshot, Instant)>> = OnceLock::new();

/// Telemetry snapshot for display brightness.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct BrightnessSnapshot {
    pub percent: u8,
    pub current: u64,
    pub max: u64,
    pub device: String,
}

pub struct BrightnessService;

impl BrightnessService {
    /// Invalidate the brightness cache.
    pub fn invalidate_cache() {
        if let Some(lock) = BRIGHTNESS_CACHE.get() {
            if let Ok(mut guard) = lock.write() {
                guard.1 = Instant::now() - Duration::from_secs(60);
            }
        }
    }

    /// Read brightness snapshot directly from sysfs with fallback to brightnessctl.
    pub fn get_brightness() -> BrightnessSnapshot {
        let lock = BRIGHTNESS_CACHE.get_or_init(|| {
            RwLock::new((
                BrightnessSnapshot {
                    percent: 100,
                    current: 100,
                    max: 100,
                    device: "fallback".to_string(),
                },
                Instant::now() - Duration::from_secs(60),
            ))
        });

        if let Ok(guard) = lock.read() {
            let ttl = if guard.0.device == "fallback" || guard.0.device.is_empty() {
                Duration::from_secs(5)
            } else {
                Duration::from_millis(1000)
            };
            if guard.1.elapsed() < ttl {
                return guard.0.clone();
            }
        }

        let snapshot = Self::read_sysfs().unwrap_or_else(Self::read_brightnessctl_or_default);

        if let Ok(mut guard) = lock.write() {
            *guard = (snapshot.clone(), Instant::now());
        }

        snapshot
    }

    /// Set brightness percentage (0-100) via brightnessctl in background.
    pub fn set_brightness(percent: u8) {
        let pct = percent.clamp(1, 100);
        std::thread::spawn(move || {
            let _ = std::process::Command::new("brightnessctl")
                .args(["set", &format!("{}%", pct)])
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .status();
            Self::invalidate_cache();
        });
    }

    fn read_sysfs() -> Option<BrightnessSnapshot> {
        let base = Path::new("/sys/class/backlight");
        if !base.exists() {
            return None;
        }

        let entries = fs::read_dir(base).ok()?;
        for entry in entries.flatten() {
            let path = entry.path();
            let cur_file = path.join("brightness");
            let max_file = path.join("max_brightness");

            if cur_file.exists() && max_file.exists() {
                let cur_str = fs::read_to_string(&cur_file).ok()?;
                let max_str = fs::read_to_string(&max_file).ok()?;

                let current = cur_str.trim().parse::<u64>().ok()?;
                let max = max_str.trim().parse::<u64>().ok()?;

                if max > 0 {
                    let percent = ((current as f64 / max as f64) * 100.0).round().clamp(0.0, 100.0) as u8;
                    let device = entry.file_name().to_string_lossy().to_string();
                    return Some(BrightnessSnapshot {
                        percent,
                        current,
                        max,
                        device,
                    });
                }
            }
        }
        None
    }

    fn read_brightnessctl_or_default() -> BrightnessSnapshot {
        if let Ok(output) = std::process::Command::new("brightnessctl")
            .args(["-m"])
            .output()
        {
            if output.status.success() {
                let text = String::from_utf8_lossy(&output.stdout);
                // format: device,class,current,percent%,max
                if let Some(line) = text.lines().next() {
                    let parts: Vec<&str> = line.split(',').collect();
                    if parts.len() >= 5 {
                        let device = parts[0].to_string();
                        let current = parts[2].parse::<u64>().unwrap_or(100);
                        let pct_clean = parts[3].trim_end_matches('%');
                        let percent = pct_clean.parse::<u8>().unwrap_or(100);
                        let max = parts[4].parse::<u64>().unwrap_or(100);
                        return BrightnessSnapshot {
                            percent,
                            current,
                            max,
                            device,
                        };
                    }
                }
            }
        }

        BrightnessSnapshot {
            percent: 100,
            current: 100,
            max: 100,
            device: "default".to_string(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_brightness_query_and_cache() {
        let b = BrightnessService::get_brightness();
        assert!(b.percent <= 100);
        assert!(!b.device.is_empty());
    }
}
