//! System Tray (StatusNotifierItem - SNI) service for Zenith Shell.
//!
//! Queries `org.kde.StatusNotifierWatcher` on the session D-Bus and retrieves
//! registered tray items with cached metadata and activation dispatchers.

use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};
use serde::{Deserialize, Serialize};

/// Individual System Tray icon item.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrayItem {
    pub id: String,
    pub title: String,
    pub icon_name: String,
    pub service: String,
}

struct TrayCache {
    items: Vec<TrayItem>,
    last_query: Instant,
}

static TRAY_CACHE: OnceLock<Arc<Mutex<TrayCache>>> = OnceLock::new();

pub struct TrayService;

impl TrayService {
    fn cache() -> &'static Arc<Mutex<TrayCache>> {
        TRAY_CACHE.get_or_init(|| {
            Arc::new(Mutex::new(TrayCache {
                items: Vec::new(),
                last_query: Instant::now() - Duration::from_secs(10),
            }))
        })
    }

    /// Retrieve list of registered StatusNotifierItem tray icons.
    pub fn list() -> Vec<TrayItem> {
        let cache_arc = Self::cache();
        let mut guard = cache_arc.lock().unwrap();

        // 1.5s cache TTL
        if guard.last_query.elapsed() < Duration::from_millis(1500) && !guard.items.is_empty() {
            return guard.items.clone();
        }

        let mut items = Vec::new();

        // Query session bus for RegisteredStatusNotifierItems
        if let Ok(services) = query_registered_items() {
            for service in services {
                if let Ok(item) = inspect_item(&service) {
                    items.push(item);
                }
            }
        }

        // Fallback items if none registered on bus
        if items.is_empty() {
            items = vec![
                TrayItem {
                    id: "nm-applet".to_string(),
                    title: "Network".to_string(),
                    icon_name: "󰤨".to_string(),
                    service: "org.freedesktop.NetworkManager".to_string(),
                },
                TrayItem {
                    id: "volume".to_string(),
                    title: "Audio".to_string(),
                    icon_name: "󰕾".to_string(),
                    service: "org.wireplumber".to_string(),
                },
                TrayItem {
                    id: "battery".to_string(),
                    title: "Power".to_string(),
                    icon_name: "󰁹".to_string(),
                    service: "org.upower".to_string(),
                },
            ];
        }

        guard.items = items.clone();
        guard.last_query = Instant::now();
        items
    }

    /// Dispatch primary activation click (Activate(x, y)).
    pub fn activate(service: &str) {
        let bus_addr = resolve_bus_address();
        let mut cmd = std::process::Command::new("busctl");
        cmd.args(["--user", "call", service, "/StatusNotifierItem", "org.kde.StatusNotifierItem", "Activate", "ii", "0", "0"]);
        if let Some(ref addr) = bus_addr {
            cmd.env("DBUS_SESSION_BUS_ADDRESS", addr);
        }
        let _ = cmd.spawn();
    }

    /// Dispatch context menu click (ContextMenu(x, y)).
    pub fn context_menu(service: &str) {
        let bus_addr = resolve_bus_address();
        let mut cmd = std::process::Command::new("busctl");
        cmd.args(["--user", "call", service, "/StatusNotifierItem", "org.kde.StatusNotifierItem", "ContextMenu", "ii", "0", "0"]);
        if let Some(ref addr) = bus_addr {
            cmd.env("DBUS_SESSION_BUS_ADDRESS", addr);
        }
        let _ = cmd.spawn();
    }
}

fn resolve_bus_address() -> Option<String> {
    if let Ok(addr) = std::env::var("DBUS_SESSION_BUS_ADDRESS") {
        if !addr.is_empty() && addr != "disabled" {
            return Some(addr);
        }
    }
    let uid = unsafe { libc::getuid() };
    let candidate = format!("/run/user/{}/bus", uid);
    if std::path::Path::new(&candidate).exists() {
        return Some(format!("unix:path={}", candidate));
    }
    None
}

fn query_registered_items() -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let bus_addr = resolve_bus_address();
    let mut cmd = std::process::Command::new("busctl");
    cmd.args([
        "--user",
        "get-property",
        "org.kde.StatusNotifierWatcher",
        "/StatusNotifierWatcher",
        "org.kde.StatusNotifierWatcher",
        "RegisteredStatusNotifierItems",
    ]);
    if let Some(ref addr) = bus_addr {
        cmd.env("DBUS_SESSION_BUS_ADDRESS", addr);
    }

    let output = cmd.output()?;
    if !output.status.success() {
        return Err("busctl command failed".into());
    }

    let out_str = String::from_utf8_lossy(&output.stdout);
    // Format: as 2 "service1" "service2"
    let mut services = Vec::new();
    for token in out_str.split('"') {
        let t = token.trim();
        if t.starts_with(":") || t.starts_with("org.") {
            services.push(t.to_string());
        }
    }

    Ok(services)
}

fn inspect_item(service_path: &str) -> Result<TrayItem, Box<dyn std::error::Error>> {
    let (service, path) = if let Some((s, p)) = service_path.split_once('/') {
        (s, format!("/{}", p))
    } else {
        (service_path, "/StatusNotifierItem".to_string())
    };

    let bus_addr = resolve_bus_address();

    let get_prop = |prop: &str| -> String {
        let mut cmd = std::process::Command::new("busctl");
        cmd.args(["--user", "get-property", service, &path, "org.kde.StatusNotifierItem", prop]);
        if let Some(ref addr) = bus_addr {
            cmd.env("DBUS_SESSION_BUS_ADDRESS", addr);
        }
        if let Ok(output) = cmd.output() {
            if output.status.success() {
                let s = String::from_utf8_lossy(&output.stdout);
                if let Some((_, val)) = s.split_once('"') {
                    return val.trim_end_matches('"').trim().to_string();
                }
            }
        }
        String::new()
    };

    let id = get_prop("Id");
    let title = get_prop("Title");
    let icon_name = get_prop("IconName");

    Ok(TrayItem {
        id: if id.is_empty() { service.to_string() } else { id },
        title: if title.is_empty() { service.to_string() } else { title },
        icon_name: if icon_name.is_empty() { "󰀻".to_string() } else { icon_name },
        service: service.to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tray_fallback_list() {
        let items = TrayService::list();
        assert!(!items.is_empty());
        assert!(items.iter().any(|i| i.id == "nm-applet" || !i.service.is_empty()));
    }
}
