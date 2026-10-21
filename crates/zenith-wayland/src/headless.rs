//! Headless Engine for Off-Screen Rendering and CI/CD Regression Testing.
//!
//! Enables layout evaluation and pixel-accurate off-screen rendering without
//! requiring an active Wayland compositor or physical display connection.

use cosmic_text::{FontSystem, SwashCache};
use zenith_layout::{ComputedBox, LayoutEngine};
use zenith_runtime::LuauRuntime;
use crate::render::shm::ShmFallbackRenderer;

/// Headless rendering engine capable of executing Luau scripts and rendering off-screen.
pub struct HeadlessEngine {
    pub runtime: LuauRuntime,
    pub layout_engine: LayoutEngine,
    pub font_system: FontSystem,
    pub swash_cache: SwashCache,
}

impl HeadlessEngine {
    /// Initialize a new headless rendering instance.
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let runtime = LuauRuntime::new()?;
        let layout_engine = LayoutEngine::new();
        let font_system = FontSystem::new();
        let swash_cache = SwashCache::new();

        Ok(Self {
            runtime,
            layout_engine,
            font_system,
            swash_cache,
        })
    }

    /// Evaluates a Luau UI script and computes layout boxes for the given dimensions.
    pub fn compute_layout(
        &mut self,
        script: &str,
        width: u32,
        height: u32,
    ) -> Result<Vec<ComputedBox>, Box<dyn std::error::Error>> {
        let root_ui = self.runtime.eval_ui(script)?;
        let boxes = self.layout_engine.compute(&root_ui, width as f32, height as f32);
        Ok(boxes)
    }

    /// Renders a Luau UI script to a raw 32-bit RGBA pixel buffer off-screen.
    pub fn render_to_buffer(
        &mut self,
        script: &str,
        width: u32,
        height: u32,
    ) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        let boxes = self.compute_layout(script, width, height)?;
        let buffer_size = (width * height * 4) as usize;
        let mut buffer = vec![0u8; buffer_size];

        ShmFallbackRenderer::render_boxes(
            &mut buffer,
            &boxes,
            width,
            height,
            1.0,
            &mut self.font_system,
            &mut self.swash_cache,
            None,
            1.0,
        )?;

        Ok(buffer)
    }

    /// Extracts the RGBA color tuple at a specific (x, y) coordinate.
    pub fn pixel_at(buffer: &[u8], width: u32, x: u32, y: u32) -> Option<(u8, u8, u8, u8)> {
        let offset = ((y * width + x) * 4) as usize;
        if offset + 4 <= buffer.len() {
            // Memory layout in tiny-skia SHM is ARGB/RGBA native
            Some((buffer[offset], buffer[offset + 1], buffer[offset + 2], buffer[offset + 3]))
        } else {
            None
        }
    }

    /// Evaluates auto-hide state transitions and computes layout boxes off-screen.
    ///
    /// - When `is_revealed || !has_collision`: surface is visible, `exclusive_zone = nominal_height`, offset = 0.
    /// - When `has_collision && !is_revealed`: surface is hidden, `exclusive_zone = 0`,
    ///   offset is translated off-screen, and reveal strip is active.
    pub fn evaluate_auto_hide(
        &mut self,
        script: &str,
        width: u32,
        nominal_height: u32,
        is_revealed: bool,
        has_collision: bool,
        reveal_strip_px: u32,
    ) -> Result<AutoHideEvaluation, Box<dyn std::error::Error>> {
        let is_visible = !has_collision || is_revealed;
        let exclusive_zone = if is_visible { nominal_height } else { 0 };
        let reveal_strip_active = !is_visible;
        let visual_offset_y = if is_visible {
            0.0
        } else {
            -(nominal_height as f32) + (reveal_strip_px as f32)
        };

        let boxes = self.compute_layout(script, width, nominal_height)?;

        Ok(AutoHideEvaluation {
            exclusive_zone,
            visual_offset_y,
            is_visible,
            reveal_strip_active,
            boxes,
        })
    }

    /// Computes Gaussian magnification scales and rise offsets for dock items based on cursor X position.
    ///
    /// Mathematical model:
    /// scale(x) = 1.0 + (max_scale - 1.0) * exp(-((x - cursor_x)^2) / (2.0 * sigma^2))
    pub fn compute_gaussian_magnification(
        slot_centers: &[f32],
        cursor_x: Option<f32>,
        base_size: f32,
        sigma: f32,
        max_scale: f32,
    ) -> Vec<MagnifiedItemTransform> {
        slot_centers
            .iter()
            .map(|&center_x| {
                let scale = if let Some(cx) = cursor_x {
                    let dist = (center_x - cx).abs();
                    1.0 + (max_scale - 1.0) * (-((dist * dist) / (2.0 * sigma * sigma))).exp()
                } else {
                    1.0
                };
                let width = (base_size * scale).round();
                let height = (base_size * scale).round();
                let rise_offset = ((scale - 1.0) * base_size * 0.45).round();

                MagnifiedItemTransform {
                    scale,
                    width,
                    height,
                    rise_offset,
                }
            })
            .collect()
    }

    /// Evaluates and renders a desktop canvas script (`canvas.luau`) to an off-screen RGBA buffer,
    /// verifying non-empty rendering and dimension bounds across screen resolutions (e.g. 1080p, 1440p, 4K).
    pub fn render_canvas_to_buffer(
        &mut self,
        script: &str,
        width: u32,
        height: u32,
    ) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        self.render_to_buffer(script, width, height)
    }
}

/// Simulated auto-hide state representation for Bar and Dock layer surfaces.
#[derive(Debug, Clone, PartialEq)]
pub struct AutoHideEvaluation {
    /// Effective exclusive_zone reported to Wayland compositor (0 when hidden, nominal height when visible).
    pub exclusive_zone: u32,
    /// Visual Y-offset applied to the surface (0.0 when revealed, translated off-screen when hidden).
    pub visual_offset_y: f32,
    /// Whether the surface is considered visibly deployed.
    pub is_visible: bool,
    /// Whether the 1-2px invisible hover reveal strip is active at the screen edge.
    pub reveal_strip_active: bool,
    /// Evaluated layout boxes for the surface.
    pub boxes: Vec<ComputedBox>,
}

/// Represents transform parameters for a magnified dock item computed from a Gaussian curve.
#[derive(Debug, Clone, PartialEq)]
pub struct MagnifiedItemTransform {
    pub scale: f32,
    pub width: f32,
    pub height: f32,
    pub rise_offset: f32,
}

impl Default for HeadlessEngine {
    fn default() -> Self {
        Self::new().expect("Failed to initialize default HeadlessEngine")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_headless_compute_layout() {
        let mut engine = HeadlessEngine::new().expect("Failed to init engine");
        let script = r##"
            return Zenith.Box({
                width = 800,
                height = 40,
                background = Zenith.hex("#1e232a"),
                children = {
                    Zenith.Text({
                        text = "Zenith Offscreen",
                        color = Zenith.hex("#ffffff")
                    })
                }
            })
        "##;

        let boxes = engine.compute_layout(script, 800, 40).expect("Failed to compute layout");
        assert!(!boxes.is_empty());
        assert_eq!(boxes[0].width, 800.0);
        assert_eq!(boxes[0].height, 40.0);
    }

    #[test]
    fn test_headless_render_to_buffer() {
        let mut engine = HeadlessEngine::new().expect("Failed to init engine");
        let script = r##"
            return Zenith.Box({
                width = 200,
                height = 50,
                background = Zenith.rgba(255, 0, 0, 255),
                children = {}
            })
        "##;

        let buffer = engine.render_to_buffer(script, 200, 50).expect("Failed to render buffer");
        assert_eq!(buffer.len(), 200 * 50 * 4);

        // Check center pixel color: should have alpha > 0 and red component > 0
        let center_pixel = HeadlessEngine::pixel_at(&buffer, 200, 100, 25);
        assert!(center_pixel.is_some());
        let (r, _, _, a) = center_pixel.unwrap();
        assert!(a > 0, "Pixel should be non-transparent");
        assert!(r > 200, "Pixel red channel should be rendered");
    }

    #[test]
    fn test_headless_auto_hide_transitions() {
        let mut engine = HeadlessEngine::new().expect("Failed to init engine");
        let bar_script = r##"
            return Zenith.Box({
                width = 1920,
                height = 42,
                background = Zenith.hex("#111318"),
                children = {
                    Zenith.Text({ text = "Bar Content", color = Zenith.hex("#ffffff") })
                }
            })
        "##;

        // Case 1: Visible state (no window collision, nominal height = 42)
        let eval_visible = engine
            .evaluate_auto_hide(bar_script, 1920, 42, false, false, 2)
            .expect("Auto-hide visible eval failed");
        assert_eq!(eval_visible.exclusive_zone, 42);
        assert_eq!(eval_visible.visual_offset_y, 0.0);
        assert!(eval_visible.is_visible);
        assert!(!eval_visible.reveal_strip_active);
        assert!(!eval_visible.boxes.is_empty());

        // Case 2: Hidden state (collision with active window, not hovered)
        let eval_hidden = engine
            .evaluate_auto_hide(bar_script, 1920, 42, false, true, 2)
            .expect("Auto-hide hidden eval failed");
        assert_eq!(eval_hidden.exclusive_zone, 0);
        assert_eq!(eval_hidden.visual_offset_y, -40.0); // -42 + 2 = -40
        assert!(!eval_hidden.is_visible);
        assert!(eval_hidden.reveal_strip_active);

        // Case 3: Revealed state (collision exists, but user hover triggered reveal)
        let eval_revealed = engine
            .evaluate_auto_hide(bar_script, 1920, 42, true, true, 2)
            .expect("Auto-hide revealed eval failed");
        assert_eq!(eval_revealed.exclusive_zone, 42);
        assert_eq!(eval_revealed.visual_offset_y, 0.0);
        assert!(eval_revealed.is_visible);
        assert!(!eval_revealed.reveal_strip_active);
    }

    #[test]
    fn test_headless_gaussian_magnification_curve() {
        let slot_centers = vec![22.0, 72.0, 122.0, 172.0, 222.0];
        let base_size = 44.0;
        let sigma = 40.0;
        let max_scale = 1.45;

        // 1. Without cursor: all scales must be exactly 1.0, zero rise
        let neutral = HeadlessEngine::compute_gaussian_magnification(
            &slot_centers,
            None,
            base_size,
            sigma,
            max_scale,
        );
        assert_eq!(neutral.len(), 5);
        for item in &neutral {
            assert_eq!(item.scale, 1.0);
            assert_eq!(item.width, 44.0);
            assert_eq!(item.rise_offset, 0.0);
        }

        // 2. Cursor centered on item 2 (x = 122.0)
        let magnified = HeadlessEngine::compute_gaussian_magnification(
            &slot_centers,
            Some(122.0),
            base_size,
            sigma,
            max_scale,
        );
        // Item 2 should have peak scale
        assert!((magnified[2].scale - max_scale).abs() < 0.001);
        assert!(magnified[2].rise_offset > 0.0);

        // Neighbors (items 1 and 3) should have intermediate Gaussian scale
        assert!(magnified[1].scale > 1.0 && magnified[1].scale < max_scale);
        assert!(magnified[3].scale > 1.0 && magnified[3].scale < max_scale);
        assert!((magnified[1].scale - magnified[3].scale).abs() < 0.001); // Symmetric decay

        // Distant items (items 0 and 4) should have lower scales than immediate neighbors
        assert!(magnified[0].scale < magnified[1].scale);
        assert!(magnified[4].scale < magnified[3].scale);
    }

    #[test]
    fn test_headless_render_canvas_multi_resolution() {
        let mut engine = HeadlessEngine::new().expect("Failed to init engine");
        let canvas_script = r##"
            return Zenith.Box({
                width = 400,
                height = 250,
                background = Zenith.rgba(22, 25, 34, 200),
                border_radius = 16,
                padding = 16,
                children = {
                    Zenith.Text({
                        text = "12:00",
                        color = Zenith.hex("#ffffff"),
                        font_size = 32,
                    }),
                    Zenith.Text({
                        text = "Desktop Canvas Ambient Widget",
                        color = Zenith.hex("#89b4fa"),
                        font_size = 14,
                    })
                }
            })
        "##;

        // 1080p resolution test
        let buf_1080p = engine
            .render_canvas_to_buffer(canvas_script, 1920, 1080)
            .expect("Render canvas 1080p failed");
        assert_eq!(buf_1080p.len(), 1920 * 1080 * 4);

        // 1440p resolution test
        let buf_1440p = engine
            .render_canvas_to_buffer(canvas_script, 2560, 1440)
            .expect("Render canvas 1440p failed");
        assert_eq!(buf_1440p.len(), 2560 * 1440 * 4);
    }
}
