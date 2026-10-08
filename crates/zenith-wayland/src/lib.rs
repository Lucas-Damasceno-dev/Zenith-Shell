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
        let pool = SlotPool::new(1920 * 40 * 4, &shm)?;

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
            pointer: None,
            pointer_pos: (0.0, 0.0),
            computed_boxes: Vec::new(),
            width: 1920,
            height: 38,
            configured: false,
            running: true,
            layout_engine,
            runtime,
            root_ui,
            font_system: cosmic_text::FontSystem::new(),
            swash_cache: cosmic_text::SwashCache::new(),
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
        Ok(())
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

        // Pass 1: Vector painting via tiny-skia on top of SHM canvas
        {
            let mut pixmap = tiny_skia::PixmapMut::from_bytes(canvas, width, height)

                .ok_or("Failed to wrap SHM canvas with tiny-skia PixmapMut")?;

            for b in &self.computed_boxes {

                if b.width <= 0.0 || b.height <= 0.0 {
                    continue;
                }

                let radius = b.border_radius.max(0.0);
                let rect = tiny_skia::Rect::from_xywh(b.x, b.y, b.width, b.height);
                if let Some(r) = rect {
                    let path = if radius > 0.0 {
                        let r = radius.min(b.width / 2.0).min(b.height / 2.0);
                        let mut pb = tiny_skia::PathBuilder::new();
                        let x = b.x;
                        let y = b.y;
                        let w = b.width;
                        let h = b.height;

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
                        Some(tiny_skia::PathBuilder::from_rect(r))
                    };

                    let path = match path {
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
            }
        } // pixmap borrow of canvas is dropped here

        // Pass 2: Draw shaped glyphs with cosmic-text onto the anti-aliased canvas
        for b in &self.computed_boxes {
            if let Some((ref text, color, font_size)) = b.text {

                let line_height = font_size * 1.3;
                let metrics = cosmic_text::Metrics::new(font_size, line_height);
                let mut buffer = cosmic_text::Buffer::new(&mut self.font_system, metrics);
                buffer.set_text(
                    text,
                    &cosmic_text::Attrs::new().family(cosmic_text::Family::Name("JetBrainsMono Nerd Font")),
                    cosmic_text::Shaping::Advanced,
                    None,
                );

                buffer.shape_until_scroll(&mut self.font_system, false);

                let cosmic_color = cosmic_text::Color::rgba(color.r, color.g, color.b, color.a);
                let bx = b.x as i32;
                // Center text vertically inside its computed bounding box
                let text_offset_y = ((b.height - line_height) / 2.0).max(0.0) as i32;
                let by = b.y as i32 + text_offset_y;

                buffer.draw(
                    &mut self.font_system,
                    &mut self.swash_cache,
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


        if let Some(ref surface) = self.bar_surface {
            buffer.attach_to(surface.wl_surface())?;
            surface.wl_surface().damage_buffer(0, 0, width as i32, height as i32);
            surface.commit();
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
                        // Find clicked box with on_click handler (deepest/innermost box)
                        let mut clicked_action: Option<String> = None;
                        for b in self.computed_boxes.iter().rev() {
                            if px >= b.x as f64
                                && px <= (b.x + b.width) as f64
                                && py >= b.y as f64
                                && py <= (b.y + b.height) as f64
                            {
                                if let Some(ref action) = b.on_click {
                                    clicked_action = Some(action.clone());
                                    break;
                                }
                            }
                        }

                        if let Some(action) = clicked_action {
                            info!("Triggering Luau on_click: {}", action);
                            if let Err(e) = self.runtime.trigger_click(&action) {
                                error!("Error executing on_click action: {}", e);
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
    fn closed(&mut self, _conn: &Connection, _qh: &QueueHandle<Self>, _layer: &LayerSurface) {
        info!("Layer surface closed by compositor");
        self.running = false;
    }

    fn configure(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _layer: &LayerSurface,
        configure: LayerSurfaceConfigure,
        _serial: u32,
    ) {
        let (new_width, new_height) = configure.new_size;
        if new_width > 0 {
            self.width = new_width;
        }
        if new_height > 0 {
            self.height = new_height;
        }

        self.configured = true;
        info!(
            "Layer surface configure received: width={}, height={}",
            self.width, self.height
        );

        if let Err(e) = self.draw() {
            error!("Failed to render buffer on configure: {}", e);
        }
    }
}
