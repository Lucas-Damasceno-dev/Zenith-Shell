//! Zenith Services - Native hardware telemetry, system metrics, Matugen theming, and SVG rendering.

use std::fs;
use std::path::{Path, PathBuf};
use serde_json::Value;

pub mod hyprland;
pub use hyprland::{ActiveWindowSnapshot, ClientItem, HyprlandService, WorkspaceItem, WorkspacesSnapshot};

pub mod launcher;
pub use launcher::{AppEntry, LauncherService};

pub mod mpris;
pub use mpris::{MediaSnapshot, MprisService};

pub mod notifications;
pub use notifications::{NotificationItem, NotificationService};

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

/// Snapshot of system audio status via Pipewire/wpctl.
#[derive(Debug, Clone, Default)]
pub struct AudioSnapshot {
    pub volume: u8,
    pub is_muted: bool,
}

/// Snapshot of network status via NetworkManager / nmcli.
#[derive(Debug, Clone, Default)]
pub struct NetworkSnapshot {
    pub is_connected: bool,
    pub connection_type: String, // "wifi", "ethernet", "disconnected"
    pub ssid: String,
}

/// Snapshot of CPU usage.
#[derive(Debug, Clone, Default)]
pub struct CpuSnapshot {
    pub percent: u8,
}


/// Dynamic Material You theme palette (loaded from Matugen/Stylix).
#[derive(Debug, Clone)]
pub struct ThemePalette {
    pub background: String,
    pub primary: String,
    pub surface: String,
    pub on_surface: String,
    pub on_primary: String,
    pub outline: String,
    pub surface_container: String,
}

impl Default for ThemePalette {
    fn default() -> Self {
        Self {
            background: "#0c141bf2".to_string(),
            primary: "#7c4dff".to_string(),
            surface: "#18202bcc".to_string(),
            on_surface: "#dbe3ed".to_string(),
            on_primary: "#ffffff".to_string(),
            outline: "#333d4b".to_string(),
            surface_container: "#1e2632".to_string(),
        }
    }
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

    /// Read audio sink volume and mute state via `wpctl`.
    pub fn audio_snapshot() -> AudioSnapshot {
        if let Ok(output) = std::process::Command::new("wpctl")
            .args(["get-volume", "@DEFAULT_AUDIO_SINK@"])
            .output()
        {
            let text = String::from_utf8_lossy(&output.stdout);
            for line in text.lines() {
                if line.contains("Volume:") {
                    let is_muted = line.contains("[MUTED]");
                    let parts: Vec<&str> = line.split_whitespace().collect();
                    if parts.len() >= 2 {
                        if let Ok(vol_float) = parts[1].parse::<f32>() {
                            let volume = (vol_float * 100.0).round().min(100.0) as u8;
                            return AudioSnapshot { volume, is_muted };
                        }
                    }
                }
            }
        }

        AudioSnapshot {
            volume: 75,
            is_muted: false,
        }
    }

    /// Read active network connection status via `nmcli`.
    pub fn network_snapshot() -> NetworkSnapshot {
        if let Ok(output) = std::process::Command::new("nmcli")
            .args(["-t", "-f", "TYPE,STATE", "dev"])
            .output()
        {
            let text = String::from_utf8_lossy(&output.stdout);
            let mut has_ethernet = false;
            let mut has_wifi = false;

            for line in text.lines() {
                let parts: Vec<&str> = line.split(':').collect();
                if parts.len() >= 2 && parts[1] == "connected" {
                    if parts[0] == "ethernet" {
                        has_ethernet = true;
                    } else if parts[0] == "wifi" {
                        has_wifi = true;
                    }
                }
            }

            if has_ethernet {
                return NetworkSnapshot {
                    is_connected: true,
                    connection_type: "ethernet".to_string(),
                    ssid: "Wired".to_string(),
                };
            } else if has_wifi {
                return NetworkSnapshot {
                    is_connected: true,
                    connection_type: "wifi".to_string(),
                    ssid: "Wi-Fi".to_string(),
                };
            }
        }

        NetworkSnapshot {
            is_connected: false,
            connection_type: "disconnected".to_string(),
            ssid: "".to_string(),
        }
    }

    /// Read CPU load percentage from `/proc/stat`.
    pub fn cpu_snapshot() -> CpuSnapshot {
        if let Ok(stat) = fs::read_to_string("/proc/stat") {
            if let Some(first_line) = stat.lines().next() {
                if first_line.starts_with("cpu ") {
                    let parts: Vec<u64> = first_line
                        .split_whitespace()
                        .skip(1)
                        .filter_map(|s| s.parse::<u64>().ok())
                        .collect();
                    if parts.len() >= 4 {
                        let idle = parts[3];
                        let total: u64 = parts.iter().sum();
                        if total > 0 {
                            let percent = (((total - idle) as f64 / total as f64) * 100.0).round() as u8;
                            return CpuSnapshot { percent: percent.min(100) };
                        }
                    }
                }
            }
        }
        CpuSnapshot { percent: 12 }
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

    /// Loads active Material You theme colors from Matugen/Stylix cache.
    pub fn load_theme() -> ThemePalette {
        let candidates = [
            dirs_home_path(".cache/quickshell/matugen/colors.json"),
            dirs_home_path(".cache/matugen/colors.json"),
            dirs_home_path(".config/quickshell/colors.json"),
        ];

        for path in candidates.into_iter().flatten() {
            if path.exists() {
                if let Ok(content) = fs::read_to_string(&path) {
                    if let Ok(val) = serde_json::from_str::<Value>(&content) {
                        return Self::parse_matugen_json(&val);
                    }
                }
            }
        }

        ThemePalette::default()
    }

    fn parse_matugen_json(val: &Value) -> ThemePalette {
        let colors = &val["colors"];
        let mut palette = ThemePalette::default();

        let extract_color = |key: &str| -> Option<String> {
            colors[key]["default"]["color"]
                .as_str()
                .or_else(|| colors[key]["dark"]["color"].as_str())
                .map(|s| s.to_string())
        };

        if let Some(c) = extract_color("background") { palette.background = format!("{}F2", c); }
        if let Some(c) = extract_color("primary") { palette.primary = c; }
        if let Some(c) = extract_color("surface") { palette.surface = format!("{}CC", c); }
        if let Some(c) = extract_color("on_surface") { palette.on_surface = c; }
        if let Some(c) = extract_color("on_primary") { palette.on_primary = c; }
        if let Some(c) = extract_color("outline") { palette.outline = c; }
        if let Some(c) = extract_color("surface_container") { palette.surface_container = c; }

        palette
    }

    /// Rasterize an SVG string into an RGBA pixel buffer at `[width, height]`.
    pub fn render_svg(svg_str: &str, width: u32, height: u32) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        let opt = resvg::usvg::Options::default();
        let tree = resvg::usvg::Tree::from_str(svg_str, &opt)?;

        let mut pixmap = resvg::tiny_skia::Pixmap::new(width, height)
            .ok_or("Failed to allocate SVG pixmap")?;

        let svg_w = tree.size().width();
        let svg_h = tree.size().height();
        let scale_x = width as f32 / svg_w;
        let scale_y = height as f32 / svg_h;
        let transform = resvg::tiny_skia::Transform::from_scale(scale_x, scale_y);

        resvg::render(&tree, transform, &mut pixmap.as_mut());
        Ok(pixmap.take())
    }
}

fn parse_meminfo_kb(line: &str) -> u64 {
    let mut parts = line.split_whitespace();
    parts.nth(1).and_then(|val| val.parse::<u64>().ok()).unwrap_or(0)
}

fn dirs_home_path(sub: &str) -> Option<PathBuf> {
    std::env::var("HOME").ok().map(|h| PathBuf::from(h).join(sub))
}
