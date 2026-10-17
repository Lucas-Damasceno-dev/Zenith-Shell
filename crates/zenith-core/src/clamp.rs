//! Clamp utility specifications and bounds management for Zenith-Shell.
//!
//! Provides boundary restriction primitives, safe range clamping,
//! and ergonomic extension traits for numeric types.

/// Clamps a value within an inclusive range `[min, max]`.
///
/// # Contract
/// - Returns `min` if `val < min`.
/// - Returns `max` if `val > max`.
/// - Returns `val` otherwise.
///
/// # Skeletons / Stubs
/// Concrete logic will be implemented in Stage 2 (Dev).
#[inline]
pub fn clamp<T: PartialOrd>(val: T, min: T, max: T) -> T {
    if val < min {
        min
    } else if val > max {
        max
    } else {
        val
    }
}

/// Safely clamps a value within `[min, max]`, handling inverted bounds (`min > max`)
/// and floating point edge cases.
///
/// # Contract
/// - Normalizes bounds if `min > max` so the interval is valid `[min(a, b), max(a, b)]`.
/// - Clamps `val` to the normalized bounds.
///
/// # Skeletons / Stubs
/// Concrete logic will be implemented in Stage 2 (Dev).
#[inline]
pub fn clamp_safe<T: PartialOrd + Copy>(val: T, min: T, max: T) -> T {
    let (min, max) = if min > max { (max, min) } else { (min, max) };
    clamp(val, min, max)
}

/// Clamps a value within `[min, max]`, falling back to `fallback` if `val` or bounds are unordered (e.g. NaN).
#[inline]
pub fn clamp_nan_safe<T: PartialOrd + Copy>(val: T, min: T, max: T, fallback: T) -> T {
    if val.partial_cmp(&val).is_none() {
        return fallback;
    }
    let (min, max) = if min > max { (max, min) } else { (min, max) };
    clamp(val, min, max)
}

/// Bounded range `[min, max]` defining valid clamp boundaries.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ClampRange<T> {
    pub min: T,
    pub max: T,
}

impl<T> ClampRange<T> {
    /// Creates a new `ClampRange` boundary definition.
    #[inline]
    pub const fn new(min: T, max: T) -> Self {
        Self { min, max }
    }
}

impl<T: PartialOrd> ClampRange<T> {
    /// Returns `true` if boundaries are valid (`min <= max`).
    #[inline]
    pub fn is_valid(&self) -> bool {
        self.min <= self.max
    }
}

impl<T: std::ops::Sub<Output = T> + Copy> ClampRange<T> {
    /// Returns the total span (`max - min`) of the range.
    #[inline]
    pub fn span(&self) -> T {
        self.max - self.min
    }
}

impl<T: PartialOrd + Copy> ClampRange<T> {
    /// Clamps `val` to fit within `[self.min, self.max]`.
    #[inline]
    pub fn clamp(&self, val: T) -> T {
        clamp(val, self.min, self.max)
    }

    /// Returns `true` if `val` is contained within `[self.min, self.max]`.
    #[inline]
    pub fn contains(&self, val: T) -> bool {
        val >= self.min && val <= self.max
    }
}

/// Extension trait enabling method-chaining clamp operations on numeric types.
pub trait ClampExt<T = Self> {
    /// Restricts `self` to the range `[min, max]`.
    fn clamp_range(self, min: T, max: T) -> Self;

    /// Restricts `self` safely to `[min, max]`, normalizing inverted bounds.
    fn clamp_safe(self, min: T, max: T) -> Self;

    /// Restricts `self` safely with fallback when unordered (e.g. NaN).
    fn clamp_nan_safe(self, min: T, max: T, fallback: T) -> Self;
}

impl<T: PartialOrd + Copy> ClampExt<T> for T {
    #[inline]
    fn clamp_range(self, min: T, max: T) -> Self {
        clamp(self, min, max)
    }

    #[inline]
    fn clamp_safe(self, min: T, max: T) -> Self {
        clamp_safe(self, min, max)
    }

    #[inline]
    fn clamp_nan_safe(self, min: T, max: T, fallback: T) -> Self {
        clamp_nan_safe(self, min, max, fallback)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_clamp_interface_contract() {
        let v: f32 = 10.0;
        let _ = clamp(v, 0.0, 5.0);
        let _ = clamp_safe(v, 5.0, 0.0);
        let range = ClampRange::new(0.0, 5.0);
        let _ = range.clamp(v);
        let _ = range.contains(v);
        let _ = v.clamp_range(0.0, 5.0);
        let _ = v.clamp_safe(5.0, 0.0);
    }

    #[test]
    fn test_clamp_below_min() {
        assert_eq!(clamp(-5.0, 0.0, 10.0), 0.0);
    }

    #[test]
    fn test_clamp_above_max() {
        assert_eq!(clamp(15.0, 0.0, 10.0), 10.0);
    }

    #[test]
    fn test_clamp_within_bounds() {
        assert_eq!(clamp(5.0, 0.0, 10.0), 5.0);
    }

    #[test]
    fn test_clamp_safe_inverted_bounds() {
        assert_eq!(clamp_safe(15.0, 10.0, 0.0), 10.0);
        assert_eq!(clamp_safe(-5.0, 10.0, 0.0), 0.0);
    }

    #[test]
    fn test_clamp_range_struct() {
        let range = ClampRange::new(10, 20);
        assert_eq!(range.clamp(5), 10);
        assert_eq!(range.clamp(25), 20);
        assert!(range.contains(15));
        assert!(!range.contains(5));
    }
}
