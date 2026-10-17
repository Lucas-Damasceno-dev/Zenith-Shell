use zenith_core::math;
use zenith_core::{clamp, clamp_safe, ClampExt, ClampRange};

#[test]
fn test_clamp_public_api_compilation() {
    let v: f64 = 42.0;
    let _ = clamp(v, 0.0, 100.0);
    let _ = clamp_safe(v, 100.0, 0.0);

    let range = ClampRange::new(0.0, 100.0);
    let _ = range.clamp(v);
    let _ = range.contains(v);

    let _ = v.clamp_range(0.0, 100.0);
    let _ = v.clamp_safe(100.0, 0.0);

    // Verify module re-export via zenith_core::math
    let _ = math::clamp(v, 0.0, 100.0);
    let _ = math::clamp_safe(v, 100.0, 0.0);
    let _ = math::ClampRange::new(0.0, 100.0);
}

#[test]
fn test_clamp_integers_below_min() {
    assert_eq!(clamp(-15, 0, 10), 0);
    assert_eq!(clamp(-1, 0, 100), 0);
    assert_eq!(clamp(-100_i64, -50, 50), -50);
}

#[test]
fn test_clamp_integers_above_max() {
    assert_eq!(clamp(15, 0, 10), 10);
    assert_eq!(clamp(101, 0, 100), 100);
    assert_eq!(clamp(200_i64, -50, 50), 50);
}

#[test]
fn test_clamp_integers_inside_bounds() {
    assert_eq!(clamp(0, 0, 10), 0);
    assert_eq!(clamp(5, 0, 10), 5);
    assert_eq!(clamp(10, 0, 10), 10);
    assert_eq!(clamp(-25_i32, -50, 50), -25);
}

#[test]
fn test_clamp_equal_bounds() {
    assert_eq!(clamp(5, 10, 10), 10);
    assert_eq!(clamp(15, 10, 10), 10);
    assert_eq!(clamp(10, 10, 10), 10);
}

#[test]
fn test_clamp_extreme_numeric_limits() {
    assert_eq!(clamp(i64::MIN, -100, 100), -100);
    assert_eq!(clamp(i64::MAX, -100, 100), 100);
    assert_eq!(clamp(0_i64, i64::MIN, i64::MAX), 0);

    assert_eq!(clamp(u8::MIN, 10, 200), 10);
    assert_eq!(clamp(u8::MAX, 10, 200), 200);
}

#[test]
fn test_clamp_floating_point_bounds() {
    assert_eq!(clamp(-0.001_f64, 0.0, 1.0), 0.0);
    assert_eq!(clamp(1.001_f64, 0.0, 1.0), 1.0);
    assert_eq!(clamp(0.5_f64, 0.0, 1.0), 0.5);

    // Negative subzero and floating boundaries
    assert_eq!(clamp(-10.5_f32, -5.0, 5.0), -5.0);
    assert_eq!(clamp(10.5_f32, -5.0, 5.0), 5.0);
}

#[test]
fn test_clamp_floating_point_infinities() {
    assert_eq!(clamp(f64::NEG_INFINITY, -1000.0, 1000.0), -1000.0);
    assert_eq!(clamp(f64::INFINITY, -1000.0, 1000.0), 1000.0);
    assert_eq!(clamp(0.0_f64, f64::NEG_INFINITY, f64::INFINITY), 0.0);
}

#[test]
fn test_clamp_safe_normal_bounds() {
    assert_eq!(clamp_safe(-50, 0, 100), 0);
    assert_eq!(clamp_safe(150, 0, 100), 100);
    assert_eq!(clamp_safe(42, 0, 100), 42);
}

#[test]
fn test_clamp_safe_inverted_bounds() {
    // Contract: Normalizes bounds if min > max
    assert_eq!(clamp_safe(15, 10, 0), 10);
    assert_eq!(clamp_safe(-5, 10, 0), 0);
    assert_eq!(clamp_safe(5, 10, 0), 5);

    // Floating-point inverted bounds
    assert_eq!(clamp_safe(150.0_f32, 100.0, -100.0), 100.0);
    assert_eq!(clamp_safe(-150.0_f32, 100.0, -100.0), -100.0);
    assert_eq!(clamp_safe(0.0_f32, 100.0, -100.0), 0.0);
}

#[test]
fn test_clamp_range_struct_clamp() {
    let range = ClampRange::new(10, 30);
    assert_eq!(range.clamp(5), 10);
    assert_eq!(range.clamp(35), 30);
    assert_eq!(range.clamp(20), 20);
    assert_eq!(range.clamp(10), 10);
    assert_eq!(range.clamp(30), 30);
}

#[test]
fn test_clamp_range_struct_contains() {
    let range = ClampRange::new(10, 30);
    assert!(range.contains(10), "range should contain min boundary");
    assert!(range.contains(30), "range should contain max boundary");
    assert!(range.contains(20), "range should contain interior point");
    assert!(!range.contains(9), "range should not contain value below min");
    assert!(!range.contains(31), "range should not contain value above max");
}

#[test]
fn test_clamp_range_float_boundaries() {
    let range = ClampRange::new(-1.0_f64, 1.0_f64);
    assert_eq!(range.clamp(-2.5), -1.0);
    assert_eq!(range.clamp(2.5), 1.0);
    assert_eq!(range.clamp(0.0), 0.0);
    assert!(range.contains(-1.0));
    assert!(range.contains(1.0));
    assert!(range.contains(0.0));
    assert!(!range.contains(-1.0001));
    assert!(!range.contains(1.0001));
}

#[test]
fn test_clamp_ext_trait() {
    // Normal bounds
    assert_eq!((-5).clamp_range(0, 10), 0);
    assert_eq!(15.clamp_range(0, 10), 10);
    assert_eq!(7.clamp_range(0, 10), 7);

    // Inverted bounds via safe extension
    assert_eq!((-5).clamp_safe(10, 0), 0);
    assert_eq!(15.clamp_safe(10, 0), 10);
    assert_eq!(7.clamp_safe(10, 0), 7);
}

#[test]
fn test_clamp_nan_safe_contracts() {
    use zenith_core::clamp_nan_safe;

    // Normal values
    assert_eq!(clamp_nan_safe(5.0_f32, 0.0, 10.0, 0.0), 5.0);
    assert_eq!(clamp_nan_safe(-5.0_f32, 0.0, 10.0, 0.0), 0.0);
    assert_eq!(clamp_nan_safe(15.0_f32, 0.0, 10.0, 0.0), 10.0);

    // Inverted bounds normalizes automatically
    assert_eq!(clamp_nan_safe(15.0_f32, 10.0, 0.0, 0.0), 10.0);

    // NaN input falls back to default safely
    assert_eq!(clamp_nan_safe(f32::NAN, 0.0, 10.0, 42.0), 42.0);

    // Via ClampExt
    assert_eq!(f32::NAN.clamp_nan_safe(0.0, 10.0, 99.0), 99.0);
    assert_eq!(5.0_f32.clamp_nan_safe(0.0, 10.0, 99.0), 5.0);
}

#[test]
fn test_clamp_range_validation_and_span() {
    let valid_range = ClampRange::new(10.0_f32, 50.0_f32);
    assert!(valid_range.is_valid());
    assert_eq!(valid_range.span(), 40.0);

    let invalid_range = ClampRange::new(50.0_f32, 10.0_f32);
    assert!(!invalid_range.is_valid());
}

#[test]
fn test_clamp_safe_concurrency() {
    use std::thread;

    let range = ClampRange::new(0, 100);
    let mut handles = Vec::new();

    for i in 0..4 {
        let r = range;
        handles.push(thread::spawn(move || {
            for v in 0..50 {
                let clamped = r.clamp(v * i - 20);
                assert!(r.contains(clamped));
            }
        }));
    }

    for handle in handles {
        handle.join().expect("thread join failed");
    }
}

