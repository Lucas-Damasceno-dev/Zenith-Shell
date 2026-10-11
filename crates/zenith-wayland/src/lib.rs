//! Zenith Wayland - Protocol bindings and layer-shell integration.

use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState},
    delegate_compositor, delegate_keyboard, delegate_layer, delegate_output, delegate_pointer,
    delegate_registry, delegate_seat, delegate_shm,
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
};
use tracing::{error, info};
use wayland_client::{
    globals::registry_queue_init,
    protocol::{wl_keyboard, wl_output, wl_shm, wl_surface},
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
    pub script: String,
    pub surface: LayerSurface,
    pub width: u32,
    pub height: u32,
    pub configured: bool,
    pub root_ui: UiNode,
    pub computed_boxes: Vec<zenith_layout::ComputedBox>,
    pub canvas_cache: Vec<u8>,
    pub spring: Option<zenith_core::SpringAnimation>,
    pub closing: bool,
}

/// Individual Layer Shell bar window instance attached to a Wayland output.
pub struct BarInstance {
    pub output: Option<wl_output::WlOutput>,
    pub output_name: String,
    pub surface: LayerSurface,
    pub width: u32,
    pub height: u32,
    pub configured: bool,
    pub computed_boxes: Vec<zenith_layout::ComputedBox>,
    pub canvas_cache: Vec<u8>,
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
            bars: Vec::new(),
            bar_surface: None,
            popup: None,
            dock: None,
            dock_autohide: true,
            dock_hovered: false,
            dock_hidden: false,
            dock_last_leave: None,
            bar_autohide: true,
            bar_hovered: false,
            bar_hidden: false,
            bar_last_leave: None,
            pointer: None,
            keyboard: None,
            pointer_pos: (0.0, 0.0),
            computed_boxes: Vec::new(),
            width: 1920,
            height: 44,
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
            qh: qh.clone(),
        };

        app.create_bar(&qh)?;

        Ok((app, conn, event_queue))
    }

    /// Creates a layer surface bar for a specific Wayland output (or default if None).
    pub fn create_bar_for_output(
        &mut self,
        output: Option<&wl_output::WlOutput>,
        output_name: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let autohide = Self::read_bar_autohide_setting();
        self.bar_autohide = autohide;
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

        let initial_exclusive = if autohide { 0 } else { self.height as i32 };

        layer_surface.set_anchor(Anchor::TOP | Anchor::LEFT | Anchor::RIGHT);
        layer_surface.set_size(0, self.height);
        layer_surface.set_exclusive_zone(initial_exclusive);
        layer_surface.set_keyboard_interactivity(KeyboardInteractivity::None);

        // Bar spans the full screen width (edge-to-edge status bar)
        layer_surface.set_margin(0, 0, 0, 0);

        layer_surface.commit();
        info!("Layer surface created for zenith-bar on output '{}' (height={}, autohide={})", output_name, self.height, autohide);

        self.bars.push(BarInstance {
            output: output.cloned(),
            output_name: output_name.to_string(),
            surface: layer_surface,
            width: self.width,
            height: self.height,
            configured: false,
            computed_boxes: Vec::new(),
            canvas_cache: Vec::new(),
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

    /// Requests an optimized redraw of the active bar and popup surfaces without reloading scripts from disk.
    pub fn request_redraw(&mut self) -> Result<(), Box<dyn std::error::Error>> {
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
        Ok(())
    }

    /// Re-evaluates Luau script and updates the UI tree on hot-reload.
    pub fn reload_script(&mut self, script: &str) -> Result<(), Box<dyn std::error::Error>> {
        self.runtime.clear_module_cache();
        self.bar_script = script.to_string();
        self.request_redraw()
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
            "dock" => ("Dock", Anchor::BOTTOM, 640, 68, 0, 0, 12, 0),
            "island" | "dynamicisland" => ("DynamicIsland", Anchor::TOP, 380, 52, 8, 0, 0, 0),
            "launcher" => ("Launcher", Anchor::TOP, 520, 620, 16, 0, 0, 0),
            "media" | "mediapopup" => ("MediaPopup", Anchor::TOP, 360, 360, 8, 0, 0, 0),
            "notifications" | "notificationcenter" => ("NotificationCenter", Anchor::TOP | Anchor::RIGHT, 420, 600, 8, 14, 0, 0),
            "audio" | "audiopopup" => ("AudioPopup", Anchor::TOP | Anchor::RIGHT, 360, 480, 8, 14, 0, 0),
            "network" | "networkpopup" => ("NetworkPopup", Anchor::TOP | Anchor::RIGHT, 380, 500, 8, 14, 0, 0),
            "bluetooth" | "bluetoothpopup" => ("BluetoothPopup", Anchor::TOP | Anchor::RIGHT, 380, 460, 8, 14, 0, 0),
            "calendar" | "calendarpopup" => ("CalendarPopup", Anchor::TOP, 360, 360, 8, 0, 0, 0),
            "power" | "powermenu" => ("PowerMenu", Anchor::TOP | Anchor::RIGHT, 300, 260, 8, 14, 0, 0),
            "osd" => ("OSD", Anchor::TOP, 280, 110, 60, 0, 0, 0),
            "canvas" | "desktopcanvas" => ("DesktopCanvas", Anchor::TOP | Anchor::LEFT, 380, 340, 16, 0, 0, 24),
            "settings" | "settingsmenu" => ("Settings", Anchor::TOP, 760, 580, 16, 0, 0, 0),
            "lock" | "lockscreen" => ("LockScreen", Anchor::TOP | Anchor::BOTTOM | Anchor::LEFT | Anchor::RIGHT, 0, 0, 0, 0, 0, 0),
            _ => (id, Anchor::TOP | Anchor::RIGHT, 340, 380, 8, 14, 0, 0),
        };

        let candidates = [
            format!("config/zenith/overlays/{}.luau", script_name),
            format!("config/zenith/overlays/{}.lua", script_name),
            format!("config/zenith/overlays/{}Popup.luau", script_name),
            format!("config/zenith/overlays/{}.luau", id),
            format!("config/zenith/{}.luau", script_name.to_lowercase()),
            format!("../../config/zenith/overlays/{}.luau", script_name),
            format!("../../config/zenith/overlays/{}.luau", id),
            format!("/home/lucas/Documents/03_Desenvolvimento/code/projects/personal/portfolio/desktop/Zenith-Shell/config/zenith/overlays/{}.luau", script_name),
            format!("/home/lucas/Documents/03_Desenvolvimento/code/projects/personal/portfolio/desktop/Zenith-Shell/config/zenith/overlays/{}.luau", id),
            format!("/home/lucas/.config/zenith/overlays/{}.luau", script_name),
            format!("/home/lucas/.config/zenith/overlays/{}.luau", id),
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

        self.runtime.set_search_query("");
        self.runtime.set_selected_index(1);

        let is_lock = id.eq_ignore_ascii_case("lock") || id.eq_ignore_ascii_case("lockscreen");
        if is_lock {
            width = self.screen_width.max(1366);
            height = self.screen_height.max(768);
            self.runtime.set_current_output_geometry("default", width, height);
        }

        let root_ui = self.runtime.eval_ui(&content)?;

        // Apply dynamic window metadata if defined in the Luau script
        let (mut anchor, mut margin_top, mut margin_right, mut margin_bottom, mut margin_left) = (anchor, margin_top, margin_right, margin_bottom, margin_left);
        let mut layer_level = if is_lock { Layer::Overlay } else { Layer::Top };
        let mut kb_mode = if is_lock { KeyboardInteractivity::Exclusive } else { KeyboardInteractivity::OnDemand };
        let mut exclusive = if id.eq_ignore_ascii_case("dock") { 68 } else { 0 };

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
                    "overlay" => Layer::Overlay,
                    "bottom" => Layer::Bottom,
                    "background" => Layer::Background,
                    _ => Layer::Top,
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
            }
        }

        // Ensure layer surface is large enough to contain root window + drop shadows
        if !is_lock {
            match &root_ui {
                UiNode::Box { style, .. } | UiNode::Window { style, .. } => {
                    if let Some(w) = style.width {
                        width = width.max(w.ceil() as u32 + 24);
                    }
                    if let Some(h) = style.height {
                        height = height.max(h.ceil() as u32 + 30);
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
            Some(zenith_core::SpringAnimation::new(0.0, 1.0))
        };

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
            spring,
            closing: false,
        });

        Ok(())
    }

    /// Re-evaluates open popup Luau script with current reactive state and redraws.
    pub fn reload_popup(&mut self, _id: &str) -> Result<(), Box<dyn std::error::Error>> {
        let script = match self.popup.as_ref() {
            Some(p) => p.script.clone(),
            None => return Ok(()),
        };

        let root_ui = self.runtime.eval_ui(&script)?;
        if let Some(ref mut popup) = self.popup {
            popup.root_ui = root_ui;
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
            } else {
                let mut anim = zenith_core::SpringAnimation::new(1.0, 0.0);
                anim.config.stiffness = 320.0;
                anim.config.damping = 28.0;
                popup.spring = Some(anim);
            }
            popup.surface.wl_surface().frame(&self.qh, popup.surface.wl_surface().clone());
            let _ = self.draw_popup();
        }
    }

    /// Reads bar auto-hide preference from zenith config.json.
    pub fn read_bar_autohide_setting() -> bool {
        let home_cfg = std::env::var("HOME").ok().map(|h| std::path::PathBuf::from(h).join(".config/zenith/config.json"));
        let mut config_paths = vec![
            std::path::PathBuf::from("config/zenith/config.json"),
            std::path::PathBuf::from("../../config/zenith/config.json"),
        ];
        if let Some(p) = home_cfg {
            config_paths.push(p);
        }

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

    /// Evaluates whether the top bar should automatically hide based on overlapping windows.
    pub fn should_bar_hide(&self) -> bool {
        if !self.bar_autohide {
            return false;
        }
        if self.bar_hovered {
            return false;
        }
        if self.popup.is_some() {
            return false;
        }
        if let Some(leave_time) = self.bar_last_leave {
            if leave_time.elapsed() < std::time::Duration::from_millis(300) {
                return false;
            }
        }

        let ws = zenith_services::HyprlandService::workspaces_snapshot();
        let active_ws = ws.active;
        let clients = zenith_services::HyprlandService::clients_snapshot();

        for c in clients {
            if c.workspace_id != active_ws {
                continue;
            }
            if c.fullscreen {
                return true;
            }
            if !c.floating {
                return true;
            }
            // Floating window overlapping the bar area at top: y <= 44 + gaps
            if c.at.1 <= 54 {
                return true;
            }
        }

        false
    }

    /// Updates the bar surface geometry and visibility based on intelligent auto-hide and dynamic window resizing.
    pub fn update_bar_visibility(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let should_hide = self.should_bar_hide();
        let autohide = self.bar_autohide;
        let is_hidden = self.bar_hidden;

        if !autohide {
            if is_hidden {
                self.bar_hidden = false;
                for bar in &mut self.bars {
                    bar.computed_boxes.clear();
                    bar.surface.set_size(0, 44);
                    bar.surface.set_exclusive_zone(44);
                    bar.surface.commit();
                    bar.surface.wl_surface().commit();
                }
                self.draw()?;
            }
            return Ok(());
        }

        if should_hide && !is_hidden {
            self.bar_hidden = true;
            for bar in &mut self.bars {
                bar.computed_boxes.clear();
                bar.surface.set_size(0, 6);
                bar.surface.set_exclusive_zone(0);
                bar.surface.commit();
                bar.surface.wl_surface().commit();
            }
            self.draw()?;
        } else if !should_hide && is_hidden {
            self.bar_hidden = false;
            for bar in &mut self.bars {
                bar.computed_boxes.clear();
                bar.surface.set_size(0, 44);
                bar.surface.set_exclusive_zone(44);
                bar.surface.commit();
                bar.surface.wl_surface().commit();
            }
            self.draw()?;
        }

        Ok(())
    }

    /// Reads dock auto-hide preference from zenith config.json.
    pub fn read_dock_autohide_setting() -> bool {
        let home_cfg = std::env::var("HOME").ok().map(|h| std::path::PathBuf::from(h).join(".config/zenith/config.json"));
        let mut config_paths = vec![
            std::path::PathBuf::from("config/zenith/config.json"),
            std::path::PathBuf::from("../../config/zenith/config.json"),
        ];
        if let Some(p) = home_cfg {
            config_paths.push(p);
        }

        config_paths
            .iter()
            .find_map(|p| {
                std::fs::read_to_string(p)
                    .ok()
                    .and_then(|c| serde_json::from_str::<serde_json::Value>(&c).ok())
                    .and_then(|v| {
                        let d = v.get("dock")?;
                        d.get("hoverToReveal").or_else(|| d.get("autoHide")).and_then(|b| b.as_bool())
                    })
            })
            .unwrap_or(true)
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
            if leave_time.elapsed() < std::time::Duration::from_millis(300) {
                return false;
            }
        }

        let ws = zenith_services::HyprlandService::workspaces_snapshot();
        let active_ws = ws.active;
        let clients = zenith_services::HyprlandService::clients_snapshot();

        let dock_top = (self.screen_height.saturating_sub(60)) as i32;

        for c in clients {
            if c.workspace_id != active_ws {
                continue;
            }
            if c.fullscreen {
                return true;
            }
            if !c.floating {
                return true;
            }
            let win_bottom = c.at.1 + c.size.1;
            if win_bottom >= dock_top {
                return true;
            }
        }

        false
    }

    /// Updates the dock surface geometry and visibility based on intelligent auto-hide and dynamic window resizing.
    pub fn update_dock_visibility(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let should_hide = self.should_dock_hide();
        let autohide = self.dock_autohide;
        let is_hidden = self.dock_hidden;

        if !autohide {
            if is_hidden {
                self.dock_hidden = false;
                if let Some(ref mut dock) = self.dock {
                    dock.computed_boxes.clear();
                    dock.surface.set_size(540, 60);
                    dock.surface.set_margin(0, 0, 0, 0);
                    dock.surface.set_exclusive_zone(60);
                    dock.surface.commit();
                    dock.surface.wl_surface().commit();
                }
                self.draw_dock()?;
            }
            return Ok(());
        }

        if should_hide && !is_hidden {
            self.dock_hidden = true;
            if let Some(ref mut dock) = self.dock {
                dock.computed_boxes.clear();
                dock.surface.set_size(540, 8);
                dock.surface.set_margin(0, 0, 0, 0);
                dock.surface.set_exclusive_zone(0);
                dock.surface.commit();
                dock.surface.wl_surface().commit();
            }
            self.draw_dock()?;
        } else if !should_hide && is_hidden {
            self.dock_hidden = false;
            if let Some(ref mut dock) = self.dock {
                dock.computed_boxes.clear();
                dock.surface.set_size(540, 60);
                dock.surface.set_margin(0, 0, 0, 0);
                dock.surface.set_exclusive_zone(60);
                dock.surface.commit();
                dock.surface.wl_surface().commit();
            }
            self.draw_dock()?;
        }

        Ok(())
    }

    /// Opens the persistent dock layer surface.
    pub fn open_dock(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if self.dock.is_some() {
            return Ok(());
        }

        let candidates = [
            "config/zenith/overlays/Dock.luau".to_string(),
            "config/zenith/overlays/Dock.lua".to_string(),
            format!("{}/.config/zenith/overlays/Dock.luau", std::env::var("HOME").unwrap_or_default()),
            "/home/lucas/Documents/03_Desenvolvimento/code/projects/personal/portfolio/desktop/Zenith-Shell/config/zenith/overlays/Dock.luau".to_string(),
        ];

        let mut script_content = None;
        for c in &candidates {
            if let Ok(content) = std::fs::read_to_string(c) {
                script_content = Some(content);
                break;
            }
        }

        let content = script_content.ok_or("Cannot find Dock.luau overlay script")?;
        let root_ui = self.runtime.eval_ui(&content)?;

        let width = 540u32;
        let height = 60u32;
        let margin_bottom = 0i32;

        let autohide = Self::read_dock_autohide_setting();
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

        layer_surface.set_anchor(Anchor::BOTTOM);
        layer_surface.set_margin(0, 0, margin_bottom, 0);
        layer_surface.set_size(width, height);
        let exclusive_zone = if autohide { 0 } else { 60 };
        layer_surface.set_exclusive_zone(exclusive_zone);
        layer_surface.set_keyboard_interactivity(KeyboardInteractivity::None);
        layer_surface.commit();

        layer_surface.wl_surface().frame(&self.qh, layer_surface.wl_surface().clone());
        layer_surface.commit();

        info!("Created dock layer surface ({}x{}, autohide={})", width, height, autohide);

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
            spring: None,
            closing: false,
        });

        let _ = self.update_dock_visibility();

        Ok(())
    }

    /// Renders the persistent dock layer surface into SHM buffer.
    pub fn draw_dock(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let is_hidden = self.dock_hidden;
        let dock = match self.dock.as_mut() {
            Some(d) if d.configured => d,
            _ => return Ok(()),
        };

        let width = dock.width.max(1);
        let height = dock.height.max(1);
        let stride = width * 4;
        let target_len = (width * height * 4) as usize;

        if is_hidden || height <= 12 {
            if dock.canvas_cache.len() != target_len {
                dock.canvas_cache = vec![0u8; target_len];
            } else {
                dock.canvas_cache.fill(0);
            }

            {
                if let Some(mut pixmap) = tiny_skia::PixmapMut::from_bytes(&mut dock.canvas_cache, width, height) {
                    let pill_w = 96.0f32;
                    let pill_h = 2.0f32;
                    let pill_x = (width as f32 - pill_w) * 0.5;
                    let pill_y = (height as f32 - pill_h).max(0.0);
                    if let Some(path) = Self::build_rounded_rect_path(pill_x, pill_y, pill_w, pill_h, 1.0) {
                        let mut paint = tiny_skia::Paint::default();
                        paint.set_color_rgba8(130, 170, 255, 120);
                        paint.anti_alias = true;
                        pixmap.fill_path(&path, &paint, tiny_skia::FillRule::Winding, tiny_skia::Transform::identity(), None);
                    }
                }
            }

            let (buffer, canvas) = self.pool.create_buffer(
                width as i32,
                height as i32,
                stride as i32,
                wl_shm::Format::Argb8888,
            )?;

            let copy_len = canvas.len().min(dock.canvas_cache.len());
            canvas[..copy_len].copy_from_slice(&dock.canvas_cache[..copy_len]);

            buffer.attach_to(dock.surface.wl_surface())?;
            dock.surface.wl_surface().damage_buffer(0, 0, width as i32, height as i32);
            dock.surface.commit();

            return Ok(());
        }

        let new_boxes = self.layout_engine.compute(&dock.root_ui, width as f32, height as f32);
        let damage = Self::compute_damage_rect(&dock.computed_boxes, &new_boxes, width, height);

        if damage.is_none() && !dock.computed_boxes.is_empty() {
            return Ok(());
        }

        dock.computed_boxes = new_boxes;

        if dock.canvas_cache.len() != target_len {
            dock.canvas_cache = vec![0u8; target_len];
        } else {
            dock.canvas_cache.fill(0);
        }

        Self::render_boxes_to_canvas(
            &mut dock.canvas_cache,
            &dock.computed_boxes,
            width,
            height,
            1.0,
            &mut self.font_system,
            &mut self.swash_cache,
        )?;

        let (buffer, canvas) = self.pool.create_buffer(
            width as i32,
            height as i32,
            stride as i32,
            wl_shm::Format::Argb8888,
        )?;

        let copy_len = canvas.len().min(dock.canvas_cache.len());
        canvas[..copy_len].copy_from_slice(&dock.canvas_cache[..copy_len]);

        buffer.attach_to(dock.surface.wl_surface())?;
        let (dx, dy, dw, dh) = damage.unwrap_or((0, 0, width as i32, height as i32));
        dock.surface.wl_surface().damage_buffer(dx, dy, dw, dh);
        dock.surface.commit();

        Ok(())
    }

    /// Re-evaluates Dock.luau with latest state (e.g. clients) and redraws.
    pub fn reload_dock(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let script = match self.dock.as_ref() {
            Some(d) => d.script.clone(),
            None => return Ok(()),
        };

        let root_ui = self.runtime.eval_ui(&script)?;
        if let Some(ref mut dock) = self.dock {
            dock.root_ui = root_ui;
        }
        self.draw_dock()?;
        Ok(())
    }

    /// Destroys the persistent dock layer surface.
    pub fn destroy_dock(&mut self) {
        if let Some(dock) = self.dock.take() {
            dock.surface.wl_surface().destroy();
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
        } else if action == "popup:close" {
            self.close_popup();
        } else if action == "lock:unlock" {
            let query = self.runtime.get_search_query();
            if verify_pam_password(&query) {
                self.runtime.set_search_query("");
                let _ = zenith_services::HyprlandService::dispatch("submap", "reset");
                self.close_popup();
            } else {
                self.runtime.set_search_query("");
                if let Some(ref p) = self.popup {
                    let id = p.id.clone();
                    let _ = self.reload_popup(&id);
                    let _ = self.draw_popup();
                }
            }
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
        } else {
            // Dismiss popup on outside actions, except audio tweaks, media controls, dock, and notification actions
            if self.popup.is_some()
                && self.popup.as_ref().map(|p| p.id != "LockScreen" && p.id != "lock" && p.id != "dock").unwrap_or(true)
                && !action.starts_with("cmd:wpctl")
                && !action.starts_with("media:")
                && !action.starts_with("notification:")
                && !action.starts_with("audio:")
                && !action.starts_with("window:toggle_minimize:")
            {
                self.close_popup();
            }
            if let Err(e) = self.runtime.trigger_click(action) {
                error!("Error executing on_click action: {}", e);
            }
            if let Some(ref p) = self.popup {
                let id = p.id.clone();
                let _ = self.reload_popup(&id);
                let _ = self.draw_popup();
            }
            if self.dock.is_some() {
                let _ = self.reload_dock();
            }
            let _ = self.draw();
        }
    }

    /// Draw the computed Luau layout into the SHM buffer for all active bar outputs.
    pub fn draw(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let is_hidden = self.bar_hidden;
        for bar in &mut self.bars {
            if !bar.configured {
                continue;
            }

            let width = bar.width.max(1);
            let height = bar.height.max(1);
            let stride = width * 4;
            let target_len = (width * height * 4) as usize;

            if is_hidden || height <= 8 {
                bar.computed_boxes.clear();
                if bar.canvas_cache.len() != target_len {
                    bar.canvas_cache = vec![0u8; target_len];
                } else {
                    bar.canvas_cache.fill(0);
                }

                {
                    if let Some(mut pixmap) = tiny_skia::PixmapMut::from_bytes(&mut bar.canvas_cache, width, height) {
                        let line_w = (width as f32 * 0.25).clamp(80.0, 300.0);
                        let line_h = 2.0f32;
                        let line_x = (width as f32 - line_w) * 0.5;
                        if let Some(path) = Self::build_rounded_rect_path(line_x, 0.0, line_w, line_h, 1.0) {
                            let mut paint = tiny_skia::Paint::default();
                            paint.set_color_rgba8(130, 170, 255, 100);
                            paint.anti_alias = true;
                            pixmap.fill_path(&path, &paint, tiny_skia::FillRule::Winding, tiny_skia::Transform::identity(), None);
                        }
                    }
                }

                let (buffer, canvas) = self.pool.create_buffer(
                    width as i32,
                    height as i32,
                    stride as i32,
                    wl_shm::Format::Argb8888,
                )?;
                let copy_len = canvas.len().min(bar.canvas_cache.len());
                canvas[..copy_len].copy_from_slice(&bar.canvas_cache[..copy_len]);
                buffer.attach_to(bar.surface.wl_surface())?;
                bar.surface.wl_surface().damage_buffer(0, 0, width as i32, height as i32);
                bar.surface.commit();
                continue;
            }

            // Contextualize output and resolution geometry for responsive layout
            let screen_w = self.screen_width.max(1);
            let screen_h = self.screen_height.max(1);
            self.runtime.set_current_output_geometry(&bar.output_name, screen_w, screen_h);
            let bar_ui = self.runtime.eval_ui(&self.bar_script).unwrap_or_else(|_| self.root_ui.clone());

            // Compute Taffy layout on the Luau tree
            let new_boxes = self.layout_engine.compute(&bar_ui, width as f32, height as f32);
            let damage = Self::compute_damage_rect(&bar.computed_boxes, &new_boxes, width, height);

            // Frame-skip optimization: if nothing changed in the computed boxes, avoid redrawing and committing!
            if damage.is_none() && !bar.computed_boxes.is_empty() {
                continue;
            }

            bar.computed_boxes = new_boxes;

            if bar.canvas_cache.len() != target_len {
                bar.canvas_cache = vec![0u8; target_len];
            } else {
                bar.canvas_cache.fill(0);
            }

            // Rasterize directly onto clean shadow buffer
            Self::render_boxes_to_canvas(
                &mut bar.canvas_cache,
                &bar.computed_boxes,
                width,
                height,
                1.0,
                &mut self.font_system,
                &mut self.swash_cache,
            )?;

            let (buffer, canvas) = self.pool.create_buffer(
                width as i32,
                height as i32,
                stride as i32,
                wl_shm::Format::Argb8888,
            )?;

            // Blit persistent cache to SHM buffer in ~5 microseconds
            let copy_len = canvas.len().min(bar.canvas_cache.len());
            canvas[..copy_len].copy_from_slice(&bar.canvas_cache[..copy_len]);

            buffer.attach_to(bar.surface.wl_surface())?;
            let (dx, dy, dw, dh) = damage.unwrap_or((0, 0, width as i32, height as i32));
            bar.surface.wl_surface().damage_buffer(dx, dy, dw, dh);
            bar.surface.commit();
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
        let target_len = (width * height * 4) as usize;

        let (spring_val, is_animating) = if let Some(ref s) = popup.spring {
            (s.current, !s.is_settled())
        } else {
            (1.0, false)
        };

        if popup.closing && (spring_val <= 0.02 || !is_animating) {
            self.popup = None;
            return Ok(());
        }

        let new_boxes = self.layout_engine.compute(&popup.root_ui, width as f32, height as f32);
        let damage = if is_animating {
            Some((0, 0, width as i32, height as i32))
        } else {
            Self::compute_damage_rect(&popup.computed_boxes, &new_boxes, width, height)
        };

        // Frame-skip optimization: skip popup redraw if unchanged and not animating
        if !is_animating && damage.is_none() && !popup.computed_boxes.is_empty() {
            return Ok(());
        }

        popup.computed_boxes = new_boxes;

        if popup.canvas_cache.len() != target_len {
            popup.canvas_cache = vec![0u8; target_len];
        } else {
            popup.canvas_cache.fill(0);
        }

        Self::render_boxes_to_canvas(
            &mut popup.canvas_cache,
            &popup.computed_boxes,
            width,
            height,
            spring_val,
            &mut self.font_system,
            &mut self.swash_cache,
        )?;

        let (buffer, canvas) = self.pool.create_buffer(
            width as i32,
            height as i32,
            stride as i32,
            wl_shm::Format::Argb8888,
        )?;

        let copy_len = canvas.len().min(popup.canvas_cache.len());
        canvas[..copy_len].copy_from_slice(&popup.canvas_cache[..copy_len]);

        buffer.attach_to(popup.surface.wl_surface())?;
        if is_animating {
            popup.surface.wl_surface().frame(&self.qh, popup.surface.wl_surface().clone());
        }
        popup.surface.wl_surface().damage_buffer(0, 0, width as i32, height as i32);
        popup.surface.commit();

        Ok(())
    }

    fn compute_damage_rect(
        old_boxes: &[zenith_layout::ComputedBox],
        new_boxes: &[zenith_layout::ComputedBox],
        width: u32,
        height: u32,
    ) -> Option<(i32, i32, i32, i32)> {
        if old_boxes.is_empty() || old_boxes.len() != new_boxes.len() {
            return Some((0, 0, width as i32, height as i32));
        }

        let mut min_x = width as f32;
        let mut min_y = height as f32;
        let mut max_x = 0.0f32;
        let mut max_y = 0.0f32;
        let mut any_diff = false;

        for (old, new) in old_boxes.iter().zip(new_boxes.iter()) {
            if old != new {
                any_diff = true;
                let pad = 24.0f32;
                min_x = min_x.min(old.x - pad).min(new.x - pad);
                min_y = min_y.min(old.y - pad).min(new.y - pad);
                max_x = max_x.max(old.x + old.width + pad).max(new.x + new.width + pad);
                max_y = max_y.max(old.y + old.height + pad).max(new.y + new.height + pad);
            }
        }

        if any_diff {
            let x = (min_x.max(0.0).floor()) as i32;
            let y = (min_y.max(0.0).floor()) as i32;
            let w = ((max_x - min_x).ceil() as i32).min(width as i32 - x).max(1);
            let h = ((max_y - min_y).ceil() as i32).min(height as i32 - y).max(1);
            Some((x, y, w, h))
        } else {
            None
        }
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

    #[allow(clippy::too_many_arguments)]
    fn render_boxes_to_canvas(
        canvas: &mut [u8],
        boxes: &[zenith_layout::ComputedBox],
        width: u32,
        height: u32,
        spring_val: f32,
        font_system: &mut cosmic_text::FontSystem,
        swash_cache: &mut cosmic_text::SwashCache,
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

                // Render multi-pass soft vector drop shadow if configured
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

                    // Fill background with anti-aliasing
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

                        pixmap.stroke_path(
                            &path,
                            &stroke_paint,
                            &stroke,
                            tiny_skia::Transform::identity(),
                            None,
                        );
                    }

                    // Blit raster (PNG) or vector (SVG) image via ImageService
                    if let Some(ref src) = b.image {
                        let target_w = (box_w.round() as u32).max(1);
                        let target_h = (box_h.round() as u32).max(1);
                        if let Ok(decoded) = zenith_services::ImageService::load_image(src, Some(target_w), Some(target_h)) {
                            if let Some(src_pixmap) = tiny_skia::PixmapRef::from_bytes(&decoded.rgba, decoded.width, decoded.height) {
                                let scale_img_x = box_w / decoded.width as f32;
                                let scale_img_y = box_h / decoded.height as f32;
                                let transform = tiny_skia::Transform::from_translate(box_x, box_y)
                                    .pre_scale(scale_img_x, scale_img_y);
                                let paint = tiny_skia::PixmapPaint {
                                    opacity: alpha_factor,
                                    blend_mode: tiny_skia::BlendMode::SourceOver,
                                    quality: tiny_skia::FilterQuality::Bilinear,
                                };
                                pixmap.draw_pixmap(0, 0, src_pixmap, &paint, transform, None);
                            }
                        }
                    }

                    // For TextInput, draw active focus outline if focused
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
                }
            } // pixmap borrow of canvas is dropped here

        // Pass 2: Draw shaped glyphs with cosmic-text onto the anti-aliased canvas
        for b in boxes {
            if b.y >= root_max_y - 2.0 {
                continue;
            }

            let text_to_draw = if let Some((ref text, color, font_size)) = b.text {
                Some((text.clone(), color, font_size))
            } else if let Some(ref input) = b.text_input {
                let (txt, col) = if input.text.is_empty() {
                    (input.placeholder.clone(), input.placeholder_color)
                } else if input.active {
                    (format!("{}|", input.text), input.color)
                } else {
                    (input.text.clone(), input.color)
                };
                Some((txt, col, input.font_size))
            } else {
                None
            };

            if let Some((text, color, font_size)) = text_to_draw {
                let line_height = font_size * 1.3;
                let metrics = cosmic_text::Metrics::new(font_size, line_height);
                let mut buffer = cosmic_text::Buffer::new(font_system, metrics);
                let is_complex = text.chars().any(|c| c as u32 > 0x0600);
                let shaping = if is_complex { cosmic_text::Shaping::Advanced } else { cosmic_text::Shaping::Basic };
                buffer.set_text(
                    &text,
                    &cosmic_text::Attrs::new().family(cosmic_text::Family::Name("JetBrainsMono Nerd Font")),
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
                // Center text vertically inside its computed bounding box
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
                                let inv_a = 255 - alpha;

                                // Fast alpha blending without CPU division: (val * 257 + 257) >> 16
                                let out_r = ((fg_r * alpha + bg_r * inv_a + 128) * 257 >> 16) as u8;
                                let out_g = ((fg_g * alpha + bg_g * inv_a + 128) * 257 >> 16) as u8;
                                let out_b = ((fg_b * alpha + bg_b * inv_a + 128) * 257 >> 16) as u8;
                                let out_a = ((alpha * 255 + bg_a * inv_a + 128) * 257 >> 16) as u8;

                                canvas[idx] = out_b;
                                canvas[idx + 1] = out_g;
                                canvas[idx + 2] = out_r;
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

// SCTK Delegate implementations
delegate_compositor!(WaylandApp);
delegate_output!(WaylandApp);
delegate_shm!(WaylandApp);
delegate_layer!(WaylandApp);
delegate_seat!(WaylandApp);
delegate_pointer!(WaylandApp);
delegate_keyboard!(WaylandApp);
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
        }
        if capability == Capability::Keyboard {
            self.keyboard = None;
        }
    }

    fn remove_seat(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _seat: wayland_client::protocol::wl_seat::WlSeat,
    ) {
        self.pointer = None;
        self.keyboard = None;
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
                    let is_dock = self.dock.as_ref().map_or(false, |d| event.surface == *d.surface.wl_surface());
                    if is_dock {
                        self.dock_hovered = true;
                        self.dock_last_leave = None;
                        if self.dock_hidden {
                            let _ = self.update_dock_visibility();
                        }
                    }
                    let is_bar = self.bars.iter().any(|b| event.surface == *b.surface.wl_surface());
                    if is_bar {
                        self.bar_hovered = true;
                        self.bar_last_leave = None;
                        if self.bar_hidden {
                            let _ = self.update_bar_visibility();
                        }
                    }
                }
                PointerEventKind::Leave { .. } => {
                    let is_dock = self.dock.as_ref().map_or(false, |d| event.surface == *d.surface.wl_surface());
                    if is_dock {
                        self.dock_hovered = false;
                        self.dock_last_leave = Some(std::time::Instant::now());
                    }
                    let is_bar = self.bars.iter().any(|b| event.surface == *b.surface.wl_surface());
                    if is_bar {
                        self.bar_hovered = false;
                        self.bar_last_leave = Some(std::time::Instant::now());
                    }
                }
                PointerEventKind::Press { button, .. } if button == BTN_LEFT || button == BTN_RIGHT => {
                    let is_right = button == BTN_RIGHT;
                    let (px, py) = self.pointer_pos;
                    let mut target_action: Option<String> = None;

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
                    if let Some(ref popup) = self.popup {
                        if event.surface == *popup.surface.wl_surface() {
                            let mut clicked_box = false;
                            let mut focused_new_input: Option<String> = None;

                            for b in popup.computed_boxes.iter().rev() {
                                if px >= b.x as f64
                                    && px <= (b.x + b.width) as f64
                                    && py >= b.y as f64
                                    && py <= (b.y + b.height) as f64
                                {
                                    clicked_box = true;
                                    if let Some(ref input) = b.text_input {
                                        let id = input.id.clone().unwrap_or_else(|| "text_input".to_string());
                                        focused_new_input = Some(id);
                                        break;
                                    }

                                    let action_opt = if is_right { b.on_right_click.as_ref() } else { b.on_click.as_ref() };
                                    if let Some(action) = action_opt {
                                        target_action = Some(action.clone());
                                        break;
                                    }
                                }
                            }

                            if let Some(input_id) = focused_new_input {
                                self.runtime.set_focused_input(Some(input_id.clone()));
                                if let Some(ref mut p) = self.popup {
                                    for pb in p.computed_boxes.iter_mut() {
                                        if let Some(ref mut inp) = pb.text_input {
                                            inp.active = inp.id.as_deref() == Some(&input_id);
                                        }
                                    }
                                }
                                let _ = self.draw_popup();
                                return;
                            }

                            if let Some(action) = target_action {
                                self.execute_action(&action);
                            } else if !clicked_box && popup.id != "lock" && popup.id != "lockscreen" && popup.id != "dock" {
                                self.close_popup();
                            }
                            return;
                        }
                    }

                    // Check if click was on any status bar
                    for bar in &self.bars {
                        if event.surface == *bar.surface.wl_surface() {
                            if self.bar_hidden {
                                self.bar_hovered = true;
                                self.bar_last_leave = None;
                                let _ = self.update_bar_visibility();
                                return;
                            }
                            for b in bar.computed_boxes.iter().rev() {
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
                                if let Some(ref p) = self.popup {
                                    let toggle_needle = format!("popup:toggle:{}", p.id.to_lowercase());
                                    if !action.to_lowercase().contains(&toggle_needle)
                                        && p.id != "dock"
                                        && p.id != "lock"
                                        && p.id != "lockscreen"
                                    {
                                        self.close_popup();
                                    }
                                }
                                self.execute_action(&action);
                            } else if self.popup.is_some() && !is_right {
                                if self.popup.as_ref().map(|p| p.id != "dock" && p.id != "lock" && p.id != "lockscreen").unwrap_or(false) {
                                    self.close_popup();
                                }
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
                                        let delta = if is_up { -24.0 } else { 24.0 };
                                        b.scroll_offset_y = (b.scroll_offset_y + delta).max(0.0);
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
        if self.popup.is_none() {
            return;
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
                        let _ = self.draw_popup();
                        return;
                    }
                    Keysym::Return => {
                        let cur_txt = self.runtime.get_input_text(input_id);
                        if let Some(ref cb) = inp.on_submit {
                            let _ = self.runtime.trigger_callback_with_arg(cb, &cur_txt);
                        }
                        return;
                    }
                    Keysym::BackSpace => {
                        let mut cur_txt = self.runtime.get_input_text(input_id);
                        if cur_txt.is_empty() && !inp.text.is_empty() {
                            cur_txt = inp.text.clone();
                        }
                        if !cur_txt.is_empty() {
                            cur_txt.pop();
                            self.runtime.set_input_text(input_id, &cur_txt);
                            if let Some(ref cb) = inp.on_change {
                                let _ = self.runtime.trigger_callback_with_arg(cb, &cur_txt);
                            }
                            if let Some(ref mut popup) = self.popup {
                                for pb in popup.computed_boxes.iter_mut() {
                                    if let Some(ref mut pb_inp) = pb.text_input {
                                        if pb_inp.id.as_deref() == Some(input_id) {
                                            pb_inp.text = cur_txt.clone();
                                        }
                                    }
                                }
                            }
                            let _ = self.draw_popup();
                        }
                        return;
                    }
                    _ => {
                        if let Some(ref text) = event.utf8 {
                            let text = text.trim_matches(|c: char| c.is_control());
                            if !text.is_empty() {
                                let mut cur_txt = self.runtime.get_input_text(input_id);
                                if cur_txt.is_empty() && !inp.text.is_empty() {
                                    cur_txt = inp.text.clone();
                                }
                                cur_txt.push_str(text);
                                self.runtime.set_input_text(input_id, &cur_txt);
                                if let Some(ref cb) = inp.on_change {
                                    let _ = self.runtime.trigger_callback_with_arg(cb, &cur_txt);
                                }
                                if let Some(ref mut popup) = self.popup {
                                    for pb in popup.computed_boxes.iter_mut() {
                                        if let Some(ref mut pb_inp) = pb.text_input {
                                            if pb_inp.id.as_deref() == Some(input_id) {
                                                pb_inp.text = cur_txt.clone();
                                            }
                                        }
                                    }
                                }
                                let _ = self.draw_popup();
                                return;
                            }
                        }
                    }
                }
            }
        }

        let popup_id = self.popup.as_ref().unwrap().id.clone();

        match event.keysym {
            Keysym::Escape => {
                if !popup_id.eq_ignore_ascii_case("lock") && !popup_id.eq_ignore_ascii_case("lockscreen") {
                    self.close_popup();
                }
            }
            Keysym::Return => {
                if popup_id.eq_ignore_ascii_case("lock") || popup_id.eq_ignore_ascii_case("lockscreen") {
                    let query = self.runtime.get_search_query();
                    if verify_pam_password(&query) {
                        self.runtime.set_search_query("");
                        let _ = zenith_services::HyprlandService::dispatch("submap", "reset");
                        self.close_popup();
                    } else {
                        self.runtime.set_search_query("");
                        let _ = self.reload_popup(&popup_id);
                        let _ = self.draw_popup();
                    }
                    return;
                }
                if popup_id.eq_ignore_ascii_case("launcher") {
                    let selected_idx = self.runtime.get_selected_index();
                    let query = self.runtime.get_search_query();
                    let list = zenith_services::LauncherService::search(&query, 100);
                    if let Some(app) = list.get(selected_idx.saturating_sub(1)) {
                        let _ = zenith_services::LauncherService::launch(&app.exec);
                        self.close_popup();
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
                    let query = self.runtime.get_search_query();
                    zenith_services::LauncherService::search(&query, 100).len()
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
        _modifiers: Modifiers,
        _layout: u32,
    ) {}
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
        // Step active spring animations on popups
        if let Some(ref mut popup) = self.popup {
            if popup.surface.wl_surface() == surface {
                if let Some(ref mut anim) = popup.spring {
                    anim.step(0.016);
                    if popup.closing && (anim.is_settled() || anim.current <= 0.02) {
                        self.popup = None;
                        return;
                    }
                }
                let _ = self.draw_popup();
                return;
            }
        }

        // Active bar VSync sync
        for bar in &self.bars {
            if bar.surface.wl_surface() == surface {
                let _ = self.draw();
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

        if let Some(info) = self.output_state.info(&output) {
            if let Some((w, h)) = info.logical_size {
                if w > 0 && h > 0 {
                    self.screen_width = w as u32;
                    self.screen_height = h as u32;
                    self.runtime.set_current_output_geometry(&name, w as u32, h as u32);
                }
            }
        }

        // If we only had the unassigned default bar, assign this output to it
        if self.bars.len() == 1 && self.bars[0].output.is_none() {
            self.bars[0].output = Some(output.clone());
            self.bars[0].output_name = name.clone();
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
            if let Some((w, h)) = info.logical_size {
                if w > 0 && h > 0 {
                    self.screen_width = w as u32;
                    self.screen_height = h as u32;
                    self.runtime.set_current_output_geometry(name, w as u32, h as u32);
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
            info!("Layer surface closed by compositor on output '{}'", self.bars[pos].output_name);
            self.bars.remove(pos);
            if self.bars.is_empty() {
                self.running = false;
            }
            return;
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

        for bar in &mut self.bars {
            if bar.surface.wl_surface() == layer.wl_surface() {
                if new_width > 0 {
                    bar.width = new_width;
                }
                if new_height > 0 {
                    bar.height = new_height;
                }
                bar.configured = true;
                bar.computed_boxes.clear();
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
                popup.configured = true;
                popup.computed_boxes.clear();
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
                dock.configured = true;
                dock.computed_boxes.clear();
                info!("Dock surface configured: {}x{}", dock.width, dock.height);
                if let Err(e) = self.draw_dock() {
                    error!("Failed to render dock buffer on configure: {}", e);
                }
                return;
            }
        }
    }
}

/// Verifies user authentication password using system unix_chkpwd helper.
fn verify_pam_password(password: &str) -> bool {
    let user = std::env::var("USER").unwrap_or_else(|_| "lucas".to_string());
    let chkpwd_paths = [
        "/run/wrappers/bin/unix_chkpwd",
        "/usr/sbin/unix_chkpwd",
        "/sbin/unix_chkpwd",
        "unix_chkpwd",
    ];

    for path in &chkpwd_paths {
        if let Ok(mut child) = std::process::Command::new(path)
            .args([&user, "nullok"])
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
