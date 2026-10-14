//! Wayland Idle Notification (`ext-idle-notify-v1`) and Idle Inhibition (`idle-inhibit-unstable-v1`) Subsystem.
//!
//! Provides native Wayland compositor idle monitoring and power-saving management:
//! - Tracks user activity and inactivity to allow the shell to turn off animations
//!   and conserve CPU/integrated GPU power when the workstation is unattended.
//! - Enables automatic or manual idle inhibition during media playback, fullscreen video,
//!   or presentations.
//! - Propagates activity and inactivity state transitions to the Zenith Luau runtime.

use std::collections::HashSet;
use std::time::{Duration, Instant};

use wayland_client::protocol::wl_seat::WlSeat;
use wayland_client::protocol::wl_surface::WlSurface;
use wayland_client::{Dispatch, Proxy, QueueHandle};
use wayland_protocols::ext::idle_notify::v1::client::ext_idle_notification_v1::ExtIdleNotificationV1;
use wayland_protocols::ext::idle_notify::v1::client::ext_idle_notifier_v1::ExtIdleNotifierV1;
use wayland_protocols::wp::idle_inhibit::zv1::client::zwp_idle_inhibit_manager_v1::ZwpIdleInhibitManagerV1;
use wayland_protocols::wp::idle_inhibit::zv1::client::zwp_idle_inhibitor_v1::ZwpIdleInhibitorV1;

/// Current idle state of the user / workstation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IdleStatus {
    /// User is actively interacting with the session.
    Active,
    /// User has been inactive for the configured timeout threshold.
    Idle,
}

/// Idle state transition event.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum IdleEvent {
    /// User transitioned to idle state.
    Idled { timeout_ms: u32, seat_id: u32 },
    /// User resumed activity from idle state.
    Resumed { seat_id: u32 },
    /// Idle inhibition state changed.
    InhibitChanged { inhibited: bool, reason: String },
}

/// User data attached to `ExtIdleNotificationV1` proxy instances.
#[derive(Debug, Clone, Copy)]
pub struct IdleNotificationData {
    pub seat_id: u32,
    pub timeout_ms: u32,
}

/// Manager coordinating Wayland idle notifications and idle inhibition.
pub struct IdleManager {
    /// Bound `ext-idle-notify-v1` global proxy, if supported by the compositor.
    pub notifier: Option<ExtIdleNotifierV1>,
    /// Bound `idle-inhibit-unstable-v1` global proxy, if supported by the compositor.
    pub inhibit_manager: Option<ZwpIdleInhibitManagerV1>,
    /// Active idle notifications registered per seat ID.
    pub notifications: Vec<(u32, ExtIdleNotificationV1)>,
    /// Active idle inhibitors registered per reason tag.
    pub inhibitors: Vec<(String, ZwpIdleInhibitorV1)>,
    /// Whether user is currently idle.
    pub is_idle: bool,
    /// Configured timeout threshold in milliseconds before firing idle notification.
    pub timeout_ms: u32,
    /// Instant when user activity was last confirmed.
    pub last_activity: Instant,
    /// Instant when idle was triggered, if currently idle.
    pub idled_at: Option<Instant>,
    /// Set of active inhibition reason tags (e.g. "media", "fullscreen").
    pub active_inhibitors: HashSet<String>,
}

impl IdleManager {
    /// Default idle timeout: 30,000 milliseconds (30 seconds).
    pub const DEFAULT_IDLE_TIMEOUT_MS: u32 = 30_000;

    /// Creates a new `IdleManager` with default timeout.
    pub fn new() -> Self {
        Self::with_timeout(Self::DEFAULT_IDLE_TIMEOUT_MS)
    }

    /// Creates a new `IdleManager` with a custom idle timeout in milliseconds.
    pub fn with_timeout(timeout_ms: u32) -> Self {
        Self {
            notifier: None,
            inhibit_manager: None,
            notifications: Vec::new(),
            inhibitors: Vec::new(),
            is_idle: false,
            timeout_ms: timeout_ms.max(100),
            last_activity: Instant::now(),
            idled_at: None,
            active_inhibitors: HashSet::new(),
        }
    }

    /// Configured idle timeout in milliseconds.
    #[inline]
    pub fn timeout_ms(&self) -> u32 {
        self.timeout_ms
    }

    /// Sets the idle timeout in milliseconds.
    pub fn set_timeout_ms(&mut self, timeout_ms: u32) {
        self.timeout_ms = timeout_ms.max(100);
    }

    /// Returns `true` if the session is currently idle.
    #[inline]
    pub fn is_idle(&self) -> bool {
        self.is_idle
    }

    /// Returns `true` if idle inhibition is active (inhibiting idle sleep/dimming).
    #[inline]
    pub fn is_inhibited(&self) -> bool {
        !self.active_inhibitors.is_empty()
    }

    /// Returns `true` if animations and periodic rendering should be paused to conserve power.
    ///
    /// Animations are paused when user is idle AND idle is not actively inhibited
    /// (e.g. paused unless media playback or fullscreen mode explicitly requested active state).
    #[inline]
    pub fn should_pause_animations(&self) -> bool {
        self.is_idle && !self.is_inhibited()
    }

    /// Returns `true` if `ext-idle-notify-v1` is bound.
    #[inline]
    pub fn has_notifier(&self) -> bool {
        self.notifier.is_some()
    }

    /// Returns `true` if `idle-inhibit-unstable-v1` is bound.
    #[inline]
    pub fn has_inhibit_manager(&self) -> bool {
        self.inhibit_manager.is_some()
    }

    /// Registers an idle notification for the given Wayland seat.
    ///
    /// Returns `true` if the notification was successfully requested from the compositor.
    pub fn register_seat<D>(&mut self, seat: &WlSeat, qh: &QueueHandle<D>) -> bool
    where
        D: Dispatch<ExtIdleNotificationV1, IdleNotificationData> + 'static,
    {
        let seat_id = seat.id().protocol_id();

        // Avoid duplicate notification registration for the same seat
        if self.notifications.iter().any(|(id, _)| *id == seat_id) {
            return false;
        }

        if let Some(ref notifier) = self.notifier {
            let udata = IdleNotificationData {
                seat_id,
                timeout_ms: self.timeout_ms,
            };
            let notif = notifier.get_idle_notification(self.timeout_ms, seat, qh, udata);
            self.notifications.push((seat_id, notif));
            true
        } else {
            false
        }
    }

    /// Unregisters and destroys idle notification for the given Wayland seat.
    pub fn unregister_seat(&mut self, seat: &WlSeat) -> bool {
        let seat_id = seat.id().protocol_id();
        if let Some(idx) = self.notifications.iter().position(|(id, _)| *id == seat_id) {
            let (_, notif) = self.notifications.remove(idx);
            notif.destroy();
            true
        } else {
            false
        }
    }

    /// Creates an idle inhibitor for a target Wayland surface.
    ///
    /// Keeps compositor active and prevents idle timeout triggers while surface is visible.
    pub fn inhibit_idle<D>(&mut self, surface: &WlSurface, qh: &QueueHandle<D>, reason: &str) -> bool
    where
        D: Dispatch<ZwpIdleInhibitorV1, ()> + 'static,
    {
        if let Some(ref mgr) = self.inhibit_manager {
            let inhibitor = mgr.create_inhibitor(surface, qh, ());
            self.inhibitors.push((reason.to_string(), inhibitor));
            self.active_inhibitors.insert(reason.to_string());
            true
        } else {
            // Track fallback logical inhibition even if compositor lacks protocol global
            self.active_inhibitors.insert(reason.to_string());
            false
        }
    }

    /// Removes and destroys idle inhibitor(s) associated with a reason tag.
    pub fn uninhibit_idle(&mut self, reason: &str) -> bool {
        let removed_reason = self.active_inhibitors.remove(reason);

        let mut destroyed_any = false;
        self.inhibitors.retain(|(r, inhibitor)| {
            if r == reason {
                inhibitor.destroy();
                destroyed_any = true;
                false
            } else {
                true
            }
        });

        removed_reason || destroyed_any
    }

    /// Destroys all active inhibitors and clears inhibition state.
    pub fn uninhibit_all(&mut self) {
        for (_, inhibitor) in self.inhibitors.drain(..) {
            inhibitor.destroy();
        }
        self.active_inhibitors.clear();
    }

    /// Handles compositor `idled` event on a seat.
    pub fn on_idled(&mut self, seat_id: u32) -> IdleEvent {
        self.is_idle = true;
        self.idled_at = Some(Instant::now());
        IdleEvent::Idled {
            timeout_ms: self.timeout_ms,
            seat_id,
        }
    }

    /// Handles compositor `resumed` event on a seat.
    pub fn on_resumed(&mut self, seat_id: u32) -> IdleEvent {
        self.is_idle = false;
        self.idled_at = None;
        self.last_activity = Instant::now();
        IdleEvent::Resumed { seat_id }
    }

    /// Duration that user has been idle, if currently idle.
    pub fn idle_duration(&self) -> Option<Duration> {
        self.idled_at.map(|t| t.elapsed())
    }

    /// Duration since last confirmed user activity.
    #[inline]
    pub fn time_since_last_activity(&self) -> Duration {
        self.last_activity.elapsed()
    }

    /// Cleanly releases all notifications and inhibitor proxies.
    pub fn destroy_all(&mut self) {
        for (_, notif) in self.notifications.drain(..) {
            notif.destroy();
        }
        for (_, inhibitor) in self.inhibitors.drain(..) {
            inhibitor.destroy();
        }
        if let Some(notifier) = self.notifier.take() {
            notifier.destroy();
        }
        if let Some(mgr) = self.inhibit_manager.take() {
            mgr.destroy();
        }
        self.active_inhibitors.clear();
    }
}

impl Default for IdleManager {
    fn default() -> Self {
        Self::new()
    }
}

impl Drop for IdleManager {
    fn drop(&mut self) {
        self.destroy_all();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_idle_manager_defaults() {
        let mgr = IdleManager::new();
        assert_eq!(mgr.timeout_ms(), IdleManager::DEFAULT_IDLE_TIMEOUT_MS);
        assert!(!mgr.is_idle());
        assert!(!mgr.is_inhibited());
        assert!(!mgr.should_pause_animations());
        assert!(mgr.idle_duration().is_none());
    }

    #[test]
    fn test_idle_transition_lifecycle() {
        let mut mgr = IdleManager::with_timeout(15_000);
        assert_eq!(mgr.timeout_ms(), 15_000);

        // Transition to idle
        let ev = mgr.on_idled(1);
        assert_eq!(
            ev,
            IdleEvent::Idled {
                timeout_ms: 15_000,
                seat_id: 1
            }
        );
        assert!(mgr.is_idle());
        assert!(mgr.should_pause_animations());
        assert!(mgr.idle_duration().is_some());

        // Resume activity
        let resume_ev = mgr.on_resumed(1);
        assert_eq!(resume_ev, IdleEvent::Resumed { seat_id: 1 });
        assert!(!mgr.is_idle());
        assert!(!mgr.should_pause_animations());
        assert!(mgr.idle_duration().is_none());
    }

    #[test]
    fn test_idle_inhibition_preserves_animations() {
        let mut mgr = IdleManager::new();

        // Add logical inhibitor (e.g. media playback)
        mgr.active_inhibitors.insert("media_playback".to_string());
        assert!(mgr.is_inhibited());

        // Even if user goes idle, animations should NOT pause because of inhibition
        mgr.on_idled(1);
        assert!(mgr.is_idle());
        assert!(!mgr.should_pause_animations());

        // Release inhibition
        assert!(mgr.uninhibit_idle("media_playback"));
        assert!(!mgr.is_inhibited());
        assert!(mgr.should_pause_animations()); // Now animations pause!
    }

    #[test]
    fn test_uninhibit_all() {
        let mut mgr = IdleManager::new();
        mgr.active_inhibitors.insert("media".to_string());
        mgr.active_inhibitors.insert("fullscreen".to_string());
        assert!(mgr.is_inhibited());

        mgr.uninhibit_all();
        assert!(!mgr.is_inhibited());
        assert!(mgr.active_inhibitors.is_empty());
    }
}
