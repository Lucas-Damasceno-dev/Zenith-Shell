//! Zenith Services - Native hardware telemetry, system metrics, Matugen theming, and SVG rendering.

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, OnceLock, RwLock};
use std::time::{Duration, Instant};
use serde_json::Value;

static AUDIO_CACHE: OnceLock<RwLock<(AudioSnapshot, Instant)>> = OnceLock::new();
static MEM_CACHE: OnceLock<RwLock<(MemorySnapshot, Instant)>> = OnceLock::new();
static CPU_PREV: OnceLock<Mutex<(u64, u64, u8, Instant)>> = OnceLock::new();
static THEME_CACHE: OnceLock<RwLock<(ThemePalette, Instant)>> = OnceLock::new();

pub mod hyprland;
pub use hyprland::{ActiveWindowSnapshot, ClientItem, HyprlandService, MonitorItem, WorkspaceItem, WorkspacesSnapshot};

pub mod launcher;
pub use launcher::{AppEntry, LauncherService};

pub mod mpris;
pub use mpris::{MediaSnapshot, MprisService};

pub mod notifications;
pub use notifications::{NotificationItem, NotificationService};

pub mod tray;
pub use tray::{StatusNotifierItemProxy, StatusNotifierWatcherProxy, TrayItem, TrayService};

pub mod cava;
pub use cava::CavaService;

pub mod network;
pub use network::{NetworkService, NetworkStatus, WifiNetwork};

pub mod bluetooth;
pub use bluetooth::{BluetoothDevice, BluetoothService, BluetoothStatus};

pub mod audio;
pub use audio::{AudioDevice, AudioService};

/// Invalidate cached audio snapshot when external PipeWire / WirePlumber events occur.
pub fn invalidate_audio_cache() {
    SystemService::invalidate_audio_cache();
}

/// Invalidate cached theme palette when external Matugen / Stylix events occur.
pub fn invalidate_theme_cache() {
    SystemService::invalidate_theme_cache();
}

pub mod weather;
pub use weather::{WeatherService, WeatherSnapshot};

pub mod recorder;
pub use recorder::RecorderService;

pub mod brightness;
pub use brightness::{BrightnessService, BrightnessSnapshot};

pub mod disk;
pub use disk::{DiskService, DiskSnapshot};

pub mod power;
pub use power::{PowerProfileService, PowerService};

pub mod image;
pub use image::{DecodedImage, ImageService};

pub mod icon;
pub use icon::XdgIconResolver;

pub mod theme_watcher;
pub use theme_watcher::ThemeWatcher;

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
#[derive(Debug, Clone, Default, PartialEq, Eq)]
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
    pub outline_variant: String,
    pub surface_container: String,
    pub surface_container_high: String,
    pub surface_container_highest: String,
    pub surface_container_low: String,
    pub surface_variant: String,
    pub on_surface_variant: String,
    pub secondary: String,
    pub on_secondary: String,
    pub tertiary: String,
    pub on_tertiary: String,
    pub error: String,
    // Base16 / Catppuccin semantic palette
    pub base00: String,
    pub base01: String,
    pub base02: String,
    pub base03: String,
    pub base04: String,
    pub base05: String,
    pub base06: String,
    pub base07: String,
    pub base08: String,
    pub base09: String,
    pub base0a: String,
    pub base0b: String,
    pub base0c: String,
    pub base0d: String,
    pub base0e: String,
    pub base0f: String,
    // Semantic color aliases
    pub red: String,
    pub peach: String,
    pub yellow: String,
    pub green: String,
    pub teal: String,
    pub blue: String,
    pub mauve: String,
    pub lavender: String,
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
            outline_variant: "#475263".to_string(),
            surface_container: "#1e2632".to_string(),
            surface_container_high: "#252f3e".to_string(),
            surface_container_highest: "#2b3647".to_string(),
            surface_container_low: "#151b24".to_string(),
            surface_variant: "#283445".to_string(),
            on_surface_variant: "#98a6b8".to_string(),
            secondary: "#b4befe".to_string(),
            on_secondary: "#11111b".to_string(),
            tertiary: "#f5c2e7".to_string(),
            on_tertiary: "#11111b".to_string(),
            error: "#f38ba8".to_string(),
            base00: "#11111b".to_string(),
            base01: "#181825".to_string(),
            base02: "#313244".to_string(),
            base03: "#45475a".to_string(),
            base04: "#6c7086".to_string(),
            base05: "#cdd6f4".to_string(),
            base06: "#f5e0dc".to_string(),
            base07: "#b4befe".to_string(),
            base08: "#f38ba8".to_string(),
            base09: "#fab387".to_string(),
            base0a: "#f9e2af".to_string(),
            base0b: "#a6e3a1".to_string(),
            base0c: "#94e2d5".to_string(),
            base0d: "#89b4fa".to_string(),
            base0e: "#cba6f7".to_string(),
            base0f: "#f2cdcd".to_string(),
            red: "#f38ba8".to_string(),
            peach: "#fab387".to_string(),
            yellow: "#f9e2af".to_string(),
            green: "#a6e3a1".to_string(),
            teal: "#94e2d5".to_string(),
            blue: "#89b4fa".to_string(),
            mauve: "#cba6f7".to_string(),
            lavender: "#b4befe".to_string(),
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

    /// Get current calendar components: (year, month 1-12, day 1-31, weekday 0-6 where 0=Sun).
    pub fn date_components() -> (i32, i32, i32, i32) {
        unsafe {
            let mut raw_time: libc::time_t = 0;
            libc::time(&mut raw_time);
            let mut tm_buf: libc::tm = std::mem::zeroed();
            libc::localtime_r(&raw_time, &mut tm_buf);
            (
                tm_buf.tm_year + 1900,
                tm_buf.tm_mon + 1,
                tm_buf.tm_mday,
                tm_buf.tm_wday,
            )
        }
    }

    /// Read memory metrics from `/proc/meminfo` with non-blocking 800ms cache.
    pub fn memory_snapshot() -> MemorySnapshot {
        let cache_lock = MEM_CACHE.get_or_init(|| {
            RwLock::new((
                MemorySnapshot::default(),
                Instant::now() - Duration::from_secs(10),
            ))
        });

        if let Ok(guard) = cache_lock.read() {
            if guard.1.elapsed() < Duration::from_millis(800) && guard.0.total_mb > 0 {
                return guard.0.clone();
            }
        }

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

        let snap = MemorySnapshot {
            total_mb,
            used_mb,
            available_mb,
            percent,
        };

        if let Ok(mut guard) = cache_lock.write() {
            *guard = (snap.clone(), Instant::now());
        }

        snap
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

    /// Invalidate cached audio snapshot when external PipeWire / WirePlumber events occur.
    pub fn invalidate_audio_cache() {
        if let Some(cache_lock) = AUDIO_CACHE.get() {
            if let Ok(mut guard) = cache_lock.write() {
                guard.1 = Instant::now() - Duration::from_secs(60);
            }
        }
    }

    /// Atomically mutate cached audio state for 0ms reactive UI feedback.
    pub fn update_audio_cache<F: FnOnce(&mut AudioSnapshot)>(f: F) -> AudioSnapshot {
        let cache_lock = AUDIO_CACHE.get_or_init(|| {
            RwLock::new((
                AudioSnapshot { volume: 75, is_muted: false },
                Instant::now() - Duration::from_secs(10),
            ))
        });
        let mut guard = cache_lock.write().unwrap();
        f(&mut guard.0);
        guard.1 = Instant::now();
        guard.0.clone()
    }

    /// Read audio sink volume and mute state via non-blocking zero-fork cache.
    pub fn audio_snapshot() -> AudioSnapshot {
        let cache_lock = AUDIO_CACHE.get_or_init(|| {
            RwLock::new((
                AudioSnapshot { volume: 75, is_muted: false },
                Instant::now(),
            ))
        });

        match cache_lock.read() {
            Ok(guard) => guard.0.clone(),
            Err(_) => AudioSnapshot { volume: 75, is_muted: false },
        }
    }

    /// Read active network connection status via kernel sysfs (/sys/class/net) without subprocess forks.
    pub fn network_snapshot() -> NetworkSnapshot {
        // Fast kernel sysfs probe: zero forks, sub-10 microseconds
        if let Ok(entries) = fs::read_dir("/sys/class/net") {
            let mut has_ethernet = false;
            let mut has_wifi = false;

            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name == "lo" {
                    continue;
                }
                let oper_file = entry.path().join("operstate");
                if let Ok(state) = fs::read_to_string(oper_file) {
                    if state.trim() == "up" {
                        if name.starts_with("wl") {
                            has_wifi = true;
                        } else if name.starts_with("en") || name.starts_with("eth") {
                            has_ethernet = true;
                        }
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
                let ssid = NetworkService::status().ssid.unwrap_or_else(|| "Wi-Fi".to_string());
                return NetworkSnapshot {
                    is_connected: true,
                    connection_type: "wifi".to_string(),
                    ssid,
                };
            }
        }

        // Fallback to cached NetworkService state
        let net_stat = NetworkService::status();
        NetworkSnapshot {
            is_connected: net_stat.connected,
            connection_type: net_stat.connection_type,
            ssid: net_stat.ssid.unwrap_or_default(),
        }
    }

    /// Read CPU load percentage from `/proc/stat` with 800ms smoothing cache.
    /// Read CPU load percentage from `/proc/stat` with 800ms smoothing cache and fixed-buffer read.
    pub fn cpu_snapshot() -> CpuSnapshot {
        let prev_lock = CPU_PREV.get_or_init(|| Mutex::new((0, 0, 12, Instant::now() - Duration::from_secs(10))));

        if let Ok(mut guard) = prev_lock.lock() {
            let (prev_total, prev_idle, cached_percent, last_time) = *guard;
            if last_time.elapsed() < Duration::from_millis(800) {
                return CpuSnapshot { percent: cached_percent };
            }

            let mut stat_buf = [0u8; 512];
            if let Ok(mut file) = fs::File::open("/proc/stat") {
                use std::io::Read;
                if let Ok(n) = file.read(&mut stat_buf) {
                    let stat = String::from_utf8_lossy(&stat_buf[..n]);
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

                                let mut new_percent = cached_percent;
                                if prev_total > 0 && total > prev_total {
                                    let total_delta = total - prev_total;
                                    let idle_delta = idle.saturating_sub(prev_idle);
                                    let used_delta = total_delta.saturating_sub(idle_delta);
                                    new_percent = (((used_delta as f64 / total_delta as f64) * 100.0).round() as u8).min(100);
                                }
                                *guard = (total, idle, new_percent, Instant::now());
                                return CpuSnapshot { percent: new_percent };
                            }
                        }
                    }
                }
            }
            return CpuSnapshot { percent: cached_percent };
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

    /// Invalidate theme cache.
    pub fn invalidate_theme_cache() {
        if let Some(c) = THEME_CACHE.get() {
            if let Ok(mut guard) = c.write() {
                guard.1 = Instant::now() - Duration::from_secs(100);
            }
        }
    }

    /// Loads active Material You theme colors from Matugen/Stylix cache with 1500ms in-memory cache.
    pub fn load_theme() -> ThemePalette {
        let cache_lock = THEME_CACHE.get_or_init(|| {
            RwLock::new((ThemePalette::default(), Instant::now() - Duration::from_secs(100)))
        });

        if let Ok(guard) = cache_lock.read() {
            if guard.1.elapsed() < Duration::from_millis(15000) {
                return guard.0.clone();
            }
        }

        let xdg_cache = std::env::var("XDG_CACHE_HOME").ok().map(PathBuf::from);
        let xdg_config = std::env::var("XDG_CONFIG_HOME").ok().map(PathBuf::from);
        let candidates = [
            xdg_cache.as_ref().map(|p| p.join("quickshell/matugen/colors.json")),
            xdg_cache.as_ref().map(|p| p.join("matugen/colors.json")),
            xdg_config.as_ref().map(|p| p.join("quickshell/colors.json")),
            dirs_home_path(".cache/quickshell/matugen/colors.json"),
            dirs_home_path(".cache/matugen/colors.json"),
            dirs_home_path(".config/quickshell/colors.json"),
        ];

        let mut loaded = ThemePalette::default();
        for path in candidates.into_iter().flatten() {
            if path.exists() {
                if let Ok(content) = fs::read_to_string(&path) {
                    if let Ok(val) = serde_json::from_str::<Value>(&content) {
                        loaded = Self::parse_matugen_json(&val);
                        break;
                    }
                }
            }
        }

        if let Ok(mut guard) = cache_lock.write() {
            *guard = (loaded.clone(), Instant::now());
        }

        loaded
    }

    fn parse_matugen_json(val: &Value) -> ThemePalette {
        let colors = &val["colors"];
        let base16 = &val["base16"];
        let mut palette = ThemePalette::default();

        let extract_color = |key: &str| -> Option<String> {
            colors[key]["default"]["color"]
                .as_str()
                .or_else(|| colors[key]["dark"]["color"].as_str())
                .map(|s| s.to_string())
        };

        let extract_base16 = |key: &str| -> Option<String> {
            base16[key]["default"]["color"]
                .as_str()
                .or_else(|| base16[key]["dark"]["color"].as_str())
                .map(|s| s.to_string())
        };

        if let Some(c) = extract_color("background") { palette.background = format!("{}F2", c); }
        if let Some(c) = extract_color("primary") { palette.primary = c; }
        if let Some(c) = extract_color("surface") { palette.surface = format!("{}CC", c); }
        if let Some(c) = extract_color("on_surface") { palette.on_surface = c; }
        if let Some(c) = extract_color("on_primary") { palette.on_primary = c; }
        if let Some(c) = extract_color("outline") { palette.outline = c; }
        if let Some(c) = extract_color("outline_variant") { palette.outline_variant = c; }
        if let Some(c) = extract_color("surface_container") { palette.surface_container = c; }
        if let Some(c) = extract_color("surface_container_high") { palette.surface_container_high = c; }
        if let Some(c) = extract_color("surface_container_highest") { palette.surface_container_highest = c; }
        if let Some(c) = extract_color("surface_container_low") { palette.surface_container_low = c; }
        if let Some(c) = extract_color("surface_variant") { palette.surface_variant = c; }
        if let Some(c) = extract_color("on_surface_variant") { palette.on_surface_variant = c; }
        if let Some(c) = extract_color("secondary") { palette.secondary = c; }
        if let Some(c) = extract_color("on_secondary") { palette.on_secondary = c; }
        if let Some(c) = extract_color("tertiary") { palette.tertiary = c; }
        if let Some(c) = extract_color("on_tertiary") { palette.on_tertiary = c; }
        if let Some(c) = extract_color("error") { palette.error = c; }

        // Extract base16 colors if present
        if let Some(c) = extract_base16("base00") { palette.base00 = c; }
        if let Some(c) = extract_base16("base01") { palette.base01 = c; }
        if let Some(c) = extract_base16("base02") { palette.base02 = c; }
        if let Some(c) = extract_base16("base03") { palette.base03 = c; }
        if let Some(c) = extract_base16("base04") { palette.base04 = c; }
        if let Some(c) = extract_base16("base05") { palette.base05 = c; }
        if let Some(c) = extract_base16("base06") { palette.base06 = c; }
        if let Some(c) = extract_base16("base07") { palette.base07 = c.clone(); palette.lavender = c; }
        if let Some(c) = extract_base16("base08") { palette.base08 = c.clone(); palette.red = c; }
        if let Some(c) = extract_base16("base09") { palette.base09 = c.clone(); palette.peach = c; }
        if let Some(c) = extract_base16("base0a") { palette.base0a = c.clone(); palette.yellow = c; }
        if let Some(c) = extract_base16("base0b") { palette.base0b = c.clone(); palette.green = c; }
        if let Some(c) = extract_base16("base0c") { palette.base0c = c.clone(); palette.teal = c; }
        if let Some(c) = extract_base16("base0d") { palette.base0d = c.clone(); palette.blue = c; }
        if let Some(c) = extract_base16("base0e") { palette.base0e = c.clone(); palette.mauve = c; }
        if let Some(c) = extract_base16("base0f") { palette.base0f = c; }

        palette
    }

    /// Rasterize an SVG string into an RGBA pixel buffer at `[width, height]` with in-memory caching.
    pub fn render_svg(svg_str: &str, width: u32, height: u32) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};

        type SvgCacheMap = Arc<RwLock<HashMap<(u64, u32, u32), Vec<u8>>>>;
        static SVG_CACHE: OnceLock<SvgCacheMap> = OnceLock::new();
        let cache = SVG_CACHE.get_or_init(|| Arc::new(RwLock::new(HashMap::new())));

        let mut hasher = DefaultHasher::new();
        svg_str.hash(&mut hasher);
        let key = (hasher.finish(), width, height);

        if let Some(cached) = cache.read().unwrap().get(&key) {
            return Ok(cached.clone());
        }

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
        let buf = pixmap.take();
        cache.write().unwrap().insert(key, buf.clone());
        Ok(buf)
    }

    /// Rasterize an SVG file from disk into an RGBA pixel buffer at `[width, height]`.
    pub fn render_svg_file(path: &Path, width: u32, height: u32) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        let content = fs::read_to_string(path)?;
        Self::render_svg(&content, width, height)
    }
}

fn parse_meminfo_kb(line: &str) -> u64 {
    let mut parts = line.split_whitespace();
    parts.nth(1).and_then(|val| val.parse::<u64>().ok()).unwrap_or(0)
}

fn dirs_home_path(sub: &str) -> Option<PathBuf> {
    std::env::var("HOME").ok().map(|h| PathBuf::from(h).join(sub))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_render_svg_caching() {
        let svg = r#"<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="red"/></svg>"#;
        let buf1 = SystemService::render_svg(svg, 48, 48).expect("Failed to render SVG");
        assert_eq!(buf1.len(), 48 * 48 * 4);

        let buf2 = SystemService::render_svg(svg, 48, 48).expect("Failed to render SVG from cache");
        assert_eq!(buf1, buf2);
    }
}
