//! Screen recording and snipping tool service for Zenith Shell.

use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};

static IS_RECORDING: AtomicBool = AtomicBool::new(false);

pub struct RecorderService;

impl RecorderService {
    /// Whether screen recording is currently active.
    pub fn is_recording() -> bool {
        // Check atomic flag or check if wf-recorder / obs is running
        if IS_RECORDING.load(Ordering::SeqCst) {
            return true;
        }

        if let Ok(out) = Command::new("pgrep").arg("-x").arg("wf-recorder").output() {
            if out.status.success() {
                IS_RECORDING.store(true, Ordering::SeqCst);
                return true;
            }
        }

        false
    }

    /// Toggle screen recording via `wf-recorder`.
    pub fn toggle_recording() -> bool {
        if Self::is_recording() {
            let _ = Command::new("pkill").arg("-INT").arg("wf-recorder").status();
            IS_RECORDING.store(false, Ordering::SeqCst);
            false
        } else {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
            let path = format!("/tmp/zenith-record-{}.mp4", now);
            let _ = Command::new("sh")
                .arg("-c")
                .arg(format!("wf-recorder -f {} &", path))
                .spawn();
            IS_RECORDING.store(true, Ordering::SeqCst);
            true
        }
    }

    /// Capture a screenshot via `grim` and `slurp` (or whole screen).
    pub fn take_screenshot(area: bool) {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
        let path = format!("{}/Pictures/Screenshots/zenith-{}.png", home, now);

        let cmd = if area {
            format!("mkdir -p ~/Pictures/Screenshots && grim -g \"$(slurp)\" {} && wl-copy < {}", path, path)
        } else {
            format!("mkdir -p ~/Pictures/Screenshots && grim {} && wl-copy < {}", path, path)
        };

        let _ = Command::new("sh").arg("-c").arg(cmd).spawn();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_recorder_query() {
        let _ = RecorderService::is_recording();
    }
}
