//! Zenith Wayland - Protocol bindings and layer-shell integration.

use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState},
    delegate_compositor, delegate_layer, delegate_output, delegate_registry, delegate_shm,
    output::{OutputHandler, OutputState},
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    seat::{
        pointer::{PointerEvent, PointerEventKind, PointerHandler, BTN_LEFT},
        Capability, SeatHandler, SeatState,
    },
    delegate_seat, delegate_pointer,
    shell::{
        wlr_layer::{
            Anchor, KeyboardInteractivity, Layer, LayerShell, LayerShellHandler, LayerSurface,
            LayerSurfaceConfigure,
        },
        WaylandSurface,
    },
    shm::{
        slot::SlotPool,
        Shm, ShmHandler,
    },

};
use tracing::{error, info};
use wayland_client::{
    globals::registry_queue_init,
    protocol::{wl_output, wl_shm, wl_surface},
    Connection, QueueHandle,
};
use zenith_layout::{LayoutEngine, UiNode};
use zenith_runtime::LuauRuntime;

/// Default Luau script to configure the status bar interface.
pub const DEFAULT_LUAU_SCRIPT: &str = r##"
return Zenith.Box({
    direction = "row",
    height = 38,
    padding = { x = 12, y = 4 },
    gap = 12,
    background = Zenith.hex("#12131cF6"),
    border_color = Zenith.hex("#7c4dff"),
    border_width = 1,
    children = {
        Zenith.Box({
            padding = { x = 10, y = 4 },
            border_radius = 6,
            background = Zenith.hex("#7c4dff"),
            children = {
                Zenith.Text({ text = "ZENITH v2", font_size = 12, color = Zenith.hex("#FFFFFF") })
            }
        }),
        Zenith.Box({
            padding = { x = 20, y = 4 },
            border_radius = 6,
            background = Zenith.hex("#252839CC"),
            border_color = Zenith.hex("#3b3f58"),
            border_width = 1,
            children = {
                Zenith.Text({ text = "Rust + Luau + Smithay", font_size = 12, color = Zenith.hex("#e0e2ee") })
            }
        }),
        Zenith.Box({
            padding = { x = 12, y = 4 },
            border_radius = 6,
            background = Zenith.hex("#1f2130"),
            children = {
                Zenith.Text({ text = "100% | 144Hz", font_size = 12, color = Zenith.hex("#a6accd") })
            }
        })
    }
})
"##;

/// Contextual popup overlay window.
pub struct PopupWindow {
    pub id: String,
    pub surface: LayerSurface,
    pub width: u32,
    pub height: u32,
    pub configured: bool,
    pub root_ui: UiNode,
    pub computed_boxes: Vec<zenith_layout::ComputedBox>,
}

/// Main application state for Wayland event handling.
pub struct WaylandApp {
    pub registry_state: RegistryState,
    pub output_state: OutputState,
    pub seat_state: SeatState,
    pub compositor_state: CompositorState,
    pub shm: Shm,
    pub pool: SlotPool,
    pub layer_shell: LayerShell,
    pub bar_surface: Option<LayerSurface>,
    pub popup: Option<PopupWindow>,
    pub pointer: Option<wayland_client::protocol::wl_pointer::WlPointer>,
    pub pointer_pos: (f64, f64),
    pub computed_boxes: Vec<zenith_layout::ComputedBox>,
    pub width: u32,
    pub height: u32,
    pub configured: bool,
    pub running: bool,
    pub layout_engine: LayoutEngine,
    pub runtime: LuauRuntime,
    pub root_ui: UiNode,
    pub font_system: cosmic_text::FontSystem,
    pub swash_cache: cosmic_text::SwashCache,
    pub qh: QueueHandle<Self>,
}

impl WaylandApp {
    /// Initialize the Wayland connection, registries, Luau runtime, and layer shell bar.
    pub fn init() -> Result<(Self, Connection, wayland_client::EventQueue<Self>), Box<dyn std::error::Error>> {
        let conn = Connection::connect_to_env()?;
        let (globals, event_queue) = registry_queue_init(&conn)?;
        let qh = event_queue.handle();

        let compositor_state = CompositorState::bind(&globals, &qh)?;
        let layer_shell = LayerShell::bind(&globals, &qh)?;
        let shm = Shm::bind(&globals, &qh)?;
        let pool = SlotPool::new(1920 * 600 * 4, &shm)?;

        let seat_state = SeatState::new(&globals, &qh);
        let runtime = LuauRuntime::new()?;
        let root_ui = runtime.eval_ui(DEFAULT_LUAU_SCRIPT)?;
        let layout_engine = LayoutEngine::new();

        let mut app = Self {
            registry_state: RegistryState::new(&globals),
            output_state: OutputState::new(&globals, &qh),
            seat_state,
            compositor_state,
            shm,
            pool,
            layer_shell,
            bar_surface: None,
            popup: None,
            pointer: None,
            pointer_pos: (0.0, 0.0),
            computed_boxes: Vec::new(),
            width: 1920,
            height: 44,
            configured: false,
            running: true,
            layout_engine,
            runtime,
            root_ui,
            font_system: cosmic_text::FontSystem::new(),
            swash_cache: cosmic_text::SwashCache::new(),
            qh: qh.clone(),
        };

        app.create_bar(&qh)?;

        Ok((app, conn, event_queue))
    }

    /// Creates the top status bar layer surface.
    pub fn create_bar(&mut self, qh: &QueueHandle<Self>) -> Result<(), Box<dyn std::error::Error>> {
        let wl_surface = self.compositor_state.create_surface(qh);

        let layer_surface = self.layer_shell.create_layer_surface(
            qh,
            wl_surface,
            Layer::Top,
            Some("zenith-bar"),
            None,
        );

        layer_surface.set_anchor(Anchor::TOP | Anchor::LEFT | Anchor::RIGHT);
        layer_surface.set_size(0, self.height);
        layer_surface.set_exclusive_zone(self.height as i32);
        layer_surface.set_keyboard_interactivity(KeyboardInteractivity::None);

        layer_surface.commit();
        info!("Layer surface created for zenith-bar (height={})", self.height);

        self.bar_surface = Some(layer_surface);
        Ok(())
    }

    /// Re-evaluates Luau script and updates the UI tree.
    pub fn reload_script(&mut self, script: &str) -> Result<(), Box<dyn std::error::Error>> {
        self.root_ui = self.runtime.eval_ui(script)?;
        self.draw()?;
        if self.popup.is_some() {
            let _ = self.draw_popup();
        }
        Ok(())
    }

    /// Opens or switches to a popup window by overlay id.
    pub fn open_popup(&mut self, id: &str) -> Result<(), Box<dyn std::error::Error>> {
        self.close_popup();

        let (script_name, anchor, width, height, margin_top, margin_right, margin_bottom, margin_left) = match id.to_lowercase().as_str() {
            "dock" => ("Dock", Anchor::BOTTOM, 640, 68, 0, 0, 12, 0),
            "island" | "dynamicisland" => ("DynamicIsland", Anchor::TOP, 380, 52, 10, 0, 0, 0),
            "launcher" => ("Launcher", Anchor::TOP, 520, 440, 80, 0, 0, 0),
            "media" | "mediapopup" => ("MediaPopup", Anchor::TOP, 340, 380, 44, 0, 0, 0),
            "notifications" | "notificationcenter" => ("NotificationCenter", Anchor::TOP | Anchor::RIGHT, 360, 520, 44, 14, 0, 0),
            "audio" | "audiopopup" => ("AudioPopup", Anchor::TOP | Anchor::RIGHT, 320, 240, 44, 14, 0, 0),
            "network" | "networkpopup" => ("NetworkPopup", Anchor::TOP | Anchor::RIGHT, 320, 280, 44, 60, 0, 0),
            "calendar" | "calendarpopup" => ("CalendarPopup", Anchor::TOP, 340, 380, 44, 0, 0, 0),
            "power" | "powermenu" => ("PowerMenu", Anchor::TOP | Anchor::RIGHT, 260, 200, 44, 14, 0, 0),
            "osd" => ("OSD", Anchor::TOP, 280, 48, 60, 0, 0, 0),
            "canvas" | "desktopcanvas" => ("DesktopCanvas", Anchor::TOP | Anchor::LEFT, 380, 320, 60, 0, 0, 24),
            _ => (id, Anchor::TOP | Anchor::RIGHT, 300, 250, 44, 14, 0, 0),
        };

        let candidates = [
            format!("config/zenith/overlays/{}.luau", script_name),
            format!("config/zenith/overlays/{}.lua", script_name),
            format!("config/zenith/overlays/{}Popup.luau", script_name),
            format!("config/zenith/overlays/{}.luau", id),
            format!("config/zenith/{}.luau", script_name.to_lowercase()),
            format!("../../config/zenith/overlays/{}.luau", script_name),
            format!("../../config/zenith/overlays/{}.luau", id),
        ];

        let mut script_content = None;
        for c in &candidates {
            if let Ok(content) = std::fs::read_to_string(c) {
                script_content = Some(content);
                break;
            }
        }

        if script_content.is_none() {
            if let Ok(home) = std::env::var("HOME") {
                let home_candidates = [
                    format!("{}/.config/zenith/overlays/{}.luau", home, script_name),
                    format!("{}/.config/zenith/overlays/{}.luau", home, id),
                    format!("{}/.config/zenith/{}.luau", home, script_name.to_lowercase()),
                ];
                for c in &home_candidates {
                    if let Ok(content) = std::fs::read_to_string(c) {
                        script_content = Some(content);
                        break;
                    }
                }
            }
        }

        let content = script_content.ok_or_else(|| {
            format!("Cannot find overlay script for popup '{}'", id)
        })?;

        let root_ui = self.runtime.eval_ui(&content)?;

        let wl_surface = self.compositor_state.create_surface(&self.qh);
        let layer_surface = self.layer_shell.create_layer_surface(
            &self.qh,
            wl_surface,
            Layer::Top,
            Some(&format!("zenith-popup-{}", id)),
            None,
        );

        layer_surface.set_anchor(anchor);
        layer_surface.set_margin(margin_top, margin_right, margin_bottom, margin_left);
        layer_surface.set_size(width, height);
        layer_surface.set_exclusive_zone(0);
        layer_surface.set_keyboard_interactivity(KeyboardInteractivity::OnDemand);
        layer_surface.commit();

        info!("Created popup layer surface for '{}' ({}x{})", id, width, height);

        self.popup = Some(PopupWindow {
            id: id.to_string(),
            surface: layer_surface,
            width,
            height,
            configured: false,
            root_ui,
            computed_boxes: Vec::new(),
        });

        Ok(())
    }

    /// Closes the currently active popup window if any.
    pub fn close_popup(&mut self) {
        if let Some(popup) = self.popup.take() {
            info!("Closed popup: {}", popup.id);
        }
    }

    /// Toggles a popup window by id.
    pub fn toggle_popup(&mut self, id: &str) {
        if let Some(ref popup) = self.popup {
            if popup.id == id {
                self.close_popup();
                return;
            }
        }
        if let Err(e) = self.open_popup(id) {
            error!("Failed to open popup '{}': {}", id, e);
        }
    }

    /// Execute an action string (e.g. popup:toggle:audio, dispatch:workspace:1, cmd:...)
    pub fn execute_action(&mut self, action: &str) {
        info!("Executing click action: {}", action);
        if action.starts_with("popup:toggle:") {
            let id = &action[13..];
            self.toggle_popup(id);
        } else if action == "popup:close" {
            self.close_popup();
        } else if action.starts_with("popup:open:") {
            let id = &action[11..];
            let _ = self.open_popup(id);
        } else {
            // Dismiss popup on outside actions, except audio tweaks, media controls, and notification actions
            if self.popup.is_some()
                && !action.starts_with("cmd:wpctl")
                && !action.starts_with("media:")
                && !action.starts_with("notification:")
            {
                self.close_popup();
            }
            if let Err(e) = self.runtime.trigger_click(action) {
                error!("Error executing on_click action: {}", e);
            }
        }
    }

    /// Draw the computed Luau layout into the SHM buffer.
    pub fn draw(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if !self.configured {
            return Ok(());
        }

        let width = self.width.max(1);
        let height = self.height.max(1);
        let stride = width * 4;

        let (buffer, canvas) = self.pool.create_buffer(
            width as i32,
            height as i32,
            stride as i32,
            wl_shm::Format::Argb8888,
        )?;

        // Clear canvas
        canvas.fill(0);

        // Compute Taffy layout on the Luau tree
        self.computed_boxes = self.layout_engine.compute(&self.root_ui, width as f32, height as f32);

        Self::render_boxes_to_canvas(
            canvas,
            &self.computed_boxes,
            width,
            height,
            &mut self.font_system,
            &mut self.swash_cache,
        )?;

        if let Some(ref surface) = self.bar_surface {
            buffer.attach_to(surface.wl_surface())?;
            surface.wl_surface().damage_buffer(0, 0, width as i32, height as i32);
            surface.commit();
        }

        Ok(())
    }

    /// Draw the computed Luau layout for the open popup into the SHM buffer.
    pub fn draw_popup(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let popup = match self.popup.as_mut() {
            Some(p) if p.configured => p,
            _ => return Ok(()),
        };

        let width = popup.width.max(1);
        let height = popup.height.max(1);
        let stride = width * 4;

        let (buffer, canvas) = self.pool.create_buffer(
            width as i32,
            height as i32,
            stride as i32,
            wl_shm::Format::Argb8888,
        )?;

        canvas.fill(0);

        popup.computed_boxes = self.layout_engine.compute(&popup.root_ui, width as f32, height as f32);

        Self::render_boxes_to_canvas(
            canvas,
            &popup.computed_boxes,
            width,
            height,
            &mut self.font_system,
            &mut self.swash_cache,
        )?;

        buffer.attach_to(popup.surface.wl_surface())?;
        popup.surface.wl_surface().damage_buffer(0, 0, width as i32, height as i32);
        popup.surface.commit();

        Ok(())
    }

    fn build_rounded_rect_path(x: f32, y: f32, w: f32, h: f32, radius: f32) -> Option<tiny_skia::Path> {
        if w <= 0.0 || h <= 0.0 {
            return None;
        }
        let r = radius.max(0.0).min(w / 2.0).min(h / 2.0);
        if r > 0.0 {
            let mut pb = tiny_skia::PathBuilder::new();
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
        } else {
            tiny_skia::Rect::from_xywh(x, y, w, h).map(tiny_skia::PathBuilder::from_rect)
        }
    }

    fn render_boxes_to_canvas(
        canvas: &mut [u8],
        boxes: &[zenith_layout::ComputedBox],
        width: u32,
        height: u32,
        font_system: &mut cosmic_text::FontSystem,
        swash_cache: &mut cosmic_text::SwashCache,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Pass 1: Vector painting via tiny-skia on top of SHM canvas
        {
            let mut pixmap = tiny_skia::PixmapMut::from_bytes(canvas, width, height)
                .ok_or("Failed to wrap SHM canvas with tiny-skia PixmapMut")?;

            for b in boxes {
                if b.width <= 0.0 || b.height <= 0.0 {
                    continue;
                }

                // Render multi-pass soft vector drop shadow if configured
                if let Some(ref shadow) = b.shadow {
                    if shadow.color.a > 0 && shadow.blur > 0.0 {
                        let steps = ((shadow.blur / 2.0).ceil() as usize).clamp(2, 5);
                        let base_alpha = shadow.color.a as f32 / (steps as f32 * 1.5);
                        for i in 1..=steps {
                            let spread = (i as f32 / steps as f32) * shadow.blur;
                            let sx = b.x + shadow.offset_x - spread * 0.5;
                            let sy = b.y + shadow.offset_y - spread * 0.5;
                            let sw = b.width + spread;
                            let sh = b.height + spread;
                            let sr = (b.border_radius + spread * 0.5).max(0.0);
                            if let Some(spath) = Self::build_rounded_rect_path(sx, sy, sw, sh, sr) {
                                let mut spaint = tiny_skia::Paint::default();
                                spaint.anti_alias = true;
                                let step_alpha = (base_alpha * (1.0 - (i as f32 - 1.0) / steps as f32)).clamp(1.0, 255.0) as u8;
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

                let path = match Self::build_rounded_rect_path(b.x, b.y, b.width, b.height, b.border_radius) {
                    Some(p) => p,
                    None => continue,
                };

                    // Fill background with anti-aliasing
                    if b.background_color.a > 0 {
                        let mut fill_paint = tiny_skia::Paint::default();
                        fill_paint.anti_alias = true;
                        fill_paint.set_color_rgba8(
                            b.background_color.r,
                            b.background_color.g,
                            b.background_color.b,
                            b.background_color.a,
                        );
                        pixmap.fill_path(
                            &path,
                            &fill_paint,
                            tiny_skia::FillRule::Winding,
                            tiny_skia::Transform::identity(),
                            None,
                        );
                    }

                    // Stroke border with anti-aliasing
                    if b.border_width > 0.0 && b.border_color.a > 0 {
                        let mut stroke_paint = tiny_skia::Paint::default();
                        stroke_paint.anti_alias = true;
                        stroke_paint.set_color_rgba8(
                            b.border_color.r,
                            b.border_color.g,
                            b.border_color.b,
                            b.border_color.a,
                        );

                        let stroke = tiny_skia::Stroke {
                            width: b.border_width,
                            ..Default::default()
                        };

                        pixmap.stroke_path(
                            &path,
                            &stroke_paint,
                            &stroke,
                            tiny_skia::Transform::identity(),
                            None,
                        );
                    }
                }
            } // pixmap borrow of canvas is dropped here

        // Pass 2: Draw shaped glyphs with cosmic-text onto the anti-aliased canvas
        for b in boxes {
            if let Some((ref text, color, font_size)) = b.text {
                let line_height = font_size * 1.3;
                let metrics = cosmic_text::Metrics::new(font_size, line_height);
                let mut buffer = cosmic_text::Buffer::new(font_system, metrics);
                buffer.set_text(
                    text,
                    &cosmic_text::Attrs::new().family(cosmic_text::Family::Name("JetBrainsMono Nerd Font")),
                    cosmic_text::Shaping::Advanced,
                    None,
                );

                buffer.shape_until_scroll(font_system, false);

                let cosmic_color = cosmic_text::Color::rgba(color.r, color.g, color.b, color.a);
                let bx = b.x as i32;
                // Center text vertically inside its computed bounding box
                let text_offset_y = ((b.height - line_height) / 2.0).max(0.0) as i32;
                let by = b.y as i32 + text_offset_y;

                buffer.draw(
                    font_system,
                    swash_cache,
                    cosmic_color,
                    |gx, gy, _gw, _gh, glyph_color| {
                        let px = bx + gx;
                        let py = by + gy;
                        if px >= 0 && px < width as i32 && py >= 0 && py < height as i32 {
                            let idx = (py as usize * width as usize + px as usize) * 4;
                            let alpha = glyph_color.a() as u32;
                            if alpha > 0 && idx + 3 < canvas.len() {
                                let bg_b = canvas[idx] as u32;
                                let bg_g = canvas[idx + 1] as u32;
                                let bg_r = canvas[idx + 2] as u32;
                                let bg_a = canvas[idx + 3] as u32;

                                let fg_b = glyph_color.b() as u32;
                                let fg_g = glyph_color.g() as u32;
                                let fg_r = glyph_color.r() as u32;

                                let out_r = (fg_r * alpha + bg_r * (255 - alpha)) / 255;
                                let out_g = (fg_g * alpha + bg_g * (255 - alpha)) / 255;
                                let out_b = (fg_b * alpha + bg_b * (255 - alpha)) / 255;
                                let out_a = alpha + (bg_a * (255 - alpha)) / 255;

                                canvas[idx] = out_b as u8;
                                canvas[idx + 1] = out_g as u8;
                                canvas[idx + 2] = out_r as u8;
                                canvas[idx + 3] = out_a as u8;
                            }
                        }
                    },
                );
            }
        }

        Ok(())
    }

}

// SCTK Delegate implementations
delegate_compositor!(WaylandApp);
delegate_output!(WaylandApp);
delegate_shm!(WaylandApp);
delegate_layer!(WaylandApp);
delegate_seat!(WaylandApp);
delegate_pointer!(WaylandApp);
delegate_registry!(WaylandApp);

impl ProvidesRegistryState for WaylandApp {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    registry_handlers![OutputState, SeatState];
}

impl SeatHandler for WaylandApp {
    fn seat_state(&mut self) -> &mut SeatState {
        &mut self.seat_state
    }

    fn new_seat(&mut self, _conn: &Connection, qh: &QueueHandle<Self>, seat: wayland_client::protocol::wl_seat::WlSeat) {
        if self.pointer.is_none() {
            if let Ok(ptr) = self.seat_state.get_pointer(qh, &seat) {
                info!("Acquired Wayland pointer from seat");
                self.pointer = Some(ptr);
            }
        }
    }

    fn new_capability(
        &mut self,
        _conn: &Connection,
        qh: &QueueHandle<Self>,
        seat: wayland_client::protocol::wl_seat::WlSeat,
        capability: Capability,
    ) {
        if capability == Capability::Pointer && self.pointer.is_none() {
            if let Ok(ptr) = self.seat_state.get_pointer(qh, &seat) {
                info!("Acquired Wayland pointer on capability");
                self.pointer = Some(ptr);
            }
        }
    }

    fn remove_capability(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _seat: wayland_client::protocol::wl_seat::WlSeat,
        capability: Capability,
    ) {
        if capability == Capability::Pointer {
            self.pointer = None;
        }
    }

    fn remove_seat(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _seat: wayland_client::protocol::wl_seat::WlSeat,
    ) {
        self.pointer = None;
    }
}

impl PointerHandler for WaylandApp {
    fn pointer_frame(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _pointer: &wayland_client::protocol::wl_pointer::WlPointer,
        events: &[PointerEvent],
    ) {
        for event in events {
            match event.kind {
                PointerEventKind::Enter { .. } | PointerEventKind::Motion { .. } => {
                    self.pointer_pos = event.position;
                }
                PointerEventKind::Press { button, .. } => {
                    if button == BTN_LEFT {
                        let (px, py) = self.pointer_pos;
                        let mut target_action: Option<String> = None;

                        // Check if click was on popup window
                        if let Some(ref popup) = self.popup {
                            if event.surface == *popup.surface.wl_surface() {
                                for b in popup.computed_boxes.iter().rev() {
                                    if px >= b.x as f64
                                        && px <= (b.x + b.width) as f64
                                        && py >= b.y as f64
                                        && py <= (b.y + b.height) as f64
                                    {
                                        if let Some(ref action) = b.on_click {
                                            target_action = Some(action.clone());
                                            break;
                                        }
                                    }
                                }

                                if let Some(action) = target_action {
                                    self.execute_action(&action);
                                }
                                return;
                            }
                        }

                        // Check if click was on status bar
                        if let Some(ref bar) = self.bar_surface {
                            if event.surface == *bar.wl_surface() {
                                for b in self.computed_boxes.iter().rev() {
                                    if px >= b.x as f64
                                        && px <= (b.x + b.width) as f64
                                        && py >= b.y as f64
                                        && py <= (b.y + b.height) as f64
                                    {
                                        if let Some(ref action) = b.on_click {
                                            target_action = Some(action.clone());
                                            break;
                                        }
                                    }
                                }

                                if let Some(action) = target_action {
                                    self.execute_action(&action);
                                } else if self.popup.is_some() {
                                    // Clicked outside on bar empty space: close popup
                                    self.close_popup();
                                }
                            }
                        }
                    }
                }
                _ => {}
            }
        }
    }
}


impl CompositorHandler for WaylandApp {
    fn scale_factor_changed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _new_scale: i32,
    ) {}

    fn transform_changed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _new_transform: wayland_client::protocol::wl_output::Transform,
    ) {}

    fn frame(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _time: u32,
    ) {}

    fn surface_enter(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _output: &wl_output::WlOutput,
    ) {}

    fn surface_leave(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _output: &wl_output::WlOutput,
    ) {}
}

impl OutputHandler for WaylandApp {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.output_state
    }

    fn new_output(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _output: wl_output::WlOutput,
    ) {}

    fn update_output(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _output: wl_output::WlOutput,
    ) {}

    fn output_destroyed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _output: wl_output::WlOutput,
    ) {}
}

impl ShmHandler for WaylandApp {
    fn shm_state(&mut self) -> &mut Shm {
        &mut self.shm
    }
}

impl LayerShellHandler for WaylandApp {
    fn closed(&mut self, _conn: &Connection, _qh: &QueueHandle<Self>, layer: &LayerSurface) {
        if let Some(ref bar) = self.bar_surface {
            if bar.wl_surface() == layer.wl_surface() {
                info!("Layer surface closed by compositor: bar");
                self.running = false;
                return;
            }
        }

        if let Some(ref popup) = self.popup {
            if popup.surface.wl_surface() == layer.wl_surface() {
                info!("Layer surface closed by compositor: popup '{}'", popup.id);
                self.popup = None;
            }
        }
    }

    fn configure(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        layer: &LayerSurface,
        configure: LayerSurfaceConfigure,
        _serial: u32,
    ) {
        let (new_width, new_height) = configure.new_size;

        if let Some(ref bar) = self.bar_surface {
            if bar.wl_surface() == layer.wl_surface() {
                if new_width > 0 {
                    self.width = new_width;
                }
                if new_height > 0 {
                    self.height = new_height;
                }
                self.configured = true;
                info!("Bar surface configured: {}x{}", self.width, self.height);
                if let Err(e) = self.draw() {
                    error!("Failed to render bar buffer on configure: {}", e);
                }
                return;
            }
        }

        if let Some(ref mut popup) = self.popup {
            if popup.surface.wl_surface() == layer.wl_surface() {
                if new_width > 0 {
                    popup.width = new_width;
                }
                if new_height > 0 {
                    popup.height = new_height;
                }
                popup.configured = true;
                info!("Popup surface configured '{}': {}x{}", popup.id, popup.width, popup.height);
                if let Err(e) = self.draw_popup() {
                    error!("Failed to render popup buffer on configure: {}", e);
                }
            }
        }
    }
}
