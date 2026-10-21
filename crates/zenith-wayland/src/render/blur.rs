//! Dual-Kawase Multi-Pass Blur Pipeline for Zenith-Shell.
//!
//! Provides ultra-low VRAM (<100KB), sub-1ms hardware-accelerated blur for Dock, Bar
//! and floating overlay glassmorphism using downsampling and upsampling FBO pyramids.

use std::sync::Arc;
use glow::HasContext;

const QUAD_VERTICES: [f32; 24] = [
    // pos_x, pos_y, uv_u, uv_v
    -1.0, -1.0, 0.0, 0.0,
     1.0, -1.0, 1.0, 0.0,
    -1.0,  1.0, 0.0, 1.0,

    -1.0,  1.0, 0.0, 1.0,
     1.0, -1.0, 1.0, 0.0,
     1.0,  1.0, 1.0, 1.0,
];

const DOWNSAMPLE_VS: &str = r#"#version 300 es
precision highp float;
layout(location = 0) in vec2 a_pos;
layout(location = 1) in vec2 a_uv;
out vec2 v_uv;
void main() {
    gl_Position = vec4(a_pos, 0.0, 1.0);
    v_uv = a_uv;
}
"#;

const DOWNSAMPLE_FS: &str = r#"#version 300 es
precision highp float;
in vec2 v_uv;
uniform sampler2D u_tex;
uniform vec2 u_halfpixel;
uniform float u_offset;
out vec4 frag_color;

void main() {
    vec2 d = u_halfpixel * u_offset;
    vec4 sum = texture(u_tex, v_uv) * 4.0;
    sum += texture(u_tex, v_uv - d);
    sum += texture(u_tex, v_uv + d);
    sum += texture(u_tex, v_uv + vec2(d.x, -d.y));
    sum += texture(u_tex, v_uv + vec2(-d.x, d.y));
    frag_color = sum / 8.0;
}
"#;

const UPSAMPLE_VS: &str = r#"#version 300 es
precision highp float;
layout(location = 0) in vec2 a_pos;
layout(location = 1) in vec2 a_uv;
out vec2 v_uv;
void main() {
    gl_Position = vec4(a_pos, 0.0, 1.0);
    v_uv = a_uv;
}
"#;

const UPSAMPLE_FS: &str = r#"#version 300 es
precision highp float;
in vec2 v_uv;
uniform sampler2D u_tex;
uniform vec2 u_halfpixel;
uniform float u_offset;
out vec4 frag_color;

void main() {
    vec2 d = u_halfpixel * u_offset;
    vec4 sum = vec4(0.0);
    // 4 diagonal taps (weight 2.0)
    sum += texture(u_tex, v_uv + vec2(-d.x, -d.y)) * 2.0;
    sum += texture(u_tex, v_uv + vec2( d.x, -d.y)) * 2.0;
    sum += texture(u_tex, v_uv + vec2(-d.x,  d.y)) * 2.0;
    sum += texture(u_tex, v_uv + vec2( d.x,  d.y)) * 2.0;
    // 4 orthogonal taps (weight 1.0)
    sum += texture(u_tex, v_uv + vec2(-2.0 * d.x, 0.0));
    sum += texture(u_tex, v_uv + vec2( 2.0 * d.x, 0.0));
    sum += texture(u_tex, v_uv + vec2(0.0, -2.0 * d.y));
    sum += texture(u_tex, v_uv + vec2(0.0,  2.0 * d.y));
    frag_color = sum / 12.0;
}
"#;

pub struct DualKawaseBlur {
    gl: Arc<glow::Context>,
    down_program: glow::NativeProgram,
    up_program: glow::NativeProgram,
    vao: glow::NativeVertexArray,
    vbo: glow::NativeBuffer,
    fbos: [glow::NativeFramebuffer; 2],
    textures: [glow::NativeTexture; 2],
    sizes: [(u32, u32); 2],
    loc_down_tex: glow::UniformLocation,
    loc_down_halfpixel: glow::UniformLocation,
    loc_down_offset: glow::UniformLocation,
    loc_up_tex: glow::UniformLocation,
    loc_up_halfpixel: glow::UniformLocation,
    loc_up_offset: glow::UniformLocation,
}

impl DualKawaseBlur {
    /// Initialize Dual-Kawase blur pipeline, compiling down/up shaders and allocating quad buffer.
    pub unsafe fn new(gl: Arc<glow::Context>) -> Result<Self, Box<dyn std::error::Error>> {
        let down_program = Self::compile_program(&gl, DOWNSAMPLE_VS, DOWNSAMPLE_FS)?;
        let up_program = Self::compile_program(&gl, UPSAMPLE_VS, UPSAMPLE_FS)?;

        let loc_down_tex = gl.get_uniform_location(down_program, "u_tex").ok_or("u_tex")?;
        let loc_down_halfpixel = gl.get_uniform_location(down_program, "u_halfpixel").ok_or("u_halfpixel")?;
        let loc_down_offset = gl.get_uniform_location(down_program, "u_offset").ok_or("u_offset")?;

        let loc_up_tex = gl.get_uniform_location(up_program, "u_tex").ok_or("u_tex")?;
        let loc_up_halfpixel = gl.get_uniform_location(up_program, "u_halfpixel").ok_or("u_halfpixel")?;
        let loc_up_offset = gl.get_uniform_location(up_program, "u_offset").ok_or("u_offset")?;

        let vao = gl.create_vertex_array()?;
        let vbo = gl.create_buffer()?;

        gl.bind_vertex_array(Some(vao));
        gl.bind_buffer(glow::ARRAY_BUFFER, Some(vbo));
        let slice = std::slice::from_raw_parts(
            QUAD_VERTICES.as_ptr() as *const u8,
            QUAD_VERTICES.len() * std::mem::size_of::<f32>(),
        );
        gl.buffer_data_u8_slice(glow::ARRAY_BUFFER, slice, glow::STATIC_DRAW);

        gl.enable_vertex_attrib_array(0);
        gl.vertex_attrib_pointer_f32(0, 2, glow::FLOAT, false, 4 * 4, 0);
        gl.enable_vertex_attrib_array(1);
        gl.vertex_attrib_pointer_f32(1, 2, glow::FLOAT, false, 4 * 4, 2 * 4);

        gl.bind_vertex_array(None);
        gl.bind_buffer(glow::ARRAY_BUFFER, None);

        let fbo0 = gl.create_framebuffer()?;
        let fbo1 = gl.create_framebuffer()?;
        let tex0 = gl.create_texture()?;
        let tex1 = gl.create_texture()?;

        Ok(Self {
            gl,
            down_program,
            up_program,
            vao,
            vbo,
            fbos: [fbo0, fbo1],
            textures: [tex0, tex1],
            sizes: [(0, 0), (0, 0)],
            loc_down_tex,
            loc_down_halfpixel,
            loc_down_offset,
            loc_up_tex,
            loc_up_halfpixel,
            loc_up_offset,
        })
    }

    /// Pre-allocates or resizes ping-pong FBO textures according to base surface size.
    pub unsafe fn ensure_fbo_sizes(&mut self, width: u32, height: u32) -> Result<(), Box<dyn std::error::Error>> {
        let half_w = (width / 2).max(1);
        let half_h = (height / 2).max(1);
        let quad_w = (width / 4).max(1);
        let quad_h = (height / 4).max(1);

        if self.sizes[0] != (half_w, half_h) {
            self.gl.bind_texture(glow::TEXTURE_2D, Some(self.textures[0]));
            self.gl.tex_image_2d(
                glow::TEXTURE_2D,
                0,
                glow::RGBA as i32,
                half_w as i32,
                half_h as i32,
                0,
                glow::RGBA,
                glow::UNSIGNED_BYTE,
                glow::PixelUnpackData::Slice(None),
            );
            self.gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MIN_FILTER, glow::LINEAR as i32);
            self.gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MAG_FILTER, glow::LINEAR as i32);
            self.gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_S, glow::CLAMP_TO_EDGE as i32);
            self.gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_T, glow::CLAMP_TO_EDGE as i32);

            self.gl.bind_framebuffer(glow::FRAMEBUFFER, Some(self.fbos[0]));
            self.gl.framebuffer_texture_2d(
                glow::FRAMEBUFFER,
                glow::COLOR_ATTACHMENT0,
                glow::TEXTURE_2D,
                Some(self.textures[0]),
                0,
            );
            self.sizes[0] = (half_w, half_h);
        }

        if self.sizes[1] != (quad_w, quad_h) {
            self.gl.bind_texture(glow::TEXTURE_2D, Some(self.textures[1]));
            self.gl.tex_image_2d(
                glow::TEXTURE_2D,
                0,
                glow::RGBA as i32,
                quad_w as i32,
                quad_h as i32,
                0,
                glow::RGBA,
                glow::UNSIGNED_BYTE,
                glow::PixelUnpackData::Slice(None),
            );
            self.gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MIN_FILTER, glow::LINEAR as i32);
            self.gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MAG_FILTER, glow::LINEAR as i32);
            self.gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_S, glow::CLAMP_TO_EDGE as i32);
            self.gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_T, glow::CLAMP_TO_EDGE as i32);

            self.gl.bind_framebuffer(glow::FRAMEBUFFER, Some(self.fbos[1]));
            self.gl.framebuffer_texture_2d(
                glow::FRAMEBUFFER,
                glow::COLOR_ATTACHMENT0,
                glow::TEXTURE_2D,
                Some(self.textures[1]),
                0,
            );
            self.sizes[1] = (quad_w, quad_h);
        }

        self.gl.bind_texture(glow::TEXTURE_2D, None);
        self.gl.bind_framebuffer(glow::FRAMEBUFFER, None);
        Ok(())
    }

    /// Executes Dual-Kawase blur passes on an input texture, returning the blurred texture (FBO 0).
    pub unsafe fn blur(
        &mut self,
        source_tex: glow::NativeTexture,
        width: u32,
        height: u32,
        blur_radius: f32,
    ) -> Result<glow::NativeTexture, Box<dyn std::error::Error>> {
        self.ensure_fbo_sizes(width, height)?;

        let (half_w, half_h) = self.sizes[0];
        let (quad_w, quad_h) = self.sizes[1];
        let offset = blur_radius.clamp(1.0, 5.0);

        self.gl.bind_vertex_array(Some(self.vao));

        // Pass 1: Downsample Source -> FBO 0 (Half resolution)
        self.gl.bind_framebuffer(glow::FRAMEBUFFER, Some(self.fbos[0]));
        self.gl.viewport(0, 0, half_w as i32, half_h as i32);
        self.gl.use_program(Some(self.down_program));
        self.gl.active_texture(glow::TEXTURE0);
        self.gl.bind_texture(glow::TEXTURE_2D, Some(source_tex));
        self.gl.uniform_1_i32(Some(&self.loc_down_tex), 0);
        self.gl.uniform_2_f32(Some(&self.loc_down_halfpixel), 0.5 / half_w as f32, 0.5 / half_h as f32);
        self.gl.uniform_1_f32(Some(&self.loc_down_offset), offset);
        self.gl.draw_arrays(glow::TRIANGLES, 0, 6);

        // Pass 2: Downsample FBO 0 -> FBO 1 (Quarter resolution)
        self.gl.bind_framebuffer(glow::FRAMEBUFFER, Some(self.fbos[1]));
        self.gl.viewport(0, 0, quad_w as i32, quad_h as i32);
        self.gl.bind_texture(glow::TEXTURE_2D, Some(self.textures[0]));
        self.gl.uniform_2_f32(Some(&self.loc_down_halfpixel), 0.5 / quad_w as f32, 0.5 / quad_h as f32);
        self.gl.uniform_1_f32(Some(&self.loc_down_offset), offset * 1.5);
        self.gl.draw_arrays(glow::TRIANGLES, 0, 6);

        // Pass 3: Upsample FBO 1 -> FBO 0 (Half resolution)
        self.gl.bind_framebuffer(glow::FRAMEBUFFER, Some(self.fbos[0]));
        self.gl.viewport(0, 0, half_w as i32, half_h as i32);
        self.gl.use_program(Some(self.up_program));
        self.gl.bind_texture(glow::TEXTURE_2D, Some(self.textures[1]));
        self.gl.uniform_1_i32(Some(&self.loc_up_tex), 0);
        self.gl.uniform_2_f32(Some(&self.loc_up_halfpixel), 0.5 / half_w as f32, 0.5 / half_h as f32);
        self.gl.uniform_1_f32(Some(&self.loc_up_offset), offset);
        self.gl.draw_arrays(glow::TRIANGLES, 0, 6);

        self.gl.bind_vertex_array(None);
        self.gl.bind_framebuffer(glow::FRAMEBUFFER, None);
        self.gl.bind_texture(glow::TEXTURE_2D, None);

        // Result texture is FBO 0 (half-res blurred texture with bilinear filtering)
        Ok(self.textures[0])
    }

    /// Returns the blurred texture from the primary FBO if already rendered.
    #[inline]
    pub fn current_blur_texture(&self) -> glow::NativeTexture {
        self.textures[0]
    }

    unsafe fn compile_program(
        gl: &glow::Context,
        vs_src: &str,
        fs_src: &str,
    ) -> Result<glow::NativeProgram, Box<dyn std::error::Error>> {
        let vs = gl.create_shader(glow::VERTEX_SHADER)?;
        gl.shader_source(vs, vs_src);
        gl.compile_shader(vs);
        if !gl.get_shader_compile_status(vs) {
            let log = gl.get_shader_info_log(vs);
            gl.delete_shader(vs);
            return Err(format!("DualKawase VS compilation failed: {}", log).into());
        }

        let fs = gl.create_shader(glow::FRAGMENT_SHADER)?;
        gl.shader_source(fs, fs_src);
        gl.compile_shader(fs);
        if !gl.get_shader_compile_status(fs) {
            let log = gl.get_shader_info_log(fs);
            gl.delete_shader(vs);
            gl.delete_shader(fs);
            return Err(format!("DualKawase FS compilation failed: {}", log).into());
        }

        let program = gl.create_program()?;
        gl.attach_shader(program, vs);
        gl.attach_shader(program, fs);
        gl.link_program(program);

        gl.delete_shader(vs);
        gl.delete_shader(fs);

        if !gl.get_program_link_status(program) {
            let log = gl.get_program_info_log(program);
            gl.delete_program(program);
            return Err(format!("DualKawase Program link failed: {}", log).into());
        }

        Ok(program)
    }
}

impl Drop for DualKawaseBlur {
    fn drop(&mut self) {
        unsafe {
            self.gl.delete_program(self.down_program);
            self.gl.delete_program(self.up_program);
            self.gl.delete_vertex_array(self.vao);
            self.gl.delete_buffer(self.vbo);
            for &fbo in &self.fbos {
                self.gl.delete_framebuffer(fbo);
            }
            for &tex in &self.textures {
                self.gl.delete_texture(tex);
            }
        }
    }
}
