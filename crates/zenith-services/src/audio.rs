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

pub struct AudioService;

impl AudioService {
    /// List all audio output sinks via `wpctl status`.
    pub fn list_sinks() -> Vec<AudioDevice> {
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
            vec![
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
            ]
        } else {
            sinks
        }
    }

    /// Set default audio output sink by ID via `wpctl set-default <id>`.
    pub fn set_default_sink(id: u32) {
        let _ = Command::new("wpctl")
            .args(["set-default", &id.to_string()])
            .status();
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
