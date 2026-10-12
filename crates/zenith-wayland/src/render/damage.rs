//! Partial damage tracking and dirty rect computation for Zenith Base v3.
//!
//! Enables hardware-accelerated partial updates via `glScissor`, `wl_surface.damage_buffer`,
//! and `EGL_EXT_swap_buffers_with_damage`.

use zenith_layout::ComputedBox;

/// Axis-aligned bounding box of dirty screen damage in surface pixel coordinates.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DamageRect {
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
}

impl DamageRect {
    pub fn new(x: i32, y: i32, width: i32, height: i32) -> Self {
        Self {
            x,
            y,
            width: width.max(1),
            height: height.max(1),
        }
    }

    /// Converts surface damage rect (top-left origin) to EGL damage rect format [x, y_bottom_left, width, height].
    pub fn to_egl_coords(&self, surface_height: i32) -> [i32; 4] {
        let y_bottom_left = (surface_height - (self.y + self.height)).max(0);
        [self.x, y_bottom_left, self.width, self.height]
    }

    /// Converts surface damage rect (top-left origin) to OpenGL Scissor rect format (gl_x, gl_y, gl_w, gl_h).
    pub fn to_gl_scissor(&self, surface_height: i32) -> (i32, i32, i32, i32) {
        let gl_y = (surface_height - (self.y + self.height)).max(0);
        (self.x, gl_y, self.width, self.height)
    }

    /// Checks if a computed layout box intersects this dirty damage rect.
    pub fn intersects_box(&self, b: &ComputedBox) -> bool {
        let b_x1 = b.x.floor() as i32;
        let b_y1 = b.y.floor() as i32;
        let b_x2 = (b.x + b.width).ceil() as i32;
        let b_y2 = (b.y + b.height).ceil() as i32;

        let d_x1 = self.x;
        let d_y1 = self.y;
        let d_x2 = self.x + self.width;
        let d_y2 = self.y + self.height;

        !(b_x2 < d_x1 || b_x1 > d_x2 || b_y2 < d_y1 || b_y1 > d_y2)
    }

    /// Merges two damage rects into a single bounding box.
    pub fn union(&self, other: &Self) -> Self {
        let min_x = self.x.min(other.x);
        let min_y = self.y.min(other.y);
        let max_x = (self.x + self.width).max(other.x + other.width);
        let max_y = (self.y + self.height).max(other.y + other.height);
        Self {
            x: min_x,
            y: min_y,
            width: (max_x - min_x).max(1),
            height: (max_y - min_y).max(1),
        }
    }
}

/// Computes the minimal bounding box of damaged pixels between successive frames.
///
/// Returns:
/// - `None` if zero mutations occurred (triggering frame-skip at 0.00% GPU/CPU).
/// - `Some(rect)` bounding the changed boxes with shadow/blur safety padding.
pub fn compute_damage_rect(
    old_boxes: &[ComputedBox],
    new_boxes: &[ComputedBox],
    viewport_width: u32,
    viewport_height: u32,
) -> Option<DamageRect> {
    if old_boxes.is_empty() || old_boxes.len() != new_boxes.len() {
        return Some(DamageRect::new(0, 0, viewport_width as i32, viewport_height as i32));
    }

    let mut min_x = viewport_width as f32;
    let mut min_y = viewport_height as f32;
    let mut max_x = 0.0f32;
    let mut max_y = 0.0f32;
    let mut any_diff = false;

    for (old, new) in old_boxes.iter().zip(new_boxes.iter()) {
        if old != new {
            any_diff = true;
            let pad = 24.0f32;
            min_x = min_x.min(old.x - pad).min(new.x - pad);
            min_y = min_y.min(old.y - pad).min(new.y - pad);
            max_x = max_x.max(old.x + old.width + pad).max(new.x + new.width + pad);
            max_y = max_y.max(old.y + old.height + pad).max(new.y + new.height + pad);
        }
    }

    if any_diff {
        let x = (min_x.max(0.0).floor()) as i32;
        let y = (min_y.max(0.0).floor()) as i32;
        let w = ((max_x - min_x).ceil() as i32).min(viewport_width as i32 - x).max(1);
        let h = ((max_y - min_y).ceil() as i32).min(viewport_height as i32 - y).max(1);
        Some(DamageRect::new(x, y, w, h))
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use zenith_layout::Color;

    #[test]
    fn test_damage_rect_conversion_and_union() {
        let r1 = DamageRect::new(10, 20, 100, 50);
        let egl = r1.to_egl_coords(600);
        // y_bottom_left = 600 - (20 + 50) = 530
        assert_eq!(egl, [10, 530, 100, 50]);

        let gl = r1.to_gl_scissor(600);
        assert_eq!(gl, (10, 530, 100, 50));

        let r2 = DamageRect::new(50, 40, 200, 60);
        let u = r1.union(&r2);
        assert_eq!(u.x, 10);
        assert_eq!(u.y, 20);
        assert_eq!(u.width, 240);
        assert_eq!(u.height, 80);
    }

    #[test]
    fn test_compute_damage_rect_no_diff() {
        let b1 = ComputedBox {
            x: 0.0,
            y: 0.0,
            width: 100.0,
            height: 30.0,
            background_color: Color::rgb(255, 0, 0),
            border_color: Color::transparent(),
            border_width: 0.0,
            border_radius: 0.0,
            shadow: None,
            custom_shader: None,
            text: None,
            image: None,
            text_input: None,
            slider: None,
            switch: None,
            overflow: zenith_layout::Overflow::Visible,
            scroll_offset_y: 0.0,
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
            tooltip_active: false,
        };

        let old = vec![b1.clone()];
        let new = vec![b1];
        let dmg = compute_damage_rect(&old, &new, 800, 600);
        assert_eq!(dmg, None); // Frame skip!
    }

    #[test]
    fn test_compute_damage_rect_with_mutation() {
        let b1 = ComputedBox {
            x: 50.0,
            y: 50.0,
            width: 100.0,
            height: 30.0,
            background_color: Color::rgb(255, 0, 0),
            border_color: Color::transparent(),
            border_width: 0.0,
            border_radius: 0.0,
            shadow: None,
            custom_shader: None,
            text: Some(("12:00".to_string(), Color::rgb(255, 255, 255), 14.0)),
            image: None,
            text_input: None,
            slider: None,
            switch: None,
            overflow: zenith_layout::Overflow::Visible,
            scroll_offset_y: 0.0,
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
            tooltip_active: false,
        };

        let mut b2 = b1.clone();
        b2.text = Some(("12:01".to_string(), Color::rgb(255, 255, 255), 14.0));

        let old = vec![b1];
        let new = vec![b2];
        let dmg = compute_damage_rect(&old, &new, 800, 600);
        assert!(dmg.is_some());
        let rect = dmg.unwrap();
        // Starts around 50 - 24 = 26
        assert!(rect.x <= 26);
        assert!(rect.y <= 26);
        assert!(rect.width >= 100);
    }
}
