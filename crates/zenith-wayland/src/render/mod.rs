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
pub use damage::{box_visual_bounds, compute_damage_rect, DamageRect, DamageRing};
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
            None,
        );
        assert!(res.is_ok());
    }

    #[test]
    fn test_shm_render_slider_and_switch() {
        use zenith_layout::{Color, ComputedBox, ComputedSlider, ComputedSwitch};

        let mut canvas = vec![0u8; 200 * 100 * 4];
        let mut font_system = cosmic_text::FontSystem::new();
        let mut swash_cache = cosmic_text::SwashCache::new();

        let slider_box = ComputedBox {
            x: 10.0,
            y: 10.0,
            width: 150.0,
            height: 20.0,
            background_color: Color::transparent(),
            border_color: Color::transparent(),
            border_width: 0.0,
            border_radius: 0.0,
            shadow: None,
            custom_shader: None,
            text: None,
            image: None,
            text_input: None,
            slider: Some(ComputedSlider {
                id: Some("slider_vol".to_string()),
                min: 0.0,
                max: 100.0,
                value: 65.0,
                track_height: 6.0,
                thumb_radius: 6.0,
                track_color: Color::rgba(255, 255, 255, 30),
                active_track_color: Color::rgb(100, 150, 250),
                thumb_color: Color::rgb(255, 255, 255),
                on_change: Some("vol_change".to_string()),
            }),
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

        let switch_box = ComputedBox {
            x: 10.0,
            y: 40.0,
            width: 42.0,
            height: 22.0,
            background_color: Color::transparent(),
            border_color: Color::transparent(),
            border_width: 0.0,
            border_radius: 11.0,
            shadow: None,
            custom_shader: None,
            text: None,
            image: None,
            text_input: None,
            slider: None,
            switch: Some(ComputedSwitch {
                id: Some("sw_wifi".to_string()),
                checked: true,
                active_color: Color::rgb(50, 120, 240),
                inactive_color: Color::rgba(255, 255, 255, 30),
                thumb_color: Color::rgb(255, 255, 255),
                on_toggle: Some("wifi_toggle".to_string()),
            }),
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

        let res = ShmFallbackRenderer::render_boxes(
            &mut canvas,
            &[slider_box, switch_box],
            200,
            100,
            1.0,
            &mut font_system,
            &mut swash_cache,
            None,
        );
        assert!(res.is_ok());

        // Ensure canvas was drawn to (non-zero alpha / bytes)
        assert!(canvas.iter().any(|&b| b != 0));
    }
}
