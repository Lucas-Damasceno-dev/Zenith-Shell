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
}

impl WaylandApp {
    /// Initialize the Wayland connection, registries, and layer shell bar.
    pub fn init() -> Result<(Self, Connection, wayland_client::EventQueue<Self>), Box<dyn std::error::Error>> {
        let conn = Connection::connect_to_env()?;
        let (globals, event_queue) = registry_queue_init(&conn)?;
        let qh = event_queue.handle();

        let compositor_state = CompositorState::bind(&globals, &qh)?;
        let layer_shell = LayerShell::bind(&globals, &qh)?;
        let shm = Shm::bind(&globals, &qh)?;
        let pool = SlotPool::new(1920 * 40 * 4, &shm)?;

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

        // Configure bar anchoring and sizing
        layer_surface.set_anchor(Anchor::TOP | Anchor::LEFT | Anchor::RIGHT);
        layer_surface.set_size(0, self.height);
        layer_surface.set_exclusive_zone(self.height as i32);
        layer_surface.set_keyboard_interactivity(KeyboardInteractivity::None);

        layer_surface.commit();
        info!("Layer surface created for zenith-bar (height={})", self.height);

        self.bar_surface = Some(layer_surface);
        Ok(())
    }

    /// Draw a test modern status bar into the SHM buffer.
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

        // Background color: Material Dark (#14151e, semi-transparent 0xF4)
        let bg_color: u32 = 0xF414151e;
        // Bottom border color: Accent violet (#7c4dff, 0xFF)
        let border_color: u32 = 0xFF7c4dff;
        // Accent pill in the center (x: center - 80 .. center + 80, y: 6 .. height - 6)
        let pill_color: u32 = 0x5532344a;
        let center_x = width / 2;
        let pill_start = center_x.saturating_sub(80);
        let pill_end = center_x.saturating_add(80);

        for y in 0..height {
            for x in 0..width {
                let pixel = if y == height - 1 {
                    border_color
                } else if x >= pill_start && x <= pill_end && y >= 6 && y <= height - 7 {
                    pill_color
                } else {
                    bg_color
                };

                let idx = ((y * width + x) * 4) as usize;
                if idx + 3 < canvas.len() {
                    // ARGB8888 is little-endian: [B, G, R, A]
                    canvas[idx] = (pixel & 0xFF) as u8;
                    canvas[idx + 1] = ((pixel >> 8) & 0xFF) as u8;
                    canvas[idx + 2] = ((pixel >> 16) & 0xFF) as u8;
                    canvas[idx + 3] = ((pixel >> 24) & 0xFF) as u8;
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
