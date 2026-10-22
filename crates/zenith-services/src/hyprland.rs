//! Hyprland IPC client and event streaming service.
//!
//! Connects to Hyprland's UNIX sockets (`.socket.sock` and `.socket2.sock`)
//! under `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/`.
//! Provides real-time workspace and active window telemetry with graceful
//! fallback when not running inside a Hyprland compositor session.

use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::sync::{Arc, OnceLock, RwLock};
use std::time::Duration;

use serde::{Deserialize, Serialize};
use serde_json::Value;
use tracing::{debug, info, warn};

/// Individual monitor/output item.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonitorItem {
    pub id: i64,
    pub name: String,
    pub width: u32,
    pub height: u32,
    pub refresh_rate: f32,
    pub scale: f32,
    pub focused: bool,
    #[serde(default)]
    pub x: i32,
    #[serde(default)]
    pub y: i32,
}

/// Individual workspace status item.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkspaceItem {
    pub id: i32,
    pub name: String,
    pub monitor: String,
    pub active: bool,
    pub urgent: bool,
    pub windows: u32,
}

/// Snapshot of all workspaces and current active workspace id.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct WorkspacesSnapshot {
    pub active: i32,
    pub workspaces: Vec<WorkspaceItem>,
}

/// Snapshot of currently focused window.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ActiveWindowSnapshot {
    pub title: String,
    pub class: String,
    pub address: String,
}

/// Individual client window status item.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClientItem {
    pub address: String,
    pub title: String,
    pub class: String,
    pub initial_class: String,
    pub workspace_id: i32,
    pub workspace_name: String,
    pub floating: bool,
    pub fullscreen: bool,
    pub hidden: bool,
    pub monitor: i64,
    pub pid: i32,
    pub at: (i32, i32),
    pub size: (i32, i32),
}

/// Internal shared state.
struct HyprlandState {
    is_hyprland: bool,
    active_workspace: i32,
    workspaces: Vec<WorkspaceItem>,
    active_window: ActiveWindowSnapshot,
    clients: Vec<ClientItem>,
    monitors: Vec<MonitorItem>,
    gaps_out: u32,
    active_layout: String,
    socket_dir: Option<PathBuf>,
}

static STATE: OnceLock<Arc<RwLock<HyprlandState>>> = OnceLock::new();
static CHANGE_LISTENER: OnceLock<Arc<dyn Fn() + Send + Sync>> = OnceLock::new();
static FOCUS_CHANGE_LISTENER: OnceLock<Arc<dyn Fn() + Send + Sync>> = OnceLock::new();

/// Hyprland IPC service provider.
pub struct HyprlandService;

impl HyprlandService {
    /// Retrieve current workspaces snapshot.
    pub fn workspaces_snapshot() -> WorkspacesSnapshot {
        let state = Self::get_state();
        let r = state.read().unwrap();
        WorkspacesSnapshot {
            active: r.active_workspace,
            workspaces: r.workspaces.clone(),
        }
    }

    /// Retrieve current active window snapshot.
    pub fn active_window_snapshot() -> ActiveWindowSnapshot {
        let state = Self::get_state();
        let r = state.read().unwrap();
        r.active_window.clone()
    }

    /// Retrieve active keyboard layout abbreviated to 2-letter ISO code.
    pub fn active_layout() -> String {
        let state = Self::get_state();
        let r = state.read().unwrap();
        let raw = &r.active_layout;
        let lower = raw.to_ascii_lowercase();
        if lower.contains("brazil") || lower.contains("abnt") || lower.contains("portuguese") {
            "BR".to_string()
        } else if lower.contains("english") || lower.contains("us") {
            "US".to_string()
        } else if lower.contains("spanish") || lower.contains("es") {
            "ES".to_string()
        } else if lower.contains("german") || lower.contains("de") {
            "DE".to_string()
        } else if lower.contains("french") || lower.contains("fr") {
            "FR".to_string()
        } else if lower.contains("japanese") || lower.contains("jp") {
            "JP".to_string()
        } else if lower.contains("russian") || lower.contains("ru") {
            "RU".to_string()
        } else {
            let code: String = raw.chars().filter(|c| c.is_alphabetic()).take(2).collect();
            if code.is_empty() {
                "BR".to_string()
            } else {
                code.to_uppercase()
            }
        }
    }

    /// Retrieve current client windows snapshot without synchronous socket blocks.
    pub fn clients_snapshot() -> Vec<ClientItem> {
        let state = Self::get_state();
        let r = state.read().unwrap();
        r.clients.clone()
    }

    /// Retrieve dynamic gaps_out configured in Hyprland.
    pub fn gaps_out() -> u32 {
        let state = Self::get_state();
        let r = state.read().unwrap();
        r.gaps_out
    }

    /// Parses JSON array from `j/monitors` into a list of MonitorItems.
    pub fn parse_monitors_json(resp: &str) -> Vec<MonitorItem> {
        #[derive(Deserialize)]
        struct RawMonitorJson {
            #[serde(default)]
            id: i64,
            #[serde(default)]
            name: String,
            #[serde(default = "default_width")]
            width: u32,
            #[serde(default = "default_height")]
            height: u32,
            #[serde(rename = "refreshRate", default = "default_refresh_rate")]
            refresh_rate: f32,
            #[serde(default = "default_scale")]
            scale: f32,
            #[serde(default)]
            focused: bool,
            #[serde(default)]
            x: i32,
            #[serde(default)]
            y: i32,
        }
        fn default_width() -> u32 { 1920 }
        fn default_height() -> u32 { 1080 }
        fn default_refresh_rate() -> f32 { 60.0 }
        fn default_scale() -> f32 { 1.0 }

        if let Ok(items) = serde_json::from_str::<Vec<RawMonitorJson>>(resp) {
            items.into_iter().map(|item| MonitorItem {
                id: item.id,
                name: item.name,
                width: item.width,
                height: item.height,
                refresh_rate: item.refresh_rate,
                scale: item.scale,
                focused: item.focused,
                x: item.x,
                y: item.y,
            }).collect()
        } else {
            Vec::new()
        }
    }

    /// Retrieve current monitors snapshot from non-blocking Hyprland state cache.
    pub fn monitors() -> Vec<MonitorItem> {
        let state_arc = Self::get_state();
        let r = state_arc.read().unwrap();
        if !r.monitors.is_empty() {
            r.monitors.clone()
        } else {
            vec![MonitorItem {
                id: 0,
                name: "DP-1".to_string(),
                width: 1366,
                height: 768,
                refresh_rate: 60.0,
                scale: 1.0,
                focused: true,
                x: 0,
                y: 0,
            }]
        }
    }

    /// Focus a window by address (e.g. `0x1234abcd`).
    pub fn focus_window(address: &str) -> Result<(), String> {
        let arg = if address.starts_with("address:") {
            address.to_string()
        } else {
            format!("address:{}", address)
        };
        Self::dispatch("focuswindow", &arg)
    }

    /// Toggle window minimize (via special:minimized) or focus window if on another workspace.
    pub fn toggle_minimize_or_focus(address: &str) -> Result<(), String> {
        let clean_addr = if let Some(stripped) = address.strip_prefix("address:") {
            stripped
        } else {
            address
        };

        let state_arc = Self::get_state();
        let (active_ws, client_ws, is_focused) = {
            let r = state_arc.read().unwrap();
            let active_ws = r.active_workspace;
            let client = r.clients.iter().find(|c| {
                let a1 = c.address.trim_start_matches("0x");
                let a2 = clean_addr.trim_start_matches("0x");
                !a1.is_empty() && a1.eq_ignore_ascii_case(a2)
            });
            let client_ws = client.map(|c| (c.workspace_id, c.workspace_name.clone()));
            let is_focused = {
                let a1 = clean_addr.trim_start_matches("0x");
                let a2 = r.active_window.address.trim_start_matches("0x");
                !a1.is_empty() && a1.eq_ignore_ascii_case(a2)
            };
            (active_ws, client_ws, is_focused)
        };

        let target_arg = if clean_addr.starts_with("0x") {
            format!("address:{}", clean_addr)
        } else {
            format!("address:0x{}", clean_addr)
        };

        let res = if let Some((ws_id, ws_name)) = client_ws {
            if ws_name.starts_with("special") || ws_id < 0 {
                // Restore from minimized special workspace back to original workspace
                let target_restore_ws = if let Some(stripped) = ws_name.strip_prefix("special:minimized_") {
                    stripped.parse::<i32>().unwrap_or(active_ws)
                } else {
                    active_ws
                };
                let _ = Self::dispatch("movetoworkspace", &format!("{},{}", target_restore_ws, target_arg));
                Self::dispatch("focuswindow", &target_arg)
            } else if is_focused {
                // Currently focused on active workspace -> minimize to special:minimized_{active_ws}
                Self::dispatch("movetoworkspacesilent", &format!("special:minimized_{},{}", active_ws, target_arg))
            } else {
                // Not focused or in another workspace -> focus window
                Self::dispatch("focuswindow", &target_arg)
            }
        } else {
            Self::dispatch("focuswindow", &target_arg)
        };

        notify_change();
        res
    }

    /// Dispatch a compositor command (e.g. `workspace`, `movetoworkspace`, `focuswindow`).
    pub fn dispatch(dispatcher: &str, arg: &str) -> Result<(), String> {
        let state_arc = Self::get_state();
        let (is_hypr, socket_dir) = {
            let r = state_arc.read().unwrap();
            (r.is_hyprland, r.socket_dir.clone())
        };

        if is_hypr {
            let mut sent = false;
            if let Some(ref dir) = socket_dir {
                let cmd_sock = dir.join(".socket.sock");
                let cmd = format!("dispatch {} {}", dispatcher, arg);
                if let Ok(resp) = send_socket_command(&cmd_sock, &cmd) {
                    debug!("Hyprland dispatch socket response: {}", resp.trim());
                    sent = true;
                }
            }

            if !sent {
                // Direct socket rediscovery (zero-subprocess)
                if let Some(fresh_dir) = resolve_hypr_dir() {
                    let cmd_sock = fresh_dir.join(".socket.sock");
                    let cmd = format!("dispatch {} {}", dispatcher, arg);
                    let _ = send_socket_command(&cmd_sock, &cmd);
                }
            }
        } else {
            // Forward command to Sway IPC if active
            if let Ok(sway_sock) = std::env::var("SWAYSOCK") {
                if dispatcher == "workspace" {
                    let _ = send_sway_ipc(Path::new(&sway_sock), 0, &format!("workspace {}", arg));
                }
            }

            // Fallback / mock mode: update internal state so UI responds reactively
            if dispatcher == "workspace" {
                if let Ok(id) = arg.parse::<i32>() {
                    let mut w = state_arc.write().unwrap();
                    w.active_workspace = id;
                    for item in &mut w.workspaces {
                        item.active = item.id == id;
                    }
                }
            } else if dispatcher == "focuswindow" {
                let addr = arg.strip_prefix("address:").unwrap_or(arg);
                let mut w = state_arc.write().unwrap();
                if let Some(target) = w.clients.iter().find(|c| c.address == addr).cloned() {
                    w.active_window = ActiveWindowSnapshot {
                        title: target.title,
                        class: target.class,
                        address: target.address,
                    };
                    w.active_workspace = target.workspace_id;
                    let target_ws = target.workspace_id;
                    for item in &mut w.workspaces {
                        item.active = item.id == target_ws;
                    }
                }
            }
            notify_change();
        }

        Ok(())
    }

    /// Send a keyword configuration command to Hyprland (e.g. dynamic layerrule).
    pub fn keyword(key: &str, value: &str) -> Result<(), String> {
        let state_arc = Self::get_state();
        let (is_hypr, socket_dir) = {
            let r = state_arc.read().unwrap();
            (r.is_hyprland, r.socket_dir.clone())
        };

        if is_hypr {
            let mut sent = false;
            if let Some(ref dir) = socket_dir {
                let cmd_sock = dir.join(".socket.sock");
                let cmd = format!("keyword {} {}", key, value);
                if let Ok(resp) = send_socket_command(&cmd_sock, &cmd) {
                    debug!("Hyprland keyword socket response: {}", resp.trim());
                    sent = true;
                }
            }

            if !sent {
                // Direct socket rediscovery (zero-subprocess)
                if let Some(fresh_dir) = resolve_hypr_dir() {
                    let cmd_sock = fresh_dir.join(".socket.sock");
                    let cmd = format!("keyword {} {}", key, value);
                    let _ = send_socket_command(&cmd_sock, &cmd);
                }
            }
        }

        Ok(())
    }

    /// Automatically configure hardware-accelerated dual-kawase blur layer rules in Hyprland
    /// for Zenith bar and overlays without CPU/SHM cost.
    pub fn apply_glassmorphism_rules() {
        let rules = [
            ("layerrule", "blur, zenith-bar"),
            ("layerrule", "ignorezero, zenith-bar"),
            ("layerrule", "blur, zenith-popup-.*"),
            ("layerrule", "ignorezero, zenith-popup-.*"),
        ];

        for (k, v) in rules {
            let _ = Self::keyword(k, v);
        }
    }

    /// Register a callback invoked whenever Hyprland state changes.
    pub fn set_change_listener<F>(callback: F)
    where
        F: Fn() + Send + Sync + 'static,
    {
        let _ = CHANGE_LISTENER.set(Arc::new(callback));
    }

    /// Register a callback invoked whenever window or workspace focus changes in Hyprland.
    pub fn set_focus_change_listener<F>(callback: F)
    where
        F: Fn() + Send + Sync + 'static,
    {
        let _ = FOCUS_CHANGE_LISTENER.set(Arc::new(callback));
    }

    /// Returns whether the service is actively connected to a real Hyprland instance.
    pub fn is_hyprland() -> bool {
        let state = Self::get_state();
        state.read().unwrap().is_hyprland
    }

    fn get_state() -> &'static Arc<RwLock<HyprlandState>> {
        STATE.get_or_init(|| {
            let dir_opt = resolve_hypr_dir();

            if let Some(dir) = dir_opt {
                let cmd_sock = dir.join(".socket.sock");
                let event_sock = dir.join(".socket2.sock");

                let mut active_workspace = 1;
                let mut workspaces = Vec::new();
                let mut active_window = ActiveWindowSnapshot::default();

                // Query initial active workspace
                if let Ok(resp) = send_socket_command(&cmd_sock, "j/activeworkspace") {
                    if let Ok(val) = serde_json::from_str::<Value>(&resp) {
                        active_workspace = val["id"].as_i64().unwrap_or(1) as i32;
                    }
                }

                // Query initial workspaces
                if let Ok(resp) = send_socket_command(&cmd_sock, "j/workspaces") {
                    if let Ok(Value::Array(items)) = serde_json::from_str::<Value>(&resp) {
                        for item in items {
                            let id = item["id"].as_i64().unwrap_or(0) as i32;
                            let name = item["name"].as_str().unwrap_or("").to_string();
                            if id < 0 || name.starts_with("special") {
                                continue;
                            }
                            let monitor = item["monitor"].as_str().unwrap_or("").to_string();
                            let windows = item["windows"].as_u64().unwrap_or(0) as u32;
                            let urgent = item["urgent"].as_bool().unwrap_or(false);
                            workspaces.push(WorkspaceItem {
                                id,
                                name,
                                monitor,
                                active: id == active_workspace,
                                urgent,
                                windows,
                            });
                        }
                    }
                }

                ensure_minimum_workspaces(&mut workspaces, active_workspace, 4);

                // Query initial active window
                if let Ok(resp) = send_socket_command(&cmd_sock, "j/activewindow") {
                    if let Ok(val) = serde_json::from_str::<Value>(&resp) {
                        let title = val["title"].as_str().unwrap_or("").to_string();
                        let class = val["class"].as_str().unwrap_or("").to_string();
                        let address = val["address"].as_str().unwrap_or("").to_string();
                        active_window = ActiveWindowSnapshot { title, class, address };
                    }
                }

                // Query initial client windows
                let mut clients = Vec::new();
                if let Ok(resp) = send_socket_command(&cmd_sock, "j/clients") {
                    clients = parse_clients_json(&resp);
                }

                // Query initial monitors
                let mut monitors = Vec::new();
                if let Ok(resp) = send_socket_command(&cmd_sock, "j/monitors") {
                    monitors = Self::parse_monitors_json(&resp);
                }

                let gaps_out = query_gaps_out(&cmd_sock);

                info!(
                    "Hyprland IPC detected at {}. Initial workspace: {}, active window: '{}', clients: {}, monitors: {}, gaps: {}",
                    dir.display(),
                    active_workspace,
                    active_window.class,
                    clients.len(),
                    monitors.len(),
                    gaps_out
                );

                let state = Arc::new(RwLock::new(HyprlandState {
                    is_hyprland: true,
                    active_workspace,
                    workspaces,
                    active_window,
                    clients,
                    monitors,
                    gaps_out,
                    active_layout: "Portuguese (Brazil)".to_string(),
                    socket_dir: Some(dir),
                }));

                // Spawn background event listener thread for .socket2.sock
                spawn_event_listener(event_sock, cmd_sock.clone(), state.clone());

                // Auto-configure hardware blur and ignorezero rules in Hyprland
                let rules = [
                    ("layerrule", "blur, zenith-bar"),
                    ("layerrule", "ignorezero, zenith-bar"),
                    ("layerrule", "blur, zenith-popup-.*"),
                    ("layerrule", "ignorezero, zenith-popup-.*"),
                ];
                for (k, v) in rules {
                    let cmd = format!("keyword {} {}\n", k, v);
                    let _ = send_socket_command(&cmd_sock, &cmd);
                }

                state
            } else {
                let mut active_workspace = 1;
                let mut workspaces = Vec::new();
                let active_window = ActiveWindowSnapshot {
                    title: "Zenith Shell".to_string(),
                    class: "zenith".to_string(),
                    address: String::new(),
                };

                // Check for Sway / i3-ipc compositor socket
                if let Ok(sway_sock_str) = std::env::var("SWAYSOCK") {
                    let sock_path = PathBuf::from(sway_sock_str);
                    if sock_path.exists() {
                        info!("Sway IPC detected at {}. Initializing Sway compositor backend.", sock_path.display());
                        if let Ok(resp) = send_sway_ipc(&sock_path, 1, "") {
                            if let Ok(Value::Array(items)) = serde_json::from_str::<Value>(&resp) {
                                for item in items {
                                    let id = item["num"].as_i64().unwrap_or(item["id"].as_i64().unwrap_or(1)) as i32;
                                    let name = item["name"].as_str().unwrap_or("").to_string();
                                    let monitor = item["output"].as_str().unwrap_or("").to_string();
                                    let active = item["focused"].as_bool().unwrap_or(false);
                                    let urgent = item["urgent"].as_bool().unwrap_or(false);
                                    if active {
                                        active_workspace = id;
                                    }
                                    workspaces.push(WorkspaceItem {
                                        id,
                                        name,
                                        monitor,
                                        active,
                                        urgent,
                                        windows: 1,
                                    });
                                }
                            }
                        }
                    }
                }

                if workspaces.is_empty() {
                    info!("Running Compositor/HyprlandService in fallback mode.");
                    ensure_minimum_workspaces(&mut workspaces, 1, 4);
                }

                let fallback_clients = vec![
                    ClientItem {
                        address: "0x1a2b3c".to_string(),
                        title: "kitty".to_string(),
                        class: "kitty".to_string(),
                        initial_class: "kitty".to_string(),
                        workspace_id: 1,
                        workspace_name: "1".to_string(),
                        floating: false,
                        fullscreen: false,
                        hidden: false,
                        monitor: 0,
                        pid: 1024,
                        at: (0, 0),
                        size: (800, 600),
                    },
                    ClientItem {
                        address: "0x4d5e6f".to_string(),
                        title: "Firefox — Zenith Shell".to_string(),
                        class: "firefox".to_string(),
                        initial_class: "firefox".to_string(),
                        workspace_id: 2,
                        workspace_name: "2".to_string(),
                        floating: false,
                        fullscreen: false,
                        hidden: false,
                        monitor: 0,
                        pid: 2048,
                        at: (0, 0),
                        size: (1920, 1080),
                    },
                    ClientItem {
                        address: "0x7a8b9c".to_string(),
                        title: "Zenith-Shell — Visual Studio Code".to_string(),
                        class: "code".to_string(),
                        initial_class: "code".to_string(),
                        workspace_id: 3,
                        workspace_name: "3".to_string(),
                        floating: false,
                        fullscreen: false,
                        hidden: false,
                        monitor: 0,
                        pid: 3072,
                        at: (0, 0),
                        size: (1920, 1080),
                    },
                ];

                Arc::new(RwLock::new(HyprlandState {
                    is_hyprland: false,
                    active_workspace,
                    workspaces,
                    active_window,
                    clients: fallback_clients,
                    monitors: vec![MonitorItem {
                        id: 0,
                        name: "DP-1".to_string(),
                        width: 1366,
                        height: 768,
                        refresh_rate: 60.0,
                        scale: 1.0,
                        focused: true,
                        x: 0,
                        y: 0,
                    }],
                    gaps_out: 10,
                    active_layout: "Portuguese (Brazil)".to_string(),
                    socket_dir: None,
                }))
            }
        })
    }
}

/// Resolve the Hyprland runtime directory containing IPC sockets.
fn resolve_hypr_dir() -> Option<PathBuf> {
    let runtime_dir = std::env::var("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(format!("/run/user/{}", unsafe { libc::getuid() })));

    if let Ok(his) = std::env::var("HYPRLAND_INSTANCE_SIGNATURE") {
        let trimmed = his.trim();
        if !trimmed.is_empty() {
            let dir = runtime_dir.join("hypr").join(trimmed);
            if dir.join(".socket2.sock").exists() {
                return Some(dir);
            }
        }
    }

    // Auto-discovery: check runtime_dir/hypr/
    let hypr_base = runtime_dir.join("hypr");
    if hypr_base.is_dir() {
        if let Ok(entries) = std::fs::read_dir(&hypr_base) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() && path.join(".socket2.sock").exists() {
                    return Some(path);
                }
            }
        }
    }

    None
}

/// Send request to Hyprland command socket (`.socket.sock`) and read full response.
fn send_socket_command(cmd_sock: &Path, cmd: &str) -> std::io::Result<String> {
    let mut stream = UnixStream::connect(cmd_sock)?;
    stream.set_read_timeout(Some(Duration::from_millis(60)))?;
    stream.set_write_timeout(Some(Duration::from_millis(60)))?;
    stream.write_all(cmd.as_bytes())?;
    stream.shutdown(std::net::Shutdown::Write)?;

    let mut response = String::new();
    stream.read_to_string(&mut response)?;
    Ok(response)
}

/// Send request to Sway i3-ipc UNIX socket and read full response.
fn send_sway_ipc(sock_path: &Path, msg_type: u32, payload: &str) -> Result<String, Box<dyn std::error::Error>> {
    let mut stream = UnixStream::connect(sock_path)?;
    stream.set_read_timeout(Some(Duration::from_millis(300)))?;
    stream.set_write_timeout(Some(Duration::from_millis(300)))?;

    let magic = b"i3-ipc";
    let len = payload.len() as u32;
    stream.write_all(magic)?;
    stream.write_all(&len.to_ne_bytes())?;
    stream.write_all(&msg_type.to_ne_bytes())?;
    if !payload.is_empty() {
        stream.write_all(payload.as_bytes())?;
    }

    let mut header = [0u8; 14];
    stream.read_exact(&mut header)?;
    if &header[0..6] != b"i3-ipc" {
        return Err("Invalid i3-ipc magic header".into());
    }
    let resp_len = u32::from_ne_bytes(header[6..10].try_into()?) as usize;
    let mut resp_buf = vec![0u8; resp_len];
    stream.read_exact(&mut resp_buf)?;
    Ok(String::from_utf8(resp_buf)?)
}

/// Resync all Hyprland state snapshots from command socket upon reconnect.
fn resync_hyprland_state(cmd_sock: &Path, state: &Arc<RwLock<HyprlandState>>) {
    let mut active_workspace = 1;
    let mut workspaces = Vec::new();
    let mut active_window = ActiveWindowSnapshot {
        title: "Zenith Shell".to_string(),
        class: "zenith".to_string(),
        address: String::new(),
    };
    let mut clients = Vec::new();

    if let Ok(resp) = send_socket_command(cmd_sock, "j/activeworkspace") {
        if let Ok(val) = serde_json::from_str::<Value>(&resp) {
            if let Some(id) = val["id"].as_i64() {
                active_workspace = id as i32;
            }
        }
    }

    if let Ok(resp) = send_socket_command(cmd_sock, "j/workspaces") {
        if let Ok(Value::Array(items)) = serde_json::from_str::<Value>(&resp) {
            for item in items {
                let id = item["id"].as_i64().unwrap_or(1) as i32;
                let name = item["name"].as_str().unwrap_or("").to_string();
                if id < 0 || name.starts_with("special") {
                    continue;
                }
                let urgent = item["urgent"].as_bool().unwrap_or(false);
                let monitor = item["monitor"].as_str().unwrap_or("").to_string();
                let windows = item["windows"].as_u64().unwrap_or(0) as u32;
                workspaces.push(WorkspaceItem {
                    id,
                    name,
                    monitor,
                    active: id == active_workspace,
                    urgent,
                    windows,
                });
            }
        }
    }
    workspaces.sort_by_key(|w| w.id);
    ensure_minimum_workspaces(&mut workspaces, active_workspace, 4);

    if let Ok(resp) = send_socket_command(cmd_sock, "j/activewindow") {
        if let Ok(val) = serde_json::from_str::<Value>(&resp) {
            active_window = ActiveWindowSnapshot {
                title: val["title"].as_str().unwrap_or("").to_string(),
                class: val["class"].as_str().unwrap_or("").to_string(),
                address: val["address"].as_str().unwrap_or("").to_string(),
            };
        }
    }

    if let Ok(resp) = send_socket_command(cmd_sock, "j/clients") {
        clients = parse_clients_json(&resp);
    }

    let mut monitors = Vec::new();
    if let Ok(resp) = send_socket_command(cmd_sock, "j/monitors") {
        monitors = HyprlandService::parse_monitors_json(&resp);
    }
    let gaps_out = query_gaps_out(cmd_sock);

    if let Ok(mut w) = state.write() {
        w.is_hyprland = true;
        w.active_workspace = active_workspace;
        w.workspaces = workspaces;
        w.active_window = active_window;
        w.clients = clients;
        if !monitors.is_empty() {
            w.monitors = monitors;
        }
        w.gaps_out = gaps_out;
    }
    notify_change();
}

/// Spawn the background thread streaming events from `.socket2.sock` with resilient auto-reconnect and exponential backoff.
fn spawn_event_listener(
    initial_event_sock: PathBuf,
    initial_cmd_sock: PathBuf,
    state: Arc<RwLock<HyprlandState>>,
) {
    let _ = std::thread::Builder::new()
        .name("hyprland-ipc".to_string())
        .spawn(move || {
            let mut event_sock = initial_event_sock;
            let mut cmd_sock = initial_cmd_sock;
            let mut backoff = Duration::from_millis(50);
            let max_backoff = Duration::from_millis(2000);

            loop {
                // If socket doesn't exist on disk, re-resolve hypr runtime directory
                if !event_sock.exists() {
                    if let Some(dir) = resolve_hypr_dir() {
                        event_sock = dir.join(".socket2.sock");
                        cmd_sock = dir.join(".socket.sock");
                        if let Ok(mut w) = state.write() {
                            w.socket_dir = Some(dir);
                            w.is_hyprland = true;
                        }
                    }
                }

                match UnixStream::connect(&event_sock) {
                    Ok(stream) => {
                        info!("Connected to Hyprland event stream: {}", event_sock.display());
                        backoff = Duration::from_millis(50);

                        // Resynchronize state upon fresh connection
                        resync_hyprland_state(&cmd_sock, &state);

                        let reader = BufReader::new(stream);
                        for line in reader.lines() {
                            match line {
                                Ok(line) => {
                                    handle_event_line(&line, &cmd_sock, &state);
                                }
                                Err(e) => {
                                    warn!("Hyprland event socket read error: {}", e);
                                    break;
                                }
                            }
                        }
                    }
                    Err(e) => {
                        debug!("Waiting for Hyprland event socket ({}), retry in {:?}...", e, backoff);
                    }
                }

                std::thread::sleep(backoff);
                backoff = (backoff * 2).min(max_backoff);
            }
        });
}

/// Process a single event line from Hyprland event socket (`.socket2.sock`).
fn handle_event_line(line: &str, cmd_sock: &Path, state: &Arc<RwLock<HyprlandState>>) {
    let line = line.trim();
    if line.is_empty() {
        return;
    }

    if let Some((event, data)) = line.split_once(">>") {
        let mut changed = false;

        match event {
            "workspace" | "workspacev2" => {
                let ws_str = if let Some((id_str, _)) = data.split_once(',') {
                    id_str.trim()
                } else {
                    data.trim()
                };
                let ws_id = ws_str.parse::<i32>().unwrap_or_else(|_| {
                    let r = state.read().unwrap();
                    r.workspaces
                        .iter()
                        .find(|w| w.name == ws_str)
                        .map(|w| w.id)
                        .unwrap_or(1)
                });

                {
                    let mut w = state.write().unwrap();
                    w.active_workspace = ws_id;
                    for item in &mut w.workspaces {
                        item.active = item.id == ws_id || item.name == ws_str;
                    }
                    ensure_minimum_workspaces(&mut w.workspaces, ws_id, 4);
                }
                notify_focus_change();
                changed = true;
            }
            "focusedmon" => {
                // Format: MONITOR,WORKSPACENAME
                let mon_name = data.split(',').next().unwrap_or("").trim();
                if let Some((_, ws_name)) = data.split_once(',') {
                    let ws_name = ws_name.trim();
                    let ws_id = ws_name.parse::<i32>().unwrap_or(1);
                    {
                        let mut w = state.write().unwrap();
                        w.active_workspace = ws_id;
                        for item in &mut w.workspaces {
                            item.active = item.id == ws_id || item.name == ws_name;
                        }
                        for mon in &mut w.monitors {
                            mon.focused = mon.name == mon_name;
                        }
                    }
                    changed = true;
                }
            }
            "monitoradded" | "monitoraddedv2" | "monitorremoved" => {
                if let Ok(resp) = send_socket_command(cmd_sock, "j/monitors") {
                    let new_mons = HyprlandService::parse_monitors_json(&resp);
                    if !new_mons.is_empty() {
                        let mut w = state.write().unwrap();
                        w.monitors = new_mons;
                    }
                }
                changed = true;
            }
            "activewindowv2" => {
                let addr = data.split(',').next().unwrap_or("").trim().to_string();
                let has_focused_client = !addr.is_empty() && addr != ",";
                let mut w = state.write().unwrap();
                w.active_window.address = addr.clone();
                let client_info = w.clients.iter().find(|c| {
                    let a1 = c.address.trim_start_matches("0x");
                    let a2 = addr.trim_start_matches("0x");
                    !a1.is_empty() && a1.eq_ignore_ascii_case(a2)
                }).map(|c| (c.class.clone(), c.title.clone()));

                if let Some((cls, ttl)) = client_info {
                    w.active_window.class = cls;
                    w.active_window.title = ttl;
                    drop(w);
                } else {
                    drop(w);
                    if has_focused_client {
                        resync_clients(cmd_sock, state);
                        let mut w = state.write().unwrap();
                        let client_info = w.clients.iter().find(|c| {
                            let a1 = c.address.trim_start_matches("0x");
                            let a2 = addr.trim_start_matches("0x");
                            !a1.is_empty() && a1.eq_ignore_ascii_case(a2)
                        }).map(|c| (c.class.clone(), c.title.clone()));
                        if let Some((cls, ttl)) = client_info {
                            w.active_window.class = cls;
                            w.active_window.title = ttl;
                        }
                    }
                }
                if has_focused_client {
                    notify_focus_change();
                }
                changed = true;
            }
            "activewindow" => {
                // Format: WINDOWCLASS,WINDOWTITLE
                let (class, title) = if let Some((c, t)) = data.split_once(',') {
                    (c.trim().to_string(), t.trim().to_string())
                } else {
                    (data.trim().to_string(), String::new())
                };

                let mut w = state.write().unwrap();
                w.active_window.class = class.clone();
                w.active_window.title = title.clone();
                if let Some(c) = w.clients.iter().find(|c| c.class == class && c.title == title) {
                    w.active_window.address = c.address.clone();
                }
                changed = true;
            }
            "activelayout" => {
                let layout = if let Some((_kb, lay)) = data.split_once(',') {
                    lay.trim().to_string()
                } else {
                    data.trim().to_string()
                };
                let mut w = state.write().unwrap();
                w.active_layout = layout;
                changed = true;
            }
            "createworkspace" | "createworkspacev2" => {
                let ws_str = if let Some((id_str, _)) = data.split_once(',') {
                    id_str.trim()
                } else {
                    data.trim()
                };
                if let Ok(id) = ws_str.parse::<i32>() {
                    if id > 0 && !data.contains("special") {
                        let mut w = state.write().unwrap();
                        if !w.workspaces.iter().any(|item| item.id == id) {
                            let active_id = w.active_workspace;
                            w.workspaces.push(WorkspaceItem {
                                id,
                                name: ws_str.to_string(),
                                monitor: String::new(),
                                active: id == active_id,
                                urgent: false,
                                windows: 0,
                            });
                            w.workspaces.sort_by_key(|item| item.id);
                        }
                    }
                }
                changed = true;
            }
            "destroyworkspace" | "destroyworkspacev2" => {
                let ws_str = if let Some((id_str, _)) = data.split_once(',') {
                    id_str.trim()
                } else {
                    data.trim()
                };
                if let Ok(id) = ws_str.parse::<i32>() {
                    let mut w = state.write().unwrap();
                    let active_id = w.active_workspace;
                    if id != active_id && w.workspaces.len() > 4 {
                        w.workspaces.retain(|item| item.id != id);
                    }
                }
                changed = true;
            }
            "openwindow" | "closewindow" | "movewindow" | "movewindowv2" | "fullscreen" | "changefloatingmode" | "pin" | "urgent" => {
                resync_workspaces(cmd_sock, state);
                resync_clients(cmd_sock, state);
                notify_change();
            }
            "configreloaded" => {
                let gaps = query_gaps_out(cmd_sock);
                {
                    let mut w = state.write().unwrap();
                    w.gaps_out = gaps;
                }
                resync_workspaces(cmd_sock, state);
                resync_clients(cmd_sock, state);
                notify_change();
            }
            _ => {}
        }

        if changed {
            notify_change();
        }
    }
}

/// Query `general:gaps_out` setting from Hyprland IPC command socket.
pub fn query_gaps_out(cmd_sock: &Path) -> u32 {
    if let Ok(resp) = send_socket_command(cmd_sock, "j/getoption general:gaps_out") {
        if let Ok(val) = serde_json::from_str::<Value>(&resp) {
            if let Some(i) = val["int"].as_i64() {
                if i >= 0 {
                    return i as u32;
                }
            }
            if let Some(s) = val["custom"].as_str().or_else(|| val["str"].as_str()) {
                if let Some(first) = s.split_whitespace().next() {
                    if let Ok(parsed) = first.parse::<u32>() {
                        return parsed;
                    }
                }
            }
        }
    }
    8
}

#[derive(Deserialize)]
struct RawWorkspaceRef {
    #[serde(default)]
    id: i64,
    #[serde(default)]
    name: String,
}

#[derive(Deserialize)]
#[serde(untagged)]
enum RawBoolOrInt {
    Bool(bool),
    Int(i64),
}

impl RawBoolOrInt {
    fn is_true(&self) -> bool {
        match self {
            RawBoolOrInt::Bool(b) => *b,
            RawBoolOrInt::Int(i) => *i != 0,
        }
    }
}

#[derive(Deserialize)]
struct RawClientJson {
    #[serde(default)]
    address: String,
    #[serde(default = "default_client_mapped")]
    mapped: bool,
    #[serde(default)]
    title: String,
    #[serde(default)]
    class: String,
    #[serde(rename = "initialClass", default)]
    initial_class: String,
    #[serde(default)]
    workspace: Option<RawWorkspaceRef>,
    #[serde(default)]
    floating: bool,
    #[serde(default)]
    fullscreen: Option<RawBoolOrInt>,
    #[serde(rename = "fullscreenClient", default)]
    fullscreen_client: Option<RawBoolOrInt>,
    #[serde(default)]
    hidden: bool,
    #[serde(default)]
    monitor: i64,
    #[serde(default)]
    pid: i32,
    #[serde(default)]
    at: Option<(i32, i32)>,
    #[serde(default)]
    size: Option<(i32, i32)>,
}
fn default_client_mapped() -> bool { true }

#[derive(Deserialize)]
struct RawWorkspaceJson {
    #[serde(default)]
    id: i32,
    #[serde(default)]
    name: String,
    #[serde(default)]
    monitor: String,
    #[serde(default)]
    windows: u32,
    #[serde(default)]
    urgent: bool,
}

/// Parse JSON output from `j/clients` into structured `ClientItem` vec.
pub fn parse_clients_json(json_str: &str) -> Vec<ClientItem> {
    let mut result = Vec::new();
    if let Ok(items) = serde_json::from_str::<Vec<RawClientJson>>(json_str) {
        for item in items {
            if !item.mapped || item.address.is_empty() {
                continue;
            }
            let (ws_id, ws_name) = item.workspace
                .map(|w| (w.id as i32, w.name))
                .unwrap_or((0, String::new()));
            let fullscreen = item.fullscreen.as_ref().map(|f| f.is_true()).unwrap_or(false)
                || item.fullscreen_client.as_ref().map(|f| f.is_true()).unwrap_or(false);

            result.push(ClientItem {
                address: item.address,
                title: item.title,
                class: item.class,
                initial_class: item.initial_class,
                workspace_id: ws_id,
                workspace_name: ws_name,
                floating: item.floating,
                fullscreen,
                hidden: item.hidden,
                monitor: item.monitor,
                pid: item.pid,
                at: item.at.unwrap_or((0, 0)),
                size: item.size.unwrap_or((0, 0)),
            });
        }
    }
    result
}

/// Re-query client windows via command socket to synchronize active apps.
fn resync_clients(cmd_sock: &Path, state: &Arc<RwLock<HyprlandState>>) {
    if let Ok(resp) = send_socket_command(cmd_sock, "j/clients") {
        let clients = parse_clients_json(&resp);
        let mut w = state.write().unwrap();
        w.clients = clients;
    }
}

/// Re-query workspaces list via command socket to synchronize window counts and list.
fn resync_workspaces(cmd_sock: &Path, state: &Arc<RwLock<HyprlandState>>) {
    if let Ok(resp) = send_socket_command(cmd_sock, "j/workspaces") {
        if let Ok(items) = serde_json::from_str::<Vec<RawWorkspaceJson>>(&resp) {
            let active_id = state.read().unwrap().active_workspace;
            let mut list = Vec::new();
            for item in items {
                if item.id < 0 || item.name.starts_with("special") {
                    continue;
                }
                let active = item.id == active_id;
                list.push(WorkspaceItem {
                    id: item.id,
                    name: item.name,
                    monitor: item.monitor,
                    active,
                    urgent: item.urgent,
                    windows: item.windows,
                });
            }

            ensure_minimum_workspaces(&mut list, active_id, 4);

            let mut w = state.write().unwrap();
            w.workspaces = list;
        }
    }
}

/// Ensure at least `min_count` workspace items are available for UI representation.
fn ensure_minimum_workspaces(workspaces: &mut Vec<WorkspaceItem>, active_id: i32, min_count: i32) {
    let max_id = workspaces
        .iter()
        .map(|w| w.id)
        .max()
        .unwrap_or(0)
        .max(active_id)
        .max(min_count);

    for id in 1..=max_id {
        if !workspaces.iter().any(|w| w.id == id) {
            workspaces.push(WorkspaceItem {
                id,
                name: id.to_string(),
                monitor: String::new(),
                active: id == active_id,
                urgent: false,
                windows: 0,
            });
        }
    }

    workspaces.sort_by_key(|w| w.id);
}

fn notify_change() {
    if let Some(cb) = CHANGE_LISTENER.get() {
        cb();
    }
}

fn notify_focus_change() {
    if let Some(cb) = FOCUS_CHANGE_LISTENER.get() {
        cb();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fallback_snapshots() {
        if HyprlandService::get_state().read().unwrap().is_hyprland {
            return;
        }
        let snap = HyprlandService::workspaces_snapshot();
        assert!(snap.workspaces.len() >= 4);
        assert_eq!(snap.active, 1);

        let win = HyprlandService::active_window_snapshot();
        assert!(!win.class.is_empty());
    }

    #[test]
    fn test_fallback_dispatch() {
        if HyprlandService::get_state().read().unwrap().is_hyprland {
            return;
        }
        let _ = HyprlandService::dispatch("workspace", "3");
        let snap = HyprlandService::workspaces_snapshot();
        assert_eq!(snap.active, 3);
        assert!(snap.workspaces.iter().any(|w| w.id == 3 && w.active));
        // Reset to 1
        let _ = HyprlandService::dispatch("workspace", "1");
    }

    #[test]
    fn test_handle_event_line_parsing() {
        let state = Arc::new(RwLock::new(HyprlandState {
            is_hyprland: true,
            active_workspace: 1,
            workspaces: vec![
                WorkspaceItem { id: 1, name: "1".into(), monitor: "DP-1".into(), active: true, urgent: false, windows: 1 },
                WorkspaceItem { id: 2, name: "2".into(), monitor: "DP-1".into(), active: false, urgent: false, windows: 0 },
            ],
            active_window: ActiveWindowSnapshot::default(),
            clients: vec![],
            monitors: vec![MonitorItem {
                id: 0,
                name: "DP-1".to_string(),
                width: 1920,
                height: 1080,
                refresh_rate: 60.0,
                scale: 1.0,
                x: 0,
                y: 0,
                focused: false,
            }],
            socket_dir: None,
            gaps_out: 0,
            active_layout: "Portuguese (Brazil)".to_string(),
        }));

        let dummy_path = Path::new("/dev/null");
        handle_event_line("workspace>>2", dummy_path, &state);
        {
            let r = state.read().unwrap();
            assert_eq!(r.active_workspace, 2);
            assert!(r.workspaces[1].active);
            assert!(!r.workspaces[0].active);
        }

        handle_event_line("activewindow>>kitty,dev@nixos: ~/test", dummy_path, &state);
        {
            let r = state.read().unwrap();
            assert_eq!(r.active_window.class, "kitty");
            assert_eq!(r.active_window.title, "dev@nixos: ~/test");
        }

        handle_event_line("focusedmon>>DP-1,1", dummy_path, &state);
        {
            let r = state.read().unwrap();
            assert_eq!(r.active_workspace, 1);
        }
    }

    #[test]
    fn test_parse_clients_json() {
        let raw_json = r#"[
            {
                "address": "0x55a1b2c3d4e5",
                "mapped": true,
                "title": "Zenith - Terminal",
                "class": "kitty",
                "initialClass": "kitty",
                "workspace": { "id": 1, "name": "1" },
                "floating": false,
                "fullscreen": false,
                "pid": 4321
            },
            {
                "address": "0x55a1b2c3d4f6",
                "mapped": false,
                "title": "Unmapped Window",
                "class": "unmapped",
                "initialClass": "unmapped",
                "workspace": { "id": 1, "name": "1" },
                "floating": false,
                "fullscreen": false,
                "pid": 9999
            }
        ]"#;

        let clients = parse_clients_json(raw_json);
        assert_eq!(clients.len(), 1);
        assert_eq!(clients[0].address, "0x55a1b2c3d4e5");
        assert_eq!(clients[0].class, "kitty");
        assert_eq!(clients[0].workspace_id, 1);
        assert_eq!(clients[0].pid, 4321);
    }

    #[test]
    fn test_fallback_clients_and_focus() {
        if HyprlandService::get_state().read().unwrap().is_hyprland {
            return;
        }
        let clients = HyprlandService::clients_snapshot();
        assert!(!clients.is_empty());
        assert!(clients.iter().any(|c| c.class == "kitty"));

        let kitty_addr = &clients[0].address;
        let _ = HyprlandService::focus_window(kitty_addr);
        let win = HyprlandService::active_window_snapshot();
        assert_eq!(win.class, clients[0].class);
    }

    #[test]
    fn test_active_layout_abbreviation() {
        let layout = HyprlandService::active_layout();
        assert_eq!(layout.len(), 2, "Active layout must be abbreviated to 2 ISO chars");
        assert!(layout.chars().all(|c| c.is_ascii_uppercase()));
    }

    #[test]
    fn test_parse_monitors_json_typed() {
        let raw = r#"[
            {
                "id": 0,
                "name": "eDP-1",
                "width": 1920,
                "height": 1080,
                "refreshRate": 144.0,
                "scale": 1.25,
                "focused": true,
                "x": 0,
                "y": 0
            }
        ]"#;
        let mons = HyprlandService::parse_monitors_json(raw);
        assert_eq!(mons.len(), 1);
        assert_eq!(mons[0].id, 0);
        assert_eq!(mons[0].name, "eDP-1");
        assert_eq!(mons[0].width, 1920);
        assert_eq!(mons[0].height, 1080);
        assert_eq!(mons[0].refresh_rate, 144.0);
        assert_eq!(mons[0].scale, 1.25);
        assert!(mons[0].focused);
    }
}
