//! Zenith Runtime - Luau VM integration and declarative UI parsing via mlua.

use mlua::prelude::*;
use tracing::info;
use zenith_layout::{Color, FlexDirection, NodeStyle, ShadowStyle, UiNode};

/// Runtime environment executing user Luau configs.
pub struct LuauRuntime {
    lua: Lua,
}

impl LuauRuntime {
    /// Initialize the Luau virtual machine with Zenith standard library bindings.
    pub fn new() -> Result<Self, LuaError> {
        let lua = Lua::new();

        // Inject global `Zenith` module
        let zenith_table = lua.create_table()?;

        // Zenith.rgba(r, g, b, a)
        let rgba_fn = lua.create_function(|lua, (r, g, b, a): (u8, u8, u8, Option<u8>)| {
            let table = lua.create_table()?;
            table.set("__type", "Color")?;
            table.set("r", r)?;
            table.set("g", g)?;
            table.set("b", b)?;
            table.set("a", a.unwrap_or(255))?;
            Ok(table)
        })?;
        zenith_table.set("rgba", rgba_fn)?;

        // Zenith.hex(str)
        let hex_fn = lua.create_function(|lua, hex: String| {
            let table = lua.create_table()?;
            let hex_clean = hex.trim_start_matches('#');
            let (r, g, b, a) = if hex_clean.len() == 6 {
                let r = u8::from_str_radix(&hex_clean[0..2], 16).unwrap_or(0);
                let g = u8::from_str_radix(&hex_clean[2..4], 16).unwrap_or(0);
                let b = u8::from_str_radix(&hex_clean[4..6], 16).unwrap_or(0);
                (r, g, b, 255)
            } else if hex_clean.len() == 8 {
                let r = u8::from_str_radix(&hex_clean[0..2], 16).unwrap_or(0);
                let g = u8::from_str_radix(&hex_clean[2..4], 16).unwrap_or(0);
                let b = u8::from_str_radix(&hex_clean[4..6], 16).unwrap_or(0);
                let a = u8::from_str_radix(&hex_clean[6..8], 16).unwrap_or(255);
                (r, g, b, a)
            } else {
                (255, 255, 255, 255)
            };
            table.set("__type", "Color")?;
            table.set("r", r)?;
            table.set("g", g)?;
            table.set("b", b)?;
            table.set("a", a)?;
            Ok(table)
        })?;
        zenith_table.set("hex", hex_fn)?;

        // Zenith.Box(props)
        let box_fn = lua.create_function(|_, props: LuaTable| {
            props.set("__type", "Box")?;
            Ok(props)
        })?;
        zenith_table.set("Box", box_fn)?;

        // Zenith.Window(props)
        let window_fn = lua.create_function(|_, props: LuaTable| {
            props.set("__type", "Window")?;
            Ok(props)
        })?;
        zenith_table.set("Window", window_fn)?;

        // Zenith.Spring(initial, target, stiffness, damping)
        let spring_fn = lua.create_function(|lua, (initial, target, stiffness, damping): (f32, f32, Option<f32>, Option<f32>)| {
            let mut anim = zenith_core::SpringAnimation::new(initial, target);
            if let Some(k) = stiffness {
                anim.config.stiffness = k;
            }
            if let Some(c) = damping {
                anim.config.damping = c;
            }
            let table = lua.create_table()?;
            table.set("current", anim.current)?;
            table.set("target", anim.target)?;
            table.set("is_settled", anim.is_settled())?;
            Ok(table)
        })?;
        zenith_table.set("Spring", spring_fn)?;

        // Zenith.Text(props)
        let text_fn = lua.create_function(|_, props: LuaTable| {
            props.set("__type", "Text")?;
            Ok(props)
        })?;
        zenith_table.set("Text", text_fn)?;

        // Zenith.Services
        let services_table = lua.create_table()?;

        let time_fn = lua.create_function(|_, ()| {
            let (time_str, date_str) = zenith_services::SystemService::current_time();
            Ok((time_str, date_str))
        })?;
        services_table.set("time", time_fn)?;

        let memory_fn = lua.create_function(|lua, ()| {
            let snap = zenith_services::SystemService::memory_snapshot();
            let tbl = lua.create_table()?;
            tbl.set("total_mb", snap.total_mb)?;
            tbl.set("used_mb", snap.used_mb)?;
            tbl.set("available_mb", snap.available_mb)?;
            tbl.set("percent", snap.percent)?;
            Ok(tbl)
        })?;
        services_table.set("memory", memory_fn)?;

        let battery_fn = lua.create_function(|lua, ()| {
            if let Some(bat) = zenith_services::SystemService::battery_snapshot() {
                let tbl = lua.create_table()?;
                tbl.set("percentage", bat.percentage)?;
                tbl.set("status", bat.status)?;
                tbl.set("is_charging", bat.is_charging)?;
                Ok(Some(tbl))
            } else {
                Ok(None)
            }
        })?;
        services_table.set("battery", battery_fn)?;

        let compositor_fn = lua.create_function(|_, ()| {
            Ok(zenith_services::SystemService::compositor_info())
        })?;
        services_table.set("compositor", compositor_fn)?;

        // Audio volume snapshot
        let audio_fn = lua.create_function(|lua, ()| {
            let snap = zenith_services::SystemService::audio_snapshot();
            let tbl = lua.create_table()?;
            tbl.set("volume", snap.volume)?;
            tbl.set("is_muted", snap.is_muted)?;
            Ok(tbl)
        })?;
        services_table.set("audio", audio_fn)?;

        // Network snapshot
        let network_fn = lua.create_function(|lua, ()| {
            let snap = zenith_services::SystemService::network_snapshot();
            let tbl = lua.create_table()?;
            tbl.set("is_connected", snap.is_connected)?;
            tbl.set("type", snap.connection_type)?;
            tbl.set("ssid", snap.ssid)?;
            Ok(tbl)
        })?;
        services_table.set("network", network_fn)?;

        // CPU load snapshot
        let cpu_fn = lua.create_function(|lua, ()| {
            let snap = zenith_services::SystemService::cpu_snapshot();
            let tbl = lua.create_table()?;
            tbl.set("percent", snap.percent)?;
            Ok(tbl)
        })?;
        services_table.set("cpu", cpu_fn)?;


        // Theme palette query
        let theme_fn = lua.create_function(|lua, ()| {
            let palette = zenith_services::SystemService::load_theme();
            let tbl = lua.create_table()?;
            tbl.set("background", palette.background)?;
            tbl.set("primary", palette.primary)?;
            tbl.set("surface", palette.surface)?;
            tbl.set("on_surface", palette.on_surface)?;
            tbl.set("on_primary", palette.on_primary)?;
            tbl.set("outline", palette.outline)?;
            tbl.set("surface_container", palette.surface_container)?;
            Ok(tbl)
        })?;
        services_table.set("theme", theme_fn.clone())?;

        // Svg rasterizer
        let render_svg_fn = lua.create_function(|_, (svg_str, w, h): (String, u32, u32)| {
            match zenith_services::SystemService::render_svg(&svg_str, w, h) {
                Ok(bytes) => Ok(Some(bytes.len())),
                Err(e) => {
                    tracing::error!("SVG render error: {}", e);
                    Ok(None)
                }
            }
        })?;
        services_table.set("render_svg", render_svg_fn)?;

        // Hyprland / Compositor Workspaces service
        let workspaces_fn = lua.create_function(|lua, ()| {
            let snap = zenith_services::HyprlandService::workspaces_snapshot();
            let tbl = lua.create_table()?;
            tbl.set("active", snap.active)?;
            let ws_tbl = lua.create_table()?;
            for (i, ws) in snap.workspaces.into_iter().enumerate() {
                let item = lua.create_table()?;
                item.set("id", ws.id)?;
                item.set("name", ws.name)?;
                item.set("active", ws.active)?;
                item.set("urgent", ws.urgent)?;
                item.set("windows", ws.windows)?;
                ws_tbl.raw_set(i + 1, item)?;
            }
            tbl.set("workspaces", ws_tbl)?;
            Ok(tbl)
        })?;
        services_table.set("Workspaces", workspaces_fn.clone())?;
        services_table.set("workspaces", workspaces_fn)?;

        // Hyprland / Compositor ActiveWindow service
        let active_window_fn = lua.create_function(|lua, ()| {
            let snap = zenith_services::HyprlandService::active_window_snapshot();
            let tbl = lua.create_table()?;
            tbl.set("title", snap.title)?;
            tbl.set("class", snap.class)?;
            Ok(tbl)
        })?;
        services_table.set("ActiveWindow", active_window_fn.clone())?;
        services_table.set("active_window", active_window_fn.clone())?;
        services_table.set("activewindow", active_window_fn)?;

        // Hyprland / Compositor Clients service
        let clients_fn = lua.create_function(|lua, ()| {
            let list = zenith_services::HyprlandService::clients_snapshot();
            let tbl = lua.create_table()?;
            for (idx, c) in list.into_iter().enumerate() {
                let item = lua.create_table()?;
                item.set("address", c.address)?;
                item.set("title", c.title)?;
                item.set("class", c.class)?;
                item.set("initial_class", c.initial_class)?;
                item.set("workspace_id", c.workspace_id)?;
                item.set("workspace_name", c.workspace_name)?;
                item.set("floating", c.floating)?;
                item.set("fullscreen", c.fullscreen)?;
                item.set("pid", c.pid)?;
                tbl.set(idx + 1, item)?;
            }
            Ok(tbl)
        })?;
        services_table.set("Clients", clients_fn.clone())?;
        services_table.set("clients", clients_fn)?;

        let focus_window_fn = lua.create_function(|_, address: String| {
            let _ = zenith_services::HyprlandService::focus_window(&address);
            Ok(())
        })?;
        services_table.set("FocusWindow", focus_window_fn.clone())?;
        services_table.set("focus_window", focus_window_fn.clone())?;
        zenith_table.set("focus_window", focus_window_fn)?;

        // Desktop Application Launcher service
        let launcher_fn = lua.create_function(|lua, (query, limit): (Option<String>, Option<usize>)| {
            let q = query.unwrap_or_default();
            let lim = limit.unwrap_or(30);
            let apps = zenith_services::LauncherService::search(&q, lim);
            let tbl = lua.create_table()?;
            for (idx, app) in apps.into_iter().enumerate() {
                let app_tbl = lua.create_table()?;
                app_tbl.set("id", app.id)?;
                app_tbl.set("name", app.name)?;
                app_tbl.set("comment", app.comment)?;
                app_tbl.set("exec", app.exec)?;
                app_tbl.set("icon", app.icon)?;
                tbl.set(idx + 1, app_tbl)?;
            }
            Ok(tbl)
        })?;
        services_table.set("Launcher", launcher_fn.clone())?;
        services_table.set("launcher", launcher_fn)?;

        let launch_fn = lua.create_function(|_, exec_cmd: String| {
            let _ = zenith_services::LauncherService::launch(&exec_cmd);
            Ok(())
        })?;
        services_table.set("Launch", launch_fn.clone())?;
        services_table.set("launch", launch_fn.clone())?;
        zenith_table.set("launch", launch_fn)?;

        // MPRIS2 Media Player service
        let media_fn = lua.create_function(|lua, ()| {
            let snap = zenith_services::MprisService::snapshot();
            let tbl = lua.create_table()?;
            tbl.set("is_available", snap.is_available)?;
            tbl.set("player_name", snap.player_name)?;
            tbl.set("status", snap.status)?;
            tbl.set("title", snap.title)?;
            tbl.set("artist", snap.artist)?;
            tbl.set("album", snap.album)?;
            tbl.set("art_url", snap.art_url)?;
            tbl.set("length", snap.length_seconds)?;
            Ok(tbl)
        })?;
        services_table.set("Media", media_fn.clone())?;
        services_table.set("media", media_fn)?;

        let media_control_fn = lua.create_function(|_, cmd: String| {
            let _ = zenith_services::MprisService::control(&cmd);
            Ok(())
        })?;
        services_table.set("MediaControl", media_control_fn.clone())?;
        services_table.set("media_control", media_control_fn.clone())?;
        zenith_table.set("media_control", media_control_fn)?;

        // Desktop Notifications Daemon service
        let notifications_fn = lua.create_function(|lua, ()| {
            let list = zenith_services::NotificationService::list_active();
            let tbl = lua.create_table()?;
            for (idx, n) in list.into_iter().enumerate() {
                let item = lua.create_table()?;
                item.set("id", n.id)?;
                item.set("app_name", n.app_name)?;
                item.set("app_icon", n.app_icon)?;
                item.set("summary", n.summary)?;
                item.set("body", n.body)?;
                item.set("urgency", n.urgency)?;
                item.set("timestamp", n.timestamp_secs)?;
                tbl.set(idx + 1, item)?;
            }
            Ok(tbl)
        })?;
        services_table.set("Notifications", notifications_fn.clone())?;
        services_table.set("notifications", notifications_fn)?;

        let notif_close_fn = lua.create_function(|_, id: u32| {
            zenith_services::NotificationService::close(id);
            Ok(())
        })?;
        services_table.set("NotificationClose", notif_close_fn.clone())?;
        services_table.set("notification_close", notif_close_fn)?;

        let notif_clear_fn = lua.create_function(|_, ()| {
            zenith_services::NotificationService::clear_all();
            Ok(())
        })?;
        services_table.set("NotificationClear", notif_clear_fn.clone())?;
        services_table.set("notification_clear", notif_clear_fn)?;

        let notify_fn = lua.create_function(|_, (summary, body, app_name): (String, Option<String>, Option<String>)| {
            let id = zenith_services::NotificationService::notify(
                app_name.unwrap_or_else(|| "Zenith".to_string()),
                0,
                "".to_string(),
                summary,
                body.unwrap_or_default(),
                vec![],
                1,
                5000,
            );
            Ok(id)
        })?;
        zenith_table.set("notify", notify_fn)?;

        zenith_table.set("Services", services_table)?;
        zenith_table.set("Theme", theme_fn)?;

        // Zenith.dispatch(dispatcher, arg)
        let dispatch_fn = lua.create_function(|_, (dispatcher, arg): (String, LuaValue)| {
            let arg_str = match arg {
                LuaValue::String(s) => s.to_str()?.to_string(),
                LuaValue::Integer(i) => i.to_string(),
                LuaValue::Number(n) => (n as i64).to_string(),
                LuaValue::Boolean(b) => b.to_string(),
                _ => String::new(),
            };
            if let Err(e) = zenith_services::HyprlandService::dispatch(&dispatcher, &arg_str) {
                tracing::error!("Zenith.dispatch error: {}", e);
            }
            Ok(())
        })?;
        zenith_table.set("dispatch", dispatch_fn)?;

        // Zenith.exec(command)
        let exec_fn = lua.create_function(|_, cmd: String| {
            let _ = std::process::Command::new("sh")
                .arg("-c")
                .arg(&cmd)
                .spawn();
            Ok(())
        })?;
        zenith_table.set("exec", exec_fn)?;

        // Zenith.import(module_path)
        let import_fn = lua.create_function(|lua, path: String| {
            let mut candidates = vec![
                format!("{}.luau", path),
                format!("{}.lua", path),
                format!("config/zenith/{}.luau", path),
                format!("config/zenith/{}.lua", path),
                format!("config/zenith/lib/{}.luau", path),
                format!("config/zenith/lib/{}.lua", path),
                format!("config/zenith/overlays/{}.luau", path),
                format!("config/zenith/overlays/{}.lua", path),
                format!("../../config/zenith/{}.luau", path),
                format!("../../config/zenith/{}.lua", path),
                format!("../../config/zenith/lib/{}.luau", path),
                format!("../../config/zenith/lib/{}.lua", path),
                format!("../../config/zenith/overlays/{}.luau", path),
                format!("../../config/zenith/overlays/{}.lua", path),
            ];

            if let Ok(home) = std::env::var("HOME") {
                candidates.push(format!("{}/.config/zenith/{}.luau", home, path));
                candidates.push(format!("{}/.config/zenith/{}.lua", home, path));
                candidates.push(format!("{}/.config/zenith/lib/{}.luau", home, path));
                candidates.push(format!("{}/.config/zenith/lib/{}.lua", home, path));
                candidates.push(format!("{}/.config/zenith/overlays/{}.luau", home, path));
                candidates.push(format!("{}/.config/zenith/overlays/{}.lua", home, path));
            }

            let mut resolved_content = None;
            for candidate in &candidates {
                if let Ok(content) = std::fs::read_to_string(candidate) {
                    resolved_content = Some(content);
                    break;
                }
            }

            if let Some(content) = resolved_content {
                let chunk = lua.load(&content);
                let val: LuaValue = chunk.eval()?;
                Ok(val)
            } else {
                Err(LuaError::runtime(format!("Cannot resolve Zenith module '{}'", path)))
            }
        })?;
        zenith_table.set("import", import_fn)?;

        let callbacks_table = lua.create_table()?;
        lua.globals().set("__zenith_callbacks", callbacks_table)?;

        lua.globals().set("Zenith", zenith_table)?;

        info!("Luau Runtime initialized successfully");
        Ok(Self { lua })
    }


    /// Load and evaluate a Luau script string, returning the root UI node.
    pub fn eval_ui(&self, script: &str) -> Result<UiNode, LuaError> {
        let val: LuaValue = self.lua.load(script).eval()?;
        match val {
            LuaValue::Table(tbl) => Self::parse_ui_node(&self.lua, &tbl),
            _ => Err(LuaError::runtime("Script must return a Zenith UI node table")),
        }
    }

    /// Trigger a registered click action by command or function key.
    pub fn trigger_click(&self, action: &str) -> Result<(), LuaError> {
        if action.starts_with("dispatch:") {
            let rest = &action[9..];
            let (dispatcher, arg) = rest.split_once(':').unwrap_or((rest, ""));
            if let Err(e) = zenith_services::HyprlandService::dispatch(dispatcher, arg) {
                tracing::error!("Failed to dispatch action {}: {}", action, e);
            }
        } else if action.starts_with("focus:") {
            let addr = &action[6..];
            let _ = zenith_services::HyprlandService::focus_window(addr);
        } else if action.starts_with("cmd:") {
            let cmd = &action[4..];
            let _ = std::process::Command::new("sh").arg("-c").arg(cmd).spawn();
        } else if action.starts_with("launch:") {
            let cmd = &action[7..];
            let _ = zenith_services::LauncherService::launch(cmd);
        } else if action.starts_with("media:") {
            let cmd = &action[6..];
            let _ = zenith_services::MprisService::control(cmd);
        } else if action.starts_with("notification:close:") {
            let id_str = &action[19..];
            if let Ok(id) = id_str.parse::<u32>() {
                zenith_services::NotificationService::close(id);
            }
        } else if action == "notification:clear" {
            zenith_services::NotificationService::clear_all();
        } else if action.starts_with("click_") {
            if let Ok(callbacks) = self.lua.globals().get::<LuaTable>("__zenith_callbacks") {
                if let Ok(func) = callbacks.get::<LuaFunction>(action) {
                    func.call::<()>(())?;
                    return Ok(());
                }
            }
            let _ = std::process::Command::new("sh").arg("-c").arg(action).spawn();
        } else {
            // Check if action corresponds to a shell command directly
            let _ = std::process::Command::new("sh").arg("-c").arg(action).spawn();
        }
        Ok(())
    }

    fn parse_ui_node(lua: &Lua, tbl: &LuaTable) -> Result<UiNode, LuaError> {
        let node_type: String = tbl.get("__type").unwrap_or_else(|_| "Box".to_string());
        let style = Self::parse_style(tbl)?;

        if node_type == "Text" {
            let text: String = tbl.get("text").unwrap_or_default();
            let font_size: f32 = tbl.get("font_size").unwrap_or(14.0);
            let color = tbl.get("color").map(|c: LuaTable| Self::parse_color(&c)).unwrap_or(Color::rgb(255, 255, 255));

            Ok(UiNode::Text {
                text,
                font_size,
                color,
                style,
            })
        } else {
            let mut children = Vec::new();
            if let Ok(child_tbl) = tbl.get::<LuaTable>("children") {
                for pair in child_tbl.sequence_values::<LuaTable>() {
                    if let Ok(child) = pair {
                        children.push(Self::parse_ui_node(lua, &child)?);
                    }
                }
            }

            let on_click: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_click") {
                static CB_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("click_{}", id);
                if let Ok(callbacks) = lua.globals().get::<LuaTable>("__zenith_callbacks") {
                    let _ = callbacks.set(key.clone(), func);
                }
                Some(key)
            } else {
                tbl.get::<String>("on_click").ok()
            };

            Ok(UiNode::Box { style, children, on_click })
        }
    }

    fn parse_style(tbl: &LuaTable) -> Result<NodeStyle, LuaError> {
        let mut style = NodeStyle::default();

        if let Ok(w) = tbl.get::<f32>("width") {
            style.width = Some(w);
        }
        if let Ok(h) = tbl.get::<f32>("height") {
            style.height = Some(h);
        }

        if let Ok(dir) = tbl.get::<String>("direction") {
            if dir == "column" {
                style.flex_direction = FlexDirection::Column;
            }
        }

        if let Ok(grow) = tbl.get::<f32>("flex_grow") {
            style.flex_grow = grow;
        }


        if let Ok(gap) = tbl.get::<f32>("gap") {

            style.gap = gap;
        }

        if let Ok(pad) = tbl.get::<f32>("padding") {
            style.padding = [pad, pad, pad, pad];
        } else if let Ok(pad_tbl) = tbl.get::<LuaTable>("padding") {
            let x: f32 = pad_tbl.get("x").unwrap_or(0.0);
            let y: f32 = pad_tbl.get("y").unwrap_or(0.0);
            style.padding = [y, x, y, x];
        }

        if let Ok(radius) = tbl.get::<f32>("border_radius") {
            style.border_radius = radius;
        }

        if let Ok(bg_tbl) = tbl.get::<LuaTable>("background") {
            style.background_color = Self::parse_color(&bg_tbl);
        }

        if let Ok(border_tbl) = tbl.get::<LuaTable>("border_color") {
            style.border_color = Self::parse_color(&border_tbl);
        }

        if let Ok(bw) = tbl.get::<f32>("border_width") {
            style.border_width = bw;
        }

        if let Ok(shadow_tbl) = tbl.get::<LuaTable>("shadow") {
            let color = shadow_tbl
                .get("color")
                .map(|c: LuaTable| Self::parse_color(&c))
                .unwrap_or(Color::rgba(0, 0, 0, 80));
            let blur = shadow_tbl.get::<f32>("blur").unwrap_or(8.0);
            let offset_x = shadow_tbl.get::<f32>("offset_x").unwrap_or(0.0);
            let offset_y = shadow_tbl.get::<f32>("offset_y").unwrap_or(4.0);
            style.shadow = Some(ShadowStyle {
                color,
                blur,
                offset_x,
                offset_y,
            });
        }

        Ok(style)
    }

    fn parse_color(tbl: &LuaTable) -> Color {
        let r: u8 = tbl.get("r").unwrap_or(0);
        let g: u8 = tbl.get("g").unwrap_or(0);
        let b: u8 = tbl.get("b").unwrap_or(0);
        let a: u8 = tbl.get("a").unwrap_or(255);
        Color::rgba(r, g, b, a)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_workspaces_and_active_window_luau() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let script = r#"
            local ws = Zenith.Services.Workspaces()
            local win = Zenith.Services.ActiveWindow()
            assert(ws.active ~= nil, "ws.active should not be nil")
            assert(#ws.workspaces >= 1, "ws.workspaces should have items")
            assert(win.class ~= nil, "win.class should not be nil")

            Zenith.dispatch("workspace", 2)
            local ws2 = Zenith.Services.Workspaces()
            assert(ws2.active == 2, "active workspace should be 2 after dispatch")

            return Zenith.Box({
                children = {
                    Zenith.Text({ text = win.title })
                }
            })
        "#;
        let node = runtime.eval_ui(script).expect("eval_ui failed");
        match node {
            UiNode::Box { children, .. } => {
                assert_eq!(children.len(), 1);
            }
            _ => panic!("Expected Box node"),
        }
    }

    #[test]
    fn test_bar_config_evaluation() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let path = std::path::Path::new("config/zenith/bar.luau");
        let parent_path = std::path::Path::new("../../config/zenith/bar.luau");
        let code = std::fs::read_to_string(path)
            .or_else(|_| std::fs::read_to_string(parent_path))
            .expect("Could not read config/zenith/bar.luau");
        let node = runtime.eval_ui(&code).expect("Evaluating bar.luau failed");
        match node {
            UiNode::Box { children, .. } => {
                assert!(!children.is_empty(), "bar.luau should produce non-empty children");
            }
            _ => panic!("bar.luau root must be a Box node"),
        }
    }

    #[test]
    fn test_overlays_evaluation() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let overlays = [
            "AudioPopup",
            "NetworkPopup",
            "CalendarPopup",
            "PowerMenu",
            "Launcher",
            "MediaPopup",
            "OSD",
            "NotificationCenter",
            "Dock",
            "DynamicIsland",
            "DesktopCanvas",
        ];
        for name in &overlays {
            let path = format!("config/zenith/overlays/{}.luau", name);
            let parent_path = format!("../../config/zenith/overlays/{}.luau", name);
            let code = std::fs::read_to_string(&path)
                .or_else(|_| std::fs::read_to_string(&parent_path))
                .unwrap_or_else(|_| panic!("Could not read overlay {}", name));
            let res = runtime.eval_ui(&code);
            assert!(res.is_ok(), "Evaluating overlay {} failed: {:?}", name, res.err());
        }
    }

    #[test]
    fn test_shadow_parsing() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let script = r#"
            return Zenith.Box {
                width = 200,
                height = 100,
                shadow = {
                    color = Zenith.rgba(0, 0, 0, 100),
                    blur = 12,
                    offset_x = 2,
                    offset_y = 6,
                },
                children = {}
            }
        "#;
        let node = runtime.eval_ui(script).expect("eval_ui failed");
        match node {
            UiNode::Box { style, .. } => {
                let s = style.shadow.expect("Shadow should be parsed");
                assert_eq!(s.blur, 12.0);
                assert_eq!(s.offset_x, 2.0);
                assert_eq!(s.offset_y, 6.0);
                assert_eq!(s.color.a, 100);
            }
            _ => panic!("Expected Box node"),
        }
    }

    #[test]
    fn test_launcher_service_luau() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let script = r#"
            local apps = Zenith.Services.Launcher("", 5)
            assert(type(apps) == "table", "Launcher must return a table")
            return Zenith.Box {
                children = {}
            }
        "#;
        let node = runtime.eval_ui(script);
        assert!(node.is_ok(), "Launcher Luau evaluation should succeed: {:?}", node.err());
    }

    #[test]
    fn test_media_service_luau() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let script = r#"
            local media = Zenith.Services.Media()
            assert(type(media) == "table", "Media must return a table")
            assert(type(media.status) == "string", "Media status must be a string")
            return Zenith.Box {
                children = {}
            }
        "#;
        let node = runtime.eval_ui(script);
        assert!(node.is_ok(), "Media Luau evaluation should succeed: {:?}", node.err());
    }

    #[test]
    fn test_notifications_service_luau() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let script = r#"
            local id = Zenith.notify("Test Notification", "Hello from Luau test", "ZenithTest")
            assert(type(id) == "number", "Zenith.notify must return an id")

            local list = Zenith.Services.Notifications()
            assert(type(list) == "table", "Notifications must return a table")
            assert(#list >= 1, "List must contain at least 1 notification")
            assert(list[1].summary == "Test Notification", "Summary mismatch")

            Zenith.Services.NotificationClose(id)
            return Zenith.Box {
                children = {}
            }
        "#;
        let node = runtime.eval_ui(script);
        assert!(node.is_ok(), "Notifications Luau evaluation should succeed: {:?}", node.err());
    }

    #[test]
    fn test_clients_service_luau() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let script = r#"
            local clients = Zenith.Services.Clients()
            assert(type(clients) == "table", "Clients must return a table")
            assert(#clients >= 1, "Clients list must have at least 1 entry")
            assert(type(clients[1].address) == "string", "Client address must be string")
            assert(type(clients[1].class) == "string", "Client class must be string")

            Zenith.focus_window(clients[1].address)
            return Zenith.Box {
                children = {}
            }
        "#;
        let node = runtime.eval_ui(script);
        assert!(node.is_ok(), "Clients Luau evaluation should succeed: {:?}", node.err());
    }
}
