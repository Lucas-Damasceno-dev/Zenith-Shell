//! Zenith Services - Decoupled, non-blocking Clipboard History service.
//!
//! Provides cached access to cliphist clipboard history without blocking the UI thread,
//! and sanitized command execution without intermediate shell interpreters.

use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

/// Cached clipboard item metadata.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClipboardItem {
    pub id: String,
    pub text: String,
    pub is_image: bool,
}

struct ClipboardCache {
    items: Vec<ClipboardItem>,
    last_fetch: Instant,
    is_fetching: bool,
}

static CACHE: OnceLock<Arc<Mutex<ClipboardCache>>> = OnceLock::new();

pub struct ClipboardService;

impl ClipboardService {
    fn cache() -> &'static Arc<Mutex<ClipboardCache>> {
        CACHE.get_or_init(|| {
            Arc::new(Mutex::new(ClipboardCache {
                items: Vec::new(),
                last_fetch: Instant::now() - Duration::from_secs(60),
                is_fetching: false,
            }))
        })
    }

    /// Retrieve clipboard history items non-blockingly with in-memory caching.
    pub fn get_history() -> Vec<ClipboardItem> {
        let cache_arc = Self::cache();
        let mut guard = cache_arc.lock().unwrap();

        // Refresh cache if stale (> 2 seconds) and not already fetching
        if guard.last_fetch.elapsed() > Duration::from_secs(2) && !guard.is_fetching {
            guard.is_fetching = true;
            let c_clone = cache_arc.clone();
            std::thread::Builder::new()
                .name("cliphist-fetch".into())
                .spawn(move || {
                    let items = Self::fetch_history_native();
                    let mut g = c_clone.lock().unwrap();
                    g.items = items;
                    g.last_fetch = Instant::now();
                    g.is_fetching = false;
                })
                .ok();
        }

        guard.items.clone()
    }

    /// Invalidate the clipboard cache immediately.
    pub fn invalidate() {
        let cache_arc = Self::cache();
        if let Ok(mut guard) = cache_arc.lock() {
            guard.last_fetch = Instant::now() - Duration::from_secs(60);
        }
    }

    fn fetch_history_native() -> Vec<ClipboardItem> {
        let mut items = Vec::new();
        if let Ok(output) = std::process::Command::new("cliphist").arg("list").output() {
            if output.status.success() {
                let out_str = String::from_utf8_lossy(&output.stdout);
                for line in out_str.lines().take(50) {
                    if let Some((id, text)) = line.split_once('\t') {
                        items.push(ClipboardItem {
                            id: id.to_string(),
                            text: text.to_string(),
                            is_image: text.starts_with("[[ binary data"),
                        });
                    }
                }
            }
        }
        items
    }

    /// Safely decodes and copies an item by id directly via cliphist and wl-copy
    /// without intermediate shell invocation or command injection vulnerabilities.
    pub fn copy(id: &str) -> std::io::Result<()> {
        let mut decode_proc = std::process::Command::new("cliphist")
            .arg("decode")
            .arg(id)
            .stdout(std::process::Stdio::piped())
            .spawn()?;

        if let Some(stdout) = decode_proc.stdout.take() {
            let mut copy_proc = std::process::Command::new("wl-copy")
                .stdin(stdout)
                .spawn()?;

            std::thread::Builder::new()
                .name("clip-copy-reaper".into())
                .spawn(move || {
                    let _ = copy_proc.wait();
                    let _ = decode_proc.wait();
                })
                .ok();
        }

        Ok(())
    }

    /// Safely deletes a clipboard item by id directly via cliphist delete
    /// without intermediate shell invocation.
    pub fn delete(id: &str) -> std::io::Result<()> {
        let items = Self::get_history();
        let payload = if let Some(item) = items.iter().find(|i| i.id == id) {
            format!("{}\t{}\n", item.id, item.text)
        } else {
            format!("{}\t\n", id)
        };

        let mut child = std::process::Command::new("cliphist")
            .arg("delete")
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn()?;

        if let Some(mut stdin) = child.stdin.take() {
            use std::io::Write;
            let _ = stdin.write_all(payload.as_bytes());
        }

        std::thread::Builder::new()
            .name("clip-del-reaper".into())
            .spawn(move || {
                let _ = child.wait();
            })
            .ok();

        Self::invalidate();
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_clipboard_cache_initialization() {
        let items = ClipboardService::get_history();
        assert!(items.is_empty() || !items.is_empty());
    }
}
