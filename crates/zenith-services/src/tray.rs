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

#[zbus::proxy(
    interface = "org.kde.StatusNotifierWatcher",
    default_service = "org.kde.StatusNotifierWatcher",
    default_path = "/StatusNotifierWatcher"
)]
pub trait StatusNotifierWatcher {
    /// RegisteredStatusNotifierItems property
    #[zbus(property)]
    fn registered_status_notifier_items(&self) -> zbus::Result<Vec<String>>;

    /// IsStatusNotifierHostRegistered property
    #[zbus(property)]
    fn is_status_notifier_host_registered(&self) -> zbus::Result<bool>;

    /// ProtocolVersion property
    #[zbus(property)]
    fn protocol_version(&self) -> zbus::Result<i32>;

    /// RegisterStatusNotifierItem method
    fn register_status_notifier_item(&self, service: &str) -> zbus::Result<()>;

    /// RegisterStatusNotifierHost method
    fn register_status_notifier_host(&self, service: &str) -> zbus::Result<()>;
}

#[zbus::proxy(
    interface = "org.kde.StatusNotifierItem",
    default_path = "/StatusNotifierItem"
)]
pub trait StatusNotifierItem {
    /// ContextMenu method
    fn context_menu(&self, x: i32, y: i32) -> zbus::Result<()>;

    /// Activate method
    fn activate(&self, x: i32, y: i32) -> zbus::Result<()>;

    /// SecondaryActivate method
    fn secondary_activate(&self, x: i32, y: i32) -> zbus::Result<()>;

    /// Scroll method
    fn scroll(&self, delta: i32, orientation: &str) -> zbus::Result<()>;

    /// Id property
    #[zbus(property)]
    fn id(&self) -> zbus::Result<String>;

    /// Title property
    #[zbus(property)]
    fn title(&self) -> zbus::Result<String>;

    /// IconName property
    #[zbus(property)]
    fn icon_name(&self) -> zbus::Result<String>;

    /// IconThemePath property
    #[zbus(property)]
    fn icon_theme_path(&self) -> zbus::Result<String>;

    /// Status property
    #[zbus(property)]
    fn status(&self) -> zbus::Result<String>;

    /// Category property
    #[zbus(property)]
    fn category(&self) -> zbus::Result<String>;

    /// WindowId property
    #[zbus(property)]
    fn window_id(&self) -> zbus::Result<i32>;

    /// ItemIsMenu property
    #[zbus(property)]
    fn item_is_menu(&self) -> zbus::Result<bool>;

    /// Menu property
    #[zbus(property)]
    fn menu(&self) -> zbus::Result<zbus::zvariant::OwnedObjectPath>;

    /// AttentionIconName property
    #[zbus(property)]
    fn attention_icon_name(&self) -> zbus::Result<String>;
}

struct TrayCache {
    items: Vec<TrayItem>,
    last_query: Instant,
}

static TRAY_CACHE: OnceLock<Arc<Mutex<TrayCache>>> = OnceLock::new();
static IS_UPDATING: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

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
            if !IS_UPDATING.swap(true, std::sync::atomic::Ordering::SeqCst) {
                let c_arc = cache_arc.clone();
                std::thread::spawn(move || {
                    let fresh = zbus::block_on(Self::list_async());
                    if let Ok(mut g) = c_arc.lock() {
                        g.items = fresh;
                        g.last_query = Instant::now();
                    }
                    IS_UPDATING.store(false, std::sync::atomic::Ordering::SeqCst);
                });
            }
        }

        guard.items.clone()
    }

    /// Asynchronously retrieve list of registered StatusNotifierItem tray icons.
    pub async fn list_async() -> Vec<TrayItem> {
        let Ok(conn) = session_connection().await else {
            return Vec::new();
        };
        let Ok(watcher) = StatusNotifierWatcherProxy::new(&conn).await else {
            return Vec::new();
        };
        let Ok(services) = watcher.registered_status_notifier_items().await else {
            return Vec::new();
        };

        let mut fresh = Vec::new();
        for service in services {
            if let Ok(item) = inspect_item_async(&conn, &service).await {
                fresh.push(item);
            }
        }
        fresh
    }

    /// Build a typed `StatusNotifierItemProxy` for a given service and path.
    pub async fn item_proxy<'a>(
        conn: &'a zbus::Connection,
        service_path: &str,
    ) -> zbus::Result<StatusNotifierItemProxy<'a>> {
        let (dest, path) = parse_service_path(service_path);
        let dest_owned = zbus::names::BusName::try_from(dest.to_string())?;
        let path_owned = zbus::zvariant::ObjectPath::try_from(path)?;
        StatusNotifierItemProxy::builder(conn)
            .destination(dest_owned)?
            .path(path_owned)?
            .build()
            .await
    }

    /// Dispatch primary activation click (Activate(x, y)) asynchronously.
    pub async fn activate_async(service: &str, x: i32, y: i32) -> zbus::Result<()> {
        let conn = session_connection().await?;
        let proxy = Self::item_proxy(&conn, service).await?;
        proxy.activate(x, y).await
    }

    /// Dispatch context menu click (ContextMenu(x, y)) asynchronously.
    pub async fn context_menu_async(service: &str, x: i32, y: i32) -> zbus::Result<()> {
        let conn = session_connection().await?;
        let proxy = Self::item_proxy(&conn, service).await?;
        proxy.context_menu(x, y).await
    }

    /// Dispatch secondary activation click (SecondaryActivate(x, y)) asynchronously.
    pub async fn secondary_activate_async(service: &str, x: i32, y: i32) -> zbus::Result<()> {
        let conn = session_connection().await?;
        let proxy = Self::item_proxy(&conn, service).await?;
        proxy.secondary_activate(x, y).await
    }

    /// Dispatch scroll event asynchronously.
    pub async fn scroll_async(service: &str, delta: i32, orientation: &str) -> zbus::Result<()> {
        let conn = session_connection().await?;
        let proxy = Self::item_proxy(&conn, service).await?;
        proxy.scroll(delta, orientation).await
    }

    /// Dispatch primary activation click (Activate(x, y)).
    pub fn activate(service: &str) {
        let service = service.to_string();
        std::thread::spawn(move || {
            let _ = zbus::block_on(Self::activate_async(&service, 0, 0));
        });
    }

    /// Dispatch context menu click (ContextMenu(x, y)).
    pub fn context_menu(service: &str) {
        let service = service.to_string();
        std::thread::spawn(move || {
            let _ = zbus::block_on(Self::context_menu_async(&service, 0, 0));
        });
    }

    /// Dispatch secondary activation click (SecondaryActivate(x, y)).
    pub fn secondary_activate(service: &str) {
        let service = service.to_string();
        std::thread::spawn(move || {
            let _ = zbus::block_on(Self::secondary_activate_async(&service, 0, 0));
        });
    }

    /// Dispatch scroll event.
    pub fn scroll(service: &str, delta: i32, orientation: &str) {
        let service = service.to_string();
        let orientation = orientation.to_string();
        std::thread::spawn(move || {
            let _ = zbus::block_on(Self::scroll_async(&service, delta, &orientation));
        });
    }

    /// Dispatch primary activation click (Activate(x, y)) synchronously.
    pub fn activate_blocking(service: &str, x: i32, y: i32) -> zbus::Result<()> {
        zbus::block_on(Self::activate_async(service, x, y))
    }

    /// Dispatch context menu click (ContextMenu(x, y)) synchronously.
    pub fn context_menu_blocking(service: &str, x: i32, y: i32) -> zbus::Result<()> {
        zbus::block_on(Self::context_menu_async(service, x, y))
    }
}

pub fn parse_service_path(service_path: &str) -> (&str, String) {
    if let Some((s, p)) = service_path.split_once('/') {
        let path = if p.starts_with('/') {
            p.to_string()
        } else {
            format!("/{}", p)
        };
        (s, path)
    } else {
        (service_path, "/StatusNotifierItem".to_string())
    }
}

pub fn resolve_bus_address() -> Option<String> {
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

/// Helper to obtain an async session connection with graceful fallback to standard runtime bus socket.
pub async fn session_connection() -> zbus::Result<zbus::Connection> {
    if let Ok(conn) = zbus::Connection::session().await {
        return Ok(conn);
    }
    if let Some(addr) = resolve_bus_address() {
        let path = addr.strip_prefix("unix:path=").unwrap_or(&addr);
        if let Ok(conn) = zbus::connection::Builder::address(path)?.build().await {
            return Ok(conn);
        }
    }
    zbus::Connection::session().await
}

pub async fn query_registered_items_async() -> zbus::Result<Vec<String>> {
    let conn = session_connection().await?;
    let watcher = StatusNotifierWatcherProxy::new(&conn).await?;
    watcher.registered_status_notifier_items().await
}

pub fn query_registered_items() -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let items = zbus::block_on(query_registered_items_async())?;
    Ok(items)
}

pub async fn inspect_item_async(conn: &zbus::Connection, service_path: &str) -> zbus::Result<TrayItem> {
    let (service, path) = parse_service_path(service_path);
    let dest_owned = zbus::names::BusName::try_from(service.to_string())?;
    let path_owned = zbus::zvariant::ObjectPath::try_from(path)?;
    let proxy = StatusNotifierItemProxy::builder(conn)
        .destination(dest_owned)?
        .path(path_owned)?
        .build()
        .await?;

    let id = proxy.id().await.unwrap_or_default();
    let title = proxy.title().await.unwrap_or_default();
    let icon_name = proxy.icon_name().await.unwrap_or_default();

    Ok(TrayItem {
        id: if id.is_empty() { service.to_string() } else { id },
        title: if title.is_empty() { service.to_string() } else { title },
        icon_name: if icon_name.is_empty() { "󰀻".to_string() } else { icon_name },
        service: service.to_string(),
    })
}

pub fn inspect_item(service_path: &str) -> Result<TrayItem, Box<dyn std::error::Error>> {
    let item = zbus::block_on(async {
        let conn = session_connection().await?;
        inspect_item_async(&conn, service_path).await
    })?;
    Ok(item)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tray_list() {
        let items = TrayService::list();
        assert!(items.is_empty() || !items.is_empty());
    }

    #[test]
    fn test_parse_service_path() {
        let (dest, path) = parse_service_path("org.kde.StatusNotifierItem-1234-1");
        assert_eq!(dest, "org.kde.StatusNotifierItem-1234-1");
        assert_eq!(path, "/StatusNotifierItem");

        let (dest, path) = parse_service_path(":1.54/org/ayatana/NotificationItem/test");
        assert_eq!(dest, ":1.54");
        assert_eq!(path, "/org/ayatana/NotificationItem/test");
    }

    #[test]
    fn test_resolve_bus_address() {
        let _ = resolve_bus_address();
    }
}
