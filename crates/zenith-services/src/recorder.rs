//! Screen recording and snipping tool service for Zenith Shell.

use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};

static IS_RECORDING: AtomicBool = AtomicBool::new(false);
static RECORDER_CACHE: std::sync::OnceLock<std::sync::RwLock<(bool, std::time::Instant)>> = std::sync::OnceLock::new();

pub struct RecorderService;

impl RecorderService {
    fn set_cached_recording(active: bool) {
        if let Some(cache) = RECORDER_CACHE.get() {
            if let Ok(mut guard) = cache.write() {
                guard.0 = active;
                guard.1 = std::time::Instant::now();
            }
        }
    }

    fn find_recorder_pid() -> Option<i32> {
        if let Ok(entries) = std::fs::read_dir("/proc") {
            for entry in entries.flatten() {
                let name = entry.file_name();
                if let Some(s) = name.to_str() {
                    if s.chars().all(|c| c.is_ascii_digit()) {
                        let comm_path = entry.path().join("comm");
                        if let Ok(comm) = std::fs::read_to_string(comm_path) {
                            if comm.trim() == "wf-recorder" {
                                // Check if process is a zombie (state 'Z' in /proc/<pid>/stat)
                                let stat_path = entry.path().join("stat");
                                if let Ok(stat) = std::fs::read_to_string(stat_path) {
                                    if let Some(idx) = stat.rfind(')') {
                                        let rest = &stat[idx + 1..];
                                        if let Some(state) = rest.split_whitespace().next() {
                                            if state == "Z" {
                                                continue;
                                            }
                                        }
                                    }
                                }
                                if let Ok(pid) = s.parse::<i32>() {
                                    return Some(pid);
                                }
                            }
                        }
                    }
                }
            }
        }
        None
    }

    /// Whether screen recording is currently active.
    pub fn is_recording() -> bool {
        let cache_lock = RECORDER_CACHE.get_or_init(|| {
            std::sync::RwLock::new((false, std::time::Instant::now() - std::time::Duration::from_secs(10)))
        });

        if let Ok(guard) = cache_lock.read() {
            if guard.1.elapsed() < std::time::Duration::from_millis(1000) {
                return guard.0;
            }
        }

        let active = Self::find_recorder_pid().is_some();
        if let Ok(mut guard) = cache_lock.write() {
            guard.0 = active;
            guard.1 = std::time::Instant::now();
        }
        IS_RECORDING.store(active, Ordering::SeqCst);
        active
    }

    /// Toggle screen recording via `wf-recorder`.
    pub fn toggle_recording() -> bool {
        if let Some(pid) = Self::find_recorder_pid() {
            unsafe {
                libc::kill(pid, libc::SIGINT);
            }
            IS_RECORDING.store(false, Ordering::SeqCst);
            Self::set_cached_recording(false);
            false
        } else {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
            let path = format!("/tmp/zenith-record-{}.mp4", now);
            if let Ok(mut child) = Command::new("wf-recorder")
                .args(["-f", &path])
                .spawn()
            {
                std::thread::Builder::new()
                    .name("wf-recorder-wait".into())
                    .spawn(move || {
                        let _ = child.wait();
                        IS_RECORDING.store(false, Ordering::SeqCst);
                        Self::set_cached_recording(false);
                    })
                    .ok();
                IS_RECORDING.store(true, Ordering::SeqCst);
                Self::set_cached_recording(true);
                true
            } else {
                false
            }
        }
    }

    /// Capture a screenshot via `grim` and `slurp` (or whole screen) with zero shell forks.
    pub fn take_screenshot(area: bool) {
        std::thread::spawn(move || {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
            let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
            let dir = std::path::PathBuf::from(home).join("Pictures/Screenshots");
            let _ = std::fs::create_dir_all(&dir);
            let file_path = dir.join(format!("zenith-{}.png", now));
            let path_str = file_path.to_string_lossy().to_string();

            let grim_status = if area {
                if let Ok(slurp_out) = Command::new("slurp").output() {
                    if slurp_out.status.success() {
                        let geom = String::from_utf8_lossy(&slurp_out.stdout).trim().to_string();
                        if !geom.is_empty() {
                            Command::new("grim").args(["-g", &geom, &path_str]).status().ok()
                        } else {
                            None
                        }
                    } else {
                        None
                    }
                } else {
                    None
                }
            } else {
                Command::new("grim").arg(&path_str).status().ok()
            };

            if let Some(status) = grim_status {
                if status.success() && file_path.exists() {
                    if let Ok(file) = std::fs::File::open(&file_path) {
                        let _ = Command::new("wl-copy")
                            .args(["--type", "image/png"])
                            .stdin(file)
                            .spawn();
                    }
                }
            }
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_recorder_query() {
        let _ = RecorderService::is_recording();
    }

    #[test]
    fn test_find_recorder_pid_pure_proc() {
        let pid = RecorderService::find_recorder_pid();
        assert!(pid.is_none() || pid.unwrap() > 0);
    }
}
