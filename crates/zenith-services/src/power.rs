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
            if guard.1.elapsed() < Duration::from_secs(2) {
                return guard.0.clone();
            }
        }

        let profile = Self::read_platform_profile()
            .or_else(Self::read_powerprofilesctl)
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
            let _ = std::process::Command::new("powerprofilesctl")
                .args(["set", &prof_str])
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .status();
            Self::invalidate_cache();
        });
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

    fn read_powerprofilesctl() -> Option<String> {
        let output = std::process::Command::new("powerprofilesctl")
            .args(["get"])
            .output()
            .ok()?;

        if output.status.success() {
            let s = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !s.is_empty() {
                return Some(s);
            }
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_power_profile_get() {
        let p = PowerProfileService::get_profile();
        assert!(!p.is_empty());
    }
}
