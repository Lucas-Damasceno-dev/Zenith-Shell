//! Wayland Pointer Gestures Subsystem (`zwp_pointer_gestures_v1`) for Zenith Base v3.
//!
//! Handles touchpad swipe and pinch-to-zoom gestures, coupling kinetic inertia
//! with containers having `overflow = "scroll"` and dispatching events to Luau.

use wayland_protocols::wp::pointer_gestures::zv1::client::{
    zwp_pointer_gesture_pinch_v1::ZwpPointerGesturePinchV1,
    zwp_pointer_gesture_swipe_v1::ZwpPointerGestureSwipeV1,
    zwp_pointer_gestures_v1::ZwpPointerGesturesV1,
};
use zenith_core::KineticScrollEngine;

/// Lifecycle phase of an interactive touchpad gesture.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GesturePhase {
    Begin,
    Update,
    End,
    Cancel,
}

/// Touchpad multi-finger swipe event data.
#[derive(Debug, Clone, PartialEq)]
pub struct SwipeGestureEvent {
    pub fingers: u32,
    pub dx: f64,
    pub dy: f64,
    pub phase: GesturePhase,
}

/// Touchpad pinch-to-zoom / rotation gesture event data.
#[derive(Debug, Clone, PartialEq)]
pub struct PinchGestureEvent {
    pub fingers: u32,
    pub dx: f64,
    pub dy: f64,
    pub scale: f64,
    pub rotation: f64,
    pub phase: GesturePhase,
}

/// Manager for Wayland pointer gesture tracking and kinetic scroll coupling.
#[derive(Debug, Default)]
pub struct PointerGesturesManager {
    pub gestures_global: Option<ZwpPointerGesturesV1>,
    pub swipe_gesture: Option<ZwpPointerGestureSwipeV1>,
    pub pinch_gesture: Option<ZwpPointerGesturePinchV1>,
    pub kinetic_scroll: KineticScrollEngine,
    pub active_swipe: Option<SwipeGestureEvent>,
    pub active_pinch: Option<PinchGestureEvent>,
}

impl PointerGesturesManager {
    /// Creates a new `PointerGesturesManager`.
    pub fn new() -> Self {
        Self {
            gestures_global: None,
            swipe_gesture: None,
            pinch_gesture: None,
            kinetic_scroll: KineticScrollEngine::new(0.0, 1000.0),
            active_swipe: None,
            active_pinch: None,
        }
    }

    /// Handles touchpad swipe motion and feeds kinetic scroll physics.
    pub fn handle_swipe_update(&mut self, fingers: u32, dx: f64, dy: f64) -> SwipeGestureEvent {
        // Feed kinetic impulse in the vertical scroll direction
        self.kinetic_scroll.add_impulse(dy as f32);

        let event = SwipeGestureEvent {
            fingers,
            dx,
            dy,
            phase: GesturePhase::Update,
        };
        self.active_swipe = Some(event.clone());
        event
    }

    /// Handles touchpad swipe end.
    pub fn handle_swipe_end(&mut self, cancelled: bool) -> SwipeGestureEvent {
        let phase = if cancelled { GesturePhase::Cancel } else { GesturePhase::End };
        let event = SwipeGestureEvent {
            fingers: self.active_swipe.as_ref().map(|s| s.fingers).unwrap_or(2),
            dx: 0.0,
            dy: 0.0,
            phase,
        };
        if cancelled {
            self.kinetic_scroll.stop();
        }
        self.active_swipe = None;
        event
    }

    /// Handles pinch-to-zoom update.
    pub fn handle_pinch_update(&mut self, fingers: u32, dx: f64, dy: f64, scale: f64, rotation: f64) -> PinchGestureEvent {
        let event = PinchGestureEvent {
            fingers,
            dx,
            dy,
            scale,
            rotation,
            phase: GesturePhase::Update,
        };
        self.active_pinch = Some(event.clone());
        event
    }

    /// Advances kinetic scroll inertia during animation frames.
    #[inline]
    pub fn step_scroll(&mut self, dt: f32) -> f32 {
        self.kinetic_scroll.step(dt)
    }

    /// Checks if kinetic scroll animation is settled.
    #[inline]
    pub fn is_scroll_settled(&self) -> bool {
        self.kinetic_scroll.is_settled()
    }
}



#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gesture_swipe_feeds_kinetic_scroll() {
        let mut mgr = PointerGesturesManager::new();
        assert!(mgr.is_scroll_settled());

        // 2-finger swipe down
        let event = mgr.handle_swipe_update(2, 0.0, 15.0);
        assert_eq!(event.fingers, 2);
        assert_eq!(event.dy, 15.0);
        assert!(!mgr.is_scroll_settled());

        // Step simulation forward: scroll offset should increase smoothly
        let s1 = mgr.step_scroll(0.016);
        let s2 = mgr.step_scroll(0.016);
        assert!(s2 > s1);

        // End swipe
        let end = mgr.handle_swipe_end(false);
        assert_eq!(end.phase, GesturePhase::End);
    }

    #[test]
    fn test_pinch_update_event() {
        let mut mgr = PointerGesturesManager::new();
        let pinch = mgr.handle_pinch_update(2, 5.0, 2.0, 1.25, 0.05);
        assert_eq!(pinch.scale, 1.25);
        assert_eq!(pinch.fingers, 2);
        assert_eq!(pinch.phase, GesturePhase::Update);
    }
}
