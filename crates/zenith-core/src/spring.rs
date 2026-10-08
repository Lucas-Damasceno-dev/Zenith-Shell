//! Spring physics animation engine based on damped harmonic oscillator.

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

    /// Step simulation forward by `dt` seconds using semi-implicit Euler integration.
    pub fn step(&mut self, dt: f32) -> f32 {
        if self.is_settled() {
            self.current = self.target;
            self.velocity = 0.0;
            return self.current;
        }

        let displacement = self.current - self.target;
        let spring_force = -self.config.stiffness * displacement;
        let damping_force = -self.config.damping * self.velocity;
        let acceleration = (spring_force + damping_force) / self.config.mass.max(0.001);

        self.velocity += acceleration * dt;
        self.current += self.velocity * dt;

        if self.is_settled() {
            self.current = self.target;
            self.velocity = 0.0;
        }

        self.current
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
}
