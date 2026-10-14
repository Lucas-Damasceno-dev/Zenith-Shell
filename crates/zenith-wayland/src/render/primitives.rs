//! OpenGL ES 3.0 Analytical SDF Shaders for Rounded Rectangles, Borders and Drop Shadows.

use std::sync::Arc;
use glow::HasContext;

const SDF_VERTEX_SHADER: &str = r#"#version 300 es
precision highp float;

layout(location = 0) in vec2 a_unit_pos;

uniform vec2 u_resolution;
uniform vec4 u_rect; // [x, y, w, h] of expanded quad
uniform vec4 u_box;  // [x, y, w, h] of inner box

out vec2 v_local_pos;

void main() {
    vec2 screen_pos = u_rect.xy + (a_unit_pos * 0.5 + 0.5) * u_rect.zw;
    vec2 clip = (screen_pos / u_resolution) * 2.0 - 1.0;
    clip.y = -clip.y;
    gl_Position = vec4(clip, 0.0, 1.0);

    vec2 box_center = u_box.xy + u_box.zw * 0.5;
    v_local_pos = screen_pos - box_center;
}
"#;

const SDF_FRAGMENT_SHADER: &str = r#"#version 300 es
precision highp float;

in vec2 v_local_pos;

uniform vec2 u_box_half_size;
uniform float u_border_radius;
uniform vec4 u_bg_color;
uniform vec4 u_border_color;
uniform float u_border_width;
uniform vec4 u_shadow_color;
uniform vec2 u_shadow_offset;
uniform float u_shadow_blur;
uniform float u_alpha_factor;

out vec4 frag_color;

float sd_round_box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    float r = min(u_border_radius, min(u_box_half_size.x, u_box_half_size.y));
    float d = sd_round_box(v_local_pos, u_box_half_size, r);

    // Box fill anti-aliasing (smoothstep 1 pixel width)
    float fill_a = clamp(0.5 - d, 0.0, 1.0) * u_bg_color.a;
    vec4 col = vec4(u_bg_color.rgb, fill_a);

    // Stroke border
    if (u_border_width > 0.0 && u_border_color.a > 0.0) {
        float b_dist = abs(d + u_border_width * 0.5) - u_border_width * 0.5;
        float border_a = clamp(0.5 - b_dist, 0.0, 1.0) * u_border_color.a;
        col = mix(col, vec4(u_border_color.rgb, u_border_color.a), border_a);
    }

    // Analytical drop shadow
    if (u_shadow_blur > 0.0 && u_shadow_color.a > 0.0) {
        vec2 shadow_p = v_local_pos - u_shadow_offset;
        float d_shadow = sd_round_box(shadow_p, u_box_half_size, r);
        float sigma = max(u_shadow_blur * 0.5, 0.5);
        float shadow_factor = exp(-max(0.0, d_shadow) / sigma);
        if (d_shadow <= 0.0) {
            shadow_factor = 1.0;
        }
        float shadow_a = shadow_factor * u_shadow_color.a * clamp(d + 1.0, 0.0, 1.0);
        vec4 shadow = vec4(u_shadow_color.rgb, shadow_a);
        col = col + shadow * (1.0 - col.a);
    }

    col.a *= u_alpha_factor;
    if (col.a <= 0.001) {
        discard;
    }
    frag_color = col;
}
"#;

pub struct SdfRectShader {
    gl: Arc<glow::Context>,
    program: glow::NativeProgram,
    vao: glow::NativeVertexArray,
    vbo: glow::NativeBuffer,
    loc_resolution: glow::UniformLocation,
    loc_rect: glow::UniformLocation,
    loc_box: glow::UniformLocation,
    loc_box_half_size: glow::UniformLocation,
    loc_border_radius: glow::UniformLocation,
    loc_bg_color: glow::UniformLocation,
    loc_border_color: glow::UniformLocation,
    loc_border_width: glow::UniformLocation,
    loc_shadow_color: glow::UniformLocation,
    loc_shadow_offset: glow::UniformLocation,
    loc_shadow_blur: glow::UniformLocation,
    loc_alpha_factor: glow::UniformLocation,
}

pub type BoxShadow = ((f32, f32, f32, f32), (f32, f32), f32);

impl SdfRectShader {
    /// Creates a new SDF rounded rect rendering shader pipeline.
    ///
    /// # Safety
    ///
    /// - The caller must ensure that an active OpenGL ES context associated with `gl` is current on the calling thread.
    /// - `gl` commands must remain valid throughout execution.
    pub unsafe fn new(gl: Arc<glow::Context>) -> Result<Self, Box<dyn std::error::Error>> {
        let program = Self::compile_program(&gl, SDF_VERTEX_SHADER, SDF_FRAGMENT_SHADER)?;

        let loc_resolution = gl.get_uniform_location(program, "u_resolution").ok_or("u_resolution")?;
        let loc_rect = gl.get_uniform_location(program, "u_rect").ok_or("u_rect")?;
        let loc_box = gl.get_uniform_location(program, "u_box").ok_or("u_box")?;
        let loc_box_half_size = gl.get_uniform_location(program, "u_box_half_size").ok_or("u_box_half_size")?;
        let loc_border_radius = gl.get_uniform_location(program, "u_border_radius").ok_or("u_border_radius")?;
        let loc_bg_color = gl.get_uniform_location(program, "u_bg_color").ok_or("u_bg_color")?;
        let loc_border_color = gl.get_uniform_location(program, "u_border_color").ok_or("u_border_color")?;
        let loc_border_width = gl.get_uniform_location(program, "u_border_width").ok_or("u_border_width")?;
        let loc_shadow_color = gl.get_uniform_location(program, "u_shadow_color").ok_or("u_shadow_color")?;
        let loc_shadow_offset = gl.get_uniform_location(program, "u_shadow_offset").ok_or("u_shadow_offset")?;
        let loc_shadow_blur = gl.get_uniform_location(program, "u_shadow_blur").ok_or("u_shadow_blur")?;
        let loc_alpha_factor = gl.get_uniform_location(program, "u_alpha_factor").ok_or("u_alpha_factor")?;

        let vao = gl.create_vertex_array()?;
        let vbo = gl.create_buffer()?;

        gl.bind_vertex_array(Some(vao));
        gl.bind_buffer(glow::ARRAY_BUFFER, Some(vbo));

        // Unit quad [-1, -1] to [1, 1]
        let unit_quad: [f32; 12] = [
            -1.0, -1.0,
             1.0, -1.0,
            -1.0,  1.0,
            -1.0,  1.0,
             1.0, -1.0,
             1.0,  1.0,
        ];

        gl.buffer_data_u8_slice(
            glow::ARRAY_BUFFER,
            bytemuck_slice(&unit_quad),
            glow::STATIC_DRAW,
        );

        gl.enable_vertex_attrib_array(0);
        gl.vertex_attrib_pointer_f32(0, 2, glow::FLOAT, false, 2 * 4, 0);

        gl.bind_vertex_array(None);
        gl.bind_buffer(glow::ARRAY_BUFFER, None);

        Ok(Self {
            gl,
            program,
            vao,
            vbo,
            loc_resolution,
            loc_rect,
            loc_box,
            loc_box_half_size,
            loc_border_radius,
            loc_bg_color,
            loc_border_color,
            loc_border_width,
            loc_shadow_color,
            loc_shadow_offset,
            loc_shadow_blur,
            loc_alpha_factor,
        })
    }

    /// Draws a rounded rectangle with optional borders and box shadows using SDF evaluation.
    ///
    /// # Safety
    ///
    /// - The caller must ensure that an active OpenGL ES context associated with `self.gl` is current on the calling thread.
    /// - `self.program`, `self.vao`, and `self.vbo` must belong to the active context.
    #[allow(clippy::too_many_arguments)]
    pub unsafe fn draw(
        &self,
        resolution: (f32, f32),
        rect: (f32, f32, f32, f32), // expanded quad
        inner_box: (f32, f32, f32, f32),
        border_radius: f32,
        bg_color: (f32, f32, f32, f32),
        border_color: (f32, f32, f32, f32),
        border_width: f32,
        shadow: Option<BoxShadow>, // ((r,g,b,a), (ox, oy), blur)
        alpha_factor: f32,
    ) {
        self.gl.use_program(Some(self.program));
        self.gl.bind_vertex_array(Some(self.vao));

        self.gl.uniform_2_f32(Some(&self.loc_resolution), resolution.0, resolution.1);
        self.gl.uniform_4_f32(Some(&self.loc_rect), rect.0, rect.1, rect.2, rect.3);
        self.gl.uniform_4_f32(Some(&self.loc_box), inner_box.0, inner_box.1, inner_box.2, inner_box.3);
        self.gl.uniform_2_f32(Some(&self.loc_box_half_size), inner_box.2 * 0.5, inner_box.3 * 0.5);
        self.gl.uniform_1_f32(Some(&self.loc_border_radius), border_radius);

        self.gl.uniform_4_f32(Some(&self.loc_bg_color), bg_color.0, bg_color.1, bg_color.2, bg_color.3);
        self.gl.uniform_4_f32(Some(&self.loc_border_color), border_color.0, border_color.1, border_color.2, border_color.3);
        self.gl.uniform_1_f32(Some(&self.loc_border_width), border_width);

        if let Some((s_col, s_off, s_blur)) = shadow {
            self.gl.uniform_4_f32(Some(&self.loc_shadow_color), s_col.0, s_col.1, s_col.2, s_col.3);
            self.gl.uniform_2_f32(Some(&self.loc_shadow_offset), s_off.0, s_off.1);
            self.gl.uniform_1_f32(Some(&self.loc_shadow_blur), s_blur);
        } else {
            self.gl.uniform_4_f32(Some(&self.loc_shadow_color), 0.0, 0.0, 0.0, 0.0);
            self.gl.uniform_2_f32(Some(&self.loc_shadow_offset), 0.0, 0.0);
            self.gl.uniform_1_f32(Some(&self.loc_shadow_blur), 0.0);
        }

        self.gl.uniform_1_f32(Some(&self.loc_alpha_factor), alpha_factor);

        self.gl.draw_arrays(glow::TRIANGLES, 0, 6);

        self.gl.bind_vertex_array(None);
        self.gl.use_program(None);
    }

    /// Compiles and links an OpenGL shader program from vertex and fragment GLSL source.
    ///
    /// # Safety
    ///
    /// - The caller must ensure that an active OpenGL ES context associated with `gl` is current on the calling thread.
    pub unsafe fn compile_program(
        gl: &glow::Context,
        vs_src: &str,
        fs_src: &str,
    ) -> Result<glow::NativeProgram, Box<dyn std::error::Error>> {
        let vs = gl.create_shader(glow::VERTEX_SHADER)?;
        gl.shader_source(vs, vs_src);
        gl.compile_shader(vs);
        if !gl.get_shader_compile_status(vs) {
            let info = gl.get_shader_info_log(vs);
            return Err(format!("Vertex shader compile error: {}", info).into());
        }

        let fs = gl.create_shader(glow::FRAGMENT_SHADER)?;
        gl.shader_source(fs, fs_src);
        gl.compile_shader(fs);
        if !gl.get_shader_compile_status(fs) {
            let info = gl.get_shader_info_log(fs);
            return Err(format!("Fragment shader compile error: {}", info).into());
        }

        let program = gl.create_program()?;
        gl.attach_shader(program, vs);
        gl.attach_shader(program, fs);
        gl.link_program(program);

        gl.delete_shader(vs);
        gl.delete_shader(fs);

        if !gl.get_program_link_status(program) {
            let info = gl.get_program_info_log(program);
            return Err(format!("Program link error: {}", info).into());
        }

        Ok(program)
    }
}

impl Drop for SdfRectShader {
    fn drop(&mut self) {
        unsafe {
            self.gl.delete_program(self.program);
            self.gl.delete_vertex_array(self.vao);
            self.gl.delete_buffer(self.vbo);
        }
    }
}

fn bytemuck_slice(slice: &[f32]) -> &[u8] {
    unsafe {
        std::slice::from_raw_parts(
            slice.as_ptr() as *const u8,
            std::mem::size_of_val(slice),
        )
    }
}
