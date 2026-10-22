//! Desktop Notifications Daemon (org.freedesktop.Notifications).
//!
//! Captures and manages system toast notifications streamed from the user
//! D-Bus session bus, supporting `notify-send` and desktop applications.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, OnceLock, RwLock};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use crate::error::NotificationError;

/// Contract for desktop notification management.
pub trait NotificationController: Send + Sync {
    /// Retrieve all active desktop notifications.
    fn list_active(&self) -> Result<Vec<NotificationItem>, NotificationError>;

    /// Retrieve all historical notifications.
    fn list_history(&self) -> Result<Vec<NotificationItem>, NotificationError>;

    /// Retrieve count of active notifications.
    fn count(&self) -> Result<usize, NotificationError>;

    /// Create or insert a notification programmatically.
    #[allow(clippy::too_many_arguments)]
    fn notify(
        &self,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        urgency: u8,
        expire_timeout_ms: i32,
    ) -> Result<u32, NotificationError>;

    /// Close notification by ID.
    fn close(&self, id: u32) -> Result<(), NotificationError>;

    /// Dismiss all active notifications.
    fn clear_all(&self) -> Result<(), NotificationError>;

    /// Clear all historical notifications.
    fn clear_history(&self) -> Result<(), NotificationError>;
}

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
    /// Retrieve all active notifications with explicit error handling and automatic expiration cleanup.
    pub fn try_list_active() -> Result<Vec<NotificationItem>, NotificationError> {
        let state = Self::get_state();
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        {
            let mut w = state.write().map_err(|e| NotificationError::LockPoisoned(e.to_string()))?;
            let before = w.active.len();
            w.active.retain(|item| {
                if item.expire_timeout_ms > 0 {
                    let expire_secs = (item.expire_timeout_ms as u64 + 999) / 1000;
                    if now >= item.timestamp_secs + expire_secs {
                        return false;
                    }
                }
                true
            });
            if w.active.len() != before {
                drop(w);
                Self::notify_change();
                let r = state.read().map_err(|e| NotificationError::LockPoisoned(e.to_string()))?;
                return Ok(r.active.clone());
            }
        }
        let r = state.read().map_err(|e| NotificationError::LockPoisoned(e.to_string()))?;
        Ok(r.active.clone())
    }

    /// Retrieve all active notifications.
    pub fn list_active() -> Vec<NotificationItem> {
        Self::try_list_active().unwrap_or_default()
    }

    /// Retrieve all historical notifications with explicit error handling.
    pub fn try_list_history() -> Result<Vec<NotificationItem>, NotificationError> {
        let state = Self::get_state();
        let r = state.read().map_err(|e| NotificationError::LockPoisoned(e.to_string()))?;
        Ok(r.history.clone())
    }

    /// Retrieve all historical notifications.
    pub fn list_history() -> Vec<NotificationItem> {
        Self::try_list_history().unwrap_or_default()
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

    /// Retrieve count of active notifications with explicit error handling.
    pub fn try_count() -> Result<usize, NotificationError> {
        let state = Self::get_state();
        let r = state.read().map_err(|e| NotificationError::LockPoisoned(e.to_string()))?;
        Ok(r.active.len())
    }

    /// Retrieve count of active notifications.
    pub fn count() -> usize {
        Self::try_count().unwrap_or(0)
    }

    /// Create or insert a notification programmatically with explicit error handling.
    #[allow(clippy::too_many_arguments)]
    pub fn try_notify(
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        urgency: u8,
        expire_timeout_ms: i32,
    ) -> Result<u32, NotificationError> {
        let state = Self::get_state();
        let mut w = state.write().map_err(|e| NotificationError::LockPoisoned(e.to_string()))?;

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
            return Ok(id);
        }

        // If replacing an existing item, update it in place
        if let Some(pos) = w.active.iter().position(|n| n.id == id) {
            w.active[pos] = item.clone();
        } else {
            w.active.insert(0, item.clone());
            // Keep active limit reasonable (up to 15 toasts)
            if w.active.len() > 15 {
                if let Some(dropped) = w.active.pop() {
                    w.history.insert(0, dropped);
                }
            }
        }

        w.history.insert(0, item);
        if w.history.len() > 50 {
            w.history.truncate(50);
        }

        drop(w);
        Self::notify_change();

        if expire_timeout_ms > 0 {
            let timeout = Duration::from_millis(expire_timeout_ms as u64);
            std::thread::Builder::new()
                .name("zenith-notif-expire".into())
                .spawn(move || {
                    std::thread::sleep(timeout);
                    let state = Self::get_state();
                    if let Ok(mut w) = state.write() {
                        let before = w.active.len();
                        w.active.retain(|n| n.id != id);
                        if w.active.len() != before {
                            drop(w);
                            Self::notify_change();
                        }
                    }
                })
                .ok();
        }

        Ok(id)
    }

    /// Create or insert a notification programmatically.
    // Preserves the D-Bus freedesktop notifications parameter mapping and public API compatibility.
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
        Self::try_notify(
            app_name,
            replaces_id,
            app_icon,
            summary,
            body,
            actions,
            urgency,
            expire_timeout_ms,
        ).unwrap_or(0)
    }

    /// Close a notification by id with explicit error handling.
    pub fn try_close(id: u32) -> Result<(), NotificationError> {
        let state = Self::get_state();
        let mut w = state.write().map_err(|e| NotificationError::LockPoisoned(e.to_string()))?;
        if let Some(pos) = w.active.iter().position(|n| n.id == id) {
            let removed = w.active.remove(pos);
            w.history.insert(0, removed);
        }
        drop(w);
        Self::notify_change();
        Ok(())
    }

    /// Close a notification by id.
    pub fn close(id: u32) {
        let _ = Self::try_close(id);
    }

    /// Dismiss/clear all active notifications with explicit error handling.
    pub fn try_clear_all() -> Result<(), NotificationError> {
        let state = Self::get_state();
        let mut w = state.write().map_err(|e| NotificationError::LockPoisoned(e.to_string()))?;
        let mut drained = w.active.drain(..).collect::<Vec<_>>();
        w.history.append(&mut drained);
        drop(w);
        Self::notify_change();
        Ok(())
    }

    /// Dismiss/clear all active notifications.
    pub fn clear_all() {
        let _ = Self::try_clear_all();
    }

    /// Clear all historical notifications with explicit error handling.
    pub fn try_clear_history() -> Result<(), NotificationError> {
        let state = Self::get_state();
        let mut w = state.write().map_err(|e| NotificationError::LockPoisoned(e.to_string()))?;
        w.history.clear();
        drop(w);
        Self::notify_change();
        Ok(())
    }

    /// Clear all historical notifications.
    pub fn clear_history() {
        let _ = Self::try_clear_history();
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

    #[allow(dead_code)]
    fn resolve_dbus_address_arg() -> Option<String> {
        crate::dbus::resolve_session_bus_address()
    }
}

impl NotificationController for NotificationService {
    fn list_active(&self) -> Result<Vec<NotificationItem>, NotificationError> {
        Self::try_list_active()
    }

    fn list_history(&self) -> Result<Vec<NotificationItem>, NotificationError> {
        Self::try_list_history()
    }

    fn count(&self) -> Result<usize, NotificationError> {
        Self::try_count()
    }

    fn notify(
        &self,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        urgency: u8,
        expire_timeout_ms: i32,
    ) -> Result<u32, NotificationError> {
        Self::try_notify(
            app_name,
            replaces_id,
            app_icon,
            summary,
            body,
            actions,
            urgency,
            expire_timeout_ms,
        )
    }

    fn close(&self, id: u32) -> Result<(), NotificationError> {
        Self::try_close(id)
    }

    fn clear_all(&self) -> Result<(), NotificationError> {
        Self::try_clear_all()
    }

    fn clear_history(&self) -> Result<(), NotificationError> {
        Self::try_clear_history()
    }
}

struct NotificationServer {
    state: Arc<RwLock<NotificationState>>,
}

#[zbus::interface(name = "org.freedesktop.Notifications")]
impl NotificationServer {
    // D-Bus org.freedesktop.Notifications.Notify specification requires 8 arguments.
    #[allow(clippy::too_many_arguments)]
    fn notify(
        &mut self,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        _hints: std::collections::HashMap<String, zbus::zvariant::OwnedValue>,
        expire_timeout: i32,
    ) -> u32 {
        let mut w = match self.state.write() {
            Ok(g) => g,
            Err(e) => e.into_inner(),
        };
        let id = if replaces_id > 0 {
            replaces_id
        } else {
            let next = w.next_id;
            w.next_id += 1;
            next
        };

        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        let urgency = if let Some(u) = _hints.get("urgency") {
            u.downcast_ref::<u8>().unwrap_or(1)
        } else {
            1
        };

        let item = NotificationItem {
            id,
            app_name,
            app_icon,
            summary,
            body,
            actions,
            urgency,
            timestamp_secs: now,
            expire_timeout_ms: expire_timeout,
        };

        if replaces_id > 0 {
            w.active.retain(|n| n.id != replaces_id);
            w.history.retain(|n| n.id != replaces_id);
        }

        let is_dnd = NotificationService::is_dnd();
        if !is_dnd || urgency >= 2 {
            w.active.insert(0, item.clone());
            if w.active.len() > 25 {
                w.active.pop();
            }
        }
        w.history.insert(0, item);
        if w.history.len() > 50 {
            w.history.truncate(50);
        }
        drop(w);

        NotificationService::notify_change();
        id
    }

    fn close_notification(&mut self, id: u32) {
        NotificationService::close(id);
    }

    fn get_capabilities(&self) -> Vec<String> {
        vec![
            "actions".to_string(),
            "body".to_string(),
            "body-hyperlinks".to_string(),
            "body-markup".to_string(),
            "icon-static".to_string(),
        ]
    }

    fn get_server_information(&self) -> (&str, &str, &str, &str) {
        ("Zenith Shell", "Zenith", "2.0", "1.2")
    }
}

impl NotificationService {
    fn spawn_bus_monitor(state: Arc<RwLock<NotificationState>>) {
        let state_clone = state.clone();
        let _ = std::thread::Builder::new()
            .name("zenith-notifications-dbus".to_string())
            .spawn(move || {
                loop {
                    let uid = unsafe { libc::getuid() };
                    let direct = format!("unix:path=/run/user/{}/bus", uid);

                    let b = if let Ok(addr) = std::env::var("DBUS_SESSION_BUS_ADDRESS") {
                        if !addr.is_empty() && addr != "disabled" {
                            zbus::blocking::connection::Builder::address(addr.as_str())
                        } else {
                            zbus::blocking::connection::Builder::address(direct.as_str())
                        }
                    } else {
                        zbus::blocking::connection::Builder::session().or_else(|_| {
                            zbus::blocking::connection::Builder::address(direct.as_str())
                        })
                    };

                    match b {
                        Ok(builder) => {
                            let server = NotificationServer { state: state_clone.clone() };
                            match builder
                                .name("org.freedesktop.Notifications")
                                .and_then(|b| b.serve_at("/org/freedesktop/Notifications", server))
                                .and_then(|b| b.build())
                            {
                                Ok(_conn) => {
                                    tracing::info!("Registered native D-Bus service 'org.freedesktop.Notifications' successfully!");
                                    loop {
                                        std::thread::sleep(Duration::from_secs(3600));
                                    }
                                }
                                Err(e) => {
                                    tracing::warn!("Failed to bind org.freedesktop.Notifications: {}. Retrying in 3s...", e);
                                }
                            }
                        }
                        Err(e) => {
                            tracing::warn!("Failed to create D-Bus connection builder: {}. Retrying in 3s...", e);
                        }
                    }
                    std::thread::sleep(Duration::from_secs(3));
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
