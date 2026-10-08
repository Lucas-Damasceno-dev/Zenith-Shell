//! Desktop Notifications Daemon (org.freedesktop.Notifications).
//!
//! Captures and manages system toast notifications streamed from the user
//! D-Bus session bus, supporting `notify-send` and desktop applications.

use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, OnceLock, RwLock};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tracing::warn;

/// Structured representation of a desktop notification toast.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, PartialEq, Eq)]
pub struct NotificationItem {
    pub id: u32,
    pub app_name: String,
    pub app_icon: String,
    pub summary: String,
    pub body: String,
    pub actions: Vec<String>,
    pub urgency: u8, // 0 = low, 1 = normal, 2 = critical
    pub timestamp_secs: u64,
    pub expire_timeout_ms: i32,
}

struct NotificationState {
    next_id: u32,
    active: Vec<NotificationItem>,
    history: Vec<NotificationItem>,
}

static STATE: OnceLock<Arc<RwLock<NotificationState>>> = OnceLock::new();
static CHANGE_LISTENER: OnceLock<Arc<dyn Fn() + Send + Sync>> = OnceLock::new();
static DND_ENABLED: AtomicBool = AtomicBool::new(false);

/// Service provider for desktop notifications.
pub struct NotificationService;

impl NotificationService {
    /// Retrieve all active notifications.
    pub fn list_active() -> Vec<NotificationItem> {
        let state = Self::get_state();
        let r = state.read().unwrap();
        r.active.clone()
    }

    /// Retrieve all historical notifications.
    pub fn list_history() -> Vec<NotificationItem> {
        let state = Self::get_state();
        let r = state.read().unwrap();
        r.history.clone()
    }

    /// Whether Do Not Disturb (DND) mode is active.
    pub fn is_dnd() -> bool {
        DND_ENABLED.load(Ordering::SeqCst)
    }

    /// Toggle Do Not Disturb (DND) mode.
    pub fn toggle_dnd() -> bool {
        let old = DND_ENABLED.fetch_xor(true, Ordering::SeqCst);
        let new_state = !old;
        Self::notify_change();
        new_state
    }

    /// Set Do Not Disturb (DND) mode.
    pub fn set_dnd(enabled: bool) {
        DND_ENABLED.store(enabled, Ordering::SeqCst);
        Self::notify_change();
    }

    /// Retrieve count of active notifications.
    pub fn count() -> usize {
        let state = Self::get_state();
        let r = state.read().unwrap();
        r.active.len()
    }

    /// Create or insert a notification programmatically.
    #[allow(clippy::too_many_arguments)]
    pub fn notify(
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        urgency: u8,
        expire_timeout_ms: i32,
    ) -> u32 {
        let state = Self::get_state();
        let mut w = state.write().unwrap();

        let id = if replaces_id > 0 {
            replaces_id
        } else {
            let next = w.next_id;
            w.next_id += 1;
            next
        };

        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        let item = NotificationItem {
            id,
            app_name: if app_name.is_empty() { "System".to_string() } else { app_name },
            app_icon,
            summary,
            body,
            actions,
            urgency,
            timestamp_secs: now,
            expire_timeout_ms,
        };

        let is_dnd = Self::is_dnd();
        if is_dnd && urgency < 2 {
            // Under DND, silence non-critical notifications into history only
            w.history.insert(0, item);
            if w.history.len() > 50 {
                w.history.truncate(50);
            }
            drop(w);
            Self::notify_change();
            return id;
        }

        // If replacing an existing item, update it in place
        if let Some(pos) = w.active.iter().position(|n| n.id == id) {
            w.active[pos] = item.clone();
        } else {
            w.active.insert(0, item.clone());
            // Keep active limit reasonable (up to 15 toasts)
            if w.active.len() > 15 {
                let dropped = w.active.pop().unwrap();
                w.history.insert(0, dropped);
            }
        }

        w.history.insert(0, item);
        if w.history.len() > 50 {
            w.history.truncate(50);
        }

        drop(w);
        Self::notify_change();
        id
    }

    /// Close a notification by id.
    pub fn close(id: u32) {
        let state = Self::get_state();
        let mut w = state.write().unwrap();
        if let Some(pos) = w.active.iter().position(|n| n.id == id) {
            let removed = w.active.remove(pos);
            w.history.insert(0, removed);
        }
        drop(w);
        Self::notify_change();
    }

    /// Dismiss/clear all active notifications.
    pub fn clear_all() {
        let state = Self::get_state();
        let mut w = state.write().unwrap();
        let mut drained = w.active.drain(..).collect::<Vec<_>>();
        w.history.append(&mut drained);
        drop(w);
        Self::notify_change();
    }

    /// Clear all historical notifications.
    pub fn clear_history() {
        let state = Self::get_state();
        let mut w = state.write().unwrap();
        w.history.clear();
        drop(w);
        Self::notify_change();
    }

    /// Register change notification listener.
    pub fn set_change_listener<F>(callback: F)
    where
        F: Fn() + Send + Sync + 'static,
    {
        let _ = CHANGE_LISTENER.set(Arc::new(callback));
    }

    fn notify_change() {
        if let Some(cb) = CHANGE_LISTENER.get() {
            cb();
        }
    }

    fn get_state() -> &'static Arc<RwLock<NotificationState>> {
        STATE.get_or_init(|| {
            let state = Arc::new(RwLock::new(NotificationState {
                next_id: 1,
                active: Vec::new(),
                history: Vec::new(),
            }));

            // Spawn D-Bus background listener thread
            Self::spawn_bus_monitor(state.clone());

            state
        })
    }

    fn resolve_dbus_address_arg() -> Option<String> {
        if let Ok(addr) = std::env::var("DBUS_SESSION_BUS_ADDRESS") {
            if !addr.is_empty() && addr != "disabled" {
                return Some(format!("--address={}", addr));
            }
        }

        if let Ok(xdg) = std::env::var("XDG_RUNTIME_DIR") {
            let p = PathBuf::from(xdg).join("bus");
            if p.exists() {
                return Some(format!("--address=unix:path={}", p.display()));
            }
        }

        let uid = unsafe { libc::getuid() };
        let direct_sock = format!("/run/user/{}/bus", uid);
        if std::path::Path::new(&direct_sock).exists() {
            return Some(format!("--address=unix:path={}", direct_sock));
        }

        None
    }

    fn spawn_bus_monitor(state: Arc<RwLock<NotificationState>>) {
        std::thread::spawn(move || {
            loop {
                let mut cmd = std::process::Command::new("busctl");
                if let Some(addr) = Self::resolve_dbus_address_arg() {
                    cmd.arg(addr);
                } else {
                    cmd.arg("--user");
                }

                cmd.args([
                    "monitor",
                    "--json=short",
                    "--match=interface='org.freedesktop.Notifications',member='Notify'",
                ]);

                cmd.stdout(std::process::Stdio::piped());
                cmd.stderr(std::process::Stdio::null());

                let mut child = match cmd.spawn() {
                    Ok(c) => c,
                    Err(e) => {
                        warn!("Failed to spawn busctl notification monitor: {}. Retrying in 5s.", e);
                        std::thread::sleep(Duration::from_secs(5));
                        continue;
                    }
                };

                if let Some(stdout) = child.stdout.take() {
                    let reader = BufReader::new(stdout);
                    for line_res in reader.lines() {
                        let line = match line_res {
                            Ok(l) => l,
                            Err(_) => break,
                        };

                        if line.trim().is_empty() {
                            continue;
                        }

                        if let Some(item) = Self::parse_notification_json(&line) {
                            let mut w = state.write().unwrap();
                            let id = if item.id > 0 {
                                item.id
                            } else {
                                let next = w.next_id;
                                w.next_id += 1;
                                next
                            };

                            let mut final_item = item;
                            final_item.id = id;

                            w.active.insert(0, final_item.clone());
                            if w.active.len() > 15 {
                                w.active.pop();
                            }
                            w.history.insert(0, final_item);
                            if w.history.len() > 50 {
                                w.history.truncate(50);
                            }
                            drop(w);

                            Self::notify_change();
                        }
                    }
                }

                let _ = child.wait();
                std::thread::sleep(Duration::from_secs(2));
            }
        });
    }

    /// Parse a single JSON line emitted by `busctl monitor --json=short`.
    pub fn parse_notification_json(json_str: &str) -> Option<NotificationItem> {
        let val = serde_json::from_str::<serde_json::Value>(json_str).ok()?;

        let member = val["member"].as_str().unwrap_or("");
        if member != "Notify" {
            return None;
        }

        let payload_data = val["payload"]["data"].as_array()?;
        if payload_data.len() < 8 {
            return None;
        }

        let app_name = payload_data[0].as_str().unwrap_or("System").to_string();
        let replaces_id = payload_data[1].as_u64().unwrap_or(0) as u32;
        let mut app_icon = payload_data[2].as_str().unwrap_or("").to_string();
        let summary = payload_data[3].as_str().unwrap_or("").to_string();
        let body = payload_data[4].as_str().unwrap_or("").to_string();

        let mut actions = Vec::new();
        if let Some(arr) = payload_data[5].as_array() {
            for a in arr {
                if let Some(s) = a.as_str() {
                    actions.push(s.to_string());
                }
            }
        }

        let mut urgency = 1u8;
        if let Some(hints) = payload_data[6].as_object() {
            if let Some(u_val) = hints.get("urgency").and_then(|v| v["data"].as_u64()) {
                urgency = (u_val as u8).min(2);
            }
            if app_icon.is_empty() {
                if let Some(icon_path) = hints.get("image-path").and_then(|v| v["data"].as_str()) {
                    app_icon = icon_path.to_string();
                }
            }
        }

        let expire_timeout_ms = payload_data[7].as_i64().unwrap_or(-1) as i32;

        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        Some(NotificationItem {
            id: replaces_id,
            app_name,
            app_icon,
            summary,
            body,
            actions,
            urgency,
            timestamp_secs: now,
            expire_timeout_ms,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_notification_json() {
        let sample = r#"{
            "type": "method_call",
            "member": "Notify",
            "payload": {
                "type": "susssasa{sv}i",
                "data": [
                    "Brave",
                    0,
                    "brave-browser",
                    "New Email Received",
                    "You have 1 new message in your inbox.",
                    ["view", "View Message"],
                    {
                        "urgency": { "type": "y", "data": 2 },
                        "image-path": { "type": "s", "data": "mail-unread" }
                    },
                    5000
                ]
            }
        }"#;

        let item = NotificationService::parse_notification_json(sample)
            .expect("Should parse notification JSON");

        assert_eq!(item.app_name, "Brave");
        assert_eq!(item.summary, "New Email Received");
        assert_eq!(item.body, "You have 1 new message in your inbox.");
        assert_eq!(item.app_icon, "brave-browser");
        assert_eq!(item.urgency, 2);
        assert_eq!(item.actions, vec!["view", "View Message"]);
        assert_eq!(item.expire_timeout_ms, 5000);
    }

    #[test]
    fn test_in_memory_queue() {
        let id1 = NotificationService::notify(
            "TestApp".into(),
            0,
            "".into(),
            "Title 1".into(),
            "Body 1".into(),
            vec![],
            1,
            3000,
        );

        assert!(id1 > 0);
        let items = NotificationService::list_active();
        assert!(items.iter().any(|n| n.id == id1 && n.summary == "Title 1"));

        NotificationService::close(id1);
        let items_after = NotificationService::list_active();
        assert!(!items_after.iter().any(|n| n.id == id1));
    }
}
