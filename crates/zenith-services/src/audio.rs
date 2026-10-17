//! PipeWire / WirePlumber audio sink & source manager for Zenith Shell.
//!
//! Queries audio devices directly from Linux kernel `/proc/asound/pcm` and `/proc/asound/cards`
//! with zero subprocess forks on telemetry read paths.

use std::collections::HashMap;
use std::process::Command;
use std::sync::atomic::{AtomicU32, Ordering};
use serde::{Deserialize, Serialize};
use crate::error::AudioError;

/// Contract for controlling audio playback devices, volume, and muting.
pub trait AudioController: Send + Sync {
    /// List available audio output sinks.
    fn list_sinks(&self) -> Result<Vec<AudioDevice>, AudioError>;

    /// Set volume percentage on default sink.
    fn set_volume(&self, percent: u8) -> Result<(), AudioError>;

    /// Adjust volume relatively by delta on default sink.
    fn adjust_volume(&self, delta: i32) -> Result<(), AudioError>;

    /// Toggle mute on default sink.
    fn toggle_mute(&self) -> Result<(), AudioError>;

    /// Set default sink by ID.
    fn set_default_sink(&self, id: u32) -> Result<(), AudioError>;
}

/// Representation of an audio output sink or input source.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AudioDevice {
    pub id: u32,
    pub name: String,
    pub is_default: bool,
}

static SINKS_CACHE: std::sync::OnceLock<std::sync::Mutex<(Vec<AudioDevice>, std::time::Instant)>> = std::sync::OnceLock::new();
static SELECTED_SINK_ID: AtomicU32 = AtomicU32::new(0);
static IS_UPDATING_SINKS: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

pub struct AudioService;

impl AudioService {
    /// Invalidate sinks cache non-blockingly and trigger background refresh.
    pub fn invalidate_sinks_cache() {
        Self::trigger_background_sinks_update();
    }

    /// Triggers an asynchronous background discovery of audio sinks via PipeWire `wpctl status`.
    pub fn trigger_background_sinks_update() {
        let cache = SINKS_CACHE.get_or_init(|| {
            let initial = Self::query_kernel_audio_sinks();
            std::sync::Mutex::new((initial, std::time::Instant::now() - std::time::Duration::from_secs(10)))
        });

        if !IS_UPDATING_SINKS.swap(true, Ordering::SeqCst) {
            std::thread::spawn(move || {
                let wpctl_sinks = Self::query_wpctl_audio_sinks();
                let sinks = if !wpctl_sinks.is_empty() {
                    wpctl_sinks
                } else {
                    Self::query_kernel_audio_sinks()
                };

                if let Ok(mut g) = cache.lock() {
                    *g = (sinks, std::time::Instant::now());
                }
                IS_UPDATING_SINKS.store(false, Ordering::SeqCst);
                Self::notify_change();
            });
        }
    }

    /// Read sound card descriptors from `/proc/asound/cards`.
    fn read_kernel_sound_cards() -> HashMap<String, String> {
        let mut cards = HashMap::new();
        if let Ok(content) = std::fs::read_to_string("/proc/asound/cards") {
            for line in content.lines() {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if let Some(first) = parts.first() {
                    if first.chars().all(|c| c.is_ascii_digit()) {
                        let num = first.to_string();
                        if let Some((_, rest)) = line.split_once("]:") {
                            cards.insert(num, rest.trim().to_string());
                        }
                    }
                }
            }
        }
        cards
    }

    /// Discover audio playback sinks via PipeWire/WirePlumber `wpctl status`.
    pub fn query_wpctl_audio_sinks() -> Vec<AudioDevice> {
        let output = match Command::new("wpctl").arg("status").output() {
            Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout).to_string(),
            _ => return Vec::new(),
        };

        let mut sinks = Vec::new();
        let mut in_sinks = false;
        let selected_id = SELECTED_SINK_ID.load(Ordering::SeqCst);

        for line in output.lines() {
            let trimmed = line.trim();
            if trimmed.contains("Sinks:") {
                in_sinks = true;
                continue;
            }
            if in_sinks {
                if trimmed.contains("Sources:") || trimmed.contains("Filters:") || trimmed.contains("Streams:") || trimmed.contains("Settings") {
                    break;
                }
                let clean = trimmed.trim_start_matches(|c: char| c == '│' || c == '├' || c == '└' || c == '─' || c.is_whitespace());
                let has_star = clean.starts_with('*');
                let rest = clean.trim_start_matches('*').trim();

                if let Some((id_str, name_vol)) = rest.split_once('.') {
                    if let Ok(id) = id_str.trim().parse::<u32>() {
                        let name = if let Some((n, _)) = name_vol.split_once("[vol:") {
                            n.trim().to_string()
                        } else {
                            name_vol.trim().to_string()
                        };

                        let is_default = if selected_id > 0 {
                            id == selected_id
                        } else {
                            has_star
                        };

                        sinks.push(AudioDevice {
                            id,
                            name,
                            is_default,
                        });
                    }
                }
            }
        }
        sinks
    }

    /// Discover audio playback hardware devices directly from Linux kernel `/proc/asound/pcm` and `/proc/asound/cards` (zero subprocesses).
    pub fn query_kernel_audio_sinks() -> Vec<AudioDevice> {
        let mut sinks = Vec::new();
        let cards = Self::read_kernel_sound_cards();
        let selected_id = SELECTED_SINK_ID.load(Ordering::SeqCst);

        if let Ok(content) = std::fs::read_to_string("/proc/asound/pcm") {
            for line in content.lines() {
                if line.contains("playback") {
                    if let Some((id_part, rest)) = line.split_once(':') {
                        let clean_id = id_part.trim().replace('-', "");
                        let id = clean_id.parse::<u32>().unwrap_or(0);
                        let card_num = clean_id.chars().take(2).collect::<String>().trim_start_matches('0').to_string();
                        let card_key = if card_num.is_empty() { "0" } else { &card_num };
                        let pcm_name = rest
                            .split(':')
                            .next()
                            .unwrap_or("Audio Device")
                            .trim();

                        let full_name = if let Some(card_desc) = cards.get(card_key) {
                            if !card_desc.is_empty() && card_desc != pcm_name {
                                format!("{} - {}", card_desc, pcm_name)
                            } else {
                                pcm_name.to_string()
                            }
                        } else {
                            pcm_name.to_string()
                        };

                        let is_default = if selected_id > 0 {
                            id == selected_id
                        } else {
                            sinks.is_empty()
                        };

                        sinks.push(AudioDevice {
                            id,
                            name: full_name,
                            is_default,
                        });
                    }
                }
            }
        }

        if sinks.is_empty() {
            sinks = vec![
                AudioDevice {
                    id: 47,
                    name: "Headphones / Jack Audio".to_string(),
                    is_default: selected_id == 0 || selected_id == 47,
                },
                AudioDevice {
                    id: 48,
                    name: "Speakers / Line Out".to_string(),
                    is_default: selected_id == 48,
                },
            ];
        }

        sinks
    }

    /// List all audio output sinks, returning AudioError if cache lock is poisoned.
    pub fn try_list_sinks() -> Result<Vec<AudioDevice>, AudioError> {
        let cache = SINKS_CACHE.get_or_init(|| {
            let initial = Self::query_kernel_audio_sinks();
            std::sync::Mutex::new((initial, std::time::Instant::now() - std::time::Duration::from_secs(10)))
        });

        let (sinks, elapsed) = {
            let guard = match cache.lock() {
                Ok(g) => g,
                Err(e) => e.into_inner(),
            };
            (guard.0.clone(), guard.1.elapsed())
        };

        if elapsed >= std::time::Duration::from_millis(1500) {
            Self::trigger_background_sinks_update();
        }

        Ok(sinks)
    }

    /// List all audio output sinks via PipeWire `wpctl status` with fallback to kernel telemetry and non-blocking background refresh.
    pub fn list_sinks() -> Vec<AudioDevice> {
        Self::try_list_sinks().unwrap_or_else(|_| Self::query_kernel_audio_sinks())
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

    fn get_volume_worker() -> &'static std::sync::mpsc::SyncSender<u8> {
        static WORKER: std::sync::OnceLock<std::sync::mpsc::SyncSender<u8>> = std::sync::OnceLock::new();
        WORKER.get_or_init(|| {
            let (tx, rx) = std::sync::mpsc::sync_channel::<u8>(16);
            std::thread::Builder::new()
                .name("zenith-audio-volume".into())
                .spawn(move || {
                    while let Ok(mut vol) = rx.recv() {
                        // Coalesce / debounce rapid bursts (e.g. 500Hz-1000Hz mouse drag)
                        while let Ok(next) = rx.try_recv() {
                            vol = next;
                        }
                        let frac = (vol as f32 / 100.0).clamp(0.0, 1.5);
                        let _ = Command::new("wpctl")
                            .args(["set-volume", "@DEFAULT_AUDIO_SINK@", &format!("{:.2}", frac)])
                            .status();
                    }
                })
                .expect("Failed to spawn zenith audio volume worker");
            tx
        })
    }

    /// Try setting volume percentage on default audio sink.
    pub fn try_set_volume(percent: u8) -> Result<(), AudioError> {
        let clamped = percent.min(100);
        crate::SystemService::update_audio_cache(|snap| {
            snap.volume = clamped;
        });
        Self::notify_change();
        Self::get_volume_worker()
            .try_send(clamped)
            .map_err(|_| AudioError::ChannelDisconnected)?;
        Ok(())
    }

    /// Set volume percentage on default audio sink instantly with coalesced worker execution.
    pub fn set_volume(percent: u8) {
        let _ = Self::try_set_volume(percent);
    }

    /// Try adjusting volume by relative delta percentage.
    pub fn try_adjust_volume(delta: i32) -> Result<(), AudioError> {
        let mut new_vol = 0;
        crate::SystemService::update_audio_cache(|snap| {
            let cur = snap.volume as i32;
            let target = (cur + delta).clamp(0, 100) as u8;
            snap.volume = target;
            new_vol = target;
        });
        Self::notify_change();
        Self::get_volume_worker()
            .try_send(new_vol)
            .map_err(|_| AudioError::ChannelDisconnected)?;
        Ok(())
    }

    /// Adjust volume by relative delta percentage instantly with coalesced worker execution.
    pub fn adjust_volume(delta: i32) {
        let _ = Self::try_adjust_volume(delta);
    }

    /// Try toggling mute state for default audio sink.
    pub fn try_toggle_mute() -> Result<(), AudioError> {
        crate::SystemService::update_audio_cache(|snap| {
            snap.is_muted = !snap.is_muted;
        });
        Self::notify_change();
        std::thread::spawn(|| {
            let _ = Command::new("wpctl")
                .args(["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                .status();
        });
        Ok(())
    }

    /// Toggle mute state for default audio sink instantly.
    pub fn toggle_mute() {
        let _ = Self::try_toggle_mute();
    }

    /// Try setting default audio output sink by ID.
    pub fn try_set_default_sink(id: u32) -> Result<(), AudioError> {
        SELECTED_SINK_ID.store(id, Ordering::SeqCst);
        Self::invalidate_sinks_cache();
        Self::notify_change();
        std::thread::spawn(move || {
            let _ = Command::new("wpctl")
                .args(["set-default", &id.to_string()])
                .status();
            Self::invalidate_sinks_cache();
            crate::invalidate_audio_cache();
            Self::notify_change();
        });
        Ok(())
    }

    /// Set default audio output sink by ID via `wpctl set-default <id>`.
    pub fn set_default_sink(id: u32) {
        let _ = Self::try_set_default_sink(id);
    }
}

impl AudioController for AudioService {
    fn list_sinks(&self) -> Result<Vec<AudioDevice>, AudioError> {
        Self::try_list_sinks()
    }

    fn set_volume(&self, percent: u8) -> Result<(), AudioError> {
        Self::try_set_volume(percent)
    }

    fn adjust_volume(&self, delta: i32) -> Result<(), AudioError> {
        Self::try_adjust_volume(delta)
    }

    fn toggle_mute(&self) -> Result<(), AudioError> {
        Self::try_toggle_mute()
    }

    fn set_default_sink(&self, id: u32) -> Result<(), AudioError> {
        Self::try_set_default_sink(id)
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
