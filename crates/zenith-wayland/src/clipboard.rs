//! Native Zero-Fork Wayland Clipboard Subsystem for Zenith Base v3.
//!
//! Replaces external `wl-copy` and `wl-paste` subprocess forks with native
//! SCTK `wl_data_device_manager` data offers and data sources, with in-process
//! fallback to thread-safe memory storage.

use std::sync::{Arc, Mutex};
use wayland_client::protocol::wl_data_source::WlDataSource;
use wayland_client::QueueHandle;
use smithay_client_toolkit::data_device_manager::{
    DataDeviceManagerState,
    data_device::DataDevice,
    data_source::CopyPasteSource,
    WritePipe,
};

/// Format MIME types supported by the Zenith native clipboard.
pub const TEXT_MIME_TYPES: [&str; 2] = [
    "text/plain;charset=utf-8",
    "text/plain",
];

/// Native clipboard manager maintaining Wayland data device state and RAM fallback.
pub struct ClipboardManager {
    pub manager_state: Option<DataDeviceManagerState>,
    pub data_device: Option<DataDevice>,
    pub copy_source: Option<CopyPasteSource>,
    pub ram_buffer: Arc<Mutex<String>>,
    pub last_serial: u32,
}

impl std::fmt::Debug for ClipboardManager {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ClipboardManager")
            .field("has_data_device", &self.data_device.is_some())
            .field("last_serial", &self.last_serial)
            .finish()
    }
}

impl Default for ClipboardManager {
    fn default() -> Self {
        Self::new()
    }
}

impl ClipboardManager {
    /// Creates a new `ClipboardManager` with thread-safe memory buffer.
    pub fn new() -> Self {
        Self {
            manager_state: None,
            data_device: None,
            copy_source: None,
            ram_buffer: Arc::new(Mutex::new(String::new())),
            last_serial: 0,
        }
    }

    /// Stores text into in-process clipboard buffer without spawning external processes.
    pub fn copy(&mut self, text: &str) {
        if let Ok(mut lock) = self.ram_buffer.lock() {
            *lock = text.to_string();
        }
    }

    /// Offers text to system clipboard via native Wayland DataDevice.
    pub fn copy_with_wayland<D>(&mut self, qh: &QueueHandle<D>, text: &str, serial: u32)
    where
        D: wayland_client::Dispatch<WlDataSource, smithay_client_toolkit::data_device_manager::data_source::DataSourceData> + 'static,
    {
        self.copy(text);
        self.last_serial = serial;

        if let (Some(ref mgr), Some(ref device)) = (&self.manager_state, &self.data_device) {
            let source = mgr.create_copy_paste_source(qh, TEXT_MIME_TYPES);
            source.set_selection(device, serial);
            self.copy_source = Some(source);
        }
    }

    /// Reads text from active system clipboard or RAM fallback without deadlocks, optionally flushing connection.
    pub fn paste_with_conn(&self, conn: Option<&wayland_client::Connection>) -> String {
        // Return immediately from pre-fetched RAM buffer if populated
        if let Ok(lock) = self.ram_buffer.lock() {
            if !lock.is_empty() {
                return lock.clone();
            }
        }

        // Try fast reading from native Wayland selection offer only for supported MIME types
        if let Some(ref device) = self.data_device {
            if let Some(offer) = device.data().selection_offer() {
                let mime_match = offer.with_mime_types(|types| {
                    TEXT_MIME_TYPES.iter().find(|m| types.iter().any(|t| t == *m)).copied()
                });

                if let Some(mime) = mime_match {
                    if let Ok(mut read_pipe) = offer.receive(mime.to_string()) {
                        if let Some(c) = conn {
                            let _ = c.flush();
                        }
                        let (tx, rx) = std::sync::mpsc::channel();
                        std::thread::spawn(move || {
                            use std::io::Read;
                            let mut content = String::new();
                            let _ = read_pipe.read_to_string(&mut content);
                            let _ = tx.send(content);
                        });
                        if let Ok(content) = rx.recv_timeout(std::time::Duration::from_millis(20)) {
                            if !content.is_empty() {
                                if let Ok(mut lock) = self.ram_buffer.lock() {
                                    *lock = content.clone();
                                }
                                return content;
                            }
                        }
                    }
                }
            }
        }

        // Fallback to in-process memory buffer
        self.ram_buffer.lock().map(|g| g.clone()).unwrap_or_default()
    }

    /// Reads text from active system clipboard or RAM fallback without subprocesses.
    pub fn paste(&self) -> String {
        self.paste_with_conn(None)
    }

    /// Handles a paste request from an external Wayland client writing into pipe.
    pub fn handle_send_request(&self, mime: &str, mut pipe: WritePipe) {
        if TEXT_MIME_TYPES.contains(&mime) {
            use std::io::Write;
            if let Ok(lock) = self.ram_buffer.lock() {
                let _ = pipe.write_all(lock.as_bytes());
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ram_clipboard_fallback() {
        let mgr = ClipboardManager::new();
        assert_eq!(mgr.paste(), "");

        *mgr.ram_buffer.lock().unwrap() = "zenith_zero_fork".to_string();
        assert_eq!(mgr.paste(), "zenith_zero_fork");
    }
}
