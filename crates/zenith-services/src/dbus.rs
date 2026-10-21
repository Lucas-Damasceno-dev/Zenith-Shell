//! Resilient D-Bus connection management and provider contracts.

use std::path::PathBuf;
use crate::error::DbusError;

/// Contract for providing resilient D-Bus connections.
pub trait DbusConnectionProvider: Send + Sync {
    /// Obtains a connection to the user's D-Bus session bus.
    fn get_session_connection(&self) -> Result<zbus::blocking::Connection, DbusError>;

    /// Obtains a connection to the Linux system bus.
    fn get_system_connection(&self) -> Result<zbus::blocking::Connection, DbusError>;
}

/// Default resilient D-Bus provider supporting fallback sockets and environment discovery.
#[derive(Debug, Clone, Default)]
pub struct DbusManager;

impl DbusConnectionProvider for DbusManager {
    fn get_session_connection(&self) -> Result<zbus::blocking::Connection, DbusError> {
        get_session_connection()
    }

    fn get_system_connection(&self) -> Result<zbus::blocking::Connection, DbusError> {
        get_system_connection()
    }
}

/// Resolves standard D-Bus session bus address with fallbacks to system/user runtime directories.
pub fn resolve_session_bus_address() -> Option<String> {
    if let Ok(addr) = std::env::var("DBUS_SESSION_BUS_ADDRESS") {
        if !addr.is_empty() && addr != "disabled" {
            return Some(addr);
        }
    }

    if let Ok(xdg) = std::env::var("XDG_RUNTIME_DIR") {
        let p = PathBuf::from(xdg).join("bus");
        if p.exists() {
            return Some(format!("unix:path={}", p.display()));
        }
    }

    let uid = unsafe { libc::getuid() };
    let direct_sock = format!("/run/user/{}/bus", uid);
    if std::path::Path::new(&direct_sock).exists() {
        return Some(format!("unix:path={}", direct_sock));
    }

    None
}

/// Connects to the D-Bus session bus resiliently without panicking.
pub fn get_session_connection() -> Result<zbus::blocking::Connection, DbusError> {
    if let Ok(conn) = zbus::blocking::Connection::session() {
        return Ok(conn);
    }

    if let Some(addr) = resolve_session_bus_address() {
        let clean_path = addr.strip_prefix("--address=").unwrap_or(&addr);
        let conn = zbus::blocking::connection::Builder::address(clean_path)?
            .build()?;
        return Ok(conn);
    }

    Err(DbusError::AddressResolutionFailed(
        "No viable D-Bus session bus address or runtime socket found".into(),
    ))
}

/// Connects to the Linux system bus resiliently without panicking.
pub fn get_system_connection() -> Result<zbus::blocking::Connection, DbusError> {
    zbus::blocking::Connection::system().map_err(DbusError::from)
}

static SESSION_SINGLETON: std::sync::OnceLock<std::sync::Arc<zbus::blocking::Connection>> = std::sync::OnceLock::new();
static SYSTEM_SINGLETON: std::sync::OnceLock<std::sync::Arc<zbus::blocking::Connection>> = std::sync::OnceLock::new();

/// Returns a shared, persistent session bus connection singleton.
pub fn get_shared_session_connection() -> Result<std::sync::Arc<zbus::blocking::Connection>, DbusError> {
    if let Some(conn) = SESSION_SINGLETON.get() {
        return Ok(conn.clone());
    }
    let conn = get_session_connection()?;
    let arc = std::sync::Arc::new(conn);
    let _ = SESSION_SINGLETON.set(arc.clone());
    Ok(arc)
}

/// Returns a shared, persistent system bus connection singleton.
pub fn get_shared_system_connection() -> Result<std::sync::Arc<zbus::blocking::Connection>, DbusError> {
    if let Some(conn) = SYSTEM_SINGLETON.get() {
        return Ok(conn.clone());
    }
    let conn = get_system_connection()?;
    let arc = std::sync::Arc::new(conn);
    let _ = SYSTEM_SINGLETON.set(arc.clone());
    Ok(arc)
}
