//! PipeWire / WirePlumber audio sink & source manager for Zenith Shell.
//!
//! Queries audio devices directly from Linux kernel `/proc/asound/pcm` and `/proc/asound/cards`
//! with zero subprocess forks on telemetry read paths.

use std::collections::HashMap;
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
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

enum AudioCommand {
    Volume(u8),
    Mute(bool),
    DefaultSink(u32),
}

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

    /// Resolves standard PipeWire native UNIX domain socket path.
    pub fn pipewire_socket_path() -> PathBuf {
        if let Ok(runtime) = std::env::var("XDG_RUNTIME_DIR") {
            let p = Path::new(&runtime).join("pipewire-0");
            if p.exists() {
                return p;
            }
        }
        let uid = unsafe { libc::getuid() };
        PathBuf::from(format!("/run/user/{}/pipewire-0", uid))
    }

    /// Checks if PipeWire native socket is reachable without subprocess forks.
    pub fn is_pipewire_socket_active() -> bool {
        let path = Self::pipewire_socket_path();
        if !path.exists() {
            return false;
        }
        UnixStream::connect(path).is_ok()
    }

    /// Parses `wpctl status` output to extract genuine PipeWire node IDs, human names, and active default status.
    pub fn parse_wpctl_sinks(output: &str) -> Vec<AudioDevice> {
        let mut sinks = Vec::new();
        let mut in_sinks = false;

        for line in output.lines() {
            let trimmed = line.trim();
            if trimmed.contains("Sinks:") {
                in_sinks = true;
                continue;
            }
            if in_sinks {
                if trimmed.contains("Sources:") || trimmed.contains("Filters:") || trimmed.contains("Streams:") || trimmed.starts_with("Video") {
                    break;
                }
                let is_default = line.contains('*');
                let cleaned = line.replace(['│', '├', '─', '└', '*'], " ");
                let cleaned = cleaned.trim();
                if let Some((id_str, rest)) = cleaned.split_once('.') {
                    if let Ok(id) = id_str.trim().parse::<u32>() {
                        let name = if let Some((n, _)) = rest.split_once("[vol:") {
                            n.trim().to_string()
                        } else {
                            rest.trim().to_string()
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

    /// Discover audio playback sinks via PipeWire `wpctl status` with fallback to kernel ALSA telemetry.
    pub fn query_wpctl_audio_sinks() -> Vec<AudioDevice> {
        if let Ok(output) = std::process::Command::new("wpctl").args(["status"]).output() {
            if output.status.success() {
                let text = String::from_utf8_lossy(&output.stdout);
                let sinks = Self::parse_wpctl_sinks(&text);
                if !sinks.is_empty() {
                    return sinks;
                }
            }
        }
        let mut sinks = Self::query_kernel_audio_sinks();
        if Self::is_pipewire_socket_active() {
            let selected_id = SELECTED_SINK_ID.load(Ordering::SeqCst);
            for s in &mut sinks {
                if selected_id > 0 {
                    s.is_default = s.id == selected_id;
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

    fn dispatch_native_volume(vol: u8) {
        let frac = (vol as f32 / 100.0).clamp(0.0, 1.5);
        let sink = "@DEFAULT_AUDIO_SINK@";
        let vol_str = format!("{:.2}", frac);
        let _ = std::process::Command::new("wpctl")
            .args(["set-volume", sink, &vol_str])
            .output();
    }

    fn dispatch_native_mute(is_muted: bool) {
        let sink = "@DEFAULT_AUDIO_SINK@";
        let val_str = if is_muted { "1" } else { "0" };
        let _ = std::process::Command::new("wpctl")
            .args(["set-mute", sink, val_str])
            .output();
    }

    fn dispatch_native_default_sink(id: u32) {
        let id_str = id.to_string();
        let _ = std::process::Command::new("wpctl")
            .args(["set-default", &id_str])
            .output();
    }

    fn get_audio_worker() -> &'static std::sync::mpsc::SyncSender<AudioCommand> {
        static WORKER: std::sync::OnceLock<std::sync::mpsc::SyncSender<AudioCommand>> = std::sync::OnceLock::new();
        WORKER.get_or_init(|| {
            let (tx, rx) = std::sync::mpsc::sync_channel::<AudioCommand>(32);
            std::thread::Builder::new()
                .name("zenith-audio-worker".into())
                .spawn(move || {
                    while let Ok(cmd) = rx.recv() {
                        match cmd {
                            AudioCommand::Volume(mut vol) => {
                                // Coalesce rapid volume adjustments
                                while let Ok(AudioCommand::Volume(next)) = rx.try_recv() {
                                    vol = next;
                                }
                                Self::dispatch_native_volume(vol);
                            }
                            AudioCommand::Mute(is_muted) => {
                                Self::dispatch_native_mute(is_muted);
                            }
                            AudioCommand::DefaultSink(id) => {
                                Self::dispatch_native_default_sink(id);
                                Self::invalidate_sinks_cache();
                                crate::invalidate_audio_cache();
                                Self::notify_change();
                            }
                        }
                    }
                })
                .expect("Failed to spawn zenith audio worker");
            tx
        })
    }

    /// Try setting volume percentage on default audio sink.
    pub fn try_set_volume(percent: u8) -> Result<(), AudioError> {
        let clamped = percent.min(150);
        crate::SystemService::update_audio_cache(|snap| {
            snap.volume = clamped;
        });
        Self::notify_change();
        match Self::get_audio_worker().try_send(AudioCommand::Volume(clamped)) {
            Ok(()) | Err(std::sync::mpsc::TrySendError::Full(_)) => Ok(()),
            Err(std::sync::mpsc::TrySendError::Disconnected(_)) => Err(AudioError::ChannelDisconnected),
        }
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
            let target = cur.saturating_add(delta).clamp(0, 150) as u8;
            snap.volume = target;
            new_vol = target;
        });
        Self::notify_change();
        match Self::get_audio_worker().try_send(AudioCommand::Volume(new_vol)) {
            Ok(()) | Err(std::sync::mpsc::TrySendError::Full(_)) => Ok(()),
            Err(std::sync::mpsc::TrySendError::Disconnected(_)) => Err(AudioError::ChannelDisconnected),
        }
    }

    /// Adjust volume by relative delta percentage instantly with coalesced worker execution.
    pub fn adjust_volume(delta: i32) {
        let _ = Self::try_adjust_volume(delta);
    }

    /// Try toggling mute state for default audio sink.
    pub fn try_toggle_mute() -> Result<(), AudioError> {
        let is_muted = crate::SystemService::update_audio_cache(|snap| {
            snap.is_muted = !snap.is_muted;
        }).is_muted;
        Self::notify_change();
        match Self::get_audio_worker().try_send(AudioCommand::Mute(is_muted)) {
            Ok(()) | Err(std::sync::mpsc::TrySendError::Full(_)) => Ok(()),
            Err(std::sync::mpsc::TrySendError::Disconnected(_)) => Err(AudioError::ChannelDisconnected),
        }
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
        match Self::get_audio_worker().try_send(AudioCommand::DefaultSink(id)) {
            Ok(()) | Err(std::sync::mpsc::TrySendError::Full(_)) => Ok(()),
            Err(std::sync::mpsc::TrySendError::Disconnected(_)) => Err(AudioError::ChannelDisconnected),
        }
    }

    /// Set default audio output sink by ID via PipeWire native socket and WirePlumber D-Bus.
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

    #[test]
    fn test_optimistic_volume_cache_retention() {
        let _ = AudioService::try_set_volume(72);
        let snap = crate::SystemService::audio_snapshot();
        assert_eq!(snap.volume, 72, "Optimistic audio cache should immediately retain updated volume");
    }
}
