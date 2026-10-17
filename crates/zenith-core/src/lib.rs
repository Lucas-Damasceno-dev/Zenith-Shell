//! Zenith Core - Primitive types, logging, and error handling for Zenith-Shell.

use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

pub mod clamp;
pub mod errors;
pub mod kinetic_scroll;
pub mod math {
    pub use crate::clamp::*;
}
pub mod spring;
pub mod sync;
pub mod traits;

pub use clamp::{clamp, clamp_nan_safe, clamp_safe, ClampExt, ClampRange};
pub use errors::{CoreError, KineticScrollError, SpringError};
pub use kinetic_scroll::{KineticScroll, KineticScrollEngine};
pub use spring::{SpringAnimation, SpringConfig};
pub use sync::{SharedKineticScroll, SharedSpringAnimation};
pub use traits::{Animation, ConcurrentAnimation, ConcurrentScrollEngine, ScrollEngine};

/// Initialize structured logging for the Zenith engine.
pub fn init_logging() {
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info,zenith=debug")))
        .with(tracing_subscriber::fmt::layer().with_target(false).compact())
        .init();
    tracing::info!("Zenith Engine Core initialized");
}
