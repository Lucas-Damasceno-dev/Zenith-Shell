//! Adversarial Red-Team Test Suite for Zenith Core.
//!
//! Rigorous validation for:
//! - Clamp bounds, numeric limits, subnormals, signed zeros, NaN fallback.
//! - Spring physics RK4 integration, edge-case delta times, micro-settling, state validation.
//! - Kinetic scroll rubber-band dynamics, overscroll resistance, instantaneous halt, boundary resizing.
//! - Multi-threaded concurrent torture testing under high-throughput contention.
//! - 100% Public API backward compatibility and Send + Sync guarantees.

use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use zenith_core::math;
use zenith_core::{
    clamp, clamp_nan_safe, clamp_safe, Animation, ClampExt, ClampRange,
    ConcurrentAnimation, ConcurrentScrollEngine, KineticScroll, KineticScrollEngine,
    KineticScrollError, ScrollEngine, SharedKineticScroll, SharedSpringAnimation,
    SpringAnimation, SpringConfig, SpringError,
};

// ============================================================================
// 1. ADVERSARIAL CLAMP & NUMERIC EXTREMES
// ============================================================================

#[test]
fn test_adversarial_clamp_numeric_limits_and_signed_zeros() {
    // Extreme integer limits
    assert_eq!(clamp(i128::MIN, -1_000_000, 1_000_000), -1_000_000);
    assert_eq!(clamp(i128::MAX, -1_000_000, 1_000_000), 1_000_000);
    assert_eq!(clamp(0_i128, i128::MIN, i128::MAX), 0);
    assert_eq!(clamp(u128::MAX, 10, 20), 20);

    // Floating-point extreme limits
    assert_eq!(clamp(f32::MIN, -100.0, 100.0), -100.0);
    assert_eq!(clamp(f32::MAX, -100.0, 100.0), 100.0);
    assert_eq!(clamp(f32::MIN_POSITIVE, 0.0, 1.0), f32::MIN_POSITIVE);
    assert_eq!(clamp(1e-40_f32, 0.0, 1.0), 1e-40_f32); // subnormal

    // Inverted bounds via clamp_safe
    assert_eq!(clamp_safe(f32::MAX, 10.0, -10.0), 10.0);
    assert_eq!(clamp_safe(f32::MIN, 10.0, -10.0), -10.0);
    assert_eq!(clamp_safe(0.0_f32, 100.0, -100.0), 0.0);

    // Signed zeros: -0.0 and +0.0 comparison behavior
    let neg_zero = -0.0_f32;
    let pos_zero = 0.0_f32;
    assert_eq!(clamp(neg_zero, pos_zero, 1.0), pos_zero);
    assert_eq!(clamp_safe(neg_zero, 1.0, pos_zero), pos_zero);

    // Inverted identical bounds
    assert_eq!(clamp_safe(5.0, 10.0, 10.0), 10.0);
    assert_eq!(clamp_safe(15.0, 10.0, 10.0), 10.0);
}

#[test]
fn test_adversarial_clamp_nan_safe_exhaustive() {
    // NaN input MUST fall back to fallback value
    assert_eq!(clamp_nan_safe(f32::NAN, 0.0, 100.0, -999.0), -999.0);
    assert_eq!(clamp_nan_safe(f32::NAN, 100.0, 0.0, 42.0), 42.0); // inverted bounds + NaN input
    assert_eq!(clamp_nan_safe(f32::NAN, f32::NAN, 10.0, 5.0), 5.0);

    // Valid inputs must not trigger fallback even when close to boundaries
    assert_eq!(clamp_nan_safe(0.0_f32, 0.0, 10.0, -1.0), 0.0);
    assert_eq!(clamp_nan_safe(10.0_f32, 0.0, 10.0, -1.0), 10.0);
    assert_eq!(clamp_nan_safe(-0.0001_f32, 0.0, 10.0, -1.0), 0.0);
    assert_eq!(clamp_nan_safe(10.0001_f32, 0.0, 10.0, -1.0), 10.0);

    // Via ClampExt trait
    assert_eq!(f32::NAN.clamp_nan_safe(0.0, 100.0, 77.0), 77.0);
    assert_eq!(50.0_f32.clamp_nan_safe(0.0, 100.0, 77.0), 50.0);
    assert_eq!((-50.0_f32).clamp_nan_safe(0.0, 100.0, 77.0), 0.0);
    assert_eq!(150.0_f32.clamp_nan_safe(0.0, 100.0, 77.0), 100.0);
}

#[test]
fn test_adversarial_clamp_range_edge_cases() {
    // Degenerate range [min == max]
    let degen = ClampRange::new(5.0_f32, 5.0_f32);
    assert!(degen.is_valid());
    assert_eq!(degen.span(), 0.0);
    assert_eq!(degen.clamp(0.0), 5.0);
    assert_eq!(degen.clamp(10.0), 5.0);
    assert_eq!(degen.clamp(5.0), 5.0);
    assert!(degen.contains(5.0));
    assert!(!degen.contains(4.9999));
    assert!(!degen.contains(5.0001));

    // Inverted range [min > max]
    let inverted = ClampRange::new(100.0_f32, 0.0_f32);
    assert!(!inverted.is_valid());
    assert_eq!(inverted.span(), -100.0);

    // Negative range [-100.0, -50.0]
    let neg_range = ClampRange::new(-100.0_f32, -50.0_f32);
    assert!(neg_range.is_valid());
    assert_eq!(neg_range.span(), 50.0);
    assert_eq!(neg_range.clamp(-150.0), -100.0);
    assert_eq!(neg_range.clamp(-20.0), -50.0);
    assert_eq!(neg_range.clamp(-75.0), -75.0);

    // Infinite range
    let inf_range = ClampRange::new(f32::NEG_INFINITY, f32::INFINITY);
    assert!(inf_range.is_valid());
    assert!(inf_range.contains(0.0));
    assert!(inf_range.contains(f32::MAX));
    assert!(inf_range.contains(f32::MIN));
    assert_eq!(inf_range.clamp(42.0), 42.0);
}

#[test]
fn test_adversarial_clamp_mathematical_properties() {
    let min = -15.5_f32;
    let max = 45.2_f32;

    // 1. Idempotency: clamp(clamp(x)) == clamp(x)
    for i in -200..200 {
        let x = i as f32 * 0.75;
        let c1 = clamp(x, min, max);
        let c2 = clamp(c1, min, max);
        assert_eq!(c1, c2, "Idempotency failed for x={}", x);
    }

    // 2. Monotonicity: if x1 <= x2, then clamp(x1) <= clamp(x2)
    for i in -100..100 {
        let x1 = i as f32;
        let x2 = x1 + 0.5;
        assert!(
            clamp(x1, min, max) <= clamp(x2, min, max),
            "Monotonicity failed for x1={}, x2={}",
            x1,
            x2
        );
    }
}

// ============================================================================
// 2. ADVERSARIAL SPRING PHYSICS & ODE INTEGRATION
// ============================================================================

#[test]
fn test_adversarial_spring_config_invalid_parameters() {
    // Stiffness <= 0.0 or non-finite
    let invalid_stiffnesses = [0.0, -10.0, -0.0001, f32::NAN, f32::INFINITY, f32::NEG_INFINITY];
    for &k in &invalid_stiffnesses {
        let config = SpringConfig {
            stiffness: k,
            damping: 20.0,
            mass: 1.0,
            precision: 0.001,
        };
        assert!(
            matches!(config.validate(), Err(SpringError::InvalidParameter { parameter: "stiffness", .. })),
            "Expected InvalidParameter for stiffness={}",
            k
        );
    }

    // Damping < 0.0 or non-finite (damping == 0.0 is physically valid for undamped oscillator)
    let invalid_dampings = [-1.0, -0.0001, f32::NAN, f32::INFINITY, f32::NEG_INFINITY];
    for &c in &invalid_dampings {
        let config = SpringConfig {
            stiffness: 100.0,
            damping: c,
            mass: 1.0,
            precision: 0.001,
        };
        assert!(
            matches!(config.validate(), Err(SpringError::InvalidParameter { parameter: "damping", .. })),
            "Expected InvalidParameter for damping={}",
            c
        );
    }

    // Mass <= 0.0 or non-finite
    let invalid_masses = [0.0, -1.0, -0.0001, f32::NAN, f32::INFINITY, f32::NEG_INFINITY];
    for &m in &invalid_masses {
        let config = SpringConfig {
            stiffness: 100.0,
            damping: 20.0,
            mass: m,
            precision: 0.001,
        };
        assert!(
            matches!(config.validate(), Err(SpringError::InvalidParameter { parameter: "mass", .. })),
            "Expected InvalidParameter for mass={}",
            m
        );
    }

    // Precision <= 0.0 or non-finite
    let invalid_precisions = [0.0, -0.001, f32::NAN, f32::INFINITY, f32::NEG_INFINITY];
    for &p in &invalid_precisions {
        let config = SpringConfig {
            stiffness: 100.0,
            damping: 20.0,
            mass: 1.0,
            precision: p,
        };
        assert!(
            matches!(config.validate(), Err(SpringError::InvalidParameter { parameter: "precision", .. })),
            "Expected InvalidParameter for precision={}",
            p
        );
    }

    // Zero damping is valid (undamped harmonic motion)
    let undamped = SpringConfig {
        stiffness: 100.0,
        damping: 0.0,
        mass: 1.0,
        precision: 0.001,
    };
    assert!(undamped.validate().is_ok());
}

#[test]
fn test_adversarial_spring_step_safe_delta_time_attacks() {
    let mut spring = SpringAnimation::new(0.0, 100.0);

    // Negative delta times
    assert_eq!(spring.step_safe(-0.0001), Err(SpringError::InvalidDeltaTime(-0.0001)));
    assert_eq!(spring.step_safe(-10.0), Err(SpringError::InvalidDeltaTime(-10.0)));

    // Non-finite delta times
    assert!(matches!(spring.step_safe(f32::NAN), Err(SpringError::InvalidDeltaTime(v)) if v.is_nan()));
    assert_eq!(spring.step_safe(f32::INFINITY), Err(SpringError::InvalidDeltaTime(f32::INFINITY)));
    assert_eq!(spring.step_safe(f32::NEG_INFINITY), Err(SpringError::InvalidDeltaTime(f32::NEG_INFINITY)));

    // Zero delta time should safely advance nothing
    let before = spring.current;
    let res = spring.step_safe(0.0);
    assert!(res.is_ok());
    assert_eq!(res.unwrap(), before);
    assert_eq!(spring.current, before);
    assert_eq!(spring.velocity, 0.0);

    // Micro delta time (numerical stability of RK4)
    for _ in 0..100 {
        let micro_res = spring.step_safe(1e-6);
        assert!(micro_res.is_ok());
        assert!(micro_res.unwrap().is_finite());
    }
}

#[test]
fn test_adversarial_spring_state_corruption_attacks() {
    // Non-finite current
    let mut spring = SpringAnimation::new(0.0, 100.0);
    spring.current = f32::NAN;
    assert!(matches!(spring.validate(), Err(SpringError::NonFiniteState { .. })));
    assert!(matches!(spring.step_safe(0.016), Err(SpringError::NonFiniteState { .. })));

    // Infinite velocity
    let mut spring = SpringAnimation::new(0.0, 100.0);
    spring.velocity = f32::INFINITY;
    assert!(matches!(spring.validate(), Err(SpringError::NonFiniteState { .. })));
    assert!(matches!(spring.step_safe(0.016), Err(SpringError::NonFiniteState { .. })));

    // Infinite target
    let mut spring = SpringAnimation::new(0.0, 100.0);
    spring.target = f32::NEG_INFINITY;
    assert!(matches!(spring.validate(), Err(SpringError::NonFiniteState { .. })));
    assert!(matches!(spring.step_safe(0.016), Err(SpringError::NonFiniteState { .. })));
}

#[test]
fn test_adversarial_spring_subpixel_snapping_boundaries() {
    let target = 200.0_f32;
    let precision = 0.001_f32;

    // Just outside precision threshold -> not settled
    let s1 = SpringAnimation::new(target + precision * 1.5, target);
    assert!(!s1.is_settled());

    // Just inside precision threshold with zero velocity -> settled immediately
    let mut s2 = SpringAnimation::new(target + precision * 0.5, target);
    assert!(s2.is_settled());
    s2.step(0.016);
    assert_eq!(s2.current, target);
    assert_eq!(s2.velocity, 0.0);

    // Inside displacement threshold but high velocity -> NOT settled
    let mut s3 = SpringAnimation::new(target + precision * 0.1, target);
    s3.velocity = 5.0;
    assert!(!s3.is_settled());
    s3.step(0.016);
    // Should move according to velocity
    assert_ne!(s3.current, target);
}

#[test]
fn test_adversarial_spring_momentum_reversal_under_heavy_load() {
    let mut spring = SpringAnimation::new(0.0, 500.0);
    // Accelerate for 20 frames
    for _ in 0..20 {
        spring.step(0.016);
    }
    assert!(spring.velocity > 10.0, "Spring should have built substantial velocity");

    // Invert target abruptly to the opposite extreme
    spring.set_target(-500.0);
    assert_eq!(spring.target, -500.0);

    // Step through the reversal without panic or numeric instability
    for _ in 0..600 {
        let val = spring.step(0.016);
        assert!(val.is_finite(), "Spring state must remain finite under reversal");
        if spring.is_settled() {
            break;
        }
    }

    assert!(spring.is_settled());
    assert_eq!(spring.current, -500.0);
    assert_eq!(spring.velocity, 0.0);
}

#[test]
fn test_adversarial_spring_reset_contract() {
    let mut spring = SpringAnimation::new(0.0, 100.0);
    for _ in 0..10 {
        spring.step(0.016);
    }
    assert_ne!(spring.velocity, 0.0);

    // Calling reset must set both current and target to new value, and zero velocity
    spring.reset(42.0);
    assert_eq!(spring.current, 42.0);
    assert_eq!(spring.target, 42.0);
    assert_eq!(spring.velocity, 0.0);
    assert!(spring.is_settled());
}

// ============================================================================
// 3. ADVERSARIAL KINETIC SCROLL & RUBBER-BAND DYNAMICS
// ============================================================================

#[test]
fn test_adversarial_kinetic_scroll_validation_errors() {
    // Inverted bounds min > max
    let mut engine = KineticScrollEngine::new(100.0, 500.0);
    engine.min_offset = 600.0;
    engine.max_offset = 500.0;
    assert_eq!(
        engine.validate(),
        Err(KineticScrollError::InvalidBounds { min: 600.0, max: 500.0 })
    );

    // Non-finite bounds
    let engine_nan = KineticScrollEngine::new(f32::NAN, 100.0);
    assert!(matches!(engine_nan.validate(), Err(KineticScrollError::InvalidBounds { .. })));

    let engine_inf = KineticScrollEngine::new(0.0, f32::INFINITY);
    assert!(matches!(engine_inf.validate(), Err(KineticScrollError::InvalidBounds { .. })));

    // Invalid friction (must be in (0.0, 1.0))
    let invalid_frictions = [0.0, 1.0, -0.1, 1.5, f32::NAN, f32::INFINITY];
    for &f in &invalid_frictions {
        let mut e = KineticScrollEngine::new(0.0, 100.0);
        e.friction = f;
        assert!(
            matches!(e.validate(), Err(KineticScrollError::InvalidFriction(v)) if v.is_nan() || v == f),
            "Expected InvalidFriction for friction={}",
            f
        );
    }

    // Non-finite offset or velocity
    let mut e = KineticScrollEngine::new(0.0, 100.0);
    e.offset = f32::NAN;
    assert!(matches!(e.validate(), Err(KineticScrollError::NonFiniteInput(..))));

    let mut e2 = KineticScrollEngine::new(0.0, 100.0);
    e2.velocity = f32::INFINITY;
    assert!(matches!(e2.validate(), Err(KineticScrollError::NonFiniteInput(..))));
}

#[test]
fn test_adversarial_kinetic_scroll_step_safe_delta_time() {
    let mut engine = KineticScrollEngine::new(0.0, 1000.0);

    // Negative delta times
    assert_eq!(engine.step_safe(-0.016), Err(KineticScrollError::NonFiniteInput(-0.016)));
    assert_eq!(engine.step_safe(-1.0), Err(KineticScrollError::NonFiniteInput(-1.0)));

    // NaN / Infinity
    assert!(matches!(engine.step_safe(f32::NAN), Err(KineticScrollError::NonFiniteInput(v)) if v.is_nan()));
    assert_eq!(engine.step_safe(f32::INFINITY), Err(KineticScrollError::NonFiniteInput(f32::INFINITY)));

    // Zero delta time: safe no-op
    assert_eq!(engine.step_safe(0.0).unwrap(), 0.0);
}

#[test]
fn test_adversarial_kinetic_scroll_massive_impulse_and_rubber_band_recovery() {
    let min = 0.0_f32;
    let max = 500.0_f32;
    let mut engine = KineticScrollEngine::new(min, max);

    // Catastrophic impulse pushing way beyond max bounds
    engine.add_impulse(100_000.0);
    assert!(engine.velocity > 1000.0);

    // Step into overscroll
    for _ in 0..15 {
        engine.step(0.016);
    }

    // Offset must have entered overscroll beyond max
    assert!(engine.offset > max, "Offset {} should have exceeded max {}", engine.offset, max);
    assert!(!engine.is_settled(), "Engine must not be settled during overscroll");

    // Rubber-band spring must progressively restore it back to max
    let mut restored = false;
    for _ in 0..500 {
        engine.step(0.016);
        if engine.is_settled() {
            restored = true;
            break;
        }
    }

    assert!(restored, "Kinetic scroll failed to settle after overscroll");
    assert!(
        engine.offset >= min - 0.01 && engine.offset <= max + 0.01,
        "Offset {} must settle within valid bounds [{}, {}]",
        engine.offset,
        min,
        max
    );
    assert_eq!(engine.velocity, 0.0);
}

#[test]
fn test_adversarial_kinetic_scroll_rapid_alternating_impulses() {
    let mut engine = KineticScrollEngine::new(-500.0, 500.0);

    // Alternating sharp gestures simulating user shaking wheel / touch trackpad
    for i in 0..40 {
        let sign = if i % 2 == 0 { 1.0 } else { -1.0 };
        engine.add_impulse(sign * 25.0);
        engine.step(0.016);
        assert!(engine.offset.is_finite());
        assert!(engine.velocity.is_finite());
    }

    // After gestures stop, system must decay and settle without endless runaway
    for _ in 0..300 {
        engine.step(0.016);
        if engine.is_settled() {
            break;
        }
    }
    assert!(engine.is_settled(), "Engine must settle after frantic alternating input");
}

#[test]
fn test_adversarial_kinetic_scroll_instant_halt_in_overscroll() {
    let mut engine = KineticScrollEngine::new(0.0, 300.0);
    engine.add_impulse(5000.0);
    for _ in 0..10 {
        engine.step(0.016);
    }

    // Verify it is in flight beyond bounds
    assert!(engine.offset > 300.0);
    assert!(engine.velocity > 0.0);

    // Instant stop must clamp immediately to boundaries and zero velocity
    engine.stop();
    assert_eq!(engine.offset, 300.0);
    assert_eq!(engine.velocity, 0.0);
    assert!(engine.is_settled());
}

#[test]
fn test_adversarial_kinetic_scroll_dynamic_bounds_resizing() {
    let mut engine = KineticScrollEngine::new(0.0, 1000.0);
    engine.set_offset(800.0);
    assert_eq!(engine.offset, 800.0);

    // Dynamically contract bounds so current offset is suddenly out-of-bounds
    engine.set_bounds(0.0, 400.0);
    assert_eq!(engine.bounds(), (0.0, 400.0));

    // Next steps must recognize overscroll and snap/spring back to new bound
    for _ in 0..300 {
        engine.step(0.016);
        if engine.is_settled() {
            break;
        }
    }
    assert!(engine.is_settled());
    assert!(
        engine.offset >= -0.01 && engine.offset <= 400.01,
        "Offset {} must settle within new bounds [0.0, 400.0]",
        engine.offset
    );
}

// ============================================================================
// 4. MULTITHREADED CONCURRENT TORTURE & SYNCHRONIZATION
// ============================================================================

#[test]
fn test_adversarial_concurrent_shared_spring_torture() {
    let shared = SharedSpringAnimation::new(0.0, 100.0);
    let running = Arc::new(AtomicBool::new(true));
    let step_count = Arc::new(AtomicUsize::new(0));

    let mut handles = Vec::new();

    // 2 Stepper Threads (continually stepping)
    for _ in 0..2 {
        let s = shared.clone();
        let r = running.clone();
        let sc = step_count.clone();
        handles.push(thread::spawn(move || {
            while r.load(Ordering::Relaxed) {
                let pos = s.step(0.016);
                assert!(pos.is_finite());
                sc.fetch_add(1, Ordering::Relaxed);
            }
        }));
    }

    // 2 Target Flipper Threads (continually changing targets between extremes)
    for id in 0..2 {
        let s = shared.clone();
        let r = running.clone();
        handles.push(thread::spawn(move || {
            let mut flip = true;
            while r.load(Ordering::Relaxed) {
                let target = if flip { (id as f32 + 1.0) * 500.0 } else { -(id as f32 + 1.0) * 500.0 };
                s.set_target(target);
                flip = !flip;
                thread::yield_now();
            }
        }));
    }

    // 2 Inspection Threads (reading values)
    for _ in 0..2 {
        let s = shared.clone();
        let r = running.clone();
        handles.push(thread::spawn(move || {
            while r.load(Ordering::Relaxed) {
                let cur = s.current();
                let tgt = s.target();
                let _ = s.is_settled();
                assert!(cur.is_finite());
                assert!(tgt.is_finite());
                thread::yield_now();
            }
        }));
    }

    // 2 Resetter Threads (periodically calling reset)
    for _ in 0..2 {
        let s = shared.clone();
        let r = running.clone();
        handles.push(thread::spawn(move || {
            while r.load(Ordering::Relaxed) {
                s.reset(0.0);
                thread::sleep(Duration::from_millis(1));
            }
        }));
    }

    // Run torture for 50ms
    thread::sleep(Duration::from_millis(50));
    running.store(false, Ordering::Relaxed);

    for h in handles {
        h.join().expect("Worker thread panicked during torture");
    }

    assert!(step_count.load(Ordering::Relaxed) > 10, "Steppers did not execute sufficient iterations");
    assert!(shared.current().is_finite());
}

#[test]
fn test_adversarial_concurrent_shared_kinetic_scroll_torture() {
    let shared = SharedKineticScroll::new(0.0, 1000.0);
    let running = Arc::new(AtomicBool::new(true));
    let mut handles = Vec::new();

    // 2 Impulse Injector Threads
    for id in 0..2 {
        let s = shared.clone();
        let r = running.clone();
        handles.push(thread::spawn(move || {
            let delta = if id == 0 { 5.0 } else { -5.0 };
            while r.load(Ordering::Relaxed) {
                s.add_impulse(delta);
                s.on_scroll(1.0);
                thread::yield_now();
            }
        }));
    }

    // 2 Simulation Stepper Threads
    for _ in 0..2 {
        let s = shared.clone();
        let r = running.clone();
        handles.push(thread::spawn(move || {
            while r.load(Ordering::Relaxed) {
                let off = s.step(0.016);
                assert!(off.is_finite());
            }
        }));
    }

    // 2 Bounds and Stopper Threads
    for _ in 0..2 {
        let s = shared.clone();
        let r = running.clone();
        handles.push(thread::spawn(move || {
            while r.load(Ordering::Relaxed) {
                s.set_bounds(-100.0, 2000.0);
                let _ = s.bounds();
                s.stop();
                thread::sleep(Duration::from_millis(1));
            }
        }));
    }

    // 2 Reader Threads
    for _ in 0..2 {
        let s = shared.clone();
        let r = running.clone();
        handles.push(thread::spawn(move || {
            while r.load(Ordering::Relaxed) {
                let off = s.offset();
                let _ = s.is_settled();
                let (min, max) = s.bounds();
                assert!(off.is_finite());
                assert!(min <= max);
                thread::yield_now();
            }
        }));
    }

    thread::sleep(Duration::from_millis(50));
    running.store(false, Ordering::Relaxed);

    for h in handles {
        h.join().expect("Kinetic scroll worker thread panicked");
    }

    assert!(shared.offset().is_finite());
}

// ============================================================================
// 5. PUBLIC API RETROCOMPATIBILITY & TYPE CONTRACTS
// ============================================================================

#[test]
fn test_adversarial_public_api_retrocompatibility() {
    // 1. Direct struct field access on SpringAnimation
    let mut sa = SpringAnimation::new(10.0, 20.0);
    sa.current = 15.0;
    sa.target = 25.0;
    sa.velocity = -2.0;
    sa.config.stiffness = 200.0;
    sa.config.damping = 25.0;
    sa.config.mass = 1.2;
    sa.config.precision = 0.005;

    assert_eq!(sa.current, 15.0);
    assert_eq!(sa.target, 25.0);
    assert_eq!(sa.velocity, -2.0);
    assert_eq!(sa.config.stiffness, 200.0);

    // 2. Direct struct field access on KineticScrollEngine and KineticScroll alias
    let mut kse: KineticScroll = KineticScrollEngine::new(0.0, 500.0);
    kse.offset = 50.0;
    kse.velocity = 10.0;
    kse.min_offset = -10.0;
    kse.max_offset = 600.0;
    kse.friction = 0.96;

    assert_eq!(kse.offset, 50.0);
    assert_eq!(kse.velocity, 10.0);
    assert_eq!(kse.min_offset, -10.0);
    assert_eq!(kse.max_offset, 600.0);
    assert_eq!(kse.friction, 0.96);

    // 3. Module re-export math::*
    assert_eq!(math::clamp(5, 0, 10), 5);
    assert_eq!(math::clamp_safe(15, 10, 0), 10);
    assert_eq!(math::clamp_nan_safe(f32::NAN, 0.0, 1.0, 0.5), 0.5);
    let r = math::ClampRange::new(0.0, 1.0);
    assert_eq!(r.span(), 1.0);

    // 4. Dynamic Trait Object Dispatch
    let mut anim_dyn: Box<dyn Animation<f32>> = Box::new(sa);
    assert_eq!(anim_dyn.current(), 15.0);
    assert_eq!(anim_dyn.target(), 25.0);
    let _ = anim_dyn.step(0.016);

    let mut scroll_dyn: Box<dyn ScrollEngine> = Box::new(kse);
    assert_eq!(scroll_dyn.offset(), 50.0);
    assert_eq!(scroll_dyn.bounds(), (-10.0, 600.0));
    let _ = scroll_dyn.step(0.016);
}

#[test]
fn test_adversarial_send_sync_thread_movement() {
    // Compile-time and runtime check that Animation and ScrollEngine types can cross threads
    fn move_across_threads<T: Send + 'static>(val: T) {
        let h = thread::spawn(move || {
            let _ = val;
        });
        h.join().unwrap();
    }

    fn assert_concurrent_animation<T: ConcurrentAnimation>() {}
    fn assert_concurrent_scroll<T: ConcurrentScrollEngine>() {}

    assert_concurrent_animation::<SharedSpringAnimation>();
    assert_concurrent_scroll::<SharedKineticScroll>();

    move_across_threads(SpringAnimation::new(0.0, 1.0));
    move_across_threads(KineticScrollEngine::new(0.0, 1.0));
    move_across_threads(SharedSpringAnimation::new(0.0, 1.0));
    move_across_threads(SharedKineticScroll::new(0.0, 1.0));
}
