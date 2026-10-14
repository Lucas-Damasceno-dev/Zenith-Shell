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

    /// Validates and converts surface damage rect to OpenGL Scissor rect format, safely clamping
    /// against viewport dimensions to prevent out-of-bounds clipping artifacts or GL errors.
    pub fn to_gl_scissor_valid(&self, surface_width: i32, surface_height: i32) -> Option<(i32, i32, i32, i32)> {
        if surface_width <= 0 || surface_height <= 0 {
            return None;
        }
        let x0 = self.x.clamp(0, surface_width);
        let y0 = self.y.clamp(0, surface_height);
        let x1 = (self.x + self.width).clamp(0, surface_width);
        let y1 = (self.y + self.height).clamp(0, surface_height);

        let sw = x1 - x0;
        let sh = y1 - y0;
        if sw <= 0 || sh <= 0 {
            return None;
        }

        let gl_y = (surface_height - y1).clamp(0, surface_height.saturating_sub(sh));
        let gl_x = x0;

        Some((gl_x, gl_y, sw, sh))
    }

    /// Clamps this damage rect against the surface viewport boundaries.
    pub fn clamp_to_viewport(&self, viewport_width: i32, viewport_height: i32) -> Self {
        let x0 = self.x.clamp(0, viewport_width);
        let y0 = self.y.clamp(0, viewport_height);
        let x1 = (self.x + self.width).clamp(0, viewport_width);
        let y1 = (self.y + self.height).clamp(0, viewport_height);
        Self {
            x: x0,
            y: y0,
            width: (x1 - x0).max(1),
            height: (y1 - y0).max(1),
        }
    }

    /// Checks if a computed layout box intersects this dirty damage rect.
    pub fn intersects_box(&self, b: &ComputedBox) -> bool {
        self.intersects_box_with_padding(b, 0.0)
    }

    /// Checks if an integer rectangle intersects this damage rect.
    #[inline]
    pub fn intersects_rect(&self, rx: i32, ry: i32, rw: i32, rh: i32) -> bool {
        !(rx + rw <= self.x || rx >= self.x + self.width || ry + rh <= self.y || ry >= self.y + self.height)
    }

    /// Checks if a coordinate point is contained inside this damage rect.
    #[inline]
    pub fn contains_point(&self, px: i32, py: i32) -> bool {
        px >= self.x && px < self.x + self.width && py >= self.y && py < self.y + self.height
    }

    /// Checks if a computed layout box (with custom padding expansion and active tooltip) intersects this dirty damage rect.
    pub fn intersects_box_with_padding(&self, b: &ComputedBox, padding: f32) -> bool {
        if let Some([cx, cy, cw, ch]) = b.clip_rect {
            if b.x + b.width <= cx || b.x >= cx + cw || b.y + b.height <= cy || b.y >= cy + ch {
                return false;
            }
        }

        let b_x1 = (b.x - padding).floor() as i32;
        let b_y1 = (b.y - padding).floor() as i32;
        let b_x2 = (b.x + b.width + padding).ceil() as i32;
        let b_y2 = (b.y + b.height + padding).ceil() as i32;

        let d_x1 = self.x;
        let d_y1 = self.y;
        let d_x2 = self.x + self.width;
        let d_y2 = self.y + self.height;

        if !(b_x2 <= d_x1 || b_x1 >= d_x2 || b_y2 <= d_y1 || b_y1 >= d_y2) {
            return true;
        }

        // Check active tooltip floating balloon if present
        if b.tooltip_active {
            if let Some(ref tip_text) = b.tooltip {
                let font_sz = 12.0f32;
                let char_count = tip_text.chars().count();
                let tip_w = (char_count as f32 * font_sz * 0.62 + 20.0).max(48.0);
                let tip_h = 26.0f32;
                let tip_x = b.x + b.width * 0.5 - tip_w * 0.5;
                let tip_y = if b.y >= tip_h + 10.0 {
                    b.y - tip_h - 8.0
                } else {
                    b.y + b.height + 8.0
                };
                let tip_pad = 20.0f32;
                let t_x1 = (tip_x - tip_pad).floor() as i32;
                let t_y1 = (tip_y - tip_pad).floor() as i32;
                let t_x2 = (tip_x + tip_w + tip_pad).ceil() as i32;
                let t_y2 = (tip_y + tip_h + tip_pad).ceil() as i32;
                if !(t_x2 <= d_x1 || t_x1 >= d_x2 || t_y2 <= d_y1 || t_y1 >= d_y2) {
                    return true;
                }
            }
        }

        false
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

/// Computes the visual bounding box of a layout box, taking into account rounded borders,
/// drop shadows, padding expansion, and active tooltip popups.
pub fn box_visual_bounds(b: &ComputedBox, viewport_width: f32) -> (f32, f32, f32, f32) {
    let shadow_blur = b.shadow.as_ref().map(|s| s.blur).unwrap_or(0.0);
    let (shadow_ox, shadow_oy) = b.shadow.as_ref().map(|s| (s.offset_x, s.offset_y)).unwrap_or((0.0, 0.0));
    // Soft shadow expansion (blur * 2.5) plus at least 4px for anti-aliased border radius and glow
    let pad = (shadow_blur * 2.5).max(b.border_radius.min(16.0)).max(4.0);

    let mut min_x = b.x + shadow_ox.min(0.0) - pad;
    let mut min_y = b.y + shadow_oy.min(0.0) - pad;
    let mut max_x = b.x + b.width + shadow_ox.max(0.0) + pad;
    let mut max_y = b.y + b.height + shadow_oy.max(0.0) + pad;

    // Account for active floating tooltip popup balloon and shadow
    if b.tooltip_active {
        if let Some(ref tip_text) = b.tooltip {
            let font_sz = 12.0f32;
            let char_count = tip_text.chars().count();
            let tip_w = (char_count as f32 * font_sz * 0.62 + 20.0).max(48.0);
            let tip_h = 26.0f32;
            let tip_x = (b.x + b.width * 0.5 - tip_w * 0.5).clamp(8.0, (viewport_width - tip_w - 8.0).max(8.0));
            let tip_y = if b.y >= tip_h + 10.0 {
                b.y - tip_h - 8.0
            } else {
                b.y + b.height + 8.0
            };
            let tip_pad = 20.0f32; // Tooltip shadow blur & padding
            min_x = min_x.min(tip_x - tip_pad);
            min_y = min_y.min(tip_y - tip_pad);
            max_x = max_x.max(tip_x + tip_w + tip_pad);
            max_y = max_y.max(tip_y + tip_h + tip_pad);
        }
    }

    // Constrain visual bounds to active clipping rectangle if present
    if let Some([cx, cy, cw, ch]) = b.clip_rect {
        min_x = min_x.max(cx);
        min_y = min_y.max(cy);
        max_x = max_x.min(cx + cw);
        max_y = max_y.min(cy + ch);
    }

    (min_x, min_y, max_x, max_y)
}

/// Computes the minimal bounding box of damaged pixels between successive frames.
///
/// Returns:
/// - `None` if zero mutations occurred (triggering frame-skip at 0.00% GPU/CPU).
/// - `Some(rect)` bounding the changed boxes with shadow/blur and popup safety padding.
pub fn compute_damage_rect(
    old_boxes: &[ComputedBox],
    new_boxes: &[ComputedBox],
    viewport_width: u32,
    viewport_height: u32,
) -> Option<DamageRect> {
    if old_boxes.is_empty() && new_boxes.is_empty() {
        return None;
    }
    if old_boxes.is_empty() || new_boxes.is_empty() {
        return Some(DamageRect::new(0, 0, viewport_width as i32, viewport_height as i32));
    }

    let vw = viewport_width as f32;
    let vh = viewport_height as f32;
    let mut min_x = vw;
    let mut min_y = vh;
    let mut max_x = 0.0f32;
    let mut max_y = 0.0f32;
    let mut any_diff = false;

    let common_len = old_boxes.len().min(new_boxes.len());
    for i in 0..common_len {
        let old = &old_boxes[i];
        let new = &new_boxes[i];
        if old != new {
            any_diff = true;
            let (o_x1, o_y1, o_x2, o_y2) = box_visual_bounds(old, vw);
            let (n_x1, n_y1, n_x2, n_y2) = box_visual_bounds(new, vw);
            min_x = min_x.min(o_x1).min(n_x1);
            min_y = min_y.min(o_y1).min(n_y1);
            max_x = max_x.max(o_x2).max(n_x2);
            max_y = max_y.max(o_y2).max(n_y2);
        }
    }

    if old_boxes.len() != new_boxes.len() {
        any_diff = true;
        for old in &old_boxes[common_len..] {
            let (o_x1, o_y1, o_x2, o_y2) = box_visual_bounds(old, vw);
            min_x = min_x.min(o_x1);
            min_y = min_y.min(o_y1);
            max_x = max_x.max(o_x2);
            max_y = max_y.max(o_y2);
        }
        for new in &new_boxes[common_len..] {
            let (n_x1, n_y1, n_x2, n_y2) = box_visual_bounds(new, vw);
            min_x = min_x.min(n_x1);
            min_y = min_y.min(n_y1);
            max_x = max_x.max(n_x2);
            max_y = max_y.max(n_y2);
        }
    }

    if any_diff && max_x > min_x && max_y > min_y {
        let x = (min_x.max(0.0).floor()) as i32;
        let y = (min_y.max(0.0).floor()) as i32;
        let w = ((max_x - min_x).ceil() as i32).min(viewport_width as i32 - x).max(1);
        let h = ((max_y - min_y).ceil() as i32).min(viewport_height as i32 - y).max(1);
        Some(DamageRect::new(x, y, w, h))
    } else {
        None
    }
}

/// Ring buffer that tracks per-buffer accumulated damage for multi-buffered swapchains (e.g. double buffering).
///
/// In Wayland EGL or SHM double-buffering (N=2), the buffer being rendered at frame K
/// was last updated at frame K-2. To ensure zero flicker without full-screen repaints,
/// the damage applied to the current buffer must be the union of all damage rects
/// produced since that specific buffer was last drawn (i.e. the current frame's damage
/// unioned with the preceding N-1 frames' damages).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DamageRing<const N: usize = 2> {
    /// History of frame damages recorded in the ring.
    history: [Option<DamageRect>; N],
    /// Current slot index (0..N).
    current_idx: usize,
    /// Number of initialized frames since creation or last reset.
    initialized_count: usize,
}

impl<const N: usize> Default for DamageRing<N> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const N: usize> DamageRing<N> {
    pub fn new() -> Self {
        assert!(N >= 1, "DamageRing must have at least 1 buffer");
        Self {
            history: [None; N],
            current_idx: 0,
            initialized_count: 0,
        }
    }

    /// Resets the ring buffer (e.g., when resizing the surface or reconfiguring an output).
    /// All subsequent N frames will request full damage to initialize all buffers in the swapchain.
    pub fn reset(&mut self) {
        self.history = [None; N];
        self.current_idx = 0;
        self.initialized_count = 0;
    }

    /// Computes the accumulated damage needed for the buffer currently being drawn,
    /// commits `current_damage` into the ring history, and rotates to the next buffer slot.
    ///
    /// If fewer than `N` frames have been drawn since `reset()`, returns a full viewport damage rect
    /// to ensure all back-buffers in the swapchain are properly seeded.
    /// Once all buffers are initialized (`initialized_count >= N`), returns the union of
    /// `current_damage` and the damage from the preceding `N-1` buffers.
    pub fn rotate_damage(
        &mut self,
        current_damage: Option<DamageRect>,
        viewport_width: i32,
        viewport_height: i32,
    ) -> Option<DamageRect> {
        let full_rect = DamageRect::new(0, 0, viewport_width.max(1), viewport_height.max(1));

        if self.initialized_count < N {
            // Buffer is not yet seeded: full repaint required.
            self.history[self.current_idx] = current_damage.or(Some(full_rect));
            self.current_idx = (self.current_idx + 1) % N;
            self.initialized_count += 1;
            return Some(full_rect);
        }

        // When current_damage is None and already initialized, no repaint needed.
        let cur = current_damage?;

        // Accumulate damage across the preceding N-1 frames that were rendered while this buffer was inactive.
        let mut accumulated = cur;
        for i in 0..N {
            if i != self.current_idx {
                if let Some(prev) = self.history[i] {
                    accumulated = accumulated.union(&prev);
                }
            }
        }

        // Record the current frame's individual damage into this buffer's slot
        self.history[self.current_idx] = Some(cur);
        self.current_idx = (self.current_idx + 1) % N;

        // Clamp accumulated damage to the viewport bounds
        Some(accumulated.clamp_to_viewport(viewport_width, viewport_height))
    }

    /// Returns the accumulated damage for the current buffer WITHOUT advancing the ring index.
    pub fn peek_damage(
        &self,
        current_damage: Option<DamageRect>,
        viewport_width: i32,
        viewport_height: i32,
    ) -> Option<DamageRect> {
        if self.initialized_count < N {
            return Some(DamageRect::new(0, 0, viewport_width.max(1), viewport_height.max(1)));
        }
        let cur = current_damage?;
        let mut accumulated = cur;
        for i in 0..N {
            if i != self.current_idx {
                if let Some(prev) = self.history[i] {
                    accumulated = accumulated.union(&prev);
                }
            }
        }
        Some(accumulated.clamp_to_viewport(viewport_width, viewport_height))
    }

    /// Returns the current slot index in the ring buffer.
    #[inline]
    pub fn current_index(&self) -> usize {
        self.current_idx
    }

    /// Returns true if all buffers in the ring have completed their cold-start seeding.
    #[inline]
    pub fn is_initialized(&self) -> bool {
        self.initialized_count >= N
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
            clip_rect: None,
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
            clip_rect: None,
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
        // Starts around 50 - 4 = 46 with fine-grained visual bounds
        assert!(rect.x <= 46);
        assert!(rect.y <= 46);
        assert!(rect.width >= 100);
    }

    #[test]
    fn test_intersects_box_with_padding() {
        let b = ComputedBox {
            x: 100.0,
            y: 100.0,
            width: 50.0,
            height: 50.0,
            background_color: Color::rgb(0, 0, 0),
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
            clip_rect: None,
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
            tooltip_active: false,
        };

        let rect_outside = DamageRect::new(200, 200, 50, 50);
        assert!(!rect_outside.intersects_box(&b));
        assert!(!rect_outside.intersects_box_with_padding(&b, 10.0));
        assert!(rect_outside.intersects_box_with_padding(&b, 100.0));

        let rect_touching = DamageRect::new(140, 140, 30, 30);
        assert!(rect_touching.intersects_box(&b));
    }

    #[test]
    fn test_damage_rect_to_gl_scissor_valid() {
        let r = DamageRect::new(10, 20, 100, 50);
        let sc = r.to_gl_scissor_valid(800, 600);
        // Wayland: top=20, bottom=70 -> OpenGL: gl_y = 600 - 70 = 530, gl_x = 10, w = 100, h = 50
        assert_eq!(sc, Some((10, 530, 100, 50)));

        // Negative coordinates clamped safely
        let r_neg = DamageRect::new(-20, -30, 100, 80);
        let sc_neg = r_neg.to_gl_scissor_valid(800, 600);
        assert!(sc_neg.is_some());
        let (sx, sy, sw, sh) = sc_neg.unwrap();
        assert_eq!(sx, 0);
        assert_eq!(sw, 80);
        // y in Wayland was -30..50 -> clamped to 0..50, height = 50, gl_y = 600 - 50 = 550
        assert_eq!(sy, 550);
        assert_eq!(sh, 50);

        // Out of bounds returns None
        let r_out = DamageRect::new(900, 700, 50, 50);
        assert_eq!(r_out.to_gl_scissor_valid(800, 600), None);
    }

    #[test]
    fn test_damage_ring_cold_start_and_rotation() {
        let mut ring = DamageRing::<2>::new();
        assert!(!ring.is_initialized());

        let widget_dmg = Some(DamageRect::new(100, 10, 60, 24));

        // Frame 0: Buffer 0 needs full damage to seed
        let f0 = ring.rotate_damage(widget_dmg, 800, 600);
        assert_eq!(f0, Some(DamageRect::new(0, 0, 800, 600)));
        assert_eq!(ring.current_index(), 1);

        // Frame 1: Buffer 1 needs full damage to seed
        let f1 = ring.rotate_damage(widget_dmg, 800, 600);
        assert_eq!(f1, Some(DamageRect::new(0, 0, 800, 600)));
        assert_eq!(ring.current_index(), 0);
        assert!(ring.is_initialized());

        // Frame 2: (clock update 1s later, same widget position) -> Buffer 0 receives ONLY widget damage union!
        let f2 = ring.rotate_damage(widget_dmg, 800, 600);
        assert_eq!(f2, Some(DamageRect::new(100, 10, 60, 24)));
        assert_eq!(ring.current_index(), 1);

        // Frame 3: Buffer 1 receives ONLY widget damage union!
        let f3 = ring.rotate_damage(widget_dmg, 800, 600);
        assert_eq!(f3, Some(DamageRect::new(100, 10, 60, 24)));
        assert_eq!(ring.current_index(), 0);

        // Frame 4: Different widget changes at (200, 10, 40, 24)
        let widget_b = Some(DamageRect::new(200, 10, 40, 24));
        let f4 = ring.rotate_damage(widget_b, 800, 600);
        // Buffer 0 must receive union of widget_b (200..240) and previous widget (100..160)
        assert_eq!(f4, Some(DamageRect::new(100, 10, 140, 24)));
    }

    #[test]
    fn test_compute_damage_rect_tooltip_expansion() {
        let b1 = ComputedBox {
            x: 50.0,
            y: 50.0,
            width: 30.0,
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
            clip_rect: None,
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: Some("Tooltip Title".to_string()),
            tooltip_active: false,
        };

        let mut b2 = b1.clone();
        b2.tooltip_active = true;

        let dmg = compute_damage_rect(&[b1], &[b2], 800, 600).expect("damage expected");
        // Tooltip balloon and shadow must be incorporated, so width must be well beyond the 30px icon
        assert!(dmg.width >= 100);
    }

    #[test]
    fn test_compute_damage_rect_clip_rect_culling() {
        let b1 = ComputedBox {
            x: 0.0,
            y: 0.0,
            width: 100.0,
            height: 100.0,
            background_color: Color::rgb(0, 0, 0),
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
            overflow: zenith_layout::Overflow::Hidden,
            scroll_offset_y: 0.0,
            clip_rect: Some([0.0, 0.0, 50.0, 50.0]),
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
            tooltip_active: false,
        };

        let mut b2 = b1.clone();
        b2.background_color = Color::rgb(255, 255, 255);

        let dmg = compute_damage_rect(&[b1], &[b2], 800, 600).expect("damage expected");
        // Bounded by clip rect width/height
        assert!(dmg.width <= 50 + 8);
        assert!(dmg.height <= 50 + 8);
    }
}
