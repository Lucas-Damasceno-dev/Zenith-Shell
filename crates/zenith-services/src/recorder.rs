//! Screen recording and snipping tool service for Zenith Shell.

use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};

static IS_RECORDING: AtomicBool = AtomicBool::new(false);

pub struct RecorderService;

impl RecorderService {
    fn find_recorder_pid() -> Option<i32> {
        if let Ok(entries) = std::fs::read_dir("/proc") {
            for entry in entries.flatten() {
                let name = entry.file_name();
                if let Some(s) = name.to_str() {
                    if s.chars().all(|c| c.is_ascii_digit()) {
                        let comm_path = entry.path().join("comm");
                        if let Ok(comm) = std::fs::read_to_string(comm_path) {
                            if comm.trim() == "wf-recorder" {
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
        if IS_RECORDING.load(Ordering::SeqCst) {
            return true;
        }

        if Self::find_recorder_pid().is_some() {
            IS_RECORDING.store(true, Ordering::SeqCst);
            return true;
        }

        false
    }

    /// Toggle screen recording via `wf-recorder`.
    pub fn toggle_recording() -> bool {
        if let Some(pid) = Self::find_recorder_pid() {
            unsafe {
                libc::kill(pid, libc::SIGINT);
            }
            IS_RECORDING.store(false, Ordering::SeqCst);
            false
        } else {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
            let path = format!("/tmp/zenith-record-{}.mp4", now);
            let _ = Command::new("wf-recorder")
                .args(["-f", &path])
                .spawn();
            IS_RECORDING.store(true, Ordering::SeqCst);
            true
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
