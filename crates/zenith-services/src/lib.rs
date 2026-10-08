//! Zenith Services - Native hardware telemetry, system metrics, and compositor integration.

use std::fs;
use std::path::Path;

/// Snapshot of system memory status.
#[derive(Debug, Clone, Default)]
pub struct MemorySnapshot {
    pub total_mb: u64,
    pub used_mb: u64,
    pub available_mb: u64,
    pub percent: u8,
}

/// Snapshot of battery status.
#[derive(Debug, Clone, Default)]
pub struct BatterySnapshot {
    pub percentage: u8,
    pub status: String,
    pub is_charging: bool,
}

/// System service provider.
pub struct SystemService;

impl SystemService {
    /// Get current formatted local time (HH:MM:SS) and date (Day, Month DD).
    pub fn current_time() -> (String, String) {
        unsafe {
            let mut raw_time: libc::time_t = 0;
            libc::time(&mut raw_time);
            let mut tm_buf: libc::tm = std::mem::zeroed();
            libc::localtime_r(&raw_time, &mut tm_buf);

            let time_str = format!(
                "{:02}:{:02}:{:02}",
                tm_buf.tm_hour, tm_buf.tm_min, tm_buf.tm_sec
            );

            let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            let m_idx = (tm_buf.tm_mon as usize).min(11);
            let d_idx = (tm_buf.tm_wday as usize).min(6);

            let date_str = format!(
                "{}, {} {:02}",
                days[d_idx], months[m_idx], tm_buf.tm_mday
            );

            (time_str, date_str)
        }
    }

    /// Read memory metrics from `/proc/meminfo`.
    pub fn memory_snapshot() -> MemorySnapshot {
        let content = fs::read_to_string("/proc/meminfo").unwrap_or_default();
        let mut total_kb: u64 = 0;
        let mut avail_kb: u64 = 0;

        for line in content.lines() {
            if line.starts_with("MemTotal:") {
                total_kb = parse_meminfo_kb(line);
            } else if line.starts_with("MemAvailable:") {
                avail_kb = parse_meminfo_kb(line);
            }
        }

        if total_kb == 0 {
            return MemorySnapshot::default();
        }

        let used_kb = total_kb.saturating_sub(avail_kb);
        let total_mb = total_kb / 1024;
        let used_mb = used_kb / 1024;
        let available_mb = avail_kb / 1024;
        let percent = ((used_kb as f64 / total_kb as f64) * 100.0).round() as u8;

        MemorySnapshot {
            total_mb,
            used_mb,
            available_mb,
            percent,
        }
    }

    /// Read battery capacity and charging status from `/sys/class/power_supply/`.
    pub fn battery_snapshot() -> Option<BatterySnapshot> {
        let ps_path = Path::new("/sys/class/power_supply");
        if !ps_path.exists() {
            return None;
        }

        if let Ok(entries) = fs::read_dir(ps_path) {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.starts_with("BAT") {
                    let cap_file = entry.path().join("capacity");
                    let status_file = entry.path().join("status");

                    let cap = fs::read_to_string(cap_file)
                        .ok()
                        .and_then(|s| s.trim().parse::<u8>().ok())
                        .unwrap_or(100);

                    let status = fs::read_to_string(status_file)
                        .ok()
                        .map(|s| s.trim().to_string())
                        .unwrap_or_else(|| "Unknown".to_string());

                    let is_charging = status.eq_ignore_ascii_case("Charging");

                    return Some(BatterySnapshot {
                        percentage: cap,
                        status,
                        is_charging,
                    });
                }
            }
        }

        None
    }

    /// Reads compositor identity or Hyprland active state if present.
    pub fn compositor_info() -> String {
        if let Ok(sig) = std::env::var("HYPRLAND_INSTANCE_SIGNATURE") {
            format!("Hyprland ({})", &sig[..sig.len().min(8)])
        } else if let Ok(disp) = std::env::var("WAYLAND_DISPLAY") {
            format!("Wayland ({})", disp)
        } else {
            "Desktop Shell".to_string()
        }
    }
}

fn parse_meminfo_kb(line: &str) -> u64 {
    let mut parts = line.split_whitespace();
    parts.nth(1).and_then(|val| val.parse::<u64>().ok()).unwrap_or(0)
}
