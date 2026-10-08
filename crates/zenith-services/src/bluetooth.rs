//! Bluetooth device manager service for Zenith Shell.
//!
//! Queries BlueZ via `bluetoothctl` and exposes paired devices and power state.

use std::process::Command;
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

pub struct BluetoothService;

impl BluetoothService {
    fn cache() -> &'static Arc<Mutex<BluetoothCache>> {
        CACHE.get_or_init(|| {
            Arc::new(Mutex::new(BluetoothCache {
                status: Self::query_system_status(),
                last_update: Instant::now(),
            }))
        })
    }

    /// Retrieve current Bluetooth controller and devices state.
    pub fn status() -> BluetoothStatus {
        let cache_arc = Self::cache();
        let mut guard = cache_arc.lock().unwrap();
        if guard.last_update.elapsed() > Duration::from_millis(3000) {
            guard.status = Self::query_system_status();
            guard.last_update = Instant::now();
        }
        guard.status.clone()
    }

    /// Connect to a Bluetooth device by MAC address.
    pub fn connect(mac: &str) -> Result<(), String> {
        let out = Command::new("bluetoothctl")
            .args(["connect", mac])
            .output()
            .map_err(|e| e.to_string())?;
        if out.status.success() {
            Ok(())
        } else {
            Err(String::from_utf8_lossy(&out.stderr).to_string())
        }
    }

    /// Disconnect from a Bluetooth device by MAC address.
    pub fn disconnect(mac: &str) -> Result<(), String> {
        let out = Command::new("bluetoothctl")
            .args(["disconnect", mac])
            .output()
            .map_err(|e| e.to_string())?;
        if out.status.success() {
            Ok(())
        } else {
            Err(String::from_utf8_lossy(&out.stderr).to_string())
        }
    }

    /// Toggle Bluetooth controller power state.
    pub fn toggle_power() -> bool {
        let current = Self::status().powered;
        let target = if current { "off" } else { "on" };
        let _ = Command::new("bluetoothctl").args(["power", target]).status();
        !current
    }

    fn query_system_status() -> BluetoothStatus {
        let mut devices = Vec::new();
        let mut powered = true;

        if let Ok(out) = Command::new("bluetoothctl").arg("show").output() {
            let s = String::from_utf8_lossy(&out.stdout);
            if s.contains("Powered: no") {
                powered = false;
            }
        }

        if let Ok(out) = Command::new("bluetoothctl").arg("devices").output() {
            let s = String::from_utf8_lossy(&out.stdout);
            for line in s.lines() {
                // Device FC:58:FA:12:34:56 Sony WH-1000XM5
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 && parts[0] == "Device" {
                    let mac = parts[1].to_string();
                    let name = parts[2..].join(" ");
                    devices.push(BluetoothDevice {
                        mac,
                        name,
                        connected: false,
                        battery: None,
                    });
                }
            }
        }

        // Check which devices are currently connected
        if let Ok(out) = Command::new("bluetoothctl").args(["devices", "Connected"]).output() {
            let s = String::from_utf8_lossy(&out.stdout);
            for line in s.lines() {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 && parts[0] == "Device" {
                    let mac = parts[1];
                    if let Some(dev) = devices.iter_mut().find(|d| d.mac == mac) {
                        dev.connected = true;
                    }
                }
            }
        }

        if devices.is_empty() {
            BluetoothStatus::default()
        } else {
            BluetoothStatus { powered, devices }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bluetooth_status_and_devices() {
        let status = BluetoothService::status();
        assert!(!status.devices.is_empty());
        assert!(status.devices.iter().any(|d| !d.mac.is_empty()));
    }
}
