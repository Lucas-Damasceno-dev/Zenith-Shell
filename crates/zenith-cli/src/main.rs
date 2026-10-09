//! Zenith Desktop Shell CLI & Entrypoint with Sub-ms Hot-Reload & IPC Control Socket.

use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::time::Duration;

use calloop::EventLoop;
use calloop_wayland_source::WaylandSource;
use notify::{Config, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use tracing::{debug, error, info, trace};
use zenith_core::init_logging;
use zenith_wayland::WaylandApp;

enum ShellCommand {
    Reload,
    Toggle(String),
    Open(String),
    Close,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    let subcmd = args.get(1).map(|s| s.as_str()).unwrap_or("daemon");

    match subcmd {
        "reload" => send_socket_command("reload"),
        "toggle" => {
            let target = args.get(2).map(|s| s.as_str()).unwrap_or("Launcher");
            send_socket_command(&format!("toggle {}", target))
        }
        "open" => {
            let target = args.get(2).map(|s| s.as_str()).unwrap_or("Launcher");
            send_socket_command(&format!("open {}", target))
        }
        "close" => send_socket_command("close"),
        "lock" => send_socket_command("lock"),
        "inspect" => send_socket_command("inspect"),
        "help" | "--help" | "-h" => {
            print_help();
            Ok(())
        }
        "daemon" | "run" => {
            let custom_cfg = args.get(2).map(PathBuf::from);
            run_daemon(custom_cfg)
        }
        _ => {
            // If argument is a file path, assume daemon with that config
            let p = PathBuf::from(subcmd);
            if p.exists() || p.extension().and_then(|s| s.to_str()) == Some("luau") {
                run_daemon(Some(p))
            } else {
                eprintln!("Unknown command: '{}'. Run 'zenith help' for usage.", subcmd);
                std::process::exit(1);
            }
        }
    }
}

fn print_help() {
    println!("Zenith-Shell (Engine v2) — Wayland Desktop Shell Framework");
    println!();
    println!("USAGE:");
    println!("    zenith [COMMAND] [OPTIONS]");
    println!();
    println!("COMMANDS:");
    println!("    daemon [path]        Run shell daemon (default: config/zenith/bar.luau)");
    println!("    reload               Trigger sub-10ms hot-reload of active Luau configuration");
    println!("    toggle <popup_id>    Toggle an overlay popup (e.g. Launcher, AudioPopup)");
    println!("    open <popup_id>      Open specified overlay popup");
    println!("    close                Close currently open overlay popup");
    println!("    lock                 Activate screen locker overlay");
    println!("    inspect              Display live shell telemetry (RSS, heap, popups)");
    println!("    help                 Show this help message");
}

fn resolve_socket_path() -> PathBuf {
    if let Ok(dir) = std::env::var("XDG_RUNTIME_DIR") {
        PathBuf::from(dir).join("zenith.sock")
    } else {
        PathBuf::from("/tmp/zenith.sock")
    }
}

fn send_socket_command(cmd: &str) -> Result<(), Box<dyn std::error::Error>> {
    let sock_path = resolve_socket_path();
    if !sock_path.exists() {
        eprintln!(
            "Error: Zenith daemon is not running (socket not found at {}).",
            sock_path.display()
        );
        std::process::exit(1);
    }

    let mut stream = match UnixStream::connect(&sock_path) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Failed to connect to Zenith socket: {}", e);
            std::process::exit(1);
        }
    };

    stream.set_read_timeout(Some(Duration::from_secs(2)))?;
    stream.write_all(format!("{}\n", cmd).as_bytes())?;

    let mut reader = BufReader::new(stream);
    let mut response = String::new();
    let _ = reader.read_line(&mut response);

    let trimmed = response.trim();
    if !trimmed.is_empty() {
        println!("{}", trimmed);
    }
    Ok(())
}

fn run_daemon(custom_path: Option<PathBuf>) -> Result<(), Box<dyn std::error::Error>> {
    init_logging();
    info!("Starting Zenith Desktop Shell (Engine v2)...");

    let (mut app, conn, event_queue) = WaylandApp::init()?;

    // Locate Luau configuration file
    let local_cfg = Path::new("config/zenith/bar.luau");
    let home_cfg = dirs_config_path();

    let script_path = if let Some(ref p) = custom_path {
        Some(p.clone())
    } else if local_cfg.exists() {
        Some(local_cfg.to_path_buf())
    } else if let Some(ref p) = home_cfg {
        if p.exists() {
            Some(p.clone())
        } else {
            None
        }
    } else {
        None
    };

    // Initial load
    if let Some(ref path) = script_path {
        info!("Loading Luau config from: {}", path.display());
        if let Ok(code) = fs::read_to_string(path) {
            if let Err(e) = app.reload_script(&code) {
                error!("Failed to execute Luau script {}: {}", path.display(), e);
            }
        }
    }

    // Set up calloop event loop
    let mut event_loop: EventLoop<WaylandApp> = EventLoop::try_new()?;
    let loop_handle = event_loop.handle();

    // Attach Wayland event source to calloop
    WaylandSource::new(conn, event_queue).insert(loop_handle.clone())?;

    // Create channel for reload notifications
    let (reload_sender, reload_channel) = calloop::channel::channel::<String>();

    loop_handle.insert_source(reload_channel, |event, _, app: &mut WaylandApp| {
        if let calloop::channel::Event::Msg(code) = event {
            debug!("Hot-reload event received! Recomputing Luau UI tree...");
            let start = std::time::Instant::now();
            if let Err(e) = app.reload_script(&code) {
                error!("Luau script error on hot-reload: {}", e);
            } else {
                let elapsed = start.elapsed();
                trace!("Hot-reload applied in {:?}!", elapsed);
            }
        }
    })?;

    // Create channel for IPC socket commands (toggle, open, close)
    let (cmd_sender, cmd_channel) = calloop::channel::channel::<ShellCommand>();

    let cmd_reload_sender = reload_sender.clone();
    let cmd_script_path = script_path.clone();

    loop_handle.insert_source(cmd_channel, move |event, _, app: &mut WaylandApp| {
        if let calloop::channel::Event::Msg(cmd) = event {
            match cmd {
                ShellCommand::Reload => {
                    if let Some(ref path) = cmd_script_path {
                        if let Ok(code) = fs::read_to_string(path) {
                            let _ = cmd_reload_sender.send(code);
                        }
                    }
                }
                ShellCommand::Toggle(id) => {
                    info!("IPC command: toggle popup '{}'", id);
                    app.toggle_popup(&id);
                }
                ShellCommand::Open(id) => {
                    info!("IPC command: open popup '{}'", id);
                    let _ = app.open_popup(&id);
                }
                ShellCommand::Close => {
                    info!("IPC command: close popup");
                    app.close_popup();
                }
            }
        }
    })?;

    // Bind UNIX domain control socket
    let sock_path = resolve_socket_path();
    if sock_path.exists() {
        let _ = fs::remove_file(&sock_path);
    }

    let listener = UnixListener::bind(&sock_path)?;
    info!("IPC control socket listening at: {}", sock_path.display());

    let socket_cmd_sender = cmd_sender.clone();
    let inspect_sock_path = sock_path.clone();

    std::thread::spawn(move || {
        for stream_res in listener.incoming() {
            let mut stream = match stream_res {
                Ok(s) => s,
                Err(_) => continue,
            };

            let mut reader = BufReader::new(&stream);
            let mut line = String::new();
            if reader.read_line(&mut line).is_err() {
                continue;
            }

            let trimmed = line.trim();
            if trimmed == "reload" {
                let _ = socket_cmd_sender.send(ShellCommand::Reload);
                let _ = stream.write_all(b"OK: reload scheduled\n");
            } else if let Some(stripped) = trimmed.strip_prefix("toggle ") {
                let id = stripped.trim().to_string();
                let _ = socket_cmd_sender.send(ShellCommand::Toggle(id));
                let _ = stream.write_all(b"OK: toggle dispatched\n");
            } else if let Some(stripped) = trimmed.strip_prefix("open ") {
                let id = stripped.trim().to_string();
                let _ = socket_cmd_sender.send(ShellCommand::Open(id));
                let _ = stream.write_all(b"OK: open dispatched\n");
            } else if trimmed == "close" {
                let _ = socket_cmd_sender.send(ShellCommand::Close);
                let _ = stream.write_all(b"OK: close dispatched\n");
            } else if trimmed == "lock" {
                let _ = std::process::Command::new("hyprlock").spawn();
                let _ = stream.write_all(b"OK: screen locked with hyprlock\n");
            } else if trimmed == "inspect" {
                let (vmrss_mb, heap_mb) = read_self_memory();
                let resp = format!(
                    "{{\"status\":\"running\",\"vmrss_mb\":{:.2},\"heap_mb\":{:.2},\"socket\":\"{}\"}}\n",
                    vmrss_mb, heap_mb, inspect_sock_path.display()
                );
                let _ = stream.write_all(resp.as_bytes());
            } else {
                let _ = stream.write_all(b"ERR: unknown command\n");
            }
        }
    });

    // Hook Hyprland compositor IPC change listener for sub-10ms UI updates
    let hypr_sender = reload_sender.clone();
    let hypr_path = script_path.clone();
    zenith_services::HyprlandService::set_change_listener(move || {
        if let Some(ref path) = hypr_path {
            if let Ok(code) = fs::read_to_string(path) {
                let _ = hypr_sender.send(code);
            }
        }
    });

    // Hook Notification Daemon change listener for instant UI updates
    let notif_sender = reload_sender.clone();
    let notif_path = script_path.clone();
    zenith_services::NotificationService::set_change_listener(move || {
        if let Some(ref path) = notif_path {
            if let Ok(code) = fs::read_to_string(path) {
                let _ = notif_sender.send(code);
            }
        }
    });

    // Start background file watcher if config exists
    let _watcher = if let Some(ref path) = script_path {
        let watch_path = path.clone();
        let sender = reload_sender.clone();

        let mut watcher = RecommendedWatcher::new(
            move |res: notify::Result<notify::Event>| {
                if let Ok(event) = res {
                    if matches!(event.kind, EventKind::Modify(_) | EventKind::Create(_)) {
                        if let Ok(code) = fs::read_to_string(&watch_path) {
                            let _ = sender.send(code);
                        }
                    }
                }
            },
            Config::default().with_poll_interval(Duration::from_millis(50)),
        )?;

        // Watch directory containing the script to catch atomics/swaps from text editors
        if let Some(parent) = path.parent() {
            watcher.watch(parent, RecursiveMode::NonRecursive)?;
            info!("Hot-reload watcher active on directory: {}", parent.display());
        } else {
            watcher.watch(path, RecursiveMode::NonRecursive)?;
            info!("Hot-reload watcher active on file: {}", path.display());
        }

        Some(watcher)
    } else {
        None
    };

    // Spawn 1-second ticker thread for clock & hardware telemetry updates
    let ticker_sender = reload_sender.clone();
    let ticker_path = script_path.clone();
    std::thread::spawn(move || {
        loop {
            std::thread::sleep(Duration::from_secs(1));
            if let Some(ref path) = ticker_path {
                if let Ok(code) = fs::read_to_string(path) {
                    let _ = ticker_sender.send(code);
                }
            }
        }
    });

    info!("Wayland connection established. Entering unified event loop...");

    while app.running {
        event_loop.dispatch(None, &mut app)?;
    }

    if sock_path.exists() {
        let _ = fs::remove_file(&sock_path);
    }

    info!("Zenith Desktop Shell exited cleanly.");
    Ok(())
}

fn read_self_memory() -> (f64, f64) {
    let mut vmrss_mb = 0.0;
    if let Ok(status) = fs::read_to_string("/proc/self/status") {
        for line in status.lines() {
            if line.starts_with("VmRSS:") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    if let Ok(kb) = parts[1].parse::<f64>() {
                        vmrss_mb = kb / 1024.0;
                    }
                }
            }
        }
    }

    let mut heap_mb = 0.0;
    if let Ok(statm) = fs::read_to_string("/proc/self/statm") {
        let parts: Vec<&str> = statm.split_whitespace().collect();
        if parts.len() >= 6 {
            if let Ok(pages) = parts[5].parse::<f64>() {
                heap_mb = (pages * 4096.0) / (1024.0 * 1024.0);
            }
        }
    }

    (vmrss_mb, heap_mb)
}

fn dirs_config_path() -> Option<PathBuf> {
    std::env::var("HOME").ok().map(|h| {
        PathBuf::from(h).join(".config/zenith/bar.luau")
    })
}
