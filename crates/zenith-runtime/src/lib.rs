use std::collections::HashMap;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, RwLock};

use mlua::prelude::*;
use tracing::info;
use zenith_layout::{AlignItems, Color, FlexDirection, JustifyContent, NodeStyle, ShadowStyle, UiNode};

pub mod async_bridge;
pub mod reactive;
pub mod spawner;
pub mod storage;
pub mod worker;
pub use async_bridge::{poll_async_completions, setup_async_bridge};
pub use reactive::{BoundProperty, EffectId, MountedTree, NodeBinding, ReactiveGraph, SignalId};
pub use spawner::{build_detached_command, parse_command_line, spawn_detached};
pub use storage::StorageEngine;
pub use worker::{TaskCompletion, TaskOutput, WorkerThreadPool};

/// Runtime environment executing user Luau configs.
pub struct LuauRuntime {
    lua: Lua,
    pub reactive: Arc<ReactiveGraph>,
    pub worker_pool: Arc<WorkerThreadPool>,
    pub storage: Arc<StorageEngine>,
    pub is_idle: Arc<AtomicBool>,
    search_query: Arc<RwLock<String>>,
    selected_index: Arc<RwLock<usize>>,
    current_output: Arc<RwLock<String>>,
    current_geometry: Arc<RwLock<(u32, u32)>>,
    script_cache: Arc<RwLock<HashMap<u64, mlua::RegistryKey>>>,
    focused_input_id: Arc<RwLock<Option<String>>>,
    input_buffers: Arc<RwLock<HashMap<String, String>>>,
    editor_engines: Arc<RwLock<HashMap<String, zenith_layout::TextEditorEngine>>>,
}

impl LuauRuntime {
    /// Initialize the Luau virtual machine with Zenith standard library bindings.
    pub fn new() -> Result<Self, LuaError> {
        let lua = Lua::new();
        let is_idle = Arc::new(AtomicBool::new(false));
        let storage = Arc::new(StorageEngine::new(None));
        let search_query = Arc::new(RwLock::new(String::new()));
        let selected_index = Arc::new(RwLock::new(1usize));
        let current_output = Arc::new(RwLock::new("default".to_string()));
        let current_geometry = Arc::new(RwLock::new((1366u32, 768u32)));
        let focused_input_id = Arc::new(RwLock::new(None));
        let input_buffers = Arc::new(RwLock::new(HashMap::new()));
        let editor_engines = Arc::new(RwLock::new(HashMap::new()));
        let reactive = Arc::new(crate::reactive::ReactiveGraph::new());

        // Inject global `Zenith` module
        let zenith_table = lua.create_table()?;

        let co_clone1 = current_output.clone();
        let get_co_fn = lua.create_function(move |_, ()| {
            let out = co_clone1.read().unwrap().clone();
            Ok(out)
        })?;
        zenith_table.set("current_output", get_co_fn.clone())?;
        zenith_table.set("get_current_output", get_co_fn)?;

        let co_clone2 = current_output.clone();
        let set_co_fn = lua.create_function(move |_, out: String| {
            *co_clone2.write().unwrap() = out;
            Ok(())
        })?;
        zenith_table.set("set_current_output", set_co_fn)?;

        let geom_clone1 = current_geometry.clone();
        let co_clone_screen = current_output.clone();
        let screen_fn = lua.create_function(move |lua, ()| {
            let tbl = lua.create_table()?;
            let (w, h) = *geom_clone1.read().unwrap();
            tbl.set("name", co_clone_screen.read().unwrap().clone())?;
            tbl.set("width", w)?;
            tbl.set("height", h)?;
            Ok(tbl)
        })?;
        zenith_table.set("Screen", screen_fn.clone())?;
        zenith_table.set("screen", screen_fn.clone())?;
        zenith_table.set("viewport", screen_fn)?;

        let sq_clone1 = search_query.clone();
        let get_sq_fn = lua.create_function(move |_, ()| {
            let q = sq_clone1.read().unwrap().clone();
            Ok(q)
        })?;
        zenith_table.set("get_search_query", get_sq_fn)?;

        let sq_clone2 = search_query.clone();
        let set_sq_fn = lua.create_function(move |_, q: String| {
            *sq_clone2.write().unwrap() = q;
            Ok(())
        })?;
        zenith_table.set("set_search_query", set_sq_fn)?;

        let si_clone1 = selected_index.clone();
        let get_si_fn = lua.create_function(move |_, ()| {
            let idx = *si_clone1.read().unwrap();
            Ok(idx)
        })?;
        zenith_table.set("get_selected_index", get_si_fn)?;

        let si_clone2 = selected_index.clone();
        let set_si_fn = lua.create_function(move |_, idx: usize| {
            *si_clone2.write().unwrap() = idx;
            Ok(())
        })?;
        zenith_table.set("set_selected_index", set_si_fn)?;

        let foc_clone1 = focused_input_id.clone();
        let get_foc_fn = lua.create_function(move |_, ()| {
            let id = foc_clone1.read().unwrap().clone();
            Ok(id)
        })?;
        zenith_table.set("get_focused_input", get_foc_fn.clone())?;
        zenith_table.set("get_focus", get_foc_fn)?;

        let foc_clone2 = focused_input_id.clone();
        let set_foc_fn = lua.create_function(move |_, id_opt: Option<String>| {
            *foc_clone2.write().unwrap() = id_opt;
            Ok(())
        })?;
        zenith_table.set("set_focused_input", set_foc_fn.clone())?;
        zenith_table.set("set_focus", set_foc_fn)?;

        let buf_clone1 = input_buffers.clone();
        let get_buf_fn = lua.create_function(move |_, id: String| {
            let text = buf_clone1.read().unwrap().get(&id).cloned().unwrap_or_default();
            Ok(text)
        })?;
        zenith_table.set("get_input_text", get_buf_fn)?;

        let buf_clone2 = input_buffers.clone();
        let set_buf_fn = lua.create_function(move |_, (id, text): (String, String)| {
            buf_clone2.write().unwrap().insert(id, text);
            Ok(())
        })?;
        zenith_table.set("set_input_text", set_buf_fn)?;

        let user_fn = lua.create_function(|_, ()| {
            let user = std::env::var("USER").unwrap_or_else(|_| "Zenith User".to_string());
            Ok(user)
        })?;
        zenith_table.set("user", user_fn.clone())?;
        zenith_table.set("User", user_fn)?;

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

        // Zenith.hex(str, alpha_override)
        let hex_fn = lua.create_function(|lua, (hex_opt, alpha_opt): (Option<String>, Option<u8>)| {
            let table = lua.create_table()?;
            let hex = hex_opt.unwrap_or_else(|| "#ffffff".to_string());
            let hex_clean = hex.trim_start_matches('#');
            let (r, g, b, mut a) = if hex_clean.len() == 6 {
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
            if let Some(alpha) = alpha_opt {
                a = alpha;
            }
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

        // Zenith.signal(initial_value) and Zenith.Signal
        let reactive_sig = reactive.clone();
        let signal_fn = lua.create_function(move |lua, initial: LuaValue| {
            let sig_id = crate::reactive::ReactiveGraph::next_signal_id();
            let sig_tbl = lua.create_table()?;
            sig_tbl.set("__type", "Signal")?;
            sig_tbl.set("__signal_id", sig_id)?;
            sig_tbl.set("value", initial.clone())?;

            let val_holder = std::rc::Rc::new(std::cell::RefCell::new(initial));

            let v1 = val_holder.clone();
            let r1 = reactive_sig.clone();
            let get_fn = lua.create_function(move |_, _self: Option<LuaValue>| {
                r1.track_access(sig_id);
                Ok(v1.borrow().clone())
            })?;
            sig_tbl.set("get", get_fn)?;

            let sig_clone = sig_tbl.clone();
            let v2 = val_holder.clone();
            let r2 = reactive_sig.clone();
            let set_fn = lua.create_function(move |lua, (first, second): (LuaValue, Option<LuaValue>)| {
                let new_val = second.unwrap_or(first);
                *v2.borrow_mut() = new_val.clone();
                let _ = sig_clone.set("value", new_val.clone());
                let str_repr = match &new_val {
                    LuaValue::String(s) => s.to_string_lossy(),
                    LuaValue::Integer(i) => i.to_string(),
                    LuaValue::Number(n) => n.to_string(),
                    LuaValue::Boolean(b) => b.to_string(),
                    _ => String::new(),
                };
                r2.notify_signal_change(lua, sig_id, &str_repr);
                Ok(())
            })?;
            sig_tbl.set("set", set_fn.clone())?;

            let v3 = val_holder.clone();
            let r3 = reactive_sig.clone();
            let call_fn = lua.create_function(move |_, _self: LuaValue| {
                r3.track_access(sig_id);
                Ok(v3.borrow().clone())
            })?;

            let v4 = val_holder.clone();
            let r4 = reactive_sig.clone();
            let index_fn = lua.create_function(move |_, (tbl, key): (LuaTable, String)| {
                if key == "value" {
                    r4.track_access(sig_id);
                    return Ok(v4.borrow().clone());
                }
                tbl.raw_get::<LuaValue>(key)
            })?;

            let mt = lua.create_table()?;
            mt.set("__call", call_fn)?;
            mt.set("__index", index_fn)?;
            let _ = sig_tbl.set_metatable(Some(mt));

            // Returns tuple (Signal, setter) per specification
            Ok(mlua::MultiValue::from_vec(vec![LuaValue::Table(sig_tbl), LuaValue::Function(set_fn)]))
        })?;
        zenith_table.set("Signal", signal_fn.clone())?;
        zenith_table.set("signal", signal_fn)?;

        // Zenith.effect(callback) and Zenith.Effect
        let reactive_eff = reactive.clone();
        let effect_fn = lua.create_function(move |lua, callback: LuaFunction| {
            reactive_eff.register_effect(lua, callback)?;
            Ok(())
        })?;
        zenith_table.set("Effect", effect_fn.clone())?;
        zenith_table.set("effect", effect_fn)?;

        // Zenith.Signals (reactive system getters)
        let signals_table = lua.create_table()?;
        let time_sig = lua.create_function(|_, ()| {
            let (t, _) = zenith_services::SystemService::current_time();
            Ok(t)
        })?;
        signals_table.set("Time", time_sig.clone())?;
        signals_table.set("time", time_sig)?;

        let date_sig = lua.create_function(|_, ()| {
            let (_, d) = zenith_services::SystemService::current_time();
            Ok(d)
        })?;
        signals_table.set("Date", date_sig.clone())?;
        signals_table.set("date", date_sig)?;

        let cpu_sig = lua.create_function(|_, ()| {
            let c = zenith_services::SystemService::cpu_snapshot();
            Ok(format!("{}%", c.percent))
        })?;
        signals_table.set("Cpu", cpu_sig.clone())?;
        signals_table.set("cpu", cpu_sig)?;

        let ram_sig = lua.create_function(|_, ()| {
            let m = zenith_services::SystemService::memory_snapshot();
            Ok(format!("{}%", m.percent))
        })?;
        signals_table.set("Memory", ram_sig.clone())?;
        signals_table.set("memory", ram_sig)?;

        let win_sig = lua.create_function(|_, ()| {
            let w = zenith_services::HyprlandService::active_window_snapshot();
            Ok(w.title)
        })?;
        signals_table.set("ActiveWindow", win_sig.clone())?;
        signals_table.set("active_window", win_sig)?;

        let bright_sig = lua.create_function(|_, ()| {
            let b = zenith_services::BrightnessService::get_brightness();
            Ok(format!("{}%", b.percent))
        })?;
        signals_table.set("Brightness", bright_sig.clone())?;
        signals_table.set("brightness", bright_sig)?;

        let idle_bool = is_idle.clone();
        let idle_sig = lua.create_function(move |_, ()| {
            Ok(idle_bool.load(Ordering::Relaxed))
        })?;
        signals_table.set("Idle", idle_sig.clone())?;
        signals_table.set("idle", idle_sig.clone())?;
        signals_table.set("IsIdle", idle_sig.clone())?;
        signals_table.set("is_idle", idle_sig)?;

        zenith_table.set("Signals", signals_table)?;

        // Zenith.Text(props)
        let text_fn = lua.create_function(|_, props: LuaTable| {
            props.set("__type", "Text")?;
            Ok(props)
        })?;
        zenith_table.set("Text", text_fn)?;

        // Zenith.TextInput(props)
        let text_input_fn = lua.create_function(|_, props: LuaTable| {
            props.set("__type", "TextInput")?;
            Ok(props)
        })?;
        zenith_table.set("TextInput", text_input_fn.clone())?;
        zenith_table.set("text_input", text_input_fn)?;

        // Zenith.Image(props)
        let image_fn = lua.create_function(|_, props: LuaTable| {
            props.set("__type", "Image")?;
            Ok(props)
        })?;
        zenith_table.set("Image", image_fn.clone())?;
        zenith_table.set("image", image_fn)?;

        // Zenith.Shader(props)
        let shader_fn = lua.create_function(|_, props: LuaTable| {
            props.set("__type", "Shader")?;
            Ok(props)
        })?;
        zenith_table.set("Shader", shader_fn.clone())?;
        zenith_table.set("shader", shader_fn)?;

        // Zenith.Slider(props)
        let slider_fn = lua.create_function(|_, props: LuaTable| {
            props.set("__type", "Slider")?;
            Ok(props)
        })?;
        zenith_table.set("Slider", slider_fn.clone())?;
        zenith_table.set("slider", slider_fn)?;

        // Zenith.Switch(props)
        let switch_fn = lua.create_function(|_, props: LuaTable| {
            props.set("__type", "Switch")?;
            Ok(props)
        })?;
        zenith_table.set("Switch", switch_fn.clone())?;
        zenith_table.set("switch", switch_fn)?;

        // Zenith.VirtualList(props)
        let virtual_list_fn = lua.create_function(|_, props: LuaTable| {
            props.set("__type", "VirtualList")?;
            Ok(props)
        })?;
        zenith_table.set("VirtualList", virtual_list_fn.clone())?;
        zenith_table.set("virtual_list", virtual_list_fn)?;

        // Zenith.Services
        let services_table = lua.create_table()?;

        let time_fn = lua.create_function(|_, ()| {
            let (time_str, date_str) = zenith_services::SystemService::current_time();
            Ok((time_str, date_str))
        })?;
        services_table.set("time", time_fn)?;

        let date_fn = lua.create_function(|lua, ()| {
            let (year, month, day, weekday) = zenith_services::SystemService::date_components();
            let tbl = lua.create_table()?;
            tbl.set("year", year)?;
            tbl.set("month", month)?;
            tbl.set("day", day)?;
            tbl.set("weekday", weekday)?;
            Ok(tbl)
        })?;
        services_table.set("date", date_fn)?;

        let memory_fn = lua.create_function(|lua, ()| {
            let snap = zenith_services::SystemService::memory_snapshot();
            let tbl = lua.create_table()?;
            tbl.set("total_mb", snap.total_mb)?;
            tbl.set("used_mb", snap.used_mb)?;
            tbl.set("available_mb", snap.available_mb)?;
            tbl.set("percent", snap.percent)?;
            Ok(tbl)
        })?;
        services_table.set("memory", memory_fn.clone())?;
        services_table.set("Memory", memory_fn)?;

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
        services_table.set("battery", battery_fn.clone())?;
        services_table.set("Battery", battery_fn)?;

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
            tbl.set("muted", snap.is_muted)?;
            Ok(tbl)
        })?;
        services_table.set("audio", audio_fn.clone())?;
        services_table.set("Audio", audio_fn)?;

        // Network snapshot
        let network_fn = lua.create_function(|lua, ()| {
            let snap = zenith_services::SystemService::network_snapshot();
            let tbl = lua.create_table()?;
            tbl.set("connected", snap.is_connected)?;
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
        services_table.set("cpu", cpu_fn.clone())?;
        services_table.set("Cpu", cpu_fn)?;


        // Theme palette query
        let theme_fn = lua.create_function(|lua, ()| {
            let palette = zenith_services::SystemService::load_theme();
            let tbl = lua.create_table()?;
            tbl.set("background", palette.background)?;
            tbl.set("primary", palette.primary.clone())?;
            tbl.set("surface", palette.surface)?;
            tbl.set("on_surface", palette.on_surface)?;
            tbl.set("on_primary", palette.on_primary)?;
            tbl.set("outline", palette.outline)?;
            tbl.set("outline_variant", palette.outline_variant)?;
            tbl.set("surface_container", palette.surface_container.clone())?;
            tbl.set("surface_container_high", palette.surface_container_high)?;
            tbl.set("surface_container_highest", palette.surface_container_highest)?;
            tbl.set("surface_container_low", palette.surface_container_low)?;
            tbl.set("surface_variant", palette.surface_variant)?;
            tbl.set("on_surface_variant", palette.on_surface_variant)?;
            tbl.set("secondary", palette.secondary)?;
            tbl.set("on_secondary", palette.on_secondary)?;
            tbl.set("tertiary", palette.tertiary)?;
            tbl.set("on_tertiary", palette.on_tertiary)?;
            tbl.set("error", palette.error.clone())?;
            tbl.set("primary_container", palette.surface_container)?;
            // Base16 colors
            tbl.set("base00", palette.base00)?;
            tbl.set("base01", palette.base01)?;
            tbl.set("base02", palette.base02)?;
            tbl.set("base03", palette.base03)?;
            tbl.set("base04", palette.base04)?;
            tbl.set("base05", palette.base05)?;
            tbl.set("base06", palette.base06)?;
            tbl.set("base07", palette.base07)?;
            tbl.set("base08", palette.base08)?;
            tbl.set("base09", palette.base09)?;
            tbl.set("base0a", palette.base0a)?;
            tbl.set("base0b", palette.base0b)?;
            tbl.set("base0c", palette.base0c)?;
            tbl.set("base0d", palette.base0d)?;
            tbl.set("base0e", palette.base0e)?;
            tbl.set("base0f", palette.base0f)?;
            // Semantic aliases
            tbl.set("red", palette.red)?;
            tbl.set("peach", palette.peach)?;
            tbl.set("yellow", palette.yellow)?;
            tbl.set("green", palette.green)?;
            tbl.set("teal", palette.teal)?;
            tbl.set("blue", palette.blue)?;
            tbl.set("mauve", palette.mauve)?;
            tbl.set("lavender", palette.lavender)?;
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
        services_table.set("render_svg", render_svg_fn.clone())?;
        services_table.set("RenderSvg", render_svg_fn)?;

        let render_svg_file_fn = lua.create_function(|_, (path, w, h): (String, u32, u32)| {
            match zenith_services::SystemService::render_svg_file(std::path::Path::new(&path), w, h) {
                Ok(bytes) => Ok(Some(bytes.len())),
                Err(e) => {
                    tracing::error!("SVG file render error: {}", e);
                    Ok(None)
                }
            }
        })?;
        services_table.set("render_svg_file", render_svg_file_fn.clone())?;
        services_table.set("RenderSvgFile", render_svg_file_fn)?;

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
                item.set("monitor", ws.monitor)?;
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
                item.set("x", c.at.0)?;
                item.set("y", c.at.1)?;
                item.set("width", c.size.0)?;
                item.set("height", c.size.1)?;
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

        // Hyprland Gaps service
        let gaps_fn = lua.create_function(|lua, ()| {
            let gaps = zenith_services::HyprlandService::gaps_out();
            let tbl = lua.create_table()?;
            tbl.set("gaps_out", gaps)?;
            tbl.set("gaps_in", (gaps / 2).max(4))?;
            Ok(tbl)
        })?;
        services_table.set("HyprlandGaps", gaps_fn.clone())?;
        services_table.set("hyprland_gaps", gaps_fn)?;

        // Wayland Outputs service (Multi-monitor)
        let outputs_fn = lua.create_function(|lua, ()| {
            let monitors = zenith_services::HyprlandService::monitors();
            let tbl = lua.create_table()?;
            for (idx, mon) in monitors.into_iter().enumerate() {
                let out = lua.create_table()?;
                out.set("id", mon.id)?;
                out.set("name", mon.name)?;
                out.set("width", mon.width)?;
                out.set("height", mon.height)?;
                out.set("scale", mon.scale)?;
                out.set("focused", mon.focused)?;
                tbl.set(idx + 1, out)?;
            }
            Ok(tbl)
        })?;
        services_table.set("Outputs", outputs_fn.clone())?;
        services_table.set("outputs", outputs_fn)?;

        // Screen & Viewport service
        let geom_clone2 = current_geometry.clone();
        let co_clone4 = current_output.clone();
        let svc_screen_fn = lua.create_function(move |lua, ()| {
            let tbl = lua.create_table()?;
            let (w, h) = *geom_clone2.read().unwrap();
            tbl.set("name", co_clone4.read().unwrap().clone())?;
            tbl.set("width", w)?;
            tbl.set("height", h)?;
            Ok(tbl)
        })?;
        services_table.set("Screen", svc_screen_fn.clone())?;
        services_table.set("screen", svc_screen_fn)?;

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

        // System Tray (StatusNotifierItem) service
        let tray_fn = lua.create_function(|lua, ()| {
            let items = zenith_services::TrayService::list();
            let tbl = lua.create_table()?;
            for (idx, item) in items.into_iter().enumerate() {
                let item_tbl = lua.create_table()?;
                item_tbl.set("id", item.id.clone())?;
                item_tbl.set("title", item.title.clone())?;
                item_tbl.set("icon", item.icon_name.clone())?;
                item_tbl.set("icon_name", item.icon_name.clone())?;
                item_tbl.set("service", item.service.clone())?;
                item_tbl.set("action", format!("tray:activate:{}", item.service))?;
                item_tbl.set("context_action", format!("tray:context:{}", item.service))?;
                item_tbl.set("secondary_action", format!("tray:secondary:{}", item.service))?;
                tbl.set(idx + 1, item_tbl)?;
            }
            Ok(tbl)
        })?;
        services_table.set("Tray", tray_fn.clone())?;
        services_table.set("tray", tray_fn)?;

        let tray_act_fn = lua.create_function(|_, service: String| {
            zenith_services::TrayService::activate(&service);
            Ok(())
        })?;
        services_table.set("TrayActivate", tray_act_fn.clone())?;
        services_table.set("tray_activate", tray_act_fn)?;

        let tray_ctx_fn = lua.create_function(|_, service: String| {
            zenith_services::TrayService::context_menu(&service);
            Ok(())
        })?;
        services_table.set("TrayContextMenu", tray_ctx_fn.clone())?;
        services_table.set("tray_context_menu", tray_ctx_fn)?;

        let tray_sec_fn = lua.create_function(|_, service: String| {
            zenith_services::TrayService::secondary_activate(&service);
            Ok(())
        })?;
        services_table.set("TraySecondaryActivate", tray_sec_fn.clone())?;
        services_table.set("tray_secondary_activate", tray_sec_fn)?;

        let tray_scroll_fn = lua.create_function(|_, (service, delta, orientation): (String, i32, Option<String>)| {
            let orient = orientation.unwrap_or_else(|| "vertical".to_string());
            zenith_services::TrayService::scroll(&service, delta, &orient);
            Ok(())
        })?;
        services_table.set("TrayScroll", tray_scroll_fn.clone())?;
        services_table.set("tray_scroll", tray_scroll_fn)?;

        // Audio Spectrum / CAVA service
        let spectrum_fn = lua.create_function(|lua, count: Option<usize>| {
            let bars = zenith_services::CavaService::spectrum(count.unwrap_or(8));
            let tbl = lua.create_table()?;
            for (idx, val) in bars.into_iter().enumerate() {
                tbl.set(idx + 1, val)?;
            }
            Ok(tbl)
        })?;
        services_table.set("Spectrum", spectrum_fn.clone())?;
        services_table.set("spectrum", spectrum_fn)?;

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
        services_table.set("media", media_fn.clone())?;
        services_table.set("Mpris", media_fn.clone())?;
        services_table.set("mpris", media_fn)?;

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

        let notif_history_fn = lua.create_function(|lua, ()| {
            let list = zenith_services::NotificationService::list_history();
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
        services_table.set("NotificationHistory", notif_history_fn.clone())?;
        services_table.set("notification_history", notif_history_fn)?;

        let notif_dnd_fn = lua.create_function(|_, ()| {
            Ok(zenith_services::NotificationService::is_dnd())
        })?;
        services_table.set("IsDND", notif_dnd_fn.clone())?;
        services_table.set("is_dnd", notif_dnd_fn)?;

        let notif_toggle_dnd_fn = lua.create_function(|_, ()| {
            Ok(zenith_services::NotificationService::toggle_dnd())
        })?;
        services_table.set("ToggleDND", notif_toggle_dnd_fn.clone())?;
        services_table.set("toggle_dnd", notif_toggle_dnd_fn)?;

        let notif_clear_hist_fn = lua.create_function(|_, ()| {
            zenith_services::NotificationService::clear_history();
            Ok(())
        })?;
        services_table.set("ClearNotificationHistory", notif_clear_hist_fn.clone())?;
        services_table.set("clear_notification_history", notif_clear_hist_fn)?;

        // Network & WiFi service
        let net_status_fn = lua.create_function(|lua, ()| {
            let s = zenith_services::NetworkService::status();
            let tbl = lua.create_table()?;
            tbl.set("connected", s.connected)?;
            tbl.set("is_connected", s.connected)?;
            tbl.set("type", s.connection_type)?;
            tbl.set("ssid", s.ssid.unwrap_or_default())?;
            tbl.set("ip", s.ip_address.unwrap_or_default())?;
            tbl.set("signal", s.signal_percent)?;
            Ok(tbl)
        })?;
        services_table.set("Network", net_status_fn.clone())?;
        services_table.set("network", net_status_fn)?;

        let wifi_scan_fn = lua.create_function(|lua, ()| {
            let list = zenith_services::NetworkService::scan_wifi();
            let tbl = lua.create_table()?;
            for (idx, w) in list.into_iter().enumerate() {
                let item = lua.create_table()?;
                item.set("ssid", w.ssid)?;
                item.set("signal", w.signal)?;
                item.set("security", w.security)?;
                item.set("in_use", w.in_use)?;
                tbl.set(idx + 1, item)?;
            }
            Ok(tbl)
        })?;
        services_table.set("WifiScan", wifi_scan_fn.clone())?;
        services_table.set("wifi_scan", wifi_scan_fn)?;

        // Bluetooth service
        let bt_status_fn = lua.create_function(|lua, ()| {
            let s = zenith_services::BluetoothService::status();
            let tbl = lua.create_table()?;
            tbl.set("powered", s.powered)?;
            let dev_tbl = lua.create_table()?;
            for (idx, d) in s.devices.into_iter().enumerate() {
                let item = lua.create_table()?;
                item.set("mac", d.mac)?;
                item.set("name", d.name)?;
                item.set("connected", d.connected)?;
                item.set("battery", d.battery.unwrap_or(0))?;
                dev_tbl.set(idx + 1, item)?;
            }
            tbl.set("devices", dev_tbl)?;
            Ok(tbl)
        })?;
        services_table.set("Bluetooth", bt_status_fn.clone())?;
        services_table.set("bluetooth", bt_status_fn)?;

        // Audio Sinks service
        let audio_sinks_fn = lua.create_function(|lua, ()| {
            let sinks = zenith_services::AudioService::list_sinks();
            let tbl = lua.create_table()?;
            for (idx, s) in sinks.into_iter().enumerate() {
                let item = lua.create_table()?;
                item.set("id", s.id)?;
                item.set("name", s.name)?;
                item.set("is_default", s.is_default)?;
                tbl.set(idx + 1, item)?;
            }
            Ok(tbl)
        })?;
        services_table.set("AudioSinks", audio_sinks_fn.clone())?;
        services_table.set("audio_sinks", audio_sinks_fn)?;

        let set_sink_fn = lua.create_function(|_, id: u32| {
            zenith_services::AudioService::set_default_sink(id);
            Ok(())
        })?;
        services_table.set("SetAudioSink", set_sink_fn.clone())?;
        services_table.set("set_audio_sink", set_sink_fn)?;

        let set_volume_fn = lua.create_function(|_, val: u32| {
            zenith_services::AudioService::set_volume(val as u8);
            Ok(())
        })?;
        services_table.set("SetVolume", set_volume_fn.clone())?;
        services_table.set("set_volume", set_volume_fn)?;

        let toggle_mute_fn = lua.create_function(|_, ()| {
            zenith_services::AudioService::toggle_mute();
            Ok(())
        })?;
        services_table.set("ToggleMute", toggle_mute_fn.clone())?;
        services_table.set("toggle_mute", toggle_mute_fn)?;

        // Weather service
        let weather_fn = lua.create_function(|lua, ()| {
            let snap = zenith_services::WeatherService::snapshot();
            let tbl = lua.create_table()?;
            tbl.set("temp", snap.temp_c)?;
            tbl.set("condition", snap.condition)?;
            tbl.set("icon", snap.icon)?;
            tbl.set("city", snap.city)?;
            Ok(tbl)
        })?;
        services_table.set("Weather", weather_fn.clone())?;
        services_table.set("weather", weather_fn)?;

        // Screen Recorder service
        let rec_status_fn = lua.create_function(|_, ()| {
            Ok(zenith_services::RecorderService::is_recording())
        })?;
        services_table.set("IsRecording", rec_status_fn.clone())?;
        services_table.set("is_recording", rec_status_fn)?;

        let rec_toggle_fn = lua.create_function(|_, ()| {
            Ok(zenith_services::RecorderService::toggle_recording())
        })?;
        services_table.set("ToggleRecording", rec_toggle_fn.clone())?;
        services_table.set("toggle_recording", rec_toggle_fn)?;

        // Brightness service
        let brightness_fn = lua.create_function(|lua, ()| {
            let snap = zenith_services::BrightnessService::get_brightness();
            let tbl = lua.create_table()?;
            tbl.set("percent", snap.percent)?;
            tbl.set("current", snap.current)?;
            tbl.set("max", snap.max)?;
            tbl.set("device", snap.device)?;
            Ok(tbl)
        })?;
        services_table.set("Brightness", brightness_fn.clone())?;
        services_table.set("brightness", brightness_fn)?;

        let set_brightness_fn = lua.create_function(|_, pct: u8| {
            zenith_services::BrightnessService::set_brightness(pct);
            Ok(())
        })?;
        services_table.set("SetBrightness", set_brightness_fn.clone())?;
        services_table.set("set_brightness", set_brightness_fn.clone())?;
        zenith_table.set("set_brightness", set_brightness_fn)?;

        let invalidate_brightness_fn = lua.create_function(|_, ()| {
            zenith_services::BrightnessService::invalidate_cache();
            Ok(())
        })?;
        services_table.set("InvalidateBrightnessCache", invalidate_brightness_fn.clone())?;
        services_table.set("invalidate_brightness_cache", invalidate_brightness_fn.clone())?;
        services_table.set("RefreshBrightness", invalidate_brightness_fn.clone())?;
        services_table.set("refresh_brightness", invalidate_brightness_fn)?;

        let step_brightness_fn = lua.create_function(|_, delta: i16| {
            let cur = zenith_services::BrightnessService::get_brightness().percent as i16;
            let new_pct = (cur + delta).clamp(0, 100) as u8;
            zenith_services::BrightnessService::set_brightness(new_pct);
            Ok(new_pct)
        })?;
        services_table.set("StepBrightness", step_brightness_fn.clone())?;
        services_table.set("step_brightness", step_brightness_fn.clone())?;
        services_table.set("AdjustBrightness", step_brightness_fn.clone())?;
        services_table.set("adjust_brightness", step_brightness_fn)?;

        // Disk storage service
        let disk_fn = lua.create_function(|lua, ()| {
            let snap = zenith_services::DiskService::get_disk_usage();
            let tbl = lua.create_table()?;
            tbl.set("total_gb", snap.total_gb)?;
            tbl.set("used_gb", snap.used_gb)?;
            tbl.set("free_gb", snap.free_gb)?;
            tbl.set("percent", snap.percent)?;
            tbl.set("mount", snap.mount)?;
            Ok(tbl)
        })?;
        services_table.set("Disk", disk_fn.clone())?;
        services_table.set("disk", disk_fn)?;

        // Power profile service
        let power_fn = lua.create_function(|_, ()| {
            Ok(zenith_services::PowerProfileService::get_profile())
        })?;
        services_table.set("PowerProfile", power_fn.clone())?;
        services_table.set("power_profile", power_fn.clone())?;
        services_table.set("Power", power_fn)?;

        let set_power_fn = lua.create_function(|_, prof: String| {
            zenith_services::PowerProfileService::set_profile(&prof);
            Ok(())
        })?;
        services_table.set("SetPowerProfile", set_power_fn.clone())?;
        services_table.set("set_power_profile", set_power_fn)?;

        let suspend_fn = lua.create_function(|_, ()| {
            zenith_services::PowerProfileService::suspend();
            Ok(())
        })?;
        services_table.set("Suspend", suspend_fn.clone())?;
        services_table.set("suspend", suspend_fn)?;

        let reboot_fn = lua.create_function(|_, ()| {
            zenith_services::PowerProfileService::reboot();
            Ok(())
        })?;
        services_table.set("Reboot", reboot_fn.clone())?;
        services_table.set("reboot", reboot_fn)?;

        let poweroff_fn = lua.create_function(|_, ()| {
            zenith_services::PowerProfileService::poweroff();
            Ok(())
        })?;
        services_table.set("PowerOff", poweroff_fn.clone())?;
        services_table.set("power_off", poweroff_fn)?;

        let set_wifi_fn = lua.create_function(|_, enabled: bool| {
            let _ = zenith_services::NetworkService::set_wifi_enabled(enabled);
            Ok(())
        })?;
        services_table.set("SetWifiEnabled", set_wifi_fn.clone())?;
        services_table.set("set_wifi_enabled", set_wifi_fn)?;

        // Idle state service
        let idle_bool_svc = is_idle.clone();
        let idle_fn = lua.create_function(move |lua, ()| {
            let cur = idle_bool_svc.load(Ordering::Relaxed);
            let tbl = lua.create_table()?;
            tbl.set("is_idle", cur)?;
            tbl.set("idle", cur)?;
            Ok(tbl)
        })?;
        services_table.set("Idle", idle_fn.clone())?;
        services_table.set("idle", idle_fn)?;

        let idle_bool_is = is_idle.clone();
        let is_idle_fn = lua.create_function(move |_, ()| {
            Ok(idle_bool_is.load(Ordering::Relaxed))
        })?;
        services_table.set("IsIdle", is_idle_fn.clone())?;
        services_table.set("is_idle", is_idle_fn)?;

        let idle_bool_set = is_idle.clone();
        let storage_idle = Arc::clone(&storage);
        let set_idle_fn = lua.create_function(move |_, val: bool| {
            idle_bool_set.store(val, Ordering::Relaxed);
            let _ = storage_idle.set("system_idle", serde_json::Value::Bool(val));
            let _ = storage_idle.set("system_activity", serde_json::Value::Bool(!val));
            Ok(())
        })?;
        services_table.set("SetIdle", set_idle_fn.clone())?;
        services_table.set("set_idle", set_idle_fn.clone())?;
        zenith_table.set("set_idle", set_idle_fn)?;

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
            let _ = spawner::spawn_detached(&cmd);
            Ok(())
        })?;
        zenith_table.set("exec", exec_fn)?;

        // Zenith.close() - in-process IPC socket command
        let close_fn = lua.create_function(|_, ()| {
            if let Ok(dir) = std::env::var("XDG_RUNTIME_DIR") {
                let sock_path = std::path::PathBuf::from(dir).join("zenith.sock");
                if let Ok(mut stream) = std::os::unix::net::UnixStream::connect(&sock_path) {
                    use std::io::Write;
                    let _ = stream.write_all(b"close\n");
                }
            }
            Ok(())
        })?;
        zenith_table.set("close", close_fn)?;

        // In-memory module cache for Zenith.import
        let modules_cache = lua.create_table()?;
        lua.globals().set("__zenith_modules", modules_cache)?;

        // Zenith.import(module_path)
        let import_fn = lua.create_function(|lua, path: String| {
            let modules_tbl: LuaTable = lua.globals().get("__zenith_modules")?;
            if let Ok(cached) = modules_tbl.get::<LuaValue>(path.as_str()) {
                if !matches!(cached, LuaValue::Nil) {
                    return Ok(cached);
                }
            }

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
                let _ = modules_tbl.set(path.as_str(), val.clone());
                Ok(val)
            } else {
                Err(LuaError::runtime(format!("Cannot resolve Zenith module '{}'", path)))
            }
        })?;
        zenith_table.set("import", import_fn)?;

        let callbacks_table = lua.create_table()?;
        lua.globals().set("__zenith_callbacks", callbacks_table)?;

        let worker_pool = Arc::new(WorkerThreadPool::new(4));
        setup_async_bridge(&lua, &zenith_table, Arc::clone(&worker_pool))?;

        storage::setup_storage_bindings(&lua, &zenith_table, Arc::clone(&storage))?;

        lua.globals().set("Zenith", zenith_table)?;

        let script_cache = Arc::new(RwLock::new(HashMap::new()));

        info!("Luau Runtime initialized successfully");
        Ok(Self {
            lua,
            reactive,
            worker_pool,
            storage,
            is_idle,
            search_query,
            selected_index,
            current_output,
            current_geometry,
            script_cache,
            focused_input_id,
            input_buffers,
            editor_engines,
        })
    }

    /// Polls completed background workers and triggers Promise resolution callbacks.
    pub fn poll_async_events(&self) -> Result<usize, LuaError> {
        poll_async_completions(&self.lua, &self.worker_pool)
    }

    /// Evaluates arbitrary Luau expression or code snippet for Live REPL and diagnostics.
    pub fn eval_code(&self, code: &str) -> Result<String, LuaError> {
        let trimmed = code.trim();
        let attempt = if !trimmed.starts_with("return ") && !trimmed.contains('=') && !trimmed.starts_with("local ") {
            format!("return {}", trimmed)
        } else {
            trimmed.to_string()
        };

        let format_val = |val: LuaValue| -> String {
            match val {
                LuaValue::Nil => "nil".to_string(),
                LuaValue::String(s) => s.to_str().map(|b| b.to_string()).unwrap_or_default(),
                other => {
                    let json_val = crate::storage::lua_to_json(other);
                    serde_json::to_string_pretty(&json_val).unwrap_or_else(|_| format!("{:?}", json_val))
                }
            }
        };

        match self.lua.load(&attempt).eval::<LuaValue>() {
            Ok(val) => Ok(format_val(val)),
            Err(_) => {
                match self.lua.load(trimmed).eval::<LuaValue>() {
                    Ok(val) => Ok(format_val(val)),
                    Err(_) => {
                        self.lua.load(trimmed).exec()?;
                        Ok("nil".to_string())
                    }
                }
            }
        }
    }

    fn hash_script(s: &str) -> u64 {
        let mut hasher = DefaultHasher::new();
        s.hash(&mut hasher);
        hasher.finish()
    }

    /// Clear loaded module cache and compiled script chunk cache (called during hot-reload).
    pub fn clear_module_cache(&self) {
        if let Ok(tbl) = self.lua.globals().get::<LuaTable>("__zenith_modules") {
            let _ = tbl.clear();
        }
        self.script_cache.write().unwrap().clear();
    }

    /// Retrieve active current output name from runtime.
    pub fn get_current_output(&self) -> String {
        self.current_output.read().unwrap().clone()
    }

    /// Set active current output name in runtime.
    pub fn set_current_output(&self, name: &str) {
        *self.current_output.write().unwrap() = name.to_string();
    }

    /// Set active current output name and viewport geometry in runtime.
    pub fn set_current_output_geometry(&self, name: &str, width: u32, height: u32) {
        *self.current_output.write().unwrap() = name.to_string();
        *self.current_geometry.write().unwrap() = (width, height);
    }

    /// Retrieve active current viewport dimensions.
    pub fn get_current_viewport(&self) -> (u32, u32) {
        *self.current_geometry.read().unwrap()
    }

    /// Updates the global idle state of the runtime and persists in storage.
    pub fn set_idle(&self, idle: bool) {
        self.is_idle.store(idle, Ordering::Relaxed);
        let _ = self.storage.set("system_idle", serde_json::Value::Bool(idle));
        let _ = self.storage.set("system_activity", serde_json::Value::Bool(!idle));
    }

    /// Returns `true` if system is currently reported as idle.
    pub fn is_idle(&self) -> bool {
        self.is_idle.load(Ordering::Relaxed)
    }

    /// Retrieve active search query string from runtime.
    pub fn get_search_query(&self) -> String {
        self.search_query.read().unwrap().clone()
    }

    /// Set active search query string in runtime.
    pub fn set_search_query(&self, q: &str) {
        *self.search_query.write().unwrap() = q.to_string();
    }

    /// Retrieve active selected index from runtime.
    pub fn get_selected_index(&self) -> usize {
        *self.selected_index.read().unwrap()
    }

    /// Set active selected index in runtime.
    pub fn set_selected_index(&self, idx: usize) {
        *self.selected_index.write().unwrap() = idx;
    }

    /// Get id of currently focused text input, if any.
    pub fn get_focused_input(&self) -> Option<String> {
        self.focused_input_id.read().unwrap().clone()
    }

    /// Set id of currently focused text input.
    pub fn set_focused_input(&self, id: Option<String>) {
        *self.focused_input_id.write().unwrap() = id;
    }

    /// Get current buffered text for a text input id.
    pub fn get_input_text(&self, id: &str) -> String {
        self.input_buffers.read().unwrap().get(id).cloned().unwrap_or_default()
    }

    /// Set buffered text for a text input id.
    pub fn set_input_text(&self, id: &str, text: &str) {
        self.input_buffers.write().unwrap().insert(id.to_string(), text.to_string());
    }

    /// Access and mutate TextEditorEngine for a given text input id.
    pub fn with_editor<F, R>(&self, id: &str, f: F) -> R
    where
        F: FnOnce(&mut zenith_layout::TextEditorEngine) -> R,
    {
        let mut map = self.editor_engines.write().unwrap();
        let cur_txt = self.get_input_text(id);
        let editor = map.entry(id.to_string()).or_insert_with(|| {
            zenith_layout::TextEditorEngine::new(&cur_txt)
        });
        if editor.text() != cur_txt && !cur_txt.is_empty() && editor.text().is_empty() {
            editor.set_text(&cur_txt);
        }
        let res = f(editor);
        let new_text = editor.text().to_string();
        drop(map);
        self.set_input_text(id, &new_text);
        res
    }

    /// Insert text into the active editor engine for an input.
    pub fn editor_insert(&self, id: &str, text: &str) {
        self.with_editor(id, |e| e.insert_text(text));
    }

    /// Backspace on the active editor engine for an input.
    pub fn editor_backspace(&self, id: &str) {
        self.with_editor(id, |e| e.backspace());
    }

    /// Delete on the active editor engine for an input.
    pub fn editor_delete(&self, id: &str) {
        self.with_editor(id, |e| e.delete());
    }

    /// Select all text on the active editor engine for an input.
    pub fn editor_select_all(&self, id: &str) {
        self.with_editor(id, |e| e.select_all());
    }

    /// Undo on the active editor engine for an input.
    pub fn editor_undo(&self, id: &str) -> bool {
        self.with_editor(id, |e| e.undo())
    }

    /// Redo on the active editor engine for an input.
    pub fn editor_redo(&self, id: &str) -> bool {
        self.with_editor(id, |e| e.redo())
    }

    /// Copy selected text on the active editor engine.
    pub fn editor_copy(&self, id: &str) -> Option<String> {
        self.with_editor(id, |e| e.copy())
    }

    /// Cut selected text on the active editor engine.
    pub fn editor_cut(&self, id: &str) -> Option<String> {
        self.with_editor(id, |e| e.cut())
    }

    /// Paste text into active editor engine.
    pub fn editor_paste(&self, id: &str, text: &str) {
        self.with_editor(id, |e| e.paste(text));
    }

    /// Move cursor with or without selection extension.
    pub fn editor_move_cursor(&self, id: &str, dir: zenith_layout::CursorDirection, extend_sel: bool) {
        self.with_editor(id, |e| e.move_cursor(dir, extend_sel));
    }

    /// Handle click on editor engine.
    pub fn editor_click(&self, id: &str, char_idx: usize, extend_sel: bool, now: std::time::Instant) {
        self.with_editor(id, |e| e.handle_click(char_idx, extend_sel, now));
    }

    /// Handle drag on editor engine.
    pub fn editor_drag(&self, id: &str, char_idx: usize) {
        self.with_editor(id, |e| e.handle_drag(char_idx));
    }

    /// Get current cursor and selection range for an input.
    pub fn get_editor_state(&self, id: &str) -> (usize, Option<(usize, usize)>) {
        let map = self.editor_engines.read().unwrap();
        if let Some(e) = map.get(id) {
            (e.cursor, e.selection_range())
        } else {
            (self.get_input_text(id).len(), None)
        }
    }

    /// Trigger a registered Lua callback with a single string argument.
    pub fn trigger_callback_with_arg(&self, key: &str, arg: &str) -> Result<(), LuaError> {
        if let Ok(callbacks) = self.lua.globals().get::<LuaTable>("__zenith_callbacks") {
            if let Ok(cb) = callbacks.get::<LuaFunction>(key) {
                cb.call::<()>(arg)?;
                return Ok(());
            }
        }
        if let Some(storage_key) = key.strip_prefix("storage:set:") {
            let clean_k = storage_key.trim_end_matches(':');
            let full_action = format!("storage:set:{}:{}", clean_k, arg);
            return self.trigger_click(&full_action);
        } else if let Some(storage_key) = key.strip_prefix("storage:toggle:") {
            let clean_k = storage_key.trim_end_matches(':');
            let full_action = format!("storage:toggle:{}", clean_k);
            return self.trigger_click(&full_action);
        }
        Ok(())
    }

    /// Load and evaluate a Luau script string, returning the root UI node with compiled chunk caching.
    pub fn eval_ui(&self, script: &str) -> Result<UiNode, LuaError> {
        let hash = Self::hash_script(script);
        let func: LuaFunction = {
            let cache = self.script_cache.read().unwrap();
            if let Some(key) = cache.get(&hash) {
                self.lua.registry_value(key)?
            } else {
                drop(cache);
                let f: LuaFunction = self.lua.load(script).into_function()?;
                let key = self.lua.create_registry_value(f.clone())?;
                self.script_cache.write().unwrap().insert(hash, key);
                f
            }
        };

        let val: LuaValue = func.call(())?;
        match val {
            LuaValue::Table(tbl) => Self::parse_ui_node(&self.lua, &tbl),
            _ => Err(LuaError::runtime("Script must return a Zenith UI node table")),
        }
    }

    /// Trigger a registered click action by command or function key.
    pub fn trigger_click(&self, action: &str) -> Result<(), LuaError> {
        if let Some(rest) = action.strip_prefix("dispatch:") {
            let (dispatcher, arg) = rest.split_once(':').unwrap_or((rest, ""));
            if let Err(e) = zenith_services::HyprlandService::dispatch(dispatcher, arg) {
                tracing::error!("Failed to dispatch action {}: {}", action, e);
            }
        } else if let Some(addr) = action.strip_prefix("focus:") {
            let _ = zenith_services::HyprlandService::focus_window(addr);
        } else if let Some(addr) = action.strip_prefix("window:toggle_minimize:") {
            let _ = zenith_services::HyprlandService::toggle_minimize_or_focus(addr);
        } else if let Some(cmd) = action.strip_prefix("cmd:") {
            let _ = spawner::spawn_detached(cmd);
        } else if let Some(cmd) = action.strip_prefix("launch:") {
            let _ = zenith_services::LauncherService::launch(cmd);
        } else if let Some(cmd) = action.strip_prefix("media:") {
            let _ = zenith_services::MprisService::control(cmd);
        } else if let Some(id_str) = action.strip_prefix("notification:close:") {
            if let Ok(id) = id_str.parse::<u32>() {
                zenith_services::NotificationService::close(id);
            }
        } else if action == "notification:clear" {
            zenith_services::NotificationService::clear_all();
        } else if action == "notification:toggle_dnd" {
            zenith_services::NotificationService::toggle_dnd();
        } else if action == "notification:clear_history" {
            zenith_services::NotificationService::clear_history();
        } else if let Some(ssid) = action.strip_prefix("wifi:connect:") {
            let _ = zenith_services::NetworkService::connect_wifi(ssid, None);
        } else if let Some(enabled_str) = action.strip_prefix("wifi:set_enabled:") {
            let enabled = enabled_str == "true" || enabled_str == "1";
            let _ = zenith_services::NetworkService::set_wifi_enabled(enabled);
        } else if action == "wifi:toggle" {
            let cur = zenith_services::NetworkService::status();
            let _ = zenith_services::NetworkService::set_wifi_enabled(!cur.connected);
        } else if let Some(prof) = action.strip_prefix("power:profile:") {
            zenith_services::PowerProfileService::set_profile(prof);
        } else if action == "system:suspend" || action == "power:suspend" {
            zenith_services::PowerProfileService::suspend();
        } else if action == "system:reboot" || action == "power:reboot" {
            zenith_services::PowerProfileService::reboot();
        } else if action == "system:poweroff" || action == "power:poweroff" {
            zenith_services::PowerProfileService::poweroff();
        } else if action == "bluetooth:toggle" {
            zenith_services::BluetoothService::toggle_power();
        } else if let Some(mac) = action.strip_prefix("bluetooth:connect:") {
            let _ = zenith_services::BluetoothService::connect(mac);
        } else if let Some(mac) = action.strip_prefix("bluetooth:disconnect:") {
            let _ = zenith_services::BluetoothService::disconnect(mac);
        } else if let Some(srv) = action.strip_prefix("tray:activate:") {
            zenith_services::TrayService::activate(srv);
        } else if let Some(srv) = action.strip_prefix("tray:context:") {
            zenith_services::TrayService::context_menu(srv);
        } else if let Some(srv) = action.strip_prefix("tray:secondary:") {
            zenith_services::TrayService::secondary_activate(srv);
        } else if let Some(rest) = action.strip_prefix("tray:scroll:") {
            if let Some((srv, delta_str)) = rest.split_once(':') {
                if let Ok(delta) = delta_str.parse::<i32>() {
                    zenith_services::TrayService::scroll(srv, delta, "vertical");
                }
            }
        } else if let Some(pct_str) = action.strip_prefix("brightness:set:") {
            if let Ok(pct) = pct_str.parse::<u8>() {
                zenith_services::BrightnessService::set_brightness(pct);
            }
        } else if let Some(step_str) = action.strip_prefix("brightness:step:") {
            if let Ok(delta) = step_str.parse::<i16>() {
                let cur = zenith_services::BrightnessService::get_brightness().percent as i16;
                let new_pct = (cur + delta).clamp(0, 100) as u8;
                zenith_services::BrightnessService::set_brightness(new_pct);
            }
        } else if let Some(val_str) = action.strip_prefix("idle:set:") {
            let val = val_str == "true" || val_str == "1";
            self.set_idle(val);
        } else if action == "idle:toggle" {
            let cur = self.is_idle();
            self.set_idle(!cur);
        } else if let Some(id_str) = action.strip_prefix("audio:set_sink:") {
            if let Ok(id) = id_str.parse::<u32>() {
                zenith_services::AudioService::set_default_sink(id);
            }
        } else if let Some(vol_str) = action.strip_prefix("audio:set_volume:") {
            if let Ok(val) = vol_str.parse::<u32>() {
                zenith_services::AudioService::set_volume(val as u8);
            }
        } else if let Some(step_str) = action.strip_prefix("audio:volume_step:") {
            if let Ok(delta) = step_str.parse::<i32>() {
                zenith_services::AudioService::adjust_volume(delta);
            }
        } else if action == "audio:toggle_mute" {
            zenith_services::AudioService::toggle_mute();
        } else if action == "record:toggle" {
            zenith_services::RecorderService::toggle_recording();
        } else if action == "screenshot:area" {
            zenith_services::RecorderService::take_screenshot(true);
        } else if action == "screenshot:full" {
            zenith_services::RecorderService::take_screenshot(false);
        } else if action == "search:clear" {
            self.set_search_query("");
            self.set_selected_index(1);
        } else if let Some(key_val) = action.strip_prefix("storage:set:") {
            if let Some((k, v)) = key_val.split_once(':') {
                let json_val = if v == "true" {
                    serde_json::Value::Bool(true)
                } else if v == "false" {
                    serde_json::Value::Bool(false)
                } else if let Ok(num) = v.parse::<i64>() {
                    serde_json::Value::from(num)
                } else if let Ok(num) = v.parse::<f64>() {
                    if (num - num.round()).abs() < 1e-4 {
                        serde_json::Value::from(num.round() as i64)
                    } else {
                        serde_json::Number::from_f64(num).map(serde_json::Value::Number).unwrap_or(serde_json::Value::Null)
                    }
                } else {
                    serde_json::Value::String(v.to_string())
                };
                let _ = self.storage.set(k, json_val);
            }
        } else if let Some(k) = action.strip_prefix("storage:toggle:") {
            let cur = self.storage.get(k).and_then(|v| v.as_bool()).unwrap_or(false);
            let _ = self.storage.set(k, serde_json::Value::Bool(!cur));
        } else if let Some(page_str) = action.strip_prefix("settings:page:") {
            if let Ok(idx) = page_str.parse::<i64>() {
                let _ = self.storage.set("settings_active_page", serde_json::Value::from(idx));
            }
        } else if action.starts_with("click_")
            || action.starts_with("right_click_")
            || action.starts_with("scroll_up_")
            || action.starts_with("scroll_down_")
            || action.starts_with("change_")
            || action.starts_with("submit_")
            || action.starts_with("switch_toggle_")
            || action.starts_with("slider_change_")
        {
            if let Ok(callbacks) = self.lua.globals().get::<LuaTable>("__zenith_callbacks") {
                if let Ok(func) = callbacks.get::<LuaFunction>(action) {
                    let _ = func.call::<()>(());
                    return Ok(());
                }
            }
            let _ = spawner::spawn_detached(action);
        } else {
            // Check if action corresponds to a shell command directly
            let _ = spawner::spawn_detached(action);
        }
        Ok(())
    }

    /// Mounts a UI tree into the reactive graph, binding signals and persisting the tree across frames.
    pub fn mount_tree(&self, tree_id: &str, script: &str) -> Result<UiNode, LuaError> {
        let hash = Self::hash_script(script);
        let func: LuaFunction = {
            let cache = self.script_cache.read().unwrap();
            if let Some(key) = cache.get(&hash) {
                self.lua.registry_value(key)?
            } else {
                drop(cache);
                let f: LuaFunction = self.lua.load(script).into_function()?;
                let key = self.lua.create_registry_value(f.clone())?;
                self.script_cache.write().unwrap().insert(hash, key);
                f
            }
        };

        let val: LuaValue = func.call(())?;
        match val {
            LuaValue::Table(tbl) => {
                let node = Self::parse_ui_node_tracked(&self.lua, &tbl, &[], Some(&self.reactive), Some(tree_id))?;
                self.reactive.mount_tree(tree_id, node.clone());
                Ok(node)
            }
            _ => Err(LuaError::runtime("Script must return a Zenith UI node table")),
        }
    }

    /// Gets the cached/updated UI tree for a given tree id.
    pub fn get_tree(&self, tree_id: &str) -> Option<UiNode> {
        self.reactive.get_tree(tree_id)
    }

    /// Checks if a mounted UI tree was modified by reactive signals.
    pub fn is_tree_dirty(&self, tree_id: &str) -> bool {
        self.reactive.is_tree_dirty(tree_id)
    }

    /// Resets the dirty flag after rendering.
    pub fn mark_tree_clean(&self, tree_id: &str) {
        self.reactive.mark_tree_clean(tree_id);
    }

    fn parse_ui_node(lua: &Lua, tbl: &LuaTable) -> Result<UiNode, LuaError> {
        Self::parse_ui_node_tracked(lua, tbl, &[], None, None)
    }

    fn parse_ui_node_tracked(
        lua: &Lua,
        tbl: &LuaTable,
        path: &[usize],
        reactive: Option<&crate::reactive::ReactiveGraph>,
        tree_id: Option<&str>,
    ) -> Result<UiNode, LuaError> {
        let node_type: String = tbl.get("__type").unwrap_or_else(|_| "Box".to_string());
        let style = Self::parse_style(tbl)?;

        if node_type == "Text" {
            let (text, maybe_sig_id): (String, Option<u64>) = if let Ok(sig_tbl) = tbl.get::<LuaTable>("text") {
                let sig_id: Option<u64> = sig_tbl.get("__signal_id").ok();
                let s = if let Ok(get_fn) = sig_tbl.get::<LuaFunction>("get") {
                    get_fn.call::<String>(Some(sig_tbl.clone())).unwrap_or_default()
                } else {
                    sig_tbl.get::<String>("value").unwrap_or_default()
                };
                (s, sig_id)
            } else if let Ok(s) = tbl.get::<String>("text") {
                (s, None)
            } else if let Ok(func) = tbl.get::<LuaFunction>("text") {
                (func.call::<String>(()).unwrap_or_default(), None)
            } else {
                (tbl.get::<f64>("text").map(|n| n.to_string()).unwrap_or_default(), None)
            };

            if let (Some(sig_id), Some(rg), Some(tid)) = (maybe_sig_id, reactive, tree_id) {
                rg.bind_node(
                    sig_id,
                    crate::reactive::NodeBinding {
                        tree_id: tid.to_string(),
                        node_path: path.to_vec(),
                        property: crate::reactive::BoundProperty::Text,
                    },
                );
            }

            let font_size: f32 = tbl.get("font_size").unwrap_or(14.0);
            let color = tbl.get("color").map(|c: LuaTable| Self::parse_color(&c)).unwrap_or(Color::rgb(255, 255, 255));

            Ok(UiNode::Text {
                text,
                font_size,
                color,
                style,
            })
        } else if node_type == "TextInput" {
            let id = tbl.get::<String>("id").ok();
            let (text, maybe_sig_id): (String, Option<u64>) = if let Ok(sig_tbl) = tbl.get::<LuaTable>("text") {
                let sig_id: Option<u64> = sig_tbl.get("__signal_id").ok();
                let s = if let Ok(get_fn) = sig_tbl.get::<LuaFunction>("get") {
                    get_fn.call::<String>(Some(sig_tbl.clone())).unwrap_or_default()
                } else {
                    sig_tbl.get::<String>("value").unwrap_or_default()
                };
                (s, sig_id)
            } else if let Ok(s) = tbl.get::<String>("text") {
                (s, None)
            } else if let Ok(func) = tbl.get::<LuaFunction>("text") {
                (func.call::<String>(()).unwrap_or_default(), None)
            } else {
                (tbl.get::<f64>("text").map(|n| n.to_string()).unwrap_or_default(), None)
            };

            if let (Some(sig_id), Some(rg), Some(tid)) = (maybe_sig_id, reactive, tree_id) {
                rg.bind_node(
                    sig_id,
                    crate::reactive::NodeBinding {
                        tree_id: tid.to_string(),
                        node_path: path.to_vec(),
                        property: crate::reactive::BoundProperty::Text,
                    },
                );
            }

            let placeholder: String = tbl.get("placeholder").unwrap_or_default();
            let font_size: f32 = tbl.get("font_size").unwrap_or(14.0);
            let color = tbl.get("color").map(|c: LuaTable| Self::parse_color(&c)).unwrap_or(Color::rgb(255, 255, 255));
            let placeholder_color = tbl.get("placeholder_color").map(|c: LuaTable| Self::parse_color(&c)).unwrap_or(Color::rgba(255, 255, 255, 120));
            let active: bool = tbl.get("active").unwrap_or(false);
            let cursor_pos: usize = tbl.get("cursor_pos").unwrap_or(text.len());

            let on_change: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_change") {
                static CB_CHANGE_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_CHANGE_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("change_{}", id);
                if let Ok(callbacks) = lua.globals().get::<LuaTable>("__zenith_callbacks") {
                    let _ = callbacks.set(key.clone(), func);
                }
                Some(key)
            } else {
                tbl.get::<String>("on_change").ok()
            };

            let on_submit: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_submit") {
                static CB_SUBMIT_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_SUBMIT_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("submit_{}", id);
                if let Ok(callbacks) = lua.globals().get::<LuaTable>("__zenith_callbacks") {
                    let _ = callbacks.set(key.clone(), func);
                }
                Some(key)
            } else {
                tbl.get::<String>("on_submit").ok()
            };

            Ok(UiNode::TextInput {
                id,
                text,
                placeholder,
                font_size,
                color,
                placeholder_color,
                active,
                cursor_pos,
                selection_range: None,
                style,
                on_change,
                on_submit,
            })
        } else if node_type == "Image" {
            let src: String = tbl.get("src").unwrap_or_default();
            Ok(UiNode::Image {
                src,
                style,
            })
        } else if node_type == "Shader" {
            let fragment: String = tbl.get("fragment").or_else(|_| tbl.get("shader")).unwrap_or_default();
            let mut uniforms = Vec::new();
            if let Ok(u_tbl) = tbl.get::<LuaTable>("uniforms") {
                for pair in u_tbl.pairs::<String, f32>().flatten() {
                    uniforms.push(pair);
                }
            }
            Ok(UiNode::Shader {
                fragment,
                uniforms,
                style,
            })
        } else if node_type == "Slider" {
            let id = tbl.get::<String>("id").ok();
            let min: f32 = tbl.get::<f32>("min").unwrap_or(0.0);
            let max: f32 = tbl.get::<f32>("max").unwrap_or(100.0);
            let value: f32 = tbl.get::<f32>("value").unwrap_or(0.0);
            let track_height: f32 = tbl.get::<f32>("track_height").unwrap_or(6.0);
            let thumb_radius: f32 = tbl.get::<f32>("thumb_radius").unwrap_or(10.0);
            let track_color = tbl.get("track_color").map(|c: LuaTable| Self::parse_color(&c)).unwrap_or(Color::rgba(255, 255, 255, 50));
            let active_track_color = tbl.get("active_track_color").map(|c: LuaTable| Self::parse_color(&c)).unwrap_or(Color::rgb(124, 77, 255));
            let thumb_color = tbl.get("thumb_color").map(|c: LuaTable| Self::parse_color(&c)).unwrap_or(Color::rgb(255, 255, 255));

            let on_change: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_change") {
                static CB_SLIDER_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_SLIDER_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("slider_change_{}", id);
                if let Ok(callbacks) = lua.globals().get::<LuaTable>("__zenith_callbacks") {
                    let _ = callbacks.set(key.clone(), func);
                }
                Some(key)
            } else {
                tbl.get::<String>("on_change").ok()
            };

            Ok(UiNode::Slider {
                id,
                min,
                max,
                value,
                track_height,
                thumb_radius,
                track_color,
                active_track_color,
                thumb_color,
                style,
                on_change,
            })
        } else if node_type == "Switch" {
            let id = tbl.get::<String>("id").ok();
            let checked: bool = tbl.get::<bool>("checked").unwrap_or(false);
            let active_color = tbl.get("active_color").map(|c: LuaTable| Self::parse_color(&c)).unwrap_or(Color::rgb(124, 77, 255));
            let inactive_color = tbl.get("inactive_color").map(|c: LuaTable| Self::parse_color(&c)).unwrap_or(Color::rgba(255, 255, 255, 50));
            let thumb_color = tbl.get("thumb_color").map(|c: LuaTable| Self::parse_color(&c)).unwrap_or(Color::rgb(255, 255, 255));

            let on_toggle: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_toggle") {
                static CB_SWITCH_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_SWITCH_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("switch_toggle_{}", id);
                if let Ok(callbacks) = lua.globals().get::<LuaTable>("__zenith_callbacks") {
                    let _ = callbacks.set(key.clone(), func);
                }
                Some(key)
            } else {
                tbl.get::<String>("on_toggle").ok()
            };

            Ok(UiNode::Switch {
                id,
                checked,
                active_color,
                inactive_color,
                thumb_color,
                style,
                on_toggle,
            })
        } else if node_type == "VirtualList" {
            let item_height: f32 = tbl.get::<f32>("item_height").unwrap_or(40.0);
            let visible_height: f32 = tbl.get::<f32>("visible_height").unwrap_or(300.0);
            let scroll_offset: f32 = tbl.get::<f32>("scroll_offset").unwrap_or(0.0);
            let items: LuaTable = tbl.get("items")?;
            let total_count = items.len().unwrap_or(0) as usize;

            let start_idx = ((scroll_offset / item_height).floor() as usize).min(total_count);
            let visible_count = ((visible_height / item_height).ceil() as usize + 2).min(total_count.saturating_sub(start_idx));
            let end_idx = (start_idx + visible_count).min(total_count);

            let top_spacer_height = start_idx as f32 * item_height;
            let bottom_spacer_height = (total_count - end_idx) as f32 * item_height;

            let mut list_children = Vec::new();
            if top_spacer_height > 0.0 {
                list_children.push(UiNode::Box {
                    style: zenith_layout::NodeStyle {
                        height: Some(top_spacer_height),
                        ..Default::default()
                    },
                    children: Vec::new(),
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                });
            }

            if let Ok(render_item_fn) = tbl.get::<LuaFunction>("render_item") {
                for i in (start_idx + 1)..=(end_idx) {
                    if let Ok(item_val) = items.get::<LuaValue>(i) {
                        if let Ok(item_node_tbl) = render_item_fn.call::<LuaTable>((item_val, i)) {
                            let child_path = [path, &[i]].concat();
                            if let Ok(child_node) = Self::parse_ui_node_tracked(lua, &item_node_tbl, &child_path, reactive, tree_id) {
                                list_children.push(child_node);
                            }
                        }
                    }
                }
            }

            if bottom_spacer_height > 0.0 {
                list_children.push(UiNode::Box {
                    style: zenith_layout::NodeStyle {
                        height: Some(bottom_spacer_height),
                        ..Default::default()
                    },
                    children: Vec::new(),
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                });
            }

            let mut list_style = style;
            if list_style.height.is_none() {
                list_style.height = Some(visible_height);
            }
            list_style.flex_direction = zenith_layout::FlexDirection::Column;
            list_style.overflow = zenith_layout::Overflow::Scroll;
            list_style.scroll_offset_y = scroll_offset;

            Ok(UiNode::Box {
                style: list_style,
                children: list_children,
                on_click: None,
                on_right_click: None,
                on_scroll_up: None,
                on_scroll_down: None,
                tooltip: None,
            })
        } else if node_type == "Window" {
            let meta = Self::parse_window_meta(tbl);
            let mut children = Vec::new();
            if let Ok(child_tbl) = tbl.get::<LuaTable>("children") {
                for (i, child) in child_tbl.sequence_values::<LuaTable>().flatten().enumerate() {
                    let mut child_path = path.to_vec();
                    child_path.push(i);
                    children.push(Self::parse_ui_node_tracked(lua, &child, &child_path, reactive, tree_id)?);
                }
            }
            Ok(UiNode::Window {
                meta,
                style,
                children,
            })
        } else {
            let mut children = Vec::new();
            if let Ok(child_tbl) = tbl.get::<LuaTable>("children") {
                for (i, child) in child_tbl.sequence_values::<LuaTable>().flatten().enumerate() {
                    let mut child_path = path.to_vec();
                    child_path.push(i);
                    children.push(Self::parse_ui_node_tracked(lua, &child, &child_path, reactive, tree_id)?);
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

            let on_right_click: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_right_click") {
                static CB_RIGHT_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_RIGHT_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("right_click_{}", id);
                if let Ok(callbacks) = lua.globals().get::<LuaTable>("__zenith_callbacks") {
                    let _ = callbacks.set(key.clone(), func);
                }
                Some(key)
            } else {
                tbl.get::<String>("on_right_click").ok()
            };

            let on_scroll_up: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_scroll_up") {
                static CB_SCROLL_UP_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_SCROLL_UP_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("scroll_up_{}", id);
                if let Ok(callbacks) = lua.globals().get::<LuaTable>("__zenith_callbacks") {
                    let _ = callbacks.set(key.clone(), func);
                }
                Some(key)
            } else {
                tbl.get::<String>("on_scroll_up").ok()
            };

            let on_scroll_down: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_scroll_down") {
                static CB_SCROLL_DOWN_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_SCROLL_DOWN_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("scroll_down_{}", id);
                if let Ok(callbacks) = lua.globals().get::<LuaTable>("__zenith_callbacks") {
                    let _ = callbacks.set(key.clone(), func);
                }
                Some(key)
            } else {
                tbl.get::<String>("on_scroll_down").ok()
            };

            let tooltip: Option<String> = tbl.get::<String>("tooltip").ok();

            Ok(UiNode::Box {
                style,
                children,
                on_click,
                on_right_click,
                on_scroll_up,
                on_scroll_down,
                tooltip,
            })
        }
    }

    fn parse_window_meta(tbl: &LuaTable) -> zenith_layout::WindowMeta {
        let mut meta = zenith_layout::WindowMeta::default();

        if let Ok(anchor_str) = tbl.get::<String>("anchor") {
            let s = anchor_str.to_lowercase();
            meta.anchor_top = s.contains("top");
            meta.anchor_bottom = s.contains("bottom");
            meta.anchor_left = s.contains("left");
            meta.anchor_right = s.contains("right");
        } else if let Ok(anchor_tbl) = tbl.get::<LuaTable>("anchor") {
            meta.anchor_top = anchor_tbl.get("top").unwrap_or(false);
            meta.anchor_bottom = anchor_tbl.get("bottom").unwrap_or(false);
            meta.anchor_left = anchor_tbl.get("left").unwrap_or(false);
            meta.anchor_right = anchor_tbl.get("right").unwrap_or(false);
        }

        if let Ok(m) = tbl.get::<i32>("margins") {
            meta.margin_top = m;
            meta.margin_right = m;
            meta.margin_bottom = m;
            meta.margin_left = m;
        } else if let Ok(m_tbl) = tbl.get::<LuaTable>("margins") {
            meta.margin_top = m_tbl.get("top").unwrap_or(0);
            meta.margin_right = m_tbl.get("right").unwrap_or(0);
            meta.margin_bottom = m_tbl.get("bottom").unwrap_or(0);
            meta.margin_left = m_tbl.get("left").unwrap_or(0);
        }

        if let Ok(w) = tbl.get::<u32>("width") {
            meta.width = Some(w);
        }
        if let Ok(h) = tbl.get::<u32>("height") {
            meta.height = Some(h);
        }
        if let Ok(l) = tbl.get::<String>("layer") {
            meta.layer = Some(l);
        }
        if let Ok(ez) = tbl.get::<i32>("exclusive_zone") {
            meta.exclusive_zone = Some(ez);
        }
        if let Ok(kb) = tbl.get::<String>("keyboard") {
            meta.keyboard_mode = Some(kb);
        }

        meta
    }

    fn parse_style(tbl: &LuaTable) -> Result<NodeStyle, LuaError> {
        let mut style = NodeStyle::default();

        if let Ok(of) = tbl.get::<String>("overflow") {
            match of.to_lowercase().as_str() {
                "scroll" => style.overflow = zenith_layout::Overflow::Scroll,
                "hidden" => style.overflow = zenith_layout::Overflow::Hidden,
                _ => style.overflow = zenith_layout::Overflow::Visible,
            }
        }

        if let Ok(sy) = tbl.get::<f32>("scroll_offset_y") {
            style.scroll_offset_y = sy;
        }

        if let Ok(w) = tbl.get::<f32>("width") {
            style.width = Some(w);
        }
        if let Ok(h) = tbl.get::<f32>("height") {
            style.height = Some(h);
        }

        if let Ok(dir) = tbl.get::<String>("direction") {
            if dir == "column" {
                style.flex_direction = FlexDirection::Column;
                style.align_items = Some(AlignItems::STRETCH);
            }
        }

        if let Ok(jc) = tbl.get::<String>("justify_content") {
            style.justify_content = match jc.to_lowercase().as_str() {
                "center" => Some(JustifyContent::CENTER),
                "space-between" | "space_between" => Some(JustifyContent::SPACE_BETWEEN),
                "space-around" | "space_around" => Some(JustifyContent::SPACE_AROUND),
                "space-evenly" | "space_evenly" => Some(JustifyContent::SPACE_EVENLY),
                "flex-start" | "flex_start" | "start" => Some(JustifyContent::FLEX_START),
                "flex-end" | "flex_end" | "end" => Some(JustifyContent::FLEX_END),
                _ => None,
            };
        }

        if let Ok(ai) = tbl.get::<String>("align_items") {
            style.align_items = match ai.to_lowercase().as_str() {
                "center" => Some(AlignItems::CENTER),
                "flex-start" | "flex_start" | "start" => Some(AlignItems::FLEX_START),
                "flex-end" | "flex_end" | "end" => Some(AlignItems::FLEX_END),
                "stretch" => Some(AlignItems::STRETCH),
                "baseline" => Some(AlignItems::BASELINE),
                _ => None,
            };
        }

        if let Ok(grow) = tbl.get::<f32>("flex_grow") {
            style.flex_grow = grow;
        }

        if let Ok(shrink) = tbl.get::<f32>("flex_shrink") {
            style.flex_shrink = shrink;
        }

        if let Ok(mw) = tbl.get::<f32>("max_width") {
            style.max_width = Some(mw);
        }


        if let Ok(gap) = tbl.get::<f32>("gap") {

            style.gap = gap;
        }

        if let Ok(pad) = tbl.get::<f32>("padding") {
            style.padding = [pad, pad, pad, pad];
        } else if let Ok(pad_tbl) = tbl.get::<LuaTable>("padding") {
            let x: f32 = pad_tbl.get("x").unwrap_or(0.0);
            let y: f32 = pad_tbl.get("y").unwrap_or(0.0);
            let top: f32 = pad_tbl.get("top").unwrap_or(y);
            let right: f32 = pad_tbl.get("right").unwrap_or(x);
            let bottom: f32 = pad_tbl.get("bottom").unwrap_or(y);
            let left: f32 = pad_tbl.get("left").unwrap_or(x);
            style.padding = [top, right, bottom, left];
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

        if let Ok(frag) = tbl.get::<String>("shader") {
            let mut uniforms = Vec::new();
            if let Ok(u_tbl) = tbl.get::<LuaTable>("uniforms") {
                for pair in u_tbl.pairs::<String, f32>().flatten() {
                    uniforms.push(pair);
                }
            }
            style.custom_shader = Some(zenith_layout::CustomShaderStyle {
                fragment: frag,
                uniforms,
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
            assert(ws2.active ~= nil, "active workspace should be present after dispatch")

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
            "BluetoothPopup",
            "BatteryPopup",
            "LockScreen",
            "Settings",
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

        let entrypoints = ["dock", "canvas", "island"];
        for name in &entrypoints {
            let path = format!("config/zenith/{}.luau", name);
            let parent_path = format!("../../config/zenith/{}.luau", name);
            let code = std::fs::read_to_string(&path)
                .or_else(|_| std::fs::read_to_string(&parent_path))
                .unwrap_or_else(|_| panic!("Could not read entrypoint {}", name));
            let res = runtime.eval_ui(&code);
            assert!(res.is_ok(), "Evaluating entrypoint {} failed: {:?}", name, res.err());
        }
    }

    #[test]
    fn test_all_26_widgets_evaluation() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let widgets = [
            "audio", "battery", "cava", "clipboard", "clock",
            "focused_app", "hardware", "kde_connect", "keyboard", "launcher",
            "media", "network", "notifications", "overview", "pill",
            "pomodoro", "privacy", "quick_status", "session", "settings_hub",
            "tray", "tweaks", "usb", "utility_hub", "weather", "workspaces",
        ];
        for widget in &widgets {
            let script = format!(r#"
                local W = Zenith.import("widgets/{}")
                assert(W ~= nil, "Widget module {} returned nil")
                if type(W) == "function" then
                    local node = W()
                    assert(type(node) == "table" or node == nil, "Widget constructor did not return table or nil")
                end
                return Zenith.Box({{ children = {{}} }})
            "#, widget, widget);
            let res = runtime.eval_ui(&script);
            assert!(res.is_ok(), "Evaluating widget '{}' failed: {:?}", widget, res.err());
        }
    }

    #[test]
    fn test_all_17_settings_pages_evaluation() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let path = "config/zenith/overlays/Settings.luau";
        let parent_path = "../../config/zenith/overlays/Settings.luau";
        let code = std::fs::read_to_string(path)
            .or_else(|_| std::fs::read_to_string(parent_path))
            .expect("Could not read Settings.luau");

        for page in 0..=16 {
            let _ = runtime.storage.set("settings_active_page", serde_json::Value::from(page));
            let res = runtime.eval_ui(&code);
            assert!(res.is_ok(), "Evaluating Settings.luau for page {} failed: {:?}", page, res.err());
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
            if #clients >= 1 then
                assert(type(clients[1].address) == "string", "Client address must be string")
                assert(type(clients[1].class) == "string", "Client class must be string")
                Zenith.focus_window(clients[1].address)
            end
            return Zenith.Box {
                children = {}
            }
        "#;
        let node = runtime.eval_ui(script);
        assert!(node.is_ok(), "Clients Luau evaluation should succeed: {:?}", node.err());
    }

    #[test]
    fn test_tray_and_spectrum_service_luau() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let script = r#"
            local tray = Zenith.Services.Tray()
            assert(type(tray) == "table", "Tray must return a table")

            local spec = Zenith.Services.Spectrum(8)
            assert(type(spec) == "table", "Spectrum must return a table")
            assert(#spec == 8, "Spectrum must have 8 bars")

            local gaps = Zenith.Services.HyprlandGaps()
            assert(type(gaps.gaps_out) == "number", "gaps_out must be number")

            return Zenith.Box {
                children = {}
            }
        "#;
        let node = runtime.eval_ui(script);
        assert!(node.is_ok(), "Tray/Spectrum evaluation should succeed: {:?}", node.err());
    }

    #[test]
    fn test_search_query_state() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        runtime.set_search_query("firefox");
        runtime.set_selected_index(2);
        assert_eq!(runtime.get_search_query(), "firefox");
        assert_eq!(runtime.get_selected_index(), 2);

        let script = r#"
            local q = Zenith.get_search_query()
            local idx = Zenith.get_selected_index()
            assert(q == "firefox", "query mismatch")
            assert(idx == 2, "idx mismatch")
            Zenith.set_search_query("kitty")
            return Zenith.Box { children = {} }
        "#;
        let node = runtime.eval_ui(script);
        assert!(node.is_ok());
        assert_eq!(runtime.get_search_query(), "kitty");
    }

    #[test]
    fn test_network_and_bluetooth_and_dnd_luau() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let script = r#"
            local net = Zenith.Services.Network()
            assert(type(net.connected) == "boolean", "Network.connected must be boolean")

            local wifis = Zenith.Services.WifiScan()
            assert(type(wifis) == "table", "WifiScan must return table")

            local bt = Zenith.Services.Bluetooth()
            assert(type(bt.powered) == "boolean", "Bluetooth.powered must be boolean")
            assert(type(bt.devices) == "table", "Bluetooth.devices must be table")

            local dnd = Zenith.Services.IsDND()
            assert(type(dnd) == "boolean", "IsDND must return boolean")

            local hist = Zenith.Services.NotificationHistory()
            assert(type(hist) == "table", "NotificationHistory must return table")

            return Zenith.Box { children = {} }
        "#;
        let node = runtime.eval_ui(script);
        assert!(node.is_ok(), "Network/Bluetooth/DND Luau evaluation failed: {:?}", node.err());
    }

    #[test]
    fn test_signals_and_reactive_text() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let script = r#"
            local sig = Zenith.Signal("Initial Signal Text")
            assert(sig:get() == "Initial Signal Text", "Signal get should work")
            assert(sig() == "Initial Signal Text", "Signal callable syntax should work")
            sig:set("Updated Signal Text")
            assert(sig:get() == "Updated Signal Text", "Signal set should update value")

            local t_fn = Zenith.Signals.Time
            assert(type(t_fn()) == "string", "Signals.Time should return string")

            return Zenith.Box({
                children = {
                    Zenith.Text({ text = sig }),
                    Zenith.Text({ text = Zenith.Signals.Time })
                }
            })
        "#;
        let node = runtime.eval_ui(script).expect("eval_ui failed with signals");
        match node {
            UiNode::Box { children, .. } => {
                assert_eq!(children.len(), 2);
                match &children[0] {
                    UiNode::Text { text, .. } => assert_eq!(text, "Updated Signal Text"),
                    _ => panic!("Expected text node"),
                }
                match &children[1] {
                    UiNode::Text { text, .. } => assert!(!text.is_empty()),
                    _ => panic!("Expected text node"),
                }
            }
            _ => panic!("Expected box root"),
        }
    }

    #[test]
    fn test_eval_ui_bytecode_cache() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let script = r#"
            return Zenith.Box({
                children = {
                    Zenith.Text({ text = "Cached Box" })
                }
            })
        "#;
        assert_eq!(runtime.script_cache.read().unwrap().len(), 0);

        // First eval populates cache
        let node1 = runtime.eval_ui(script).expect("eval 1 failed");
        assert_eq!(runtime.script_cache.read().unwrap().len(), 1);

        // Second eval hits cache
        let node2 = runtime.eval_ui(script).expect("eval 2 failed");
        assert_eq!(runtime.script_cache.read().unwrap().len(), 1);
        assert_eq!(node1, node2);

        // Clearing cache empties it
        runtime.clear_module_cache();
        assert_eq!(runtime.script_cache.read().unwrap().len(), 0);
    }

    #[test]
    fn test_text_input_image_window_and_new_services() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let script = r#"
            local bright = Zenith.Services.Brightness()
            assert(type(bright.percent) == "number", "Brightness.percent must be number")

            local disk = Zenith.Services.Disk()
            assert(type(disk.total_gb) == "number", "Disk.total_gb must be number")
            assert(type(disk.percent) == "number", "Disk.percent must be number")

            local power = Zenith.Services.PowerProfile()
            assert(type(power) == "string", "PowerProfile must be string")

            Zenith.set_focused_input("main_input")
            assert(Zenith.get_focused_input() == "main_input", "Focus getter/setter mismatch")

            Zenith.set_input_text("main_input", "typed text")
            assert(Zenith.get_input_text("main_input") == "typed text", "Input buffer mismatch")

            return Zenith.Window({
                anchor = "top-right",
                margins = { top = 8, right = 14 },
                layer = "top",
                exclusive_zone = 0,
                keyboard = "on_demand",
                children = {
                    Zenith.Box({
                        overflow = "scroll",
                        scroll_offset_y = 20,
                        children = {
                            Zenith.TextInput({
                                id = "main_input",
                                text = "Search...",
                                placeholder = "Type here",
                                font_size = 13,
                                active = true,
                                on_change = function(t) end,
                                on_submit = function(t) end,
                            }),
                            Zenith.Image({
                                src = "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'></svg>",
                                width = 16,
                                height = 16,
                            }),
                        }
                    })
                }
            })
        "#;
        let root = runtime.eval_ui(script).expect("Failed to evaluate test script");
        match root {
            UiNode::Window { meta, children, .. } => {
                assert!(meta.anchor_top);
                assert!(meta.anchor_right);
                assert_eq!(meta.margin_top, 8);
                assert_eq!(meta.margin_right, 14);
                assert_eq!(meta.layer.as_deref(), Some("top"));
                assert_eq!(children.len(), 1);

                match &children[0] {
                    UiNode::Box { style, children: inner, .. } => {
                        assert_eq!(style.overflow, zenith_layout::Overflow::Scroll);
                        assert_eq!(style.scroll_offset_y, 20.0);
                        assert_eq!(inner.len(), 2);

                        match &inner[0] {
                            UiNode::TextInput { id, text, active, .. } => {
                                assert_eq!(id.as_deref(), Some("main_input"));
                                assert_eq!(text, "Search...");
                                assert!(active);
                            }
                            _ => panic!("Expected TextInput node"),
                        }

                        match &inner[1] {
                            UiNode::Image { src, .. } => {
                                assert!(src.starts_with("<svg"));
                            }
                            _ => panic!("Expected Image node"),
                        }
                    }
                    _ => panic!("Expected Box node"),
                }
            }
            _ => panic!("Expected Window root node"),
        }
    }

    #[test]
    fn test_reactive_signals_effects_and_mount_tree() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let script = r#"
            local count, setCount = Zenith.signal(10)
            assert(count() == 10, "Signal getter initial value")
            
            local effect_runs = 0
            Zenith.effect(function()
                local val = count()
                effect_runs = effect_runs + 1
            end)
            assert(effect_runs == 1, "Effect should run immediately upon creation")

            setCount(25)
            assert(count() == 25, "Signal setter should update value")
            assert(effect_runs == 2, "Effect should re-run after signal update")

            return Zenith.Box({
                children = {
                    Zenith.Text({ text = count }),
                }
            })
        "#;

        let node = runtime.mount_tree("test_bar", script).expect("mount_tree failed");
        match &node {
            UiNode::Box { children, .. } => {
                assert_eq!(children.len(), 1);
                match &children[0] {
                    UiNode::Text { text, .. } => assert_eq!(text, "25"),
                    _ => panic!("Expected text node"),
                }
            }
            _ => panic!("Expected box root"),
        }
        assert!(runtime.is_tree_dirty("test_bar"));
        runtime.mark_tree_clean("test_bar");
        assert!(!runtime.is_tree_dirty("test_bar"));
    }

    #[test]
    fn test_custom_shader_node_parsing() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let script = r#"
            return Zenith.Box({
                shader = "void main() { frag_color = vec4(1.0, 0.0, 0.0, 1.0); }",
                uniforms = {
                    speed = 2.5,
                    intensity = 0.8
                },
                children = {
                    Zenith.Shader({
                        fragment = "void main() { frag_color = vec4(0.0, 1.0, 0.0, 1.0); }",
                        uniforms = {
                            freq = 440.0
                        }
                    })
                }
            })
        "#;

        let node = runtime.eval_ui(script).expect("Failed to eval shader UI");
        match node {
            UiNode::Box { style, children, .. } => {
                let shader = style.custom_shader.expect("Expected Box custom_shader");
                assert!(shader.fragment.contains("frag_color = vec4(1.0"));
                assert!(shader.uniforms.iter().any(|(k, v)| k == "speed" && (*v - 2.5).abs() < 1e-4));
                assert_eq!(children.len(), 1);

                match &children[0] {
                    UiNode::Shader { fragment, uniforms, .. } => {
                        assert!(fragment.contains("frag_color = vec4(0.0, 1.0"));
                        assert!(uniforms.iter().any(|(k, v)| k == "freq" && (*v - 440.0).abs() < 1e-4));
                    }
                    _ => panic!("Expected Shader child node"),
                }
            }
            _ => panic!("Expected Box root node"),
        }
    }

    #[test]
    fn test_repl_eval_code() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let expr_res = runtime.eval_code("10 + 32").expect("eval expression failed");
        assert!(expr_res.contains("42"));

        let storage_res = runtime.eval_code("Zenith.Storage.set('repl_test', 99)").expect("eval statement failed");
        assert!(storage_res.contains("nil"));

        let get_res = runtime.eval_code("Zenith.Storage.get('repl_test', 0)").expect("eval get failed");
        assert!(get_res.contains("99"));
    }

    #[test]
    fn test_editor_engine_runtime_integration() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let id = "test_input";
        runtime.set_input_text(id, "zenith shell");

        // Select all and copy
        runtime.editor_select_all(id);
        let copied = runtime.editor_copy(id);
        assert_eq!(copied.as_deref(), Some("zenith shell"));

        // Insert text replacing selection
        runtime.editor_insert(id, "replaced");
        assert_eq!(runtime.get_input_text(id), "replaced");

        // Undo & Redo
        assert!(runtime.editor_undo(id));
        assert_eq!(runtime.get_input_text(id), "zenith shell");
        assert!(runtime.editor_redo(id));
        assert_eq!(runtime.get_input_text(id), "replaced");

        // Cursor movement
        runtime.editor_move_cursor(id, zenith_layout::CursorDirection::Home, false);
        let (cursor, sel) = runtime.get_editor_state(id);
        assert_eq!(cursor, 0);
        assert_eq!(sel, None);
    }

    #[test]
    fn test_slider_switch_virtual_list_runtime() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let script = r#"
            local slider = Zenith.Slider({
                id = "vol_slider",
                min = 0,
                max = 100,
                value = 75,
                track_height = 8,
                thumb_radius = 12,
            })

            local switch = Zenith.Switch({
                id = "wifi_toggle",
                checked = true,
            })

            local list = Zenith.VirtualList({
                items = { "Item 1", "Item 2", "Item 3", "Item 4" },
                item_height = 40,
                visible_height = 80,
                scroll_offset = 0,
                render_item = function(item, index)
                    return Zenith.Text({ text = item })
                end,
            })

            return Zenith.Box({
                children = { slider, switch, list }
            })
        "#;

        let node = runtime.eval_ui(script).expect("failed to eval ui tree with widgets");
        match node {
            UiNode::Box { children, .. } => {
                assert_eq!(children.len(), 3);
                match &children[0] {
                    UiNode::Slider { id, value, .. } => {
                        assert_eq!(id.as_deref(), Some("vol_slider"));
                        assert_eq!(*value, 75.0);
                    }
                    _ => panic!("Expected Slider node"),
                }
                match &children[1] {
                    UiNode::Switch { id, checked, .. } => {
                        assert_eq!(id.as_deref(), Some("wifi_toggle"));
                        assert!(*checked);
                    }
                    _ => panic!("Expected Switch node"),
                }
                match &children[2] {
                    UiNode::Box { children: list_children, style, .. } => {
                        assert_eq!(style.overflow, zenith_layout::Overflow::Scroll);
                        assert!(!list_children.is_empty());
                    }
                    _ => panic!("Expected Box node for VirtualList"),
                }
            }
            _ => panic!("Expected root Box node"),
        }
    }

    #[test]
    fn test_zenith_ui_kit_design_system_integration() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let script = r#"
            local UIKit = Zenith.import("ui_kit")
            local Button = UIKit.Button
            local Slider = UIKit.Slider
            local Switch = UIKit.Switch
            local Card = UIKit.Card
            local VirtualList = UIKit.VirtualList

            local btn = Button({
                label = "Apply Theme",
                icon = "󰔎",
                variant = "primary",
                on_click = "apply_theme",
            })

            local slider = Slider({
                id = "brightness_slider",
                min = 0,
                max = 100,
                value = 80,
                label = "Brightness",
                show_value = true,
            })

            local switch = Switch({
                id = "night_light",
                checked = true,
                label = "Night Light",
                subtitle = "Warm screen colors",
            })

            local list = VirtualList({
                items = { "Color 1", "Color 2", "Color 3" },
                item_height = 30,
                visible_height = 90,
                render_item = function(item, idx)
                    return Zenith.Text({ text = item })
                end,
            })

            return Card({
                variant = "glass",
                children = { btn, slider, switch, list },
            })
        "#;

        let node = runtime.eval_ui(script).expect("failed to eval ui tree with UI Kit components");
        match node {
            UiNode::Box { children, style, .. } => {
                assert_eq!(style.border_radius, 14.0);
                assert_eq!(children.len(), 4);
            }
            _ => panic!("Expected root Card/Box node"),
        }
    }

    #[test]
    fn test_luau_box_tooltip_parsing() {
        let runtime = LuauRuntime::new().unwrap();
        let script = r#"
            return Zenith.Box({
                tooltip = "Battery: 85% charging",
                children = {
                    Zenith.Text({ text = "85%" })
                }
            })
        "#;
        let node = runtime.eval_ui(script).unwrap();
        match node {
            UiNode::Box { tooltip, .. } => {
                assert_eq!(tooltip.as_deref(), Some("Battery: 85% charging"));
            }
            _ => panic!("Expected Box node"),
        }
    }

    #[test]
    fn test_zenith_ui_kit_matugen_tokens_and_reactive_widgets() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let script = r#"
            local UIKit = Zenith.import("ui_kit")
            assert(UIKit.Tokens ~= nil, "UIKit.Tokens should exist")
            assert(UIKit.Tokens.colors ~= nil, "Tokens.colors should exist")
            assert(UIKit.Tokens.colors.primary ~= nil, "primary token should exist")
            assert(UIKit.Tokens.colors.surface ~= nil, "surface token should exist")
            assert(UIKit.Tokens.typography ~= nil, "Tokens.typography should exist")
            assert(UIKit.Tokens.shapes ~= nil, "Tokens.shapes should exist")

            -- Test Signals subsystem
            assert(UIKit.Signals ~= nil, "UIKit.Signals should exist")
            local sig, setSig = UIKit.Signals.create("Reactive Pill Text")
            assert(sig() == "Reactive Pill Text", "Signal getter callable")
            setSig("Updated Pill Text")
            assert(sig() == "Updated Pill Text", "Signal setter updated")

            -- Test Widgets catalog
            assert(UIKit.Widgets ~= nil, "UIKit.Widgets should exist")
            local pill = UIKit.Widgets.Pill({
                label = sig,
                icon = "󰌌",
            })
            assert(pill ~= nil, "Pill widget with signal created")

            local clock = UIKit.Widgets.Clock({ reactive = true })
            assert(clock ~= nil, "Reactive clock created")

            local hw = UIKit.Widgets.Hardware({ reactive = true })
            assert(hw ~= nil, "Reactive hardware monitor created")

            return Zenith.Box({
                children = { pill, clock, hw }
            })
        "#;
        let node = runtime.eval_ui(script).expect("failed to eval ui tree with UI Kit signals and tokens");
        match node {
            UiNode::Box { children, .. } => {
                assert_eq!(children.len(), 3);
            }
            _ => panic!("Expected root Box node"),
        }
    }

    #[test]
    fn test_trigger_click_sanitized_spawner() {
        let runtime = LuauRuntime::new().unwrap();
        assert!(runtime.trigger_click("cmd:true").is_ok());
        assert!(runtime.trigger_click("true").is_ok());
    }

    #[test]
    fn test_wave33_luau_bindings_and_services() {
        let runtime = LuauRuntime::new().expect("Failed to create LuauRuntime");
        let script = r#"
            -- Test Backlight / Brightness service & methods
            local bright = Zenith.Services.Brightness()
            assert(type(bright) == "table", "Brightness must return table")
            assert(type(bright.percent) == "number", "Brightness.percent must be number")
            assert(type(bright.current) == "number", "Brightness.current must be number")
            assert(type(bright.max) == "number", "Brightness.max must be number")
            assert(type(bright.device) == "string", "Brightness.device must be string")

            Zenith.Services.SetBrightness(75)
            Zenith.Services.InvalidateBrightnessCache()
            Zenith.Services.RefreshBrightness()
            local stepped = Zenith.Services.StepBrightness(5)
            assert(type(stepped) == "number", "StepBrightness must return number")

            -- Test Tray service & methods
            local tray = Zenith.Services.Tray()
            assert(type(tray) == "table", "Tray must return table")
            Zenith.Services.TrayActivate("org.kde.StatusNotifierItem-1-1")
            Zenith.Services.TrayContextMenu("org.kde.StatusNotifierItem-1-1")
            Zenith.Services.TraySecondaryActivate("org.kde.StatusNotifierItem-1-1")
            Zenith.Services.TrayScroll("org.kde.StatusNotifierItem-1-1", 1, "vertical")

            -- Test Idle state service & signals
            local idle_state = Zenith.Services.Idle()
            assert(type(idle_state) == "table", "Idle must return table")
            assert(type(idle_state.is_idle) == "boolean", "Idle.is_idle must be boolean")
            assert(Zenith.Services.IsIdle() == false, "Initial IsIdle must be false")

            Zenith.Services.SetIdle(true)
            assert(Zenith.Services.IsIdle() == true, "IsIdle should be true after SetIdle(true)")
            assert(Zenith.Signals.is_idle() == true, "Signals.is_idle should be true")

            Zenith.Services.SetIdle(false)
            assert(Zenith.Services.IsIdle() == false, "IsIdle should be false after SetIdle(false)")
            assert(Zenith.Signals.is_idle() == false, "Signals.is_idle should be false")

            return Zenith.Box({ children = {} })
        "#;
        let node = runtime.eval_ui(script);
        assert!(node.is_ok(), "Wave 3.3 bindings test failed: {:?}", node.err());

        // Test trigger_click for tray, brightness, idle
        assert!(runtime.trigger_click("tray:activate:test").is_ok());
        assert!(runtime.trigger_click("tray:context:test").is_ok());
        assert!(runtime.trigger_click("tray:secondary:test").is_ok());
        assert!(runtime.trigger_click("tray:scroll:test:2").is_ok());
        assert!(runtime.trigger_click("brightness:set:80").is_ok());
        assert!(runtime.trigger_click("brightness:step:5").is_ok());
        assert!(runtime.trigger_click("idle:set:true").is_ok());
        assert!(runtime.is_idle());
        assert!(runtime.trigger_click("idle:toggle").is_ok());
        assert!(!runtime.is_idle());
    }
}
