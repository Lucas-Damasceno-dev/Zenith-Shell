//! Spring physics animation engine based on damped harmonic oscillator.

use crate::errors::SpringError;
use crate::traits::Animation;

/// Physical configuration for a spring simulation.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct SpringConfig {
    pub stiffness: f32, // Tension (default 170.0)
    pub damping: f32,   // Friction (default 26.0)
    pub mass: f32,      // Mass (default 1.0)
    pub precision: f32, // Threshold for settling (default 0.001)
}

impl Default for SpringConfig {
    fn default() -> Self {
        Self {
            stiffness: 170.0,
            damping: 26.0,
            mass: 1.0,
            precision: 0.001,
        }
    }
}

impl SpringConfig {
    pub fn gentle() -> Self {
        Self {
            stiffness: 120.0,
            damping: 14.0,
            mass: 1.0,
            precision: 0.001,
        }
    }

    pub fn wobbly() -> Self {
        Self {
            stiffness: 180.0,
            damping: 12.0,
            mass: 1.0,
            precision: 0.001,
        }
    }

    pub fn stiff() -> Self {
        Self {
            stiffness: 210.0,
            damping: 20.0,
            mass: 1.0,
            precision: 0.001,
        }
    }

    /// Critically damped configuration where oscillation is eliminated and settling occurs in minimal time:
    /// damping = 2.0 * sqrt(stiffness * mass)
    pub fn critically_damped(stiffness: f32) -> Self {
        let mass = 1.0;
        let damping = 2.0 * (stiffness * mass).sqrt();
        Self {
            stiffness,
            damping,
            mass,
            precision: 0.001,
        }
    }

    /// Over-damped configuration where system exponentially decays to rest without oscillating:
    /// damping = factor * 2.0 * sqrt(stiffness * mass), where factor > 1.0
    pub fn overdamped(stiffness: f32, factor: f32) -> Self {
        let mass = 1.0;
        let critical = 2.0 * (stiffness * mass).sqrt();
        let damping = critical * factor.max(1.05);
        Self {
            stiffness,
            damping,
            mass,
            precision: 0.001,
        }
    }

    /// Standard preset for critical damping (zero overshoot, rapid settling).
    pub fn critical() -> Self {
        Self::critically_damped(170.0)
    }

    /// Standard preset for over-damped motion (heavy friction, no overshoot).
    pub fn over_damped() -> Self {
        Self::overdamped(170.0, 1.5)
    }

    /// Validates spring physical parameters.
    pub fn validate(&self) -> Result<(), SpringError> {
        if !self.stiffness.is_finite() || self.stiffness <= 0.0 {
            return Err(SpringError::InvalidParameter {
                parameter: "stiffness",
                value: self.stiffness,
                reason: "stiffness must be positive and finite",
            });
        }
        if !self.damping.is_finite() || self.damping < 0.0 {
            return Err(SpringError::InvalidParameter {
                parameter: "damping",
                value: self.damping,
                reason: "damping must be non-negative and finite",
            });
        }
        if !self.mass.is_finite() || self.mass <= 0.0 {
            return Err(SpringError::InvalidParameter {
                parameter: "mass",
                value: self.mass,
                reason: "mass must be positive and finite",
            });
        }
        if !self.precision.is_finite() || self.precision <= 0.0 {
            return Err(SpringError::InvalidParameter {
                parameter: "precision",
                value: self.precision,
                reason: "precision must be positive and finite",
            });
        }
        Ok(())
    }
}

/// Damped harmonic oscillator tracking value, velocity, and target.
#[derive(Debug, Clone, Copy)]
pub struct SpringAnimation {
    pub config: SpringConfig,
    pub current: f32,
    pub target: f32,
    pub velocity: f32,
}

impl SpringAnimation {
    pub fn new(initial: f32, target: f32) -> Self {
        Self {
            config: SpringConfig::default(),
            current: initial,
            target,
            velocity: 0.0,
        }
    }

    pub fn with_config(mut self, config: SpringConfig) -> Self {
        self.config = config;
        self
    }

    pub fn set_target(&mut self, target: f32) {
        self.target = target;
    }

    pub fn is_settled(&self) -> bool {
        (self.current - self.target).abs() < self.config.precision
            && self.velocity.abs() < self.config.precision
    }

    /// Step simulation forward by `dt` seconds using 4th-order Runge-Kutta (RK4) integration.
    /// Handles sub-pixel micro-values (< 0.001) ensuring stable rest without infinite oscillation.
    pub fn step(&mut self, dt: f32) -> f32 {
        if dt == 0.0 || self.is_settled() {
            if self.is_settled() {
                self.current = self.target;
                self.velocity = 0.0;
            }
            return self.current;
        }

        let k = self.config.stiffness;
        let c = self.config.damping;
        let m = self.config.mass.max(0.0001);

        let acceleration = |disp: f32, vel: f32| -> f32 {
            let spring_force = -k * disp;
            let damping_force = -c * vel;
            (spring_force + damping_force) / m
        };

        // RK4 integration for 2nd order harmonic oscillator ODE:
        // x represents displacement from target
        let x0 = self.current - self.target;
        let v0 = self.velocity;

        // Stage 1 (k1)
        let a1 = acceleration(x0, v0);
        let dx1 = v0;

        // Stage 2 (k2, midpoint)
        let dt_half = dt * 0.5;
        let x2 = x0 + dx1 * dt_half;
        let v2 = v0 + a1 * dt_half;
        let a2 = acceleration(x2, v2);
        let dx2 = v2;

        // Stage 3 (k3, midpoint)
        let x3 = x0 + dx2 * dt_half;
        let v3 = v0 + a2 * dt_half;
        let a3 = acceleration(x3, v3);
        let dx3 = v3;

        // Stage 4 (k4, endpoint)
        let x4 = x0 + dx3 * dt;
        let v4 = v0 + a3 * dt;
        let a4 = acceleration(x4, v4);
        let dx4 = v4;

        // Weighted increments
        let delta_x = (dx1 + 2.0 * dx2 + 2.0 * dx3 + dx4) * (dt / 6.0);
        let delta_v = (a1 + 2.0 * a2 + 2.0 * a3 + a4) * (dt / 6.0);

        self.current += delta_x;
        self.velocity += delta_v;

        // Rest threshold snapping: stable stop for sub-pixel residual values
        if self.is_settled() {
            self.current = self.target;
            self.velocity = 0.0;
        }

        self.current
    }

    /// Resets current position and target position to `val`, and clears velocity.
    pub fn reset(&mut self, val: f32) {
        self.current = val;
        self.target = val;
        self.velocity = 0.0;
    }

    /// Returns current animated position.
    #[inline]
    pub fn current(&self) -> f32 {
        self.current
    }

    /// Returns target destination value.
    #[inline]
    pub fn target(&self) -> f32 {
        self.target
    }

    /// Returns current velocity.
    #[inline]
    pub fn velocity(&self) -> f32 {
        self.velocity
    }

    /// Validates internal state and configuration for finite, physically valid values.
    pub fn validate(&self) -> Result<(), SpringError> {
        self.config.validate()?;
        if !self.current.is_finite() || !self.velocity.is_finite() || !self.target.is_finite() {
            return Err(SpringError::NonFiniteState {
                current: self.current,
                velocity: self.velocity,
                target: self.target,
            });
        }
        Ok(())
    }

    /// Safely steps simulation forward by `dt` seconds, returning an error on invalid input or non-finite state.
    pub fn step_safe(&mut self, dt: f32) -> Result<f32, SpringError> {
        if !dt.is_finite() || dt < 0.0 {
            return Err(SpringError::InvalidDeltaTime(dt));
        }
        self.validate()?;
        Ok(self.step(dt))
    }
}

impl Animation<f32> for SpringAnimation {
    #[inline]
    fn step(&mut self, dt: f32) -> f32 {
        self.step(dt)
    }

    #[inline]
    fn is_settled(&self) -> bool {
        self.is_settled()
    }

    #[inline]
    fn target(&self) -> f32 {
        self.target
    }

    #[inline]
    fn set_target(&mut self, target: f32) {
        self.set_target(target);
    }

    #[inline]
    fn current(&self) -> f32 {
        self.current
    }

    #[inline]
    fn velocity(&self) -> f32 {
        self.velocity
    }

    #[inline]
    fn reset(&mut self, val: f32) {
        self.reset(val);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_spring_converges_to_target() {
        let mut spring = SpringAnimation::new(0.0, 100.0);
        let dt = 1.0 / 60.0; // 60 FPS frame time
        for _ in 0..120 {
            spring.step(dt);
            if spring.is_settled() {
                break;
            }
        }
        assert!(spring.is_settled());
        assert!((spring.current - 100.0).abs() < 0.01);
    }

    #[test]
    fn test_spring_gentle_config() {
        let mut spring = SpringAnimation::new(0.0, 50.0).with_config(SpringConfig::gentle());
        assert_eq!(spring.target, 50.0);
        spring.step(0.016);
        assert!(spring.current > 0.0);
    }

    #[test]
    fn test_spring_subpixel_micro_values_settle() {
        // Micro-displacement sub-pixel (<0.001) should settle to absolute rest without infinite oscillation
        let mut spring = SpringAnimation::new(50.0004, 50.0);
        assert!(spring.is_settled());
        spring.step(0.016);
        assert_eq!(spring.current, 50.0);
        assert_eq!(spring.velocity, 0.0);
        assert!(spring.is_settled());

        // Negative sub-pixel micro-displacement
        let mut spring_neg = SpringAnimation::new(49.9996, 50.0);
        assert!(spring_neg.is_settled());
        spring_neg.step(0.016);
        assert_eq!(spring_neg.current, 50.0);
        assert_eq!(spring_neg.velocity, 0.0);
        assert!(spring_neg.is_settled());
    }

    #[test]
    fn test_spring_critically_damped_absolute_rest() {
        // Critical damping: fastest approach to target with zero or negligible overshoot
        let mut spring = SpringAnimation::new(0.0, 100.0)
            .with_config(SpringConfig::critically_damped(160.0));
        let dt = 1.0 / 60.0;
        let mut max_observed = 0.0f32;

        for _ in 0..150 {
            spring.step(dt);
            if spring.current > max_observed {
                max_observed = spring.current;
            }
            if spring.is_settled() {
                break;
            }
        }

        assert!(spring.is_settled());
        assert_eq!(spring.current, 100.0);
        assert_eq!(spring.velocity, 0.0);
        // Critical damping should not significantly overshoot the target
        assert!(max_observed <= 100.01);
    }

    #[test]
    fn test_spring_overdamped_absolute_rest() {
        // Over-damped: heavy damping, strictly no overshoot, settles to absolute rest
        let mut spring = SpringAnimation::new(0.0, 100.0)
            .with_config(SpringConfig::overdamped(160.0, 1.4));
        let dt = 1.0 / 60.0;
        let mut prev = 0.0f32;

        for _ in 0..300 {
            spring.step(dt);
            // Monotonically non-decreasing towards target
            assert!(spring.current >= prev - 0.0001);
            prev = spring.current;
            if spring.is_settled() {
                break;
            }
        }

        assert!(spring.is_settled());
        assert_eq!(spring.current, 100.0);
        assert_eq!(spring.velocity, 0.0);
    }
}
