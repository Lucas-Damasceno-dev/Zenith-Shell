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
}
