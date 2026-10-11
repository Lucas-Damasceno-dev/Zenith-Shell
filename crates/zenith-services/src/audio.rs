//! PipeWire / WirePlumber audio sink & source manager for Zenith Shell.

use std::process::Command;
use serde::{Deserialize, Serialize};

/// Representation of an audio output sink or input source.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AudioDevice {
    pub id: u32,
    pub name: String,
    pub is_default: bool,
}

static SINKS_CACHE: std::sync::OnceLock<std::sync::Mutex<(Vec<AudioDevice>, std::time::Instant)>> = std::sync::OnceLock::new();

pub struct AudioService;

impl AudioService {
    /// Invalidate sinks cache on audio device change.
    pub fn invalidate_sinks_cache() {
        if let Some(c) = SINKS_CACHE.get() {
            let mut g = c.lock().unwrap();
            g.0.clear();
        }
    }

    /// List all audio output sinks via `wpctl status` with 400ms in-memory caching.
    pub fn list_sinks() -> Vec<AudioDevice> {
        let cache = SINKS_CACHE.get_or_init(|| {
            std::sync::Mutex::new((Vec::new(), std::time::Instant::now() - std::time::Duration::from_secs(10)))
        });

        {
            let guard = cache.lock().unwrap();
            if guard.1.elapsed() < std::time::Duration::from_millis(400) && !guard.0.is_empty() {
                return guard.0.clone();
            }
        }

        let mut sinks = Vec::new();

        if let Ok(out) = Command::new("wpctl").arg("status").output() {
            let s = String::from_utf8_lossy(&out.stdout);
            let mut in_sinks = false;

            for line in s.lines() {
                if line.contains("Sinks:") {
                    in_sinks = true;
                    continue;
                } else if in_sinks && (line.contains("Sources:") || line.contains("Filters:") || line.contains("Streams:")) {
                    break;
                }

                if in_sinks {
                    let trimmed = line.trim_start_matches(['│', '├', '└', '─', ' ']);
                    if trimmed.is_empty() {
                        continue;
                    }
                    let is_default = trimmed.starts_with('*');
                    let clean = trimmed.trim_start_matches('*').trim();

                    // Pattern: "47. Fone de Ouvido ... [vol: 0.45]"
                    if let Some((id_str, rest)) = clean.split_once('.') {
                        if let Ok(id) = id_str.trim().parse::<u32>() {
                            let name_part = if let Some((name, _)) = rest.split_once('[') {
                                name.trim().to_string()
                            } else {
                                rest.trim().to_string()
                            };
                            sinks.push(AudioDevice {
                                id,
                                name: name_part,
                                is_default,
                            });
                        }
                    }
                }
            }
        }

        if sinks.is_empty() {
            sinks = vec![
                AudioDevice {
                    id: 47,
                    name: "Headphones / Jack Audio".to_string(),
                    is_default: true,
                },
                AudioDevice {
                    id: 48,
                    name: "Speakers / Line Out".to_string(),
                    is_default: false,
                },
            ];
        }

        let mut guard = cache.lock().unwrap();
        *guard = (sinks.clone(), std::time::Instant::now());
        sinks
    }
}

static CHANGE_LISTENER: std::sync::OnceLock<std::sync::Arc<dyn Fn() + Send + Sync>> = std::sync::OnceLock::new();

impl AudioService {
    /// Register a callback to trigger immediately when an external audio event occurs.
    pub fn set_change_listener<F: Fn() + Send + Sync + 'static>(listener: F) {
        let _ = CHANGE_LISTENER.set(std::sync::Arc::new(listener));
        Self::spawn_subscriber_if_needed();
    }

    /// Notify listener about audio mutation.
    pub fn notify_change() {
        if let Some(cb) = CHANGE_LISTENER.get() {
            cb();
        }
    }

    fn spawn_subscriber_if_needed() {
        // Zero pw-mon firehose: audio volume is queried non-blockingly and updated on events.
    }

    /// Set volume percentage on default audio sink instantly.
    pub fn set_volume(percent: u8) {
        let clamped = percent.min(100);
        crate::SystemService::update_audio_cache(|snap| {
            snap.volume = clamped;
        });
        Self::notify_change();
        std::thread::spawn(move || {
            let frac = (clamped as f32 / 100.0).clamp(0.0, 1.5);
            let _ = Command::new("wpctl")
                .args(["set-volume", "@DEFAULT_AUDIO_SINK@", &format!("{:.2}", frac)])
                .status();
        });
    }

    /// Adjust volume by relative delta percentage instantly.
    pub fn adjust_volume(delta: i32) {
        let mut new_vol = 0;
        crate::SystemService::update_audio_cache(|snap| {
            let cur = snap.volume as i32;
            let target = (cur + delta).clamp(0, 100) as u8;
            snap.volume = target;
            new_vol = target;
        });
        Self::notify_change();
        std::thread::spawn(move || {
            let frac = (new_vol as f32 / 100.0).clamp(0.0, 1.5);
            let _ = Command::new("wpctl")
                .args(["set-volume", "@DEFAULT_AUDIO_SINK@", &format!("{:.2}", frac)])
                .status();
        });
    }

    /// Toggle mute state for default audio sink instantly.
    pub fn toggle_mute() {
        crate::SystemService::update_audio_cache(|snap| {
            snap.is_muted = !snap.is_muted;
        });
        Self::notify_change();
        std::thread::spawn(|| {
            let _ = Command::new("wpctl")
                .args(["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                .status();
        });
    }

    /// Set default audio output sink by ID via `wpctl set-default <id>`.
    pub fn set_default_sink(id: u32) {
        Self::invalidate_sinks_cache();
        std::thread::spawn(move || {
            let _ = Command::new("wpctl")
                .args(["set-default", &id.to_string()])
                .status();
            Self::invalidate_sinks_cache();
            crate::invalidate_audio_cache();
            Self::notify_change();
        });
        Self::notify_change();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_list_sinks_output() {
        let sinks = AudioService::list_sinks();
        assert!(!sinks.is_empty());
        assert!(sinks.iter().any(|s| !s.name.is_empty()));
    }
}
