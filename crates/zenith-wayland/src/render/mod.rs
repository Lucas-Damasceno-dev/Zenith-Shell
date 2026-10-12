//! Zenith Rendering Subsystem — Hardware-accelerated GLES 3.0 & Contingency SHM Fallback.

pub mod atlas;
pub mod custom_shader;
pub mod damage;
pub mod gles;
pub mod image_cache;
pub mod primitives;
pub mod shm;

pub use atlas::GlyphAtlas;
pub use custom_shader::CustomShaderPipeline;
pub use damage::{compute_damage_rect, DamageRect};
pub use gles::GlesRenderer;
pub use image_cache::ImageCache;
pub use primitives::SdfRectShader;
pub use shm::ShmFallbackRenderer;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_shm_rounded_rect_path() {
        let p1 = ShmFallbackRenderer::build_rounded_rect_path(0.0, 0.0, 100.0, 40.0, 8.0);
        assert!(p1.is_some());

        let p2 = ShmFallbackRenderer::build_rounded_rect_path(10.0, 10.0, 50.0, 50.0, 0.0);
        assert!(p2.is_some());
    }

    #[test]
    fn test_shm_render_boxes_empty() {
        let mut canvas = vec![0u8; 100 * 100 * 4];
        let mut font_system = cosmic_text::FontSystem::new();
        let mut swash_cache = cosmic_text::SwashCache::new();
        let res = ShmFallbackRenderer::render_boxes(
            &mut canvas,
            &[],
            100,
            100,
            1.0,
            &mut font_system,
            &mut swash_cache,
        );
        assert!(res.is_ok());
    }
}
