//! Full OpenGL ES 3.0 Rendering Engine for Zenith UI Nodes.

use std::sync::Arc;
use glow::HasContext;
use cosmic_text::{Buffer, FontSystem, Metrics, Shaping, SwashCache};
use zenith_layout::ComputedBox;

use super::atlas::GlyphAtlas;
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

uniform vec2 u_resolution;

out vec2 v_uv;
out float v_is_color;

void main() {
    vec2 clip = (a_pos / u_resolution) * 2.0 - 1.0;
    clip.y = -clip.y;
    gl_Position = vec4(clip, 0.0, 1.0);
    v_uv = a_uv;
    v_is_color = a_is_color;
}
"#;

const TEXT_FS: &str = r#"#version 300 es
precision highp float;

in vec2 v_uv;
in float v_is_color;
uniform sampler2D u_atlas;
uniform vec4 u_text_color;

out vec4 frag_color;

void main() {
    vec4 tex = texture(u_atlas, v_uv);
    if (tex.a <= 0.001) {
        discard;
    }
    if (v_is_color > 0.5) {
        frag_color = vec4(tex.rgb, tex.a * u_text_color.a);
    } else {
        frag_color = vec4(u_text_color.rgb, u_text_color.a * tex.a);
    }
}
"#;

#[inline]
fn current_font_family() -> String {
    std::env::var("ZENITH_FONT").unwrap_or_else(|_| "JetBrainsMono Nerd Font".to_string())
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
    loc_text_color: glow::UniformLocation,
    glyph_scratch: Vec<f32>,
    text_buffer: Buffer,
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
        let loc_text_color = gl.get_uniform_location(text_program, "u_text_color").ok_or("u_text_color")?;

        let text_vao = gl.create_vertex_array()?;
        let text_vbo = gl.create_buffer()?;

        gl.bind_vertex_array(Some(text_vao));
        gl.bind_buffer(glow::ARRAY_BUFFER, Some(text_vbo));

        // Vertex layout: [pos_x, pos_y, uv_u, uv_v, is_color] (stride: 5 floats = 20 bytes)
        gl.enable_vertex_attrib_array(0);
        gl.vertex_attrib_pointer_f32(0, 2, glow::FLOAT, false, 5 * 4, 0);
        gl.enable_vertex_attrib_array(1);
        gl.vertex_attrib_pointer_f32(1, 2, glow::FLOAT, false, 5 * 4, 2 * 4);
        gl.enable_vertex_attrib_array(2);
        gl.vertex_attrib_pointer_f32(2, 1, glow::FLOAT, false, 5 * 4, 4 * 4);

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
            loc_text_color,
            glyph_scratch: Vec::with_capacity(512),
            text_buffer,
            inspect_mode: false,
            frame_counter: 0,
            last_fps_instant: std::time::Instant::now(),
            current_fps: 60.0,
        })
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
            boxes[0].y + boxes[0].height
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
                if let Some([cx, cy, cw, ch]) = b.clip_rect {
                    if b.y + b.height <= cy || b.y >= cy + ch || b.x + b.width <= cx || b.x >= cx + cw {
                        continue;
                    }
                }
                if i > 0 && b.y >= root_max_y - 2.0 {
                    continue;
                }

                let cx = b.x + b.width * 0.5;
                let cy = b.y;
                let box_w = b.width * scale_x;
                let mut box_h = b.height * scale_y;
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
                        Some((c, (s.offset_x, s.offset_y), s.blur))
                    } else {
                        None
                    }
                });

                let pad = shadow_spec.map(|(_, _, blur)| blur * 2.5).unwrap_or(2.0);
                if let Some(rect) = damage_rect {
                    if !rect.intersects_box_with_padding(b, pad) {
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
                    ((0.0f32, 0.95f32, 1.0f32, 0.65f32), 1.0f32.max(b.border_width))
                } else {
                    (
                        (
                            b.border_color.r as f32 / 255.0,
                            b.border_color.g as f32 / 255.0,
                            b.border_color.b as f32 / 255.0,
                            b.border_color.a as f32 / 255.0,
                        ),
                        b.border_width,
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
                        b.border_radius,
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
                        self.sdf_instances.push(SdfInstance::new(
                            (box_x - 2.0, box_y - 2.0, box_w + 4.0, box_h + 4.0),
                            (box_x, box_y, box_w, box_h),
                            b.border_radius,
                            (0.0, 0.0, 0.0, 0.0),
                            focus_col,
                            2.0,
                            None,
                            alpha_factor,
                        ));

                        // Quad de seleção com cor de destaque (theme.primary_container)
                        if let Some((sel_rx, sel_ry, sel_rw, sel_rh)) = input.selection_rect {
                            let sel_quad = (box_x + sel_rx, box_y + sel_ry, sel_rw, sel_rh);
                            let sel_bg = (124.0 / 255.0, 77.0 / 255.0, 1.0, 0.40 * alpha_factor);
                            self.sdf_instances.push(SdfInstance::new(
                                sel_quad,
                                sel_quad,
                                2.0,
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
                    let track_h = sl.track_height.max(2.0);
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
                    let thumb_d = sl.thumb_radius * 2.0;
                    let thumb_x = (box_x + norm * (box_w - thumb_d)).clamp(box_x, box_x + box_w - thumb_d);
                    let thumb_y = box_y + (box_h - thumb_d) * 0.5;
                    self.sdf_instances.push(SdfInstance::new(
                        (thumb_x, thumb_y, thumb_d, thumb_d),
                        (thumb_x, thumb_y, thumb_d, thumb_d),
                        sl.thumb_radius,
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
                    let thumb_d = (box_h - 4.0).max(4.0);
                    let thumb_r = thumb_d * 0.5;
                    let thumb_y = box_y + 2.0;
                    let thumb_x = if sw.checked {
                        box_x + box_w - thumb_d - 2.0
                    } else {
                        box_x + 2.0
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
                    if i > 0 && b.y >= root_max_y - 2.0 {
                        continue;
                    }
                    if let Some(rect) = damage_rect {
                        if !rect.intersects_box_with_padding(b, 2.0) {
                            continue;
                        }
                    }
                    if let Some([cx, cy, cw, ch]) = b.clip_rect {
                        if b.y + b.height <= cy || b.y >= cy + ch || b.x + b.width <= cx || b.x >= cx + cw {
                            continue;
                        }
                    }
                    let cx = b.x + b.width * 0.5;
                    let cy = b.y;
                    let box_w = b.width * scale_x;
                    let box_h = b.height * scale_y;
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
                        let font_sz = 12.0f32;
                        let char_count = tip_text.chars().count();
                        let tip_w = (char_count as f32 * font_sz * 0.62 + 20.0).max(48.0);
                        let tip_h = 26.0f32;
                        let tip_x = (b.x + b.width * 0.5 - tip_w * 0.5).clamp(8.0, (width as f32 - tip_w - 8.0).max(8.0));
                        let tip_y = if b.y >= tip_h + 10.0 {
                            b.y - tip_h - 8.0
                        } else {
                            b.y + b.height + 8.0
                        };

                        let pad = 20.0f32;
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
                            (0.0f32, 3.0f32),
                            8.0f32,
                        ));
                        let quad_rect = (
                            tip_x - pad,
                            tip_y - pad,
                            tip_w + pad * 2.0,
                            tip_h + pad * 2.0,
                        );
                        let bg_color = (0.10f32, 0.10f32, 0.14f32, 0.96f32);
                        let border_color = (0.45f32, 0.35f32, 0.75f32, 0.85f32);
                        let border_width = 1.0f32;
                        let border_radius = 6.0f32;

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
                    if i > 0 && b.y >= root_max_y - 2.0 {
                        continue;
                    }
                    if let Some(rect) = damage_rect {
                        if !rect.intersects_box_with_padding(b, 2.0) {
                            continue;
                        }
                    }
                    let cx = b.x + b.width * 0.5;
                    let cy = b.y;
                    let box_w = b.width * scale_x;
                    let box_h = b.height * scale_y;
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

            // Pass 4: Shaped Typography with VRAM Texture Atlas
            for b in boxes {
                if b.y >= root_max_y - 2.0 {
                    continue;
                }
                if let Some(rect) = damage_rect {
                    if !rect.intersects_box_with_padding(b, 4.0) {
                        continue;
                    }
                }
                if let Some([cx, cy, cw, ch]) = b.clip_rect {
                    if b.y + b.height <= cy || b.y >= cy + ch || b.x + b.width <= cx || b.x >= cx + cw {
                        continue;
                    }
                }

                let text_to_draw: Option<(std::borrow::Cow<'_, str>, zenith_layout::Color, f32)> = if let Some((ref text, color, font_size)) = b.text {
                    Some((std::borrow::Cow::Borrowed(text.as_str()), color, font_size))
                } else if let Some(ref input) = b.text_input {
                    let (txt, col) = if input.text.is_empty() {
                        (std::borrow::Cow::Borrowed(input.placeholder.as_str()), input.placeholder_color)
                    } else {
                        (std::borrow::Cow::Borrowed(input.text.as_str()), input.color)
                    };
                    Some((txt, col, input.font_size))
                } else {
                    None
                };

                if let Some((text, color, font_size)) = text_to_draw {
                    let line_height = font_size * 1.3;
                    let metrics = Metrics::new(font_size, line_height);
                    self.text_buffer.set_metrics(metrics);
                    let is_complex = text.chars().any(|c| c as u32 > 0x0600);
                    let shaping = if is_complex { Shaping::Advanced } else { Shaping::Basic };
                    let font_family = current_font_family();
                    self.text_buffer.set_text(
                        &text,
                        &cosmic_text::Attrs::new().family(cosmic_text::Family::Name(&font_family)),
                        shaping,
                        None,
                    );
                    self.text_buffer.shape_until_scroll(font_system, false);

                    let cx = b.x + b.width * 0.5;
                    let cy = b.y;
                    let box_w = b.width * scale_x;
                    let box_h = b.height * scale_y;
                    let box_x = cx - box_w * 0.5;
                    let box_y = cy;

                    let text_offset_y = ((box_h - line_height) / 2.0).max(0.0);
                    let base_y = box_y + text_offset_y;

                    self.glyph_scratch.clear();

                    for run in self.text_buffer.layout_runs() {
                        for glyph in run.glyphs {
                            let physical = glyph.physical((box_x, base_y + run.line_top), 1.0);
                            if let Some(cached) = self.atlas.get_or_insert(font_system, swash_cache, physical.cache_key) {
                                let gx = (physical.x + cached.offset_x) as f32;
                                let gy = (physical.y - cached.offset_y) as f32;
                                let gw = cached.width as f32;
                                let gh = cached.height as f32;

                                let gx1 = gx + gw;
                                let gy1 = gy + gh;
                                let is_col = if cached.is_color { 1.0f32 } else { 0.0f32 };

                                self.glyph_scratch.extend_from_slice(&[
                                    gx,  gy,  cached.u0, cached.v0, is_col,
                                    gx1, gy,  cached.u1, cached.v0, is_col,
                                    gx,  gy1, cached.u0, cached.v1, is_col,

                                    gx,  gy1, cached.u0, cached.v1, is_col,
                                    gx1, gy,  cached.u1, cached.v0, is_col,
                                    gx1, gy1, cached.u1, cached.v1, is_col,
                                ]);
                            }
                        }
                    }

                    if !self.glyph_scratch.is_empty() {
                        self.gl.use_program(Some(self.text_program));
                        self.gl.bind_vertex_array(Some(self.text_vao));

                        self.gl.uniform_2_f32(Some(&self.loc_text_resolution), res.0, res.1);
                        self.gl.uniform_4_f32(
                            Some(&self.loc_text_color),
                            color.r as f32 / 255.0,
                            color.g as f32 / 255.0,
                            color.b as f32 / 255.0,
                            (color.a as f32 / 255.0) * alpha_factor,
                        );

                        self.gl.active_texture(glow::TEXTURE0);
                        self.gl.bind_texture(glow::TEXTURE_2D, Some(self.atlas.texture()));
                        self.gl.uniform_1_i32(Some(&self.loc_text_atlas), 0);

                        self.gl.bind_buffer(glow::ARRAY_BUFFER, Some(self.text_vbo));
                        let slice = std::slice::from_raw_parts(
                            self.glyph_scratch.as_ptr() as *const u8,
                            self.glyph_scratch.len() * std::mem::size_of::<f32>(),
                        );
                        self.gl.buffer_data_u8_slice(glow::ARRAY_BUFFER, slice, glow::DYNAMIC_DRAW);

                        let vertex_count = (self.glyph_scratch.len() / 5) as i32;
                        self.gl.draw_arrays(glow::TRIANGLES, 0, vertex_count);

                        self.gl.bind_texture(glow::TEXTURE_2D, None);
                        self.gl.bind_vertex_array(None);
                        self.gl.use_program(None);
                    }

                    // Render smooth pulsing spring cursor when TextInput is active
                    if let Some(ref input) = b.text_input {
                        if input.active {
                            let cur_x = box_x + input.cursor_offset_x.clamp(0.0, (box_w - 4.0).max(0.0));
                            let cur_y = base_y;
                            let cur_w = 2.0f32;
                            let cur_h = line_height;
                            let pulse = ((self.frame_counter as f32 * 0.15).sin() * 0.35 + 0.65).clamp(0.0, 1.0);
                            let cur_col = (
                                input.color.r as f32 / 255.0,
                                input.color.g as f32 / 255.0,
                                input.color.b as f32 / 255.0,
                                pulse * alpha_factor,
                            );
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
                    }
                }
            }

            // Pass 4b: Tooltip typography on top of floating balloon
            for b in boxes {
                if b.tooltip_active {
                    if let Some(ref tip_text) = b.tooltip {
                        let font_sz = 12.0f32;
                        let char_count = tip_text.chars().count();
                        let tip_w = (char_count as f32 * font_sz * 0.62 + 20.0).max(48.0);
                        let tip_h = 26.0f32;
                        let tip_x = (b.x + b.width * 0.5 - tip_w * 0.5).clamp(8.0, (width as f32 - tip_w - 8.0).max(8.0));
                        let tip_y = if b.y >= tip_h + 10.0 {
                            b.y - tip_h - 8.0
                        } else {
                            b.y + b.height + 8.0
                        };

                        let pad = 20.0f32;
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

                        let line_height = font_sz * 1.3;
                        let metrics = Metrics::new(font_sz, line_height);
                        self.text_buffer.set_metrics(metrics);
                        let font_family = current_font_family();
                        self.text_buffer.set_text(
                            tip_text,
                            &cosmic_text::Attrs::new().family(cosmic_text::Family::Name(&font_family)),
                            Shaping::Basic,
                            None,
                        );
                        self.text_buffer.shape_until_scroll(font_system, false);

                        let text_offset_y = ((tip_h - line_height) / 2.0).max(0.0);
                        let base_y = tip_y + text_offset_y;
                        let base_x = tip_x + 10.0;

                        self.glyph_scratch.clear();

                        for run in self.text_buffer.layout_runs() {
                            for glyph in run.glyphs {
                                let physical = glyph.physical((base_x, base_y + run.line_top), 1.0);
                                if let Some(cached) = self.atlas.get_or_insert(font_system, swash_cache, physical.cache_key) {
                                    let gx = (physical.x + cached.offset_x) as f32;
                                    let gy = (physical.y - cached.offset_y) as f32;
                                    let gw = cached.width as f32;
                                    let gh = cached.height as f32;

                                    let gx1 = gx + gw;
                                    let gy1 = gy + gh;
                                    let is_col = if cached.is_color { 1.0f32 } else { 0.0f32 };

                                    self.glyph_scratch.extend_from_slice(&[
                                        gx,  gy,  cached.u0, cached.v0, is_col,
                                        gx1, gy,  cached.u1, cached.v0, is_col,
                                        gx,  gy1, cached.u0, cached.v1, is_col,

                                        gx,  gy1, cached.u0, cached.v1, is_col,
                                        gx1, gy,  cached.u1, cached.v0, is_col,
                                        gx1, gy1, cached.u1, cached.v1, is_col,
                                    ]);
                                }
                            }
                        }

                        if !self.glyph_scratch.is_empty() {
                            self.gl.use_program(Some(self.text_program));
                            self.gl.bind_vertex_array(Some(self.text_vao));

                            self.gl.uniform_2_f32(Some(&self.loc_text_resolution), res.0, res.1);
                            self.gl.uniform_4_f32(
                                Some(&self.loc_text_color),
                                0.95, 0.95, 0.98, alpha_factor,
                            );

                            self.gl.active_texture(glow::TEXTURE0);
                            self.gl.bind_texture(glow::TEXTURE_2D, Some(self.atlas.texture()));
                            self.gl.uniform_1_i32(Some(&self.loc_text_atlas), 0);

                            self.gl.bind_buffer(glow::ARRAY_BUFFER, Some(self.text_vbo));
                            let slice = std::slice::from_raw_parts(
                                self.glyph_scratch.as_ptr() as *const u8,
                                self.glyph_scratch.len() * std::mem::size_of::<f32>(),
                            );
                            self.gl.buffer_data_u8_slice(glow::ARRAY_BUFFER, slice, glow::DYNAMIC_DRAW);

                            let vertex_count = (self.glyph_scratch.len() / 5) as i32;
                            self.gl.draw_arrays(glow::TRIANGLES, 0, vertex_count);

                            self.gl.bind_texture(glow::TEXTURE_2D, None);
                            self.gl.bind_vertex_array(None);
                            self.gl.use_program(None);
                        }
                    }
                }
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
