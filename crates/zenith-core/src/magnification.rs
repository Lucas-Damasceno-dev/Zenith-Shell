//! Smooth Physics-Based Dock Magnification Engine for Zenith-Shell.
//!
//! Computes bell-curve deformation profiles (cosine / gaussian) with RK4 spring-damped
//! smoothing for macOS/Quickshell-grade fluid magnification at 120Hz/240Hz.

use crate::spring::{SpringAnimation, SpringConfig};

/// Mathematical kernel used for the magnification falloff curve.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum MagnificationCurve {
    /// Cosine bell curve: (cos(d / R * PI / 2))^2
    #[default]
    Cosine,
    /// Gaussian bell curve: exp(-d^2 / (2 * sigma^2))
    Gaussian,
}

/// Configuration parameters for dock magnification.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct MagnificationConfig {
    /// Peak scale multiplier at the cursor focal point (e.g., 1.55 = 155% base size).
    pub max_scale: f32,
    /// Influence radius (in pixels) across which magnification smoothly decays to 1.0.
    pub influence_radius: f32,
    /// Falloff curve function.
    pub curve: MagnificationCurve,
    /// Optional bottom anchor: if true, items expand upwards from dock shelf.
    pub anchor_bottom: bool,
}

impl Default for MagnificationConfig {
    fn default() -> Self {
        Self {
            max_scale: 1.55,
            influence_radius: 130.0,
            curve: MagnificationCurve::Cosine,
            anchor_bottom: true,
        }
    }
}

/// Magnification mathematical model.
#[derive(Debug, Clone, PartialEq)]
pub struct MagnificationModel {
    pub config: MagnificationConfig,
}

impl MagnificationModel {
    pub fn new(config: MagnificationConfig) -> Self {
        Self { config }
    }

    /// Evaluates the instantaneous scale factor for an item at `item_center_x` given pointer at `pointer_x`.
    #[inline]
    pub fn compute_scale(&self, pointer_x: f32, item_center_x: f32) -> f32 {
        let dist = (item_center_x - pointer_x).abs();
        if dist >= self.config.influence_radius {
            return 1.0;
        }

        let weight = match self.config.curve {
            MagnificationCurve::Cosine => {
                let norm = (dist / self.config.influence_radius) * (std::f32::consts::PI * 0.5);
                let c = norm.cos();
                c * c
            }
            MagnificationCurve::Gaussian => {
                let sigma = self.config.influence_radius * 0.42;
                (-0.5 * (dist / sigma).powi(2)).exp()
            }
        };

        1.0 + (self.config.max_scale - 1.0) * weight
    }

    /// Computes instant target scales for an entire array of item centers.
    pub fn compute_scales(&self, pointer_x: Option<f32>, item_centers: &[f32], out_scales: &mut [f32]) {
        assert_eq!(item_centers.len(), out_scales.len());
        if let Some(px) = pointer_x {
            for (center, out) in item_centers.iter().zip(out_scales.iter_mut()) {
                *out = self.compute_scale(px, *center);
            }
        } else {
            for out in out_scales.iter_mut() {
                *out = 1.0;
            }
        }
    }
}

/// Spring-damped dynamic tracker for multi-item magnification.
///
/// Prevents harsh teleportation of icon sizes when the mouse abruptly enters,
/// moves across or leaves the dock area.
#[derive(Debug, Clone)]
pub struct MagnificationSpringTracker {
    springs: Vec<SpringAnimation>,
}

impl MagnificationSpringTracker {
    /// Creates a new spring tracker for `item_count` dock items.
    pub fn new(item_count: usize) -> Self {
        let config = SpringConfig {
            stiffness: 260.0,
            damping: 24.0,
            mass: 1.0,
            precision: 0.001,
        };
        let mut springs = Vec::with_capacity(item_count);
        for _ in 0..item_count {
            springs.push(SpringAnimation::new(1.0, 1.0).with_config(config));
        }
        Self { springs }
    }

    /// Resizes the tracker item count if dock items are added or removed.
    pub fn resize(&mut self, item_count: usize) {
        if self.springs.len() != item_count {
            let config = SpringConfig {
                stiffness: 260.0,
                damping: 24.0,
                mass: 1.0,
                precision: 0.001,
            };
            self.springs.resize_with(item_count, || SpringAnimation::new(1.0, 1.0).with_config(config));
        }
    }

    /// Advances the spring simulation by `dt` seconds towards `target_scales` and stores output in `out_scales`.
    pub fn update(&mut self, target_scales: &[f32], dt: f32, out_scales: &mut [f32]) -> bool {
        assert_eq!(self.springs.len(), target_scales.len());
        assert_eq!(self.springs.len(), out_scales.len());
        let mut any_active = false;
        for (i, spring) in self.springs.iter_mut().enumerate() {
            spring.set_target(target_scales[i]);
            let val = spring.step(dt);
            if !spring.is_settled() {
                any_active = true;
            }
            out_scales[i] = val;
        }
        any_active
    }

    /// Gets current settled scales without stepping simulation.
    pub fn current_scales(&self, out_scales: &mut [f32]) {
        assert_eq!(self.springs.len(), out_scales.len());
        for (i, spring) in self.springs.iter().enumerate() {
            out_scales[i] = spring.current();
        }
    }
}
