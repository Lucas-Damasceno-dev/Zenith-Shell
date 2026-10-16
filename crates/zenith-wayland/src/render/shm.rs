//! Fallback CPU Tiny-Skia / SHM Renderer for headless tests or legacy hardware.

use cosmic_text::{Buffer, FontSystem, Metrics, Shaping, SwashCache};
use zenith_layout::ComputedBox;

pub struct ShmFallbackRenderer;

impl ShmFallbackRenderer {
    pub fn build_rounded_rect_path(x: f32, y: f32, w: f32, h: f32, radius: f32) -> Option<tiny_skia::Path> {
        let mut pb = tiny_skia::PathBuilder::new();
        let r = radius.min(w * 0.5).min(h * 0.5).max(0.0);

        if r <= 0.0 {
            pb.move_to(x, y);
            pb.line_to(x + w, y);
            pb.line_to(x + w, y + h);
            pb.line_to(x, y + h);
            pb.close();
            return pb.finish();
        }

        pb.move_to(x + r, y);
        pb.line_to(x + w - r, y);
        pb.quad_to(x + w, y, x + w, y + r);
        pb.line_to(x + w, y + h - r);
        pb.quad_to(x + w, y + h, x + w - r, y + h);
        pb.line_to(x + r, y + h);
        pb.quad_to(x, y + h, x, y + h - r);
        pb.line_to(x, y + r);
        pb.quad_to(x, y, x + r, y);
        pb.close();
        pb.finish()
    }

    #[allow(clippy::too_many_arguments)]
    pub fn render_boxes(
        canvas: &mut [u8],
        boxes: &[ComputedBox],
        width: u32,
        height: u32,
        spring_val: f32,
        font_system: &mut FontSystem,
        swash_cache: &mut SwashCache,
        damage_rect: Option<crate::render::damage::DamageRect>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let alpha_factor = spring_val.clamp(0.0, 1.0);
        let scale_y = (0.88 + 0.12 * spring_val.clamp(0.0, 1.15)).max(0.0);
        let scale_x = (0.95 + 0.05 * spring_val.clamp(0.0, 1.15)).max(0.0);

        let root_max_y = if !boxes.is_empty() {
            boxes[0].y + boxes[0].height
        } else {
            height as f32
        };

        // Pass 1: Vector painting via tiny-skia on top of SHM canvas
        {
            let mut pixmap = tiny_skia::PixmapMut::from_bytes(canvas, width, height)
                .ok_or("Failed to wrap SHM canvas with tiny-skia PixmapMut")?;

            for (i, b) in boxes.iter().enumerate() {
                if b.width <= 0.0 || b.height <= 0.0 {
                    continue;
                }

                if i > 0 && b.y >= root_max_y - 2.0 {
                    continue;
                }

                let shadow_pad = b.shadow.as_ref().map(|s| s.blur * 2.5).unwrap_or(2.0);
                if let Some(rect) = damage_rect {
                    if !rect.intersects_box_with_padding(b, shadow_pad) {
                        continue;
                    }
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

                if box_x + box_w <= 0.0 || box_x >= width as f32 || box_y + box_h <= 0.0 || box_y >= height as f32 {
                    continue;
                }

                // Multi-pass drop shadow
                if let Some(ref shadow) = b.shadow {
                    if shadow.color.a > 0 && shadow.blur > 0.0 {
                        let steps = ((shadow.blur / 2.0).ceil() as usize).clamp(2, 5);
                        let base_alpha = shadow.color.a as f32 / (steps as f32 * 1.5);
                        for i in 1..=steps {
                            let spread = (i as f32 / steps as f32) * shadow.blur;
                            let sx = box_x + shadow.offset_x - spread * 0.5;
                            let sy = box_y + shadow.offset_y - spread * 0.5;
                            let sw = box_w + spread;
                            let sh = box_h + spread;
                            let sr = (b.border_radius + spread * 0.5).max(0.0);
                            if let Some(spath) = Self::build_rounded_rect_path(sx, sy, sw, sh, sr) {
                                let mut spaint = tiny_skia::Paint {
                                    anti_alias: true,
                                    ..Default::default()
                                };
                                let step_alpha = ((base_alpha * (1.0 - (i as f32 - 1.0) / steps as f32)).clamp(1.0, 255.0) * alpha_factor) as u8;
                                spaint.set_color_rgba8(shadow.color.r, shadow.color.g, shadow.color.b, step_alpha);
                                pixmap.fill_path(
                                    &spath,
                                    &spaint,
                                    tiny_skia::FillRule::Winding,
                                    tiny_skia::Transform::identity(),
                                    None,
                                );
                            }
                        }
                    }
                }

                let path = match Self::build_rounded_rect_path(box_x, box_y, box_w, box_h, b.border_radius) {
                    Some(p) => p,
                    None => continue,
                };

                // Fill background
                if b.background_color.a > 0 {
                    let mut fill_paint = tiny_skia::Paint {
                        anti_alias: true,
                        ..Default::default()
                    };
                    fill_paint.set_color_rgba8(
                        b.background_color.r,
                        b.background_color.g,
                        b.background_color.b,
                        (b.background_color.a as f32 * alpha_factor) as u8,
                    );
                    pixmap.fill_path(&path, &fill_paint, tiny_skia::FillRule::Winding, tiny_skia::Transform::identity(), None);
                }

                // Stroke border
                if b.border_width > 0.0 && b.border_color.a > 0 {
                    let mut stroke_paint = tiny_skia::Paint {
                        anti_alias: true,
                        ..Default::default()
                    };
                    stroke_paint.set_color_rgba8(
                        b.border_color.r,
                        b.border_color.g,
                        b.border_color.b,
                        (b.border_color.a as f32 * alpha_factor) as u8,
                    );
                    let stroke = tiny_skia::Stroke {
                        width: b.border_width,
                        ..Default::default()
                    };
                    pixmap.stroke_path(&path, &stroke_paint, &stroke, tiny_skia::Transform::identity(), None);
                }

                // Images
                if let Some(ref src) = b.image {
                    let target_w = (box_w.round() as u32).max(1);
                    let target_h = (box_h.round() as u32).max(1);
                    if let Ok(decoded) = zenith_services::ImageService::load_image(src, Some(target_w), Some(target_h)) {
                        if let Some(src_pixmap) = tiny_skia::PixmapRef::from_bytes(&decoded.rgba, decoded.width, decoded.height) {
                            let scale_img_x = box_w / decoded.width as f32;
                            let scale_img_y = box_h / decoded.height as f32;
                            let transform = tiny_skia::Transform::from_translate(box_x, box_y).pre_scale(scale_img_x, scale_img_y);
                            let paint = tiny_skia::PixmapPaint {
                                opacity: alpha_factor,
                                blend_mode: tiny_skia::BlendMode::SourceOver,
                                quality: tiny_skia::FilterQuality::Bilinear,
                            };
                            pixmap.draw_pixmap(0, 0, src_pixmap, &paint, transform, None);
                        }
                    }
                }

                // TextInput focus outline
                if let Some(ref input) = b.text_input {
                    if input.active {
                        let mut focus_paint = tiny_skia::Paint {
                            anti_alias: true,
                            ..Default::default()
                        };
                        focus_paint.set_color_rgba8(124, 77, 255, (220.0 * alpha_factor) as u8);
                        let focus_stroke = tiny_skia::Stroke {
                            width: 2.0,
                            ..Default::default()
                        };
                        pixmap.stroke_path(&path, &focus_paint, &focus_stroke, tiny_skia::Transform::identity(), None);
                    }
                }

                // Render Zenith.Slider
                if let Some(ref sl) = b.slider {
                    let track_h = sl.track_height.max(2.0);
                    let track_y = box_y + (box_h - track_h) * 0.5;
                    let norm = ((sl.value - sl.min) / (sl.max - sl.min).max(0.001)).clamp(0.0, 1.0);

                    // Background track
                    if let Some(track_path) = Self::build_rounded_rect_path(box_x, track_y, box_w, track_h, track_h * 0.5) {
                        let mut track_paint = tiny_skia::Paint { anti_alias: true, ..Default::default() };
                        track_paint.set_color_rgba8(
                            sl.track_color.r,
                            sl.track_color.g,
                            sl.track_color.b,
                            (sl.track_color.a as f32 * alpha_factor) as u8,
                        );
                        pixmap.fill_path(&track_path, &track_paint, tiny_skia::FillRule::Winding, tiny_skia::Transform::identity(), None);
                    }

                    // Active filled track
                    let active_w = box_w * norm;
                    if active_w > 1.0 {
                        if let Some(active_path) = Self::build_rounded_rect_path(box_x, track_y, active_w, track_h, track_h * 0.5) {
                            let mut active_paint = tiny_skia::Paint { anti_alias: true, ..Default::default() };
                            active_paint.set_color_rgba8(
                                sl.active_track_color.r,
                                sl.active_track_color.g,
                                sl.active_track_color.b,
                                (sl.active_track_color.a as f32 * alpha_factor) as u8,
                            );
                            pixmap.fill_path(&active_path, &active_paint, tiny_skia::FillRule::Winding, tiny_skia::Transform::identity(), None);
                        }
                    }

                    // Thumb
                    let thumb_d = sl.thumb_radius * 2.0;
                    let thumb_x = (box_x + norm * (box_w - thumb_d)).clamp(box_x, box_x + box_w - thumb_d);
                    let thumb_y = box_y + (box_h - thumb_d) * 0.5;
                    if let Some(thumb_path) = Self::build_rounded_rect_path(thumb_x, thumb_y, thumb_d, thumb_d, sl.thumb_radius) {
                        let mut thumb_paint = tiny_skia::Paint { anti_alias: true, ..Default::default() };
                        thumb_paint.set_color_rgba8(
                            sl.thumb_color.r,
                            sl.thumb_color.g,
                            sl.thumb_color.b,
                            (sl.thumb_color.a as f32 * alpha_factor) as u8,
                        );
                        pixmap.fill_path(&thumb_path, &thumb_paint, tiny_skia::FillRule::Winding, tiny_skia::Transform::identity(), None);
                    }
                }

                // Render Zenith.Switch
                if let Some(ref sw) = b.switch {
                    let pill_radius = box_h * 0.5;
                    let bg_color = if sw.checked { sw.active_color } else { sw.inactive_color };
                    if let Some(pill_path) = Self::build_rounded_rect_path(box_x, box_y, box_w, box_h, pill_radius) {
                        let mut pill_paint = tiny_skia::Paint { anti_alias: true, ..Default::default() };
                        pill_paint.set_color_rgba8(
                            bg_color.r,
                            bg_color.g,
                            bg_color.b,
                            (bg_color.a as f32 * alpha_factor) as u8,
                        );
                        pixmap.fill_path(&pill_path, &pill_paint, tiny_skia::FillRule::Winding, tiny_skia::Transform::identity(), None);
                    }

                    // Sliding thumb
                    let thumb_d = (box_h - 4.0).max(4.0);
                    let thumb_r = thumb_d * 0.5;
                    let thumb_y = box_y + 2.0;
                    let thumb_x = if sw.checked {
                        box_x + box_w - thumb_d - 2.0
                    } else {
                        box_x + 2.0
                    };
                    if let Some(thumb_path) = Self::build_rounded_rect_path(thumb_x, thumb_y, thumb_d, thumb_d, thumb_r) {
                        let mut thumb_paint = tiny_skia::Paint { anti_alias: true, ..Default::default() };
                        thumb_paint.set_color_rgba8(
                            sw.thumb_color.r,
                            sw.thumb_color.g,
                            sw.thumb_color.b,
                            (sw.thumb_color.a as f32 * alpha_factor) as u8,
                        );
                        pixmap.fill_path(&thumb_path, &thumb_paint, tiny_skia::FillRule::Winding, tiny_skia::Transform::identity(), None);
                    }
                }
            }
        }

        // Pass 2: cosmic-text glyphs
        let mut buffer = Buffer::new_empty(Metrics::new(14.0, 18.0));
        for b in boxes {
            if b.y >= root_max_y - 2.0 {
                continue;
            }
            if let Some(rect) = damage_rect {
                if !rect.intersects_box_with_padding(b, 4.0) {
                    continue;
                }
            }

            let text_to_draw: Option<(std::borrow::Cow<'_, str>, zenith_layout::Color, f32)> = if let Some((ref text, color, font_size)) = b.text {
                Some((std::borrow::Cow::Borrowed(text.as_str()), color, font_size))
            } else if let Some(ref input) = b.text_input {
                let (txt, col) = if input.text.is_empty() {
                    (std::borrow::Cow::Borrowed(input.placeholder.as_str()), input.placeholder_color)
                } else if input.active {
                    (std::borrow::Cow::Owned(format!("{}|", input.text)), input.color)
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
                buffer.set_metrics(metrics);
                let is_complex = text.chars().any(|c| c as u32 > 0x0600);
                let shaping = if is_complex { Shaping::Advanced } else { Shaping::Basic };
                let font_family = std::env::var("ZENITH_FONT").unwrap_or_else(|_| "JetBrainsMono Nerd Font".to_string());
                buffer.set_text(
                    &text,
                    &cosmic_text::Attrs::new().family(cosmic_text::Family::Name(&font_family)),
                    shaping,
                    None,
                );
                buffer.shape_until_scroll(font_system, false);

                let cosmic_color = cosmic_text::Color::rgba(
                    color.r,
                    color.g,
                    color.b,
                    (color.a as f32 * alpha_factor) as u8,
                );
                let cx = b.x + b.width * 0.5;
                let cy = b.y;
                let box_w = b.width * scale_x;
                let box_h = b.height * scale_y;
                let box_x = cx - box_w * 0.5;
                let box_y = cy;

                let bx = box_x as i32;
                let text_offset_y = ((box_h - line_height) / 2.0).max(0.0) as i32;
                let by = box_y as i32 + text_offset_y;

                buffer.draw(
                    font_system,
                    swash_cache,
                    cosmic_color,
                    |gx, gy, _gw, _gh, glyph_color| {
                        let px = bx + gx;
                        let py = by + gy;
                        if px >= 0 && px < width as i32 && py >= 0 && (py as f32) < root_max_y {
                            if let Some(rect) = damage_rect {
                                if !rect.contains_point(px, py) {
                                    return;
                                }
                            }
                            let idx = (py as usize * width as usize + px as usize) * 4;
                            let alpha = glyph_color.a() as u32;
                            if alpha > 0 && idx + 3 < canvas.len() {
                                // tiny-skia SHM canvas stores premultiplied RGBA in memory:
                                let bg_r = canvas[idx] as u32;
                                let bg_g = canvas[idx + 1] as u32;
                                let bg_b = canvas[idx + 2] as u32;
                                let bg_a = canvas[idx + 3] as u32;

                                let fg_r = glyph_color.r() as u32;
                                let fg_g = glyph_color.g() as u32;
                                let fg_b = glyph_color.b() as u32;
                                let inv_a = 255 - alpha;

                                let out_r = (((fg_r * alpha + bg_r * inv_a + 128) * 257) >> 16) as u8;
                                let out_g = (((fg_g * alpha + bg_g * inv_a + 128) * 257) >> 16) as u8;
                                let out_b = (((fg_b * alpha + bg_b * inv_a + 128) * 257) >> 16) as u8;
                                let out_a = (((alpha * 255 + bg_a * inv_a + 128) * 257) >> 16) as u8;

                                canvas[idx] = out_r;
                                canvas[idx + 1] = out_g;
                                canvas[idx + 2] = out_b;
                                canvas[idx + 3] = out_a;
                            }
                        }
                    },
                );
            }
        }

        Ok(())
    }
}
