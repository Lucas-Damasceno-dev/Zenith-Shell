//! GPU Texture Cache for SVG / PNG raster images blitted in Zenith UI.

use std::collections::HashMap;
use std::sync::Arc;
use glow::HasContext;

const IMAGE_VS: &str = r#"#version 300 es
precision highp float;

layout(location = 0) in vec2 a_pos;
layout(location = 1) in vec2 a_uv;

uniform vec2 u_resolution;
uniform vec4 u_rect; // (x, y, w, h)

out vec2 v_uv;
out vec2 v_local_pos;
out vec2 v_half_size;

void main() {
    vec2 clip = (a_pos / u_resolution) * 2.0 - 1.0;
    clip.y = -clip.y;
    gl_Position = vec4(clip, 0.0, 1.0);
    v_uv = a_uv;
    vec2 center = u_rect.xy + u_rect.zw * 0.5;
    v_local_pos = a_pos - center;
    v_half_size = u_rect.zw * 0.5;
}
"#;

const IMAGE_FS: &str = r#"#version 300 es
precision highp float;

in vec2 v_uv;
in vec2 v_local_pos;
in vec2 v_half_size;

uniform sampler2D u_texture;
uniform float u_opacity;
uniform float u_border_radius;

out vec4 frag_color;

float sd_round_box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec4 c = texture(u_texture, v_uv);
    float a = c.a * u_opacity;
    if (u_border_radius > 0.0) {
        float r = min(u_border_radius, min(v_half_size.x, v_half_size.y));
        float d = sd_round_box(v_local_pos, v_half_size, r);
        float mask = clamp(0.5 - d, 0.0, 1.0);
        a *= mask;
    }
    frag_color = vec4(c.rgb, a);
}
"#;

pub const MAX_TEXTURE_CAPACITY: usize = 256;

struct TextureEntry {
    texture: glow::NativeTexture,
    width: u32,
    height: u32,
    last_used: u64,
}

struct TextureVariant {
    width: u32,
    height: u32,
    entry: Option<TextureEntry>,
}

struct ImageVariants {
    variants: Vec<TextureVariant>,
}

pub struct ImageCache {
    gl: Arc<glow::Context>,
    textures: HashMap<String, ImageVariants>,
    access_counter: u64,
    program: glow::NativeProgram,
    vao: glow::NativeVertexArray,
    vbo: glow::NativeBuffer,
    pub vbo_capacity: std::cell::Cell<usize>,
    loc_resolution: glow::UniformLocation,
    loc_texture: glow::UniformLocation,
    loc_opacity: glow::UniformLocation,
    loc_rect: glow::UniformLocation,
    loc_border_radius: glow::UniformLocation,
}

impl ImageCache {
    /// Creates a new texture cache and initializes the image rendering pipeline.
    ///
    /// # Safety
    ///
    /// - The caller must ensure that an active OpenGL ES context associated with `gl` is current on the calling thread.
    /// - `gl` commands must remain valid throughout execution.
    pub unsafe fn new(gl: Arc<glow::Context>) -> Result<Self, Box<dyn std::error::Error>> {
        let program = super::primitives::SdfRectShader::compile_program(&gl, IMAGE_VS, IMAGE_FS)?;

        let loc_resolution = gl.get_uniform_location(program, "u_resolution").ok_or("u_resolution")?;
        let loc_texture = gl.get_uniform_location(program, "u_texture").ok_or("u_texture")?;
        let loc_opacity = gl.get_uniform_location(program, "u_opacity").ok_or("u_opacity")?;
        let loc_rect = gl.get_uniform_location(program, "u_rect").ok_or("u_rect")?;
        let loc_border_radius = gl.get_uniform_location(program, "u_border_radius").ok_or("u_border_radius")?;

        let vao = gl.create_vertex_array()?;
        let vbo = gl.create_buffer()?;

        gl.bind_vertex_array(Some(vao));
        gl.bind_buffer(glow::ARRAY_BUFFER, Some(vbo));

        // Vertex buffer dynamically populated per quad [x, y, u, v]
        gl.enable_vertex_attrib_array(0);
        gl.vertex_attrib_pointer_f32(0, 2, glow::FLOAT, false, 4 * 4, 0);
        gl.enable_vertex_attrib_array(1);
        gl.vertex_attrib_pointer_f32(1, 2, glow::FLOAT, false, 4 * 4, 2 * 4);

        gl.bind_vertex_array(None);
        gl.bind_buffer(glow::ARRAY_BUFFER, None);

        Ok(Self {
            gl,
            textures: HashMap::new(),
            access_counter: 0,
            program,
            vao,
            vbo,
            vbo_capacity: std::cell::Cell::new(0),
            loc_resolution,
            loc_texture,
            loc_opacity,
            loc_rect,
            loc_border_radius,
        })
    }

    /// Number of textures currently allocated in VRAM cache.
    pub fn len(&self) -> usize {
        self.textures.values().map(|iv| iv.variants.iter().filter(|v| v.entry.is_some()).count()).sum()
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// Retrieves an existing GPU texture or uploads from disk via ImageService with LRU eviction.
    pub fn get_or_load(
        &mut self,
        src: &str,
        target_w: u32,
        target_h: u32,
    ) -> Option<(glow::NativeTexture, u32, u32)> {
        self.access_counter = self.access_counter.wrapping_add(1);
        let current_access = self.access_counter;

        // Zero-allocation cache lookup using &str directly without format!
        if let Some(iv) = self.textures.get_mut(src) {
            if let Some(variant) = iv.variants.iter_mut().find(|v| v.width == target_w && v.height == target_h) {
                if let Some(ref mut entry) = variant.entry {
                    entry.last_used = current_access;
                    return Some((entry.texture, entry.width, entry.height));
                } else {
                    // Cached failure: never repeat disk I/O on invalid/missing images
                    return None;
                }
            }
        }

        let decoded = match zenith_services::ImageService::load_image(src, Some(target_w), Some(target_h)) {
            Ok(d) => d,
            Err(_) => {
                // Cache failure in memory so we do not attempt disk/decode operations again
                let entry = self.textures.entry(src.to_string()).or_insert_with(|| ImageVariants { variants: Vec::new() });
                entry.variants.push(TextureVariant {
                    width: target_w,
                    height: target_h,
                    entry: None,
                });
                return None;
            }
        };

        unsafe {
            // LRU eviction: when exceeding MAX_TEXTURE_CAPACITY (256), delete the least recently used texture
            if self.len() >= MAX_TEXTURE_CAPACITY {
                let mut oldest: Option<(String, u32, u32, u64)> = None;
                for (s, iv) in &self.textures {
                    for v in &iv.variants {
                        if let Some(ref e) = v.entry {
                            if oldest.as_ref().map(|(_, _, _, lu)| e.last_used < *lu).unwrap_or(true) {
                                oldest = Some((s.clone(), v.width, v.height, e.last_used));
                            }
                        }
                    }
                }
                if let Some((old_src, old_w, old_h, _)) = oldest {
                    if let Some(iv) = self.textures.get_mut(&old_src) {
                        if let Some(pos) = iv.variants.iter().position(|v| v.width == old_w && v.height == old_h) {
                            if let Some(evicted) = iv.variants.remove(pos).entry {
                                self.gl.delete_texture(evicted.texture);
                            }
                        }
                    }
                }
            }

            let texture = self.gl.create_texture().ok()?;
            self.gl.bind_texture(glow::TEXTURE_2D, Some(texture));
            self.gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MIN_FILTER, glow::LINEAR as i32);
            self.gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MAG_FILTER, glow::LINEAR as i32);
            self.gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_S, glow::CLAMP_TO_EDGE as i32);
            self.gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_T, glow::CLAMP_TO_EDGE as i32);

            self.gl.tex_image_2d(
                glow::TEXTURE_2D,
                0,
                glow::RGBA8 as i32,
                decoded.width as i32,
                decoded.height as i32,
                0,
                glow::RGBA,
                glow::UNSIGNED_BYTE,
                glow::PixelUnpackData::Slice(Some(&decoded.rgba)),
            );

            self.gl.bind_texture(glow::TEXTURE_2D, None);

            let entry = self.textures.entry(src.to_string()).or_insert_with(|| ImageVariants { variants: Vec::new() });
            entry.variants.push(TextureVariant {
                width: target_w,
                height: target_h,
                entry: Some(TextureEntry {
                    texture,
                    width: decoded.width,
                    height: decoded.height,
                    last_used: current_access,
                }),
            });

            Some((texture, decoded.width, decoded.height))
        }
    }

    /// Draws a cached texture into the target viewport at the specified rectangle.
    ///
    /// # Safety
    ///
    /// - The caller must ensure that an active OpenGL ES context associated with `self.gl` is current on the calling thread.
    /// - `texture` must be a valid, live OpenGL texture handle within this context.
    pub unsafe fn draw(
        &self,
        texture: glow::NativeTexture,
        resolution: (f32, f32),
        rect: (f32, f32, f32, f32), // (x, y, w, h)
        opacity: f32,
        border_radius: f32,
    ) {
        let (x, y, w, h) = rect;
        let x1 = x + w;
        let y1 = y + h;

        // Quad with vertices: (x, y, u, v)
        let vertices: [f32; 24] = [
            x,  y,  0.0, 0.0,
            x1, y,  1.0, 0.0,
            x,  y1, 0.0, 1.0,

            x,  y1, 0.0, 1.0,
            x1, y,  1.0, 0.0,
            x1, y1, 1.0, 1.0,
        ];

        self.gl.use_program(Some(self.program));
        self.gl.bind_vertex_array(Some(self.vao));

        self.gl.uniform_2_f32(Some(&self.loc_resolution), resolution.0, resolution.1);
        self.gl.uniform_1_f32(Some(&self.loc_opacity), opacity);
        self.gl.uniform_4_f32(Some(&self.loc_rect), rect.0, rect.1, rect.2, rect.3);
        self.gl.uniform_1_f32(Some(&self.loc_border_radius), border_radius);

        self.gl.active_texture(glow::TEXTURE0);
        self.gl.bind_texture(glow::TEXTURE_2D, Some(texture));
        self.gl.uniform_1_i32(Some(&self.loc_texture), 0);

        self.gl.bind_buffer(glow::ARRAY_BUFFER, Some(self.vbo));
        let needed_bytes = vertices.len() * std::mem::size_of::<f32>();
        let slice = std::slice::from_raw_parts(
            vertices.as_ptr() as *const u8,
            needed_bytes,
        );
        let cur_cap = self.vbo_capacity.get();
        if needed_bytes <= cur_cap {
            self.gl.buffer_sub_data_u8_slice(glow::ARRAY_BUFFER, 0, slice);
        } else {
            let new_cap = needed_bytes.next_power_of_two().max(256);
            self.gl.buffer_data_size(glow::ARRAY_BUFFER, new_cap as i32, glow::DYNAMIC_DRAW);
            self.gl.buffer_sub_data_u8_slice(glow::ARRAY_BUFFER, 0, slice);
            self.vbo_capacity.set(new_cap);
        }

        self.gl.draw_arrays(glow::TRIANGLES, 0, 6);

        self.gl.bind_texture(glow::TEXTURE_2D, None);
        self.gl.bind_vertex_array(None);
        self.gl.use_program(None);
    }
}

impl Drop for ImageCache {
    fn drop(&mut self) {
        unsafe {
            for image_variants in self.textures.values() {
                for variant in &image_variants.variants {
                    if let Some(ref entry) = variant.entry {
                        self.gl.delete_texture(entry.texture);
                    }
                }
            }
            self.gl.delete_program(self.program);
            self.gl.delete_vertex_array(self.vao);
            self.gl.delete_buffer(self.vbo);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_max_texture_capacity_constant() {
        assert_eq!(MAX_TEXTURE_CAPACITY, 256);
    }
}
