//! Error types and validation contracts for Zenith Core.

use thiserror::Error;

/// Aggregated core error type for mathematical, physical, and boundary violations.
#[derive(Debug, Error, Clone, PartialEq)]
pub enum CoreError {
    #[error("Spring physics error: {0}")]
    Spring(#[from] SpringError),

    #[error("Kinetic scroll error: {0}")]
    KineticScroll(#[from] KineticScrollError),

    #[error("Invalid bounds: min={min}, max={max}")]
    InvalidBounds { min: f32, max: f32 },

    #[error("Non-finite numeric value encountered: {0}")]
    NonFinite(f32),
}

/// Errors occurring during spring simulation, configuration, or step evaluation.
#[derive(Debug, Error, Clone, PartialEq)]
pub enum SpringError {
    #[error("Invalid delta time: dt={0} (must be non-negative and finite)")]
    InvalidDeltaTime(f32),

    #[error("Invalid spring parameter '{parameter}' = {value}: {reason}")]
    InvalidParameter {
        parameter: &'static str,
        value: f32,
        reason: &'static str,
    },

    #[error("Non-finite state encountered in spring: current={current}, velocity={velocity}, target={target}")]
    NonFiniteState {
        current: f32,
        velocity: f32,
        target: f32,
    },
}

/// Errors occurring during kinetic scroll operations, boundaries, or impulse application.
#[derive(Debug, Error, Clone, PartialEq)]
pub enum KineticScrollError {
    #[error("Invalid scroll bounds: min={min}, max={max} (min must be finite and <= max)")]
    InvalidBounds { min: f32, max: f32 },

    #[error("Invalid input value: {0} (must be finite)")]
    NonFiniteInput(f32),

    #[error("Invalid friction coefficient: {0} (must be within (0.0, 1.0))")]
    InvalidFriction(f32),
}
