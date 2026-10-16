//! VRAM Texture Atlas for caching shaped glyphs from `cosmic-text`.
//! Eliminates per-frame CPU rasterization and manual alpha blending.

use std::collections::HashMap;
use std::sync::Arc;
use cosmic_text::{CacheKey, FontSystem, SwashCache, SwashContent};
use glow::HasContext;

pub const ATLAS_SIZE: u32 = 2048;

#[derive(Debug, Clone, Copy)]
pub struct CachedGlyph {
    pub u0: f32,
    pub v0: f32,
    pub u1: f32,
    pub v1: f32,
    pub offset_x: i32,
    pub offset_y: i32,
    pub width: u32,
    pub height: u32,
    pub is_color: bool,
}

pub struct GlyphAtlas {
    gl: Arc<glow::Context>,
    texture: glow::NativeTexture,
    cache: HashMap<CacheKey, Option<CachedGlyph>>,
    cursor_x: u32,
    cursor_y: u32,
    row_height: u32,
}

impl GlyphAtlas {
    /// Initializes a new dynamic VRAM glyph texture atlas.
    ///
    /// # Safety
    ///
    /// - The caller must ensure that an active OpenGL ES context associated with `gl` is current on the calling thread.
    /// - `gl` commands must be valid to execute on the calling thread.
    pub unsafe fn new(gl: Arc<glow::Context>) -> Result<Self, Box<dyn std::error::Error>> {
        let texture = gl.create_texture()?;
        gl.bind_texture(glow::TEXTURE_2D, Some(texture));
        gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MIN_FILTER, glow::LINEAR as i32);
        gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MAG_FILTER, glow::LINEAR as i32);
        gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_S, glow::CLAMP_TO_EDGE as i32);
        gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_T, glow::CLAMP_TO_EDGE as i32);

        // Pre-allocate 2048x2048 RGBA8 texture (supports monochrome masks and full-color emojis)
        gl.tex_image_2d(
            glow::TEXTURE_2D,
            0,
            glow::RGBA8 as i32,
            ATLAS_SIZE as i32,
            ATLAS_SIZE as i32,
            0,
            glow::RGBA,
            glow::UNSIGNED_BYTE,
            glow::PixelUnpackData::Slice(None),
        );

        gl.bind_texture(glow::TEXTURE_2D, None);

        Ok(Self {
            gl,
            texture,
            cache: HashMap::with_capacity(1024),
            cursor_x: 1,
            cursor_y: 1,
            row_height: 0,
        })
    }

    #[inline]
    pub fn texture(&self) -> glow::NativeTexture {
        self.texture
    }

    /// Lookup cached glyph or rasterize on-demand via SwashCache and upload into VRAM.
    pub fn get_or_insert(
        &mut self,
        font_system: &mut FontSystem,
        swash_cache: &mut SwashCache,
        key: CacheKey,
    ) -> Option<CachedGlyph> {
        if let Some(entry) = self.cache.get(&key) {
            return *entry;
        }

        let image = swash_cache.get_image_uncached(font_system, key)?;
        let width = image.placement.width;
        let height = image.placement.height;

        if width == 0 || height == 0 {
            self.cache.insert(key, None);
            return None;
        }

        // Shelf packing algorithm: check if glyph fits in current row
        let padding = 1;
        if self.cursor_x + width + padding >= ATLAS_SIZE {
            // Move to next shelf row
            self.cursor_x = 1;
            self.cursor_y += self.row_height + padding;
            self.row_height = 0;
        }

        // If atlas is completely full, reset and purge cache
        if self.cursor_y + height + padding >= ATLAS_SIZE {
            tracing::warn!("Glyph Atlas VRAM full ({}x{}), resetting cache", ATLAS_SIZE, ATLAS_SIZE);
            self.cache.clear();
            self.cursor_x = 1;
            self.cursor_y = 1;
            self.row_height = 0;
        }

        let x = self.cursor_x;
        let y = self.cursor_y;

        self.cursor_x += width + padding;
        self.row_height = self.row_height.max(height);

        // Upload glyph raster to VRAM via glTexSubImage2D
        let is_color = unsafe {
            self.gl.bind_texture(glow::TEXTURE_2D, Some(self.texture));
            self.gl.pixel_store_i32(glow::UNPACK_ALIGNMENT, 1);

            let is_col = match image.content {
                SwashContent::Mask => {
                    let mut rgba = Vec::with_capacity((width * height * 4) as usize);
                    for &a in &image.data {
                        rgba.extend_from_slice(&[255, 255, 255, a]);
                    }
                    self.gl.tex_sub_image_2d(
                        glow::TEXTURE_2D,
                        0,
                        x as i32,
                        y as i32,
                        width as i32,
                        height as i32,
                        glow::RGBA,
                        glow::UNSIGNED_BYTE,
                        glow::PixelUnpackData::Slice(Some(&rgba)),
                    );
                    false
                }
                SwashContent::SubpixelMask => {
                    let mut rgba = Vec::with_capacity((width * height * 4) as usize);
                    for chunk in image.data.chunks_exact(3) {
                        let avg = ((chunk[0] as u16 + chunk[1] as u16 + chunk[2] as u16) / 3) as u8;
                        rgba.extend_from_slice(&[255, 255, 255, avg]);
                    }
                    self.gl.tex_sub_image_2d(
                        glow::TEXTURE_2D,
                        0,
                        x as i32,
                        y as i32,
                        width as i32,
                        height as i32,
                        glow::RGBA,
                        glow::UNSIGNED_BYTE,
                        glow::PixelUnpackData::Slice(Some(&rgba)),
                    );
                    false
                }
                SwashContent::Color => {
                    // True color RGBA emoji raster
                    self.gl.tex_sub_image_2d(
                        glow::TEXTURE_2D,
                        0,
                        x as i32,
                        y as i32,
                        width as i32,
                        height as i32,
                        glow::RGBA,
                        glow::UNSIGNED_BYTE,
                        glow::PixelUnpackData::Slice(Some(&image.data)),
                    );
                    true
                }
            };

            self.gl.bind_texture(glow::TEXTURE_2D, None);
            is_col
        };

        let u0 = x as f32 / ATLAS_SIZE as f32;
        let v0 = y as f32 / ATLAS_SIZE as f32;
        let u1 = (x + width) as f32 / ATLAS_SIZE as f32;
        let v1 = (y + height) as f32 / ATLAS_SIZE as f32;

        let entry = CachedGlyph {
            u0,
            v0,
            u1,
            v1,
            offset_x: image.placement.left,
            offset_y: image.placement.top,
            width,
            height,
            is_color,
        };

        self.cache.insert(key, Some(entry));
        Some(entry)
    }
}

impl Drop for GlyphAtlas {
    fn drop(&mut self) {
        unsafe {
            self.gl.delete_texture(self.texture);
        }
    }
}
