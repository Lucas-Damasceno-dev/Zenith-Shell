use std::thread;
use zenith_core::{Animation, SharedSpringAnimation, SpringAnimation, SpringConfig, SpringError};

#[test]
fn test_spring_public_api_compatibility() {
    let mut spring = SpringAnimation::new(0.0, 100.0);
    assert_eq!(spring.current, 0.0);
    assert_eq!(spring.target, 100.0);
    assert_eq!(spring.velocity, 0.0);

    spring = spring.with_config(SpringConfig::gentle());
    spring.set_target(50.0);
    assert_eq!(spring.target, 50.0);

    let _ = spring.step(0.016);
    let _ = spring.is_settled();
}

#[test]
fn test_spring_animation_trait_contract() {
    let mut anim: Box<dyn Animation<f32>> = Box::new(SpringAnimation::new(10.0, 20.0));
    assert_eq!(anim.current(), 10.0);
    assert_eq!(anim.target(), 20.0);
    assert_eq!(anim.velocity(), 0.0);

    anim.set_target(30.0);
    assert_eq!(anim.target(), 30.0);

    let next = anim.step(0.016);
    assert!(next > 10.0);

    anim.reset(0.0);
    assert_eq!(anim.current(), 0.0);
    assert_eq!(anim.target(), 0.0);
    assert_eq!(anim.velocity(), 0.0);
}

#[test]
fn test_spring_validation_and_safe_step_edge_cases() {
    let mut spring = SpringAnimation::new(0.0, 100.0);

    // Negative delta time error contract
    assert_eq!(
        spring.step_safe(-0.016),
        Err(SpringError::InvalidDeltaTime(-0.016))
    );

    // NaN delta time error contract
    assert!(matches!(
        spring.step_safe(f32::NAN),
        Err(SpringError::InvalidDeltaTime(v)) if v.is_nan()
    ));

    // Valid step
    assert!(spring.step_safe(0.016).is_ok());

    // Non-finite state validation contract
    spring.current = f32::NAN;
    assert!(matches!(
        spring.validate(),
        Err(SpringError::NonFiniteState { .. })
    ));
}

#[test]
fn test_spring_safe_concurrency_multithreaded() {
    let shared = SharedSpringAnimation::new(0.0, 100.0);
    let mut handles = Vec::new();

    for _ in 0..4 {
        let s = shared.clone();
        handles.push(thread::spawn(move || {
            for _ in 0..50 {
                let _ = s.step(0.016);
                let _ = s.current();
                let _ = s.is_settled();
            }
        }));
    }

    for handle in handles {
        handle.join().expect("thread join failed");
    }

    assert!(shared.current() > 0.0);
}
