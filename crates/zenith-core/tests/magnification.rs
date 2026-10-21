use zenith_core::magnification::{
    MagnificationConfig, MagnificationCurve, MagnificationModel, MagnificationSpringTracker,
};

#[test]
fn test_magnification_model_cosine_scale() {
    let config = MagnificationConfig {
        max_scale: 1.6,
        influence_radius: 100.0,
        curve: MagnificationCurve::Cosine,
        anchor_bottom: true,
    };
    let model = MagnificationModel::new(config);

    // Exact focal point
    let center_scale = model.compute_scale(50.0, 50.0);
    assert!((center_scale - 1.6).abs() < 1e-4);

    // Beyond influence radius
    let far_scale = model.compute_scale(50.0, 200.0);
    assert!((far_scale - 1.0).abs() < 1e-4);

    // Halfway point
    let half_scale = model.compute_scale(50.0, 100.0);
    assert!(half_scale > 1.0 && half_scale < 1.6);
}

#[test]
fn test_magnification_model_gaussian_scale() {
    let config = MagnificationConfig {
        max_scale: 1.5,
        influence_radius: 120.0,
        curve: MagnificationCurve::Gaussian,
        anchor_bottom: true,
    };
    let model = MagnificationModel::new(config);

    let peak = model.compute_scale(100.0, 100.0);
    assert!((peak - 1.5).abs() < 1e-4);

    let edge = model.compute_scale(100.0, 250.0);
    assert_eq!(edge, 1.0);
}

#[test]
fn test_magnification_spring_tracker_settling() {
    let mut tracker = MagnificationSpringTracker::new(3);
    let mut current = [0.0f32; 3];

    tracker.current_scales(&mut current);
    assert_eq!(current, [1.0, 1.0, 1.0]);

    // Target change: focal item 1 magnifies to 1.6
    let targets = [1.0, 1.6, 1.0];
    let mut active = true;
    for _ in 0..100 {
        if !active {
            break;
        }
        active = tracker.update(&targets, 1.0 / 60.0, &mut current);
    }

    assert!((current[1] - 1.6).abs() < 0.05);
}
