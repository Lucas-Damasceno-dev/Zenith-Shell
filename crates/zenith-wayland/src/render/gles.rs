//! Full OpenGL ES 3.0 Rendering Engine for Zenith UI Nodes.

use std::collections::HashMap;
use std::sync::Arc;
use glow::HasContext;
use cosmic_text::{Buffer, FontSystem, Metrics, Shaping, SwashCache};
use zenith_layout::ComputedBox;

use super::atlas::GlyphAtlas;
use super::blur::DualKawaseBlur;
use super::custom_shader::CustomShaderPipeline;
use super::image_cache::ImageCache;
use super::primitives::{SdfInstance, SdfRectShader};

#[inline]
fn color_to_norm(c: zenith_layout::Color) -> (f32, f32, f32, f32) {
    (
        c.r as f32 / 255.0,
        c.g as f32 / 255.0,
        c.b as f32 / 255.0,
        c.a as f32 / 255.0,
    )
}

const TEXT_VS: &str = r#"#version 300 es
precision highp float;

layout(location = 0) in vec2 a_pos;
layout(location = 1) in vec2 a_uv;
layout(location = 2) in float a_is_color;
layout(location = 3) in vec4 a_color;

uniform vec2 u_resolution;

out vec2 v_uv;
out float v_is_color;
out vec4 v_color;

void main() {
    vec2 clip = (a_pos / u_resolution) * 2.0 - 1.0;
    clip.y = -clip.y;
    gl_Position = vec4(clip, 0.0, 1.0);
    v_uv = a_uv;
    v_is_color = a_is_color;
    v_color = a_color;
}
"#;

const TEXT_FS: &str = r#"#version 300 es
precision highp float;

in vec2 v_uv;
in float v_is_color;
in vec4 v_color;
uniform sampler2D u_atlas;

out vec4 frag_color;

void main() {
    vec4 tex = texture(u_atlas, v_uv);
    if (tex.a <= 0.001) {
        discard;
    }
    if (v_is_color > 0.5) {
        frag_color = vec4(tex.rgb, tex.a * v_color.a);
    } else {
        frag_color = vec4(v_color.rgb, v_color.a * tex.a);
    }
}
"#;

#[inline]
fn current_font_family() -> &'static str {
    static FONT: std::sync::OnceLock<String> = std::sync::OnceLock::new();
    FONT.get_or_init(|| std::env::var("ZENITH_FONT").unwrap_or_else(|_| "JetBrainsMono Nerd Font".to_string()))
}

#[derive(Clone, Debug)]
pub struct PositionedGlyph {
    pub x: f32,
    pub y: f32,
    pub glyph: cosmic_text::LayoutGlyph,
}

#[derive(Clone, Debug)]
pub struct CachedTextLayout {
    pub line_height: f32,
    pub glyphs: std::rc::Rc<[PositionedGlyph]>,
}

pub struct GlesRenderer {
    gl: Arc<glow::Context>,
    sdf_shader: SdfRectShader,
    sdf_instances: Vec<SdfInstance>,
    atlas: GlyphAtlas,
    image_cache: ImageCache,
    custom_shaders: CustomShaderPipeline,
    text_program: glow::NativeProgram,
    text_vao: glow::NativeVertexArray,
    text_vbo: glow::NativeBuffer,
    loc_text_resolution: glow::UniformLocation,
    loc_text_atlas: glow::UniformLocation,
    glyph_scratch: Vec<f32>,
    text_buffer: Buffer,
    pub text_vbo_capacity: usize,
    text_shaping_access_counter: u64,
    text_shaping_cache: HashMap<(u64, u32), (String, CachedTextLayout, u64)>,
    pub blur: Option<DualKawaseBlur>,
    pub inspect_mode: bool,
    pub frame_counter: u32,
    pub last_fps_instant: std::time::Instant,
    pub current_fps: f32,
}

impl GlesRenderer {
    /// Initialize GLES renderer, compiling shaders and allocating vertex buffers.
    ///
    /// # Safety
    ///
    /// - The caller must ensure that an active OpenGL ES context associated with `gl` is current on the calling thread.
    /// - `gl` commands must remain valid throughout execution.
    pub unsafe fn new(gl: Arc<glow::Context>) -> Result<Self, Box<dyn std::error::Error>> {
        let sdf_shader = SdfRectShader::new(gl.clone())?;
        let atlas = GlyphAtlas::new(gl.clone())?;
        let image_cache = ImageCache::new(gl.clone())?;
        let custom_shaders = CustomShaderPipeline::new(gl.clone())?;

        let text_program = SdfRectShader::compile_program(&gl, TEXT_VS, TEXT_FS)?;
        let loc_text_resolution = gl.get_uniform_location(text_program, "u_resolution").ok_or("u_resolution")?;
        let loc_text_atlas = gl.get_uniform_location(text_program, "u_atlas").ok_or("u_atlas")?;

        let text_vao = gl.create_vertex_array()?;
        let text_vbo = gl.create_buffer()?;

        gl.bind_vertex_array(Some(text_vao));
        gl.bind_buffer(glow::ARRAY_BUFFER, Some(text_vbo));

        // Vertex layout: [pos_x, pos_y, uv_u, uv_v, is_color, r, g, b, a] (stride: 9 floats = 36 bytes)
        gl.enable_vertex_attrib_array(0);
        gl.vertex_attrib_pointer_f32(0, 2, glow::FLOAT, false, 9 * 4, 0);
        gl.enable_vertex_attrib_array(1);
        gl.vertex_attrib_pointer_f32(1, 2, glow::FLOAT, false, 9 * 4, 2 * 4);
        gl.enable_vertex_attrib_array(2);
        gl.vertex_attrib_pointer_f32(2, 1, glow::FLOAT, false, 9 * 4, 4 * 4);
        gl.enable_vertex_attrib_array(3);
        gl.vertex_attrib_pointer_f32(3, 4, glow::FLOAT, false, 9 * 4, 5 * 4);

        gl.bind_vertex_array(None);
        gl.bind_buffer(glow::ARRAY_BUFFER, None);

        let text_buffer = Buffer::new_empty(Metrics::new(14.0, 18.0));

        Ok(Self {
            gl,
            sdf_shader,
            sdf_instances: Vec::with_capacity(128),
            atlas,
            image_cache,
            custom_shaders,
            text_program,
            text_vao,
            text_vbo,
            loc_text_resolution,
            loc_text_atlas,
            glyph_scratch: Vec::with_capacity(512),
            text_buffer,
            text_vbo_capacity: 0,
            text_shaping_access_counter: 0,
            text_shaping_cache: HashMap::new(),
            blur: None,
            inspect_mode: false,
            frame_counter: 0,
            last_fps_instant: std::time::Instant::now(),
            current_fps: 60.0,
        })
    }

    pub unsafe fn flush_glyphs(&mut self, res: (f32, f32)) {
        if self.glyph_scratch.is_empty() {
            return;
        }
        self.gl.use_program(Some(self.text_program));
        self.gl.bind_vertex_array(Some(self.text_vao));

        self.gl.uniform_2_f32(Some(&self.loc_text_resolution), res.0, res.1);

        self.gl.active_texture(glow::TEXTURE0);
        self.gl.bind_texture(glow::TEXTURE_2D, Some(self.atlas.texture()));
        self.gl.uniform_1_i32(Some(&self.loc_text_atlas), 0);

        self.gl.bind_buffer(glow::ARRAY_BUFFER, Some(self.text_vbo));
        let needed_bytes = self.glyph_scratch.len() * std::mem::size_of::<f32>();
        let slice = std::slice::from_raw_parts(
            self.glyph_scratch.as_ptr() as *const u8,
            needed_bytes,
        );
        if needed_bytes <= self.text_vbo_capacity {
            self.gl.buffer_sub_data_u8_slice(glow::ARRAY_BUFFER, 0, slice);
        } else {
            let new_cap = needed_bytes.next_power_of_two().max(1024);
            self.gl.buffer_data_size(glow::ARRAY_BUFFER, new_cap as i32, glow::DYNAMIC_DRAW);
            self.gl.buffer_sub_data_u8_slice(glow::ARRAY_BUFFER, 0, slice);
            self.text_vbo_capacity = new_cap;
        }

        let vertex_count = (self.glyph_scratch.len() / 9) as i32;
        self.gl.draw_arrays(glow::TRIANGLES, 0, vertex_count);

        self.gl.bind_texture(glow::TEXTURE_2D, None);
        self.gl.bind_vertex_array(None);
        self.gl.use_program(None);
        self.glyph_scratch.clear();
    }

    pub fn get_or_shape_text(
        &mut self,
        text: &str,
        font_size: f32,
        font_system: &mut FontSystem,
    ) -> CachedTextLayout {
        use std::hash::{Hash, Hasher};
        self.text_shaping_access_counter = self.text_shaping_access_counter.wrapping_add(1);
        let current_access = self.text_shaping_access_counter;

        let font_family = current_font_family();
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        text.hash(&mut hasher);
        font_family.hash(&mut hasher);
        let key = (hasher.finish(), font_size.to_bits());

        if let Some((cached_text, layout, last_used)) = self.text_shaping_cache.get_mut(&key) {
            if cached_text == text {
                *last_used = current_access;
                return layout.clone();
            }
        }

        if self.text_shaping_cache.len() >= 1024 {
            let mut entries: Vec<((u64, u32), u64)> = self.text_shaping_cache.iter()
                .map(|(k, (_, _, lu))| (*k, *lu))
                .collect();
            entries.sort_unstable_by_key(|(_, lu)| *lu);
            for (k, _) in entries.into_iter().take(256) {
                self.text_shaping_cache.remove(&k);
            }
        }

        let line_height = font_size * 1.3;
        let metrics = Metrics::new(font_size, line_height);
        self.text_buffer.set_metrics(metrics);
        let is_complex = text.chars().any(|c| (c as u32) > 0x0600);
        let shaping = if is_complex { Shaping::Advanced } else { Shaping::Basic };
        self.text_buffer.set_text(
            text,
            &cosmic_text::Attrs::new().family(cosmic_text::Family::Name(&font_family)),
            shaping,
            None,
        );
        self.text_buffer.shape_until_scroll(font_system, false);

        let mut glyphs = Vec::new();
        for run in self.text_buffer.layout_runs() {
            for glyph in run.glyphs {
                glyphs.push(PositionedGlyph {
                    x: glyph.x,
                    y: run.line_top + glyph.y,
                    glyph: glyph.clone(),
                });
            }
        }
        let layout = CachedTextLayout {
            line_height,
            glyphs: glyphs.into(),
        };
        self.text_shaping_cache.insert(key, (text.to_string(), layout.clone(), current_access));
        layout
    }

    /// Renders the computed layout boxes directly onto the bound EGL surface framebuffer.
    #[allow(clippy::too_many_arguments)]
    pub fn render_boxes(
        &mut self,
        boxes: &[ComputedBox],
        width: u32,
        height: u32,
        spring_val: f32,
        font_system: &mut FontSystem,
        swash_cache: &mut SwashCache,
        damage_rect: Option<crate::render::damage::DamageRect>,
        scale_factor: f32,
    ) -> Result<(), Box<dyn std::error::Error>> {
        self.frame_counter += 1;
        if self.last_fps_instant.elapsed() >= std::time::Duration::from_millis(500) {
            let elapsed_sec = self.last_fps_instant.elapsed().as_secs_f32();
            self.current_fps = (self.frame_counter as f32 / elapsed_sec).round();
            self.frame_counter = 0;
            self.last_fps_instant = std::time::Instant::now();
        }

        let alpha_factor = spring_val.clamp(0.0, 1.0);
        let scale_y = (0.88 + 0.12 * spring_val.clamp(0.0, 1.15)).max(0.0);
        let scale_x = (0.95 + 0.05 * spring_val.clamp(0.0, 1.15)).max(0.0);

        let root_max_y = if !boxes.is_empty() {
            (boxes[0].y + boxes[0].height) * scale_factor
        } else {
            height as f32
        };

        let res = (width as f32, height as f32);

        unsafe {
            self.gl.viewport(0, 0, width as i32, height as i32);
            if let Some(rect) = damage_rect {
                if let Some((sx, sy, sw, sh)) = rect.to_gl_scissor_valid(width as i32, height as i32) {
                    self.gl.enable(glow::SCISSOR_TEST);
                    self.gl.scissor(sx, sy, sw, sh);
                } else {
                    self.gl.disable(glow::SCISSOR_TEST);
                }
            } else {
                self.gl.disable(glow::SCISSOR_TEST);
            }

            self.gl.clear_color(0.0, 0.0, 0.0, 0.0);
            self.gl.clear(glow::COLOR_BUFFER_BIT);

            self.gl.enable(glow::BLEND);
            self.gl.blend_func_separate(
                glow::SRC_ALPHA,
                glow::ONE_MINUS_SRC_ALPHA,
                glow::ONE,
                glow::ONE_MINUS_SRC_ALPHA,
            );

            // Pass 1: Analytical SDF Geometries & Drop Shadows (Single Batched Instanced Draw Call)
            self.sdf_instances.clear();
            for (i, b) in boxes.iter().enumerate() {
                if b.width <= 0.0 || b.height <= 0.0 {
                    continue;
                }
                let bx = b.x * scale_factor;
                let by = b.y * scale_factor;
                let bw = b.width * scale_factor;
                let bh = b.height * scale_factor;
                let border_radius = b.border_radius * scale_factor;
                let border_width_orig = b.border_width * scale_factor;

                let clip_rect = b.clip_rect.map(|[cx, cy, cw, ch]| {
                    [cx * scale_factor, cy * scale_factor, cw * scale_factor, ch * scale_factor]
                });
                if let Some([cx, cy, cw, ch]) = clip_rect {
                    if by + bh <= cy || by >= cy + ch || bx + bw <= cx || bx >= cx + cw {
                        continue;
                    }
                }
                if i > 0 && by >= root_max_y - 2.0 * scale_factor {
                    continue;
                }

                let cx = bx + bw * 0.5;
                let cy = by;
                let box_w = bw * scale_x;
                let mut box_h = bh * scale_y;
                if i > 0 && cy + box_h > root_max_y {
                    box_h = (root_max_y - cy).max(0.0);
                    if box_h <= 1.0 {
                        continue;
                    }
                }
                let box_x = cx - box_w * 0.5;
                let box_y = cy;

                let shadow_spec = b.shadow.as_ref().and_then(|s| {
                    if s.color.a > 0 && s.blur > 0.0 {
                        let c = (
                            s.color.r as f32 / 255.0,
                            s.color.g as f32 / 255.0,
                            s.color.b as f32 / 255.0,
                            s.color.a as f32 / 255.0,
                        );
                        Some((c, (s.offset_x * scale_factor, s.offset_y * scale_factor), s.blur * scale_factor))
                    } else {
                        None
                    }
                });

                let pad = shadow_spec.map(|(_, _, blur)| blur * 2.5).unwrap_or(2.0 * scale_factor);
                if let Some(rect) = damage_rect {
                    if !rect.intersects_rect(
                        (bx - pad) as i32,
                        (by - pad) as i32,
                        (bw + pad * 2.0) as i32,
                        (bh + pad * 2.0) as i32,
                    ) {
                        continue;
                    }
                }
                if box_x + box_w <= 0.0 || box_x >= width as f32 || box_y + box_h <= 0.0 || box_y >= height as f32 {
                    continue;
                }
                let (ox, oy) = shadow_spec.map(|(_, off, _)| off).unwrap_or((0.0, 0.0));
                let quad_rect = (
                    box_x + ox.min(0.0) - pad,
                    box_y + oy.min(0.0) - pad,
                    box_w + ox.abs() + pad * 2.0,
                    box_h + oy.abs() + pad * 2.0,
                );

                let bg = (
                    b.background_color.r as f32 / 255.0,
                    b.background_color.g as f32 / 255.0,
                    b.background_color.b as f32 / 255.0,
                    b.background_color.a as f32 / 255.0,
                );

                let (border, border_width) = if self.inspect_mode {
                    ((0.0f32, 0.95f32, 1.0f32, 0.65f32), (1.0f32 * scale_factor).max(border_width_orig))
                } else {
                    (
                        (
                            b.border_color.r as f32 / 255.0,
                            b.border_color.g as f32 / 255.0,
                            b.border_color.b as f32 / 255.0,
                            b.border_color.a as f32 / 255.0,
                        ),
                        border_width_orig,
                    )
                };

                let has_visible_geometry = b.background_color.a > 0
                    || (border.3 > 0.0 && border_width > 0.0)
                    || shadow_spec.is_some()
                    || self.inspect_mode;

                if has_visible_geometry {
                    self.sdf_instances.push(SdfInstance::new(
                        quad_rect,
                        (box_x, box_y, box_w, box_h),
                        border_radius,
                        bg,
                        border,
                        border_width,
                        shadow_spec,
                        alpha_factor,
                    ));
                }

                // Focus outline for active TextInput
                if let Some(ref input) = b.text_input {
                    if input.active {
                        let focus_col = (124.0 / 255.0, 77.0 / 255.0, 1.0, 0.86);
                        let pad2 = 2.0 * scale_factor;
                        self.sdf_instances.push(SdfInstance::new(
                            (box_x - pad2, box_y - pad2, box_w + pad2 * 2.0, box_h + pad2 * 2.0),
                            (box_x, box_y, box_w, box_h),
                            border_radius,
                            (0.0, 0.0, 0.0, 0.0),
                            focus_col,
                            pad2,
                            None,
                            alpha_factor,
                        ));

                        // Quad de seleção com cor de destaque (theme.primary_container)
                        if let Some((sel_rx, sel_ry, sel_rw, sel_rh)) = input.selection_rect {
                            let sel_quad = (
                                box_x + sel_rx * scale_factor,
                                box_y + sel_ry * scale_factor,
                                sel_rw * scale_factor,
                                sel_rh * scale_factor,
                            );
                            let sel_bg = (124.0 / 255.0, 77.0 / 255.0, 1.0, 0.40 * alpha_factor);
                            self.sdf_instances.push(SdfInstance::new(
                                sel_quad,
                                sel_quad,
                                2.0 * scale_factor,
                                sel_bg,
                                (0.0, 0.0, 0.0, 0.0),
                                0.0,
                                None,
                                alpha_factor,
                            ));
                        }
                    }
                }

                // Render Zenith.Slider
                if let Some(ref sl) = b.slider {
                    let track_h = (sl.track_height * scale_factor).max(2.0 * scale_factor);
                    let track_y = box_y + (box_h - track_h) * 0.5;
                    let track_col = color_to_norm(sl.track_color);
                    let active_track_col = color_to_norm(sl.active_track_color);
                    let thumb_col = color_to_norm(sl.thumb_color);
                    let norm = ((sl.value - sl.min) / (sl.max - sl.min).max(0.001)).clamp(0.0, 1.0);

                    // Background track
                    self.sdf_instances.push(SdfInstance::new(
                        (box_x, track_y, box_w, track_h),
                        (box_x, track_y, box_w, track_h),
                        track_h * 0.5,
                        track_col,
                        (0.0, 0.0, 0.0, 0.0),
                        0.0,
                        None,
                        alpha_factor,
                    ));

                    // Active filled track
                    let active_w = box_w * norm;
                    if active_w > 1.0 {
                        self.sdf_instances.push(SdfInstance::new(
                            (box_x, track_y, active_w, track_h),
                            (box_x, track_y, active_w, track_h),
                            track_h * 0.5,
                            active_track_col,
                            (0.0, 0.0, 0.0, 0.0),
                            0.0,
                            None,
                            alpha_factor,
                        ));
                    }

                    // Thumb
                    let thumb_d = sl.thumb_radius * 2.0 * scale_factor;
                    let thumb_x = (box_x + norm * (box_w - thumb_d)).clamp(box_x, box_x + box_w - thumb_d);
                    let thumb_y = box_y + (box_h - thumb_d) * 0.5;
                    self.sdf_instances.push(SdfInstance::new(
                        (thumb_x, thumb_y, thumb_d, thumb_d),
                        (thumb_x, thumb_y, thumb_d, thumb_d),
                        sl.thumb_radius * scale_factor,
                        thumb_col,
                        (0.0, 0.0, 0.0, 0.0),
                        0.0,
                        None,
                        alpha_factor,
                    ));
                }

                // Render Zenith.Switch
                if let Some(ref sw) = b.switch {
                    let pill_radius = box_h * 0.5;
                    let bg_color = if sw.checked {
                        color_to_norm(sw.active_color)
                    } else {
                        color_to_norm(sw.inactive_color)
                    };
                    let thumb_color = color_to_norm(sw.thumb_color);

                    // Pill body
                    self.sdf_instances.push(SdfInstance::new(
                        (box_x, box_y, box_w, box_h),
                        (box_x, box_y, box_w, box_h),
                        pill_radius,
                        bg_color,
                        (0.0, 0.0, 0.0, 0.0),
                        0.0,
                        None,
                        alpha_factor,
                    ));

                    // Sliding thumb
                    let thumb_d = (box_h - 4.0 * scale_factor).max(4.0 * scale_factor);
                    let thumb_r = thumb_d * 0.5;
                    let thumb_y = box_y + 2.0 * scale_factor;
                    let thumb_x = if sw.checked {
                        box_x + box_w - thumb_d - 2.0 * scale_factor
                    } else {
                        box_x + 2.0 * scale_factor
                    };
                    self.sdf_instances.push(SdfInstance::new(
                        (thumb_x, thumb_y, thumb_d, thumb_d),
                        (thumb_x, thumb_y, thumb_d, thumb_d),
                        thumb_r,
                        thumb_color,
                        (0.0, 0.0, 0.0, 0.0),
                        0.0,
                        None,
                        alpha_factor,
                    ));
                }
            }
            self.sdf_shader.draw_batch(res, &self.sdf_instances);
            self.sdf_instances.clear();

            self.gl.blend_func_separate(
                glow::SRC_ALPHA,
                glow::ONE_MINUS_SRC_ALPHA,
                glow::ONE,
                glow::ONE_MINUS_SRC_ALPHA,
            );

            // Pass 2: Raster/SVG Images & Active Tooltip Floating Balloons
            for (i, b) in boxes.iter().enumerate() {
                if let Some(ref src) = b.image {
                    let bx = b.x * scale_factor;
                    let by = b.y * scale_factor;
                    let bw = b.width * scale_factor;
                    let bh = b.height * scale_factor;

                    if i > 0 && by >= root_max_y - 2.0 * scale_factor {
                        continue;
                    }
                    if let Some(rect) = damage_rect {
                        if !rect.intersects_rect(
                            (bx - 2.0 * scale_factor) as i32,
                            (by - 2.0 * scale_factor) as i32,
                            (bw + 4.0 * scale_factor) as i32,
                            (bh + 4.0 * scale_factor) as i32,
                        ) {
                            continue;
                        }
                    }
                    let clip_rect = b.clip_rect.map(|[cx, cy, cw, ch]| {
                        [cx * scale_factor, cy * scale_factor, cw * scale_factor, ch * scale_factor]
                    });
                    if let Some([cx, cy, cw, ch]) = clip_rect {
                        if by + bh <= cy || by >= cy + ch || bx + bw <= cx || bx >= cx + cw {
                            continue;
                        }
                    }
                    let cx = bx + bw * 0.5;
                    let cy = by;
                    let box_w = bw * scale_x;
                    let box_h = bh * scale_y;
                    let box_x = cx - box_w * 0.5;
                    let box_y = cy;

                    let target_w = (box_w.round() as u32).max(1);
                    let target_h = (box_h.round() as u32).max(1);

                    if let Some((tex, _, _)) = self.image_cache.get_or_load(src, target_w, target_h) {
                        self.image_cache.draw(tex, res, (box_x, box_y, box_w, box_h), alpha_factor);
                    }
                }
            }

            for b in boxes {
                if b.tooltip_active {
                    if let Some(ref tip_text) = b.tooltip {
                        let bx = b.x * scale_factor;
                        let by = b.y * scale_factor;
                        let bw = b.width * scale_factor;
                        let bh = b.height * scale_factor;

                        let font_sz = 12.0f32 * scale_factor;
                        let char_count = tip_text.chars().count();
                        let tip_w = (char_count as f32 * font_sz * 0.62 + 20.0 * scale_factor).max(48.0 * scale_factor);
                        let tip_h = 26.0f32 * scale_factor;
                        let tip_x = (bx + bw * 0.5 - tip_w * 0.5).clamp(8.0 * scale_factor, (width as f32 - tip_w - 8.0 * scale_factor).max(8.0 * scale_factor));
                        let tip_y = if by >= tip_h + 10.0 * scale_factor {
                            by - tip_h - 8.0 * scale_factor
                        } else {
                            by + bh + 8.0 * scale_factor
                        };

                        let pad = 20.0f32 * scale_factor;
                        if let Some(rect) = damage_rect {
                            if !rect.intersects_rect(
                                (tip_x - pad) as i32,
                                (tip_y - pad) as i32,
                                (tip_w + pad * 2.0) as i32,
                                (tip_h + pad * 2.0) as i32,
                            ) {
                                continue;
                            }
                        }

                        let shadow_spec = Some((
                            (0.0f32, 0.0f32, 0.0f32, 0.75f32),
                            (0.0f32, 3.0f32 * scale_factor),
                            8.0f32 * scale_factor,
                        ));
                        let quad_rect = (
                            tip_x - pad,
                            tip_y - pad,
                            tip_w + pad * 2.0,
                            tip_h + pad * 2.0,
                        );
                        let bg_color = (0.10f32, 0.10f32, 0.14f32, 0.96f32);
                        let border_color = (0.45f32, 0.35f32, 0.75f32, 0.85f32);
                        let border_width = 1.0f32 * scale_factor;
                        let border_radius = 6.0f32 * scale_factor;

                        self.sdf_shader.draw(
                            res,
                            quad_rect,
                            (tip_x, tip_y, tip_w, tip_h),
                            border_radius,
                            bg_color,
                            border_color,
                            border_width,
                            shadow_spec,
                            alpha_factor,
                        );
                    }
                }
            }

            // Pass 3: Custom GLSL ES 3.0 Fragment Shaders
            for (i, b) in boxes.iter().enumerate() {
                if let Some(ref shader) = b.custom_shader {
                    let bx = b.x * scale_factor;
                    let by = b.y * scale_factor;
                    let bw = b.width * scale_factor;
                    let bh = b.height * scale_factor;

                    if i > 0 && by >= root_max_y - 2.0 * scale_factor {
                        continue;
                    }
                    if let Some(rect) = damage_rect {
                        if !rect.intersects_rect(
                            (bx - 2.0 * scale_factor) as i32,
                            (by - 2.0 * scale_factor) as i32,
                            (bw + 4.0 * scale_factor) as i32,
                            (bh + 4.0 * scale_factor) as i32,
                        ) {
                            continue;
                        }
                    }
                    let cx = bx + bw * 0.5;
                    let cy = by;
                    let box_w = bw * scale_x;
                    let box_h = bh * scale_y;
                    let box_x = cx - box_w * 0.5;
                    let box_y = cy;

                    let _ = self.custom_shaders.render(
                        shader,
                        box_x,
                        box_y,
                        box_w,
                        box_h,
                        width,
                        height,
                    );
                }
            }

            // Pass 4: Shaped Typography with VRAM Texture Atlas (Batched into 1 draw call)
            self.glyph_scratch.clear();
            let mut active_cursor: Option<((f32, f32, f32, f32), (f32, f32, f32, f32))> = None;

            for b in boxes {
                let bx = b.x * scale_factor;
                let by = b.y * scale_factor;
                let bw = b.width * scale_factor;
                let bh = b.height * scale_factor;

                if by >= root_max_y - 2.0 * scale_factor {
                    continue;
                }
                if let Some(rect) = damage_rect {
                    if !rect.intersects_rect(
                        (bx - 4.0 * scale_factor) as i32,
                        (by - 4.0 * scale_factor) as i32,
                        (bw + 8.0 * scale_factor) as i32,
                        (bh + 8.0 * scale_factor) as i32,
                    ) {
                        continue;
                    }
                }
                let clip_rect = b.clip_rect.map(|[cx, cy, cw, ch]| {
                    [cx * scale_factor, cy * scale_factor, cw * scale_factor, ch * scale_factor]
                });
                if let Some([cx, cy, cw, ch]) = clip_rect {
                    if by + bh <= cy || by >= cy + ch || bx + bw <= cx || bx >= cx + cw {
                        continue;
                    }
                }

                let text_to_draw: Option<(std::borrow::Cow<'_, str>, zenith_layout::Color, f32)> = if let Some((ref text, color, font_size)) = b.text {
                    Some((std::borrow::Cow::Borrowed(text.as_str()), color, font_size * scale_factor))
                } else if let Some(ref input) = b.text_input {
                    let (txt, col) = if input.text.is_empty() {
                        (std::borrow::Cow::Borrowed(input.placeholder.as_str()), input.placeholder_color)
                    } else {
                        (std::borrow::Cow::Borrowed(input.text.as_str()), input.color)
                    };
                    Some((txt, col, input.font_size * scale_factor))
                } else {
                    None
                };

                if let Some((text, color, font_size)) = text_to_draw {
                    let layout = self.get_or_shape_text(&text, font_size, font_system);
                    let line_height = layout.line_height;

                    let cx = bx + bw * 0.5;
                    let cy = by;
                    let box_w = bw * scale_x;
                    let box_h = bh * scale_y;
                    let box_x = cx - box_w * 0.5;
                    let box_y = cy;

                    let text_offset_y = ((box_h - line_height) / 2.0).max(0.0);
                    let base_y = box_y + text_offset_y;

                    let cr = color.r as f32 / 255.0;
                    let cg = color.g as f32 / 255.0;
                    let cb = color.b as f32 / 255.0;
                    let ca = (color.a as f32 / 255.0) * alpha_factor;

                    for pos_glyph in layout.glyphs.iter() {
                        let physical = pos_glyph.glyph.physical((box_x + pos_glyph.x, base_y + pos_glyph.y), 1.0);

                        let mut cached_opt = self.atlas.get_or_insert(font_system, swash_cache, physical.cache_key);
                        if cached_opt.is_none() && self.atlas.needs_flush {
                            self.flush_glyphs(res);
                            self.atlas.reset();
                            cached_opt = self.atlas.get_or_insert(font_system, swash_cache, physical.cache_key);
                        }

                        if let Some(cached) = cached_opt {
                            let gx = (physical.x + cached.offset_x) as f32;
                            let gy = (physical.y - cached.offset_y) as f32;
                            let gw = cached.width as f32;
                            let gh = cached.height as f32;

                            let gx1 = gx + gw;
                            let gy1 = gy + gh;
                            let is_col = if cached.is_color { 1.0f32 } else { 0.0f32 };

                            self.glyph_scratch.extend_from_slice(&[
                                gx,  gy,  cached.u0, cached.v0, is_col, cr, cg, cb, ca,
                                gx1, gy,  cached.u1, cached.v0, is_col, cr, cg, cb, ca,
                                gx,  gy1, cached.u0, cached.v1, is_col, cr, cg, cb, ca,

                                gx,  gy1, cached.u0, cached.v1, is_col, cr, cg, cb, ca,
                                gx1, gy,  cached.u1, cached.v0, is_col, cr, cg, cb, ca,
                                gx1, gy1, cached.u1, cached.v1, is_col, cr, cg, cb, ca,
                            ]);
                        }
                    }

                    // Render smooth pulsing spring cursor when TextInput is active
                    if let Some(ref input) = b.text_input {
                        if input.active {
                            let cur_x = box_x + (input.cursor_offset_x * scale_factor).clamp(0.0, (box_w - 4.0 * scale_factor).max(0.0));
                            let cur_y = base_y;
                            let cur_w = 2.0f32 * scale_factor;
                            let cur_h = line_height;
                            let pulse = ((self.frame_counter as f32 * 0.15).sin() * 0.35 + 0.65).clamp(0.0, 1.0);
                            let cur_col = (
                                input.color.r as f32 / 255.0,
                                input.color.g as f32 / 255.0,
                                input.color.b as f32 / 255.0,
                                pulse * alpha_factor,
                            );
                            active_cursor = Some(((cur_x, cur_y, cur_w, cur_h), cur_col));
                        }
                    }
                }
            }

            // Pass 4b: Tooltip typography on top of floating balloon
            for b in boxes {
                if b.tooltip_active {
                    if let Some(ref tip_text) = b.tooltip {
                        let bx = b.x * scale_factor;
                        let by = b.y * scale_factor;
                        let bw = b.width * scale_factor;
                        let bh = b.height * scale_factor;

                        let font_sz = 12.0f32 * scale_factor;
                        let char_count = tip_text.chars().count();
                        let tip_w = (char_count as f32 * font_sz * 0.62 + 20.0 * scale_factor).max(48.0 * scale_factor);
                        let tip_h = 26.0f32 * scale_factor;
                        let tip_x = (bx + bw * 0.5 - tip_w * 0.5).clamp(8.0 * scale_factor, (width as f32 - tip_w - 8.0 * scale_factor).max(8.0 * scale_factor));
                        let tip_y = if by >= tip_h + 10.0 * scale_factor {
                            by - tip_h - 8.0 * scale_factor
                        } else {
                            by + bh + 8.0 * scale_factor
                        };

                        let pad = 20.0f32 * scale_factor;
                        if let Some(rect) = damage_rect {
                            if !rect.intersects_rect(
                                (tip_x - pad) as i32,
                                (tip_y - pad) as i32,
                                (tip_w + pad * 2.0) as i32,
                                (tip_h + pad * 2.0) as i32,
                            ) {
                                continue;
                            }
                        }

                        let layout = self.get_or_shape_text(tip_text, font_sz, font_system);
                        let line_height = layout.line_height;

                        let text_offset_y = ((tip_h - line_height) / 2.0).max(0.0);
                        let base_y = tip_y + text_offset_y;
                        let base_x = tip_x + 10.0 * scale_factor;

                        let cr = 0.95f32;
                        let cg = 0.95f32;
                        let cb = 0.98f32;
                        let ca = alpha_factor;

                        for pos_glyph in layout.glyphs.iter() {
                            let physical = pos_glyph.glyph.physical((base_x + pos_glyph.x, base_y + pos_glyph.y), 1.0);

                            let mut cached_opt = self.atlas.get_or_insert(font_system, swash_cache, physical.cache_key);
                            if cached_opt.is_none() && self.atlas.needs_flush {
                                self.flush_glyphs(res);
                                self.atlas.reset();
                                cached_opt = self.atlas.get_or_insert(font_system, swash_cache, physical.cache_key);
                            }

                            if let Some(cached) = cached_opt {
                                let gx = (physical.x + cached.offset_x) as f32;
                                let gy = (physical.y - cached.offset_y) as f32;
                                let gw = cached.width as f32;
                                let gh = cached.height as f32;

                                let gx1 = gx + gw;
                                let gy1 = gy + gh;
                                let is_col = if cached.is_color { 1.0f32 } else { 0.0f32 };

                                self.glyph_scratch.extend_from_slice(&[
                                    gx,  gy,  cached.u0, cached.v0, is_col, cr, cg, cb, ca,
                                    gx1, gy,  cached.u1, cached.v0, is_col, cr, cg, cb, ca,
                                    gx,  gy1, cached.u0, cached.v1, is_col, cr, cg, cb, ca,

                                    gx,  gy1, cached.u0, cached.v1, is_col, cr, cg, cb, ca,
                                    gx1, gy,  cached.u1, cached.v0, is_col, cr, cg, cb, ca,
                                    gx1, gy1, cached.u1, cached.v1, is_col, cr, cg, cb, ca,
                                ]);
                            }
                        }
                    }
                }
            }

            // Single Batched Draw Call for all text and tooltips
            if !self.glyph_scratch.is_empty() {
                self.flush_glyphs(res);
            }

            if let Some(((cur_x, cur_y, cur_w, cur_h), cur_col)) = active_cursor {
                self.sdf_shader.draw(
                    res,
                    (cur_x, cur_y, cur_w, cur_h),
                    (cur_x, cur_y, cur_w, cur_h),
                    1.0,
                    cur_col,
                    (0.0, 0.0, 0.0, 0.0),
                    0.0,
                    None,
                    alpha_factor,
                );
            }

            self.gl.disable(glow::SCISSOR_TEST);
        }

        Ok(())
    }
}

impl Drop for GlesRenderer {
    fn drop(&mut self) {
        unsafe {
            self.gl.delete_program(self.text_program);
            self.gl.delete_vertex_array(self.text_vao);
            self.gl.delete_buffer(self.text_vbo);
        }
    }
}
