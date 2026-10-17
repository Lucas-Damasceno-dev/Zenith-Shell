//! Abstract trait definitions for animation, physics engines, and scroll controllers.

/// Standard interface for animated numeric values driven by physics or interpolation.
pub trait Animation<T = f32> {
    /// Advances the animation by delta time `dt` in seconds, returning the new value.
    fn step(&mut self, dt: f32) -> T;

    /// Returns `true` if the animation has settled within its target precision.
    fn is_settled(&self) -> bool;

    /// Returns the target destination value.
    fn target(&self) -> T;

    /// Updates the target destination value.
    fn set_target(&mut self, target: T);

    /// Returns the current animated value.
    fn current(&self) -> T;

    /// Returns the current rate of change (velocity).
    fn velocity(&self) -> T;

    /// Resets the current and target position to `val` and zeros velocity.
    fn reset(&mut self, val: T);
}

/// Interface for kinetic inertial scroll physics engines.
pub trait ScrollEngine {
    /// Returns the current scroll offset.
    fn offset(&self) -> f32;

    /// Directly updates scroll offset and resets velocity.
    fn set_offset(&mut self, offset: f32);

    /// Adds an external impulse velocity (e.g. mouse wheel or swipe).
    fn add_impulse(&mut self, delta_y: f32);

    /// Applies an immediate relative scroll displacement.
    fn on_scroll(&mut self, delta_y: f32);

    /// Advances simulation forward by `dt` seconds.
    fn step(&mut self, dt: f32) -> f32;

    /// Returns `true` if inertia has settled to rest within bounds.
    fn is_settled(&self) -> bool;

    /// Instantly halts all motion and clamps offset within bounds.
    fn stop(&mut self);

    /// Returns current boundary limits as `(min_offset, max_offset)`.
    fn bounds(&self) -> (f32, f32);

    /// Updates boundary limits.
    fn set_bounds(&mut self, min: f32, max: f32);
}

/// Marker trait guaranteeing safe concurrent usage across threads.
pub trait ConcurrentAnimation: Animation + Send + Sync {}
impl<T: Animation + Send + Sync> ConcurrentAnimation for T {}

/// Marker trait guaranteeing safe concurrent usage for scroll engines across threads.
pub trait ConcurrentScrollEngine: ScrollEngine + Send + Sync {}
impl<T: ScrollEngine + Send + Sync> ConcurrentScrollEngine for T {}
