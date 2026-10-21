//! Off-Screen Headless Integration Test Suite (Auto-Hide, Gaussian Curves & Desktop Canvas)

use std::sync::Mutex;
use zenith_tests::{realistic_canvas_script, realistic_dock_magnified_script};
use zenith_wayland::headless::HeadlessEngine;

static SUITE_MUTEX: Mutex<()> = Mutex::new(());

#[test]
fn test_offscreen_auto_hide_transitions() {
    let _lock = SUITE_MUTEX.lock().unwrap();
    let mut engine = HeadlessEngine::new().expect("Failed to initialize HeadlessEngine");

    let script = r##"
        return Zenith.Box({
            width = 1920,
            height = 42,
            background = Zenith.hex("#111318"),
            children = {
                Zenith.Text({ text = "Auto-Hide Status Bar", color = Zenith.hex("#ffffff") })
            }
        })
    "##;

    // 1. Normal state (no window collision): visible, full exclusive_zone
    let visible = engine
        .evaluate_auto_hide(script, 1920, 42, false, false, 2)
        .expect("Visible auto-hide evaluation failed");
    assert_eq!(visible.exclusive_zone, 42);
    assert_eq!(visible.visual_offset_y, 0.0);
    assert!(visible.is_visible);
    assert!(!visible.reveal_strip_active);
    assert_eq!(visible.boxes[0].width, 1920.0);
    assert_eq!(visible.boxes[0].height, 42.0);

    // 2. Window collision without hover: hidden, exclusive_zone 0, reveal strip active
    let hidden = engine
        .evaluate_auto_hide(script, 1920, 42, false, true, 2)
        .expect("Hidden auto-hide evaluation failed");
    assert_eq!(hidden.exclusive_zone, 0);
    assert_eq!(hidden.visual_offset_y, -40.0);
    assert!(!hidden.is_visible);
    assert!(hidden.reveal_strip_active);

    // 3. User cursor hovering reveal strip: revealed, full exclusive_zone
    let revealed = engine
        .evaluate_auto_hide(script, 1920, 42, true, true, 2)
        .expect("Revealed auto-hide evaluation failed");
    assert_eq!(revealed.exclusive_zone, 42);
    assert_eq!(revealed.visual_offset_y, 0.0);
    assert!(revealed.is_visible);
    assert!(!revealed.reveal_strip_active);
}

#[test]
fn test_offscreen_dock_gaussian_magnification() {
    let _lock = SUITE_MUTEX.lock().unwrap();
    let mut engine = HeadlessEngine::new().expect("Failed to initialize HeadlessEngine");

    let slot_centers = vec![30.0, 82.0, 134.0, 186.0, 238.0];
    let base_size = 44.0;
    let sigma = 45.0;
    let max_scale = 1.42;

    // Hover center slot (x = 134.0)
    let transforms = HeadlessEngine::compute_gaussian_magnification(
        &slot_centers,
        Some(134.0),
        base_size,
        sigma,
        max_scale,
    );

    assert_eq!(transforms.len(), 5);
    let peak_item = &transforms[2];
    assert!((peak_item.scale - max_scale).abs() < 0.01);
    assert_eq!(peak_item.width, (base_size * max_scale).round());

    // Neighbors should be scaled according to Gaussian decay
    let neighbor_item = &transforms[1];
    assert!(neighbor_item.scale > 1.0 && neighbor_item.scale < peak_item.scale);

    // Evaluate layout with realistic magnified dock script
    let dock_script = realistic_dock_magnified_script(peak_item.scale, neighbor_item.scale);
    let boxes = engine
        .compute_layout(&dock_script, 800, 80)
        .expect("Magnified dock layout computation failed");

    assert!(!boxes.is_empty());
    // Verify children count matches dock slots
    assert!(boxes.len() >= 5);
}

#[test]
fn test_offscreen_canvas_rendering_and_memory() {
    let _lock = SUITE_MUTEX.lock().unwrap();
    let mut engine = HeadlessEngine::new().expect("Failed to initialize HeadlessEngine");

    let script = realistic_canvas_script("12:34:56", 24.5, 62.0);

    // Warmup 1 frame
    let buf = engine
        .render_canvas_to_buffer(&script, 1920, 1080)
        .expect("Canvas render failed");
    assert_eq!(buf.len(), 1920 * 1080 * 4);

    // Verify non-empty rendering (has colored pixels)
    let mut non_zero_pixels = 0;
    for chunk in buf.chunks_exact(4) {
        if chunk[3] > 0 {
            non_zero_pixels += 1;
        }
    }
    assert!(
        non_zero_pixels > 1000,
        "Canvas rendering buffer should contain non-empty pixels"
    );

    // Multi-frame off-screen rendering stability loop
    for i in 0..10 {
        let time_str = format!("12:35:{:02}", i);
        let s = realistic_canvas_script(&time_str, 20.0 + (i as f32), 60.0 - (i as f32));
        let b = engine
            .render_canvas_to_buffer(&s, 1920, 1080)
            .expect("Canvas multi-frame render failed");
        assert_eq!(b.len(), 1920 * 1080 * 4);
    }
}
