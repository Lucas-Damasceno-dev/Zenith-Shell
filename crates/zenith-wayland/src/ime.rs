//! Input Method & Dead-Key Composition Subsystem for Zenith Base v3.
//!
//! Provides ABNT2 / international dead-key composition (accents, tildes, cedillas)
//! and text-input focus management with visual focus rings.

use smithay_client_toolkit::seat::keyboard::Keysym;
use xkbcommon::xkb::compose::{self, State, Table};
use xkbcommon::xkb::Context;

/// Result of feeding a keysym to the XKB compose state machine.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ComposeResult {
    /// Sequence resolved to a composed UTF-8 character (e.g. dead_tilde + a -> "ã").
    Composed(String),
    /// State machine is actively buffering dead keys / multi-key sequence.
    Composing,
    /// Sequence was invalidated or cancelled.
    Cancelled,
    /// No compose sequence active for this key.
    Nothing,
}

/// Native XKB Compose State Machine leveraging system compose tables according to active locale.
pub struct XkbComposeTracker {
    state: Option<State>,
}

impl Default for XkbComposeTracker {
    fn default() -> Self {
        Self::new()
    }
}

impl XkbComposeTracker {
    /// Initializes compose table from system locale (LC_ALL / LC_CTYPE / LANG) with reliable UTF-8 fallback.
    pub fn new() -> Self {
        let ctx = Context::new(xkbcommon::xkb::CONTEXT_NO_FLAGS);
        let locale_str = std::env::var("LC_ALL")
            .or_else(|_| std::env::var("LC_CTYPE"))
            .or_else(|_| std::env::var("LANG"))
            .unwrap_or_else(|_| "C.UTF-8".to_string());

        let candidates = if locale_str == "C" || locale_str == "POSIX" || locale_str.is_empty() {
            vec!["C.UTF-8", "en_US.UTF-8", "pt_BR.UTF-8", "C"]
        } else {
            vec![locale_str.as_str(), "C.UTF-8", "en_US.UTF-8", "pt_BR.UTF-8", "C"]
        };

        let mut table = None;
        for loc in candidates {
            if let Ok(t) = Table::new_from_locale(&ctx, std::ffi::OsStr::new(loc), compose::COMPILE_NO_FLAGS) {
                table = Some(t);
                break;
            }
        }

        let state = table.map(|t| State::new(&t, compose::STATE_NO_FLAGS));

        Self { state }
    }

    /// Feeds a Wayland Keysym into the compose engine.
    pub fn feed(&mut self, keysym: Keysym) -> ComposeResult {
        if let Some(ref mut state) = self.state {
            state.feed(xkbcommon::xkb::Keysym::new(keysym.raw()));
            match state.status() {
                compose::Status::Composed => {
                    let res = state.utf8();
                    state.reset();
                    if let Some(utf8) = res {
                        ComposeResult::Composed(utf8)
                    } else {
                        ComposeResult::Cancelled
                    }
                }
                compose::Status::Composing => ComposeResult::Composing,
                compose::Status::Cancelled => {
                    state.reset();
                    ComposeResult::Cancelled
                }
                compose::Status::Nothing => ComposeResult::Nothing,
            }
        } else {
            ComposeResult::Nothing
        }
    }

    /// Resets any active composing buffer.
    pub fn reset(&mut self) {
        if let Some(ref mut state) = self.state {
            state.reset();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_xkb_compose_tracker_initialization() {
        let mut tracker = XkbComposeTracker::new();
        // Feeding a non-dead key should return Nothing
        assert_eq!(tracker.feed(Keysym::a), ComposeResult::Nothing);
        // Reset should not panic
        tracker.reset();
    }

    #[test]
    fn test_xkb_compose_dead_key_sequence() {
        let mut tracker = XkbComposeTracker::new();
        if tracker.state.is_some() {
            let r1 = tracker.feed(Keysym::dead_tilde);
            assert_eq!(r1, ComposeResult::Composing);
            let r2 = tracker.feed(Keysym::a);
            assert_eq!(r2, ComposeResult::Composed("ã".to_string()));
        }
    }
}
