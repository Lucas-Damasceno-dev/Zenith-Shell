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
    pub pid: i32,
}

/// Internal shared state.
struct HyprlandState {
    is_hyprland: bool,
    active_workspace: i32,
    workspaces: Vec<WorkspaceItem>,
    active_window: ActiveWindowSnapshot,
    clients: Vec<ClientItem>,
    gaps_out: u32,
    socket_dir: Option<PathBuf>,
}

static STATE: OnceLock<Arc<RwLock<HyprlandState>>> = OnceLock::new();
static CHANGE_LISTENER: OnceLock<Arc<dyn Fn() + Send + Sync>> = OnceLock::new();

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

    /// Retrieve current client windows snapshot.
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

    /// Focus a window by address (e.g. `0x1234abcd`).
    pub fn focus_window(address: &str) -> Result<(), String> {
        let arg = if address.starts_with("address:") {
            address.to_string()
        } else {
            format!("address:{}", address)
        };
        Self::dispatch("focuswindow", &arg)
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
                let cmd = format!("dispatch {} {}\n", dispatcher, arg);
                if let Ok(resp) = send_socket_command(&cmd_sock, &cmd) {
                    debug!("Hyprland dispatch socket response: {}", resp.trim());
                    sent = true;
                }
            }

            if !sent {
                // Fallback to hyprctl command line if direct socket write failed
                let _ = std::process::Command::new("hyprctl")
                    .args(["dispatch", dispatcher, arg])
                    .spawn();
            }
        } else {
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
                let cmd = format!("keyword {} {}\n", key, value);
                if let Ok(resp) = send_socket_command(&cmd_sock, &cmd) {
                    debug!("Hyprland keyword socket response: {}", resp.trim());
                    sent = true;
                }
            }

            if !sent {
                let _ = std::process::Command::new("hyprctl")
                    .args(["keyword", key, value])
                    .spawn();
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
                        active_window = ActiveWindowSnapshot { title, class };
                    }
                }

                // Query initial client windows
                let mut clients = Vec::new();
                if let Ok(resp) = send_socket_command(&cmd_sock, "j/clients") {
                    clients = parse_clients_json(&resp);
                }

                let gaps_out = query_gaps_out(&cmd_sock);

                info!(
                    "Hyprland IPC detected at {}. Initial workspace: {}, active window: '{}', clients: {}, gaps: {}",
                    dir.display(),
                    active_workspace,
                    active_window.class,
                    clients.len(),
                    gaps_out
                );

                let state = Arc::new(RwLock::new(HyprlandState {
                    is_hyprland: true,
                    active_workspace,
                    workspaces,
                    active_window,
                    clients,
                    gaps_out,
                    socket_dir: Some(dir),
                }));

                // Spawn background event listener thread for .socket2.sock
                spawn_event_listener(event_sock, cmd_sock, state.clone());

                // Auto-configure hardware blur and ignorezero rules in Hyprland
                Self::apply_glassmorphism_rules();

                state
            } else {
                info!("Hyprland socket not detected. Running HyprlandService in fallback mode.");
                let mut workspaces = Vec::new();
                ensure_minimum_workspaces(&mut workspaces, 1, 4);

                let fallback_clients = vec![
                    ClientItem {
                        address: "0x1a2b3c".to_string(),
                        title: "kitty - zsh".to_string(),
                        class: "kitty".to_string(),
                        initial_class: "kitty".to_string(),
                        workspace_id: 1,
                        workspace_name: "1".to_string(),
                        floating: false,
                        fullscreen: false,
                        pid: 1024,
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
                        pid: 2048,
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
                        pid: 3072,
                    },
                ];

                Arc::new(RwLock::new(HyprlandState {
                    is_hyprland: false,
                    active_workspace: 1,
                    workspaces,
                    active_window: ActiveWindowSnapshot {
                        title: "Zenith Shell".to_string(),
                        class: "zenith".to_string(),
                    },
                    clients: fallback_clients,
                    gaps_out: 10,
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
    stream.set_read_timeout(Some(Duration::from_millis(300)))?;
    stream.set_write_timeout(Some(Duration::from_millis(300)))?;
    stream.write_all(cmd.as_bytes())?;
    stream.shutdown(std::net::Shutdown::Write)?;

    let mut response = String::new();
    stream.read_to_string(&mut response)?;
    Ok(response)
}

/// Spawn the background thread streaming events from `.socket2.sock`.
fn spawn_event_listener(
    event_sock: PathBuf,
    cmd_sock: PathBuf,
    state: Arc<RwLock<HyprlandState>>,
) {
    let _ = std::thread::Builder::new()
        .name("hyprland-ipc".to_string())
        .spawn(move || {
            loop {
                match UnixStream::connect(&event_sock) {
                    Ok(stream) => {
                        info!("Connected to Hyprland event stream: {}", event_sock.display());
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
                        debug!("Waiting for Hyprland event socket ({})...", e);
                    }
                }
                std::thread::sleep(Duration::from_secs(1));
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
            "workspace" => {
                let ws_name = data.trim();
                let ws_id = ws_name.parse::<i32>().unwrap_or_else(|_| {
                    let r = state.read().unwrap();
                    r.workspaces
                        .iter()
                        .find(|w| w.name == ws_name)
                        .map(|w| w.id)
                        .unwrap_or(1)
                });

                let mut w = state.write().unwrap();
                w.active_workspace = ws_id;
                for item in &mut w.workspaces {
                    item.active = item.id == ws_id || item.name == ws_name;
                }
                let known = w.workspaces.iter().any(|item| item.id == ws_id);
                drop(w);

                if !known {
                    resync_workspaces(cmd_sock, state);
                }
                changed = true;
            }
            "focusedmon" => {
                // Format: MONITOR,WORKSPACENAME
                if let Some((_, ws_name)) = data.split_once(',') {
                    let ws_name = ws_name.trim();
                    let ws_id = ws_name.parse::<i32>().unwrap_or(1);
                    let mut w = state.write().unwrap();
                    w.active_workspace = ws_id;
                    for item in &mut w.workspaces {
                        item.active = item.id == ws_id || item.name == ws_name;
                    }
                    changed = true;
                }
            }
            "activewindow" => {
                // Format: WINDOWCLASS,WINDOWTITLE
                let (class, title) = if let Some((c, t)) = data.split_once(',') {
                    (c.trim().to_string(), t.trim().to_string())
                } else {
                    (String::new(), String::new())
                };

                let mut w = state.write().unwrap();
                w.active_window = ActiveWindowSnapshot { title, class };
                changed = true;
            }
            "createworkspace" | "destroyworkspace" => {
                resync_workspaces(cmd_sock, state);
                changed = true;
            }
            "openwindow" | "closewindow" | "movewindow" => {
                resync_workspaces(cmd_sock, state);
                resync_clients(cmd_sock, state);
                changed = true;
            }
            "urgent" => {
                // Re-sync on urgent window flag
                resync_workspaces(cmd_sock, state);
                resync_clients(cmd_sock, state);
                changed = true;
            }
            "configreloaded" => {
                let gaps = query_gaps_out(cmd_sock);
                {
                    let mut w = state.write().unwrap();
                    w.gaps_out = gaps;
                }
                resync_workspaces(cmd_sock, state);
                resync_clients(cmd_sock, state);
                changed = true;
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
            if let Some(s) = val["str"].as_str() {
                if let Some(first) = s.split_whitespace().next() {
                    if let Ok(parsed) = first.parse::<u32>() {
                        return parsed;
                    }
                }
            }
        }
    }
    10
}

/// Parse JSON output from `j/clients` into structured `ClientItem` vec.
pub fn parse_clients_json(json_str: &str) -> Vec<ClientItem> {
    let mut result = Vec::new();
    if let Ok(Value::Array(items)) = serde_json::from_str::<Value>(json_str) {
        for item in items {
            let address = item["address"].as_str().unwrap_or("").to_string();
            let mapped = item["mapped"].as_bool().unwrap_or(true);
            if !mapped || address.is_empty() {
                continue;
            }
            let title = item["title"].as_str().unwrap_or("").to_string();
            let class = item["class"].as_str().unwrap_or("").to_string();
            let initial_class = item["initialClass"].as_str().unwrap_or("").to_string();
            let workspace = &item["workspace"];
            let workspace_id = workspace["id"].as_i64().unwrap_or(0) as i32;
            let workspace_name = workspace["name"].as_str().unwrap_or("").to_string();
            let floating = item["floating"].as_bool().unwrap_or(false);
            let fullscreen = item["fullscreen"].as_bool().unwrap_or(false);
            let pid = item["pid"].as_i64().unwrap_or(0) as i32;

            result.push(ClientItem {
                address,
                title,
                class,
                initial_class,
                workspace_id,
                workspace_name,
                floating,
                fullscreen,
                pid,
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
        if let Ok(Value::Array(items)) = serde_json::from_str::<Value>(&resp) {
            let active_id = state.read().unwrap().active_workspace;
            let mut list = Vec::new();
            for item in items {
                let id = item["id"].as_i64().unwrap_or(0) as i32;
                let name = item["name"].as_str().unwrap_or("").to_string();
                let monitor = item["monitor"].as_str().unwrap_or("").to_string();
                let windows = item["windows"].as_u64().unwrap_or(0) as u32;
                let urgent = item["urgent"].as_bool().unwrap_or(false);
                let active = id == active_id;
                list.push(WorkspaceItem {
                    id,
                    name,
                    monitor,
                    active,
                    urgent,
                    windows,
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fallback_snapshots() {
        let snap = HyprlandService::workspaces_snapshot();
        assert!(snap.workspaces.len() >= 4);
        assert_eq!(snap.active, 1);

        let win = HyprlandService::active_window_snapshot();
        assert!(!win.class.is_empty());
    }

    #[test]
    fn test_fallback_dispatch() {
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
            socket_dir: None,
            gaps_out: 0,
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
        let clients = HyprlandService::clients_snapshot();
        assert!(!clients.is_empty());
        assert!(clients.iter().any(|c| c.class == "kitty"));

        let kitty_addr = &clients[0].address;
        let _ = HyprlandService::focus_window(kitty_addr);
        let win = HyprlandService::active_window_snapshot();
        assert_eq!(win.class, clients[0].class);
    }
}
