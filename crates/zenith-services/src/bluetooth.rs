//! Bluetooth device manager service for Zenith Shell.
//!
//! Queries BlueZ natively via D-Bus (`org.bluez`) and kernel sysfs (`/sys/class/rfkill`).
//! Completely zero-subprocess: no forks of `bluetoothctl`.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};
use serde::{Deserialize, Serialize};

/// Individual Bluetooth peripheral metadata.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BluetoothDevice {
    pub mac: String,
    pub name: String,
    pub connected: bool,
    pub battery: Option<u8>,
}

/// Overall Bluetooth controller status.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BluetoothStatus {
    pub powered: bool,
    pub devices: Vec<BluetoothDevice>,
}

impl Default for BluetoothStatus {
    fn default() -> Self {
        Self {
            powered: false,
            devices: Vec::new(),
        }
    }
}

impl BluetoothStatus {
    #[cfg(test)]
    pub fn mock() -> Self {
        Self {
            powered: true,
            devices: vec![
                BluetoothDevice {
                    mac: "FC:58:FA:12:34:56".to_string(),
                    name: "Sony WH-1000XM5".to_string(),
                    connected: true,
                    battery: Some(80),
                },
                BluetoothDevice {
                    mac: "E8:07:BF:AB:CD:EF".to_string(),
                    name: "Keychron K2 Pro".to_string(),
                    connected: true,
                    battery: Some(95),
                },
                BluetoothDevice {
                    mac: "00:1B:66:88:99:AA".to_string(),
                    name: "Logitech MX Master 3S".to_string(),
                    connected: false,
                    battery: None,
                },
            ],
        }
    }
}

struct BluetoothCache {
    status: BluetoothStatus,
    last_update: Instant,
}

static CACHE: OnceLock<Arc<Mutex<BluetoothCache>>> = OnceLock::new();
static MONITOR_INITIALIZED: AtomicBool = AtomicBool::new(false);

pub struct BluetoothService;

impl BluetoothService {
    fn cache() -> &'static Arc<Mutex<BluetoothCache>> {
        CACHE.get_or_init(|| {
            Arc::new(Mutex::new(BluetoothCache {
                status: BluetoothStatus::default(),
                last_update: Instant::now() - Duration::from_secs(120),
            }))
        })
    }

    fn ensure_signal_monitor_spawned() {
        if !MONITOR_INITIALIZED.swap(true, Ordering::SeqCst) {
            std::thread::Builder::new()
                .name("zenith-bluetooth-monitor".into())
                .spawn(|| {
                    if let Ok(conn) = crate::dbus::get_system_connection() {
                        let _ = conn.call_method(
                            Some("org.freedesktop.DBus"),
                            "/org/freedesktop/DBus",
                            Some("org.freedesktop.DBus"),
                            "AddMatch",
                            &("type='signal',sender='org.bluez'"),
                        );

                        for _msg in zbus::blocking::MessageIterator::from(&conn) {
                            let fresh = Self::query_system_status();
                            let cache_arc = Self::cache();
                            if let Ok(mut g) = cache_arc.lock() {
                                g.status = fresh;
                                g.last_update = Instant::now();
                            }
                        }
                    }
                })
                .ok();
        }
    }

    /// Retrieve current Bluetooth controller and devices state non-blockingly.
    pub fn status() -> BluetoothStatus {
        Self::ensure_signal_monitor_spawned();
        static IS_UPDATING: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
        let cache_arc = Self::cache();
        let mut guard = cache_arc.lock().unwrap();

        if guard.last_update.elapsed() > Duration::from_secs(30) {
            guard.last_update = Instant::now();
            if !IS_UPDATING.swap(true, std::sync::atomic::Ordering::SeqCst) {
                let cache_clone = cache_arc.clone();
                std::thread::Builder::new()
                    .name("zenith-bluetooth-status-bg".into())
                    .spawn(move || {
                        let fresh = Self::query_system_status();
                        if let Ok(mut g) = cache_clone.lock() {
                            g.status = fresh;
                            g.last_update = Instant::now();
                        }
                        IS_UPDATING.store(false, std::sync::atomic::Ordering::SeqCst);
                    })
                    .ok();
            }
        }

        guard.status.clone()
    }

    /// Check if physical bluetooth adapter exists on this machine.
    pub fn has_hardware() -> bool {
        std::path::Path::new("/sys/class/bluetooth").exists()
            || std::path::Path::new("/sys/class/rfkill").exists()
    }

    /// Connect to a Bluetooth device by MAC address via native BlueZ D-Bus.
    pub fn connect(mac: &str) -> Result<(), String> {
        if !Self::has_hardware() {
            return Err("No Bluetooth adapter present".to_string());
        }

        let conn = crate::dbus::get_shared_system_connection()
            .map_err(|e| format!("Failed to connect to system D-Bus: {}", e))?;

        let dev_path = Self::find_device_path(&conn, mac)
            .ok_or_else(|| format!("Device {} not found in BlueZ registry", mac))?;

        let dev_proxy = zbus::blocking::Proxy::new(
            &conn,
            "org.bluez",
            dev_path.as_str(),
            "org.bluez.Device1",
        ).map_err(|e| e.to_string())?;

        dev_proxy.call_method("Connect", &())
            .map_err(|e| format!("Failed to connect to {}: {}", mac, e))?;

        Self::invalidate_cache();
        Ok(())
    }

    /// Disconnect from a Bluetooth device by MAC address via native BlueZ D-Bus.
    pub fn disconnect(mac: &str) -> Result<(), String> {
        if !Self::has_hardware() {
            return Err("No Bluetooth adapter present".to_string());
        }

        let conn = crate::dbus::get_shared_system_connection()
            .map_err(|e| format!("Failed to connect to system D-Bus: {}", e))?;

        let dev_path = Self::find_device_path(&conn, mac)
            .ok_or_else(|| format!("Device {} not found in BlueZ registry", mac))?;

        let dev_proxy = zbus::blocking::Proxy::new(
            &conn,
            "org.bluez",
            dev_path.as_str(),
            "org.bluez.Device1",
        ).map_err(|e| e.to_string())?;

        dev_proxy.call_method("Disconnect", &())
            .map_err(|e| format!("Failed to disconnect from {}: {}", mac, e))?;

        Self::invalidate_cache();
        Ok(())
    }

    /// Toggle Bluetooth controller power state via native BlueZ D-Bus and kernel rfkill.
    pub fn toggle_power() -> bool {
        if !Self::has_hardware() {
            return false;
        }

        let current = Self::status().powered;
        let target = !current;

        // 1. D-Bus BlueZ Adapter1 toggle
        if let Ok(conn) = crate::dbus::get_shared_system_connection() {
            if let Some(adapter_path) = Self::find_first_adapter_path(&conn) {
                if let Ok(adapter_proxy) = zbus::blocking::Proxy::new(
                    &conn,
                    "org.bluez",
                    adapter_path.as_str(),
                    "org.bluez.Adapter1",
                ) {
                    let _ = adapter_proxy.set_property("Powered", target);
                }
            }
        }

        // 2. Direct kernel rfkill control (zero-subprocess)
        if let Ok(entries) = std::fs::read_dir("/sys/class/rfkill") {
            for entry in entries.flatten() {
                let t_path = entry.path().join("type");
                if let Ok(t) = std::fs::read_to_string(t_path) {
                    if t.trim() == "bluetooth" {
                        let state = if target { "0" } else { "1" };
                        let _ = std::fs::write(entry.path().join("soft"), state);
                    }
                }
            }
        }

        Self::invalidate_cache();
        target
    }

    fn invalidate_cache() {
        if let Some(cache_arc) = CACHE.get() {
            if let Ok(mut g) = cache_arc.lock() {
                g.last_update = Instant::now() - Duration::from_secs(10);
            }
        }
    }

    fn find_first_adapter_path(conn: &zbus::blocking::Connection) -> Option<zbus::zvariant::OwnedObjectPath> {
        let proxy = zbus::blocking::Proxy::new(
            conn,
            "org.bluez",
            "/",
            "org.freedesktop.DBus.ObjectManager",
        ).ok()?;

        let objects: HashMap<zbus::zvariant::OwnedObjectPath, HashMap<String, HashMap<String, zbus::zvariant::OwnedValue>>> =
            proxy.call_method("GetManagedObjects", &()).ok()?.body().deserialize().ok()?;

        for (path, interfaces) in objects {
            if interfaces.contains_key("org.bluez.Adapter1") {
                return Some(path);
            }
        }
        None
    }

    fn find_device_path(
        conn: &zbus::blocking::Connection,
        mac: &str,
    ) -> Option<zbus::zvariant::OwnedObjectPath> {
        let proxy = zbus::blocking::Proxy::new(
            conn,
            "org.bluez",
            "/",
            "org.freedesktop.DBus.ObjectManager",
        ).ok()?;

        let objects: HashMap<zbus::zvariant::OwnedObjectPath, HashMap<String, HashMap<String, zbus::zvariant::OwnedValue>>> =
            proxy.call_method("GetManagedObjects", &()).ok()?.body().deserialize().ok()?;

        for (path, interfaces) in objects {
            if let Some(device_props) = interfaces.get("org.bluez.Device1") {
                if let Some(addr_val) = device_props.get("Address") {
                    if let zbus::zvariant::Value::Str(addr_str) = &**addr_val {
                        if addr_str.as_str().eq_ignore_ascii_case(mac) {
                            return Some(path);
                        }
                    }
                }
            }
        }
        None
    }

    fn query_system_status() -> BluetoothStatus {
        if !Self::has_hardware() {
            return BluetoothStatus::default();
        }

        if let Ok(conn) = crate::dbus::get_shared_system_connection() {
            if let Ok(proxy) = zbus::blocking::Proxy::new(
                &conn,
                "org.bluez",
                "/",
                "org.freedesktop.DBus.ObjectManager",
            ) {
                if let Ok(reply) = proxy.call_method("GetManagedObjects", &()) {
                    if let Ok(objects) = reply.body().deserialize::<HashMap<
                        zbus::zvariant::OwnedObjectPath,
                        HashMap<String, HashMap<String, zbus::zvariant::OwnedValue>>,
                    >>() {
                        let mut powered = true;
                        let mut devices = Vec::new();

                        for (_path, interfaces) in objects {
                            if let Some(adapter_props) = interfaces.get("org.bluez.Adapter1") {
                                if let Some(p_val) = adapter_props.get("Powered") {
                                    if let zbus::zvariant::Value::Bool(b) = &**p_val {
                                        powered = *b;
                                    }
                                }
                            }

                            if let Some(dev_props) = interfaces.get("org.bluez.Device1") {
                                let mut mac = String::new();
                                let mut name = String::new();
                                let mut connected = false;

                                if let Some(addr_val) = dev_props.get("Address") {
                                    if let zbus::zvariant::Value::Str(s) = &**addr_val {
                                        mac = s.as_str().to_string();
                                    }
                                }

                                if let Some(name_val) = dev_props.get("Name").or_else(|| dev_props.get("Alias")) {
                                    if let zbus::zvariant::Value::Str(s) = &**name_val {
                                        name = s.as_str().to_string();
                                    }
                                }

                                if let Some(conn_val) = dev_props.get("Connected") {
                                    if let zbus::zvariant::Value::Bool(b) = &**conn_val {
                                        connected = *b;
                                    }
                                }

                                let mut battery = None;
                                if let Some(bat_props) = interfaces.get("org.bluez.Battery1") {
                                    if let Some(pct_val) = bat_props.get("Percentage") {
                                        match &**pct_val {
                                            zbus::zvariant::Value::U8(pct) => battery = Some(*pct),
                                            zbus::zvariant::Value::U32(pct) => battery = Some(*pct as u8),
                                            zbus::zvariant::Value::I32(pct) => battery = Some(*pct as u8),
                                            _ => {}
                                        }
                                    }
                                }

                                if !mac.is_empty() {
                                    devices.push(BluetoothDevice {
                                        mac,
                                        name: if name.is_empty() { "Bluetooth Device".to_string() } else { name },
                                        connected,
                                        battery,
                                    });
                                }
                            }
                        }

                        // Check rfkill for soft-blocked power status if BlueZ had no adapter
                        if let Ok(entries) = std::fs::read_dir("/sys/class/rfkill") {
                            for entry in entries.flatten() {
                                let t_path = entry.path().join("type");
                                if let Ok(t) = std::fs::read_to_string(t_path) {
                                    if t.trim() == "bluetooth" {
                                        if let Ok(s) = std::fs::read_to_string(entry.path().join("soft")) {
                                            if s.trim() == "1" {
                                                powered = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        return BluetoothStatus { powered, devices };
                    }
                }
            }
        }

        BluetoothStatus::default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bluetooth_status_and_devices() {
        let mock = BluetoothStatus::mock();
        assert!(!mock.devices.is_empty());
        assert!(mock.devices.iter().any(|d| !d.mac.is_empty()));

        let status = BluetoothService::status();
        // Hardware query returns gracefully without panic
        let _ = status.powered;
    }
}
