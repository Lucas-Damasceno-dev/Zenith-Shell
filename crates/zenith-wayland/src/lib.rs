//! Zenith Wayland - Protocol bindings and layer-shell integration.
pub mod clipboard;
pub mod egl;
pub mod fractional_scale;
pub mod gestures;
pub mod headless;
pub mod ime;
pub mod idle;
pub mod monitor;
pub mod render;

pub use clipboard::ClipboardManager;
pub use gestures::{GesturePhase, PinchGestureEvent, PointerGesturesManager, SwipeGestureEvent};
pub use headless::HeadlessEngine;
pub use idle::{IdleEvent, IdleManager, IdleNotificationData, IdleStatus};
pub use ime::{ComposeResult, XkbComposeTracker};
pub use monitor::{MonitorLifecycleManager, MonitorState, OutputMode};

use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState},
    data_device_manager::{
        data_device::DataDeviceHandler,
        data_offer::DataOfferHandler,
        data_source::DataSourceHandler,
        DataDeviceManagerState,
    },
    delegate_compositor, delegate_data_device, delegate_keyboard, delegate_layer, delegate_output,
    delegate_pointer, delegate_registry, delegate_seat, delegate_shm, delegate_subcompositor,
    output::{OutputHandler, OutputState},
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    seat::{
        keyboard::{KeyEvent, KeyboardHandler, Keysym, Modifiers},
        pointer::{PointerEvent, PointerEventKind, PointerHandler, BTN_LEFT, BTN_RIGHT},
        Capability, SeatHandler, SeatState,
    },
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
    subcompositor::SubcompositorState,
};
use tracing::{error, info};
use wayland_client::{
    globals::registry_queue_init,
    protocol::{wl_keyboard, wl_output, wl_shm, wl_surface},
    Connection, Dispatch, Proxy, QueueHandle,
};
use wayland_protocols::wp::fractional_scale::v1::client::wp_fractional_scale_manager_v1::WpFractionalScaleManagerV1;
use wayland_protocols::wp::fractional_scale::v1::client::wp_fractional_scale_v1::WpFractionalScaleV1;
use wayland_protocols::wp::viewporter::client::wp_viewport::WpViewport;
use wayland_protocols::wp::viewporter::client::wp_viewporter::WpViewporter;
use wayland_protocols::wp::pointer_gestures::zv1::client::{
    zwp_pointer_gesture_pinch_v1::{self, ZwpPointerGesturePinchV1},
    zwp_pointer_gesture_swipe_v1::{self, ZwpPointerGestureSwipeV1},
    zwp_pointer_gestures_v1::ZwpPointerGesturesV1,
};
use wayland_protocols::wp::cursor_shape::v1::client::{
    wp_cursor_shape_device_v1::{Shape, WpCursorShapeDeviceV1},
    wp_cursor_shape_manager_v1::WpCursorShapeManagerV1,
};
use wayland_protocols::ext::idle_notify::v1::client::{
    ext_idle_notification_v1::{self, ExtIdleNotificationV1},
    ext_idle_notifier_v1::ExtIdleNotifierV1,
};
use wayland_protocols::wp::idle_inhibit::zv1::client::{
    zwp_idle_inhibit_manager_v1::ZwpIdleInhibitManagerV1,
    zwp_idle_inhibitor_v1::ZwpIdleInhibitorV1,
};
use wayland_protocols::ext::session_lock::v1::client::{
    ext_session_lock_manager_v1::ExtSessionLockManagerV1,
    ext_session_lock_v1::{self, ExtSessionLockV1},
    ext_session_lock_surface_v1::{self, ExtSessionLockSurfaceV1},
};

pub struct SessionLockSurface {
    pub output: wl_output::WlOutput,
    pub lock_surface: ExtSessionLockSurfaceV1,
    pub wl_surface: wl_surface::WlSurface,
    pub width: u32,
    pub height: u32,
    pub configured: bool,
    pub computed_boxes: Vec<zenith_layout::ComputedBox>,
    pub canvas_cache: Vec<u8>,
    pub egl_surface: Option<crate::egl::EglSurface>,
    pub damage_ring: crate::render::damage::DamageRing<4>,
    pub frame_callback_pending: bool,
}

#[derive(Default)]
pub struct SessionLockState {
    pub manager: Option<ExtSessionLockManagerV1>,
    pub lock: Option<ExtSessionLockV1>,
    pub surfaces: Vec<SessionLockSurface>,
    pub locked: bool,
}

/// Swizzles a tiny-skia RGBA byte slice into Wayland Argb8888 memory layout (BGRA little-endian).
#[inline]
pub fn copy_rgba_to_argb8888(dst: &mut [u8], src: &[u8]) {
    let len = dst.len().min(src.len());
    let chunks = len / 4;
    for i in 0..chunks {
        let idx = i * 4;
        let r = src[idx];
        let g = src[idx + 1];
        let b = src[idx + 2];
        let a = src[idx + 3];
        dst[idx] = b;
        dst[idx + 1] = g;
        dst[idx + 2] = r;
        dst[idx + 3] = a;
    }
}

pub type FocusedInputState = (String, usize, Option<(usize, usize)>);

impl Dispatch<ExtSessionLockManagerV1, ()> for WaylandApp {
    fn event(
        _state: &mut Self,
        _proxy: &ExtSessionLockManagerV1,
        _event: <ExtSessionLockManagerV1 as Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {}
}

impl Dispatch<ExtSessionLockV1, ()> for WaylandApp {
    fn event(
        state: &mut Self,
        proxy: &ExtSessionLockV1,
        event: ext_session_lock_v1::Event,
        _data: &(),
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
        match event {
            ext_session_lock_v1::Event::Locked => {
                info!("ext-session-lock-v1: session successfully locked by compositor");
                state.session_lock.locked = true;
                let _ = state.draw_lock_surfaces();
            }
            ext_session_lock_v1::Event::Finished => {
                info!("ext-session-lock-v1: session lock finished");
                proxy.destroy();
                state.session_lock.lock = None;
                state.session_lock.locked = false;
                state.session_lock.surfaces.clear();
            }
            _ => {}
        }
    }
}

impl Dispatch<ExtSessionLockSurfaceV1, ()> for WaylandApp {
    fn event(
        state: &mut Self,
        proxy: &ExtSessionLockSurfaceV1,
        event: ext_session_lock_surface_v1::Event,
        _data: &(),
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
        match event {
            ext_session_lock_surface_v1::Event::Configure { serial, width, height } => {
                proxy.ack_configure(serial);
                for surf in &mut state.session_lock.surfaces {
                    if &surf.lock_surface == proxy {
                        surf.width = width;
                        surf.height = height;
                        surf.configured = true;
                        break;
                    }
                }
                let _ = state.draw_lock_surfaces();
            }
            _ => {}
        }
    }
}

impl Dispatch<WpCursorShapeManagerV1, ()> for WaylandApp {
    fn event(
        _state: &mut Self,
        _proxy: &WpCursorShapeManagerV1,
        _event: <WpCursorShapeManagerV1 as Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {}
}

impl Dispatch<WpCursorShapeDeviceV1, ()> for WaylandApp {
    fn event(
        _state: &mut Self,
        _proxy: &WpCursorShapeDeviceV1,
        _event: <WpCursorShapeDeviceV1 as Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {}
}

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
    pub script: String,
    pub surface: LayerSurface,
    pub width: u32,
    pub height: u32,
    pub configured: bool,
    pub root_ui: UiNode,
    pub computed_boxes: Vec<zenith_layout::ComputedBox>,
    pub canvas_cache: Vec<u8>,
    pub egl_surface: Option<crate::egl::EglSurface>,
    pub scale_tracker: Option<crate::fractional_scale::SurfaceScaleTracker>,
    pub spring: Option<zenith_core::SpringAnimation>,
    pub closing: bool,
    pub damage_ring: crate::render::damage::DamageRing<4>,
    pub frame_callback_pending: bool,
}

impl Drop for PopupWindow {
    fn drop(&mut self) {
        self.egl_surface = None;
        self.scale_tracker = None;
    }
}

/// Individual Layer Shell bar window instance attached to a Wayland output.
pub struct BarInstance {
    pub output: Option<wl_output::WlOutput>,
    pub output_name: String,
    pub surface: LayerSurface,
    pub width: u32,
    pub height: u32,
    pub configured: bool,
    pub is_hidden: bool,
    pub computed_boxes: Vec<zenith_layout::ComputedBox>,
    pub canvas_cache: Vec<u8>,
    pub egl_surface: Option<crate::egl::EglSurface>,
    pub scale_tracker: Option<crate::fractional_scale::SurfaceScaleTracker>,
    pub damage_ring: crate::render::damage::DamageRing<4>,
    pub frame_callback_pending: bool,
}

impl Drop for BarInstance {
    fn drop(&mut self) {
        self.egl_surface = None;
        self.scale_tracker = None;
    }
}

/// Main application state for Wayland event handling.
pub struct WaylandApp {
    pub registry_state: RegistryState,
    pub output_state: OutputState,
    pub seat_state: SeatState,
    pub compositor_state: CompositorState,
    pub subcompositor_state: SubcompositorState,
    pub fractional_scale_mgr: crate::fractional_scale::FractionalScaleManager,
    pub shm: Shm,
    pub pool: SlotPool,
    pub egl_context: Option<std::sync::Arc<crate::egl::EglContext>>,
    pub gles_renderer: Option<crate::render::GlesRenderer>,
    pub layer_shell: LayerShell,
    pub bars: Vec<BarInstance>,
    pub bar_surface: Option<LayerSurface>,
    pub popup: Option<PopupWindow>,
    pub dock: Option<PopupWindow>,
    pub dock_autohide: bool,
    pub dock_hovered: bool,
    pub dock_hidden: bool,
    pub dock_last_leave: Option<std::time::Instant>,
    pub bar_autohide: bool,
    pub bar_hovered: bool,
    pub bar_hidden: bool,
    pub bar_last_leave: Option<std::time::Instant>,
    pub pointer: Option<wayland_client::protocol::wl_pointer::WlPointer>,
    pub keyboard: Option<wayland_client::protocol::wl_keyboard::WlKeyboard>,
    pub pointer_pos: (f64, f64),
    pub computed_boxes: Vec<zenith_layout::ComputedBox>,
    pub width: u32,
    pub height: u32,
    pub screen_width: u32,
    pub screen_height: u32,
    pub configured: bool,
    pub running: bool,
    pub layout_engine: LayoutEngine,
    pub runtime: LuauRuntime,
    pub root_ui: UiNode,
    pub bar_script: String,
    pub font_system: cosmic_text::FontSystem,
    pub swash_cache: cosmic_text::SwashCache,
    pub overlay_path_cache: std::collections::HashMap<String, std::path::PathBuf>,
    pub qh: QueueHandle<Self>,
    pub inspect_mode: bool,
    pub modifiers: Modifiers,
    pub pointer_pressed: bool,
    pub clipboard_manager: ClipboardManager,
    pub compose_tracker: XkbComposeTracker,
    pub pam_auth_rx: Option<std::sync::mpsc::Receiver<bool>>,
    pub active_dragging_slider: Option<String>,
    pub monitor_manager: MonitorLifecycleManager,
    pub gestures_manager: PointerGesturesManager,
    pub idle_manager: crate::idle::IdleManager,
    pub cursor_shape_mgr: Option<WpCursorShapeManagerV1>,
    pub cursor_shape_device: Option<WpCursorShapeDeviceV1>,
    pub last_pointer_enter_serial: Option<u32>,
    pub current_cursor_shape: Option<Shape>,
    pub tooltip_hover: Option<(String, std::time::Instant)>,
    pub session_lock: SessionLockState,
    pub needs_redraw_bars: bool,
    pub needs_redraw_popup: bool,
    pub needs_redraw_dock: bool,
    pub dock_magnification: zenith_core::MagnificationModel,
}

impl WaylandApp {
    /// Initialize the Wayland connection, registries, Luau runtime, and layer shell bar.
    pub fn init() -> Result<(Self, Connection, wayland_client::EventQueue<Self>), Box<dyn std::error::Error>> {
        let conn = Connection::connect_to_env()?;
        let (globals, event_queue) = registry_queue_init(&conn)?;
        let qh = event_queue.handle();

        let compositor_state = CompositorState::bind(&globals, &qh)?;
        let subcompositor_state = SubcompositorState::bind(compositor_state.wl_compositor().clone(), &globals, &qh)?;
        let layer_shell = LayerShell::bind(&globals, &qh)?;
        let shm = Shm::bind(&globals, &qh)?;
        let pool = SlotPool::new(1920 * 600 * 4, &shm)?;

        let mut fractional_scale_mgr = crate::fractional_scale::FractionalScaleManager::new();
        if let Ok(mgr) = globals.bind::<WpFractionalScaleManagerV1, _, _>(&qh, 1..=1, ()) {
            fractional_scale_mgr.manager = Some(mgr);
        }
        if let Ok(vp) = globals.bind::<WpViewporter, _, _>(&qh, 1..=1, ()) {
            fractional_scale_mgr.viewporter = Some(vp);
        }

        let seat_state = SeatState::new(&globals, &qh);
        let runtime = LuauRuntime::new()?;
        let root_ui = runtime.eval_ui(DEFAULT_LUAU_SCRIPT)?;
        let layout_engine = LayoutEngine::new();

        let mut gestures_manager = PointerGesturesManager::new();
        if let Ok(gestures) = globals.bind::<ZwpPointerGesturesV1, _, _>(&qh, 1..=3, ()) {
            gestures_manager.gestures_global = Some(gestures);
        }
        let monitor_manager = MonitorLifecycleManager::new();

        let mut idle_manager = crate::idle::IdleManager::new();
        if let Ok(notifier) = globals.bind::<ExtIdleNotifierV1, _, _>(&qh, 1..=1, ()) {
            info!("Bound ext_idle_notifier_v1 protocol for idle power-saving");
            idle_manager.notifier = Some(notifier);
        }
        if let Ok(inhibit_mgr) = globals.bind::<ZwpIdleInhibitManagerV1, _, _>(&qh, 1..=1, ()) {
            info!("Bound zwp_idle_inhibit_manager_v1 protocol for idle inhibition");
            idle_manager.inhibit_manager = Some(inhibit_mgr);
        }
        for seat in seat_state.seats() {
            idle_manager.register_seat(&seat, &qh);
        }

        let mut cursor_shape_mgr = None;
        if let Ok(mgr) = globals.bind::<WpCursorShapeManagerV1, _, _>(&qh, 1..=1, ()) {
            cursor_shape_mgr = Some(mgr);
        }

        let (egl_context, gles_renderer) = unsafe {
            let display_ptr = conn.backend().display_ptr() as *mut std::ffi::c_void;
            match crate::egl::EglContext::new(display_ptr) {
                Ok(ctx) => {
                    let ctx = std::sync::Arc::new(ctx);
                    match crate::render::GlesRenderer::new(ctx.gl.clone()) {
                        Ok(renderer) => {
                            info!("Wayland EGL + OpenGL ES 3.0 hardware acceleration initialized successfully");
                            (Some(ctx), Some(renderer))
                        }
                        Err(e) => {
                            tracing::warn!("Failed to initialize GLES 3.0 renderer, falling back to SHM tiny-skia: {}", e);
                            (None, None)
                        }
                    }
                }
                Err(e) => {
                    tracing::warn!("Failed to initialize Wayland EGL context, falling back to SHM tiny-skia: {}", e);
                    (None, None)
                }
            }
        };

        let mut clipboard_manager = ClipboardManager::new();
        if let Ok(ddm) = DataDeviceManagerState::bind(&globals, &qh) {
            if let Some(first_seat) = seat_state.seats().next() {
                clipboard_manager.data_device = Some(ddm.get_data_device(&qh, &first_seat));
            }
            clipboard_manager.manager_state = Some(ddm);
        }

        let mut session_lock = SessionLockState::default();
        if let Ok(lock_mgr) = globals.bind::<ExtSessionLockManagerV1, _, _>(&qh, 1..=1, ()) {
            info!("Bound ext_session_lock_manager_v1 protocol for secure Wayland session locking");
            session_lock.manager = Some(lock_mgr);
        }

        let mut app = Self {
            registry_state: RegistryState::new(&globals),
            output_state: OutputState::new(&globals, &qh),
            seat_state,
            compositor_state,
            subcompositor_state,
            fractional_scale_mgr,
            shm,
            pool,
            egl_context,
            gles_renderer,
            layer_shell,
            bars: Vec::new(),
            bar_surface: None,
            popup: None,
            dock: None,
            dock_autohide: false,
            dock_hovered: false,
            dock_hidden: false,
            dock_last_leave: None,
            bar_autohide: false,
            bar_hovered: false,
            bar_hidden: false,
            bar_last_leave: None,
            pointer: None,
            keyboard: None,
            pointer_pos: (0.0, 0.0),
            computed_boxes: Vec::new(),
            width: 1920,
            height: 42,
            screen_width: 1366,
            screen_height: 768,
            configured: false,
            running: true,
            layout_engine,
            runtime,
            root_ui,
            bar_script: DEFAULT_LUAU_SCRIPT.to_string(),
            font_system: cosmic_text::FontSystem::new(),
            swash_cache: cosmic_text::SwashCache::new(),
            overlay_path_cache: std::collections::HashMap::new(),
            qh: qh.clone(),
            inspect_mode: false,
            modifiers: Modifiers::default(),
            pointer_pressed: false,
            clipboard_manager,
            compose_tracker: XkbComposeTracker::new(),
            pam_auth_rx: None,
            active_dragging_slider: None,
            monitor_manager,
            gestures_manager,
            idle_manager,
            cursor_shape_mgr,
            cursor_shape_device: None,
            last_pointer_enter_serial: None,
            current_cursor_shape: None,
            tooltip_hover: None,
            session_lock,
            needs_redraw_bars: false,
            needs_redraw_popup: false,
            needs_redraw_dock: false,
            dock_magnification: zenith_core::MagnificationModel::new(zenith_core::MagnificationConfig::default()),
        };

        app.height = app.get_bar_height();
        app.create_bar(&qh)?;

        Ok((app, conn, event_queue))
    }

    /// Returns the target bar height from runtime storage schema (supporting compact mode).
    pub fn get_bar_height(&self) -> u32 {
        let val_to_u32 = |v: &serde_json::Value| -> Option<u32> {
            v.as_u64().map(|n| n as u32).or_else(|| v.as_f64().map(|f| f.round() as u32))
        };
        let is_compact = self.runtime.storage.get("barCompactMode").and_then(|v| v.as_bool()).unwrap_or(false);
        if is_compact {
            self.runtime.storage.get("barCompactHeight").as_ref().and_then(val_to_u32).unwrap_or(36)
        } else {
            self.runtime.storage.get("barHeight").as_ref().and_then(val_to_u32).unwrap_or(42)
        }
    }

    /// Returns the target dock height from runtime storage schema.
    pub fn get_dock_height(&self) -> u32 {
        let val_to_u32 = |v: &serde_json::Value| -> Option<u32> {
            v.as_u64().map(|n| n as u32).or_else(|| v.as_f64().map(|f| f.round() as u32))
        };
        self.runtime.storage.get("dockHeight").as_ref().and_then(val_to_u32).unwrap_or(58)
    }

    /// Securely locks the Wayland desktop session via `ext-session-lock-v1` if supported,
    /// falling back to exclusive overlay popup.
    pub fn lock_session(&mut self) {
        self.clipboard_manager.set_locked(true);
        self.runtime.set_focused_input(None);
        self.destroy_popup_immediately();

        if let Some(ref mgr) = self.session_lock.manager {
            if self.session_lock.lock.is_none() {
                info!("Requesting compositor session lock via ext-session-lock-v1");
                let lock = mgr.lock(&self.qh, ());
                self.session_lock.surfaces.clear();
                for out in self.output_state.outputs() {
                    let wl_surface = self.compositor_state.create_surface(&self.qh);
                    let lock_surf = lock.get_lock_surface(&wl_surface, &out, &self.qh, ());
                    self.session_lock.surfaces.push(SessionLockSurface {
                        output: out,
                        lock_surface: lock_surf,
                        wl_surface,
                        width: 0,
                        height: 0,
                        configured: false,
                        computed_boxes: Vec::new(),
                        canvas_cache: Vec::new(),
                        egl_surface: None,
                        damage_ring: crate::render::damage::DamageRing::new(),
                        frame_callback_pending: false,
                    });
                }
                self.session_lock.lock = Some(lock);
                return;
            }
        }
        let _ = self.open_popup("LockScreen");
    }

    /// Unlocks the session, destroying compositor lock and dismissing lockscreen.
    pub fn unlock_session(&mut self) {
        self.clipboard_manager.set_locked(false);
        if let Some(lock) = self.session_lock.lock.take() {
            info!("Unlocking and destroying ext-session-lock-v1 session");
            lock.unlock_and_destroy();
            self.session_lock.locked = false;
            self.session_lock.surfaces.clear();
        }
        let _ = zenith_services::HyprlandService::dispatch("submap", "reset");
        self.close_popup();
    }

    /// Creates a layer surface bar for a specific Wayland output (or default if None).
    pub fn create_bar_for_output(
        &mut self,
        output: Option<&wl_output::WlOutput>,
        output_name: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let autohide = self.runtime.storage.get("barAutoHide").and_then(|v| v.as_bool()).unwrap_or_else(Self::read_bar_autohide_setting);
        self.bar_autohide = autohide;
        self.height = self.get_bar_height();
        self.bar_hovered = false;
        self.bar_hidden = false;
        self.bar_last_leave = None;

        let wl_surface = self.compositor_state.create_surface(&self.qh);
        let layer_surface = self.layer_shell.create_layer_surface(
            &self.qh,
            wl_surface,
            Layer::Top,
            Some("zenith-bar"),
            output,
        );

        layer_surface.set_anchor(Anchor::TOP | Anchor::LEFT | Anchor::RIGHT);
        layer_surface.set_size(0, self.height);
        layer_surface.set_exclusive_zone(self.height as i32);
        layer_surface.set_keyboard_interactivity(KeyboardInteractivity::None);

        // Bar spans the full screen width (edge-to-edge status bar)
        layer_surface.set_margin(0, 0, 0, 0);

        layer_surface.commit();
        info!("Layer surface created for zenith-bar on output '{}' (height={}, autohide={})", output_name, self.height, autohide);

        let scale_tracker = Some(self.fractional_scale_mgr.attach_surface(&self.qh, layer_surface.wl_surface()));

        self.bars.push(BarInstance {
            output: output.cloned(),
            output_name: output_name.to_string(),
            surface: layer_surface,
            width: self.width,
            height: self.height,
            configured: false,
            is_hidden: false,
            computed_boxes: Vec::new(),
            canvas_cache: Vec::new(),
            egl_surface: None,
            scale_tracker,
            damage_ring: crate::render::damage::DamageRing::new(),
            frame_callback_pending: false,
        });

        let _ = self.update_bar_visibility();

        Ok(())
    }

    /// Creates the top status bar layer surface.
    pub fn create_bar(&mut self, _qh: &QueueHandle<Self>) -> Result<(), Box<dyn std::error::Error>> {
        self.create_bar_for_output(None, "default")
    }

    /// Dynamically syncs margins with current Hyprland gaps_out setting across all active bars.
    pub fn sync_gaps(&mut self) {
        // Status bar stays edge-to-edge (no side margins)
        for bar in &self.bars {
            bar.surface.set_margin(0, 0, 0, 0);
            bar.surface.commit();
        }
        if let Some(ref bar) = self.bar_surface {
            bar.set_margin(0, 0, 0, 0);
            bar.commit();
        }
    }

    /// Polls completed background workers and triggers Promise resolution callbacks.
    pub fn poll_async_tasks(&mut self) -> Result<usize, Box<dyn std::error::Error>> {
        let mut count = self.runtime.poll_async_events()?;
        if let Some(ref rx) = self.pam_auth_rx {
            if let Ok(success) = rx.try_recv() {
                self.pam_auth_rx = None;
                if success {
                    self.runtime.record_lock_success();
                    self.runtime.clear_lock_password();
                    self.runtime.set_search_query("");
                    self.unlock_session();
                } else {
                    self.runtime.record_lock_failure();
                    self.runtime.clear_lock_password();
                    self.runtime.set_search_query("");
                    if self.session_lock.locked {
                        let _ = self.draw_lock_surfaces();
                    } else if let Some(ref p) = self.popup {
                        let id = p.id.clone();
                        let _ = self.reload_popup(&id);
                    }
                }
                count += 1;
            }
        }
        Ok(count)
    }

    /// Dispatches an asynchronous PAM authentication check in a background worker thread.
    pub fn start_pam_auth(&mut self, password: &str) {
        let pwd = password.to_string();
        let (tx, rx) = std::sync::mpsc::channel();
        self.pam_auth_rx = Some(rx);
        std::thread::spawn(move || {
            let res = verify_pam_password_sync(&pwd);
            let _ = tx.send(res);
        });
    }

    /// Evaluates arbitrary Luau code via the embedded runtime (used by REPL).
    pub fn eval_code(&self, code: &str) -> Result<String, Box<dyn std::error::Error>> {
        let res = self.runtime.eval_code(code)?;
        Ok(res)
    }

    /// Toggles or sets visual inspection mode (displaying Taffy bounding boxes & telemetry).
    pub fn set_inspect_mode(&mut self, enabled: bool) {
        self.inspect_mode = enabled;
        if let Some(ref mut gles) = self.gles_renderer {
            gles.inspect_mode = enabled;
        }
    }

    /// Inhibit idle when media is playing or fullscreen presentation is active.
    pub fn inhibit_idle(&mut self, reason: &str) -> bool {
        let surface = if let Some(bar) = self.bars.first() {
            Some(bar.surface.wl_surface().clone())
        } else if let Some(ref popup) = self.popup {
            Some(popup.surface.wl_surface().clone())
        } else {
            self.dock.as_ref().map(|dock| dock.surface.wl_surface().clone())
        };

        if let Some(surf) = surface {
            self.idle_manager.inhibit_idle(&surf, &self.qh, reason)
        } else {
            self.idle_manager.active_inhibitors.insert(reason.to_string());
            false
        }
    }

    /// Release idle inhibition for a given reason tag.
    pub fn uninhibit_idle(&mut self, reason: &str) -> bool {
        self.idle_manager.uninhibit_idle(reason)
    }

    /// Check if session is currently idle.
    #[inline]
    pub fn is_idle(&self) -> bool {
        self.idle_manager.is_idle()
    }

    /// Check if idle inhibition is active.
    #[inline]
    pub fn is_idle_inhibited(&self) -> bool {
        self.idle_manager.is_inhibited()
    }

    /// Checks if animations or periodic rendering should be paused to conserve CPU/GPU energy.
    #[inline]
    pub fn should_pause_animations(&self) -> bool {
        self.idle_manager.should_pause_animations() || self.monitor_manager.should_pause_rendering()
    }

    /// Requests an optimized redraw of the active bar, popup and dock surfaces via VSync frame callbacks.
    pub fn request_redraw(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if self.should_pause_animations() {
            return Ok(());
        }

        if self.session_lock.locked {
            let mut need_draw = false;
            for surf in &mut self.session_lock.surfaces {
                if !surf.frame_callback_pending {
                    surf.frame_callback_pending = true;
                    need_draw = true;
                }
            }
            if need_draw {
                let _ = self.draw_lock_surfaces();
            }
            return Ok(());
        }

        let mut bars_need_draw = false;
        for bar in &mut self.bars {
            if !bar.configured {
                bar.frame_callback_pending = false;
                continue;
            }
            if !bar.frame_callback_pending {
                bar.frame_callback_pending = true;
                bars_need_draw = true;
            } else {
                self.needs_redraw_bars = true;
            }
        }
        if bars_need_draw {
            self.needs_redraw_bars = false;
            let redrawn = self.update_bar_visibility().unwrap_or(false);
            if !redrawn {
                let _ = self.draw();
            }
        }

        if let Some(ref mut popup) = self.popup {
            if popup.configured {
                if !popup.frame_callback_pending {
                    popup.frame_callback_pending = true;
                    self.needs_redraw_popup = false;
                    if !popup.closing {
                        let id = popup.id.clone();
                        let _ = self.reload_popup(&id);
                    } else {
                        let _ = self.draw_popup();
                    }
                } else {
                    self.needs_redraw_popup = true;
                }
            }
        }

        if let Some(ref mut dock) = self.dock {
            if dock.configured {
                if !dock.frame_callback_pending {
                    dock.frame_callback_pending = true;
                    self.needs_redraw_dock = false;
                    let _ = self.update_dock_visibility();
                    if !self.dock_hidden {
                        let _ = self.reload_dock();
                    } else {
                        let _ = self.draw_dock();
                    }
                } else {
                    self.needs_redraw_dock = true;
                }
            }
        }

        Ok(())
    }

    /// Forces an immediate synchronous redraw of bars, popup and dock (bypassing VSync frame callbacks).
    pub fn redraw_now(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if self.should_pause_animations() {
            return Ok(());
        }
        let _ = self.update_bar_visibility();
        self.draw()?;
        if let Some(ref p) = self.popup {
            let id = p.id.clone();
            let _ = self.reload_popup(&id);
            let _ = self.draw_popup();
        }
        if self.dock.is_some() {
            let _ = self.update_dock_visibility();
            if !self.dock_hidden {
                let _ = self.reload_dock();
            }
        }
        self.needs_redraw_bars = false;
        self.needs_redraw_popup = false;
        self.needs_redraw_dock = false;
        Ok(())
    }

    /// Sets the device cursor shape via wp_cursor_shape_v1.
    pub fn set_cursor_shape(&mut self, shape: Shape) {
        if self.current_cursor_shape == Some(shape) {
            return;
        }
        if let (Some(ref dev), Some(serial)) = (&self.cursor_shape_device, self.last_pointer_enter_serial) {
            dev.set_shape(serial, shape);
            self.current_cursor_shape = Some(shape);
        }
    }

    /// Checks if a pending tooltip hover has exceeded 400ms and activates the tooltip box.
    pub fn check_tooltip_timer(&mut self) -> bool {
        let mut activated = false;
        if let Some((ref key, start)) = self.tooltip_hover {
            if start.elapsed() >= std::time::Duration::from_millis(400) {
                if let Some(ref mut popup) = self.popup {
                    for b in &mut popup.computed_boxes {
                        if b.tooltip.is_some() && key.starts_with("popup:") && key.contains(&format!("@{:.0},{:.0}", b.x, b.y)) && !b.tooltip_active {
                            b.tooltip_active = true;
                            activated = true;
                        }
                    }
                }
                if let Some(ref mut dock) = self.dock {
                    for b in &mut dock.computed_boxes {
                        if b.tooltip.is_some() && key.starts_with("dock:") && key.contains(&format!("@{:.0},{:.0}", b.x, b.y)) && !b.tooltip_active {
                            b.tooltip_active = true;
                            activated = true;
                        }
                    }
                }
                for bar in &mut self.bars {
                    for b in &mut bar.computed_boxes {
                        if b.tooltip.is_some() && key.starts_with(&format!("bar:{}", bar.output_name)) && key.contains(&format!("@{:.0},{:.0}", b.x, b.y)) && !b.tooltip_active {
                            b.tooltip_active = true;
                            activated = true;
                        }
                    }
                }
            }
        }
        if activated {
            let _ = self.request_redraw();
        }
        activated
    }

    /// Reloads Luau active component trees after file modifications.
    pub fn reload_active_trees(&mut self) {
        self.runtime.clear_module_cache();

        // Reload bars
        for bar in &mut self.bars {
            bar.computed_boxes.clear();
        }

        // Reload open popup if active
        if let Some(ref popup) = self.popup {
            let popup_id = popup.id.clone();
            if let Some(cached_path) = self.overlay_path_cache.get(&popup_id) {
                if let Ok(new_content) = std::fs::read_to_string(cached_path) {
                    if let Some(ref mut p) = self.popup {
                        p.script = new_content;
                    }
                }
            }
            let _ = self.reload_popup(&popup_id);
        }

        // Reload dock if active
        if self.dock.is_some() {
            if let Some(cached_path) = self.overlay_path_cache.get("dock") {
                if let Ok(new_content) = std::fs::read_to_string(cached_path) {
                    if let Some(ref mut d) = self.dock {
                        d.script = new_content;
                    }
                }
            }
            let _ = self.reload_dock();
        }

        let _ = self.request_redraw();
    }

    /// Re-evaluates Luau script and updates the UI tree on hot-reload.
    /// Preserves the last rendered frame if syntax or evaluation error occurs (Error Boundary).
    pub fn reload_script(&mut self, script: &str) -> Result<(), Box<dyn std::error::Error>> {
        if let Err(e) = self.runtime.eval_ui(script) {
            eprintln!("[zenith] Hot-reload compilation error, preserving last frame: {e}");
            return Ok(());
        }
        self.bar_script = script.to_string();
        self.reload_active_trees();
        Ok(())
    }

    /// Resolves and caches the file content for an overlay script.
    pub fn resolve_overlay_script(&mut self, id: &str, script_name: &str) -> Result<String, String> {
        if let Some(cached_path) = self.overlay_path_cache.get(id) {
            if let Ok(content) = std::fs::read_to_string(cached_path) {
                return Ok(content);
            }
        }

        let mut candidates = vec![
            format!("config/zenith/overlays/{}.luau", script_name),
            format!("config/zenith/overlays/{}.lua", script_name),
            format!("config/zenith/overlays/{}Popup.luau", script_name),
            format!("config/zenith/overlays/{}.luau", id),
            format!("config/zenith/{}.luau", script_name.to_lowercase()),
            format!("../../config/zenith/overlays/{}.luau", script_name),
            format!("../../config/zenith/overlays/{}.luau", id),
        ];

        if let Ok(config_dir) = std::env::var("ZENITH_CONFIG_DIR") {
            candidates.push(format!("{}/overlays/{}.luau", config_dir, script_name));
            candidates.push(format!("{}/overlays/{}.luau", config_dir, id));
        }
        if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
            candidates.push(format!("{}/zenith/overlays/{}.luau", xdg, script_name));
            candidates.push(format!("{}/zenith/overlays/{}.luau", xdg, id));
        }

        for c in &candidates {
            let p = std::path::PathBuf::from(c);
            if let Ok(content) = std::fs::read_to_string(&p) {
                self.overlay_path_cache.insert(id.to_string(), p);
                return Ok(content);
            }
        }

        if let Ok(home) = std::env::var("HOME") {
            let home_candidates = [
                format!("{}/.config/zenith/overlays/{}.luau", home, script_name),
                format!("{}/.config/zenith/overlays/{}.luau", home, id),
                format!("{}/.config/zenith/{}.luau", home, script_name.to_lowercase()),
            ];
            for c in &home_candidates {
                let p = std::path::PathBuf::from(c);
                if let Ok(content) = std::fs::read_to_string(&p) {
                    self.overlay_path_cache.insert(id.to_string(), p);
                    return Ok(content);
                }
            }
        }

        Err(format!("Cannot find overlay script for popup '{}'", id))
    }

    /// Opens or switches to a popup window by overlay id.
    pub fn open_popup(&mut self, id: &str) -> Result<(), Box<dyn std::error::Error>> {
        if id.eq_ignore_ascii_case("dock") {
            return self.open_dock();
        }

        self.destroy_popup_immediately();

        if id.eq_ignore_ascii_case("audio") || id.eq_ignore_ascii_case("audiopopup") {
            zenith_services::AudioService::invalidate_sinks_cache();
            zenith_services::invalidate_audio_cache();
        }

        let (script_name, anchor, mut width, mut height, margin_top, margin_right, margin_bottom, margin_left) = match id.to_lowercase().as_str() {
            "dock" => ("Dock", Anchor::BOTTOM, 640, self.get_dock_height(), 0, 0, 12, 0),
            "island" | "dynamicisland" => ("DynamicIsland", Anchor::TOP, 380, 52, 8, 0, 0, 0),
            "launcher" => ("Launcher", Anchor::TOP, 680, 520, 16, 0, 0, 0),
            "media" | "mediapopup" => ("MediaPopup", Anchor::TOP, 360, 360, 48, 0, 0, 0),
            "notifications" | "notificationcenter" => ("NotificationCenter", Anchor::TOP | Anchor::RIGHT, 420, 600, 48, 14, 0, 0),
            "audio" | "audiopopup" => ("AudioPopup", Anchor::TOP | Anchor::RIGHT, 360, 480, 48, 14, 0, 0),
            "network" | "networkpopup" => ("NetworkPopup", Anchor::TOP | Anchor::RIGHT, 380, 500, 48, 14, 0, 0),
            "bluetooth" | "bluetoothpopup" => ("BluetoothPopup", Anchor::TOP | Anchor::RIGHT, 380, 460, 48, 14, 0, 0),
            "battery" | "batterypopup" => ("BatteryPopup", Anchor::TOP | Anchor::RIGHT, 360, 400, 48, 14, 0, 0),
            "calendar" | "calendarpopup" => ("CalendarPopup", Anchor::TOP, 360, 360, 48, 0, 0, 0),
            "power" | "powermenu" => ("PowerMenu", Anchor::TOP | Anchor::RIGHT, 300, 260, 48, 14, 0, 0),
            "osd" => ("OSD", Anchor::TOP, 280, 110, 60, 0, 0, 0),
            "controlcenter" => ("ControlCenter", Anchor::TOP | Anchor::RIGHT, 380, 700, 48, 14, 0, 0),
            "canvas" | "desktopcanvas" => ("DesktopCanvas", Anchor::TOP | Anchor::LEFT, 380, 340, 16, 0, 0, 24),
            "settings" | "settingsmenu" => ("Settings", Anchor::TOP, 1040, 660, 48, 0, 0, 0),
            "lock" | "lockscreen" => ("LockScreen", Anchor::TOP | Anchor::BOTTOM | Anchor::LEFT | Anchor::RIGHT, 0, 0, 0, 0, 0, 0),
            "expose" | "exposepopup" => ("ExposePopup", Anchor::TOP, 780, 480, 48, 0, 0, 0),
            "cheatsheet" => ("CheatSheet", Anchor::TOP, 460, 560, 48, 0, 0, 0),
            "weather" | "weatherpopup" => ("WeatherPopup", Anchor::TOP | Anchor::RIGHT, 360, 420, 48, 14, 0, 0),
            "pomodoro" | "pomodoropopup" => ("PomodoroPopup", Anchor::TOP | Anchor::RIGHT, 340, 380, 48, 14, 0, 0),
            "clipboard" | "clipboardpopup" => ("ClipboardPopup", Anchor::TOP | Anchor::RIGHT, 380, 500, 48, 14, 0, 0),
            "systemmonitor" | "systemmonitorpopup" => ("SystemMonitorPopup", Anchor::TOP | Anchor::RIGHT, 420, 520, 48, 14, 0, 0),
            "usb" | "usbpopup" => ("USBPopup", Anchor::TOP | Anchor::RIGHT, 340, 340, 48, 14, 0, 0),
            _ => (id, Anchor::TOP | Anchor::RIGHT, 340, 380, 48, 14, 0, 0),
        };

        let content = self.resolve_overlay_script(id, script_name)?;

        self.runtime.set_search_query("");
        self.runtime.set_selected_index(1);

        let is_lock = id.eq_ignore_ascii_case("lock") || id.eq_ignore_ascii_case("lockscreen");
        if is_lock {
            width = self.screen_width.max(1366);
            height = self.screen_height.max(768);
            self.runtime.set_current_output_geometry("default", width, height);
        }

        let root_ui = self.runtime.eval_ui_for_tree(&format!("popup_{}", id), &content)?;

        // Apply dynamic window metadata if defined in the Luau script
        let (mut anchor, mut margin_top, mut margin_right, mut margin_bottom, mut margin_left) = (anchor, margin_top, margin_right, margin_bottom, margin_left);
        let mut layer_level = Layer::Overlay;
        let mut kb_mode = if is_lock {
            KeyboardInteractivity::Exclusive
        } else if id.eq_ignore_ascii_case("dock") || id.eq_ignore_ascii_case("desktopcanvas") {
            KeyboardInteractivity::None
        } else {
            KeyboardInteractivity::OnDemand
        };
        let mut exclusive = if id.eq_ignore_ascii_case("dock") { self.get_dock_height() as i32 } else { 0 };

        if let Some(meta) = root_ui.window_meta() {
            let mut dynamic_anchor = Anchor::empty();
            if meta.anchor_top { dynamic_anchor |= Anchor::TOP; }
            if meta.anchor_bottom { dynamic_anchor |= Anchor::BOTTOM; }
            if meta.anchor_left { dynamic_anchor |= Anchor::LEFT; }
            if meta.anchor_right { dynamic_anchor |= Anchor::RIGHT; }
            if !dynamic_anchor.is_empty() {
                anchor = dynamic_anchor;
            }

            margin_top = meta.margin_top;
            margin_right = meta.margin_right;
            margin_bottom = meta.margin_bottom;
            margin_left = meta.margin_left;

            if let Some(w) = meta.width { width = w; }
            if let Some(h) = meta.height { height = h; }

            if let Some(ref l) = meta.layer {
                layer_level = match l.to_lowercase().as_str() {
                    "top" => Layer::Top,
                    "bottom" => Layer::Bottom,
                    "background" => Layer::Background,
                    _ => Layer::Overlay,
                };
            }

            if let Some(ez) = meta.exclusive_zone {
                exclusive = ez;
            }

            if let Some(ref km) = meta.keyboard_mode {
                kb_mode = match km.to_lowercase().as_str() {
                    "exclusive" => KeyboardInteractivity::Exclusive,
                    "none" => KeyboardInteractivity::None,
                    _ => KeyboardInteractivity::OnDemand,
                };
            } else if id.eq_ignore_ascii_case("launcher")
                || id.eq_ignore_ascii_case("controlcenter")
                || id.eq_ignore_ascii_case("settings")
                || id.eq_ignore_ascii_case("clipboard")
            {
                kb_mode = KeyboardInteractivity::OnDemand;
            }
        }

        // Ensure layer surface is large enough to contain root window + drop shadows
        if !is_lock {
            match &root_ui {
                UiNode::Box { style, .. } | UiNode::Window { style, .. } => {
                    if let Some(dim) = style.width {
                        if let zenith_layout::ExpandedDimension::Length(w) = dim.expand() {
                            width = width.max(w.ceil() as u32 + 24);
                        }
                    }
                    if let Some(dim) = style.height {
                        if let zenith_layout::ExpandedDimension::Length(h) = dim.expand() {
                            height = height.max(h.ceil() as u32 + 30);
                        }
                    }
                }
                _ => {}
            }
        }

        if is_lock {
            self.runtime.set_search_query("");
        }

        let wl_surface = self.compositor_state.create_surface(&self.qh);
        let layer_surface = self.layer_shell.create_layer_surface(
            &self.qh,
            wl_surface,
            layer_level,
            Some(&format!("zenith-popup-{}", id)),
            None,
        );

        layer_surface.set_anchor(anchor);
        layer_surface.set_margin(margin_top, margin_right, margin_bottom, margin_left);
        layer_surface.set_size(width, height);
        layer_surface.set_exclusive_zone(exclusive);
        layer_surface.set_keyboard_interactivity(kb_mode);
        layer_surface.commit();

        layer_surface.wl_surface().frame(&self.qh, layer_surface.wl_surface().clone());
        layer_surface.commit();

        info!("Created popup layer surface for '{}' ({}x{})", id, width, height);

        let spring = if is_lock {
            None
        } else {
            let mut anim = zenith_core::SpringAnimation::new(0.0, 1.0);
            anim.config.stiffness = 580.0;
            anim.config.damping = 36.0;
            anim.config.precision = 0.005;
            Some(anim)
        };

        let scale_tracker = Some(self.fractional_scale_mgr.attach_surface(&self.qh, layer_surface.wl_surface()));

        self.popup = Some(PopupWindow {
            id: id.to_string(),
            script: content,
            surface: layer_surface,
            width,
            height,
            configured: false,
            root_ui,
            computed_boxes: Vec::new(),
            canvas_cache: Vec::new(),
            egl_surface: None,
            scale_tracker,
            spring,
            closing: false,
            damage_ring: crate::render::damage::DamageRing::new(),
            frame_callback_pending: false,
        });

        Ok(())
    }

    /// Re-evaluates open popup Luau script with current reactive state and redraws.
    pub fn reload_popup(&mut self, id: &str) -> Result<(), Box<dyn std::error::Error>> {
        let script = match self.popup.as_ref() {
            Some(p) => p.script.clone(),
            None => return Ok(()),
        };

        let root_ui = self.runtime.eval_ui_for_tree(&format!("popup_{}", id), &script)?;
        if let Some(ref mut popup) = self.popup {
            popup.root_ui = root_ui;
            popup.computed_boxes.clear();
            let _ = self.draw_popup();
        }

        Ok(())
    }

    /// Immediately destroys the active popup window without animation.
    pub fn destroy_popup_immediately(&mut self) {
        if let Some(popup) = self.popup.take() {
            if popup.id.eq_ignore_ascii_case("lock") || popup.id.eq_ignore_ascii_case("lockscreen") {
                let _ = zenith_services::HyprlandService::dispatch("submap", "reset");
            }
            info!("Destroyed popup immediately: {}", popup.id);
        }
    }

    /// Closes the currently active popup window with smooth spring exit physics.
    pub fn close_popup(&mut self) {
        if let Some(ref mut popup) = self.popup {
            if popup.id.eq_ignore_ascii_case("lock") || popup.id.eq_ignore_ascii_case("lockscreen") {
                let _ = zenith_services::HyprlandService::dispatch("submap", "reset");
            }
            if popup.closing {
                return;
            }
            popup.closing = true;
            if let Some(ref mut anim) = popup.spring {
                anim.target = 0.0;
                anim.config.stiffness = 700.0;
                anim.config.damping = 40.0;
                anim.config.precision = 0.01;
            } else {
                let mut anim = zenith_core::SpringAnimation::new(1.0, 0.0);
                anim.config.stiffness = 700.0;
                anim.config.damping = 40.0;
                anim.config.precision = 0.01;
                popup.spring = Some(anim);
            }
            popup.surface.wl_surface().frame(&self.qh, popup.surface.wl_surface().clone());
            let _ = self.draw_popup();
        }
    }

    /// Reads bar auto-hide preference from zenith config.json.
    pub fn read_bar_autohide_setting() -> bool {
        let home_cfg = std::env::var("HOME").ok().map(|h| std::path::PathBuf::from(h).join(".config/zenith/config.json"));
        let mut config_paths = Vec::new();
        if let Some(p) = home_cfg {
            config_paths.push(p);
        }
        config_paths.push(std::path::PathBuf::from("config/zenith/config.json"));
        config_paths.push(std::path::PathBuf::from("../../config/zenith/config.json"));

        config_paths
            .iter()
            .find_map(|p| {
                std::fs::read_to_string(p)
                    .ok()
                    .and_then(|c| serde_json::from_str::<serde_json::Value>(&c).ok())
                    .and_then(|v| {
                        let b = v.get("bar")?;
                        b.get("autoHide").or_else(|| v.get("quick")?.get("barAutoHide")).and_then(|val| val.as_bool())
                    })
            })
            .unwrap_or(true)
    }

    /// Evaluates whether any window on a specific output collides with the top bar area.
    pub fn has_bar_window_collision_for_output(&self, output_name: &str) -> bool {
        let monitors = zenith_services::HyprlandService::monitors();
        let mon = monitors.iter().find(|m| m.name == output_name || output_name.is_empty() || output_name == "default");
        let (mon_x, mon_y, mon_w) = if let Some(m) = mon {
            (m.x, m.y, m.width as i32)
        } else {
            (0, 0, self.screen_width as i32)
        };

        let ws = zenith_services::HyprlandService::workspaces_snapshot();
        let active_ws = ws
            .workspaces
            .iter()
            .find(|w| (w.monitor == output_name || output_name == "default") && w.active)
            .map(|w| w.id)
            .unwrap_or(ws.active);
        let clients = zenith_services::HyprlandService::clients_snapshot();
        let bar_height = self.get_bar_height() as i32;
        let gaps = zenith_services::HyprlandService::gaps_out() as i32;
        // Compensa o deslocamento causado pelo exclusive_zone quando a barra está visível
        let active_exclusive = if self.bar_hidden { 0 } else { bar_height };

        for c in clients {
            if c.hidden || c.workspace_id < 0 || c.workspace_name.starts_with("special") {
                continue;
            }
            if c.workspace_id != active_ws {
                continue;
            }
            if c.fullscreen {
                return true;
            }
            let win_top = c.at.1 - mon_y;
            let win_bottom = win_top + c.size.1;
            let win_left = c.at.0 - mon_x;
            let win_right = win_left + c.size.0;
            let overlap_x = win_left < mon_w && win_right > 0;

            if !overlap_x {
                continue;
            }

            // Janelas em modo tile (!c.floating) no workspace ativo sempre ocupam o topo quando a barra recolhe
            if !c.floating {
                return true;
            }

            let bar_bottom = bar_height + active_exclusive + gaps + 16;
            if win_top < bar_bottom && win_bottom > 0 {
                return true;
            }
        }
        false
    }

    /// Evaluates whether any window on the active workspace collides with the top bar area.
    pub fn has_bar_window_collision(&self) -> bool {
        if self.bars.is_empty() {
            return self.has_bar_window_collision_for_output("");
        }
        self.bars.iter().any(|b| self.has_bar_window_collision_for_output(&b.output_name))
    }

    /// Returns the auto-hide delay duration from storage or default 450ms.
    pub fn get_autohide_delay(&self) -> std::time::Duration {
        let ms = self.runtime.storage.get("barAutoHideDelayMs")
            .and_then(|v| v.as_u64())
            .unwrap_or(450);
        std::time::Duration::from_millis(ms)
    }

    /// Evaluates whether the top bar should automatically hide based on overlapping windows.
    pub fn should_bar_hide(&self) -> bool {
        if !self.bar_autohide {
            return false;
        }
        if self.bar_hovered {
            return false;
        }
        if let Some(ref p) = self.popup {
            if !p.id.eq_ignore_ascii_case("desktopcanvas") && !p.id.eq_ignore_ascii_case("canvas") && !p.id.eq_ignore_ascii_case("osd") {
                return false;
            }
        }
        if let Some(leave_time) = self.bar_last_leave {
            if leave_time.elapsed() < self.get_autohide_delay() {
                return false;
            }
        }
        self.has_bar_window_collision()
    }

    /// Synchronizes internal auto-hide state with StorageEngine.
    pub fn sync_autohide_settings(&mut self) {
        if let Some(val) = self.runtime.storage.get("barAutoHide").and_then(|v| v.as_bool()) {
            self.bar_autohide = val;
        }
        if let Some(val) = self.runtime.storage.get("dockAutoHide").and_then(|v| v.as_bool()) {
            self.dock_autohide = val;
        }
    }

    /// Updates the bar surface geometry and visibility based on intelligent auto-hide and dynamic window resizing.
    pub fn update_bar_visibility(&mut self) -> Result<bool, Box<dyn std::error::Error>> {
        self.sync_autohide_settings();
        let target_bar_h = self.get_bar_height();
        self.height = target_bar_h;
        let should_hide = self.should_bar_hide();
        let autohide = self.bar_autohide;
        let is_hidden = self.bar_hidden;

        if !autohide {
            self.bar_last_leave = None;
            if is_hidden || self.bars.iter().any(|b| b.height != target_bar_h) {
                self.bar_hidden = false;
                for bar in &mut self.bars {
                    bar.is_hidden = false;
                    bar.height = target_bar_h;
                    bar.computed_boxes.clear();
                    bar.damage_ring.reset();
                    bar.surface.set_size(0, target_bar_h);
                    bar.surface.set_exclusive_zone(target_bar_h as i32);
                    bar.surface.wl_surface().set_input_region(None);
                    bar.surface.commit();
                }
                self.draw()?;
                return Ok(true);
            }
            return Ok(false);
        }

        if should_hide && !is_hidden {
            self.bar_hidden = true;
            for bar in &mut self.bars {
                bar.is_hidden = true;
                bar.height = 12;
                bar.computed_boxes.clear();
                bar.damage_ring.reset();
                bar.surface.set_size(0, 12);
                bar.surface.set_exclusive_zone(0);

                let region = self.compositor_state.wl_compositor().create_region(&self.qh, ());
                region.add(0, 0, bar.width.max(self.screen_width).max(1920) as i32, 3);
                bar.surface.wl_surface().set_input_region(Some(&region));
                region.destroy();
                bar.surface.commit();
            }
            self.draw()?;
            return Ok(true);
        } else if !should_hide && is_hidden {
            self.bar_hidden = false;
            for bar in &mut self.bars {
                bar.is_hidden = false;
                bar.height = target_bar_h;
                bar.computed_boxes.clear();
                bar.damage_ring.reset();
                bar.surface.set_size(0, target_bar_h);
                // Reserva exclusive_zone dinamicamente para redimensionar as janelas tile ao revelar a barra
                bar.surface.set_exclusive_zone(target_bar_h as i32);
                bar.surface.wl_surface().set_input_region(None);
                bar.surface.commit();
            }
            self.draw()?;
            return Ok(true);
        } else if !should_hide && !is_hidden && self.bars.iter().any(|b| b.height != target_bar_h) {
            for bar in &mut self.bars {
                bar.height = target_bar_h;
                bar.computed_boxes.clear();
                bar.damage_ring.reset();
                bar.surface.set_size(0, target_bar_h);
                bar.surface.set_exclusive_zone(target_bar_h as i32);
                bar.surface.wl_surface().set_input_region(None);
                bar.surface.commit();
            }
            self.draw()?;
            return Ok(true);
        }

        Ok(false)
    }

    /// Reads dock auto-hide preference from zenith config.json.
    pub fn read_dock_autohide_setting() -> bool {
        let home_cfg = std::env::var("HOME").ok().map(|h| std::path::PathBuf::from(h).join(".config/zenith/config.json"));
        let mut config_paths = Vec::new();
        if let Some(p) = home_cfg {
            config_paths.push(p);
        }
        config_paths.push(std::path::PathBuf::from("config/zenith/config.json"));
        config_paths.push(std::path::PathBuf::from("../../config/zenith/config.json"));

        config_paths
            .iter()
            .find_map(|p| {
                std::fs::read_to_string(p)
                    .ok()
                    .and_then(|c| serde_json::from_str::<serde_json::Value>(&c).ok())
                    .and_then(|v| {
                        let d = v.get("dock")?;
                        d.get("autoHide").or_else(|| d.get("hoverToReveal")).or_else(|| v.get("quick")?.get("dockAutoHide")).and_then(|b| b.as_bool())
                    })
            })
            .unwrap_or(true)
    }

    /// Evaluates whether any window on the active workspace collides with the bottom dock area.
    pub fn has_dock_window_collision(&self) -> bool {
        let monitors = zenith_services::HyprlandService::monitors();
        let mon = monitors.iter().find(|m| m.focused).or_else(|| monitors.first());
        let (mon_x, mon_y, mon_w, mon_h) = if let Some(m) = mon {
            (m.x, m.y, m.width as i32, m.height as i32)
        } else {
            (0, 0, self.screen_width as i32, self.screen_height as i32)
        };

        let ws = zenith_services::HyprlandService::workspaces_snapshot();
        let active_ws = mon
            .and_then(|m| ws.workspaces.iter().find(|w| w.monitor == m.name && w.active).map(|w| w.id))
            .unwrap_or(ws.active);
        let clients = zenith_services::HyprlandService::clients_snapshot();

        let dock_h = self.get_dock_height() as i32;
        let gaps = zenith_services::HyprlandService::gaps_out() as i32;
        // Compensa o deslocamento causado pelo exclusive_zone quando a dock está visível
        let active_exclusive = if self.dock_hidden { 0 } else { dock_h };
        let dock_top = mon_h.saturating_sub(dock_h + active_exclusive + gaps + 16);

        for c in clients {
            if c.hidden || c.workspace_id < 0 || c.workspace_name.starts_with("special") {
                continue;
            }
            if c.workspace_id != active_ws {
                continue;
            }
            if c.fullscreen {
                return true;
            }
            let win_top = c.at.1 - mon_y;
            let win_bottom = win_top + c.size.1;
            let win_left = c.at.0 - mon_x;
            let win_right = win_left + c.size.0;
            let overlap_x = win_left < mon_w && win_right > 0;

            if !overlap_x {
                continue;
            }

            // Janelas em modo tile (!c.floating) no workspace ativo sempre ocupam a base quando a dock recolhe
            if !c.floating {
                return true;
            }

            if win_bottom >= dock_top && win_top < mon_h {
                return true;
            }
        }
        false
    }

    /// Evaluates whether the dock should automatically hide based on overlapping windows.
    pub fn should_dock_hide(&self) -> bool {
        if !self.dock_autohide {
            return false;
        }
        if self.dock_hovered {
            return false;
        }
        if let Some(leave_time) = self.dock_last_leave {
            if leave_time.elapsed() < self.get_autohide_delay() {
                return false;
            }
        }
        self.has_dock_window_collision()
    }

    /// Updates the dock surface geometry and visibility based on intelligent auto-hide and dynamic window resizing.
    pub fn update_dock_visibility(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let dock_enabled = self.runtime.storage.get("dockEnabled").and_then(|v| v.as_bool()).unwrap_or(true);
        if !dock_enabled {
            if self.dock.is_some() {
                self.destroy_dock();
            }
            return Ok(());
        } else if self.dock.is_none() {
            return self.open_dock();
        }

        self.sync_autohide_settings();
        let target_dock_h = self.get_dock_height();
        let should_hide = self.should_dock_hide();
        let autohide = self.dock_autohide;
        let is_hidden = self.dock_hidden;

        if !autohide {
            self.dock_last_leave = None;
            if is_hidden || self.dock.as_ref().is_some_and(|d| d.height != target_dock_h) {
                self.dock_hidden = false;
                if let Some(ref mut dock) = self.dock {
                    dock.height = target_dock_h;
                    dock.computed_boxes.clear();
                    dock.damage_ring.reset();
                    dock.surface.set_size(0, target_dock_h);
                    dock.surface.set_margin(0, 0, 0, 0);
                    dock.surface.set_exclusive_zone(target_dock_h as i32);
                    dock.surface.wl_surface().set_input_region(None);
                    dock.surface.commit();
                }
                self.reload_dock()?;
            }
            return Ok(());
        }

        if should_hide && !is_hidden {
            self.dock_hidden = true;
            if let Some(ref mut dock) = self.dock {
                dock.height = 16;
                dock.computed_boxes.clear();
                dock.damage_ring.reset();
                dock.surface.set_size(0, 16);
                dock.surface.set_margin(0, 0, 0, 0);
                dock.surface.set_exclusive_zone(0);

                let region = self.compositor_state.wl_compositor().create_region(&self.qh, ());
                region.add(0, 13, dock.width.max(self.screen_width).max(1920) as i32, 3);
                dock.surface.wl_surface().set_input_region(Some(&region));
                region.destroy();
                dock.surface.commit();
            }
            self.draw_dock()?;
        } else if !should_hide && is_hidden {
            self.dock_hidden = false;
            if let Some(ref mut dock) = self.dock {
                dock.height = target_dock_h;
                dock.computed_boxes.clear();
                dock.damage_ring.reset();
                dock.surface.set_size(0, target_dock_h);
                dock.surface.set_margin(0, 0, 0, 0);
                // Reserva exclusive_zone dinamicamente para redimensionar as janelas tile ao revelar a dock
                dock.surface.set_exclusive_zone(target_dock_h as i32);
                dock.surface.wl_surface().set_input_region(None);
                dock.surface.commit();
            }
            self.reload_dock()?;
        } else if !should_hide && !is_hidden && self.dock.as_ref().is_some_and(|d| d.height != target_dock_h) {
            if let Some(ref mut dock) = self.dock {
                dock.height = target_dock_h;
                dock.computed_boxes.clear();
                dock.damage_ring.reset();
                dock.surface.set_size(0, target_dock_h);
                dock.surface.set_margin(0, 0, 0, 0);
                dock.surface.set_exclusive_zone(target_dock_h as i32);
                dock.surface.wl_surface().set_input_region(None);
                dock.surface.commit();
            }
            self.reload_dock()?;
        }

        Ok(())
    }

    /// Opens the persistent dock layer surface.
    pub fn open_dock(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if self.dock.is_some() {
            return Ok(());
        }

        let mut candidates = vec![
            "config/zenith/overlays/Dock.luau".to_string(),
            "config/zenith/overlays/Dock.lua".to_string(),
            "../../config/zenith/overlays/Dock.luau".to_string(),
        ];
        if let Ok(config_dir) = std::env::var("ZENITH_CONFIG_DIR") {
            candidates.push(format!("{}/overlays/Dock.luau", config_dir));
        }
        if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
            candidates.push(format!("{}/zenith/overlays/Dock.luau", xdg));
        }
        if let Ok(home) = std::env::var("HOME") {
            candidates.push(format!("{}/.config/zenith/overlays/Dock.luau", home));
        }

        let mut script_content = None;
        for c in &candidates {
            if let Ok(content) = std::fs::read_to_string(c) {
                script_content = Some(content);
                break;
            }
        }

        let content = script_content.ok_or("Cannot find Dock.luau overlay script")?;
        let root_ui = self.runtime.eval_ui_for_tree("dock", &content)?;

        let width = 0u32;
        let height = self.get_dock_height();
        let margin_bottom = 0i32;

        let autohide = self.runtime.storage.get("dockAutoHide")
            .and_then(|v| v.as_bool())
            .unwrap_or_else(Self::read_dock_autohide_setting);
        self.dock_autohide = autohide;
        self.dock_hovered = false;
        self.dock_hidden = false;
        self.dock_last_leave = None;

        let wl_surface = self.compositor_state.create_surface(&self.qh);
        let layer_surface = self.layer_shell.create_layer_surface(
            &self.qh,
            wl_surface,
            Layer::Top,
            Some("zenith-dock"),
            None,
        );

        layer_surface.set_anchor(Anchor::BOTTOM | Anchor::LEFT | Anchor::RIGHT);
        layer_surface.set_margin(0, 0, margin_bottom, 0);
        layer_surface.set_size(width, height);
        layer_surface.set_exclusive_zone(height as i32);
        layer_surface.set_keyboard_interactivity(KeyboardInteractivity::None);
        layer_surface.commit();

        layer_surface.wl_surface().frame(&self.qh, layer_surface.wl_surface().clone());
        layer_surface.commit();

        info!("Created dock layer surface ({}x{}, autohide={})", width, height, autohide);

        let scale_tracker = Some(self.fractional_scale_mgr.attach_surface(&self.qh, layer_surface.wl_surface()));

        self.dock = Some(PopupWindow {
            id: "dock".to_string(),
            script: content,
            surface: layer_surface,
            width,
            height,
            configured: false,
            root_ui,
            computed_boxes: Vec::new(),
            canvas_cache: Vec::new(),
            egl_surface: None,
            scale_tracker,
            spring: None,
            closing: false,
            damage_ring: crate::render::damage::DamageRing::new(),
            frame_callback_pending: false,
        });

        let _ = self.update_dock_visibility();

        Ok(())
    }

    /// Scales computed layout boxes by fractional/integer surface scale factor.
    pub fn scale_computed_boxes<'a>(
        boxes: &'a [zenith_layout::ComputedBox],
        scale_factor: f32,
    ) -> std::borrow::Cow<'a, [zenith_layout::ComputedBox]> {
        if (scale_factor - 1.0).abs() > 0.001 {
            std::borrow::Cow::Owned(boxes.iter().map(|b| {
                let mut scaled = b.clone();
                scaled.x *= scale_factor;
                scaled.y *= scale_factor;
                scaled.width *= scale_factor;
                scaled.height *= scale_factor;
                scaled.border_width *= scale_factor;
                scaled.border_radius *= scale_factor;
                if let Some((ref txt, color, size)) = scaled.text {
                    scaled.text = Some((txt.clone(), color, size * scale_factor));
                }
                if let Some(ref mut input) = scaled.text_input {
                    input.font_size *= scale_factor;
                }
                if let Some(ref mut shadow) = scaled.shadow {
                    shadow.blur *= scale_factor;
                    shadow.offset_x *= scale_factor;
                    shadow.offset_y *= scale_factor;
                }
                if let Some([cx, cy, cw, ch]) = scaled.clip_rect {
                    scaled.clip_rect = Some([cx * scale_factor, cy * scale_factor, cw * scale_factor, ch * scale_factor]);
                }
                scaled
            }).collect())
        } else {
            std::borrow::Cow::Borrowed(boxes)
        }
    }

    /// Unified rendering pipeline for all Wayland surfaces (Bars, Dock, Popups, Lockscreen).
    /// Enforces correct EGL make_current ordering before buffer age query, and swizzles
    /// RGBA to Little-Endian Argb8888 (BGRA) for SHM fallback.
    #[allow(clippy::too_many_arguments)]
    pub fn render_surface_pipeline_helper(
        egl_context: &Option<std::sync::Arc<crate::egl::EglContext>>,
        gles_renderer: &mut Option<crate::render::gles::GlesRenderer>,
        font_system: &mut cosmic_text::FontSystem,
        swash_cache: &mut cosmic_text::SwashCache,
        pool: &mut smithay_client_toolkit::shm::slot::SlotPool,
        qh: &QueueHandle<WaylandApp>,
        wl_surface: &wl_surface::WlSurface,
        egl_surface: &mut Option<crate::egl::EglSurface>,
        damage_ring: &mut crate::render::damage::DamageRing<4>,
        canvas_cache: &mut Vec<u8>,
        render_boxes: &[zenith_layout::ComputedBox],
        damage: Option<(i32, i32, i32, i32)>,
        scale_factor: f32,
        width: u32,
        height: u32,
        scale_or_spring: f32,
        attach_frame_callback: bool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let phys_w = ((width as f32) * scale_factor).round().max(1.0) as u32;
        let phys_h = ((height as f32) * scale_factor).round().max(1.0) as u32;

        if let Some(ref egl_ctx) = egl_context {
            if let Some(ref mut egl_surf) = egl_surface {
                if egl_surf.width() != phys_w || egl_surf.height() != phys_h {
                    egl_surf.resize(phys_w, phys_h);
                    damage_ring.reset();
                }
            } else if let Ok(egl_surf) = egl_ctx.create_surface(wl_surface, phys_w, phys_h) {
                *egl_surface = Some(egl_surf);
                damage_ring.reset();
            }
        }

        let p_damage = damage.map(|(dx, dy, dw, dh)| {
            let p_dx = ((dx as f32) * scale_factor).round() as i32;
            let p_dy = ((dy as f32) * scale_factor).round() as i32;
            let p_dw = ((dw as f32) * scale_factor).round() as i32;
            let p_dh = ((dh as f32) * scale_factor).round() as i32;
            crate::render::DamageRect::new(p_dx, p_dy, p_dw, p_dh)
        });

        let mut drawn_egl = false;
        let mut dmg_rect = None;
        let mut p_dx = 0;
        let mut p_dy = 0;
        let mut p_dw = phys_w as i32;
        let mut p_dh = phys_h as i32;

        if let (Some(ref egl_ctx), Some(ref mut gles_rend)) = (egl_context, gles_renderer) {
            if let Some(ref egl_surf) = egl_surface {
                // Critical: egl_ctx.make_current MUST be called BEFORE querying EGL_BUFFER_AGE_EXT
                if egl_ctx.make_current(egl_surf).is_ok() {
                    let buffer_age = egl_surf.query_buffer_age();
                    let calculated_dmg = damage_ring.rotate_damage_with_age(p_damage, buffer_age, phys_w as i32, phys_h as i32);
                    dmg_rect = calculated_dmg;
                    let (dx, dy, dw, dh) = calculated_dmg
                        .map(|r| (r.x, r.y, r.width, r.height))
                        .unwrap_or((0, 0, phys_w as i32, phys_h as i32));
                    p_dx = dx;
                    p_dy = dy;
                    p_dw = dw;
                    p_dh = dh;

                    if gles_rend.render_boxes(
                        render_boxes,
                        phys_w,
                        phys_h,
                        scale_or_spring,
                        font_system,
                        swash_cache,
                        calculated_dmg,
                        scale_factor,
                    ).is_ok() {
                        let _ = egl_surf.swap_buffers_with_damage(calculated_dmg);
                        if attach_frame_callback {
                            wl_surface.frame(qh, wl_surface.clone());
                        }
                        wl_surface.damage_buffer(p_dx, p_dy, p_dw, p_dh);
                        wl_surface.commit();
                        drawn_egl = true;
                    }
                }
            }
        }

        if !drawn_egl {
            if dmg_rect.is_none() {
                dmg_rect = damage_ring.rotate_damage_with_age(p_damage, None, phys_w as i32, phys_h as i32);
                let (dx, dy, dw, dh) = dmg_rect
                    .map(|r| (r.x, r.y, r.width, r.height))
                    .unwrap_or((0, 0, phys_w as i32, phys_h as i32));
                p_dx = dx;
                p_dy = dy;
                p_dw = dw;
                p_dh = dh;
            }

            let shm_target_len = (phys_w * phys_h * 4) as usize;
            let shm_stride = phys_w * 4;
            if canvas_cache.len() != shm_target_len {
                *canvas_cache = vec![0u8; shm_target_len];
            } else if damage.is_some() {
                let cx1 = p_dx.max(0) as usize;
                let cy1 = p_dy.max(0) as usize;
                let cx2 = (p_dx + p_dw).max(0).min(phys_w as i32) as usize;
                let cy2 = (p_dy + p_dh).max(0).min(phys_h as i32) as usize;
                for row_y in cy1..cy2 {
                    let row_start = (row_y * phys_w as usize + cx1) * 4;
                    let row_end = (row_y * phys_w as usize + cx2) * 4;
                    if row_end <= canvas_cache.len() {
                        canvas_cache[row_start..row_end].fill(0);
                    }
                }
            } else {
                canvas_cache.fill(0);
            }

            Self::render_boxes_to_canvas(
                canvas_cache,
                render_boxes,
                phys_w,
                phys_h,
                scale_or_spring,
                font_system,
                swash_cache,
                dmg_rect,
                scale_factor,
            )?;

            let (buffer, canvas) = pool.create_buffer(
                phys_w as i32,
                phys_h as i32,
                shm_stride as i32,
                wl_shm::Format::Argb8888,
            )?;

            copy_rgba_to_argb8888(canvas, canvas_cache);

            buffer.attach_to(wl_surface)?;
            if attach_frame_callback {
                wl_surface.frame(qh, wl_surface.clone());
            }
            wl_surface.damage_buffer(p_dx, p_dy, p_dw, p_dh);
            wl_surface.commit();
        }

        Ok(())
    }

    #[allow(clippy::too_many_arguments)]
    pub fn render_surface_pipeline(
        &mut self,
        wl_surface: &wl_surface::WlSurface,
        egl_surface: &mut Option<crate::egl::EglSurface>,
        damage_ring: &mut crate::render::damage::DamageRing<4>,
        canvas_cache: &mut Vec<u8>,
        render_boxes: &[zenith_layout::ComputedBox],
        damage: Option<(i32, i32, i32, i32)>,
        scale_factor: f32,
        width: u32,
        height: u32,
        scale_or_spring: f32,
        attach_frame_callback: bool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        Self::render_surface_pipeline_helper(
            &self.egl_context,
            &mut self.gles_renderer,
            &mut self.font_system,
            &mut self.swash_cache,
            &mut self.pool,
            &self.qh,
            wl_surface,
            egl_surface,
            damage_ring,
            canvas_cache,
            render_boxes,
            damage,
            scale_factor,
            width,
            height,
            scale_or_spring,
            attach_frame_callback,
        )
    }

    /// Renders the LockScreen UI tree directly to all active ExtSessionLockSurfaceV1 Wayland surfaces.
    pub fn draw_lock_surfaces(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if !self.session_lock.locked {
            return Ok(());
        }

        let script = self.resolve_overlay_script("lockscreen", "LockScreen").unwrap_or_else(|_| {
            r##"
            return Zenith.Box {
                direction = "column",
                width = "100%",
                height = "100%",
                align_items = "center",
                justify_content = "center",
                background = "#101216",
                children = {
                    Zenith.Text { text = "Zenith Desktop Locked", font_size = 28, color = "#FFFFFF" },
                    Zenith.TextInput { id = "password", placeholder = "Enter password to unlock...", active = true }
                }
            }
            "##.to_string()
        });

        for i in 0..self.session_lock.surfaces.len() {
            let surf = &self.session_lock.surfaces[i];
            if !surf.configured || surf.width == 0 || surf.height == 0 {
                continue;
            }
            let width = surf.width;
            let height = surf.height;

            self.runtime.set_current_output_geometry("lock", width, height);
            let root_ui = match self.runtime.eval_ui_for_tree("lockscreen", &script) {
                Ok(ui) => ui,
                Err(e) => {
                    tracing::error!("Failed to evaluate LockScreen UI: {}", e);
                    continue;
                }
            };

            let new_boxes = self.layout_engine.compute(&root_ui, width as f32, height as f32);
            let surf = &mut self.session_lock.surfaces[i];
            let damage = Self::compute_damage_rect(&surf.computed_boxes, &new_boxes, width, height);
            surf.computed_boxes = new_boxes;

            let render_boxes = std::borrow::Cow::Borrowed(&surf.computed_boxes);
            let wl_surf = surf.wl_surface.clone();
            let egl_surf = &mut surf.egl_surface;
            let damage_ring = &mut surf.damage_ring;
            let canvas_cache = &mut surf.canvas_cache;
            let attach_frame = surf.frame_callback_pending;

            Self::render_surface_pipeline_helper(
                &self.egl_context,
                &mut self.gles_renderer,
                &mut self.font_system,
                &mut self.swash_cache,
                &mut self.pool,
                &self.qh,
                &wl_surf,
                egl_surf,
                damage_ring,
                canvas_cache,
                &render_boxes,
                damage,
                1.0,
                width,
                height,
                1.0,
                attach_frame,
            )?;
        }
        Ok(())
    }

    /// Renders the persistent dock layer surface into SHM buffer.
    pub fn draw_dock(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if self.monitor_manager.should_pause_rendering() {
            return Ok(());
        }
        let is_hidden = self.dock_hidden;
        let dock = match self.dock.as_mut() {
            Some(d) if d.configured => d,
            Some(d) => {
                d.frame_callback_pending = false;
                return Ok(());
            }
            _ => return Ok(()),
        };

        let width = dock.width.max(1);
        let height = dock.height.max(1);

        if is_hidden {
            let pill_w = (width as f32 * 0.18).clamp(80.0, 240.0);
            let pill_h = 2.0f32;
            let pill_x = (width as f32 - pill_w) * 0.5;
            let pill_y = (height as f32 - pill_h).max(0.0);
            let new_boxes = vec![zenith_layout::ComputedBox {
                x: pill_x,
                y: pill_y,
                width: pill_w,
                height: pill_h,
                background_color: zenith_layout::Color::rgba(130, 170, 255, 120),
                border_radius: 1.0,
                ..Default::default()
            }];
            if dock.computed_boxes == new_boxes {
                dock.frame_callback_pending = false;
                return Ok(());
            }
            dock.computed_boxes = new_boxes;

            let scale_factor = dock.scale_tracker.as_ref().map(|t| t.scale_factor).unwrap_or(1.0);
            if let Some(ref tracker) = dock.scale_tracker {
                tracker.apply_destination(width as i32, height as i32);
            }

            let wl_surf = dock.surface.wl_surface().clone();
            let egl_surf = &mut dock.egl_surface;
            let damage_ring = &mut dock.damage_ring;
            let canvas_cache = &mut dock.canvas_cache;
            let attach_frame = dock.frame_callback_pending;

            Self::render_surface_pipeline_helper(
                &self.egl_context,
                &mut self.gles_renderer,
                &mut self.font_system,
                &mut self.swash_cache,
                &mut self.pool,
                &self.qh,
                &wl_surf,
                egl_surf,
                damage_ring,
                canvas_cache,
                &dock.computed_boxes,
                Some((0, 0, width as i32, height as i32)),
                scale_factor,
                width,
                height,
                1.0,
                attach_frame,
            )?;

            return Ok(());
        }

        let mut new_boxes = self.layout_engine.compute(&dock.root_ui, width as f32, height as f32);
        let mag_enabled = self.runtime.storage.get("dockMagnification").and_then(|v| v.as_bool()).unwrap_or(true);
        let pointer_x = if self.dock_hovered && mag_enabled {
            Some(self.pointer_pos.0 as f32)
        } else {
            None
        };
        zenith_layout::apply_dock_magnification(&mut new_boxes, &self.dock_magnification, pointer_x, true);
        let damage = Self::compute_damage_rect(&dock.computed_boxes, &new_boxes, width, height);

        if damage.is_none() && !dock.computed_boxes.is_empty() {
            dock.frame_callback_pending = false;
            return Ok(());
        }

        dock.computed_boxes = new_boxes;

        let scale_factor = dock.scale_tracker.as_ref().map(|t| t.scale_factor).unwrap_or(1.0);
        if let Some(ref tracker) = dock.scale_tracker {
            tracker.apply_destination(width as i32, height as i32);
        }

        let wl_surf = dock.surface.wl_surface().clone();
        let egl_surf = &mut dock.egl_surface;
        let damage_ring = &mut dock.damage_ring;
        let canvas_cache = &mut dock.canvas_cache;
        let attach_frame = dock.frame_callback_pending;

        Self::render_surface_pipeline_helper(
            &self.egl_context,
            &mut self.gles_renderer,
            &mut self.font_system,
            &mut self.swash_cache,
            &mut self.pool,
            &self.qh,
            &wl_surf,
            egl_surf,
            damage_ring,
            canvas_cache,
            &dock.computed_boxes,
            damage,
            scale_factor,
            width,
            height,
            1.0,
            attach_frame,
        )?;

        Ok(())
    }

    /// Re-evaluates Dock.luau with latest state (e.g. clients) and redraws.
    pub fn reload_dock(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let script = match self.dock.as_ref() {
            Some(d) => d.script.clone(),
            None => return Ok(()),
        };

        let root_ui = self.runtime.eval_ui_for_tree("dock", &script)?;
        if let Some(ref mut dock) = self.dock {
            dock.root_ui = root_ui;
        }
        self.draw_dock()?;
        Ok(())
    }

    /// Destroys the persistent dock layer surface.
    pub fn destroy_dock(&mut self) {
        if let Some(_dock) = self.dock.take() {
            info!("Destroyed persistent dock layer surface");
        }
    }

    /// Toggles a popup window by id.
    pub fn toggle_popup(&mut self, id: &str) {
        if id.eq_ignore_ascii_case("dock") {
            if self.dock.is_some() {
                self.destroy_dock();
            } else {
                let _ = self.open_dock();
            }
            return;
        }

        if let Some(ref mut popup) = self.popup {
            if popup.id.eq_ignore_ascii_case(id) {
                if popup.closing {
                    popup.closing = false;
                    if let Some(ref mut anim) = popup.spring {
                        anim.target = 1.0;
                    }
                    popup.surface.wl_surface().frame(&self.qh, popup.surface.wl_surface().clone());
                    let _ = self.draw_popup();
                } else {
                    self.close_popup();
                }
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
        if let Some(id) = action.strip_prefix("popup:toggle:") {
            self.toggle_popup(id);
        } else if action == "popup:close" || action == "close" {
            self.close_popup();
        } else if action == "lock" || action == "system:lock" {
            self.lock_session();
        } else if action == "lock:unlock" {
            if !self.runtime.is_locked_out() {
                let pwd = self.runtime.take_lock_password();
                self.start_pam_auth(&pwd);
            }
        } else if action == "bar:toggle_autohide" {
            let cur = self.runtime.storage.get("barAutoHide").and_then(|v| v.as_bool()).unwrap_or_else(Self::read_bar_autohide_setting);
            let next = !cur;
            let _ = self.runtime.storage.set("barAutoHide", serde_json::Value::Bool(next));
            self.bar_autohide = next;
            let _ = self.update_bar_visibility();
            let _ = self.request_redraw();
        } else if action == "dock:toggle_autohide" {
            let cur = self.runtime.storage.get("dockAutoHide").and_then(|v| v.as_bool()).unwrap_or_else(Self::read_dock_autohide_setting);
            let next = !cur;
            let _ = self.runtime.storage.set("dockAutoHide", serde_json::Value::Bool(next));
            self.dock_autohide = next;
            let _ = self.update_dock_visibility();
            let _ = self.request_redraw();
        } else if action == "bar:toggle_compact" {
            let cur = self.runtime.storage.get("barCompactMode").and_then(|v| v.as_bool()).unwrap_or(false);
            let _ = self.runtime.storage.set("barCompactMode", serde_json::Value::Bool(!cur));
            let _ = self.update_bar_visibility();
            let _ = self.request_redraw();
        } else if let Some(id) = action.strip_prefix("popup:open:") {
            let _ = self.open_popup(id);
        } else if action == "search:clear" {
            self.runtime.set_search_query("");
            self.runtime.set_selected_index(1);
            if let Some(ref p) = self.popup {
                let id = p.id.clone();
                let _ = self.reload_popup(&id);
                let _ = self.draw_popup();
            }
        } else if let Some(reason) = action.strip_prefix("idle:inhibit:") {
            let _ = self.inhibit_idle(reason);
        } else if action == "idle:inhibit" {
            let _ = self.inhibit_idle("manual");
        } else if let Some(reason) = action.strip_prefix("idle:uninhibit:") {
            let _ = self.uninhibit_idle(reason);
        } else if action == "idle:uninhibit" {
            let _ = self.uninhibit_idle("manual");
        } else if let Some(reason) = action.strip_prefix("idle:toggle_inhibit:") {
            if self.idle_manager.active_inhibitors.contains(reason) {
                let _ = self.uninhibit_idle(reason);
            } else {
                let _ = self.inhibit_idle(reason);
            }
        } else {
            // Dismiss popup on outside actions, except audio tweaks, media controls, dock, settings, and notification actions
            if self.popup.is_some()
                && self.popup.as_ref().map(|p| !p.id.eq_ignore_ascii_case("lock") && !p.id.eq_ignore_ascii_case("lockscreen") && p.id != "dock" && !p.id.eq_ignore_ascii_case("settings")).unwrap_or(true)
                && !action.starts_with("cmd:wpctl")
                && !action.starts_with("media:")
                && !action.starts_with("notification:")
                && !action.starts_with("audio:")
                && !action.starts_with("settings:")
                && !action.starts_with("storage:")
                && !action.starts_with("idle:")
                && !action.starts_with("window:toggle_minimize:")
                && !action.starts_with("expose:")
                && !action.starts_with("bluetooth:")
                && !action.starts_with("wifi:")
                && !action.starts_with("power:profile:")
                && !action.starts_with("brightness:")
                && !action.starts_with("dispatch:closewindow:")
            {
                self.close_popup();
            }
            if let Err(e) = self.runtime.trigger_click(action) {
                error!("Error executing on_click action: {}", e);
            }
            if self.runtime.check_close_requested() {
                self.close_popup();
            }
            self.sync_autohide_settings();
            let _ = self.update_bar_visibility();
            let _ = self.update_dock_visibility();
            if let Some(ref p) = self.popup {
                let id = p.id.clone();
                let _ = self.reload_popup(&id);
            }
            if self.dock.is_some() {
                let _ = self.reload_dock();
            }
            let _ = self.draw();
        }
    }

    /// Draw the computed Luau layout into the SHM or EGL buffer for all active bar outputs.
    pub fn draw(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if self.monitor_manager.should_pause_rendering() {
            return Ok(());
        }
        let is_hidden = self.bar_hidden;
        for bar in &mut self.bars {
            if !bar.configured {
                bar.frame_callback_pending = false;
                continue;
            }

            let width = bar.width.max(1);
            let height = bar.height.max(1);

            if is_hidden {
                let line_w = (width as f32 * 0.25).clamp(80.0, 300.0);
                let line_h = 2.0f32;
                let line_x = (width as f32 - line_w) * 0.5;
                let new_boxes = vec![zenith_layout::ComputedBox {
                    x: line_x,
                    y: 0.0,
                    width: line_w,
                    height: line_h,
                    background_color: zenith_layout::Color::rgba(130, 170, 255, 100),
                    border_radius: 1.0,
                    ..Default::default()
                }];
                if bar.computed_boxes == new_boxes {
                    bar.frame_callback_pending = false;
                    continue;
                }
                bar.computed_boxes = new_boxes;

                let scale_factor = bar.scale_tracker.as_ref().map(|t| t.scale_factor).unwrap_or(1.0);
                if let Some(ref tracker) = bar.scale_tracker {
                    tracker.apply_destination(width as i32, height as i32);
                }
                let wl_surf = bar.surface.wl_surface().clone();
                let egl_surf = &mut bar.egl_surface;
                let damage_ring = &mut bar.damage_ring;
                let canvas_cache = &mut bar.canvas_cache;
                let attach_frame = bar.frame_callback_pending;

                Self::render_surface_pipeline_helper(
                    &self.egl_context,
                    &mut self.gles_renderer,
                    &mut self.font_system,
                    &mut self.swash_cache,
                    &mut self.pool,
                    &self.qh,
                    &wl_surf,
                    egl_surf,
                    damage_ring,
                    canvas_cache,
                    &bar.computed_boxes,
                    Some((0, 0, width as i32, height as i32)),
                    scale_factor,
                    width,
                    height,
                    1.0,
                    attach_frame,
                )?;
                continue;
            }

            if let Some(m) = self.monitor_manager.monitors.get(&bar.output_name) {
                if !m.dpms_awake {
                    bar.frame_callback_pending = false;
                    continue;
                }
            }

            // Contextualize output and resolution geometry for responsive layout
            let (screen_w, screen_h) = if let Some(m) = self.monitor_manager.monitors.get(&bar.output_name) {
                (m.logical_size.0.max(1), m.logical_size.1.max(1))
            } else {
                (self.screen_width.max(1), self.screen_height.max(1))
            };
            self.runtime.set_current_output_geometry(&bar.output_name, screen_w, screen_h);

            let bar_ui = match self.runtime.eval_ui_for_tree("bar", &self.bar_script) {
                Ok(ui) => ui,
                Err(e) => {
                    tracing::error!("BAR EVAL ERROR: {}", e);
                    self.root_ui.clone()
                }
            };

            // Compute Taffy layout on the Luau tree
            let new_boxes = self.layout_engine.compute(&bar_ui, width as f32, height as f32);
            let damage = Self::compute_damage_rect(&bar.computed_boxes, &new_boxes, width, height);

            // Frame-skip optimization: if nothing changed in the computed boxes, avoid redrawing and committing!
            if damage.is_none() && !bar.computed_boxes.is_empty() {
                bar.frame_callback_pending = false;
                continue;
            }

            bar.computed_boxes = new_boxes;

            let scale_factor = bar.scale_tracker.as_ref().map(|t| t.scale_factor).unwrap_or(1.0);
            if let Some(ref tracker) = bar.scale_tracker {
                tracker.apply_destination(width as i32, height as i32);
            }

            let wl_surf = bar.surface.wl_surface().clone();
            let egl_surf = &mut bar.egl_surface;
            let damage_ring = &mut bar.damage_ring;
            let canvas_cache = &mut bar.canvas_cache;
            let attach_frame = bar.frame_callback_pending;

            Self::render_surface_pipeline_helper(
                &self.egl_context,
                &mut self.gles_renderer,
                &mut self.font_system,
                &mut self.swash_cache,
                &mut self.pool,
                &self.qh,
                &wl_surf,
                egl_surf,
                damage_ring,
                canvas_cache,
                &bar.computed_boxes,
                damage,
                scale_factor,
                width,
                height,
                1.0,
                attach_frame,
            )?;
        }

        Ok(())
    }

    /// Draw the computed Luau layout for the open popup into the SHM or EGL buffer.
    pub fn draw_popup(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if self.monitor_manager.should_pause_rendering() {
            return Ok(());
        }
        let popup = match self.popup.as_mut() {
            Some(p) if p.configured => p,
            Some(p) => {
                p.frame_callback_pending = false;
                return Ok(());
            }
            _ => return Ok(()),
        };

        let width = popup.width.max(1);
        let height = popup.height.max(1);

        let (spring_val, is_spring_animating) = if let Some(ref s) = popup.spring {
            (s.current, !s.is_settled())
        } else {
            (1.0, false)
        };
        let is_scroll_animating = !self.gestures_manager.is_scroll_settled();
        let is_animating = is_spring_animating || is_scroll_animating;

        if popup.closing && (spring_val <= 0.04 || !is_animating) {
            self.popup = None;
            return Ok(());
        }

        let new_boxes = if is_spring_animating && !is_scroll_animating && !popup.computed_boxes.is_empty() {
            popup.computed_boxes.clone()
        } else {
            self.layout_engine.compute(&popup.root_ui, width as f32, height as f32)
        };
        let damage = if is_animating {
            Some((0, 0, width as i32, height as i32))
        } else {
            Self::compute_damage_rect(&popup.computed_boxes, &new_boxes, width, height)
        };

        // Frame-skip optimization: skip popup redraw if unchanged and not animating
        if !is_animating && damage.is_none() && !popup.computed_boxes.is_empty() {
            popup.frame_callback_pending = false;
            return Ok(());
        }

        popup.computed_boxes = new_boxes;

        let scale_factor = popup.scale_tracker.as_ref().map(|t| t.scale_factor).unwrap_or(1.0);
        if let Some(ref tracker) = popup.scale_tracker {
            tracker.apply_destination(width as i32, height as i32);
        }

        let wl_surf = popup.surface.wl_surface().clone();
        let egl_surf = &mut popup.egl_surface;
        let damage_ring = &mut popup.damage_ring;
        let canvas_cache = &mut popup.canvas_cache;
        let attach_frame = is_animating || popup.frame_callback_pending;

        Self::render_surface_pipeline_helper(
            &self.egl_context,
            &mut self.gles_renderer,
            &mut self.font_system,
            &mut self.swash_cache,
            &mut self.pool,
            &self.qh,
            &wl_surf,
            egl_surf,
            damage_ring,
            canvas_cache,
            &popup.computed_boxes,
            damage,
            scale_factor,
            width,
            height,
            spring_val,
            attach_frame,
        )?;

        if is_animating {
            popup.frame_callback_pending = true;
        }

        Ok(())
    }

    fn compute_damage_rect(
        old_boxes: &[zenith_layout::ComputedBox],
        new_boxes: &[zenith_layout::ComputedBox],
        width: u32,
        height: u32,
    ) -> Option<(i32, i32, i32, i32)> {
        crate::render::damage::compute_damage_rect(old_boxes, new_boxes, width, height)
            .map(|d| (d.x, d.y, d.width, d.height))
    }

    #[allow(dead_code)]
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

    #[allow(clippy::too_many_arguments)]
    fn render_boxes_to_canvas(
        canvas: &mut [u8],
        boxes: &[zenith_layout::ComputedBox],
        width: u32,
        height: u32,
        spring_val: f32,
        font_system: &mut cosmic_text::FontSystem,
        swash_cache: &mut cosmic_text::SwashCache,
        damage_rect: Option<crate::render::damage::DamageRect>,
        scale_factor: f32,
    ) -> Result<(), Box<dyn std::error::Error>> {
        crate::render::ShmFallbackRenderer::render_boxes(
            canvas,
            boxes,
            width,
            height,
            spring_val,
            font_system,
            swash_cache,
            damage_rect,
            scale_factor,
        )
    }

    /// Creates a Wayland subsurface attached to a parent surface at the given coordinates.
    pub fn create_subsurface(
        &mut self,
        parent: &wl_surface::WlSurface,
        x: i32,
        y: i32,
    ) -> (wayland_client::protocol::wl_subsurface::WlSubsurface, wl_surface::WlSurface) {
        let (subsurface, surface) = self.subcompositor_state.create_subsurface(parent.clone(), &self.qh);
        subsurface.set_position(x, y);
        subsurface.set_desync();
        (subsurface, surface)
    }

}

// SCTK Delegate implementations
delegate_compositor!(WaylandApp);
delegate_subcompositor!(WaylandApp);
delegate_output!(WaylandApp);
delegate_shm!(WaylandApp);
delegate_layer!(WaylandApp);
delegate_seat!(WaylandApp);
delegate_pointer!(WaylandApp);
delegate_keyboard!(WaylandApp);
delegate_registry!(WaylandApp);
delegate_data_device!(WaylandApp);
wayland_client::delegate_noop!(WaylandApp: ignore wayland_client::protocol::wl_region::WlRegion);

impl AsMut<DataDeviceManagerState> for WaylandApp {
    fn as_mut(&mut self) -> &mut DataDeviceManagerState {
        self.clipboard_manager
            .manager_state
            .as_mut()
            .expect("DataDeviceManagerState not initialized")
    }
}

impl DataDeviceHandler for WaylandApp {
    fn enter(&mut self, _conn: &Connection, _qh: &QueueHandle<Self>, _data_device: &wayland_client::protocol::wl_data_device::WlDataDevice, _x: f64, _y: f64, _surface: &wayland_client::protocol::wl_surface::WlSurface) {}
    fn leave(&mut self, _conn: &Connection, _qh: &QueueHandle<Self>, _data_device: &wayland_client::protocol::wl_data_device::WlDataDevice) {}
    fn motion(&mut self, _conn: &Connection, _qh: &QueueHandle<Self>, _data_device: &wayland_client::protocol::wl_data_device::WlDataDevice, _x: f64, _y: f64) {}
    fn selection(&mut self, _conn: &Connection, _qh: &QueueHandle<Self>, _data_device: &wayland_client::protocol::wl_data_device::WlDataDevice) {
        if self.clipboard_manager.copy_source.is_none() {
            if let Some(ref device) = self.clipboard_manager.data_device {
                if let Some(offer) = device.data().selection_offer() {
                    let mime_match = offer.with_mime_types(|types| {
                        crate::clipboard::TEXT_MIME_TYPES
                            .iter()
                            .find(|m| types.iter().any(|t| t == *m))
                            .copied()
                    });
                    if let Some(mime) = mime_match {
                        if let Ok(mut read_pipe) = offer.receive(mime.to_string()) {
                            let ram_buf = self.clipboard_manager.ram_buffer.clone();
                            std::thread::spawn(move || {
                                use std::io::Read;
                                let mut text = String::new();
                                if read_pipe.read_to_string(&mut text).is_ok() && !text.is_empty() {
                                    if let Ok(mut lock) = ram_buf.lock() {
                                        *lock = text;
                                    }
                                }
                            });
                        }
                    }
                }
            }
        }
    }
    fn drop_performed(&mut self, _conn: &Connection, _qh: &QueueHandle<Self>, _data_device: &wayland_client::protocol::wl_data_device::WlDataDevice) {}
}

impl DataOfferHandler for WaylandApp {
    fn source_actions(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _offer: &mut smithay_client_toolkit::data_device_manager::data_offer::DragOffer,
        _actions: wayland_client::protocol::wl_data_device_manager::DndAction,
    ) {}
    fn selected_action(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _offer: &mut smithay_client_toolkit::data_device_manager::data_offer::DragOffer,
        _actions: wayland_client::protocol::wl_data_device_manager::DndAction,
    ) {}
}

impl DataSourceHandler for WaylandApp {
    fn accept_mime(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _source: &wayland_client::protocol::wl_data_source::WlDataSource,
        _mime: Option<String>,
    ) {}
    fn send_request(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _source: &wayland_client::protocol::wl_data_source::WlDataSource,
        mime: String,
        write_pipe: smithay_client_toolkit::data_device_manager::WritePipe,
    ) {
        self.clipboard_manager.handle_send_request(&mime, write_pipe);
    }
    fn cancelled(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _source: &wayland_client::protocol::wl_data_source::WlDataSource,
    ) {
        self.clipboard_manager.copy_source = None;
    }
    fn dnd_dropped(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _source: &wayland_client::protocol::wl_data_source::WlDataSource,
    ) {}
    fn dnd_finished(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _source: &wayland_client::protocol::wl_data_source::WlDataSource,
    ) {}
    fn action(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _source: &wayland_client::protocol::wl_data_source::WlDataSource,
        _action: wayland_client::protocol::wl_data_device_manager::DndAction,
    ) {}
}

impl AsMut<SubcompositorState> for WaylandApp {
    fn as_mut(&mut self) -> &mut SubcompositorState {
        &mut self.subcompositor_state
    }
}

impl Dispatch<WpFractionalScaleManagerV1, ()> for WaylandApp {
    fn event(
        _state: &mut Self,
        _proxy: &WpFractionalScaleManagerV1,
        _event: <WpFractionalScaleManagerV1 as Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<WpFractionalScaleV1, crate::fractional_scale::SurfaceData> for WaylandApp {
    fn event(
        state: &mut Self,
        _proxy: &WpFractionalScaleV1,
        event: <WpFractionalScaleV1 as Proxy>::Event,
        data: &crate::fractional_scale::SurfaceData,
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
        if let wayland_protocols::wp::fractional_scale::v1::client::wp_fractional_scale_v1::Event::PreferredScale { scale } = event {
            let factor = scale as f32 / 120.0;
            let surf_id = data.surface_id;
            for bar in &mut state.bars {
                if let Some(ref mut tracker) = bar.scale_tracker {
                    if tracker.surface_id == surf_id {
                        tracker.scale_factor = factor;
                        info!("Bar on output '{}' fractional scale updated to {:.2}x", bar.output_name, factor);
                    }
                }
            }
            if let Some(ref mut popup) = state.popup {
                if let Some(ref mut tracker) = popup.scale_tracker {
                    if tracker.surface_id == surf_id {
                        tracker.scale_factor = factor;
                        info!("Popup '{}' fractional scale updated to {:.2}x", popup.id, factor);
                    }
                }
            }
            if let Some(ref mut dock) = state.dock {
                if let Some(ref mut tracker) = dock.scale_tracker {
                    if tracker.surface_id == surf_id {
                        tracker.scale_factor = factor;
                        info!("Dock fractional scale updated to {:.2}x", factor);
                    }
                }
            }
        }
    }
}

impl Dispatch<WpViewporter, ()> for WaylandApp {
    fn event(
        _state: &mut Self,
        _proxy: &WpViewporter,
        _event: <WpViewporter as Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<WpViewport, ()> for WaylandApp {
    fn event(
        _state: &mut Self,
        _proxy: &WpViewport,
        _event: <WpViewport as Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ZwpPointerGesturesV1, ()> for WaylandApp {
    fn event(
        _state: &mut Self,
        _proxy: &ZwpPointerGesturesV1,
        _event: <ZwpPointerGesturesV1 as Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ZwpPointerGestureSwipeV1, ()> for WaylandApp {
    fn event(
        state: &mut Self,
        _proxy: &ZwpPointerGestureSwipeV1,
        event: <ZwpPointerGestureSwipeV1 as Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
        match event {
            zwp_pointer_gesture_swipe_v1::Event::Begin { fingers, .. } => {
                state.gestures_manager.active_swipe = Some(crate::gestures::SwipeGestureEvent {
                    fingers,
                    dx: 0.0,
                    dy: 0.0,
                    phase: crate::gestures::GesturePhase::Begin,
                });
            }
            zwp_pointer_gesture_swipe_v1::Event::Update { dx, dy, .. } => {
                let fingers = state.gestures_manager.active_swipe.as_ref().map(|s| s.fingers).unwrap_or(2);
                let _evt = state.gestures_manager.handle_swipe_update(fingers, dx, dy);
                let new_scroll = state.gestures_manager.kinetic_scroll.offset();
                if let Some(ref mut popup) = state.popup {
                    zenith_layout::set_scroll_offset_in_tree(&mut popup.root_ui, new_scroll);
                    for b in &mut popup.computed_boxes {
                        if b.overflow == zenith_layout::Overflow::Scroll {
                            b.scroll_offset_y = new_scroll;
                        }
                    }
                }
                let _ = state.request_redraw();
            }
            zwp_pointer_gesture_swipe_v1::Event::End { cancelled, .. } => {
                let _evt = state.gestures_manager.handle_swipe_end(cancelled != 0);
                let _ = state.request_redraw();
            }
            _ => {}
        }
    }
}

impl Dispatch<ZwpPointerGesturePinchV1, ()> for WaylandApp {
    fn event(
        state: &mut Self,
        _proxy: &ZwpPointerGesturePinchV1,
        event: <ZwpPointerGesturePinchV1 as Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
        match event {
            zwp_pointer_gesture_pinch_v1::Event::Begin { fingers, .. } => {
                state.gestures_manager.active_pinch = Some(crate::gestures::PinchGestureEvent {
                    fingers,
                    dx: 0.0,
                    dy: 0.0,
                    scale: 1.0,
                    rotation: 0.0,
                    phase: crate::gestures::GesturePhase::Begin,
                });
            }
            zwp_pointer_gesture_pinch_v1::Event::Update { dx, dy, scale, rotation, .. } => {
                let fingers = state.gestures_manager.active_pinch.as_ref().map(|p| p.fingers).unwrap_or(2);
                let evt = state.gestures_manager.handle_pinch_update(fingers, dx, dy, scale, rotation);
                let payload = format!("{{\"scale\":{},\"rotation\":{},\"dx\":{},\"dy\":{}}}", evt.scale, evt.rotation, evt.dx, evt.dy);
                let _ = state.runtime.trigger_callback_with_arg("on_pinch_gesture", &payload);
                let _ = state.request_redraw();
            }
            zwp_pointer_gesture_pinch_v1::Event::End { .. } => {
                state.gestures_manager.active_pinch = None;
                let _ = state.request_redraw();
            }
            _ => {}
        }
    }
}

impl Dispatch<ExtIdleNotifierV1, ()> for WaylandApp {
    fn event(
        _state: &mut Self,
        _proxy: &ExtIdleNotifierV1,
        _event: <ExtIdleNotifierV1 as Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ExtIdleNotificationV1, crate::idle::IdleNotificationData> for WaylandApp {
    fn event(
        state: &mut Self,
        _proxy: &ExtIdleNotificationV1,
        event: ext_idle_notification_v1::Event,
        data: &crate::idle::IdleNotificationData,
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
        match event {
            ext_idle_notification_v1::Event::Idled => {
                info!("Wayland compositor reported idle state on seat {} (timeout: {}ms)", data.seat_id, data.timeout_ms);
                let _ = state.idle_manager.on_idled(data.seat_id);
                state.runtime.set_idle(true);
                let _ = state.runtime.trigger_callback_with_arg("on_idle_state", "true");
            }
            ext_idle_notification_v1::Event::Resumed => {
                info!("Wayland compositor reported activity resumed on seat {}", data.seat_id);
                let _ = state.idle_manager.on_resumed(data.seat_id);
                state.runtime.set_idle(false);
                let _ = state.runtime.trigger_callback_with_arg("on_idle_state", "false");
                let _ = state.request_redraw();
            }
            _ => {}
        }
    }
}

impl Dispatch<ZwpIdleInhibitManagerV1, ()> for WaylandApp {
    fn event(
        _state: &mut Self,
        _proxy: &ZwpIdleInhibitManagerV1,
        _event: <ZwpIdleInhibitManagerV1 as Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ZwpIdleInhibitorV1, ()> for WaylandApp {
    fn event(
        _state: &mut Self,
        _proxy: &ZwpIdleInhibitorV1,
        _event: <ZwpIdleInhibitorV1 as Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
    }
}

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
        if self.clipboard_manager.data_device.is_none() {
            if let Some(ref mgr) = self.clipboard_manager.manager_state {
                self.clipboard_manager.data_device = Some(mgr.get_data_device(qh, &seat));
            }
        }
        self.idle_manager.register_seat(&seat, qh);
        if self.pointer.is_none() {
            if let Ok(ptr) = self.seat_state.get_pointer(qh, &seat) {
                info!("Acquired Wayland pointer from seat");
                if let Some(ref gestures) = self.gestures_manager.gestures_global {
                    if self.gestures_manager.swipe_gesture.is_none() {
                        self.gestures_manager.swipe_gesture = Some(gestures.get_swipe_gesture(&ptr, qh, ()));
                    }
                    if self.gestures_manager.pinch_gesture.is_none() {
                        self.gestures_manager.pinch_gesture = Some(gestures.get_pinch_gesture(&ptr, qh, ()));
                    }
                }
                if let Some(ref mgr) = self.cursor_shape_mgr {
                    let dev = mgr.get_pointer(&ptr, qh, ());
                    self.cursor_shape_device = Some(dev);
                }
                self.pointer = Some(ptr);
            }
        }
        if self.keyboard.is_none() {
            if let Ok(kbd) = self.seat_state.get_keyboard(qh, &seat, None) {
                info!("Acquired Wayland keyboard from seat");
                self.keyboard = Some(kbd);
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
                if let Some(ref gestures) = self.gestures_manager.gestures_global {
                    if self.gestures_manager.swipe_gesture.is_none() {
                        self.gestures_manager.swipe_gesture = Some(gestures.get_swipe_gesture(&ptr, qh, ()));
                    }
                    if self.gestures_manager.pinch_gesture.is_none() {
                        self.gestures_manager.pinch_gesture = Some(gestures.get_pinch_gesture(&ptr, qh, ()));
                    }
                }
                if let Some(ref mgr) = self.cursor_shape_mgr {
                    let dev = mgr.get_pointer(&ptr, qh, ());
                    self.cursor_shape_device = Some(dev);
                }
                self.pointer = Some(ptr);
            }
        }
        if capability == Capability::Keyboard && self.keyboard.is_none() {
            if let Ok(kbd) = self.seat_state.get_keyboard(qh, &seat, None) {
                info!("Acquired Wayland keyboard on capability");
                self.keyboard = Some(kbd);
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
            self.cursor_shape_device = None;
            self.gestures_manager.swipe_gesture = None;
            self.gestures_manager.pinch_gesture = None;
        }
        if capability == Capability::Keyboard {
            self.keyboard = None;
        }
    }

    fn remove_seat(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        seat: wayland_client::protocol::wl_seat::WlSeat,
    ) {
        self.idle_manager.unregister_seat(&seat);
        self.pointer = None;
        self.cursor_shape_device = None;
        self.keyboard = None;
    }
}

fn measure_text_cursor_idx(
    font_system: &mut cosmic_text::FontSystem,
    text: &str,
    font_size: f32,
    rel_x: f32,
) -> usize {
    if text.is_empty() || rel_x <= 0.0 {
        return 0;
    }
    let font_family = std::env::var("ZENITH_FONT").unwrap_or_else(|_| "JetBrainsMono Nerd Font".to_string());
    let mut buffer = cosmic_text::Buffer::new_empty(cosmic_text::Metrics::new(font_size, font_size * 1.3));
    buffer.set_text(
        text,
        &cosmic_text::Attrs::new().family(cosmic_text::Family::Name(&font_family)),
        cosmic_text::Shaping::Basic,
        None,
    );
    buffer.shape_until_scroll(font_system, false);

    for run in buffer.layout_runs() {
        let mut total_w = 0.0f32;
        for (idx, glyph) in run.glyphs.iter().enumerate() {
            if rel_x < total_w + glyph.w * 0.5 {
                return idx;
            }
            total_w += glyph.w;
        }
        return run.glyphs.len();
    }

    let char_w = (font_size * 0.62).max(1.0);
    (rel_x / char_w).round() as usize
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
                    if let PointerEventKind::Enter { serial } = event.kind {
                        self.last_pointer_enter_serial = Some(serial);
                        self.current_cursor_shape = None;
                    }
                    self.pointer_pos = event.position;
                    let is_dock = self.dock.as_ref().is_some_and(|d| event.surface == *d.surface.wl_surface());
                    let is_popup = self.popup.as_ref().is_some_and(|p| event.surface == *p.surface.wl_surface());
                    let is_bar = self.bars.iter().any(|b| event.surface == *b.surface.wl_surface());

                    if is_dock {
                        self.dock_hovered = true;
                        self.dock_last_leave = None;
                        if self.dock_hidden {
                            let _ = self.update_dock_visibility();
                        } else {
                            let _ = self.draw_dock();
                        }
                    }
                    if is_bar {
                        self.bar_hovered = true;
                        self.bar_last_leave = None;
                        if self.bar_hidden {
                            let _ = self.update_bar_visibility();
                        }
                    }

                    // 1. Dynamic Cursor Shape (wp_cursor_shape_v1) & Tooltip Hover Detection
                    let (px, py) = self.pointer_pos;
                    let mut desired_shape = Shape::Default;
                    let mut hovered_box_key: Option<String> = None;

                    if is_popup {
                        if let Some(ref popup) = self.popup {
                            for b in popup.computed_boxes.iter().rev() {
                                if px >= b.x as f64 && px <= (b.x + b.width) as f64 && py >= b.y as f64 && py <= (b.y + b.height) as f64 {
                                    if desired_shape == Shape::Default {
                                        if let Some(ref inp) = b.text_input {
                                            if inp.active {
                                                desired_shape = Shape::Text;
                                            }
                                        } else if b.on_click.is_some() || b.slider.is_some() || b.switch.is_some() {
                                            desired_shape = Shape::Pointer;
                                        }
                                    }
                                    if hovered_box_key.is_none() {
                                        if let Some(ref tt) = b.tooltip {
                                            hovered_box_key = Some(format!("popup:{}@{:.0},{:.0}", tt, b.x, b.y));
                                        }
                                    }
                                    if desired_shape != Shape::Default && hovered_box_key.is_some() {
                                        break;
                                    }
                                }
                            }
                        }
                    } else if is_dock {
                        if let Some(ref dock) = self.dock {
                            for b in dock.computed_boxes.iter().rev() {
                                if px >= b.x as f64 && px <= (b.x + b.width) as f64 && py >= b.y as f64 && py <= (b.y + b.height) as f64 {
                                    if desired_shape == Shape::Default {
                                        if let Some(ref inp) = b.text_input {
                                            if inp.active {
                                                desired_shape = Shape::Text;
                                            }
                                        } else if b.on_click.is_some() || b.slider.is_some() || b.switch.is_some() {
                                            desired_shape = Shape::Pointer;
                                        }
                                    }
                                    if hovered_box_key.is_none() {
                                        if let Some(ref tt) = b.tooltip {
                                            hovered_box_key = Some(format!("dock:{}@{:.0},{:.0}", tt, b.x, b.y));
                                        }
                                    }
                                    if desired_shape != Shape::Default && hovered_box_key.is_some() {
                                        break;
                                    }
                                }
                            }
                        }
                    } else if is_bar {
                        for bar in &self.bars {
                            if event.surface == *bar.surface.wl_surface() {
                                for b in bar.computed_boxes.iter().rev() {
                                    if px >= b.x as f64 && px <= (b.x + b.width) as f64 && py >= b.y as f64 && py <= (b.y + b.height) as f64 {
                                        if desired_shape == Shape::Default {
                                            if let Some(ref inp) = b.text_input {
                                                if inp.active {
                                                    desired_shape = Shape::Text;
                                                }
                                            } else if b.on_click.is_some() || b.slider.is_some() || b.switch.is_some() {
                                                desired_shape = Shape::Pointer;
                                            }
                                        }
                                        if hovered_box_key.is_none() {
                                            if let Some(ref tt) = b.tooltip {
                                                hovered_box_key = Some(format!("bar:{}:{}@{:.0},{:.0}", bar.output_name, tt, b.x, b.y));
                                            }
                                        }
                                        if desired_shape != Shape::Default && hovered_box_key.is_some() {
                                            break;
                                        }
                                    }
                                }
                                break;
                            }
                        }
                    }

                    self.set_cursor_shape(desired_shape);

                    // 2. Tooltip Hover Timer (>400ms)
                    let now = std::time::Instant::now();
                    let is_tooltip_active = match (&self.tooltip_hover, &hovered_box_key) {
                        (Some((prev_key, start)), Some(curr_key)) if prev_key == curr_key => {
                            start.elapsed() >= std::time::Duration::from_millis(400)
                        }
                        (_, Some(curr_key)) => {
                            self.tooltip_hover = Some((curr_key.clone(), now));
                            false
                        }
                        _ => {
                            self.tooltip_hover = None;
                            false
                        }
                    };

                    let mut redraw_for_tooltip = false;
                    if let Some(ref mut popup) = self.popup {
                        for b in &mut popup.computed_boxes {
                            let should_be = is_tooltip_active && b.tooltip.is_some() && hovered_box_key.as_ref().is_some_and(|k| k.starts_with("popup:") && k.contains(&format!("@{:.0},{:.0}", b.x, b.y)));
                            if b.tooltip_active != should_be {
                                b.tooltip_active = should_be;
                                redraw_for_tooltip = true;
                            }
                        }
                    }
                    if let Some(ref mut dock) = self.dock {
                        for b in &mut dock.computed_boxes {
                            let should_be = is_tooltip_active && b.tooltip.is_some() && hovered_box_key.as_ref().is_some_and(|k| k.starts_with("dock:") && k.contains(&format!("@{:.0},{:.0}", b.x, b.y)));
                            if b.tooltip_active != should_be {
                                b.tooltip_active = should_be;
                                redraw_for_tooltip = true;
                            }
                        }
                    }
                    for bar in &mut self.bars {
                        for b in &mut bar.computed_boxes {
                            let should_be = is_tooltip_active && b.tooltip.is_some() && hovered_box_key.as_ref().is_some_and(|k| k.starts_with(&format!("bar:{}", bar.output_name)) && k.contains(&format!("@{:.0},{:.0}", b.x, b.y)));
                            if b.tooltip_active != should_be {
                                b.tooltip_active = should_be;
                                redraw_for_tooltip = true;
                            }
                        }
                    }

                    if redraw_for_tooltip {
                        let _ = self.request_redraw();
                    }

                    // Drag selection in active focused TextInput
                    if self.pointer_pressed {
                        if let Some(ref input_id) = self.runtime.get_focused_input() {
                            let mut moved_input = false;
                            if let Some(ref mut popup) = self.popup {
                                for b in &mut popup.computed_boxes {
                                    if let Some(ref mut inp) = b.text_input {
                                        if inp.id.as_deref() == Some(input_id) && inp.active {
                                            let (px, _) = self.pointer_pos;
                                            let rel_x = (px - b.x as f64).max(0.0) as f32;
                                            let char_idx = measure_text_cursor_idx(&mut self.font_system, &inp.text, inp.font_size, rel_x);
                                            self.runtime.editor_drag(input_id, char_idx);
                                            let (cur, sel) = self.runtime.get_editor_state(input_id);
                                            inp.cursor_pos = cur;
                                            inp.selection_range = sel;
                                            moved_input = true;
                                            break;
                                        }
                                    }
                                }
                            }
                            if moved_input {
                                let _ = self.request_redraw();
                            }
                        }

                        // Drag active slider if one is being dragged
                        if let Some(ref dragging_id) = self.active_dragging_slider {
                            let (px, _) = self.pointer_pos;
                            let mut updated_val = None;
                            let mut change_cb = None;

                            // Check popup
                            if let Some(ref mut popup) = self.popup {
                                for b in &mut popup.computed_boxes {
                                    if let Some(ref mut sl) = b.slider {
                                        let is_match = sl.id.as_deref() == Some(dragging_id)
                                            || (sl.id.is_none() && sl.on_change.as_deref() == Some(dragging_id));
                                        if is_match {
                                            let rel_x = (px - b.x as f64).clamp(0.0, b.width as f64) as f32;
                                            let fraction = if b.width > 0.0 { rel_x / b.width } else { 0.0 };
                                            let new_val = fraction * (sl.max - sl.min) + sl.min;
                                            sl.value = new_val;
                                            updated_val = Some(new_val);
                                            change_cb = sl.on_change.clone();
                                            break;
                                        }
                                    }
                                }
                            }

                            // Check bars
                            if updated_val.is_none() {
                                for bar in &mut self.bars {
                                    for b in &mut bar.computed_boxes {
                                        if let Some(ref mut sl) = b.slider {
                                            let is_match = sl.id.as_deref() == Some(dragging_id)
                                                || (sl.id.is_none() && sl.on_change.as_deref() == Some(dragging_id));
                                            if is_match {
                                                let rel_x = (px - b.x as f64).clamp(0.0, b.width as f64) as f32;
                                                let fraction = if b.width > 0.0 { rel_x / b.width } else { 0.0 };
                                                let new_val = fraction * (sl.max - sl.min) + sl.min;
                                                sl.value = new_val;
                                                updated_val = Some(new_val);
                                                change_cb = sl.on_change.clone();
                                                break;
                                            }
                                        }
                                    }
                                    if updated_val.is_some() {
                                        break;
                                    }
                                }
                            }

                            if let Some(val) = updated_val {
                                if let Some(cb) = change_cb {
                                    let _ = self.runtime.trigger_callback_with_arg(&cb, &val.to_string());
                                }
                                let _ = self.update_bar_visibility();
                                let _ = self.update_dock_visibility();
                                let _ = self.request_redraw();
                            }
                        }
                    }
                }
                PointerEventKind::Release { .. } => {
                    self.pointer_pressed = false;
                    if self.active_dragging_slider.is_some() {
                        self.active_dragging_slider = None;
                        let _ = self.update_bar_visibility();
                        let _ = self.update_dock_visibility();
                        if let Some(ref p) = self.popup {
                            let id = p.id.clone();
                            let _ = self.reload_popup(&id);
                        }
                        let _ = self.request_redraw();
                    }
                }
                PointerEventKind::Leave { .. } => {
                    self.current_cursor_shape = None;
                    self.tooltip_hover = None;
                    let mut cleared_tooltip = false;
                    if let Some(ref mut popup) = self.popup {
                        for b in &mut popup.computed_boxes {
                            if b.tooltip_active {
                                b.tooltip_active = false;
                                cleared_tooltip = true;
                            }
                        }
                    }
                    if let Some(ref mut dock) = self.dock {
                        for b in &mut dock.computed_boxes {
                            if b.tooltip_active {
                                b.tooltip_active = false;
                                cleared_tooltip = true;
                            }
                        }
                    }
                    for bar in &mut self.bars {
                        for b in &mut bar.computed_boxes {
                            if b.tooltip_active {
                                b.tooltip_active = false;
                                cleared_tooltip = true;
                            }
                        }
                    }
                    if cleared_tooltip {
                        let _ = self.request_redraw();
                    }
                    let is_dock = self.dock.as_ref().is_some_and(|d| event.surface == *d.surface.wl_surface());
                    if is_dock {
                        self.dock_hovered = false;
                        self.dock_last_leave = Some(std::time::Instant::now());
                        if !self.dock_hidden {
                            let _ = self.draw_dock();
                        }
                    }
                    let is_bar = self.bars.iter().any(|b| event.surface == *b.surface.wl_surface());
                    if is_bar {
                        self.bar_hovered = false;
                        self.bar_last_leave = Some(std::time::Instant::now());
                    }
                }
                PointerEventKind::Press { button, .. } if button == BTN_LEFT || button == BTN_RIGHT => {
                    self.pointer_pressed = true;
                    let is_right = button == BTN_RIGHT;
                    let (px, py) = self.pointer_pos;
                    let mut target_action: Option<String> = None;

                    // Check if click was on ext-session-lock surface
                    if self.session_lock.locked {
                        for s in &mut self.session_lock.surfaces {
                            if event.surface == s.wl_surface {
                                for b in s.computed_boxes.iter().rev() {
                                    if px >= b.x as f64
                                        && px <= (b.x + b.width) as f64
                                        && py >= b.y as f64
                                        && py <= (b.y + b.height) as f64
                                    {
                                        let action_opt = if is_right { b.on_right_click.as_ref() } else { b.on_click.as_ref() };
                                        if let Some(action) = action_opt {
                                            target_action = Some(action.clone());
                                            break;
                                        }
                                    }
                                }
                                if let Some(action) = target_action {
                                    self.execute_action(&action);
                                    let _ = self.draw_lock_surfaces();
                                }
                                return;
                            }
                        }
                    }

                    // Check if click was on dock
                    if let Some(ref dock) = self.dock {
                        if event.surface == *dock.surface.wl_surface() {
                            if self.dock_hidden {
                                self.dock_hovered = true;
                                self.dock_last_leave = None;
                                let _ = self.update_dock_visibility();
                                return;
                            }
                            for b in dock.computed_boxes.iter().rev() {
                                if px >= b.x as f64
                                    && px <= (b.x + b.width) as f64
                                    && py >= b.y as f64
                                    && py <= (b.y + b.height) as f64
                                {
                                    let action_opt = if is_right { b.on_right_click.as_ref() } else { b.on_click.as_ref() };
                                    if let Some(action) = action_opt {
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

                    // Check if click was on popup window
                    let is_popup_surface = self.popup.as_ref().is_some_and(|p| event.surface == *p.surface.wl_surface());
                    if is_popup_surface {
                        let mut _clicked_box = false;
                        let mut focused_new_input: Option<FocusedInputState> = None;
                        let mut toggled_switch: Option<(bool, Option<String>)> = None;
                        let mut clicked_slider: Option<(f32, Option<String>, Option<String>)> = None;

                        if let Some(ref mut popup) = self.popup {
                            for b in popup.computed_boxes.iter_mut().rev() {
                                if px >= b.x as f64
                                    && px <= (b.x + b.width) as f64
                                    && py >= b.y as f64
                                    && py <= (b.y + b.height) as f64
                                {
                                    _clicked_box = true;
                                    if let Some(ref input) = b.text_input {
                                        let id = input.id.clone().unwrap_or_else(|| "text_input".to_string());
                                        let rel_x = (px - b.x as f64).max(0.0) as f32;
                                        let char_idx = measure_text_cursor_idx(&mut self.font_system, &input.text, input.font_size, rel_x);
                                        self.runtime.editor_click(&id, char_idx, self.modifiers.shift, std::time::Instant::now());
                                        let (cur, sel) = self.runtime.get_editor_state(&id);
                                        focused_new_input = Some((id, cur, sel));
                                        break;
                                    }

                                    if let Some(ref mut sw) = b.switch {
                                        sw.checked = !sw.checked;
                                        toggled_switch = Some((sw.checked, sw.on_toggle.clone()));
                                        break;
                                    }

                                    if let Some(ref mut sl) = b.slider {
                                        let rel_x = (px - b.x as f64).clamp(0.0, b.width as f64) as f32;
                                        let fraction = if b.width > 0.0 { rel_x / b.width } else { 0.0 };
                                        let new_val = fraction * (sl.max - sl.min) + sl.min;
                                        sl.value = new_val;
                                        clicked_slider = Some((new_val, sl.id.clone(), sl.on_change.clone()));
                                        break;
                                    }

                                    let action_opt = if is_right { b.on_right_click.as_ref() } else { b.on_click.as_ref() };
                                    if let Some(action) = action_opt {
                                        target_action = Some(action.clone());
                                        break;
                                    }
                                }
                            }
                        }

                        if let Some((checked, cb_opt)) = toggled_switch {
                            if let Some(cb) = cb_opt {
                                let _ = self.runtime.trigger_callback_with_arg(&cb, if checked { "true" } else { "false" });
                            }
                            if let Some(ref p) = self.popup {
                                let id = p.id.clone();
                                let _ = self.reload_popup(&id);
                            }
                            let _ = self.update_bar_visibility();
                            let _ = self.update_dock_visibility();
                            let _ = self.request_redraw();
                            return;
                        }

                        if let Some((new_val, id_opt, cb_opt)) = clicked_slider {
                            let slider_id = id_opt.or(cb_opt.clone()).unwrap_or_else(|| "slider".to_string());
                            self.active_dragging_slider = Some(slider_id);
                            if let Some(cb) = cb_opt {
                                let _ = self.runtime.trigger_callback_with_arg(&cb, &new_val.to_string());
                            }
                            let _ = self.update_bar_visibility();
                            let _ = self.update_dock_visibility();
                            let _ = self.request_redraw();
                            return;
                        }

                        if let Some((input_id, cursor_pos, selection_range)) = focused_new_input {
                            self.runtime.set_focused_input(Some(input_id.clone()));
                            if let Some(ref mut p) = self.popup {
                                for pb in p.computed_boxes.iter_mut() {
                                    if let Some(ref mut inp) = pb.text_input {
                                        let is_target = inp.id.as_deref().unwrap_or("text_input") == input_id;
                                        inp.active = is_target;
                                        if is_target {
                                            inp.cursor_pos = cursor_pos;
                                            inp.selection_range = selection_range;
                                        }
                                    }
                                }
                            }
                            let _ = self.request_redraw();
                            return;
                        }

                        if let Some(action) = target_action {
                            self.execute_action(&action);
                            let _ = self.update_bar_visibility();
                            let _ = self.update_dock_visibility();
                            let _ = self.request_redraw();
                        }
                        return;
                    } else if let Some(ref popup) = self.popup {
                        if !popup.id.eq_ignore_ascii_case("lock") && !popup.id.eq_ignore_ascii_case("lockscreen") && popup.id != "dock" {
                            // Click was OUTSIDE the popup surface - close the popup!
                            self.close_popup();
                        }
                    }

                    // Check if click was on any status bar
                    for bar in &mut self.bars {
                        if event.surface == *bar.surface.wl_surface() {
                            if self.bar_hidden {
                                self.bar_hovered = true;
                                self.bar_last_leave = None;
                                let _ = self.update_bar_visibility();
                                return;
                            }
                            let mut bar_toggled_switch: Option<(bool, Option<String>)> = None;
                            let mut bar_clicked_slider: Option<(f32, Option<String>, Option<String>)> = None;

                            for b in bar.computed_boxes.iter_mut().rev() {
                                if px >= b.x as f64
                                    && px <= (b.x + b.width) as f64
                                    && py >= b.y as f64
                                    && py <= (b.y + b.height) as f64
                                {
                                    if let Some(ref mut sw) = b.switch {
                                        sw.checked = !sw.checked;
                                        bar_toggled_switch = Some((sw.checked, sw.on_toggle.clone()));
                                        break;
                                    }

                                    if let Some(ref mut sl) = b.slider {
                                        let rel_x = (px - b.x as f64).clamp(0.0, b.width as f64) as f32;
                                        let fraction = if b.width > 0.0 { rel_x / b.width } else { 0.0 };
                                        let new_val = fraction * (sl.max - sl.min) + sl.min;
                                        sl.value = new_val;
                                        bar_clicked_slider = Some((new_val, sl.id.clone(), sl.on_change.clone()));
                                        break;
                                    }

                                    let action_opt = if is_right { b.on_right_click.as_ref() } else { b.on_click.as_ref() };
                                    if let Some(action) = action_opt {
                                        target_action = Some(action.clone());
                                        break;
                                    }
                                }
                            }

                            if let Some((checked, cb_opt)) = bar_toggled_switch {
                                if let Some(cb) = cb_opt {
                                    let _ = self.runtime.trigger_callback_with_arg(&cb, if checked { "true" } else { "false" });
                                }
                                let _ = self.request_redraw();
                                return;
                            }

                            if let Some((new_val, id_opt, cb_opt)) = bar_clicked_slider {
                                let slider_id = id_opt.or(cb_opt.clone()).unwrap_or_else(|| "slider".to_string());
                                self.active_dragging_slider = Some(slider_id);
                                if let Some(cb) = cb_opt {
                                    let _ = self.runtime.trigger_callback_with_arg(&cb, &new_val.to_string());
                                }
                                let _ = self.update_bar_visibility();
                                let _ = self.update_dock_visibility();
                                let _ = self.request_redraw();
                                return;
                            }

                            if let Some(action) = target_action {
                                if let Some(ref p) = self.popup {
                                    let toggle_needle = format!("popup:toggle:{}", p.id.to_lowercase());
                                    if !action.to_lowercase().contains(&toggle_needle)
                                        && !action.to_lowercase().contains(&p.id.to_lowercase())
                                        && p.id != "dock"
                                        && !p.id.eq_ignore_ascii_case("lock")
                                        && !p.id.eq_ignore_ascii_case("lockscreen")
                                    {
                                        self.close_popup();
                                    }
                                }
                                self.execute_action(&action);
                            } else if self.popup.is_some()
                                && !is_right
                                && self.popup.as_ref().is_some_and(|p| p.id != "dock" && !p.id.eq_ignore_ascii_case("lock") && !p.id.eq_ignore_ascii_case("lockscreen"))
                            {
                                self.close_popup();
                            }
                            return;
                        }
                    }
                }
                PointerEventKind::Axis { vertical, .. } => {
                    let is_up = vertical.absolute < 0.0 || vertical.discrete < 0;
                    let is_down = vertical.absolute > 0.0 || vertical.discrete > 0;
                    if !is_up && !is_down {
                        continue;
                    }

                    let (px, py) = self.pointer_pos;
                    let mut target_action: Option<String> = None;
                    let mut handled_scroll = false;

                    // Check popup window first
                    if let Some(ref mut popup) = self.popup {
                        if event.surface == *popup.surface.wl_surface() {
                            for b in popup.computed_boxes.iter_mut().rev() {
                                if px >= b.x as f64
                                    && px <= (b.x + b.width) as f64
                                    && py >= b.y as f64
                                    && py <= (b.y + b.height) as f64
                                {
                                    if b.overflow == zenith_layout::Overflow::Scroll {
                                        let delta = if is_up { -28.0 } else { 28.0 };
                                        zenith_layout::update_scroll_offset_in_tree(&mut popup.root_ui, delta);
                                        self.gestures_manager.kinetic_scroll.on_scroll(delta);
                                        b.scroll_offset_y = self.gestures_manager.kinetic_scroll.offset();
                                        handled_scroll = true;
                                        break;
                                    }

                                    let action_opt = if is_up {
                                        b.on_scroll_up.as_ref()
                                    } else {
                                        b.on_scroll_down.as_ref()
                                    };
                                    if let Some(action) = action_opt {
                                        target_action = Some(action.clone());
                                        break;
                                    }
                                }
                            }

                            if handled_scroll {
                                let _ = self.draw_popup();
                                return;
                            }

                            if let Some(action) = target_action {
                                self.execute_action(&action);
                            }
                            return;
                        }
                    }

                    // Check status bars
                    for bar in &self.bars {
                        if event.surface == *bar.surface.wl_surface() {
                            for b in bar.computed_boxes.iter().rev() {
                                if px >= b.x as f64
                                    && px <= (b.x + b.width) as f64
                                    && py >= b.y as f64
                                    && py <= (b.y + b.height) as f64
                                {
                                    let action_opt = if is_up {
                                        b.on_scroll_up.as_ref()
                                    } else {
                                        b.on_scroll_down.as_ref()
                                    };
                                    if let Some(action) = action_opt {
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
                }
                _ => {}
            }
        }
    }
}


impl KeyboardHandler for WaylandApp {
    fn enter(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _keyboard: &wl_keyboard::WlKeyboard,
        _surface: &wl_surface::WlSurface,
        _serial: u32,
        _raw: &[u32],
        _keysyms: &[Keysym],
    ) {}

    fn leave(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _keyboard: &wl_keyboard::WlKeyboard,
        _surface: &wl_surface::WlSurface,
        _serial: u32,
    ) {}

    fn press_key(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _keyboard: &wl_keyboard::WlKeyboard,
        _serial: u32,
        event: KeyEvent,
    ) {
        if self.popup.is_none() && !self.session_lock.locked {
            return;
        }

        let is_lock = self.session_lock.locked
            || self.popup.as_ref().map(|p| p.id.eq_ignore_ascii_case("lock") || p.id.eq_ignore_ascii_case("lockscreen")).unwrap_or(false);

        if is_lock {
            match event.keysym {
                Keysym::Return => {
                    let pwd = self.runtime.take_lock_password();
                    self.start_pam_auth(&pwd);
                }
                Keysym::BackSpace => {
                    self.runtime.pop_lock_password();
                    if self.session_lock.locked {
                        let _ = self.draw_lock_surfaces();
                    } else if let Some(ref p) = self.popup {
                        let id = p.id.clone();
                        let _ = self.reload_popup(&id);
                        let _ = self.draw_popup();
                    }
                }
                Keysym::Escape => {
                    self.runtime.clear_lock_password();
                    if self.session_lock.locked {
                        let _ = self.draw_lock_surfaces();
                    } else if let Some(ref p) = self.popup {
                        let id = p.id.clone();
                        let _ = self.reload_popup(&id);
                        let _ = self.draw_popup();
                    }
                }
                _ => {
                    if let Some(text) = event.utf8 {
                        let text = text.trim_matches(|c: char| c.is_control());
                        if !text.is_empty() {
                            self.runtime.push_lock_password(text);
                            if self.session_lock.locked {
                                let _ = self.draw_lock_surfaces();
                            } else if let Some(ref p) = self.popup {
                                let id = p.id.clone();
                                let _ = self.reload_popup(&id);
                                let _ = self.draw_popup();
                            }
                        }
                    }
                }
            }
            return;
        }

        let is_shift = self.modifiers.shift;

        // Tab / Shift+Tab keyboard focus cycling across TextInputs
        if event.keysym == Keysym::Tab || event.keysym == Keysym::ISO_Left_Tab {
            if let Some(ref popup) = self.popup {
                let input_ids: Vec<String> = popup
                    .computed_boxes
                    .iter()
                    .filter_map(|b| b.text_input.as_ref().and_then(|inp| inp.id.clone()))
                    .collect();
                if !input_ids.is_empty() {
                    let focused_input = self.runtime.get_focused_input();
                    let cur_idx = focused_input
                        .as_ref()
                        .and_then(|fid| input_ids.iter().position(|id| id == fid));
                    let next_idx = match cur_idx {
                        Some(idx) => {
                            if is_shift || event.keysym == Keysym::ISO_Left_Tab {
                                if idx == 0 {
                                    input_ids.len() - 1
                                } else {
                                    idx - 1
                                }
                            } else {
                                (idx + 1) % input_ids.len()
                            }
                        }
                        None => 0,
                    };
                    let next_id = input_ids[next_idx].clone();
                    self.runtime.set_focused_input(Some(next_id.clone()));
                    if let Some(ref mut popup) = self.popup {
                        for pb in popup.computed_boxes.iter_mut() {
                            if let Some(ref mut pb_inp) = pb.text_input {
                                pb_inp.active = pb_inp.id.as_deref() == Some(&next_id);
                            }
                        }
                    }
                    let _ = self.request_redraw();
                    return;
                }
            }
        }

        // Handle generic focused TextInput typing if active
        let focused_input = self.runtime.get_focused_input();
        if let Some(ref input_id) = focused_input {
            let mut matched_input = None;
            if let Some(ref popup) = self.popup {
                for b in &popup.computed_boxes {
                    if let Some(ref inp) = b.text_input {
                        if inp.id.as_deref() == Some(input_id) || inp.active {
                            matched_input = Some(inp.clone());
                            break;
                        }
                    }
                }
            }

            if let Some(inp) = matched_input {
                let is_ctrl = self.modifiers.ctrl;
                let is_shift = self.modifiers.shift;

                if !is_ctrl {
                    match self.compose_tracker.feed(event.keysym) {
                        ComposeResult::Composed(text) => {
                            self.runtime.editor_insert(input_id, &text);
                            let cur_txt = self.runtime.get_input_text(input_id);
                            let (cursor_pos, selection_range) = self.runtime.get_editor_state(input_id);
                            if let Some(ref cb) = inp.on_change {
                                let _ = self.runtime.trigger_callback_with_arg(cb, &cur_txt);
                            }
                            if let Some(ref mut popup) = self.popup {
                                for pb in popup.computed_boxes.iter_mut() {
                                    if let Some(ref mut pb_inp) = pb.text_input {
                                        if pb_inp.id.as_deref() == Some(input_id) {
                                            pb_inp.text = cur_txt.clone();
                                            pb_inp.cursor_pos = cursor_pos;
                                            pb_inp.selection_range = selection_range;
                                        }
                                    }
                                }
                            }
                            if let Some(ref p) = self.popup {
                                let id = p.id.clone();
                                let _ = self.reload_popup(&id);
                            }
                            let _ = self.request_redraw();
                            return;
                        }
                        ComposeResult::Composing => {
                            return;
                        }
                        ComposeResult::Cancelled => {
                            return;
                        }
                        ComposeResult::Nothing => {}
                    }
                }

                match event.keysym {
                    Keysym::Escape => {
                        self.runtime.set_focused_input(None);
                        if let Some(ref mut popup) = self.popup {
                            for pb in popup.computed_boxes.iter_mut() {
                                if let Some(ref mut pb_inp) = pb.text_input {
                                    pb_inp.active = false;
                                }
                            }
                        }
                        let _ = self.request_redraw();
                        return;
                    }
                    Keysym::Return => {
                        let cur_txt = self.runtime.get_input_text(input_id);
                        if let Some(ref cb) = inp.on_submit {
                            let _ = self.runtime.trigger_callback_with_arg(cb, &cur_txt);
                        }
                        return;
                    }
                    // Ctrl+A: Select All
                    Keysym::a | Keysym::A if is_ctrl => {
                        self.runtime.editor_select_all(input_id);
                    }
                    // Ctrl+C: Copy (Zero-Fork Native Wayland Clipboard + RAM Buffer)
                    Keysym::c | Keysym::C if is_ctrl => {
                        if let Some(text) = self.runtime.editor_copy(input_id) {
                            self.clipboard_manager.copy_with_wayland(&self.qh, &text, _serial);
                        }
                        return;
                    }
                    // Ctrl+X: Cut (Zero-Fork Native Wayland Clipboard + RAM Buffer)
                    Keysym::x | Keysym::X if is_ctrl => {
                        if let Some(text) = self.runtime.editor_cut(input_id) {
                            self.clipboard_manager.copy_with_wayland(&self.qh, &text, _serial);
                        }
                    }
                    // Ctrl+V: Paste (Zero-Fork Native Wayland Clipboard Offer + RAM Buffer)
                    Keysym::v | Keysym::V if is_ctrl => {
                        let paste_text = self.clipboard_manager.paste_with_conn(Some(_conn));
                        if !paste_text.is_empty() {
                            self.runtime.editor_paste(input_id, &paste_text);
                        }
                    }
                    // Ctrl+Z (Undo) / Ctrl+Shift+Z (Redo)
                    Keysym::z | Keysym::Z if is_ctrl => {
                        if is_shift {
                            self.runtime.editor_redo(input_id);
                        } else {
                            self.runtime.editor_undo(input_id);
                        }
                    }
                    // Ctrl+Y: Redo
                    Keysym::y | Keysym::Y if is_ctrl => {
                        self.runtime.editor_redo(input_id);
                    }
                    // Arrow Keys with optional Shift
                    Keysym::Left => {
                        self.runtime.editor_move_cursor(input_id, zenith_layout::CursorDirection::Left, is_shift);
                    }
                    Keysym::Right => {
                        self.runtime.editor_move_cursor(input_id, zenith_layout::CursorDirection::Right, is_shift);
                    }
                    Keysym::Home => {
                        self.runtime.editor_move_cursor(input_id, zenith_layout::CursorDirection::Home, is_shift);
                    }
                    Keysym::End => {
                        self.runtime.editor_move_cursor(input_id, zenith_layout::CursorDirection::End, is_shift);
                    }
                    Keysym::BackSpace => {
                        self.runtime.editor_backspace(input_id);
                    }
                    Keysym::Delete => {
                        self.runtime.editor_delete(input_id);
                    }
                    _ => {
                        if !is_ctrl {
                            if let Some(ref text) = event.utf8 {
                                let text = text.trim_matches(|c: char| c.is_control());
                                if !text.is_empty() {
                                    self.runtime.editor_insert(input_id, text);
                                }
                            }
                        }
                    }
                }

                let cur_txt = self.runtime.get_input_text(input_id);
                let (cursor_pos, selection_range) = self.runtime.get_editor_state(input_id);

                if let Some(ref cb) = inp.on_change {
                    let _ = self.runtime.trigger_callback_with_arg(cb, &cur_txt);
                }

                if let Some(ref mut popup) = self.popup {
                    for pb in popup.computed_boxes.iter_mut() {
                        if let Some(ref mut pb_inp) = pb.text_input {
                            if pb_inp.id.as_deref() == Some(input_id) {
                                pb_inp.text = cur_txt.clone();
                                pb_inp.cursor_pos = cursor_pos;
                                pb_inp.selection_range = selection_range;
                            }
                        }
                    }
                }

                if let Some(ref p) = self.popup {
                    let id = p.id.clone();
                    let _ = self.reload_popup(&id);
                }

                let _ = self.request_redraw();
                return;
            }
        }

        if self.popup.is_none() {
            return;
        }
        let popup_id = self.popup.as_ref().unwrap().id.clone();

        match event.keysym {
            Keysym::Escape => {
                if let Some(ref p) = self.popup {
                    if p.closing {
                        self.destroy_popup_immediately();
                    } else {
                        self.close_popup();
                    }
                }
            }
            Keysym::Return => {
                if popup_id.eq_ignore_ascii_case("launcher") {
                    let selected_idx = self.runtime.get_selected_index();
                    let query = self.runtime.get_search_query();
                    let list = zenith_services::LauncherService::search(&query, 30);
                    if let Some(app) = list.get(selected_idx.saturating_sub(1)) {
                        let _ = zenith_services::LauncherService::launch(&app.exec);
                        self.destroy_popup_immediately();
                        return;
                    }
                }
                let selected_idx = self.runtime.get_selected_index();
                if let Some(ref popup) = self.popup {
                    let mut actionables: Vec<String> = Vec::new();
                    for b in &popup.computed_boxes {
                        if let Some(ref act) = b.on_click {
                            if act.starts_with("launch:") {
                                actionables.push(act.clone());
                            }
                        }
                    }
                    if !actionables.is_empty() {
                        let target = if selected_idx > 0 && selected_idx <= actionables.len() {
                            Some(actionables[selected_idx - 1].clone())
                        } else {
                            actionables.first().cloned()
                        };
                        if let Some(act) = target {
                            self.execute_action(&act);
                        }
                    }
                }
            }
            Keysym::Up => {
                let current = self.runtime.get_selected_index();
                if current > 1 {
                    self.runtime.set_selected_index(current - 1);
                    let _ = self.reload_popup(&popup_id);
                    let _ = self.draw_popup();
                }
            }
            Keysym::Down => {
                let current = self.runtime.get_selected_index();
                let max_count = if popup_id.eq_ignore_ascii_case("launcher") {
                    30
                } else {
                    50
                };
                if max_count > 0 && current < max_count {
                    self.runtime.set_selected_index(current + 1);
                    let _ = self.reload_popup(&popup_id);
                    let _ = self.draw_popup();
                }
            }
            Keysym::BackSpace => {
                let mut q = self.runtime.get_search_query();
                if !q.is_empty() {
                    q.pop();
                    self.runtime.set_search_query(&q);
                    self.runtime.set_selected_index(1);
                    let _ = self.reload_popup(&popup_id);
                    let _ = self.draw_popup();
                }
            }
            _ => {
                if let Some(text) = event.utf8 {
                    let text = text.trim_matches(|c: char| c.is_control());
                    if !text.is_empty() {
                        let mut q = self.runtime.get_search_query();
                        q.push_str(text);
                        self.runtime.set_search_query(&q);
                        self.runtime.set_selected_index(1);
                        let _ = self.reload_popup(&popup_id);
                        let _ = self.draw_popup();
                    }
                }
            }
        }
    }

    fn release_key(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _keyboard: &wl_keyboard::WlKeyboard,
        _serial: u32,
        _event: KeyEvent,
    ) {}

    fn update_modifiers(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _keyboard: &wl_keyboard::WlKeyboard,
        _serial: u32,
        modifiers: Modifiers,
        _layout: u32,
    ) {
        self.modifiers = modifiers;
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
        surface: &wl_surface::WlSurface,
        _time: u32,
    ) {
        // Session lock surfaces VSync sync
        if self.session_lock.locked {
            for surf in &mut self.session_lock.surfaces {
                if surf.wl_surface == *surface {
                    surf.frame_callback_pending = false;
                    let _ = self.draw_lock_surfaces();
                    return;
                }
            }
        }

        // Step active spring animations on popups
        if let Some(ref mut popup) = self.popup {
            if popup.surface.wl_surface() == surface {
                popup.frame_callback_pending = false;
                let mut should_draw = self.needs_redraw_popup;
                if let Some(ref mut anim) = popup.spring {
                    anim.step(0.016);
                    should_draw = true;
                    if popup.closing && (anim.is_settled() || anim.current <= 0.04) {
                        self.popup = None;
                        return;
                    }
                }
                if !self.gestures_manager.is_scroll_settled() {
                    let new_scroll = self.gestures_manager.step_scroll(0.016);
                    zenith_layout::set_scroll_offset_in_tree(&mut popup.root_ui, new_scroll);
                    for b in &mut popup.computed_boxes {
                        if b.overflow == zenith_layout::Overflow::Scroll {
                            b.scroll_offset_y = new_scroll;
                        }
                    }
                    should_draw = true;
                }
                if should_draw {
                    let needs_reload = self.needs_redraw_popup && !popup.closing;
                    self.needs_redraw_popup = false;
                    if needs_reload {
                        let id = popup.id.clone();
                        let _ = self.reload_popup(&id);
                    } else {
                        let _ = self.draw_popup();
                    }
                }
                return;
            }
        }

        // Active dock VSync sync
        if let Some(ref mut dock) = self.dock {
            if dock.surface.wl_surface() == surface {
                dock.frame_callback_pending = false;
                if self.needs_redraw_dock {
                    self.needs_redraw_dock = false;
                    let _ = self.update_dock_visibility();
                    if !self.dock_hidden {
                        let _ = self.reload_dock();
                    } else {
                        let _ = self.draw_dock();
                    }
                }
                return;
            }
        }

        // Active bar VSync sync
        for bar in &mut self.bars {
            if bar.surface.wl_surface() == surface {
                bar.frame_callback_pending = false;
                if self.needs_redraw_bars {
                    self.needs_redraw_bars = false;
                    let _ = self.update_bar_visibility();
                    let _ = self.draw();
                }
                break;
            }
        }
    }

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
        output: wl_output::WlOutput,
    ) {
        let name = self.output_state.info(&output)
            .and_then(|i| i.name)
            .unwrap_or_else(|| format!("output-{}", self.bars.len()));
        info!("Wayland output added: name={:?}", name);

        let mut log_size = (1920, 1080);
        let mut scale = 1.0;
        let mut current_mode = None;

        if let Some(info) = self.output_state.info(&output) {
            scale = info.scale_factor as f64;
            if let Some((w, h)) = info.logical_size {
                if w > 0 && h > 0 {
                    self.screen_width = w as u32;
                    self.screen_height = h as u32;
                    log_size = (w as u32, h as u32);
                    self.runtime.set_current_output_geometry(&name, w as u32, h as u32);
                }
            }
            if let Some(m) = info.modes.iter().find(|m| m.current).or_else(|| info.modes.first()) {
                current_mode = Some(crate::monitor::OutputMode {
                    width: m.dimensions.0,
                    height: m.dimensions.1,
                    refresh_mhz: m.refresh_rate,
                });
            }
        }

        self.monitor_manager.register_output(&name, log_size, scale, current_mode);

        // If we have an existing bar with this exact output name:
        if let Some(pos) = self.bars.iter().position(|b| b.output_name == name) {
            if self.bars[pos].output.as_ref() == Some(&output) {
                return;
            }
            // Output handle changed; replace existing bar cleanly with a new surface on the new output
            self.bars.remove(pos);
            if let Err(e) = self.create_bar_for_output(Some(&output), &name) {
                error!("Failed to recreate bar for reconnected output '{}': {}", name, e);
            }
            return;
        }

        // If we only had the unassigned default bar, adopt this explicit output directly
        if self.bars.len() == 1 && self.bars[0].output.is_none() {
            self.bars[0].output = Some(output);
            self.bars[0].output_name = name.to_string();
            return;
        }

        // Spawn a cloned bar for this new output if it doesn't already have one
        let exists = self.bars.iter().any(|b| b.output.as_ref() == Some(&output) || b.output_name == name);
        if !exists {
            if let Err(e) = self.create_bar_for_output(Some(&output), &name) {
                error!("Failed to create bar for output '{}': {}", name, e);
            }
        }
    }

    fn update_output(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        output: wl_output::WlOutput,
    ) {
        if let Some(info) = self.output_state.info(&output) {
            info!("Wayland output updated: name={:?}, size={:?}", info.name, info.logical_size);
            let name = info.name.as_deref().unwrap_or("default");
            let mut log_size = (self.screen_width, self.screen_height);
            if let Some((w, h)) = info.logical_size {
                if w > 0 && h > 0 {
                    self.screen_width = w as u32;
                    self.screen_height = h as u32;
                    log_size = (w as u32, h as u32);
                    self.runtime.set_current_output_geometry(name, w as u32, h as u32);
                }
            }
            let mode = info.modes.iter().find(|m| m.current).map(|m| crate::monitor::OutputMode {
                width: m.dimensions.0,
                height: m.dimensions.1,
                refresh_mhz: m.refresh_rate,
            });
            if let Some(m) = mode {
                self.monitor_manager.update_mode(name, m.width, m.height, m.refresh_mhz);
            }
            self.monitor_manager.register_output(name, log_size, info.scale_factor as f64, mode);

            // Notify corresponding bar if resolution or geometry changed
            if let Some(bar) = self.bars.iter_mut().find(|b| b.output.as_ref() == Some(&output) || b.output_name == name) {
                if let Some((w, _)) = info.logical_size {
                    if w > 0 && bar.width != w as u32 {
                        bar.width = w as u32;
                        bar.damage_ring.reset();
                        bar.computed_boxes.clear();
                    }
                }
            }
        }
    }

    fn output_destroyed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        output: wl_output::WlOutput,
    ) {
        info!("Wayland output destroyed");
        let mut destroyed_name = None;
        if let Some(bar) = self.bars.iter().find(|b| b.output.as_ref() == Some(&output)) {
            destroyed_name = Some(bar.output_name.clone());
        } else if let Some(info) = self.output_state.info(&output) {
            destroyed_name = info.name;
        }
        if let Some(name) = destroyed_name {
            self.monitor_manager.unregister_output(&name);
        }
        self.bars.retain(|b| b.output.as_ref() != Some(&output));
    }
}

impl ShmHandler for WaylandApp {
    fn shm_state(&mut self) -> &mut Shm {
        &mut self.shm
    }
}

impl LayerShellHandler for WaylandApp {
    fn closed(&mut self, _conn: &Connection, _qh: &QueueHandle<Self>, layer: &LayerSurface) {
        if let Some(pos) = self.bars.iter().position(|b| b.surface.wl_surface() == layer.wl_surface()) {
            let output_name = self.bars[pos].output_name.clone();
            let output = self.bars[pos].output.clone();
            info!("Layer surface closed by compositor on output '{}'", output_name);
            self.bars.remove(pos);
            info!("Bar removed. Active bars remaining: {}", self.bars.len());

            // If the output is still connected in output_state, recreate resiliently
            if let Some(out) = output {
                if let Some(info) = self.output_state.info(&out) {
                    let name = info.name.as_deref().unwrap_or(&output_name);
                    info!("Output '{}' is still active; recreating layer surface", name);
                    let _ = self.create_bar_for_output(Some(&out), name);
                }
            }
            return;
        }

        if let Some(ref popup) = self.popup {
            if popup.surface.wl_surface() == layer.wl_surface() {
                info!("Layer surface closed by compositor: popup '{}'", popup.id);
                self.popup = None;
                return;
            }
        }

        if let Some(ref dock) = self.dock {
            if dock.surface.wl_surface() == layer.wl_surface() {
                info!("Layer surface closed by compositor: dock");
                self.dock = None;
                return;
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

        for bar in &mut self.bars {
            if bar.surface.wl_surface() == layer.wl_surface() {
                if new_width > 0 {
                    bar.width = new_width;
                }
                if new_height > 0 {
                    bar.height = new_height;
                }
                if let Some(ref mut egl_surf) = bar.egl_surface {
                    egl_surf.resize(bar.width, bar.height);
                }
                bar.configured = true;
                bar.computed_boxes.clear();
                bar.damage_ring.reset();
                info!("Bar surface configured on '{}': {}x{}", bar.output_name, bar.width, bar.height);
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
                if let Some(ref mut egl_surf) = popup.egl_surface {
                    egl_surf.resize(popup.width, popup.height);
                }
                popup.configured = true;
                popup.computed_boxes.clear();
                popup.damage_ring.reset();
                info!("Popup surface configured '{}': {}x{}", popup.id, popup.width, popup.height);
                if let Err(e) = self.draw_popup() {
                    error!("Failed to render popup buffer on configure: {}", e);
                }
                return;
            }
        }

        if let Some(ref mut dock) = self.dock {
            if dock.surface.wl_surface() == layer.wl_surface() {
                if new_width > 0 {
                    dock.width = new_width;
                }
                if new_height > 0 {
                    dock.height = new_height;
                }
                if let Some(ref mut egl_surf) = dock.egl_surface {
                    egl_surf.resize(dock.width, dock.height);
                }
                dock.configured = true;
                dock.computed_boxes.clear();
                dock.damage_ring.reset();
                info!("Dock surface configured: {}x{}", dock.width, dock.height);
                if !self.dock_hidden {
                    let _ = self.reload_dock();
                } else if let Err(e) = self.draw_dock() {
                    error!("Failed to render dock buffer on configure: {}", e);
                }
            }
        }
    }
}

/// Verifies user authentication password using system unix_chkpwd helper.
fn get_current_username() -> Option<String> {
    std::env::var("USER")
        .or_else(|_| std::env::var("LOGNAME"))
        .ok()
        .filter(|u| !u.is_empty())
        .or_else(|| {
            std::process::Command::new("id")
                .arg("-un")
                .output()
                .ok()
                .and_then(|out| {
                    if out.status.success() {
                        String::from_utf8(out.stdout).ok().map(|s| s.trim().to_string())
                    } else {
                        None
                    }
                })
        })
}

/// Verifies user authentication password using system unix_chkpwd helper.
/// Runs in a worker thread with timeout to prevent main event loop deadlocks.
pub fn verify_pam_password(password: &str) -> bool {
    let pwd = password.to_string();
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let res = verify_pam_password_sync(&pwd);
        let _ = tx.send(res);
    });

    rx.recv_timeout(std::time::Duration::from_secs(3)).unwrap_or(false)
}

fn verify_pam_password_sync(password: &str) -> bool {
    let user = match get_current_username() {
        Some(u) => u,
        None => {
            tracing::error!("Could not resolve active username for PAM authentication");
            return false;
        }
    };

    let chkpwd_paths = [
        "/run/wrappers/bin/unix_chkpwd",
        "/usr/sbin/unix_chkpwd",
        "/sbin/unix_chkpwd",
        "unix_chkpwd",
    ];

    for path in &chkpwd_paths {
        if let Ok(mut child) = std::process::Command::new(path)
            .arg(&user)
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn()
        {
            if let Some(mut stdin) = child.stdin.take() {
                use std::io::Write;
                let _ = stdin.write_all(password.as_bytes());
                let _ = stdin.write_all(b"\0");
                let _ = stdin.flush();
            }
            if let Ok(status) = child.wait() {
                return status.success();
            }
        }
    }

    false
}

#[cfg(test)]
mod tests {
    use crate::WaylandApp;
    use zenith_layout::{Color, ComputedBox, ComputedSlider, ComputedSwitch, LayoutEngine, NodeStyle, UiNode};

    #[test]
    fn test_switch_toggle_interaction() {
        let sw = ComputedSwitch {
            id: Some("toggle_wifi".to_string()),
            checked: false,
            active_color: Color::rgb(124, 77, 255),
            inactive_color: Color::rgba(255, 255, 255, 50),
            thumb_color: Color::rgb(255, 255, 255),
            on_toggle: Some("wifi_changed".to_string()),
        };

        let mut b = ComputedBox {
            x: 10.0,
            y: 20.0,
            width: 50.0,
            height: 26.0,
            background_color: Color::transparent(),
            border_color: Color::transparent(),
            border_width: 0.0,
            border_radius: 13.0,
            shadow: None,
            custom_shader: None,
            text: None,
            image: None,
            text_input: None,
            slider: None,
            switch: Some(sw),
            overflow: zenith_layout::Overflow::Visible,
            scroll_offset_y: 0.0,
            clip_rect: None,
            on_click: Some("wifi_changed".to_string()),
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
            tooltip_active: false,
        };

        // Click inside switch bounds (25.0, 30.0)
        let px = 25.0;
        let py = 30.0;
        assert!(px >= b.x as f64 && px <= (b.x + b.width) as f64);
        assert!(py >= b.y as f64 && py <= (b.y + b.height) as f64);

        if let Some(ref mut s) = b.switch {
            s.checked = !s.checked;
            assert!(s.checked);
        }

        // Second click toggles back to false
        if let Some(ref mut s) = b.switch {
            s.checked = !s.checked;
            assert!(!s.checked);
        }
    }

    #[test]
    fn test_slider_click_and_drag_math() {
        let sl = ComputedSlider {
            id: Some("volume_slider".to_string()),
            min: 0.0,
            max: 100.0,
            value: 20.0,
            track_height: 6.0,
            thumb_radius: 10.0,
            track_color: Color::rgba(255, 255, 255, 50),
            active_track_color: Color::rgb(124, 77, 255),
            thumb_color: Color::rgb(255, 255, 255),
            on_change: Some("on_volume".to_string()),
        };

        let b = ComputedBox {
            x: 100.0,
            y: 50.0,
            width: 200.0,
            height: 30.0,
            background_color: Color::transparent(),
            border_color: Color::transparent(),
            border_width: 0.0,
            border_radius: 0.0,
            shadow: None,
            custom_shader: None,
            text: None,
            image: None,
            text_input: None,
            slider: Some(sl),
            switch: None,
            overflow: zenith_layout::Overflow::Visible,
            scroll_offset_y: 0.0,
            clip_rect: None,
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
            tooltip_active: false,
        };

        let sl_ref = b.slider.as_ref().unwrap();

        // Click at middle (px = 200.0 -> rel_x = 100.0)
        let px = 200.0;
        let rel_x = (px - b.x as f64).clamp(0.0, b.width as f64) as f32;
        let fraction = rel_x / b.width;
        let new_val = fraction * (sl_ref.max - sl_ref.min) + sl_ref.min;
        assert_eq!(new_val, 50.0);

        // Drag to 75% (px = 250.0 -> rel_x = 150.0)
        let px_drag = 250.0;
        let rel_x_drag = (px_drag - b.x as f64).clamp(0.0, b.width as f64) as f32;
        let fraction_drag = rel_x_drag / b.width;
        let val_drag = fraction_drag * (sl_ref.max - sl_ref.min) + sl_ref.min;
        assert_eq!(val_drag, 75.0);

        // Clamp below left edge (px = 50.0 < 100.0)
        let px_under = 50.0;
        let rel_x_under = (px_under - b.x as f64).clamp(0.0, b.width as f64) as f32;
        assert_eq!(rel_x_under, 0.0);

        // Clamp beyond right edge (px = 350.0 > 300.0)
        let px_over = 350.0;
        let rel_x_over = (px_over - b.x as f64).clamp(0.0, b.width as f64) as f32;
        assert_eq!(rel_x_over, 200.0);
    }

    #[test]
    fn test_layout_maps_switch_on_toggle_to_on_click() {
        let mut engine = LayoutEngine::new();
        let node = UiNode::Switch {
            id: Some("sw1".to_string()),
            checked: true,
            active_color: Color::rgb(10, 20, 30),
            inactive_color: Color::rgb(40, 50, 60),
            thumb_color: Color::rgb(255, 255, 255),
            style: NodeStyle {
                width: Some(zenith_layout::length(60.0)),
                height: Some(zenith_layout::length(30.0)),
                ..Default::default()
            },
            on_toggle: Some("my_toggle_action".to_string()),
        };

        let boxes = engine.compute(&node, 800.0, 600.0);
        assert_eq!(boxes.len(), 1);
        let b = &boxes[0];
        assert_eq!(b.on_click.as_deref(), Some("my_toggle_action"));
        assert!(b.switch.is_some());
        assert!(b.switch.as_ref().unwrap().checked);
    }

    #[test]
    fn test_autohide_settings_resolution() {
        let bar_hide = WaylandApp::read_bar_autohide_setting();
        assert!(bar_hide, "Bar autohide should resolve to true by default");
        let dock_hide = WaylandApp::read_dock_autohide_setting();
        assert!(dock_hide, "Dock autohide should resolve to true by default");
    }

    #[test]
    fn test_idle_manager_state_and_animation_pausing() {
        let mut idle_mgr = crate::idle::IdleManager::new();
        assert!(!idle_mgr.is_idle());
        assert!(!idle_mgr.is_inhibited());
        assert!(!idle_mgr.should_pause_animations());

        // Compositor fires idled event
        idle_mgr.on_idled(42);
        assert!(idle_mgr.is_idle());
        assert!(idle_mgr.should_pause_animations());

        // Inhibit idle (e.g., media playback started)
        idle_mgr.active_inhibitors.insert("media_playback".to_string());
        assert!(idle_mgr.is_inhibited());
        // Animations should not pause while inhibited
        assert!(!idle_mgr.should_pause_animations());

        // Uninhibit
        assert!(idle_mgr.uninhibit_idle("media_playback"));
        assert!(!idle_mgr.is_inhibited());
        assert!(idle_mgr.should_pause_animations());

        // User moves mouse -> resumed event
        idle_mgr.on_resumed(42);
        assert!(!idle_mgr.is_idle());
        assert!(!idle_mgr.should_pause_animations());
    }

    #[test]
    fn test_runtime_idle_signals_and_storage_sync() {
        let runtime = zenith_runtime::LuauRuntime::new().expect("LuauRuntime creation failed");
        assert!(!runtime.is_idle());

        // Set idle to true
        runtime.set_idle(true);
        assert!(runtime.is_idle());
        let storage_val = runtime.storage.get("system_idle").expect("system_idle not in storage");
        assert_eq!(storage_val, serde_json::Value::Bool(true));

        let activity_val = runtime.storage.get("system_activity").expect("system_activity not in storage");
        assert_eq!(activity_val, serde_json::Value::Bool(false));

        // Evaluate Luau signal
        let is_idle_luau = runtime.eval_code("return Zenith.Signals.is_idle()").expect("eval is_idle");
        assert_eq!(is_idle_luau.trim(), "true");

        // Resume activity
        runtime.set_idle(false);
        assert!(!runtime.is_idle());
        let is_idle_luau2 = runtime.eval_code("return Zenith.Signals.is_idle()").expect("eval is_idle");
        assert_eq!(is_idle_luau2.trim(), "false");
    }
}