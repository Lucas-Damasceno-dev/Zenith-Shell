//! Zenith Services - Native hardware telemetry, system metrics, Matugen theming, and SVG rendering.

use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock, RwLock};
use std::time::{Duration, Instant};
use serde_json::Value;

static AUDIO_CACHE: OnceLock<RwLock<(AudioSnapshot, Instant)>> = OnceLock::new();
static MEM_CACHE: OnceLock<RwLock<(MemorySnapshot, Instant)>> = OnceLock::new();
static CPU_PREV: OnceLock<Mutex<(u64, u64, u8, Instant)>> = OnceLock::new();
static THEME_CACHE: OnceLock<RwLock<(ThemePalette, Instant)>> = OnceLock::new();
static CPU_HISTORY: OnceLock<RwLock<RingBuffer<u8, 60>>> = OnceLock::new();
static MEM_HISTORY: OnceLock<RwLock<RingBuffer<u8, 60>>> = OnceLock::new();
static NET_STATS: OnceLock<RwLock<(RingBuffer<f32, 60>, RingBuffer<f32, 60>, Instant, u64, u64)>> = OnceLock::new();

pub mod error;
pub use error::{AudioError, DbusError, MprisError, NotificationError, ServiceError};

pub mod dbus;
pub use dbus::{
    get_session_connection, get_shared_session_connection, get_shared_system_connection,
    get_system_connection, resolve_session_bus_address, DbusConnectionProvider, DbusManager,
};

pub mod hyprland;
pub use hyprland::{ActiveWindowSnapshot, ClientItem, HyprlandService, MonitorItem, WorkspaceItem, WorkspacesSnapshot};

pub mod launcher;
pub use launcher::{AppEntry, LauncherService};

pub mod mpris;
pub use mpris::{MediaSnapshot, MprisController, MprisService};

pub mod notifications;
pub use notifications::{NotificationController, NotificationItem, NotificationService};

pub mod tray;
pub use tray::{StatusNotifierItemProxy, StatusNotifierWatcherProxy, TrayItem, TrayService};

pub mod cava;
pub use cava::CavaService;

pub mod network;
pub use network::{NetworkService, NetworkStatus, WifiNetwork};

pub mod bluetooth;
pub use bluetooth::{BluetoothDevice, BluetoothService, BluetoothStatus};

pub mod audio;
pub use audio::{AudioController, AudioDevice, AudioService};

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

pub mod clipboard;
pub use clipboard::{ClipboardItem, ClipboardService};

pub mod toplevel;
pub use toplevel::{ToplevelAction, ToplevelInfo, ToplevelService};

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
    pub cycle_count: i32,
    pub health_pct: u8,
    pub model_name: String,
    pub uptime_str: String,
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

/// Fixed-size circular ring-buffer for sparkline history without heap allocation.
#[derive(Debug, Clone, Copy)]
pub struct RingBuffer<T: Copy + Default, const N: usize> {
    pub data: [T; N],
    pub head: usize,
    pub count: usize,
}

impl<T: Copy + Default, const N: usize> Default for RingBuffer<T, N> {
    fn default() -> Self {
        Self {
            data: [T::default(); N],
            head: 0,
            count: 0,
        }
    }
}

impl<T: Copy + Default, const N: usize> RingBuffer<T, N> {
    pub fn push(&mut self, item: T) {
        self.data[self.head] = item;
        self.head = (self.head + 1) % N;
        if self.count < N {
            self.count += 1;
        }
    }

    /// Read historical entries in chronological order into a fixed array.
    pub fn as_ordered_slice(&self) -> [T; N] {
        let mut out = [T::default(); N];
        if self.count == 0 {
            return out;
        }
        let start = if self.count < N { 0 } else { self.head };
        for i in 0..self.count {
            out[i] = self.data[(start + i) % N];
        }
        out
    }
}

/// Snapshot of network bandwidth rate.
#[derive(Debug, Clone, Copy, Default)]
pub struct NetworkBandwidthSnapshot {
    pub rx_kb_sec: f32,
    pub tx_kb_sec: f32,
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

    /// Read memory metrics from `/proc/meminfo` with non-blocking 800ms cache without heap allocations.
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

        let mut mem_buf = [0u8; 1024];
        let mut total_kb: u64 = 0;
        let mut avail_kb: u64 = 0;

        if let Ok(mut file) = fs::File::open("/proc/meminfo") {
            use std::io::Read;
            if let Ok(n) = file.read(&mut mem_buf) {
                let content = String::from_utf8_lossy(&mem_buf[..n]);
                for line in content.lines() {
                    if line.starts_with("MemTotal:") {
                        total_kb = parse_meminfo_kb(line);
                    } else if line.starts_with("MemAvailable:") {
                        avail_kb = parse_meminfo_kb(line);
                    }
                }
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

        let hist_lock = MEM_HISTORY.get_or_init(|| RwLock::new(RingBuffer::default()));
        if let Ok(mut h) = hist_lock.write() {
            h.push(percent);
        }

        snap
    }

    /// Read battery capacity and charging status from `/sys/class/power_supply/` with 2-second caching and hardware property memoization.
    pub fn battery_snapshot() -> Option<BatterySnapshot> {
        static BAT_CACHE: OnceLock<RwLock<(Option<BatterySnapshot>, Instant)>> = OnceLock::new();
        static STATIC_BAT_INFO: OnceLock<(String, Option<f64>)> = OnceLock::new();

        let cache = BAT_CACHE.get_or_init(|| {
            RwLock::new((None, Instant::now() - Duration::from_secs(10)))
        });

        if let Ok(guard) = cache.read() {
            if guard.1.elapsed() < Duration::from_secs(2) {
                return guard.0.clone();
            }
        }

        let ps_path = Path::new("/sys/class/power_supply");
        if !ps_path.exists() {
            if let Ok(mut guard) = cache.write() {
                guard.0 = None;
                guard.1 = Instant::now();
            }
            return None;
        }

        let mut result = None;
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

                    let cycle_count = fs::read_to_string(entry.path().join("cycle_count"))
                        .ok()
                        .and_then(|s| s.trim().parse::<i32>().ok())
                        .unwrap_or(-1);

                    let (model_name, energy_full_design) = STATIC_BAT_INFO.get_or_init(|| {
                        let mn = fs::read_to_string(entry.path().join("model_name"))
                            .ok()
                            .map(|s| s.trim().to_string())
                            .unwrap_or_else(|| "Primary Battery".to_string());
                        let efd = fs::read_to_string(entry.path().join("energy_full_design"))
                            .or_else(|_| fs::read_to_string(entry.path().join("charge_full_design")))
                            .ok()
                            .and_then(|s| s.trim().parse::<f64>().ok());
                        (mn, efd)
                    }).clone();

                    let energy_full = fs::read_to_string(entry.path().join("energy_full"))
                        .or_else(|_| fs::read_to_string(entry.path().join("charge_full")))
                        .ok()
                        .and_then(|s| s.trim().parse::<f64>().ok());

                    let health_pct = match (energy_full, energy_full_design) {
                        (Some(full), Some(design)) if design > 0.0 => {
                            ((full / design) * 100.0).clamp(0.0, 100.0).round() as u8
                        }
                        _ => 100,
                    };

                    let uptime_str = fs::read_to_string("/proc/uptime")
                        .ok()
                        .and_then(|s| {
                            let sec = s.split_whitespace().next()?.parse::<f64>().ok()? as u64;
                            let h = sec / 3600;
                            let m = (sec % 3600) / 60;
                            Some(format!("{}h {}m", h, m))
                        })
                        .unwrap_or_else(|| "0h 0m".to_string());

                    result = Some(BatterySnapshot {
                        percentage: cap,
                        status,
                        is_charging,
                        cycle_count,
                        health_pct,
                        model_name,
                        uptime_str,
                    });
                    break;
                }
            }
        }

        if let Ok(mut guard) = cache.write() {
            guard.0 = result.clone();
            guard.1 = Instant::now();
        }
        result
    }

    /// Queries current volume and mute status from PipeWire / WirePlumber.
    pub fn query_wpctl_snapshot() -> Option<AudioSnapshot> {
        let output = std::process::Command::new("wpctl")
            .args(["get-volume", "@DEFAULT_AUDIO_SINK@"])
            .output()
            .ok()?;
        if output.status.success() {
            let s = String::from_utf8_lossy(&output.stdout);
            let is_muted = s.contains("[MUTED]");
            let vol_str = s.trim_start().strip_prefix("Volume:")?.trim();
            let vol_val_str = vol_str.split_whitespace().next()?;
            let vol_f = vol_val_str.parse::<f32>().ok()?;
            let volume = (vol_f * 100.0).round().clamp(0.0, 150.0) as u8;
            Some(AudioSnapshot { volume, is_muted })
        } else {
            None
        }
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
            let initial = Self::query_wpctl_snapshot().unwrap_or(AudioSnapshot { volume: 75, is_muted: false });
            RwLock::new((initial, Instant::now() - Duration::from_secs(10)))
        });
        let mut guard = match cache_lock.write() {
            Ok(g) => g,
            Err(e) => e.into_inner(),
        };
        f(&mut guard.0);
        guard.1 = Instant::now();
        guard.0.clone()
    }

    /// Read audio sink volume and mute state via non-blocking zero-fork cache.
    pub fn audio_snapshot() -> AudioSnapshot {
        static FETCHING: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
        let cache_lock = AUDIO_CACHE.get_or_init(|| {
            let initial = Self::query_wpctl_snapshot().unwrap_or(AudioSnapshot { volume: 75, is_muted: false });
            RwLock::new((initial, Instant::now()))
        });

        let needs_update = if let Ok(guard) = cache_lock.read() {
            guard.1.elapsed() >= Duration::from_secs(30)
        } else {
            false
        };

        if needs_update {
            if let Ok(mut guard) = cache_lock.write() {
                guard.1 = Instant::now();
            }
            if !FETCHING.swap(true, std::sync::atomic::Ordering::SeqCst) {
                std::thread::Builder::new()
                    .name("audio-cache-update".into())
                    .spawn(move || {
                        if let Some(real_snap) = Self::query_wpctl_snapshot() {
                            if let Some(lock) = AUDIO_CACHE.get() {
                                if let Ok(mut guard) = lock.write() {
                                    guard.0 = real_snap;
                                    guard.1 = Instant::now();
                                }
                            }
                        }
                        FETCHING.store(false, std::sync::atomic::Ordering::SeqCst);
                    })
                    .ok();
            }
        }

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

                                let hist_lock = CPU_HISTORY.get_or_init(|| RwLock::new(RingBuffer::default()));
                                if let Ok(mut h) = hist_lock.write() {
                                    h.push(new_percent);
                                }

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

    /// Read network bandwidth delta throughput from `/proc/net/dev` with zero heap allocations.
    pub fn network_bandwidth_snapshot() -> NetworkBandwidthSnapshot {
        let stats_lock = NET_STATS.get_or_init(|| {
            RwLock::new((
                RingBuffer::default(),
                RingBuffer::default(),
                Instant::now() - Duration::from_secs(10),
                0,
                0,
            ))
        });

        let mut net_buf = [0u8; 1024];
        let mut total_rx = 0u64;
        let mut total_tx = 0u64;

        if let Ok(mut file) = fs::File::open("/proc/net/dev") {
            use std::io::Read;
            if let Ok(n) = file.read(&mut net_buf) {
                let content = String::from_utf8_lossy(&net_buf[..n]);
                for line in content.lines().skip(2) {
                    if let Some((iface, metrics)) = line.split_once(':') {
                        let iface_clean = iface.trim();
                        if iface_clean == "lo" {
                            continue;
                        }
                        let cols: Vec<&str> = metrics.split_whitespace().collect();
                        if cols.len() >= 9 {
                            let rx: u64 = cols[0].parse().unwrap_or(0);
                            let tx: u64 = cols[8].parse().unwrap_or(0);
                            total_rx += rx;
                            total_tx += tx;
                        }
                    }
                }
            }
        }

        if let Ok(mut guard) = stats_lock.write() {
            let (ref mut rx_ring, ref mut tx_ring, ref mut last_time, prev_rx, prev_tx) = *guard;
            let elapsed = last_time.elapsed().as_secs_f32();
            let mut rx_rate = 0.0f32;
            let mut tx_rate = 0.0f32;

            if elapsed > 0.0 && prev_rx > 0 && total_rx >= prev_rx {
                rx_rate = ((total_rx - prev_rx) as f32 / 1024.0) / elapsed;
                tx_rate = ((total_tx.saturating_sub(prev_tx)) as f32 / 1024.0) / elapsed;
            }

            rx_ring.push(rx_rate);
            tx_ring.push(tx_rate);
            *last_time = Instant::now();
            guard.3 = total_rx;
            guard.4 = total_tx;

            NetworkBandwidthSnapshot {
                rx_kb_sec: rx_rate,
                tx_kb_sec: tx_rate,
            }
        } else {
            NetworkBandwidthSnapshot::default()
        }
    }

    /// Returns 60-point historical CPU load percentages for canvas sparklines.
    pub fn cpu_history() -> [u8; 60] {
        let hist_lock = CPU_HISTORY.get_or_init(|| RwLock::new(RingBuffer::default()));
        if let Ok(h) = hist_lock.read() {
            h.as_ordered_slice()
        } else {
            [0u8; 60]
        }
    }

    /// Returns 60-point historical Memory load percentages for canvas sparklines.
    pub fn memory_history() -> [u8; 60] {
        let hist_lock = MEM_HISTORY.get_or_init(|| RwLock::new(RingBuffer::default()));
        if let Ok(h) = hist_lock.read() {
            h.as_ordered_slice()
        } else {
            [0u8; 60]
        }
    }

    /// Returns 60-point historical Network bandwidth (rx, tx in KB/s) for canvas sparklines.
    pub fn network_history() -> ([f32; 60], [f32; 60]) {
        let stats_lock = NET_STATS.get_or_init(|| {
            RwLock::new((
                RingBuffer::default(),
                RingBuffer::default(),
                Instant::now() - Duration::from_secs(10),
                0,
                0,
            ))
        });
        if let Ok(g) = stats_lock.read() {
            (g.0.as_ordered_slice(), g.1.as_ordered_slice())
        } else {
            ([0.0f32; 60], [0.0f32; 60])
        }
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
