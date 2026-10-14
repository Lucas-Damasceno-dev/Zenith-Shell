//! GPU Texture Cache for SVG / PNG raster images blitted in Zenith UI.

use std::collections::HashMap;
use std::sync::Arc;
use glow::HasContext;

const IMAGE_VS: &str = r#"#version 300 es
precision highp float;

layout(location = 0) in vec2 a_pos;
layout(location = 1) in vec2 a_uv;

uniform vec2 u_resolution;

out vec2 v_uv;

void main() {
    vec2 clip = (a_pos / u_resolution) * 2.0 - 1.0;
    clip.y = -clip.y;
    gl_Position = vec4(clip, 0.0, 1.0);
    v_uv = a_uv;
}
"#;

const IMAGE_FS: &str = r#"#version 300 es
precision highp float;

in vec2 v_uv;
uniform sampler2D u_texture;
uniform float u_opacity;

out vec4 frag_color;

void main() {
    vec4 c = texture(u_texture, v_uv);
    frag_color = vec4(c.rgb, c.a * u_opacity);
}
"#;

pub const MAX_TEXTURE_CAPACITY: usize = 256;

struct TextureEntry {
    texture: glow::NativeTexture,
    width: u32,
    height: u32,
    last_used: u64,
}

pub struct ImageCache {
    gl: Arc<glow::Context>,
    textures: HashMap<String, TextureEntry>,
    access_counter: u64,
    program: glow::NativeProgram,
    vao: glow::NativeVertexArray,
    vbo: glow::NativeBuffer,
    loc_resolution: glow::UniformLocation,
    loc_texture: glow::UniformLocation,
    loc_opacity: glow::UniformLocation,
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
            loc_resolution,
            loc_texture,
            loc_opacity,
        })
    }

    /// Number of textures currently allocated in VRAM cache.
    pub fn len(&self) -> usize {
        self.textures.len()
    }

    pub fn is_empty(&self) -> bool {
        self.textures.is_empty()
    }

    /// Retrieves an existing GPU texture or uploads from disk via ImageService with LRU eviction.
    pub fn get_or_load(
        &mut self,
        src: &str,
        target_w: u32,
        target_h: u32,
    ) -> Option<(glow::NativeTexture, u32, u32)> {
        let key = format!("{}::{}x{}", src, target_w, target_h);
        self.access_counter = self.access_counter.wrapping_add(1);
        let current_access = self.access_counter;

        if let Some(entry) = self.textures.get_mut(&key) {
            entry.last_used = current_access;
            return Some((entry.texture, entry.width, entry.height));
        }

        let decoded = zenith_services::ImageService::load_image(src, Some(target_w), Some(target_h)).ok()?;

        unsafe {
            // LRU eviction: when exceeding MAX_TEXTURE_CAPACITY (256), delete the least recently used texture
            if self.textures.len() >= MAX_TEXTURE_CAPACITY {
                if let Some((oldest_key, _)) = self
                    .textures
                    .iter()
                    .min_by_key(|(_, entry)| entry.last_used)
                    .map(|(k, v)| (k.clone(), v.last_used))
                {
                    if let Some(evicted) = self.textures.remove(&oldest_key) {
                        self.gl.delete_texture(evicted.texture);
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

            self.textures.insert(
                key,
                TextureEntry {
                    texture,
                    width: decoded.width,
                    height: decoded.height,
                    last_used: current_access,
                },
            );

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

        self.gl.active_texture(glow::TEXTURE0);
        self.gl.bind_texture(glow::TEXTURE_2D, Some(texture));
        self.gl.uniform_1_i32(Some(&self.loc_texture), 0);

        self.gl.bind_buffer(glow::ARRAY_BUFFER, Some(self.vbo));
        let slice = std::slice::from_raw_parts(
            vertices.as_ptr() as *const u8,
            vertices.len() * std::mem::size_of::<f32>(),
        );
        self.gl.buffer_data_u8_slice(glow::ARRAY_BUFFER, slice, glow::DYNAMIC_DRAW);

        self.gl.draw_arrays(glow::TRIANGLES, 0, 6);

        self.gl.bind_texture(glow::TEXTURE_2D, None);
        self.gl.bind_vertex_array(None);
        self.gl.use_program(None);
    }
}

impl Drop for ImageCache {
    fn drop(&mut self) {
        unsafe {
            for entry in self.textures.values() {
                self.gl.delete_texture(entry.texture);
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
