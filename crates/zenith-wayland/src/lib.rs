//! Zenith Wayland - Protocol bindings and layer-shell integration.

use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState},
    delegate_compositor, delegate_layer, delegate_output, delegate_registry, delegate_shm,
    output::{OutputHandler, OutputState},
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
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
    pub compositor_state: CompositorState,
    pub shm: Shm,
    pub pool: SlotPool,
    pub layer_shell: LayerShell,
    pub bar_surface: Option<LayerSurface>,
    pub width: u32,
    pub height: u32,
    pub configured: bool,
    pub running: bool,
    pub layout_engine: LayoutEngine,
    pub runtime: LuauRuntime,
    pub root_ui: UiNode,
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

        let runtime = LuauRuntime::new()?;
        let root_ui = runtime.eval_ui(DEFAULT_LUAU_SCRIPT)?;
        let layout_engine = LayoutEngine::new();

        let mut app = Self {
            registry_state: RegistryState::new(&globals),
            output_state: OutputState::new(&globals, &qh),
            compositor_state,
            shm,
            pool,
            layer_shell,
            bar_surface: None,
            width: 1920,
            height: 38,
            configured: false,
            running: true,
            layout_engine,
            runtime,
            root_ui,
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
        let computed_boxes = self.layout_engine.compute(&self.root_ui, width as f32, height as f32);

        for b in &computed_boxes {
            let x_start = (b.x as usize).min(width as usize);
            let x_end = ((b.x + b.width) as usize).min(width as usize);
            let y_start = (b.y as usize).min(height as usize);
            let y_end = ((b.y + b.height) as usize).min(height as usize);

            let bg_color = b.background_color.to_argb_u32();
            let border_color = b.border_color.to_argb_u32();
            let has_border = b.border_width > 0.0 && b.border_color.a > 0;

            for y in y_start..y_end {
                for x in x_start..x_end {
                    let is_border_pixel = has_border && (
                        x < x_start + b.border_width as usize
                        || x >= x_end.saturating_sub(b.border_width as usize)
                        || y < y_start + b.border_width as usize
                        || y >= y_end.saturating_sub(b.border_width as usize)
                    );

                    let pixel = if is_border_pixel { border_color } else { bg_color };

                    let idx = (y * width as usize + x) * 4;
                    if idx + 3 < canvas.len() {
                        canvas[idx] = (pixel & 0xFF) as u8;
                        canvas[idx + 1] = ((pixel >> 8) & 0xFF) as u8;
                        canvas[idx + 2] = ((pixel >> 16) & 0xFF) as u8;
                        canvas[idx + 3] = ((pixel >> 24) & 0xFF) as u8;
                    }
                }
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
delegate_registry!(WaylandApp);

impl ProvidesRegistryState for WaylandApp {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    registry_handlers![OutputState];
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
