use zenith_core::magnification::{MagnificationConfig, MagnificationCurve, MagnificationModel};
use zenith_layout::{apply_dock_magnification, Color, ComputedBox, Overflow};

fn make_box(x: f32, y: f32, size: f32) -> ComputedBox {
    ComputedBox {
        x,
        y,
        width: size,
        height: size,
        background_color: Color::rgb(40, 40, 40),
        border_color: Color::rgb(255, 255, 255),
        border_width: 1.0,
        border_radius: 8.0,
        shadow: None,
        custom_shader: None,
        text: None,
        image: None,
        text_input: None,
        slider: None,
        switch: None,
        overflow: Overflow::Visible,
        scroll_offset_y: 0.0,
        clip_rect: None,
        on_click: None,
        on_right_click: None,
        on_scroll_up: None,
        on_scroll_down: None,
        tooltip: None,
        tooltip_active: false,
    }
}

#[test]
fn test_apply_dock_magnification_in_place() {
    let mut items = vec![
        make_box(10.0, 10.0, 48.0),
        make_box(68.0, 10.0, 48.0), // center at 92.0
        make_box(126.0, 10.0, 48.0),
    ];

    let config = MagnificationConfig {
        max_scale: 1.5,
        influence_radius: 80.0,
        curve: MagnificationCurve::Cosine,
        anchor_bottom: true,
    };
    let model = MagnificationModel::new(config);

    // Hover exactly over item 1 center (68 + 24 = 92)
    apply_dock_magnification(&mut items, &model, Some(92.0), true);

    // Middle item should be enlarged to 48 * 1.5 = 72
    assert!((items[1].width - 72.0).abs() < 1e-3);
    assert!((items[1].height - 72.0).abs() < 1e-3);

    // Bottom anchor: original bottom was 10.0 + 48.0 = 58.0
    // New y must be 58.0 - 72.0 = -14.0
    assert!((items[1].y - (-14.0)).abs() < 1e-3);

    // Left and right items should be pushed outward without overlapping
    assert!(items[0].x + items[0].width <= items[1].x);
    assert!(items[1].x + items[1].width <= items[2].x);
}

#[test]
fn test_dock_magnification_none_leaves_unchanged() {
    let mut items = vec![
        make_box(10.0, 10.0, 48.0),
        make_box(68.0, 10.0, 48.0),
    ];
    let orig = items.clone();

    let config = MagnificationConfig::default();
    let model = MagnificationModel::new(config);

    apply_dock_magnification(&mut items, &model, None, true);

    assert_eq!(items, orig);
}
