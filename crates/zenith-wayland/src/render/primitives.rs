//! OpenGL ES 3.0 Analytical SDF Shaders for Rounded Rectangles, Borders and Drop Shadows.

use std::sync::Arc;
use glow::HasContext;

const SDF_VERTEX_SHADER: &str = r#"#version 300 es
precision highp float;

layout(location = 0) in vec2 a_unit_pos;
layout(location = 1) in vec4 i_rect;
layout(location = 2) in vec4 i_box;
layout(location = 3) in vec4 i_radius_border_alpha;
layout(location = 4) in vec4 i_bg_color;
layout(location = 5) in vec4 i_border_color;
layout(location = 6) in vec4 i_shadow_color;
layout(location = 7) in vec4 i_shadow_geom;

uniform vec2 u_resolution;

out vec2 v_local_pos;
out vec2 v_box_half_size;
out float v_border_radius;
out vec4 v_bg_color;
out vec4 v_border_color;
out float v_border_width;
out vec4 v_shadow_color;
out vec2 v_shadow_offset;
out float v_shadow_blur;
out float v_alpha_factor;

void main() {
    vec2 screen_pos = i_rect.xy + (a_unit_pos * 0.5 + 0.5) * i_rect.zw;
    vec2 clip = (screen_pos / u_resolution) * 2.0 - 1.0;
    clip.y = -clip.y;
    gl_Position = vec4(clip, 0.0, 1.0);

    vec2 box_center = i_box.xy + i_box.zw * 0.5;
    v_local_pos = screen_pos - box_center;
    v_box_half_size = i_box.zw * 0.5;
    v_border_radius = i_radius_border_alpha.x;
    v_border_width = i_radius_border_alpha.y;
    v_alpha_factor = i_radius_border_alpha.z;
    v_bg_color = i_bg_color;
    v_border_color = i_border_color;
    v_shadow_color = i_shadow_color;
    v_shadow_offset = i_shadow_geom.xy;
    v_shadow_blur = i_shadow_geom.z;
}
"#;

const SDF_FRAGMENT_SHADER: &str = r#"#version 300 es
precision highp float;

in vec2 v_local_pos;
in vec2 v_box_half_size;
in float v_border_radius;
in vec4 v_bg_color;
in vec4 v_border_color;
in float v_border_width;
in vec4 v_shadow_color;
in vec2 v_shadow_offset;
in float v_shadow_blur;
in float v_alpha_factor;

out vec4 frag_color;

float sd_round_box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    float r = min(v_border_radius, min(v_box_half_size.x, v_box_half_size.y));
    float d = sd_round_box(v_local_pos, v_box_half_size, r);

    // Box fill anti-aliasing (smoothstep 1 pixel width) with premultiplied alpha
    float fill_a = clamp(0.5 - d, 0.0, 1.0) * v_bg_color.a;
    vec4 col = vec4(v_bg_color.rgb * fill_a, fill_a);

    // Stroke border with analytical physical micro-bevel & Fresnel lighting
    if (v_border_width > 0.0 && v_border_color.a > 0.0 && d <= 1.0 && d >= -v_border_width - 1.5) {
        float b_dist = abs(d + v_border_width * 0.5) - v_border_width * 0.5;
        float border_a = clamp(0.5 - b_dist, 0.0, 1.0) * v_border_color.a;

        // Analytical 2D gradient / surface normal: n = normalize(grad(sd_round_box))
        vec2 q = abs(v_local_pos) - (v_box_half_size - vec2(r));
        vec2 grad;
        if (max(q.x, q.y) > 0.0) {
            grad = sign(v_local_pos) * max(q, vec2(0.0));
        } else {
            grad = (q.x > q.y) ? vec2(sign(v_local_pos.x), 0.0) : vec2(0.0, sign(v_local_pos.y));
        }
        float grad_len = length(grad);
        vec2 normal = (grad_len > 0.001) ? (grad / grad_len) : vec2(0.0, -1.0);

        // Directional key light from top: L = (0.0, -1.0)
        // Upper edge (normal.y < 0) catches physical highlight; lower edge receives ambient occlusion
        float light_factor = -normal.y; // 1.0 at top, -1.0 at bottom
        vec3 border_rgb = v_border_color.rgb;
        if (light_factor > 0.0) {
            // Specular Fresnel / Top light highlight (tactile acrylic glass micro-edge)
            float specular = pow(light_factor, 1.8);
            border_rgb = mix(border_rgb, vec3(1.0), specular * 0.35);
        } else {
            // Ambient occlusion attenuation at bottom edge
            border_rgb *= (1.0 + light_factor * 0.22);
        }

        // Inner micro-chamfer bevel reflection when within the inner stroke boundary
        if (d <= 0.0 && d >= -v_border_width - 1.0 && light_factor > 0.2) {
            float inner_bevel = smoothstep(-v_border_width - 1.0, -v_border_width, d) * light_factor * 0.15;
            col.rgb += vec3(inner_bevel * col.a);
        }

        vec4 border = vec4(border_rgb * border_a, border_a);
        col = border + col * (1.0 - border.a);
    }

    // Analytical drop shadow behind the box with premultiplied alpha
    if (v_shadow_blur > 0.0 && v_shadow_color.a > 0.0) {
        vec2 shadow_p = v_local_pos - v_shadow_offset;
        float d_shadow = sd_round_box(shadow_p, v_box_half_size, r);
        float sigma = max(v_shadow_blur * 0.5, 0.5);
        float shadow_factor = exp(-max(0.0, d_shadow) / sigma);
        if (d_shadow <= 0.0) {
            shadow_factor = 1.0;
        }
        float shadow_a = shadow_factor * v_shadow_color.a * clamp(d + 1.0, 0.0, 1.0);
        vec4 shadow = vec4(v_shadow_color.rgb * shadow_a, shadow_a);
        col = col + shadow * (1.0 - col.a);
    }

    col *= v_alpha_factor;
    if (col.a <= 0.001) {
        discard;
    }
    frag_color = col;
}
"#;

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct SdfInstance {
    pub rect: [f32; 4],
    pub box_geom: [f32; 4],
    pub radius_border_alpha: [f32; 4],
    pub bg_color: [f32; 4],
    pub border_color: [f32; 4],
    pub shadow_color: [f32; 4],
    pub shadow_geom: [f32; 4],
}

pub type BoxShadow = ((f32, f32, f32, f32), (f32, f32), f32);

impl SdfInstance {
    pub fn new(
        rect: (f32, f32, f32, f32),
        inner_box: (f32, f32, f32, f32),
        border_radius: f32,
        bg_color: (f32, f32, f32, f32),
        border_color: (f32, f32, f32, f32),
        border_width: f32,
        shadow: Option<BoxShadow>,
        alpha_factor: f32,
    ) -> Self {
        let (s_col, s_geom) = if let Some((s_c, s_off, s_blur)) = shadow {
            (
                [s_c.0, s_c.1, s_c.2, s_c.3],
                [s_off.0, s_off.1, s_blur, 1.0],
            )
        } else {
            ([0.0; 4], [0.0; 4])
        };

        Self {
            rect: [rect.0, rect.1, rect.2, rect.3],
            box_geom: [inner_box.0, inner_box.1, inner_box.2, inner_box.3],
            radius_border_alpha: [border_radius, border_width, alpha_factor, 0.0],
            bg_color: [bg_color.0, bg_color.1, bg_color.2, bg_color.3],
            border_color: [border_color.0, border_color.1, border_color.2, border_color.3],
            shadow_color: s_col,
            shadow_geom: s_geom,
        }
    }
}

pub struct SdfRectShader {
    gl: Arc<glow::Context>,
    program: glow::NativeProgram,
    vao: glow::NativeVertexArray,
    quad_vbo: glow::NativeBuffer,
    instance_vbo: glow::NativeBuffer,
    pub instance_vbo_capacity: std::cell::Cell<usize>,
    loc_resolution: glow::UniformLocation,
}

impl SdfRectShader {
    /// Creates a new SDF rounded rect rendering shader pipeline with hardware instancing support.
    ///
    /// # Safety
    ///
    /// - The caller must ensure that an active OpenGL ES context associated with `gl` is current on the calling thread.
    /// - `gl` commands must remain valid throughout execution.
    pub unsafe fn new(gl: Arc<glow::Context>) -> Result<Self, Box<dyn std::error::Error>> {
        let program = Self::compile_program(&gl, SDF_VERTEX_SHADER, SDF_FRAGMENT_SHADER)?;
        let loc_resolution = gl.get_uniform_location(program, "u_resolution").ok_or("u_resolution")?;

        let vao = gl.create_vertex_array()?;
        let quad_vbo = gl.create_buffer()?;
        let instance_vbo = gl.create_buffer()?;

        gl.bind_vertex_array(Some(vao));

        // 1. Static unit quad [-1, -1] to [1, 1]
        gl.bind_buffer(glow::ARRAY_BUFFER, Some(quad_vbo));
        let unit_quad: [f32; 12] = [
            -1.0, -1.0,
             1.0, -1.0,
            -1.0,  1.0,
            -1.0,  1.0,
             1.0, -1.0,
              1.0,  1.0,
        ];
        gl.buffer_data_u8_slice(glow::ARRAY_BUFFER, bytemuck_slice(&unit_quad), glow::STATIC_DRAW);
        gl.enable_vertex_attrib_array(0);
        gl.vertex_attrib_pointer_f32(0, 2, glow::FLOAT, false, 2 * 4, 0);

        // 2. Instanced attributes buffer
        gl.bind_buffer(glow::ARRAY_BUFFER, Some(instance_vbo));
        let stride = std::mem::size_of::<SdfInstance>() as i32;

        for (loc, offset_floats) in [
            (1, 0),
            (2, 4),
            (3, 8),
            (4, 12),
            (5, 16),
            (6, 20),
            (7, 24),
        ] {
            gl.enable_vertex_attrib_array(loc);
            gl.vertex_attrib_pointer_f32(loc, 4, glow::FLOAT, false, stride, offset_floats * 4);
            gl.vertex_attrib_divisor(loc, 1);
        }

        gl.bind_vertex_array(None);
        gl.bind_buffer(glow::ARRAY_BUFFER, None);

        Ok(Self {
            gl,
            program,
            vao,
            quad_vbo,
            instance_vbo,
            instance_vbo_capacity: std::cell::Cell::new(0),
            loc_resolution,
        })
    }

    /// Dispatches an entire batch of SDF rounded boxes in a single instanced draw call.
    ///
    /// # Safety
    ///
    /// - Context must be active.
    pub unsafe fn draw_batch(&self, resolution: (f32, f32), instances: &[SdfInstance]) {
        if instances.is_empty() {
            return;
        }

        self.gl.use_program(Some(self.program));
        self.gl.bind_vertex_array(Some(self.vao));
        self.gl.blend_func(glow::ONE, glow::ONE_MINUS_SRC_ALPHA);
        self.gl.uniform_2_f32(Some(&self.loc_resolution), resolution.0, resolution.1);

        self.gl.bind_buffer(glow::ARRAY_BUFFER, Some(self.instance_vbo));
        let needed_bytes = instances.len() * std::mem::size_of::<SdfInstance>();
        let slice = std::slice::from_raw_parts(
            instances.as_ptr() as *const u8,
            needed_bytes,
        );
        let cur_cap = self.instance_vbo_capacity.get();
        if needed_bytes <= cur_cap {
            self.gl.buffer_sub_data_u8_slice(glow::ARRAY_BUFFER, 0, slice);
        } else {
            let new_cap = needed_bytes.next_power_of_two().max(1024);
            self.gl.buffer_data_size(glow::ARRAY_BUFFER, new_cap as i32, glow::DYNAMIC_DRAW);
            self.gl.buffer_sub_data_u8_slice(glow::ARRAY_BUFFER, 0, slice);
            self.instance_vbo_capacity.set(new_cap);
        }

        self.gl.draw_arrays_instanced(glow::TRIANGLES, 0, 6, instances.len() as i32);

        self.gl.bind_buffer(glow::ARRAY_BUFFER, None);
        self.gl.bind_vertex_array(None);
        self.gl.use_program(None);

        // Restore standard straight alpha blend mode used across other rendering passes
        self.gl.blend_func_separate(
            glow::SRC_ALPHA,
            glow::ONE_MINUS_SRC_ALPHA,
            glow::ONE,
            glow::ONE_MINUS_SRC_ALPHA,
        );
    }

    /// Convenience draw call for a single rounded rectangle box.
    #[allow(clippy::too_many_arguments)]
    pub unsafe fn draw(
        &self,
        resolution: (f32, f32),
        rect: (f32, f32, f32, f32),
        inner_box: (f32, f32, f32, f32),
        border_radius: f32,
        bg_color: (f32, f32, f32, f32),
        border_color: (f32, f32, f32, f32),
        border_width: f32,
        shadow: Option<BoxShadow>,
        alpha_factor: f32,
    ) {
        let (s_col, s_geom) = if let Some((s_c, s_off, s_blur)) = shadow {
            (
                [s_c.0, s_c.1, s_c.2, s_c.3],
                [s_off.0, s_off.1, s_blur, 1.0],
            )
        } else {
            ([0.0; 4], [0.0; 4])
        };

        let inst = SdfInstance {
            rect: [rect.0, rect.1, rect.2, rect.3],
            box_geom: [inner_box.0, inner_box.1, inner_box.2, inner_box.3],
            radius_border_alpha: [border_radius, border_width, alpha_factor, 0.0],
            bg_color: [bg_color.0, bg_color.1, bg_color.2, bg_color.3],
            border_color: [border_color.0, border_color.1, border_color.2, border_color.3],
            shadow_color: s_col,
            shadow_geom: s_geom,
        };

        self.draw_batch(resolution, &[inst]);
    }

    /// Compiles and links an OpenGL shader program from vertex and fragment GLSL source.
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
            self.gl.delete_buffer(self.quad_vbo);
            self.gl.delete_buffer(self.instance_vbo);
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
