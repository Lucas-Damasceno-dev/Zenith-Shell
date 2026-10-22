//! Zenith Services - Native power profiles telemetry and switching.

use std::fs;
use std::path::Path;
use std::sync::{OnceLock, RwLock};
use std::time::{Duration, Instant};

static POWER_PROFILE_CACHE: OnceLock<RwLock<(String, Instant)>> = OnceLock::new();

pub struct PowerProfileService;

impl PowerProfileService {
    /// Invalidate power profile cache.
    pub fn invalidate_cache() {
        if let Some(lock) = POWER_PROFILE_CACHE.get() {
            if let Ok(mut guard) = lock.write() {
                guard.1 = Instant::now() - Duration::from_secs(60);
            }
        }
    }

    /// Get active power profile ("performance", "balanced", or "power-saver").
    pub fn get_profile() -> String {
        let lock = POWER_PROFILE_CACHE.get_or_init(|| {
            RwLock::new((
                "balanced".to_string(),
                Instant::now() - Duration::from_secs(60),
            ))
        });

        if let Ok(guard) = lock.read() {
            if guard.1.elapsed() < Duration::from_secs(10) {
                return guard.0.clone();
            }
        }

        let profile = Self::read_dbus_power_profile()
            .or_else(Self::read_platform_profile)
            .unwrap_or_else(|| "balanced".to_string());

        if let Ok(mut guard) = lock.write() {
            *guard = (profile.clone(), Instant::now());
        }

        profile
    }

    /// Set power profile asynchronously.
    pub fn set_profile(profile: &str) {
        let prof = match profile.to_lowercase().as_str() {
            "performance" => "performance",
            "low-power" | "power-saver" | "powersaver" => "power-saver",
            _ => "balanced",
        };

        let prof_str = prof.to_string();
        std::thread::spawn(move || {
            let sent_native = if let Ok(conn) = crate::dbus::get_shared_system_connection() {
                if let Ok(proxy) = zbus::blocking::Proxy::new(
                    &conn,
                    "net.hadess.PowerProfiles",
                    "/net/hadess/PowerProfiles",
                    "net.hadess.PowerProfiles",
                ) {
                    proxy.set_property("ActiveProfile", &prof_str).is_ok()
                } else {
                    false
                }
            } else {
                false
            };

            if !sent_native {
                // Direct kernel sysfs write (zero-subprocess)
                let _ = fs::write("/sys/firmware/acpi/platform_profile", &prof_str);
            }
            Self::invalidate_cache();
        });
    }

    fn read_dbus_power_profile() -> Option<String> {
        if let Ok(conn) = crate::dbus::get_shared_system_connection() {
            if let Ok(proxy) = zbus::blocking::Proxy::new(
                &conn,
                "net.hadess.PowerProfiles",
                "/net/hadess/PowerProfiles",
                "net.hadess.PowerProfiles",
            ) {
                if let Ok(prof) = proxy.get_property::<String>("ActiveProfile") {
                    let trimmed = prof.trim().to_string();
                    if !trimmed.is_empty() {
                        return Some(trimmed);
                    }
                }
            }
        }
        None
    }

    fn read_platform_profile() -> Option<String> {
        let path = Path::new("/sys/firmware/acpi/platform_profile");
        if path.exists() {
            let content = fs::read_to_string(path).ok()?;
            let trimmed = content.trim();
            if !trimmed.is_empty() {
                return Some(trimmed.to_string());
            }
        }
        None
    }

    /// Suspend system via logind / systemd D-Bus or kernel /sys/power/state.
    pub fn suspend() {
        std::thread::spawn(|| {
            if let Ok(conn) = crate::dbus::get_shared_system_connection() {
                if let Ok(proxy) = zbus::blocking::Proxy::new(
                    &conn,
                    "org.freedesktop.login1",
                    "/org/freedesktop/login1",
                    "org.freedesktop.login1.Manager",
                ) {
                    if proxy.call_method("Suspend", &(true,)).is_ok() {
                        return;
                    }
                }
                if let Ok(proxy) = zbus::blocking::Proxy::new(
                    &conn,
                    "org.freedesktop.systemd1",
                    "/org/freedesktop/systemd1",
                    "org.freedesktop.systemd1.Manager",
                ) {
                    if proxy.call_method("StartUnit", &("suspend.target", "replace")).is_ok() {
                        return;
                    }
                }
            }
            let _ = fs::write("/sys/power/state", "mem");
        });
    }

    /// Reboot system via logind / systemd D-Bus or kernel sysrq.
    pub fn reboot() {
        std::thread::spawn(|| {
            if let Ok(conn) = crate::dbus::get_shared_system_connection() {
                if let Ok(proxy) = zbus::blocking::Proxy::new(
                    &conn,
                    "org.freedesktop.login1",
                    "/org/freedesktop/login1",
                    "org.freedesktop.login1.Manager",
                ) {
                    if proxy.call_method("Reboot", &(true,)).is_ok() {
                        return;
                    }
                }
                if let Ok(proxy) = zbus::blocking::Proxy::new(
                    &conn,
                    "org.freedesktop.systemd1",
                    "/org/freedesktop/systemd1",
                    "org.freedesktop.systemd1.Manager",
                ) {
                    if proxy.call_method("StartUnit", &("reboot.target", "replace")).is_ok() {
                        return;
                    }
                }
            }
            let _ = fs::write("/proc/sysrq-trigger", "b");
        });
    }

    /// Power off system via logind / systemd D-Bus or kernel sysrq.
    pub fn poweroff() {
        std::thread::spawn(|| {
            if let Ok(conn) = crate::dbus::get_shared_system_connection() {
                if let Ok(proxy) = zbus::blocking::Proxy::new(
                    &conn,
                    "org.freedesktop.login1",
                    "/org/freedesktop/login1",
                    "org.freedesktop.login1.Manager",
                ) {
                    if proxy.call_method("PowerOff", &(true,)).is_ok() {
                        return;
                    }
                }
                if let Ok(proxy) = zbus::blocking::Proxy::new(
                    &conn,
                    "org.freedesktop.systemd1",
                    "/org/freedesktop/systemd1",
                    "org.freedesktop.systemd1.Manager",
                ) {
                    if proxy.call_method("StartUnit", &("poweroff.target", "replace")).is_ok() {
                        return;
                    }
                }
            }
            let _ = fs::write("/proc/sysrq-trigger", "o");
        });
    }
}

pub type PowerService = PowerProfileService;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_power_profile_get() {
        let p = PowerProfileService::get_profile();
        assert!(!p.is_empty());
    }
}
