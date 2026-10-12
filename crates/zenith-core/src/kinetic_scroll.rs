//! Kinetic Inertial Scroll Engine for Zenith-Shell.
//!
//! Provides natural inertial scrolling with exponential friction,
//! damped momentum deceleration, and spring-based rubber-band overscroll.

use crate::spring::{SpringAnimation, SpringConfig};

/// State and physics engine for kinetic inertial scrolling.
#[derive(Debug, Clone)]
pub struct KineticScrollEngine {
    pub offset: f32,
    pub velocity: f32,
    pub min_offset: f32,
    pub max_offset: f32,
    pub friction: f32,
    pub spring: SpringAnimation,
    pub in_overscroll: bool,
}

impl Default for KineticScrollEngine {
    fn default() -> Self {
        Self::new(0.0, 0.0)
    }
}

impl KineticScrollEngine {
    /// Creates a new `KineticScrollEngine` with bounding limits `[min_offset, max_offset]`.
    pub fn new(min_offset: f32, max_offset: f32) -> Self {
        let spring = SpringAnimation::new(min_offset, min_offset)
            .with_config(SpringConfig::gentle());
        Self {
            offset: min_offset,
            velocity: 0.0,
            min_offset,
            max_offset: max_offset.max(min_offset),
            friction: 0.92,
            spring,
            in_overscroll: false,
        }
    }

    /// Sets new scroll bounds (e.g. when content size or viewport height changes).
    pub fn set_bounds(&mut self, min_offset: f32, max_offset: f32) {
        self.min_offset = min_offset;
        self.max_offset = max_offset.max(min_offset);
    }

    /// Current scroll offset.
    #[inline]
    pub fn offset(&self) -> f32 {
        self.offset
    }

    /// Directly sets scroll offset, resetting velocity.
    pub fn set_offset(&mut self, offset: f32) {
        self.offset = offset.clamp(self.min_offset, self.max_offset);
        self.velocity = 0.0;
        self.spring.current = self.offset;
        self.spring.target = self.offset;
        self.in_overscroll = false;
    }

    /// Adds an external scroll impulse (e.g. mouse wheel or touchpad swipe).
    pub fn add_impulse(&mut self, delta_y: f32) {
        self.velocity += delta_y * 18.0;
        self.in_overscroll = false;
    }

    /// Immediate relative scroll step.
    pub fn on_scroll(&mut self, delta_y: f32) {
        self.offset += delta_y;
        self.velocity += delta_y * 12.0;
        self.in_overscroll = false;
    }

    /// Advances simulation forward by `dt` seconds.
    pub fn step(&mut self, dt: f32) -> f32 {
        let fps_ratio = (dt * 60.0).clamp(0.1, 3.0);

        // Check if currently outside bounds (overscroll rubber-band)
        if self.offset < self.min_offset {
            self.in_overscroll = true;
            self.spring.current = self.offset;
            self.spring.target = self.min_offset;
            self.offset = self.spring.step(dt);
            self.velocity *= 0.5f32.powf(fps_ratio);
        } else if self.offset > self.max_offset {
            self.in_overscroll = true;
            self.spring.current = self.offset;
            self.spring.target = self.max_offset;
            self.offset = self.spring.step(dt);
            self.velocity *= 0.5f32.powf(fps_ratio);
        } else {
            self.in_overscroll = false;
            if self.velocity.abs() > 0.05 {
                self.offset += self.velocity * dt;
                let decay = self.friction.powf(fps_ratio);
                self.velocity *= decay;

                if self.velocity.abs() <= 0.05 {
                    self.velocity = 0.0;
                }
            } else {
                self.velocity = 0.0;
            }
        }

        self.offset
    }

    /// Returns `true` if motion has settled to rest within bounds.
    pub fn is_settled(&self) -> bool {
        self.velocity.abs() < 0.05
            && (self.offset >= self.min_offset && self.offset <= self.max_offset)
            && (!self.in_overscroll || self.spring.is_settled())
    }

    /// Instantly stops any active inertia.
    pub fn stop(&mut self) {
        self.velocity = 0.0;
        self.offset = self.offset.clamp(self.min_offset, self.max_offset);
        self.in_overscroll = false;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_kinetic_scroll_deceleration_and_friction() {
        let mut engine = KineticScrollEngine::new(0.0, 1000.0);
        engine.add_impulse(10.0); // positive impulse (180.0 velocity)
        assert!(engine.velocity > 0.0);

        let initial_offset = engine.offset;
        let mut last_v = engine.velocity;

        // Step 10 frames
        for _ in 0..10 {
            engine.step(0.016);
            assert!(engine.velocity < last_v); // decelerating
            last_v = engine.velocity;
        }

        assert!(engine.offset > initial_offset);

        // Run until settled
        for _ in 0..150 {
            engine.step(0.016);
            if engine.is_settled() {
                break;
            }
        }

        assert!(engine.is_settled());
        assert_eq!(engine.velocity, 0.0);
    }

    #[test]
    fn test_kinetic_scroll_overscroll_bounce() {
        let mut engine = KineticScrollEngine::new(0.0, 500.0);
        // Force overscroll beyond max_offset
        engine.offset = 550.0;
        assert!(engine.offset > engine.max_offset);

        // Advance simulation: spring should pull it back towards 500.0
        for _ in 0..100 {
            engine.step(0.016);
        }

        assert!((engine.offset - 500.0).abs() < 1.0);
        assert!(engine.is_settled());
    }
}
