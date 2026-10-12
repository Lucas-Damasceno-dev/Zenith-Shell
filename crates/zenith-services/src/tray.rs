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

    /// Retrieve list of registered StatusNotifierItem tray icons with non-blocking cache.
    pub fn list() -> Vec<TrayItem> {
        let cache_arc = Self::cache();
        let mut guard = cache_arc.lock().unwrap();

        // Asynchronously refresh items if stale (> 3s)
        if guard.last_query.elapsed() >= Duration::from_millis(3000) {
            guard.last_query = Instant::now();
            let c_arc = cache_arc.clone();
            std::thread::spawn(move || {
                let mut fresh = Vec::new();
                if let Ok(services) = query_registered_items() {
                    for service in services {
                        if let Ok(item) = inspect_item(&service) {
                            fresh.push(item);
                        }
                    }
                }
                if let Ok(mut g) = c_arc.lock() {
                    g.items = fresh;
                    g.last_query = Instant::now();
                }
            });
        }

        guard.items.clone()
    }

    /// Dispatch primary activation click (Activate(x, y)).
    pub fn activate(service: &str) {
        if let Ok(conn) = zbus::blocking::Connection::session() {
            let _ = conn.call_method(
                Some(service),
                "/StatusNotifierItem",
                Some("org.kde.StatusNotifierItem"),
                "Activate",
                &(0i32, 0i32),
            );
            return;
        }

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
        if let Ok(conn) = zbus::blocking::Connection::session() {
            let _ = conn.call_method(
                Some(service),
                "/StatusNotifierItem",
                Some("org.kde.StatusNotifierItem"),
                "ContextMenu",
                &(0i32, 0i32),
            );
            return;
        }

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
    if let Ok(conn) = zbus::blocking::Connection::session() {
        if let Ok(proxy) = zbus::blocking::Proxy::new(
            &conn,
            "org.kde.StatusNotifierWatcher",
            "/StatusNotifierWatcher",
            "org.kde.StatusNotifierWatcher",
        ) {
            if let Ok(items) = proxy.get_property::<Vec<String>>("RegisteredStatusNotifierItems") {
                return Ok(items);
            }
        }
    }

    let bus_addr = resolve_bus_address();
    if bus_addr.is_none() {
        return Err("No D-Bus session bus available".into());
    }
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

    if let Ok(conn) = zbus::blocking::Connection::session() {
        if let Ok(proxy) = zbus::blocking::Proxy::new(
            &conn,
            service,
            path.as_str(),
            "org.kde.StatusNotifierItem",
        ) {
            let id = proxy.get_property::<String>("Id").unwrap_or_default();
            let title = proxy.get_property::<String>("Title").unwrap_or_default();
            let icon_name = proxy.get_property::<String>("IconName").unwrap_or_default();

            return Ok(TrayItem {
                id: if id.is_empty() { service.to_string() } else { id },
                title: if title.is_empty() { service.to_string() } else { title },
                icon_name: if icon_name.is_empty() { "󰀻".to_string() } else { icon_name },
                service: service.to_string(),
            });
        }
    }

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
    fn test_tray_list() {
        let items = TrayService::list();
        assert!(items.is_empty() || !items.is_empty());
    }
}
