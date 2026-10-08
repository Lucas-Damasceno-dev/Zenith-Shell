//! Audio Spectrum / CAVA visualizer service for Zenith Shell.
//!
//! Reads real-time frequency band levels from `/tmp/cava.fifo` or simulates
//! dynamic reactive audio waveforms when MPRIS media is playing.

use std::io::Read;
use std::os::unix::fs::OpenOptionsExt;
use std::path::PathBuf;
use std::sync::OnceLock;
use std::time::Instant;

static START: OnceLock<Instant> = OnceLock::new();

pub struct CavaService;

impl CavaService {
    /// Retrieve normalized spectrum bars levels between 0.0 and 1.0.
    pub fn spectrum(bar_count: usize) -> Vec<f32> {
        let count = bar_count.clamp(4, 32);

        // 1. Try reading real FIFO
        if let Some(fifo_path) = find_fifo() {
            if let Ok(mut file) = std::fs::OpenOptions::new()
                .read(true)
                .custom_flags(libc::O_NONBLOCK)
                .open(&fifo_path)
            {
                let mut buf = [0u8; 256];
                if let Ok(n) = file.read(&mut buf) {
                    if n > 0 {
                        let text = String::from_utf8_lossy(&buf[..n]);
                        if let Some(last_line) = text.lines().last() {
                            let mut parsed = Vec::new();
                            for token in last_line.split(';') {
                                if let Ok(val) = token.trim().parse::<f32>() {
                                    parsed.push((val / 100.0).clamp(0.0, 1.0));
                                }
                            }
                            if !parsed.is_empty() {
                                parsed.resize(count, 0.0);
                                return parsed;
                            }
                        }
                    }
                }
            }
        }

        // 2. Dynamic reactive audio simulation synced with MPRIS media
        let mpris = crate::mpris::MprisService::snapshot();
        let start = START.get_or_init(Instant::now);

        if mpris.is_available && mpris.status == "Playing" {
            let t = start.elapsed().as_secs_f32() * 6.0;
            (0..count)
                .map(|i| {
                    let phase = i as f32 * 0.75;
                    let v = (t * 1.8 + phase).sin().abs() * 0.55
                        + (t * 3.2 + phase * 1.6).cos().abs() * 0.35
                        + 0.1;
                    v.clamp(0.08, 1.0)
                })
                .collect()
        } else {
            vec![0.04; count]
        }
    }
}

fn find_fifo() -> Option<PathBuf> {
    let uid = unsafe { libc::getuid() };
    let candidates = [
        PathBuf::from("/tmp/cava.fifo"),
        PathBuf::from("/tmp/mpd.fifo"),
        PathBuf::from(format!("/run/user/{}/cava.fifo", uid)),
    ];

    for c in &candidates {
        if c.exists() {
            return Some(c.clone());
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_spectrum_generation() {
        let bars = CavaService::spectrum(8);
        assert_eq!(bars.len(), 8);
        for b in bars {
            assert!((0.0..=1.0).contains(&b));
        }
    }
}
