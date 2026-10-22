//! Zenith Services - Native display and keyboard brightness telemetry.

use std::fs;
use std::path::{Path, PathBuf};
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

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Clone, Copy)]
enum BacklightType {
    Raw = 0,
    Platform = 1,
    Firmware = 2,
    Unknown = 3,
}

#[derive(Debug, Clone)]
struct BacklightDevice {
    name: String,
    path: PathBuf,
    current: u64,
    max: u64,
    device_type: BacklightType,
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

    /// Read brightness snapshot directly from sysfs with fallback to default snapshot.
    pub fn get_brightness() -> BrightnessSnapshot {
        let lock = BRIGHTNESS_CACHE.get_or_init(|| {
            RwLock::new((
                Self::default_snapshot(),
                Instant::now() - Duration::from_secs(60),
            ))
        });

        if let Ok(guard) = lock.read() {
            let ttl = if guard.0.device == "none" || guard.0.device == "fallback" || guard.0.device.is_empty() {
                Duration::from_secs(5)
            } else {
                Duration::from_millis(1000)
            };
            if guard.1.elapsed() < ttl {
                return guard.0.clone();
            }
        }

        let snapshot = Self::read_sysfs().unwrap_or_else(Self::default_snapshot);

        if let Ok(mut guard) = lock.write() {
            *guard = (snapshot.clone(), Instant::now());
        }

        snapshot
    }

    fn get_brightness_worker() -> &'static std::sync::mpsc::SyncSender<u8> {
        static WORKER: OnceLock<std::sync::mpsc::SyncSender<u8>> = OnceLock::new();
        WORKER.get_or_init(|| {
            let (tx, rx) = std::sync::mpsc::sync_channel::<u8>(16);
            std::thread::Builder::new()
                .name("zenith-brightness".into())
                .spawn(move || {
                    while let Ok(mut pct) = rx.recv() {
                        while let Ok(next) = rx.try_recv() {
                            pct = next;
                        }
                        Self::apply_brightness(pct);
                        Self::invalidate_cache();
                    }
                })
                .expect("Failed to spawn zenith brightness worker");
            tx
        })
    }

    /// Set brightness percentage (0-100) directly via sysfs or logind D-Bus in background.
    pub fn set_brightness(percent: u8) {
        let pct = percent.clamp(1, 100);
        let _ = Self::get_brightness_worker().try_send(pct);
    }

    fn default_snapshot() -> BrightnessSnapshot {
        BrightnessSnapshot {
            percent: 100,
            current: 100,
            max: 100,
            device: "none".to_string(),
        }
    }

    fn read_sysfs() -> Option<BrightnessSnapshot> {
        Self::read_sysfs_from(Path::new("/sys/class/backlight"))
    }

    fn read_sysfs_from(base: &Path) -> Option<BrightnessSnapshot> {
        let dev = Self::find_backlight_device(base)?;
        let percent = ((dev.current as f64 / dev.max as f64) * 100.0)
            .round()
            .clamp(0.0, 100.0) as u8;
        Some(BrightnessSnapshot {
            percent,
            current: dev.current,
            max: dev.max,
            device: dev.name,
        })
    }

    fn find_backlight_device(base: &Path) -> Option<BacklightDevice> {
        if !base.exists() {
            return None;
        }

        let entries = fs::read_dir(base).ok()?;
        let mut devices = Vec::new();

        for entry in entries.flatten() {
            let path = entry.path();
            let cur_file = path.join("brightness");
            let max_file = path.join("max_brightness");

            if !cur_file.exists() || !max_file.exists() {
                continue;
            }

            let cur_str = match fs::read_to_string(&cur_file) {
                Ok(s) => s,
                Err(_) => continue,
            };
            let max_str = match fs::read_to_string(&max_file) {
                Ok(s) => s,
                Err(_) => continue,
            };

            let current = match cur_str.trim().parse::<u64>() {
                Ok(v) => v,
                Err(_) => continue,
            };
            let max = match max_str.trim().parse::<u64>() {
                Ok(v) if v > 0 => v,
                _ => continue,
            };

            let type_file = path.join("type");
            let device_type = if let Ok(type_str) = fs::read_to_string(&type_file) {
                match type_str.trim() {
                    "raw" => BacklightType::Raw,
                    "platform" => BacklightType::Platform,
                    "firmware" => BacklightType::Firmware,
                    _ => BacklightType::Unknown,
                }
            } else {
                BacklightType::Unknown
            };

            let name = entry.file_name().to_string_lossy().to_string();
            devices.push(BacklightDevice {
                name,
                path,
                current,
                max,
                device_type,
            });
        }

        devices.into_iter().min_by(|a, b| {
            a.device_type
                .cmp(&b.device_type)
                .then_with(|| a.name.cmp(&b.name))
        })
    }

    fn apply_brightness(percent: u8) {
        Self::apply_brightness_to(Path::new("/sys/class/backlight"), percent);
    }

    fn apply_brightness_to(base: &Path, percent: u8) {
        let dev = match Self::find_backlight_device(base) {
            Some(d) => d,
            None => return, // Silent exit: external monitor DDC/CI or desktop without sysfs backlight
        };

        let target = if percent == 0 {
            0
        } else {
            let val = ((percent as f64 / 100.0) * dev.max as f64).round() as u64;
            val.clamp(1, dev.max)
        };

        // 1. Direct sysfs write (fastest, zero-subprocess, works with udev permissions)
        let cur_file = dev.path.join("brightness");
        if fs::write(&cur_file, target.to_string()).is_ok() {
            return;
        }

        // 2. D-Bus logind fallback (org.freedesktop.login1.Session.SetBrightness)
        Self::set_brightness_logind(&dev.name, target);
    }

    fn set_brightness_logind(device: &str, target: u64) {
        if let Ok(conn) = crate::dbus::get_shared_system_connection() {
            let target_u32 = target.min(u32::MAX as u64) as u32;

            let sent = if let Ok(proxy) = zbus::blocking::Proxy::new(
                &conn,
                "org.freedesktop.login1",
                "/org/freedesktop/login1/session/auto",
                "org.freedesktop.login1.Session",
            ) {
                proxy
                    .call_method("SetBrightness", &("backlight", device, target_u32))
                    .is_ok()
            } else {
                false
            };

            if !sent {
                if let Ok(proxy) = zbus::blocking::Proxy::new(
                    &conn,
                    "org.freedesktop.login1",
                    "/org/freedesktop/login1/session/self",
                    "org.freedesktop.login1.Session",
                ) {
                    let _ = proxy.call_method("SetBrightness", &("backlight", device, target_u32));
                }
            }
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

    #[test]
    fn test_read_sysfs_from_mock_dir() {
        let unique = format!(
            "zenith_test_bl_{}_{}",
            std::process::id(),
            Instant::now().elapsed().as_nanos()
        );
        let temp_dir = std::env::temp_dir().join(unique);
        let _ = fs::create_dir_all(&temp_dir);

        let fw_dev = temp_dir.join("acpi_video0");
        let _ = fs::create_dir_all(&fw_dev);
        let _ = fs::write(fw_dev.join("brightness"), "50\n");
        let _ = fs::write(fw_dev.join("max_brightness"), "100\n");
        let _ = fs::write(fw_dev.join("type"), "firmware\n");

        let raw_dev = temp_dir.join("intel_backlight");
        let _ = fs::create_dir_all(&raw_dev);
        let _ = fs::write(raw_dev.join("brightness"), "120\n");
        let _ = fs::write(raw_dev.join("max_brightness"), "240\n");
        let _ = fs::write(raw_dev.join("type"), "raw\n");

        let snap = BrightnessService::read_sysfs_from(&temp_dir).expect("should find raw backlight");
        assert_eq!(snap.device, "intel_backlight");
        assert_eq!(snap.percent, 50);
        assert_eq!(snap.current, 120);
        assert_eq!(snap.max, 240);

        // Test direct sysfs writing
        BrightnessService::apply_brightness_to(&temp_dir, 75);
        let updated = fs::read_to_string(raw_dev.join("brightness")).unwrap();
        assert_eq!(updated.trim(), "180"); // 75% of 240 is 180

        let _ = fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_no_backlight_graceful() {
        let unique = format!(
            "zenith_test_bl_empty_{}_{}",
            std::process::id(),
            Instant::now().elapsed().as_nanos()
        );
        let temp_dir = std::env::temp_dir().join(unique);
        let _ = fs::create_dir_all(&temp_dir);

        let snap = BrightnessService::read_sysfs_from(&temp_dir);
        assert!(snap.is_none());

        // Should exit gracefully without panicking
        BrightnessService::apply_brightness_to(&temp_dir, 50);

        let _ = fs::remove_dir_all(&temp_dir);
    }
}

