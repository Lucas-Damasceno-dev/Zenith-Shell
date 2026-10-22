//! Custom GLSL ES 3.0 Fragment Shader Pipeline for Zenith UI Nodes.

use std::collections::HashMap;
use std::sync::Arc;
use std::time::Instant;
use glow::HasContext;
use zenith_layout::CustomShaderStyle;

const SHADER_QUAD_VS: &str = r#"#version 300 es
precision highp float;

layout(location = 0) in vec2 a_pos;

uniform vec2 u_resolution;
uniform vec4 u_bounds;

out vec2 v_uv;
out vec2 v_coord;

void main() {
    vec2 clip = (a_pos / u_resolution) * 2.0 - 1.0;
    clip.y = -clip.y;
    gl_Position = vec4(clip, 0.0, 1.0);
    v_coord = (a_pos - u_bounds.xy) / max(u_bounds.zw, vec2(1.0));
    v_uv = a_pos / u_resolution;
}
"#;

pub struct CompiledCustomShader {
    pub program: glow::NativeProgram,
    pub loc_resolution: Option<glow::UniformLocation>,
    pub loc_bounds: Option<glow::UniformLocation>,
    pub loc_time: Option<glow::UniformLocation>,
    pub custom_uniforms: HashMap<String, Option<glow::UniformLocation>>,
}

pub struct CustomShaderPipeline {
    gl: Arc<glow::Context>,
    pub(crate) start_time: Instant,
    vao: glow::NativeVertexArray,
    vbo: glow::NativeBuffer,
    pub vbo_capacity: usize,
    program_cache: HashMap<String, CompiledCustomShader>,
    failed_shaders: HashMap<String, String>,
}

impl CustomShaderPipeline {
    /// Creates a new custom shader pipeline and allocates quad VAO/VBO.
    ///
    /// # Safety
    ///
    /// - The caller must ensure that an active OpenGL ES context associated with `gl` is current on the calling thread.
    /// - `gl` commands must be valid to execute on the calling thread.
    pub unsafe fn new(gl: Arc<glow::Context>) -> Result<Self, Box<dyn std::error::Error>> {
        let vao = gl.create_vertex_array()?;
        let vbo = gl.create_buffer()?;

        gl.bind_vertex_array(Some(vao));
        gl.bind_buffer(glow::ARRAY_BUFFER, Some(vbo));

        gl.enable_vertex_attrib_array(0);
        gl.vertex_attrib_pointer_f32(0, 2, glow::FLOAT, false, 2 * 4, 0);

        gl.bind_vertex_array(None);
        gl.bind_buffer(glow::ARRAY_BUFFER, None);

        Ok(Self {
            gl,
            start_time: Instant::now(),
            vao,
            vbo,
            vbo_capacity: 0,
            program_cache: HashMap::new(),
            failed_shaders: HashMap::new(),
        })
    }

    /// Render a custom GLSL fragment shader over the given bounding quad.
    ///
    /// # Safety
    ///
    /// - The caller must ensure that an active OpenGL ES context associated with `self.gl` is current on the calling thread.
    /// - `self.vao`, `self.vbo`, and compiled programs must belong to the current context.
    #[allow(clippy::too_many_arguments)]
    pub unsafe fn render(
        &mut self,
        shader: &CustomShaderStyle,
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        screen_w: u32,
        screen_h: u32,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if w <= 0.0 || h <= 0.0 {
            return Ok(());
        }

        if self.get_or_compile(&shader.fragment).is_none() {
            return Ok(());
        }

        let gl = &self.gl;
        let shader_entry = self.program_cache.get_mut(&shader.fragment).unwrap();
        gl.use_program(Some(shader_entry.program));

        // Bind standard pre-resolved uniforms (zero driver query overhead)
        if let Some(ref loc) = shader_entry.loc_resolution {
            gl.uniform_2_f32(Some(loc), screen_w as f32, screen_h as f32);
        }
        if let Some(ref loc) = shader_entry.loc_bounds {
            gl.uniform_4_f32(Some(loc), x, y, w, h);
        }
        if let Some(ref loc) = shader_entry.loc_time {
            let elapsed = self.start_time.elapsed().as_secs_f32();
            gl.uniform_1_f32(Some(loc), elapsed);
        }

        // Bind user-supplied custom scalar uniforms with cached locations
        let program = shader_entry.program;
        for (name, val) in &shader.uniforms {
            let loc = shader_entry.custom_uniforms.entry(name.clone()).or_insert_with(|| {
                gl.get_uniform_location(program, name)
            });
            if let Some(ref l) = loc {
                gl.uniform_1_f32(Some(l), *val);
            }
        }

        // Upload quad vertices
        let x2 = x + w;
        let y2 = y + h;
        let vertices: [f32; 12] = [
            x, y,
            x2, y,
            x2, y2,
            x, y,
            x2, y2,
            x, y2,
        ];

        gl.bind_vertex_array(Some(self.vao));
        gl.bind_buffer(glow::ARRAY_BUFFER, Some(self.vbo));
        let slice = bytemuck_cast_slice(&vertices);
        let needed_bytes = slice.len();
        if needed_bytes <= self.vbo_capacity {
            gl.buffer_sub_data_u8_slice(glow::ARRAY_BUFFER, 0, slice);
        } else {
            let new_cap = needed_bytes.next_power_of_two().max(256);
            gl.buffer_data_size(glow::ARRAY_BUFFER, new_cap as i32, glow::DYNAMIC_DRAW);
            gl.buffer_sub_data_u8_slice(glow::ARRAY_BUFFER, 0, slice);
            self.vbo_capacity = new_cap;
        }

        gl.draw_arrays(glow::TRIANGLES, 0, 6);

        gl.bind_vertex_array(None);
        gl.bind_buffer(glow::ARRAY_BUFFER, None);
        gl.use_program(None);

        Ok(())
    }

    unsafe fn get_or_compile(&mut self, fragment_source: &str) -> Option<glow::NativeProgram> {
        if let Some(entry) = self.program_cache.get(fragment_source) {
            return Some(entry.program);
        }

        if self.failed_shaders.contains_key(fragment_source) {
            return None;
        }

        let full_fs = if fragment_source.contains("#version") {
            fragment_source.to_string()
        } else {
            format!(
                r#"#version 300 es
precision highp float;

in vec2 v_uv;
in vec2 v_coord;

uniform vec2 u_resolution;
uniform vec4 u_bounds;
uniform float u_time;

out vec4 frag_color;

{}
"#,
                fragment_source
            )
        };

        // Bound cache size to prevent leak across dynamic scripts (VmRSS ceiling < 15MB)
        if self.program_cache.len() >= 64 {
            if let Some((first_key, _)) = self.program_cache.iter().next().map(|(k, e)| (k.clone(), e.program)) {
                if let Some(old_entry) = self.program_cache.remove(&first_key) {
                    self.gl.delete_program(old_entry.program);
                }
            }
        }
        if self.failed_shaders.len() >= 64 {
            self.failed_shaders.clear();
        }

        match self.compile_program(SHADER_QUAD_VS, &full_fs) {
            Ok((prog, loc_res, loc_bounds, loc_time)) => {
                let program = prog;
                self.program_cache.insert(
                    fragment_source.to_string(),
                    CompiledCustomShader {
                        program: prog,
                        loc_resolution: loc_res,
                        loc_bounds,
                        loc_time,
                        custom_uniforms: HashMap::new(),
                    },
                );
                Some(program)
            }
            Err(e) => {
                tracing::warn!("[zenith-shader] Failed to compile custom GLSL shader: {}", e);
                self.failed_shaders.insert(fragment_source.to_string(), e);
                None
            }
        }
    }

    unsafe fn compile_program(
        &self,
        vs_src: &str,
        fs_src: &str,
    ) -> Result<
        (
            glow::NativeProgram,
            Option<glow::UniformLocation>,
            Option<glow::UniformLocation>,
            Option<glow::UniformLocation>,
        ),
        String,
    > {
        let gl = &self.gl;

        let vs = gl.create_shader(glow::VERTEX_SHADER).map_err(|e| e.to_string())?;
        gl.shader_source(vs, vs_src);
        gl.compile_shader(vs);
        if !gl.get_shader_compile_status(vs) {
            let log = gl.get_shader_info_log(vs);
            gl.delete_shader(vs);
            return Err(format!("Vertex Shader Error: {}", log));
        }

        let fs = gl.create_shader(glow::FRAGMENT_SHADER).map_err(|e| e.to_string())?;
        gl.shader_source(fs, fs_src);
        gl.compile_shader(fs);
        if !gl.get_shader_compile_status(fs) {
            let log = gl.get_shader_info_log(fs);
            gl.delete_shader(vs);
            gl.delete_shader(fs);
            return Err(format!("Fragment Shader Error: {}", log));
        }

        let program = gl.create_program().map_err(|e| e.to_string())?;
        gl.attach_shader(program, vs);
        gl.attach_shader(program, fs);
        gl.link_program(program);

        gl.delete_shader(vs);
        gl.delete_shader(fs);

        if !gl.get_program_link_status(program) {
            let log = gl.get_program_info_log(program);
            gl.delete_program(program);
            return Err(format!("Shader Program Link Error: {}", log));
        }

        let loc_resolution = gl.get_uniform_location(program, "u_resolution");
        let loc_bounds = gl.get_uniform_location(program, "u_bounds");
        let loc_time = gl.get_uniform_location(program, "u_time");

        Ok((program, loc_resolution, loc_bounds, loc_time))
    }
}

impl Drop for CustomShaderPipeline {
    fn drop(&mut self) {
        unsafe {
            for (_, entry) in self.program_cache.drain() {
                self.gl.delete_program(entry.program);
            }
            self.gl.delete_buffer(self.vbo);
            self.gl.delete_vertex_array(self.vao);
        }
    }
}

fn bytemuck_cast_slice(floats: &[f32]) -> &[u8] {
    unsafe {
        std::slice::from_raw_parts(
            floats.as_ptr() as *const u8,
            std::mem::size_of_val(floats),
        )
    }
}
