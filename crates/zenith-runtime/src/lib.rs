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

/// Opaque password buffer with volatile zeroization on drop and clear.
#[derive(Default)]
pub struct SecurePasswordBuffer {
    bytes: Vec<u8>,
}

impl Drop for SecurePasswordBuffer {
    fn drop(&mut self) {
        self.zeroize();
    }
}

impl SecurePasswordBuffer {
    pub fn new() -> Self {
        Self { bytes: Vec::new() }
    }

    pub fn push_str(&mut self, s: &str) {
        self.bytes.extend_from_slice(s.as_bytes());
    }

    pub fn pop(&mut self) {
        if let Ok(s) = std::str::from_utf8(&self.bytes) {
            if let Some(ch) = s.chars().last() {
                let char_len = ch.len_utf8();
                let new_len = self.bytes.len().saturating_sub(char_len);
                for b in &mut self.bytes[new_len..] {
                    unsafe { std::ptr::write_volatile(b, 0) };
                }
                std::sync::atomic::compiler_fence(std::sync::atomic::Ordering::SeqCst);
                self.bytes.truncate(new_len);
            }
        }
    }

    pub fn zeroize(&mut self) {
        for b in &mut self.bytes {
            unsafe { std::ptr::write_volatile(b, 0) };
        }
        std::sync::atomic::compiler_fence(std::sync::atomic::Ordering::SeqCst);
    }

    pub fn clear(&mut self) {
        self.zeroize();
        self.bytes.clear();
    }

    pub fn len(&self) -> usize {
        std::str::from_utf8(&self.bytes).map(|s| s.chars().count()).unwrap_or(0)
    }

    pub fn is_empty(&self) -> bool {
        self.bytes.is_empty()
    }

    pub fn take_password(&mut self) -> String {
        let res = String::from_utf8_lossy(&self.bytes).to_string();
        self.clear();
        res
    }
}

/// Anti-brute-force rate limiter with exponential backoff lockout after 3 failed attempts.
#[derive(Default)]
pub struct LockoutManager {
    failed_attempts: usize,
    lockout_until: Option<std::time::Instant>,
}

impl LockoutManager {
    pub fn new() -> Self {
        Self {
            failed_attempts: 0,
            lockout_until: None,
        }
    }

    pub fn record_failure(&mut self) -> u64 {
        self.failed_attempts += 1;
        if self.failed_attempts >= 3 {
            let exponent = (self.failed_attempts - 3).min(5);
            let delay_secs = (2u64.pow(exponent as u32)).min(30);
            let until = std::time::Instant::now() + std::time::Duration::from_secs(delay_secs);
            self.lockout_until = Some(until);
            delay_secs
        } else {
            0
        }
    }

    pub fn record_success(&mut self) {
        self.failed_attempts = 0;
        self.lockout_until = None;
    }

    pub fn is_locked_out(&self) -> bool {
        if let Some(until) = self.lockout_until {
            std::time::Instant::now() < until
        } else {
            false
        }
    }

    pub fn remaining_lockout_secs(&self) -> u64 {
        if let Some(until) = self.lockout_until {
            let now = std::time::Instant::now();
            if until > now {
                return (until - now).as_secs() + 1;
            }
        }
        0
    }
}

/// Core reactive system signal IDs tracked by LuauRuntime.
#[derive(Clone, Copy, Debug)]
pub struct SystemSignals {
    pub time: SignalId,
    pub date: SignalId,
    pub cpu: SignalId,
    pub memory: SignalId,
    pub active_window: SignalId,
    pub brightness: SignalId,
    pub keyboard: SignalId,
}

/// Runtime environment executing user Luau configs.
pub struct LuauRuntime {
    lua: Lua,
    pub reactive: Arc<ReactiveGraph>,
    pub worker_pool: Arc<WorkerThreadPool>,
    pub storage: Arc<StorageEngine>,
    pub is_idle: Arc<AtomicBool>,
    pub close_requested: Arc<AtomicBool>,
    search_query: Arc<RwLock<String>>,
    selected_index: Arc<RwLock<usize>>,
    current_output: Arc<RwLock<String>>,
    current_geometry: Arc<RwLock<(u32, u32)>>,
    script_cache: Arc<RwLock<HashMap<u64, mlua::RegistryKey>>>,
    focused_input_id: Arc<RwLock<Option<String>>>,
    input_buffers: Arc<RwLock<HashMap<String, String>>>,
    editor_engines: Arc<RwLock<HashMap<String, zenith_layout::TextEditorEngine>>>,
    pub lock_password: Arc<RwLock<SecurePasswordBuffer>>,
    pub lockout: Arc<RwLock<LockoutManager>>,
    pub system_signals: SystemSignals,
}

impl LuauRuntime {
    /// Initialize the Luau virtual machine with Zenith standard library bindings.
    pub fn new() -> Result<Self, LuaError> {
        let lua = Lua::new();
        let is_idle = Arc::new(AtomicBool::new(false));
        let close_requested = Arc::new(AtomicBool::new(false));
        let storage = Arc::new(StorageEngine::new(None));
        let search_query = Arc::new(RwLock::new(String::new()));
        let selected_index = Arc::new(RwLock::new(1usize));
        let current_output = Arc::new(RwLock::new("default".to_string()));
        let current_geometry = Arc::new(RwLock::new((1366u32, 768u32)));
        let focused_input_id = Arc::new(RwLock::new(None));
        let input_buffers = Arc::new(RwLock::new(HashMap::new()));
        let editor_engines = Arc::new(RwLock::new(HashMap::new()));
        let reactive = Arc::new(crate::reactive::ReactiveGraph::new());
        let lock_password = Arc::new(RwLock::new(SecurePasswordBuffer::new()));
        let lockout = Arc::new(RwLock::new(LockoutManager::new()));


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

        // LockScreen Secure Password & Anti-Brute-Force Bindings
        let lp_clone1 = lock_password.clone();
        let lock_len_fn = lua.create_function(move |_, ()| {
            let len = lp_clone1.read().unwrap().len();
            Ok(len)
        })?;
        zenith_table.set("lock_pass_len", lock_len_fn.clone())?;
        zenith_table.set("get_lock_password_len", lock_len_fn.clone())?;

        let lp_clone2 = lock_password.clone();
        let lock_disp_fn = lua.create_function(move |_, ()| {
            let len = lp_clone2.read().unwrap().len();
            if len > 0 {
                Ok(format!("{}▎", "● ".repeat(len)))
            } else {
                Ok("Enter password to unlock...▎".to_string())
            }
        })?;
        zenith_table.set("lock_pass_display", lock_disp_fn.clone())?;

        let lo_clone1 = lockout.clone();
        let is_locked_fn = lua.create_function(move |_, ()| {
            Ok(lo_clone1.read().unwrap().is_locked_out())
        })?;
        zenith_table.set("is_locked_out", is_locked_fn.clone())?;

        let lo_clone2 = lockout.clone();
        let lock_rem_fn = lua.create_function(move |_, ()| {
            Ok(lo_clone2.read().unwrap().remaining_lockout_secs())
        })?;
        zenith_table.set("lockout_remaining_secs", lock_rem_fn.clone())?;

        let sec_table = lua.create_table()?;
        sec_table.set("pass_length", lock_len_fn)?;
        sec_table.set("get_display_dots", lock_disp_fn)?;
        sec_table.set("is_locked_out", is_locked_fn)?;
        sec_table.set("remaining_lockout_secs", lock_rem_fn)?;
        zenith_table.set("Security", sec_table)?;

        let user_fn = lua.create_function(|_, ()| {
            static CACHED_USER: std::sync::OnceLock<String> = std::sync::OnceLock::new();
            let user = CACHED_USER.get_or_init(|| {
                std::env::var("USER").unwrap_or_else(|_| "Zenith User".to_string())
            });
            Ok(user.clone())
        })?;

        zenith_table.set("user", user_fn.clone())?;
        zenith_table.set("User", user_fn)?;

        let host_fn = lua.create_function(|_, ()| {
            static CACHED_HOST: std::sync::OnceLock<String> = std::sync::OnceLock::new();
            let host = CACHED_HOST.get_or_init(|| {
                std::fs::read_to_string("/etc/hostname")
                    .map(|s| s.trim().to_string())
                    .or_else(|_| std::env::var("HOSTNAME"))
                    .unwrap_or_else(|_| "zenith".to_string())
            });
            Ok(host.clone())
        })?;

        zenith_table.set("host", host_fn.clone())?;
        zenith_table.set("hostname", host_fn)?;

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
                let sig_val = match &new_val {
                    LuaValue::Number(n) => crate::reactive::SignalValue::Float(*n as f32),
                    LuaValue::Integer(i) => crate::reactive::SignalValue::Float(*i as f32),
                    LuaValue::String(s) => crate::reactive::SignalValue::Text(s.to_string_lossy()),
                    LuaValue::Boolean(b) => crate::reactive::SignalValue::Boolean(*b),
                    _ => crate::reactive::SignalValue::Text(String::new()),
                };
                r2.notify_signal_value_change(lua, sig_id, sig_val);
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

        // Zenith.batch(callback) and Zenith.Batch
        let reactive_batch = reactive.clone();
        let batch_fn = lua.create_function(move |lua, callback: LuaFunction| {
            reactive_batch.batch(lua, || {
                callback.call::<()>(())
            })?;
            Ok(())
        })?;
        zenith_table.set("Batch", batch_fn.clone())?;
        zenith_table.set("batch", batch_fn)?;

        // Zenith.Signals (reactive system getters)
        let signals_table = lua.create_table()?;

        let (initial_time, initial_date) = zenith_services::SystemService::current_time();
        let initial_cpu = format!("{}%", zenith_services::SystemService::cpu_snapshot().percent);
        let initial_ram = format!("{}%", zenith_services::SystemService::memory_snapshot().percent);
        let initial_win = zenith_services::HyprlandService::active_window_snapshot().title;
        let initial_bright = format!("{}%", zenith_services::BrightnessService::get_brightness().percent);
        let initial_kb = zenith_services::HyprlandService::active_layout();

        let sig_time_id = crate::reactive::ReactiveGraph::next_signal_id();
        let sig_date_id = crate::reactive::ReactiveGraph::next_signal_id();
        let sig_cpu_id = crate::reactive::ReactiveGraph::next_signal_id();
        let sig_ram_id = crate::reactive::ReactiveGraph::next_signal_id();
        let sig_win_id = crate::reactive::ReactiveGraph::next_signal_id();
        let sig_bright_id = crate::reactive::ReactiveGraph::next_signal_id();
        let sig_kb_id = crate::reactive::ReactiveGraph::next_signal_id();

        let system_signals = SystemSignals {
            time: sig_time_id,
            date: sig_date_id,
            cpu: sig_cpu_id,
            memory: sig_ram_id,
            active_window: sig_win_id,
            brightness: sig_bright_id,
            keyboard: sig_kb_id,
        };

        let time_sig = Self::make_str_system_signal(&lua, &reactive, sig_time_id, &initial_time)?;
        signals_table.set("Time", time_sig.clone())?;
        signals_table.set("time", time_sig)?;

        let date_sig = Self::make_str_system_signal(&lua, &reactive, sig_date_id, &initial_date)?;
        signals_table.set("Date", date_sig.clone())?;
        signals_table.set("date", date_sig)?;

        let cpu_sig = Self::make_str_system_signal(&lua, &reactive, sig_cpu_id, &initial_cpu)?;
        signals_table.set("Cpu", cpu_sig.clone())?;
        signals_table.set("cpu", cpu_sig)?;

        let ram_sig = Self::make_str_system_signal(&lua, &reactive, sig_ram_id, &initial_ram)?;
        signals_table.set("Memory", ram_sig.clone())?;
        signals_table.set("memory", ram_sig)?;

        let win_sig = Self::make_str_system_signal(&lua, &reactive, sig_win_id, &initial_win)?;
        signals_table.set("ActiveWindow", win_sig.clone())?;
        signals_table.set("active_window", win_sig)?;

        let bright_sig = Self::make_str_system_signal(&lua, &reactive, sig_bright_id, &initial_bright)?;
        signals_table.set("Brightness", bright_sig.clone())?;
        signals_table.set("brightness", bright_sig)?;

        let idle_bool_sig = is_idle.clone();
        let idle_sig = lua.create_function(move |_, ()| {
            Ok(idle_bool_sig.load(Ordering::Relaxed))
        })?;
        signals_table.set("Idle", idle_sig.clone())?;
        signals_table.set("idle", idle_sig.clone())?;
        signals_table.set("IsIdle", idle_sig.clone())?;
        signals_table.set("is_idle", idle_sig)?;

        let kb_sig_tbl = Self::make_str_system_signal(&lua, &reactive, sig_kb_id, &initial_kb)?;
        signals_table.set("Keyboard", kb_sig_tbl.clone())?;
        signals_table.set("keyboard", kb_sig_tbl)?;

        let kb_fn = lua.create_function(|_, ()| {
            Ok(zenith_services::HyprlandService::active_layout())
        })?;
        signals_table.set("KeyboardLayout", kb_fn.clone())?;
        signals_table.set("keyboard_layout", kb_fn)?;

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
                tbl.set("percent", bat.percentage)?;
                tbl.set("status", bat.status)?;
                tbl.set("charging", bat.is_charging)?;
                tbl.set("is_charging", bat.is_charging)?;
                tbl.set("cycle_count", bat.cycle_count)?;
                tbl.set("health_pct", bat.health_pct)?;
                tbl.set("model_name", bat.model_name)?;
                tbl.set("uptime_str", bat.uptime_str)?;
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


        // Theme palette query with VM-level table memoization
        let theme_fn = lua.create_function(|lua, ()| {
            if let Ok(cached) = lua.globals().get::<LuaTable>("__zenith_cached_theme") {
                return Ok(cached);
            }
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
            let _ = lua.globals().set("__zenith_cached_theme", tbl.clone());
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
            tbl.set("address", snap.address)?;
            Ok(tbl)
        })?;
        services_table.set("ActiveWindow", active_window_fn.clone())?;
        services_table.set("active_window", active_window_fn.clone())?;
        services_table.set("activewindow", active_window_fn)?;

        // Hyprland / Compositor Clients service
        let clients_fn = lua.create_function(|lua, ()| {
            let list = zenith_services::HyprlandService::clients_snapshot();
            let active_addr = zenith_services::HyprlandService::active_window_snapshot().address;
            let active_clean = active_addr.trim_start_matches("0x");
            let tbl = lua.create_table()?;
            for (idx, c) in list.into_iter().enumerate() {
                let item = lua.create_table()?;
                let c_clean = c.address.trim_start_matches("0x");
                let is_focused = !active_clean.is_empty() && c_clean.eq_ignore_ascii_case(active_clean);
                item.set("focused", is_focused)?;
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
                let cat_tbl = lua.create_table()?;
                for (c_idx, cat) in app.categories.into_iter().enumerate() {
                    cat_tbl.set(c_idx + 1, cat)?;
                }
                app_tbl.set("categories", cat_tbl)?;
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

        // Clipboard History service via cliphist (cached, non-blocking)
        let clip_fn = lua.create_function(|lua, ()| {
            let tbl = lua.create_table()?;
            let items = zenith_services::ClipboardService::get_history();
            for (idx, item) in items.into_iter().enumerate() {
                let entry = lua.create_table()?;
                entry.set("id", item.id)?;
                entry.set("text", item.text.clone())?;
                entry.set("content", item.text)?;
                entry.set("is_image", item.is_image)?;
                tbl.set(idx + 1, entry)?;
            }
            Ok(tbl)
        })?;
        services_table.set("ClipboardHistory", clip_fn.clone())?;
        services_table.set("clipboard_history", clip_fn)?;

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

        let notif_set_dnd_fn = lua.create_function(|_, enabled: bool| {
            zenith_services::NotificationService::set_dnd(enabled);
            Ok(())
        })?;
        services_table.set("SetDND", notif_set_dnd_fn.clone())?;
        services_table.set("set_dnd", notif_set_dnd_fn)?;

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
            let mut connected = false;
            let mut device_name: Option<String> = None;
            let dev_tbl = lua.create_table()?;
            for (idx, d) in s.devices.into_iter().enumerate() {
                if d.connected {
                    connected = true;
                    if device_name.is_none() {
                        device_name = Some(d.name.clone());
                    }
                }
                let item = lua.create_table()?;
                item.set("mac", d.mac)?;
                item.set("name", d.name)?;
                item.set("connected", d.connected)?;
                item.set("battery", d.battery.unwrap_or(0))?;
                dev_tbl.set(idx + 1, item)?;
            }
            tbl.set("devices", dev_tbl)?;
            tbl.set("connected", connected)?;
            if let Some(name) = device_name {
                tbl.set("device_name", name)?;
            }
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
        let storage_weather = Arc::clone(&storage);
        let weather_fn = lua.create_function(move |lua, ()| {
            let city = storage_weather.get("weatherCity").and_then(|v| v.as_str().map(|s| s.to_string()));
            let units = storage_weather.get("weatherUnits").and_then(|v| v.as_str().map(|s| s.to_string()));
            if let Some(c) = city.as_deref() {
                zenith_services::WeatherService::set_config(c, units.as_deref().unwrap_or("metric"));
            }
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

        // Foreign Toplevel Management service (zwlr_foreign_toplevel_management_v1)
        let toplevels_fn = lua.create_function(|lua, ()| {
            let list = zenith_services::ToplevelService::get_toplevels();
            let tbl = lua.create_table()?;
            for (idx, t) in list.into_iter().enumerate() {
                let item = lua.create_table()?;
                item.set("id", t.id.to_string())?;
                item.set("title", t.title)?;
                item.set("app_id", t.app_id)?;
                let state_tbl = lua.create_table()?;
                state_tbl.set("active", t.activated)?;
                state_tbl.set("minimized", t.minimized)?;
                state_tbl.set("maximized", t.maximized)?;
                state_tbl.set("fullscreen", t.fullscreen)?;
                item.set("state", state_tbl)?;
                tbl.set(idx + 1, item)?;
            }
            Ok(tbl)
        })?;
        services_table.set("Toplevels", toplevels_fn.clone())?;
        services_table.set("toplevels", toplevels_fn)?;

        let toplevel_activate_fn = lua.create_function(|_, id_str: String| {
            if let Ok(id) = id_str.parse::<u32>() {
                zenith_services::ToplevelService::send_action(zenith_services::ToplevelAction::Activate(id));
            } else {
                let _ = zenith_services::HyprlandService::focus_window(&id_str);
            }
            Ok(())
        })?;
        services_table.set("ToplevelActivate", toplevel_activate_fn.clone())?;
        services_table.set("toplevel_activate", toplevel_activate_fn)?;

        let toplevel_close_fn = lua.create_function(|_, id_str: String| {
            if let Ok(id) = id_str.parse::<u32>() {
                zenith_services::ToplevelService::send_action(zenith_services::ToplevelAction::Close(id));
            } else {
                let _ = zenith_services::HyprlandService::dispatch("closewindow", &format!("address:{}", id_str));
            }
            Ok(())
        })?;
        services_table.set("ToplevelClose", toplevel_close_fn.clone())?;
        services_table.set("toplevel_close", toplevel_close_fn)?;

        let toplevel_set_minimized_fn = lua.create_function(|_, (id_str, min): (String, bool)| {
            if let Ok(id) = id_str.parse::<u32>() {
                zenith_services::ToplevelService::send_action(zenith_services::ToplevelAction::SetMinimized(id, min));
            }
            Ok(())
        })?;
        services_table.set("ToplevelSetMinimized", toplevel_set_minimized_fn.clone())?;
        services_table.set("toplevel_set_minimized", toplevel_set_minimized_fn)?;

        let toplevel_set_maximized_fn = lua.create_function(|_, (id_str, max): (String, bool)| {
            if let Ok(id) = id_str.parse::<u32>() {
                zenith_services::ToplevelService::send_action(zenith_services::ToplevelAction::SetMaximized(id, max));
            }
            Ok(())
        })?;
        services_table.set("ToplevelSetMaximized", toplevel_set_maximized_fn.clone())?;
        services_table.set("toplevel_set_maximized", toplevel_set_maximized_fn)?;

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
        let disk_fn = lua.create_function(|lua, mount_path: Option<String>| {
            let snap = if let Some(ref path) = mount_path {
                zenith_services::DiskService::query_statvfs(path).unwrap_or_else(zenith_services::DiskService::get_disk_usage)
            } else {
                zenith_services::DiskService::get_disk_usage()
            };
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

        // Zenith.close() - in-process request flag (zero disk/socket blocking)
        let close_req = close_requested.clone();
        let close_fn = lua.create_function(move |_, ()| {
            close_req.store(true, Ordering::Release);
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

            static CONFIG_BASE_DIRS: std::sync::OnceLock<Vec<std::path::PathBuf>> = std::sync::OnceLock::new();
            let base_dirs = CONFIG_BASE_DIRS.get_or_init(|| {
                let mut dirs = Vec::new();
                if let Ok(dir) = std::env::var("ZENITH_CONFIG_DIR") {
                    dirs.push(std::path::PathBuf::from(dir));
                }
                if let Ok(home) = std::env::var("HOME") {
                    dirs.push(std::path::PathBuf::from(format!("{}/.config/zenith", home)));
                }
                dirs.push(std::path::PathBuf::from("config/zenith"));
                dirs.push(std::path::PathBuf::from("../../config/zenith"));
                dirs.push(std::path::PathBuf::from("/run/current-system/sw/share/zenith"));
                dirs.retain(|p| p.is_dir());
                if dirs.is_empty() {
                    dirs.push(std::path::PathBuf::from("."));
                }
                dirs
            });

            let mut resolved_content = None;
            let direct_path = std::path::Path::new(&path);
            if direct_path.is_file() {
                resolved_content = std::fs::read_to_string(direct_path).ok();
            }

            if resolved_content.is_none() {
                let test_subpaths = [
                    format!("{}.luau", path),
                    format!("{}.lua", path),
                    format!("{}/init.luau", path),
                    format!("{}/init.lua", path),
                    format!("lib/{}.luau", path),
                    format!("lib/{}.lua", path),
                    format!("overlays/{}.luau", path),
                    format!("overlays/{}.lua", path),
                ];

                'outer: for base in base_dirs {
                    for s in &test_subpaths {
                        let cand = base.join(s);
                        if cand.is_file() {
                            if let Ok(content) = std::fs::read_to_string(&cand) {
                                resolved_content = Some(content);
                                break 'outer;
                            }
                        }
                    }

                    let widget_name = path.strip_prefix("widgets/").unwrap_or(&path);
                    for domain in &["system", "desktop", "media", "tools", "shared"] {
                        for ext in &["init.luau", "widget.luau", "popup.luau"] {
                            let cand = base.join("widgets").join(domain).join(widget_name).join(ext);
                            if cand.is_file() {
                                if let Ok(content) = std::fs::read_to_string(&cand) {
                                    resolved_content = Some(content);
                                    break 'outer;
                                }
                            }
                        }
                        let cand = base.join("widgets").join(domain).join(format!("{}.luau", widget_name));
                        if cand.is_file() {
                            if let Ok(content) = std::fs::read_to_string(&cand) {
                                resolved_content = Some(content);
                                break 'outer;
                            }
                        }
                    }
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
            close_requested,
            search_query,
            selected_index,
            current_output,
            current_geometry,
            script_cache,
            focused_input_id,
            input_buffers,
            editor_engines,
            lock_password,
            lockout,
            system_signals,
        })
    }

    /// Efficiently queries and notifies all registered system reactive signals in-place.
    /// Updates bound text and properties on mounted UI trees without Luau VM script re-evaluation.
    pub fn update_system_signals(&self) {
        let (mut t, d) = zenith_services::SystemService::current_time();
        let second_precision = self.storage.get("secondPrecision")
            .and_then(|v| v.as_bool())
            .unwrap_or(false);
        if !second_precision && t.len() >= 5 {
            t = t[..5].to_string();
        }
        let c = zenith_services::SystemService::cpu_snapshot();
        let m = zenith_services::SystemService::memory_snapshot();
        let w = zenith_services::HyprlandService::active_window_snapshot();
        let b = zenith_services::BrightnessService::get_brightness();
        let k = zenith_services::HyprlandService::active_layout();

        self.reactive.notify_signal_value_change(&self.lua, self.system_signals.time, crate::reactive::SignalValue::Text(t));
        self.reactive.notify_signal_value_change(&self.lua, self.system_signals.date, crate::reactive::SignalValue::Text(d));
        self.reactive.notify_signal_value_change(&self.lua, self.system_signals.cpu, crate::reactive::SignalValue::Text(format!("{}%", c.percent)));
        self.reactive.notify_signal_value_change(&self.lua, self.system_signals.memory, crate::reactive::SignalValue::Text(format!("{}%", m.percent)));
        self.reactive.notify_signal_value_change(&self.lua, self.system_signals.active_window, crate::reactive::SignalValue::Text(w.title));
        self.reactive.notify_signal_value_change(&self.lua, self.system_signals.brightness, crate::reactive::SignalValue::Text(format!("{}%", b.percent)));
        self.reactive.notify_signal_value_change(&self.lua, self.system_signals.keyboard, crate::reactive::SignalValue::Text(k));
    }

    fn make_str_system_signal(
        lua: &Lua,
        reactive: &Arc<crate::reactive::ReactiveGraph>,
        id: SignalId,
        init_val: &str,
    ) -> Result<LuaTable, LuaError> {
        let tbl = lua.create_table()?;
        tbl.set("__type", "Signal")?;
        tbl.set("__signal_id", id)?;
        tbl.set("value", init_val)?;
        reactive.set_signal_value(id, crate::reactive::SignalValue::Text(init_val.to_string()));

        let r_get = reactive.clone();
        let get_fn = lua.create_function(move |_, _self: Option<LuaValue>| {
            r_get.track_access(id);
            if let Some(val) = r_get.get_signal_value(id) {
                Ok(val.as_str().into_owned())
            } else {
                Ok(String::new())
            }
        })?;
        tbl.set("get", get_fn)?;

        let r_call = reactive.clone();
        let call_fn = lua.create_function(move |_, _self: LuaValue| {
            r_call.track_access(id);
            if let Some(val) = r_call.get_signal_value(id) {
                Ok(val.as_str().into_owned())
            } else {
                Ok(String::new())
            }
        })?;

        let r_idx = reactive.clone();
        let index_fn = lua.create_function(move |lua_ctx, (t, key): (LuaTable, String)| {
            if key == "value" {
                r_idx.track_access(id);
                if let Some(val) = r_idx.get_signal_value(id) {
                    return Ok(LuaValue::String(lua_ctx.create_string(&*val.as_str())?));
                }
            }
            t.raw_get::<LuaValue>(key)
        })?;

        let mt = lua.create_table()?;
        mt.set("__call", call_fn)?;
        mt.set("__index", index_fn)?;
        tbl.set_metatable(Some(mt))?;
        Ok(tbl)
    }

    /// Polls completed background workers and triggers Promise resolution callbacks.
    pub fn poll_async_events(&self) -> Result<usize, LuaError> {
        poll_async_completions(&self.lua, &self.worker_pool)
    }

    /// Sets an event notifier to wake up the main event loop immediately when an async worker job completes.
    pub fn set_worker_completion_notifier(&self, notifier: Arc<dyn Fn() + Send + Sync>) {
        self.worker_pool.set_completion_notifier(notifier);
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

        // 1. Compile as expression or fallback to statement block without executing
        let func = match self.lua.load(&attempt).into_function() {
            Ok(f) => f,
            Err(_) => self.lua.load(trimmed).into_function()?,
        };

        // 2. Execute exactly once
        let val: LuaValue = func.call(())?;
        Ok(format_val(val))
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
        if let Ok(tbl) = self.lua.globals().get::<LuaTable>("__zenith_callbacks") {
            let _ = tbl.clear();
        }
        let _ = self.lua.globals().set("__zenith_cached_theme", LuaValue::Nil);
        self.script_cache.write().unwrap().clear();
        self.lua.expire_registry_values();
    }

    /// Checks and resets the close requested flag.
    pub fn check_close_requested(&self) -> bool {
        self.close_requested.swap(false, Ordering::AcqRel)
    }

    /// Requests the Wayland app to close active popups/overlays.
    pub fn request_close(&self) {
        self.close_requested.store(true, Ordering::Release);
    }

    /// Clears cached callbacks for a specific UI tree before re-evaluation, preventing memory leaks.
    pub fn clear_tree_callbacks(&self, tree_id: &str) {
        if let Ok(callbacks) = self.lua.globals().get::<LuaTable>("__zenith_callbacks") {
            if let Ok(empty_tbl) = self.lua.create_table() {
                let _ = callbacks.set(tree_id, empty_tbl);
            }
        }
    }

    pub(crate) fn find_callback(lua: &Lua, key: &str) -> Option<LuaFunction> {
        if let Ok(callbacks) = lua.globals().get::<LuaTable>("__zenith_callbacks") {
            if let Ok(f) = callbacks.get::<LuaFunction>(key) {
                return Some(f);
            }
            for pair in callbacks.pairs::<LuaValue, LuaTable>() {
                if let Ok((_k, sub_tbl)) = pair {
                    if let Ok(f) = sub_tbl.get::<LuaFunction>(key) {
                        return Some(f);
                    }
                }
            }
        }
        None
    }

    pub(crate) fn store_callback(lua: &Lua, tree_id: Option<&str>, key: &str, func: LuaFunction) {
        if let Ok(callbacks) = lua.globals().get::<LuaTable>("__zenith_callbacks") {
            let tid = tree_id.unwrap_or("default");
            let target_tbl = if let Ok(sub) = callbacks.get::<LuaTable>(tid) {
                sub
            } else if let Ok(sub) = lua.create_table() {
                let _ = callbacks.set(tid, sub.clone());
                sub
            } else {
                callbacks
            };
            let _ = target_tbl.set(key, func);
        }
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

    /// Push characters into the volatile zeroized lock password buffer.
    pub fn push_lock_password(&self, s: &str) {
        self.lock_password.write().unwrap().push_str(s);
    }

    /// Pop a character from the volatile zeroized lock password buffer.
    pub fn pop_lock_password(&self) {
        self.lock_password.write().unwrap().pop();
    }

    /// Clears and zeroizes the lock password buffer.
    pub fn clear_lock_password(&self) {
        self.lock_password.write().unwrap().clear();
    }

    /// Takes the password for PAM authentication and immediately scrubs the internal buffer.
    pub fn take_lock_password(&self) -> String {
        self.lock_password.write().unwrap().take_password()
    }

    /// Returns length in characters of the current secure lock password.
    pub fn lock_password_len(&self) -> usize {
        self.lock_password.read().unwrap().len()
    }

    /// Checks if authentication is temporarily locked out due to repeated failures.
    pub fn is_locked_out(&self) -> bool {
        self.lockout.read().unwrap().is_locked_out()
    }

    /// Records a failed authentication attempt and returns lockout duration in seconds (if any).
    pub fn record_lock_failure(&self) -> u64 {
        self.lockout.write().unwrap().record_failure()
    }

    /// Records a successful authentication, resetting failed attempts and lockout timers.
    pub fn record_lock_success(&self) {
        self.lockout.write().unwrap().record_success();
    }

    /// Returns remaining lockout time in seconds.
    pub fn remaining_lockout_secs(&self) -> u64 {
        self.lockout.read().unwrap().remaining_lockout_secs()
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
        if let Some(ed) = self.editor_engines.write().unwrap().get_mut(id) {
            if ed.text() != text {
                ed.set_text(text);
            }
        }
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
        self.input_buffers.write().unwrap().insert(id.to_string(), new_text);
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
        if let Some(cb) = Self::find_callback(&self.lua, key) {
            cb.call::<()>(arg)?;
            return Ok(());
        }
        if key == "settings:search:change" {
            let _ = self.storage.set("settings_search_query", serde_json::Value::String(arg.to_string()));
            return Ok(());
        }
        if let Some(storage_key) = key.strip_prefix("storage:set:") {
            let clean_k = storage_key.trim_end_matches(':');
            let full_action = format!("storage:set:{}:{}", clean_k, arg);
            return self.trigger_click(&full_action);
        } else if let Some(storage_key) = key.strip_prefix("storage:toggle:") {
            let clean_k = storage_key.trim_end_matches(':');
            let full_action = format!("storage:toggle:{}", clean_k);
            return self.trigger_click(&full_action);
        } else if key.contains(':') {
            let clean_k = key.trim_end_matches(':');
            let full_action = format!("{}:{}", clean_k, arg);
            return self.trigger_click(&full_action);
        }
        Ok(())
    }

    /// Evaluates a Luau script string for a specific UI tree, resetting its callback scope to eliminate memory leaks.
    pub fn eval_ui_for_tree(&self, tree_id: &str, script: &str) -> Result<UiNode, LuaError> {
        self.mount_tree(tree_id, script)
    }

    /// Load and evaluate a Luau script string, returning the root UI node with compiled chunk caching.
    pub fn eval_ui(&self, script: &str) -> Result<UiNode, LuaError> {
        self.eval_ui_for_tree("default", script)
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
        } else if let Some(id_str) = action.strip_prefix("notification:close:").or_else(|| action.strip_prefix("notification:dismiss:")) {
            if let Ok(id) = id_str.parse::<u32>() {
                zenith_services::NotificationService::close(id);
            }
        } else if action == "notification:clear" {
            zenith_services::NotificationService::clear_all();
        } else if action == "notification:toggle_dnd" {
            let next = zenith_services::NotificationService::toggle_dnd();
            let _ = self.storage.set("dndEnabled", serde_json::Value::Bool(next));
        } else if action == "notification:dnd:on" {
            zenith_services::NotificationService::set_dnd(true);
            let _ = self.storage.set("dndEnabled", serde_json::Value::Bool(true));
        } else if action == "notification:dnd:off" {
            zenith_services::NotificationService::set_dnd(false);
            let _ = self.storage.set("dndEnabled", serde_json::Value::Bool(false));
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
        } else if action == "system:logout" {
            let _ = zenith_services::HyprlandService::dispatch("exit", "");
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
            if let Ok(pct) = pct_str.parse::<f32>() {
                zenith_services::BrightnessService::set_brightness(pct.round().clamp(1.0, 100.0) as u8);
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
            if let Ok(val) = vol_str.parse::<f32>() {
                zenith_services::AudioService::set_volume(val.round().clamp(0.0, 150.0) as u8);
            }
        } else if let Some(step_str) = action.strip_prefix("audio:volume_step:") {
            if let Ok(delta) = step_str.parse::<i32>() {
                zenith_services::AudioService::adjust_volume(delta);
            }
        } else if action == "audio:toggle_mute" {
            zenith_services::AudioService::toggle_mute();
        } else if let Some(id) = action.strip_prefix("clipboard:copy:") {
            let _ = zenith_services::ClipboardService::copy(id);
        } else if let Some(id) = action.strip_prefix("clipboard:delete:") {
            let _ = zenith_services::ClipboardService::delete(id);
        } else if action == "record:toggle" {
            zenith_services::RecorderService::toggle_recording();
        } else if action == "screenshot:area" {
            zenith_services::RecorderService::take_screenshot(true);
        } else if action == "screenshot:full" {
            zenith_services::RecorderService::take_screenshot(false);
        } else if action == "search:clear" {
            self.set_search_query("");
            self.set_selected_index(1);
        } else if action == "settings:sync" {
            let _ = self.storage.sync_to_config();
        } else if action == "settings:reset_defaults" {
            let _ = self.storage.clear();
            let _ = self.storage.sync_to_config();
            let _ = self.storage.reload_from_config();
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
                match k {
                    "gapsIn" => {
                        let _ = zenith_services::HyprlandService::keyword("general:gaps_in", v);
                    }
                    "gapsOut" => {
                        let _ = zenith_services::HyprlandService::keyword("general:gaps_out", v);
                    }
                    "borderSize" => {
                        let _ = zenith_services::HyprlandService::keyword("general:border_size", v);
                    }
                    _ => {}
                }
            }
        } else if let Some(k) = action.strip_prefix("storage:toggle:") {
            let cur = self.storage.get(k).and_then(|v| v.as_bool()).unwrap_or(false);
            let _ = self.storage.set(k, serde_json::Value::Bool(!cur));
        } else if let Some(page_str) = action.strip_prefix("settings:page:") {
            if let Ok(idx) = page_str.parse::<i64>() {
                let _ = self.storage.set("settings_active_page", serde_json::Value::from(idx));
            }
        } else if let Some(task_id) = action.strip_prefix("settings:task:") {
            let active_page = self.storage.get("settings_active_page").and_then(|v| v.as_i64()).unwrap_or(0);
            let page_keys = [
                "general", "appearance", "wallpaper", "bar", "dock", "launcher", "osd", "widgets",
                "sys_audio", "tools", "compositor", "monitors", "media", "network", "power", "security", "about"
            ];
            let key = if (active_page as usize) < page_keys.len() {
                format!("settings_task_{}", page_keys[active_page as usize])
            } else {
                "settings_active_task".to_string()
            };
            let _ = self.storage.set(&key, serde_json::Value::String(task_id.to_string()));
            let _ = self.storage.set("settings_active_task", serde_json::Value::String(task_id.to_string()));
        } else if action == "settings:search:clear" {
            let _ = self.storage.set("settings_search_query", serde_json::Value::String(String::new()));
            self.set_input_text("settings_search_input", "");
        } else if action == "settings:toggle_overlay" {
            let cur = self.storage.get("settings_overlay_mode").and_then(|v| v.as_bool()).unwrap_or(false);
            let _ = self.storage.set("settings_overlay_mode", serde_json::Value::Bool(!cur));
        } else if action == "bar:toggle_compact" {
            let cur = self.storage.get("barCompactMode").and_then(|v| v.as_bool()).unwrap_or(false);
            let _ = self.storage.set("barCompactMode", serde_json::Value::Bool(!cur));
        } else if action == "quick-term" {
            let _ = zenith_services::HyprlandService::dispatch("togglespecialworkspace", "quick-term");
        } else if action == "trash:///" {
            let _ = spawner::spawn_detached("xdg-open trash:///");
        } else if action == "trash-empty" {
            let _ = spawner::spawn_detached("gio trash --empty");
        } else if action == "expose:filter:all" {
            let _ = self.lua.globals().set("__expose_filter", "all");
            let _ = self.storage.set("expose_filter", serde_json::Value::String("all".into()));
        } else if action == "expose:filter:current" {
            let _ = self.lua.globals().set("__expose_filter", "current");
            let _ = self.storage.set("expose_filter", serde_json::Value::String("current".into()));
        } else if action.starts_with("click_")
            || action.starts_with("right_click_")
            || action.starts_with("middle_click_")
            || action.starts_with("scroll_up_")
            || action.starts_with("scroll_down_")
            || action.starts_with("change_")
            || action.starts_with("submit_")
            || action.starts_with("switch_toggle_")
            || action.starts_with("slider_change_")
        {
            if let Some(func) = Self::find_callback(&self.lua, action) {
                let _ = func.call::<()>(());
                return Ok(());
            }
            tracing::warn!("Callback '{}' not found in __zenith_callbacks", action);
        } else {
            tracing::warn!("Unknown action: {}", action);
        }
        Ok(())
    }

    /// Mounts a UI tree into the reactive graph, binding signals and persisting the tree across frames.
    pub fn mount_tree(&self, tree_id: &str, script: &str) -> Result<UiNode, LuaError> {
        self.clear_tree_callbacks(tree_id);
        self.reactive.clear_tree(tree_id);
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

        crate::reactive::CURRENT_MOUNTING_TREE.with(|t| {
            *t.borrow_mut() = Some(tree_id.to_string());
        });
        let val_res = func.call(());
        let val: LuaValue = match val_res {
            Ok(v) => v,
            Err(e) => {
                crate::reactive::CURRENT_MOUNTING_TREE.with(|t| {
                    *t.borrow_mut() = None;
                });
                return Err(e);
            }
        };
        let focused_id = self.focused_input_id.read().unwrap().clone();
        let engines = self.editor_engines.read().unwrap();
        let editor_ctx = Some((&focused_id, &*engines));
        let node_res = match val {
            LuaValue::Table(tbl) => {
                let mut path = Vec::new();
                let node = Self::parse_ui_node_tracked(&self.lua, &tbl, &mut path, Some(&self.reactive), Some(tree_id), editor_ctx)?;
                self.reactive.mount_tree(tree_id, node.clone());
                Ok(node)
            }
            _ => Err(LuaError::runtime("Script must return a Zenith UI node table")),
        };
        crate::reactive::CURRENT_MOUNTING_TREE.with(|t| {
            *t.borrow_mut() = None;
        });
        self.lua.expire_registry_values();
        node_res
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

    /// Marks the UI tree as dirty.
    pub fn mark_tree_dirty(&self, tree_id: &str) {
        self.reactive.mark_tree_dirty(tree_id);
    }

    #[allow(dead_code)]
    fn parse_ui_node(lua: &Lua, tbl: &LuaTable) -> Result<UiNode, LuaError> {
        let mut path = Vec::new();
        Self::parse_ui_node_tracked(lua, tbl, &mut path, None, None, None)
    }

    fn parse_ui_node_tracked(
        lua: &Lua,
        tbl: &LuaTable,
        path: &mut Vec<usize>,
        reactive: Option<&crate::reactive::ReactiveGraph>,
        tree_id: Option<&str>,
        editor_ctx: Option<(&Option<String>, &std::collections::HashMap<String, zenith_layout::TextEditorEngine>)>,
    ) -> Result<UiNode, LuaError> {
        let node_type: String = tbl.get("__type").unwrap_or_else(|_| "Box".to_string());
        let style = Self::parse_style(tbl)?;

        if let (Some(rg), Some(tid)) = (reactive, tree_id) {
            for (key, prop) in [
                ("width", crate::reactive::BoundProperty::Width),
                ("height", crate::reactive::BoundProperty::Height),
                ("opacity", crate::reactive::BoundProperty::Opacity),
                ("scale", crate::reactive::BoundProperty::Scale),
                ("background", crate::reactive::BoundProperty::Background),
                ("background_color", crate::reactive::BoundProperty::Background),
            ] {
                if let Ok(sig_tbl) = tbl.get::<LuaTable>(key) {
                    if let Ok(sig_id) = sig_tbl.get::<u64>("__signal_id") {
                        rg.bind_node(
                            sig_id,
                            crate::reactive::NodeBinding {
                                tree_id: tid.to_string(),
                                node_path: path.to_vec(),
                                property: prop,
                            },
                        );
                    }
                }
            }
        }

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

            if let (Some(rg), Some(tid)) = (reactive, tree_id) {
                if let Ok(sig_tbl) = tbl.get::<LuaTable>("color") {
                    if let Ok(sig_id) = sig_tbl.get::<u64>("__signal_id") {
                        rg.bind_node(
                            sig_id,
                            crate::reactive::NodeBinding {
                                tree_id: tid.to_string(),
                                node_path: path.to_vec(),
                                property: crate::reactive::BoundProperty::Color,
                            },
                        );
                    }
                }
            }

            let font_size: f32 = tbl.get("font_size").unwrap_or(14.0);
            let color = tbl.get::<LuaValue>("color").ok().and_then(|v| Self::parse_color_value(&v)).unwrap_or(Color::rgb(255, 255, 255));
            let font_family = tbl.get::<String>("font_family").ok();
            let font_weight = if let Ok(w_str) = tbl.get::<String>("font_weight") {
                match w_str.to_lowercase().as_str() {
                    "thin" => Some(100),
                    "extralight" => Some(200),
                    "light" => Some(300),
                    "normal" | "regular" => Some(400),
                    "medium" => Some(500),
                    "semibold" => Some(600),
                    "bold" => Some(700),
                    "extrabold" => Some(800),
                    "black" => Some(900),
                    _ => None,
                }
            } else if let Ok(w_num) = tbl.get::<u16>("font_weight") {
                Some(w_num)
            } else {
                None
            };

            Ok(UiNode::Text {
                text: text.into(),
                font_size,
                color,
                font_family: font_family.map(Into::into),
                font_weight,
                style,
            })
        } else if node_type == "TextInput" {
            let id = tbl.get::<String>("id").ok();
            let (mut text, maybe_sig_id): (String, Option<u64>) = if let Ok(sig_tbl) = tbl.get::<LuaTable>("text") {
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
            let color = tbl.get::<LuaValue>("color").ok().and_then(|v| Self::parse_color_value(&v)).unwrap_or(Color::rgb(255, 255, 255));
            let placeholder_color = tbl.get::<LuaValue>("placeholder_color").ok().and_then(|v| Self::parse_color_value(&v)).unwrap_or(Color::rgba(255, 255, 255, 120));
            let mut active: bool = tbl.get("active").unwrap_or(false);
            let mut cursor_pos: usize = tbl.get("cursor_pos").unwrap_or(text.len());
            let mut selection_range: Option<(usize, usize)> = None;

            if let Some(ref input_id) = id {
                if let Some((focused, engines)) = editor_ctx {
                    if focused.as_deref() == Some(input_id.as_str()) {
                        active = true;
                    }
                    if let Some(engine) = engines.get(input_id) {
                        text = engine.text().to_string();
                        cursor_pos = engine.cursor;
                        selection_range = engine.selection_range();
                    }
                }
            }

            let on_change: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_change") {
                static CB_CHANGE_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_CHANGE_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("change_{}", id);
                Self::store_callback(lua, tree_id, &key, func);
                Some(key)
            } else {
                tbl.get::<String>("on_change").ok()
            };

            let on_submit: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_submit") {
                static CB_SUBMIT_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_SUBMIT_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("submit_{}", id);
                Self::store_callback(lua, tree_id, &key, func);
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
                selection_range,
                style,
                on_change: on_change.map(Into::into),
                on_submit: on_submit.map(Into::into),
            })
        } else if node_type == "Image" {
            let src: String = tbl.get("src").unwrap_or_default();
            Ok(UiNode::Image {
                src: src.into(),
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
            let track_color = tbl.get::<LuaValue>("track_color").ok().and_then(|v| Self::parse_color_value(&v)).unwrap_or(Color::rgba(255, 255, 255, 50));
            let active_track_color = tbl.get::<LuaValue>("active_track_color").ok().and_then(|v| Self::parse_color_value(&v)).unwrap_or(Color::rgb(124, 77, 255));
            let thumb_color = tbl.get::<LuaValue>("thumb_color").ok().and_then(|v| Self::parse_color_value(&v)).unwrap_or(Color::rgb(255, 255, 255));

            let on_change: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_change") {
                static CB_SLIDER_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_SLIDER_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("slider_change_{}", id);
                Self::store_callback(lua, tree_id, &key, func);
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
                on_change: on_change.map(Into::into),
            })
        } else if node_type == "Switch" {
            let id = tbl.get::<String>("id").ok();
            let checked: bool = tbl.get::<bool>("checked").unwrap_or(false);
            let active_color = tbl.get::<LuaValue>("active_color").ok().and_then(|v| Self::parse_color_value(&v)).unwrap_or(Color::rgb(124, 77, 255));
            let inactive_color = tbl.get::<LuaValue>("inactive_color").ok().and_then(|v| Self::parse_color_value(&v)).unwrap_or(Color::rgba(255, 255, 255, 50));
            let thumb_color = tbl.get::<LuaValue>("thumb_color").ok().and_then(|v| Self::parse_color_value(&v)).unwrap_or(Color::rgb(255, 255, 255));

            let on_toggle: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_toggle") {
                static CB_SWITCH_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_SWITCH_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("switch_toggle_{}", id);
                Self::store_callback(lua, tree_id, &key, func);
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
                on_toggle: on_toggle.map(Into::into),
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
                        height: Some(zenith_layout::length(top_spacer_height)),
                        ..Default::default()
                    },
                    children: Vec::new(),
                    on_click: None,
                    on_right_click: None,
                    on_middle_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                });
            }

            if let Ok(render_item_fn) = tbl.get::<LuaFunction>("render_item") {
                for i in (start_idx + 1)..=(end_idx) {
                    if let Ok(item_val) = items.get::<LuaValue>(i) {
                        if let Ok(item_node_tbl) = render_item_fn.call::<LuaTable>((item_val, i)) {
                            path.push(i);
                            if let Ok(child_node) = Self::parse_ui_node_tracked(lua, &item_node_tbl, path, reactive, tree_id, editor_ctx) {
                                list_children.push(child_node);
                            }
                            path.pop();
                        }
                    }
                }
            }

            if bottom_spacer_height > 0.0 {
                list_children.push(UiNode::Box {
                    style: zenith_layout::NodeStyle {
                        height: Some(zenith_layout::length(bottom_spacer_height)),
                        ..Default::default()
                    },
                    children: Vec::new(),
                    on_click: None,
                    on_right_click: None,
                    on_middle_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                });
            }

            let mut list_style = style;
            if list_style.height.is_none() {
                list_style.height = Some(zenith_layout::length(visible_height));
            }
            list_style.flex_direction = zenith_layout::FlexDirection::Column;
            list_style.overflow = zenith_layout::Overflow::Scroll;
            list_style.scroll_offset_y = scroll_offset;

            Ok(UiNode::Box {
                style: list_style,
                children: list_children,
                on_click: None,
                on_right_click: None,
                on_middle_click: None,
                on_scroll_up: None,
                on_scroll_down: None,
                tooltip: None,
            })
        } else if node_type == "Window" {
            let meta = Self::parse_window_meta(tbl);
            let mut children = Vec::new();
            if let Ok(child_tbl) = tbl.get::<LuaTable>("children") {
                for (i, child) in child_tbl.sequence_values::<LuaTable>().flatten().enumerate() {
                    path.push(i);
                    let child_node = Self::parse_ui_node_tracked(lua, &child, path, reactive, tree_id, editor_ctx)?;
                    path.pop();
                    children.push(child_node);
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
                    path.push(i);
                    let child_node = Self::parse_ui_node_tracked(lua, &child, path, reactive, tree_id, editor_ctx)?;
                    path.pop();
                    children.push(child_node);
                }
            }

            let on_click: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_click") {
                static CB_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("click_{}", id);
                Self::store_callback(lua, tree_id, &key, func);
                Some(key)
            } else {
                tbl.get::<String>("on_click").ok()
            };

            let on_right_click: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_right_click") {
                static CB_RIGHT_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_RIGHT_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("right_click_{}", id);
                Self::store_callback(lua, tree_id, &key, func);
                Some(key)
            } else {
                tbl.get::<String>("on_right_click").ok()
            };

            let on_middle_click: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_middle_click") {
                static CB_MIDDLE_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_MIDDLE_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("middle_click_{}", id);
                Self::store_callback(lua, tree_id, &key, func);
                Some(key)
            } else {
                tbl.get::<String>("on_middle_click").ok()
            };

            let on_scroll_up: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_scroll_up") {
                static CB_SCROLL_UP_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_SCROLL_UP_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("scroll_up_{}", id);
                Self::store_callback(lua, tree_id, &key, func);
                Some(key)
            } else {
                tbl.get::<String>("on_scroll_up").ok()
            };

            let on_scroll_down: Option<String> = if let Ok(func) = tbl.get::<LuaFunction>("on_scroll_down") {
                static CB_SCROLL_DOWN_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);
                let id = CB_SCROLL_DOWN_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let key = format!("scroll_down_{}", id);
                Self::store_callback(lua, tree_id, &key, func);
                Some(key)
            } else {
                tbl.get::<String>("on_scroll_down").ok()
            };

            let tooltip: Option<String> = tbl.get::<String>("tooltip").ok();

            Ok(UiNode::Box {
                style,
                children,
                on_click: on_click.map(Into::into),
                on_right_click: on_right_click.map(Into::into),
                on_middle_click: on_middle_click.map(Into::into),
                on_scroll_up: on_scroll_up.map(Into::into),
                on_scroll_down: on_scroll_down.map(Into::into),
                tooltip: tooltip.map(Into::into),
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

    pub fn parse_dimension(val: &LuaValue) -> Option<zenith_layout::Dimension> {
        match val {
            LuaValue::Number(n) => Some(zenith_layout::length(*n as f32)),
            LuaValue::Integer(i) => Some(zenith_layout::length(*i as f32)),
            LuaValue::String(s) => {
                let str_val = s.to_str().ok()?;
                let trimmed = str_val.trim();
                if trimmed.eq_ignore_ascii_case("auto") {
                    Some(zenith_layout::auto())
                } else if trimmed.ends_with('%') {
                    let num_str = trimmed.trim_end_matches('%').trim();
                    let pct = num_str.parse::<f32>().ok()?;
                    Some(zenith_layout::percent(pct / 100.0))
                } else if let Ok(num) = trimmed.parse::<f32>() {
                    Some(zenith_layout::length(num))
                } else {
                    None
                }
            }
            LuaValue::Table(tbl) => {
                if let Ok(get_fn) = tbl.get::<LuaFunction>("get") {
                    if let Ok(res) = get_fn.call::<LuaValue>(Some(tbl.clone())) {
                        return Self::parse_dimension(&res);
                    }
                }
                if let Ok(res) = tbl.get::<LuaValue>("value") {
                    return Self::parse_dimension(&res);
                }
                None
            }
            _ => None,
        }
    }

    pub fn parse_color_str(hex: &str) -> Color {
        let hex = hex.trim();
        if hex.eq_ignore_ascii_case("transparent") {
            return Color::transparent();
        }
        let hex_clean = hex.trim_start_matches('#');
        if hex_clean.len() == 6 {
            let r = u8::from_str_radix(&hex_clean[0..2], 16).unwrap_or(0);
            let g = u8::from_str_radix(&hex_clean[2..4], 16).unwrap_or(0);
            let b = u8::from_str_radix(&hex_clean[4..6], 16).unwrap_or(0);
            Color::rgb(r, g, b)
        } else if hex_clean.len() == 8 {
            let r = u8::from_str_radix(&hex_clean[0..2], 16).unwrap_or(0);
            let g = u8::from_str_radix(&hex_clean[2..4], 16).unwrap_or(0);
            let b = u8::from_str_radix(&hex_clean[4..6], 16).unwrap_or(0);
            let a = u8::from_str_radix(&hex_clean[6..8], 16).unwrap_or(255);
            Color::rgba(r, g, b, a)
        } else if hex_clean.len() == 3 {
            let r = u8::from_str_radix(&hex_clean[0..1].repeat(2), 16).unwrap_or(0);
            let g = u8::from_str_radix(&hex_clean[1..2].repeat(2), 16).unwrap_or(0);
            let b = u8::from_str_radix(&hex_clean[2..3].repeat(2), 16).unwrap_or(0);
            Color::rgb(r, g, b)
        } else {
            Color::rgb(255, 255, 255)
        }
    }

    pub fn parse_color_value(val: &LuaValue) -> Option<Color> {
        match val {
            LuaValue::Table(tbl) => Some(Self::parse_color(tbl)),
            LuaValue::String(s) => {
                let s_str = s.to_str().ok()?;
                Some(Self::parse_color_str(&s_str))
            }
            _ => None,
        }
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

        if let Ok(w_val) = tbl.get::<LuaValue>("width") {
            style.width = Self::parse_dimension(&w_val);
        }

        if let Ok(h_val) = tbl.get::<LuaValue>("height") {
            style.height = Self::parse_dimension(&h_val);
        }

        if let Ok(mw_val) = tbl.get::<LuaValue>("max_width") {
            style.max_width = Self::parse_dimension(&mw_val);
        }

        if let Ok(op) = tbl.get::<f32>("opacity") {
            style.opacity = Some(op);
        } else if let Ok(sig_tbl) = tbl.get::<LuaTable>("opacity") {
            if let Ok(get_fn) = sig_tbl.get::<LuaFunction>("get") {
                if let Ok(op) = get_fn.call::<f32>(Some(sig_tbl.clone())) {
                    style.opacity = Some(op);
                }
            } else if let Ok(op) = sig_tbl.get::<f32>("value") {
                style.opacity = Some(op);
            }
        }

        if let Ok(sc) = tbl.get::<f32>("scale") {
            style.scale = Some(sc);
        } else if let Ok(sig_tbl) = tbl.get::<LuaTable>("scale") {
            if let Ok(get_fn) = sig_tbl.get::<LuaFunction>("get") {
                if let Ok(sc) = get_fn.call::<f32>(Some(sig_tbl.clone())) {
                    style.scale = Some(sc);
                }
            } else if let Ok(sc) = sig_tbl.get::<f32>("value") {
                style.scale = Some(sc);
            }
        }

        if let Ok(dir) = tbl.get::<String>("flex_direction").or_else(|_| tbl.get::<String>("direction")) {
            match dir.to_lowercase().as_str() {
                "column" => {
                    style.flex_direction = FlexDirection::Column;
                    style.align_items = Some(AlignItems::STRETCH);
                }
                "row" => {
                    style.flex_direction = FlexDirection::Row;
                }
                "column-reverse" | "column_reverse" => {
                    style.flex_direction = FlexDirection::ColumnReverse;
                    style.align_items = Some(AlignItems::STRETCH);
                }
                "row-reverse" | "row_reverse" => {
                    style.flex_direction = FlexDirection::RowReverse;
                }
                _ => {}
            }
        }

        if let Ok(wrap_str) = tbl.get::<String>("flex_wrap").or_else(|_| tbl.get::<String>("wrap")) {
            match wrap_str.to_lowercase().as_str() {
                "wrap" => style.flex_wrap = zenith_layout::FlexWrap::Wrap,
                "wrap-reverse" | "wrap_reverse" => style.flex_wrap = zenith_layout::FlexWrap::WrapReverse,
                "no-wrap" | "nowrap" | "no_wrap" => style.flex_wrap = zenith_layout::FlexWrap::NoWrap,
                _ => {}
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

        if let Ok(gap) = tbl.get::<f32>("gap") {
            style.gap = gap;
        }

        if let Ok(pad) = tbl.get::<f32>("padding") {
            style.padding = [pad, pad, pad, pad];
        } else if let Ok(pad_tbl) = tbl.get::<LuaTable>("padding") {
            let h: f32 = pad_tbl.get("horizontal").or_else(|_| pad_tbl.get("x")).unwrap_or(0.0);
            let v: f32 = pad_tbl.get("vertical").or_else(|_| pad_tbl.get("y")).unwrap_or(0.0);
            let top: f32 = pad_tbl.get("top").unwrap_or(v);
            let right: f32 = pad_tbl.get("right").unwrap_or(h);
            let bottom: f32 = pad_tbl.get("bottom").unwrap_or(v);
            let left: f32 = pad_tbl.get("left").unwrap_or(h);
            style.padding = [top, right, bottom, left];
        }

        if let Ok(m) = tbl.get::<f32>("margin") {
            style.margin = [m, m, m, m];
        } else if let Ok(m_tbl) = tbl.get::<LuaTable>("margin") {
            let h: f32 = m_tbl.get("horizontal").or_else(|_| m_tbl.get("x")).unwrap_or(0.0);
            let v: f32 = m_tbl.get("vertical").or_else(|_| m_tbl.get("y")).unwrap_or(0.0);
            let top: f32 = m_tbl.get("top").unwrap_or(v);
            let right: f32 = m_tbl.get("right").unwrap_or(h);
            let bottom: f32 = m_tbl.get("bottom").unwrap_or(v);
            let left: f32 = m_tbl.get("left").unwrap_or(h);
            style.margin = [top, right, bottom, left];
        }

        if let Ok(radius) = tbl.get::<f32>("border_radius") {
            style.border_radius = radius;
        }

        if let Ok(bg_val) = tbl.get::<LuaValue>("background").or_else(|_| tbl.get::<LuaValue>("bg")) {
            if let Some(c) = Self::parse_color_value(&bg_val) {
                style.background_color = c;
            }
        }

        if let Ok(border_val) = tbl.get::<LuaValue>("border_color") {
            if let Some(c) = Self::parse_color_value(&border_val) {
                style.border_color = c;
            }
        }

        if let Ok(bw) = tbl.get::<f32>("border_width") {
            style.border_width = bw;
        }

        if let Ok(shadow_tbl) = tbl.get::<LuaTable>("shadow") {
            let color = shadow_tbl
                .get::<LuaValue>("color")
                .ok()
                .and_then(|v| Self::parse_color_value(&v))
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
            "ExposePopup",
            "CheatSheet",
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
                    UiNode::Text { text, .. } => assert_eq!(&**text, "Updated Signal Text"),
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
                    UiNode::Text { text, .. } => assert_eq!(&**text, "25"),
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
        assert!(runtime.trigger_click("idle:toggle").is_ok());
        assert!(!runtime.is_idle());
    }

    #[test]
    fn test_secure_password_and_lockout() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");

        // Verify initial state
        assert_eq!(runtime.lock_password_len(), 0);
        assert!(!runtime.is_locked_out());
        assert_eq!(runtime.remaining_lockout_secs(), 0);

        // Test pushing password characters
        runtime.push_lock_password("s");
        runtime.push_lock_password("e");
        runtime.push_lock_password("c");
        runtime.push_lock_password("ret");
        assert_eq!(runtime.lock_password_len(), 6);

        // Test pop
        runtime.pop_lock_password();
        assert_eq!(runtime.lock_password_len(), 5);

        // Test take_password scrubs buffer immediately
        let pwd = runtime.take_lock_password();
        assert_eq!(pwd, "secre");
        assert_eq!(runtime.lock_password_len(), 0);

        // Test lockout exponential progression
        assert_eq!(runtime.record_lock_failure(), 0); // 1st failure
        assert!(!runtime.is_locked_out());
        assert_eq!(runtime.record_lock_failure(), 0); // 2nd failure
        assert!(!runtime.is_locked_out());

        let delay1 = runtime.record_lock_failure(); // 3rd failure triggers lockout
        assert!(delay1 > 0);
        assert!(runtime.is_locked_out());
        assert!(runtime.remaining_lockout_secs() > 0);

        // Test success resets lockout
        runtime.record_lock_success();
        assert!(!runtime.is_locked_out());
        assert_eq!(runtime.remaining_lockout_secs(), 0);
    }

    #[test]
    fn test_clear_tree_preserves_reactive_bindings() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let script = r#"
            local count, setCount = Zenith.signal(100)
            _G.set_bar_count = setCount
            return Zenith.Box({
                children = {
                    Zenith.Text({ text = count }),
                }
            })
        "#;

        let node = runtime.mount_tree("bar", script).expect("mount_tree failed");
        match &node {
            UiNode::Box { children, .. } => {
                assert_eq!(children.len(), 1);
                match &children[0] {
                    UiNode::Text { text, .. } => assert_eq!(&**text, "100"),
                    _ => panic!("Expected text node"),
                }
            }
            _ => panic!("Expected box root"),
        }

        // Clean tree initially
        runtime.mark_tree_clean("bar");
        assert!(!runtime.is_tree_dirty("bar"));

        // Trigger setter from Lua
        let set_fn: LuaFunction = runtime.lua.globals().get("set_bar_count").expect("setter not found");
        set_fn.call::<()>(200).expect("failed to call setter");

        // Reactive graph must mark tree dirty
        assert!(runtime.is_tree_dirty("bar"), "Tree must be dirty after signal mutation");
        let updated = runtime.get_tree("bar").expect("tree missing");
        match &updated {
            UiNode::Box { children, .. } => match &children[0] {
                UiNode::Text { text, .. } => assert_eq!(&**text, "200"),
                _ => panic!("Expected text node"),
            },
            _ => panic!("Expected box root"),
        }

        // Test mark_tree_dirty explicitly
        runtime.mark_tree_clean("bar");
        assert!(!runtime.is_tree_dirty("bar"));
        runtime.mark_tree_dirty("bar");
        assert!(runtime.is_tree_dirty("bar"));
    }

    #[test]
    fn test_clear_module_cache_clears_cached_theme() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let tbl = runtime.lua.create_table().unwrap();
        tbl.set("primary", "#123456").unwrap();
        runtime.lua.globals().set("__zenith_cached_theme", tbl).unwrap();

        let before: LuaValue = runtime.lua.globals().get("__zenith_cached_theme").unwrap();
        assert!(matches!(before, LuaValue::Table(_)));

        runtime.clear_module_cache();

        let after: LuaValue = runtime.lua.globals().get("__zenith_cached_theme").unwrap();
        assert!(matches!(after, LuaValue::Nil));
    }

    #[test]
    fn test_trigger_click_middle_click() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let clicked = Arc::new(AtomicBool::new(false));
        let clicked_clone = clicked.clone();

        let callbacks = runtime.lua.create_table().unwrap();
        let cb = runtime.lua.create_function_mut(move |_, ()| {
            clicked_clone.store(true, Ordering::SeqCst);
            Ok(())
        }).unwrap();
        callbacks.set("middle_click_btn", cb).unwrap();
        runtime.lua.globals().set("__zenith_callbacks", callbacks).unwrap();

        assert!(runtime.trigger_click("middle_click_btn").is_ok());
        assert!(clicked.load(Ordering::SeqCst), "Middle click callback must be executed");
    }

    #[test]
    fn test_keyboard_layout_short_code() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let zenith: LuaTable = runtime.lua.globals().get("Zenith").expect("Zenith global missing");
        let signals: LuaTable = zenith.get("Signals").expect("Signals missing");
        let kb_fn: LuaFunction = signals.get("KeyboardLayout").expect("KeyboardLayout missing");
        let layout: String = kb_fn.call(()).expect("KeyboardLayout call failed");
        assert_eq!(layout.len(), 2);
        assert!(layout.chars().all(|c| c.is_ascii_uppercase()));
    }

    #[test]
    fn test_system_signals_inplace_update() {
        let runtime = LuauRuntime::new().expect("Failed to create runtime");
        let script = r#"
            return Zenith.Box({
                children = {
                    Zenith.Text({
                        text = Zenith.Signals.Time
                    })
                }
            })
        "#;
        runtime.mount_tree("bar_test", script).expect("Failed to mount tree");
        let initial_text = runtime.reactive.with_tree("bar_test", |node| {
            if let zenith_layout::UiNode::Box { children, .. } = node {
                if let Some(zenith_layout::UiNode::Text { text, .. }) = children.first() {
                    return Some(text.to_string());
                }
            }
            None
        }).flatten().expect("Must have initial text");
        assert!(!initial_text.is_empty());

        // Mark tree clean as if a frame had just been drawn
        runtime.reactive.mark_tree_clean("bar_test");
        assert!(!runtime.reactive.is_tree_dirty("bar_test"));

        // Update signals in-place
        runtime.update_system_signals();

        let updated_text = runtime.reactive.with_tree("bar_test", |node| {
            if let zenith_layout::UiNode::Box { children, .. } = node {
                if let Some(zenith_layout::UiNode::Text { text, .. }) = children.first() {
                    return Some(text.to_string());
                }
            }
            None
        }).flatten().expect("Must have updated text");
        assert!(!updated_text.is_empty());
        // Verify tree was marked dirty for renderer without re-evaluating Luau scripts
        assert!(runtime.reactive.is_tree_dirty("bar_test"));
    }

    #[test]
    fn test_update_system_signals_second_precision_truncation() {
        let runtime = LuauRuntime::new().expect("Failed to initialize runtime");
        let script = r#"
            return Zenith.Box({
                children = {
                    Zenith.Text({
                        text = Zenith.Signals.Time
                    })
                }
            })
        "#;
        runtime.mount_tree("time_tree", script).expect("Failed to mount tree");

        // By default secondPrecision is false -> truncated to HH:MM (5 chars)
        let _ = runtime.storage.set("secondPrecision", serde_json::Value::Bool(false));
        runtime.update_system_signals();
        let time_str = runtime.reactive.with_tree("time_tree", |node| {
            if let zenith_layout::UiNode::Box { children, .. } = node {
                if let Some(zenith_layout::UiNode::Text { text, .. }) = children.first() {
                    return Some(text.to_string());
                }
            }
            None
        }).flatten().expect("Must have time text");
        assert_eq!(time_str.len(), 5, "Time should be HH:MM (5 chars) when secondPrecision is false");
        assert!(time_str.contains(':'));

        // When secondPrecision is true -> full HH:MM:SS (8 chars)
        let _ = runtime.storage.set("secondPrecision", serde_json::Value::Bool(true));
        runtime.update_system_signals();
        let time_str_full = runtime.reactive.with_tree("time_tree", |node| {
            if let zenith_layout::UiNode::Box { children, .. } = node {
                if let Some(zenith_layout::UiNode::Text { text, .. }) = children.first() {
                    return Some(text.to_string());
                }
            }
            None
        }).flatten().expect("Must have time text");
        assert_eq!(time_str_full.len(), 8, "Time should be HH:MM:SS (8 chars) when secondPrecision is true");
    }

    #[test]
    fn test_settings_reset_defaults_reloads_config() {
        let runtime = LuauRuntime::new().expect("Failed to initialize runtime");
        let _ = runtime.storage.set("customTestKey", serde_json::Value::String("customVal".to_string()));
        assert_eq!(runtime.storage.get("customTestKey"), Some(serde_json::Value::String("customVal".to_string())));

        let _ = runtime.trigger_click("settings:reset_defaults");
        assert_eq!(runtime.storage.get("customTestKey"), None);
    }
}

