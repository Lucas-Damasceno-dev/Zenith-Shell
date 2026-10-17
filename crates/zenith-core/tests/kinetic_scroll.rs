use std::thread;
use zenith_core::{KineticScroll, KineticScrollEngine, KineticScrollError, ScrollEngine, SharedKineticScroll};

#[test]
fn test_kinetic_scroll_public_api_compatibility() {
    // Both KineticScrollEngine and KineticScroll alias should work identically
    let mut engine: KineticScroll = KineticScrollEngine::new(0.0, 500.0);
    assert_eq!(engine.offset(), 0.0);
    assert_eq!(engine.offset, 0.0);
    assert_eq!(engine.min_offset, 0.0);
    assert_eq!(engine.max_offset, 500.0);

    engine.add_impulse(5.0);
    assert!(engine.velocity > 0.0);

    engine.on_scroll(10.0);
    assert_eq!(engine.offset, 10.0);

    let _ = engine.step(0.016);
    let _ = engine.is_settled();
    engine.stop();
    assert_eq!(engine.velocity, 0.0);
}

#[test]
fn test_kinetic_scroll_engine_trait_contract() {
    let mut engine: Box<dyn ScrollEngine> = Box::new(KineticScrollEngine::new(0.0, 1000.0));
    assert_eq!(engine.offset(), 0.0);
    assert_eq!(engine.bounds(), (0.0, 1000.0));

    engine.set_offset(150.0);
    assert_eq!(engine.offset(), 150.0);

    engine.add_impulse(10.0);
    let next = engine.step(0.016);
    assert!(next > 150.0);

    engine.stop();
    assert_eq!(engine.bounds(), (0.0, 1000.0));
}

#[test]
fn test_kinetic_scroll_validation_and_safe_step_edge_cases() {
    let mut engine = KineticScrollEngine::new(0.0, 500.0);

    // Negative delta time error contract
    assert_eq!(
        engine.step_safe(-0.016),
        Err(KineticScrollError::NonFiniteInput(-0.016))
    );

    // NaN delta time error contract
    assert!(matches!(
        engine.step_safe(f32::NAN),
        Err(KineticScrollError::NonFiniteInput(v)) if v.is_nan()
    ));

    // Inverted bounds validation contract
    engine.min_offset = 600.0;
    engine.max_offset = 500.0;
    assert_eq!(
        engine.validate(),
        Err(KineticScrollError::InvalidBounds { min: 600.0, max: 500.0 })
    );
}

#[test]
fn test_kinetic_scroll_safe_concurrency_multithreaded() {
    let shared = SharedKineticScroll::new(0.0, 1000.0);
    let mut handles = Vec::new();

    for i in 0..4 {
        let s = shared.clone();
        handles.push(thread::spawn(move || {
            for _j in 0..30 {
                if i % 2 == 0 {
                    s.add_impulse(1.0);
                    let _ = s.step(0.016);
                } else {
                    let _ = s.offset();
                    let _ = s.is_settled();
                    let _ = s.bounds();
                }
            }
        }));
    }

    for handle in handles {
        handle.join().expect("thread join failed");
    }

    assert!(shared.offset() >= 0.0);
}
