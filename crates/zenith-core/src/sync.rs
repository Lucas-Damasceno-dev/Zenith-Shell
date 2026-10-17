//! Safe concurrency wrappers and thread-safe abstractions for Zenith Core.

use std::sync::{Arc, Mutex, RwLock};
use crate::kinetic_scroll::KineticScrollEngine;
use crate::spring::SpringAnimation;
use crate::traits::{Animation, ScrollEngine};

/// Thread-safe, atomically synchronized wrapper around `SpringAnimation`.
#[derive(Debug, Clone)]
pub struct SharedSpringAnimation {
    inner: Arc<Mutex<SpringAnimation>>,
}

impl SharedSpringAnimation {
    /// Creates a new `SharedSpringAnimation` with initial and target positions.
    pub fn new(initial: f32, target: f32) -> Self {
        Self {
            inner: Arc::new(Mutex::new(SpringAnimation::new(initial, target))),
        }
    }

    /// Wraps an existing `SpringAnimation` into a thread-safe shared handle.
    pub fn from_spring(spring: SpringAnimation) -> Self {
        Self {
            inner: Arc::new(Mutex::new(spring)),
        }
    }

    /// Advances the spring animation forward by `dt` seconds thread-safely.
    pub fn step(&self, dt: f32) -> f32 {
        let mut guard = self.inner.lock().expect("mutex poisoned");
        guard.step(dt)
    }

    /// Returns `true` if the spring has settled at the target destination.
    pub fn is_settled(&self) -> bool {
        let guard = self.inner.lock().expect("mutex poisoned");
        guard.is_settled()
    }

    /// Returns the current position.
    pub fn current(&self) -> f32 {
        let guard = self.inner.lock().expect("mutex poisoned");
        guard.current
    }

    /// Returns the target position.
    pub fn target(&self) -> f32 {
        let guard = self.inner.lock().expect("mutex poisoned");
        guard.target
    }

    /// Updates the target destination thread-safely.
    pub fn set_target(&self, target: f32) {
        let mut guard = self.inner.lock().expect("mutex poisoned");
        guard.set_target(target);
    }

    /// Resets position and velocity thread-safely.
    pub fn reset(&self, val: f32) {
        let mut guard = self.inner.lock().expect("mutex poisoned");
        guard.reset(val);
    }
}

impl Animation<f32> for SharedSpringAnimation {
    fn step(&mut self, dt: f32) -> f32 {
        SharedSpringAnimation::step(self, dt)
    }

    fn is_settled(&self) -> bool {
        SharedSpringAnimation::is_settled(self)
    }

    fn target(&self) -> f32 {
        SharedSpringAnimation::target(self)
    }

    fn set_target(&mut self, target: f32) {
        SharedSpringAnimation::set_target(self, target);
    }

    fn current(&self) -> f32 {
        SharedSpringAnimation::current(self)
    }

    fn velocity(&self) -> f32 {
        let guard = self.inner.lock().expect("mutex poisoned");
        guard.velocity
    }

    fn reset(&mut self, val: f32) {
        SharedSpringAnimation::reset(self, val);
    }
}

/// Thread-safe, synchronized wrapper around `KineticScrollEngine`.
#[derive(Debug, Clone)]
pub struct SharedKineticScroll {
    inner: Arc<RwLock<KineticScrollEngine>>,
}

impl SharedKineticScroll {
    /// Creates a new `SharedKineticScroll` with bounding limits.
    pub fn new(min_offset: f32, max_offset: f32) -> Self {
        Self {
            inner: Arc::new(RwLock::new(KineticScrollEngine::new(min_offset, max_offset))),
        }
    }

    /// Wraps an existing `KineticScrollEngine` into a thread-safe shared handle.
    pub fn from_engine(engine: KineticScrollEngine) -> Self {
        Self {
            inner: Arc::new(RwLock::new(engine)),
        }
    }

    /// Returns current scroll offset.
    pub fn offset(&self) -> f32 {
        let guard = self.inner.read().expect("rwlock poisoned");
        guard.offset()
    }

    /// Advances simulation forward by `dt` seconds thread-safely.
    pub fn step(&self, dt: f32) -> f32 {
        let mut guard = self.inner.write().expect("rwlock poisoned");
        guard.step(dt)
    }

    /// Adds external scroll impulse thread-safely.
    pub fn add_impulse(&self, delta_y: f32) {
        let mut guard = self.inner.write().expect("rwlock poisoned");
        guard.add_impulse(delta_y);
    }

    /// Applies relative scroll displacement thread-safely.
    pub fn on_scroll(&self, delta_y: f32) {
        let mut guard = self.inner.write().expect("rwlock poisoned");
        guard.on_scroll(delta_y);
    }

    /// Returns `true` if motion has settled to rest within bounds.
    pub fn is_settled(&self) -> bool {
        let guard = self.inner.read().expect("rwlock poisoned");
        guard.is_settled()
    }

    /// Instantly stops active inertia thread-safely.
    pub fn stop(&self) {
        let mut guard = self.inner.write().expect("rwlock poisoned");
        guard.stop();
    }

    /// Sets new scroll bounds thread-safely.
    pub fn set_bounds(&self, min_offset: f32, max_offset: f32) {
        let mut guard = self.inner.write().expect("rwlock poisoned");
        guard.set_bounds(min_offset, max_offset);
    }

    /// Returns current boundary limits `(min, max)`.
    pub fn bounds(&self) -> (f32, f32) {
        let guard = self.inner.read().expect("rwlock poisoned");
        guard.bounds()
    }
}

impl ScrollEngine for SharedKineticScroll {
    fn offset(&self) -> f32 {
        SharedKineticScroll::offset(self)
    }

    fn set_offset(&mut self, offset: f32) {
        let mut guard = self.inner.write().expect("rwlock poisoned");
        guard.set_offset(offset);
    }

    fn add_impulse(&mut self, delta_y: f32) {
        SharedKineticScroll::add_impulse(self, delta_y);
    }

    fn on_scroll(&mut self, delta_y: f32) {
        SharedKineticScroll::on_scroll(self, delta_y);
    }

    fn step(&mut self, dt: f32) -> f32 {
        SharedKineticScroll::step(self, dt)
    }

    fn is_settled(&self) -> bool {
        SharedKineticScroll::is_settled(self)
    }

    fn stop(&mut self) {
        SharedKineticScroll::stop(self);
    }

    fn bounds(&self) -> (f32, f32) {
        SharedKineticScroll::bounds(self)
    }

    fn set_bounds(&mut self, min: f32, max: f32) {
        SharedKineticScroll::set_bounds(self, min, max);
    }
}

// Compile-time static assertions ensuring types implement Send + Sync
const _: () = {
    const fn assert_send_sync<T: Send + Sync>() {}
    assert_send_sync::<SpringAnimation>();
    assert_send_sync::<crate::spring::SpringConfig>();
    assert_send_sync::<KineticScrollEngine>();
    assert_send_sync::<SharedSpringAnimation>();
    assert_send_sync::<SharedKineticScroll>();
};
