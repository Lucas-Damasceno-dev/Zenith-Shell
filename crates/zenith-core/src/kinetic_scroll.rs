//! Kinetic Inertial Scroll Engine for Zenith-Shell.
//!
//! Provides natural inertial scrolling with exponential friction,
//! damped momentum deceleration, and spring-based rubber-band overscroll.

use crate::errors::KineticScrollError;
use crate::spring::{SpringAnimation, SpringConfig};
use crate::traits::ScrollEngine;

/// Type alias for 100% backward and architectural API compatibility.
pub type KineticScroll = KineticScrollEngine;

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
            // Sub-pixel threshold: if difference is < 0.001, snap directly to rest
            if (self.min_offset - self.offset) < 0.001 {
                self.offset = self.min_offset;
                self.velocity = 0.0;
                self.in_overscroll = false;
                self.spring.current = self.min_offset;
                self.spring.target = self.min_offset;
                self.spring.velocity = 0.0;
                return self.offset;
            }

            self.in_overscroll = true;
            self.spring.current = self.offset;
            self.spring.target = self.min_offset;
            self.offset = self.spring.step(dt);
            self.velocity *= 0.5f32.powf(fps_ratio);

            if self.spring.is_settled() || (self.min_offset - self.offset).abs() < 0.001 {
                self.offset = self.min_offset;
                self.velocity = 0.0;
                self.in_overscroll = false;
                self.spring.current = self.min_offset;
                self.spring.velocity = 0.0;
            }
        } else if self.offset > self.max_offset {
            // Sub-pixel threshold: if difference is < 0.001, snap directly to rest
            if (self.offset - self.max_offset) < 0.001 {
                self.offset = self.max_offset;
                self.velocity = 0.0;
                self.in_overscroll = false;
                self.spring.current = self.max_offset;
                self.spring.target = self.max_offset;
                self.spring.velocity = 0.0;
                return self.offset;
            }

            self.in_overscroll = true;
            self.spring.current = self.offset;
            self.spring.target = self.max_offset;
            self.offset = self.spring.step(dt);
            self.velocity *= 0.5f32.powf(fps_ratio);

            if self.spring.is_settled() || (self.offset - self.max_offset).abs() < 0.001 {
                self.offset = self.max_offset;
                self.velocity = 0.0;
                self.in_overscroll = false;
                self.spring.current = self.max_offset;
                self.spring.velocity = 0.0;
            }
        } else {
            self.in_overscroll = false;
            // Within bounds: treat sub-pixel velocity (< 0.001) as settled rest
            if self.velocity.abs() >= 0.001 {
                self.offset += self.velocity * dt;
                let decay = self.friction.powf(fps_ratio);
                self.velocity *= decay;

                if self.velocity.abs() < 0.001 {
                    self.velocity = 0.0;
                }
            } else {
                self.velocity = 0.0;
            }

            // Snap micro-boundary offsets
            if (self.offset - self.min_offset).abs() < 0.001 {
                self.offset = self.min_offset;
            } else if (self.offset - self.max_offset).abs() < 0.001 {
                self.offset = self.max_offset;
            }
        }

        self.offset
    }

    /// Returns `true` if motion has settled to rest within bounds.
    pub fn is_settled(&self) -> bool {
        self.velocity.abs() < 0.001
            && (self.offset >= self.min_offset - 0.001 && self.offset <= self.max_offset + 0.001)
            && (!self.in_overscroll || self.spring.is_settled())
    }

    /// Instantly stops any active inertia.
    pub fn stop(&mut self) {
        self.velocity = 0.0;
        self.offset = self.offset.clamp(self.min_offset, self.max_offset);
        self.in_overscroll = false;
    }

    /// Returns current boundary limits as `(min_offset, max_offset)`.
    #[inline]
    pub fn bounds(&self) -> (f32, f32) {
        (self.min_offset, self.max_offset)
    }

    /// Returns current velocity.
    #[inline]
    pub fn velocity(&self) -> f32 {
        self.velocity
    }

    /// Validates internal state and boundaries.
    pub fn validate(&self) -> Result<(), KineticScrollError> {
        if !self.min_offset.is_finite() || !self.max_offset.is_finite() || self.min_offset > self.max_offset {
            return Err(KineticScrollError::InvalidBounds {
                min: self.min_offset,
                max: self.max_offset,
            });
        }
        if !self.offset.is_finite() || !self.velocity.is_finite() {
            return Err(KineticScrollError::NonFiniteInput(if !self.offset.is_finite() {
                self.offset
            } else {
                self.velocity
            }));
        }
        if !self.friction.is_finite() || self.friction <= 0.0 || self.friction >= 1.0 {
            return Err(KineticScrollError::InvalidFriction(self.friction));
        }
        Ok(())
    }

    /// Safely steps simulation forward by `dt` seconds, returning an error on invalid input.
    pub fn step_safe(&mut self, dt: f32) -> Result<f32, KineticScrollError> {
        if !dt.is_finite() || dt < 0.0 {
            return Err(KineticScrollError::NonFiniteInput(dt));
        }
        self.validate()?;
        Ok(self.step(dt))
    }
}

impl ScrollEngine for KineticScrollEngine {
    #[inline]
    fn offset(&self) -> f32 {
        self.offset()
    }

    #[inline]
    fn set_offset(&mut self, offset: f32) {
        self.set_offset(offset);
    }

    #[inline]
    fn add_impulse(&mut self, delta_y: f32) {
        self.add_impulse(delta_y);
    }

    #[inline]
    fn on_scroll(&mut self, delta_y: f32) {
        self.on_scroll(delta_y);
    }

    #[inline]
    fn step(&mut self, dt: f32) -> f32 {
        self.step(dt)
    }

    #[inline]
    fn is_settled(&self) -> bool {
        self.is_settled()
    }

    #[inline]
    fn stop(&mut self) {
        self.stop();
    }

    #[inline]
    fn bounds(&self) -> (f32, f32) {
        self.bounds()
    }

    #[inline]
    fn set_bounds(&mut self, min: f32, max: f32) {
        self.set_bounds(min, max);
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

    #[test]
    fn test_kinetic_scroll_subpixel_micro_values_settle() {
        let mut engine = KineticScrollEngine::new(0.0, 500.0);

        // Micro-overscroll (<0.001 below min)
        engine.offset = -0.0004;
        engine.step(0.016);
        assert_eq!(engine.offset, 0.0);
        assert_eq!(engine.velocity, 0.0);
        assert!(engine.is_settled());

        // Micro-overscroll (<0.001 above max)
        engine.offset = 500.0006;
        engine.step(0.016);
        assert_eq!(engine.offset, 500.0);
        assert_eq!(engine.velocity, 0.0);
        assert!(engine.is_settled());

        // Micro-velocity (<0.001) within bounds
        engine.offset = 250.0;
        engine.velocity = 0.0005;
        engine.step(0.016);
        assert_eq!(engine.velocity, 0.0);
        assert!(engine.is_settled());
    }
}
