//! Zenith Desktop Shell CLI & Entrypoint with Sub-ms Hot-Reload & IPC Control Socket.

use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use calloop::EventLoop;
use calloop_wayland_source::WaylandSource;
use notify::{Config, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use tracing::{error, info};
use zenith_core::init_logging;
use zenith_wayland::WaylandApp;
use zenith_cli::ShellCommand;

enum AppEvent {
    Reload(String),
    ReloadActiveTrees,
    Tick,
    StateChanged,
    DismissPopup,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    let subcmd = args.get(1).map(|s| s.as_str()).unwrap_or("daemon");
    let inspect_flag = args.iter().any(|a| a == "--inspect");

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
        "inspect:toggle" | "inspect-toggle" => send_socket_command("inspect:toggle"),
        "eval" => {
            let code = args[2..].join(" ");
            send_socket_command(&format!("eval {}", code))
        }
        "repl" => run_repl(),
        "sync" => send_socket_command("settings:sync"),
        "reset-defaults" => send_socket_command("settings:reset_defaults"),
        "bluetooth-toggle" => {
            let _ = zenith_services::BluetoothService::toggle_power();
            Ok(())
        }
        "wallpaper" => {
            let action = args.get(2).map(|s| s.as_str()).unwrap_or("pick");
            if action == "pick" {
                let script = std::env::var("HOME")
                    .map(|h| format!("{}/.config/hypr/scripts/random-wallpaper.sh", h))
                    .unwrap_or_else(|_| "config/hypr/scripts/random-wallpaper.sh".to_string());
                let _ = std::process::Command::new("bash").arg(script).arg("--next").status();
            }
            Ok(())
        }
        "theme" => {
            let action = args.get(2).map(|s| s.as_str()).unwrap_or("generate");
            if action == "generate" {
                let script = std::env::var("HOME")
                    .map(|h| format!("{}/.config/hypr/scripts/random-wallpaper.sh", h))
                    .unwrap_or_else(|_| "config/hypr/scripts/random-wallpaper.sh".to_string());
                let _ = std::process::Command::new("bash").arg(script).arg("--reload-colors").status();
            }
            Ok(())
        }
        "launcher" => {
            if args.get(2).map(|s| s.as_str()) == Some("filter") {
                if let Some(cat) = args.get(3) {
                    send_socket_command(&format!("settings:set launcher_category {}", cat))?;
                }
            }
            Ok(())
        }
        "help" | "--help" | "-h" => {
            print_help();
            Ok(())
        }
        "settings" | "config" => {
            let action = args.get(2).map(|s| s.as_str()).unwrap_or("list");
            match action {
                "get" => {
                    if let Some(key) = args.get(3) {
                        send_socket_command(&format!("settings:get {}", key))
                    } else {
                        eprintln!("Usage: zenith settings get <key>");
                        std::process::exit(1);
                    }
                }
                "set" => {
                    if let (Some(key), Some(val)) = (args.get(3), args.get(4)) {
                        send_socket_command(&format!("settings:set {} {}", key, val))
                    } else {
                        eprintln!("Usage: zenith settings set <key> <val>");
                        std::process::exit(1);
                    }
                }
                "list" | "all" => send_socket_command("settings:list"),
                "sync" => send_socket_command("settings:sync"),
                "reload" => send_socket_command("settings:reload"),
                "reset-defaults" | "reset_defaults" => send_socket_command("settings:reset_defaults"),
                _ => {
                    eprintln!("Unknown settings action: '{}'. Valid actions: get, set, list, sync, reload.", action);
                    std::process::exit(1);
                }
            }
        }
        "daemon" | "run" => {
            let custom_cfg = args.iter().skip(2).find(|a| !a.starts_with("--")).map(PathBuf::from);
            run_daemon(custom_cfg, inspect_flag)
        }
        _ => {
            let p = PathBuf::from(subcmd);
            if p.exists() || p.extension().and_then(|s| s.to_str()) == Some("luau") {
                run_daemon(Some(p), inspect_flag)
            } else {
                eprintln!("Unknown command: '{}'. Run 'zenith help' for usage.", subcmd);
                std::process::exit(1);
            }
        }
    }
}

fn print_help() {
    println!("Zenith-Shell (Engine Base v3) — Wayland Desktop Shell Framework");
    println!();
    println!("USAGE:");
    println!("    zenith [COMMAND] [OPTIONS]");
    println!();
    println!("COMMANDS:");
    println!("    daemon [path] [--inspect] Run shell daemon (default: config/zenith/bar.luau)");
    println!("    reload                    Trigger sub-10ms hot-reload of active Luau configuration");
    println!("    toggle <popup_id>         Toggle an overlay popup (e.g. Launcher, AudioPopup)");
    println!("    open <popup_id>           Open specified overlay popup");
    println!("    close                     Close currently open overlay popup");
    println!("    lock                      Activate screen locker overlay");
    println!("    inspect                   Display live shell telemetry (RSS, heap, popups)");
    println!("    inspect:toggle            Toggle on-screen visual bounding box overlays");
    println!("    settings get <key>        Get configuration setting value via IPC");
    println!("    settings set <key> <val>  Set configuration setting and persist atomically");
    println!("    settings list             List all configuration key-values as JSON");
    println!("    settings sync             Flush and persist all settings to config.json");
    println!("    settings reload           Reload settings from config.json into live state");
    println!("    eval <code>               Evaluate arbitrary Luau expression via daemon");
    println!("    repl                      Start interactive live Luau shell session");
    println!("    help                      Show this help message");
}

fn resolve_socket_path() -> PathBuf {
    zenith_cli::resolve_socket_path()
}

fn send_socket_command(cmd: &str) -> Result<(), Box<dyn std::error::Error>> {
    let sock_path = resolve_socket_path();
    match zenith_cli::send_socket_command_to(&sock_path, cmd) {
        Ok(resp) => {
            if !resp.is_empty() {
                println!("{}", resp);
            }
            Ok(())
        }
        Err(e) => {
            eprintln!("{}", e);
            std::process::exit(1);
        }
    }
}

fn run_daemon(custom_path: Option<PathBuf>, inspect_mode: bool) -> Result<(), Box<dyn std::error::Error>> {
    init_logging();
    info!("Starting Zenith Desktop Shell (Engine Base v3)...");

    let (mut app, conn, event_queue) = WaylandApp::init()?;
    if inspect_mode {
        app.set_inspect_mode(true);
        info!("Inspect mode enabled: Taffy bounding box overlays active");
    }

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

    // Auto-launch Dock if enabled in configuration
    let dock_enabled = app.runtime.storage.get("dockEnabled")
        .and_then(|v| v.as_bool())
        .unwrap_or(true);

    if dock_enabled {
        info!("Dock enabled in configuration, launching dock overlay...");
        let _ = app.open_dock();
    }

    // Set up calloop event loop
    let mut event_loop: EventLoop<WaylandApp> = EventLoop::try_new()?;
    let loop_handle = event_loop.handle();

    // Attach Wayland event source to calloop
    WaylandSource::new(conn, event_queue).insert(loop_handle.clone())?;

    // Create channel for UI lifecycle notifications (reload vs redraw)
    let (event_sender, event_channel) = calloop::channel::channel::<AppEvent>();
    let needs_redraw = Arc::new(AtomicBool::new(false));
    let needs_redraw_cb = needs_redraw.clone();

    loop_handle.insert_source(event_channel, move |event, _, app: &mut WaylandApp| {
        if let calloop::channel::Event::Msg(app_evt) = event {
            match app_evt {
                AppEvent::Reload(code) => {
                    info!("Hot-reload triggered, recomputing Luau UI tree...");
                    let start = std::time::Instant::now();
                    if let Err(e) = app.reload_script(&code) {
                        error!("Luau script error on hot-reload: {}", e);
                    } else {
                        app.sync_autohide_settings();
                        let _ = app.update_bar_visibility();
                        let _ = app.update_dock_visibility();
                        let elapsed = start.elapsed();
                        info!("Hot-reload successfully applied in {:?}!", elapsed);
                        needs_redraw_cb.store(true, Ordering::Release);
                    }
                }
                AppEvent::ReloadActiveTrees => {
                    info!("Hot-reload triggered for module/overlay, refreshing Luau module cache and active trees...");
                    let start = std::time::Instant::now();
                    app.sync_autohide_settings();
                    let _ = app.update_bar_visibility();
                    let _ = app.update_dock_visibility();
                    app.reload_active_trees();
                    let elapsed = start.elapsed();
                    info!("Active trees and Luau module cache reloaded in {:?}!", elapsed);
                    needs_redraw_cb.store(true, Ordering::Release);
                }
                AppEvent::Tick => {
                    app.runtime.update_system_signals();
                    app.sync_autohide_settings();
                    let prev_bar_hidden = app.bar_hidden;
                    let prev_dock_hidden = app.dock_hidden;
                    if app.bar_last_leave.is_none() {
                        let _ = app.update_bar_visibility();
                    }
                    if app.dock_last_leave.is_none() {
                        let _ = app.update_dock_visibility();
                    }
                    let visibility_changed = prev_bar_hidden != app.bar_hidden || prev_dock_hidden != app.dock_hidden;
                    let has_visible = !app.bar_hidden || !app.dock_hidden || app.popup.is_some();
                    if (has_visible || visibility_changed) && !app.runtime.is_idle() {
                        needs_redraw_cb.store(true, Ordering::Release);
                    }
                }
                AppEvent::StateChanged => {
                    let script = app.bar_script.clone();
                    let _ = app.reload_script(&script);
                    if !app.dock_hidden {
                        let _ = app.reload_dock();
                    }
                    needs_redraw_cb.store(true, Ordering::Release);
                    let _ = app.request_redraw();
                }
                AppEvent::DismissPopup => {
                    if let Some(ref popup) = app.popup {
                        if !popup.id.eq_ignore_ascii_case("lock") && !popup.id.eq_ignore_ascii_case("lockscreen") {
                            app.close_popup();
                        }
                    }
                    if app.bar_last_leave.is_none() {
                        let _ = app.update_bar_visibility();
                    }
                    if app.dock_last_leave.is_none() {
                        let _ = app.update_dock_visibility();
                    }
                    needs_redraw_cb.store(true, Ordering::Release);
                }
            }
        }
    })?;

    // Create channel for IPC socket commands (toggle, open, close)
    let (cmd_sender, cmd_channel) = calloop::channel::channel::<ShellCommand>();

    let cmd_event_sender = event_sender.clone();
    let cmd_script_path = script_path.clone();
    let cmd_needs_redraw = needs_redraw.clone();

    loop_handle.insert_source(cmd_channel, move |event, _, app: &mut WaylandApp| {
        if let calloop::channel::Event::Msg(cmd) = event {
            match cmd {
                ShellCommand::Reload => {
                    if let Some(ref path) = cmd_script_path {
                        if let Ok(code) = fs::read_to_string(path) {
                            let _ = cmd_event_sender.send(AppEvent::Reload(code));
                        }
                    }
                }
                ShellCommand::Toggle(id) => {
                    info!("IPC command: toggle popup/mode '{}'", id);
                    if id == "bar:autohide" {
                        app.execute_action("bar:toggle_autohide");
                    } else if id == "dock:autohide" {
                        app.execute_action("dock:toggle_autohide");
                    } else {
                        app.toggle_popup(&id);
                    }
                    cmd_needs_redraw.store(true, Ordering::Release);
                    let _ = app.request_redraw();
                }
                ShellCommand::Open(id) => {
                    info!("IPC command: open popup '{}'", id);
                    let _ = app.open_popup(&id);
                    cmd_needs_redraw.store(true, Ordering::Release);
                    let _ = app.request_redraw();
                }
                ShellCommand::Close => {
                    info!("IPC command: close popup");
                    app.close_popup();
                    cmd_needs_redraw.store(true, Ordering::Release);
                    let _ = app.request_redraw();
                }
                ShellCommand::ToggleInspect => {
                    let current = app.inspect_mode;
                    app.set_inspect_mode(!current);
                    info!("Toggled visual inspector mode to: {}", !current);
                    let _ = app.request_redraw();
                }
                ShellCommand::Eval(code, tx) => {
                    let res = match app.eval_code(&code) {
                        Ok(v) => format!("OK: {}\n", v),
                        Err(e) => format!("ERR: {}\n", e),
                    };
                    let _ = tx.send(res);
                }
                ShellCommand::SettingsGet(key, tx) => {
                    let resp = match app.runtime.storage.get(&key) {
                        Some(val) => format!("OK: {}\n", val),
                        None => format!("ERR: setting '{}' not found\n", key),
                    };
                    let _ = tx.send(resp);
                }
                ShellCommand::SettingsSet(key, val_str, tx) => {
                    let json_val = if val_str == "true" {
                        serde_json::Value::Bool(true)
                    } else if val_str == "false" {
                        serde_json::Value::Bool(false)
                    } else if let Ok(num) = val_str.parse::<i64>() {
                        serde_json::Value::from(num)
                    } else if let Ok(num) = val_str.parse::<f64>() {
                        if (num - num.round()).abs() < 1e-4 {
                            serde_json::Value::from(num.round() as i64)
                        } else {
                            serde_json::Number::from_f64(num).map(serde_json::Value::Number).unwrap_or(serde_json::Value::Null)
                        }
                    } else if (val_str.starts_with('{') && val_str.ends_with('}'))
                        || (val_str.starts_with('[') && val_str.ends_with(']'))
                    {
                        serde_json::from_str::<serde_json::Value>(&val_str).unwrap_or(serde_json::Value::String(val_str.clone()))
                    } else {
                        serde_json::Value::String(val_str.clone())
                    };

                    let res = match app.runtime.storage.set(&key, json_val.clone()) {
                        Ok(_) => {
                            app.sync_autohide_settings();
                            let _ = app.update_bar_visibility();
                            let _ = app.update_dock_visibility();
                            app.reload_active_trees();
                            cmd_needs_redraw.store(true, Ordering::Release);
                            let _ = app.request_redraw();
                            format!("OK: setting '{}' set to {}\n", key, json_val)
                        }
                        Err(e) => format!("ERR: failed to persist setting '{}': {}\n", key, e),
                    };
                    let _ = tx.send(res);
                }
                ShellCommand::SettingsList(tx) => {
                    let all_map = app.runtime.storage.all();
                    let resp = match serde_json::to_string_pretty(&all_map) {
                        Ok(json_str) => format!("OK: {}\n", json_str),
                        Err(_) => "ERR: failed to serialize settings\n".to_string(),
                    };
                    let _ = tx.send(resp);
                }
                ShellCommand::SettingsSync(tx) => {
                    let resp = match app.runtime.storage.sync_to_config() {
                        Ok(_) => "OK: settings synced to config.json\n".to_string(),
                        Err(e) => format!("ERR: failed to sync settings: {}\n", e),
                    };
                    let _ = tx.send(resp);
                }
                ShellCommand::SettingsReload(tx) => {
                    let resp = match app.runtime.storage.reload_from_config() {
                        Ok(_) => {
                            app.sync_autohide_settings();
                            let _ = app.update_bar_visibility();
                            let _ = app.update_dock_visibility();
                            app.reload_active_trees();
                            cmd_needs_redraw.store(true, Ordering::Release);
                            let _ = app.request_redraw();
                            "OK: settings reloaded from config.json and UI updated\n".to_string()
                        }
                        Err(e) => format!("ERR: failed to reload settings: {}\n", e),
                    };
                    let _ = tx.send(resp);
                }
                ShellCommand::SettingsResetDefaults(tx) => {
                    let _ = app.runtime.storage.clear();
                    let _ = app.runtime.storage.sync_to_config();
                    let resp = match app.runtime.storage.reload_from_config() {
                        Ok(_) => {
                            app.sync_autohide_settings();
                            let _ = app.update_bar_visibility();
                            let _ = app.update_dock_visibility();
                            app.reload_active_trees();
                            cmd_needs_redraw.store(true, Ordering::Release);
                            let _ = app.request_redraw();
                            "OK: settings reset to defaults and UI updated\n".to_string()
                        }
                        Err(e) => format!("ERR: failed to reset settings: {}\n", e),
                    };
                    let _ = tx.send(resp);
                }
                ShellCommand::Lock => {
                    info!("IPC command: lock screen");
                    app.lock_session();
                    cmd_needs_redraw.store(true, Ordering::Release);
                    let _ = app.request_redraw();
                }
                ShellCommand::Inspect => {
                    info!("IPC command: inspect telemetry");
                }
            }
        }
    })?;

    // Bind UNIX domain control socket using hardened IPC server (0600 perms, SO_PEERCRED, 1s timeout, 64KB cap)
    let sock_path = resolve_socket_path();
    let socket_cmd_sender = cmd_sender.clone();
    let _ipc_handle = zenith_cli::start_ipc_server(sock_path.clone(), move |cmd| {
        let _ = socket_cmd_sender.send(cmd);
        None
    }).map_err(|e| -> Box<dyn std::error::Error> { e })?;

    // Hook Hyprland compositor IPC change listener for sub-10ms UI updates (zero disk I/O)
    let hypr_sender = event_sender.clone();
    zenith_services::HyprlandService::set_change_listener(move || {
        let _ = hypr_sender.send(AppEvent::StateChanged);
    });

    let dismiss_sender = event_sender.clone();
    zenith_services::HyprlandService::set_focus_change_listener(move || {
        let _ = dismiss_sender.send(AppEvent::DismissPopup);
    });

    // Hook Notification Daemon change listener for instant UI updates (zero disk I/O)
    let notif_sender = event_sender.clone();
    zenith_services::NotificationService::set_change_listener(move || {
        let _ = notif_sender.send(AppEvent::StateChanged);
    });

    // Hook Audio change listener for instant volume/mute UI updates (zero polling)
    let audio_sender = event_sender.clone();
    zenith_services::AudioService::set_change_listener(move || {
        let _ = audio_sender.send(AppEvent::StateChanged);
    });

    // Hook MPRIS media change listener for instant track/playback UI updates
    let mpris_sender = event_sender.clone();
    zenith_services::MprisService::set_change_listener(move || {
        let _ = mpris_sender.send(AppEvent::StateChanged);
    });

    // Hook Theme change listener for instant theme updates (zero polling)
    let theme_sender = event_sender.clone();
    zenith_services::ThemeWatcher::set_change_listener(move || {
        let _ = theme_sender.send(AppEvent::ReloadActiveTrees);
    });

    // Hook worker pool completion ping to immediately dispatch async callbacks in calloop
    let (worker_ping, worker_ping_source) = calloop::ping::make_ping()?;
    let ping_needs_redraw = needs_redraw.clone();
    loop_handle.insert_source(worker_ping_source, move |(), _, app: &mut WaylandApp| {
        if let Ok(count) = app.poll_async_tasks() {
            if count > 0 {
                ping_needs_redraw.store(true, Ordering::Release);
                let _ = app.request_redraw();
            }
        }
    })?;
    app.runtime.set_worker_completion_notifier(Arc::new(move || {
        worker_ping.ping();
    }));

    // Integrated 1-second calloop timer for clock & hardware telemetry updates (zero wakeups when animations paused)
    let ticker_sender = event_sender.clone();
    let timer = calloop::timer::Timer::from_duration(Duration::from_secs(1));
    loop_handle.insert_source(timer, move |_deadline, _, app: &mut WaylandApp| {
        if !app.should_pause_animations() {
            let _ = ticker_sender.send(AppEvent::Tick);
        }
        calloop::timer::TimeoutAction::ToDuration(Duration::from_secs(1))
    })?;

    // Start background file watcher if config exists
    let _watcher = if let Some(ref path) = script_path {
        let watch_path = path.clone();
        let watcher_sender = event_sender.clone();

        let mut watcher = RecommendedWatcher::new(
            move |res: notify::Result<notify::Event>| {
                if let Ok(event) = res {
                    if matches!(event.kind, EventKind::Modify(_) | EventKind::Create(_)) {
                        // Prevent feedback loops with StorageEngine by ignoring config/storage files and temp rename files
                        let is_ephemeral_or_config = event.paths.iter().any(|p| {
                            let name = p.file_name().and_then(|n| n.to_str()).unwrap_or("");
                            name == "config.json"
                                || name == "storage.json"
                                || name.contains(".tmp.")
                                || name.ends_with(".tmp")
                        });
                        if is_ephemeral_or_config {
                            return;
                        }

                        let is_theme_change = event.paths.iter().any(|p| {
                            let name = p.file_name().and_then(|n| n.to_str()).unwrap_or("");
                            name == "colors.json" || name == "theme.json" || name == "palette.json"
                        });
                        if is_theme_change {
                            zenith_services::SystemService::invalidate_theme_cache();
                            let _ = watcher_sender.send(AppEvent::ReloadActiveTrees);
                            return;
                        }

                        let is_main_script = event.paths.iter().any(|p| p == &watch_path);
                        let is_overlay_or_lib = event.paths.iter().any(|p| {
                            let s = p.to_string_lossy();
                            s.contains("overlays")
                                || s.contains("lib/widgets")
                                || s.contains("widgets")
                                || s.contains("lib")
                        });

                        if is_main_script {
                            if let Ok(code) = fs::read_to_string(&watch_path) {
                                let _ = watcher_sender.send(AppEvent::Reload(code));
                            }
                        } else if is_overlay_or_lib {
                            let _ = watcher_sender.send(AppEvent::ReloadActiveTrees);
                        } else {
                            let is_luau = event.paths.iter().any(|p| {
                                p.extension().and_then(|ext| ext.to_str()) == Some("luau")
                                    || p.extension().and_then(|ext| ext.to_str()) == Some("lua")
                            });
                            if is_luau {
                                let _ = watcher_sender.send(AppEvent::ReloadActiveTrees);
                            }
                        }
                    }
                }
            },
            Config::default().with_poll_interval(Duration::from_millis(50)),
        )?;

        // Watch directory containing the script to catch atomics/swaps from text editors and nested modules
        if let Some(parent) = path.parent() {
            watcher.watch(parent, RecursiveMode::Recursive)?;
            info!("Hot-reload watcher active on directory: {} (recursive)", parent.display());
        } else {
            watcher.watch(path, RecursiveMode::Recursive)?;
            info!("Hot-reload watcher active on file: {} (recursive)", path.display());
        }

        // Add native inotify watchers for theme directories without polling disk
        if let Ok(home) = std::env::var("HOME") {
            let matugen_cache = std::path::PathBuf::from(&home).join(".cache/matugen");
            if matugen_cache.exists() {
                let _ = watcher.watch(&matugen_cache, RecursiveMode::Recursive);
            }
            let zenith_config = std::path::PathBuf::from(&home).join(".config/zenith");
            if zenith_config.exists() && Some(zenith_config.as_path()) != path.parent() {
                let _ = watcher.watch(&zenith_config, RecursiveMode::Recursive);
            }
        }

        Some(watcher)
    } else {
        None
    };

    info!("Wayland connection established. Entering unified event loop...");

    let mut last_draw = std::time::Instant::now() - Duration::from_millis(100);

    while app.running {
        let autohide_delay = app.get_autohide_delay();
        let leave_timeout = [app.dock_last_leave, app.bar_last_leave]
            .into_iter()
            .flatten()
            .map(|t| autohide_delay.saturating_sub(t.elapsed()))
            .min();

        let any_frame_pending = app.bars.iter().any(|b| b.frame_callback_pending)
            || app.dock.as_ref().map(|d| d.frame_callback_pending).unwrap_or(false)
            || app.popup.as_ref().map(|p| p.frame_callback_pending).unwrap_or(false);

        let timeout = if needs_redraw.load(Ordering::Acquire) {
            if !any_frame_pending {
                Some(Duration::ZERO)
            } else {
                Some(Duration::from_millis(8))
            }
        } else if let Some(lt) = leave_timeout {
            Some(lt.max(Duration::from_millis(1)))
        } else if app.tooltip_hover.is_some() {
            Some(Duration::from_millis(50))
        } else {
            None
        };

        event_loop.dispatch(timeout, &mut app)?;

        if app.tooltip_hover.is_some() && app.check_tooltip_timer() {
            needs_redraw.store(true, Ordering::Release);
        }

        if app.runtime.check_close_requested() {
            app.close_popup();
            needs_redraw.store(true, Ordering::Release);
        }

        // Handle dock auto-hide debounce timer when cursor leaves dock
        if let Some(leave_time) = app.dock_last_leave {
            if leave_time.elapsed() >= autohide_delay {
                app.dock_last_leave = None;
                if let Err(e) = app.update_dock_visibility() {
                    error!("Failed to update dock auto-hide visibility: {}", e);
                }
                needs_redraw.store(true, Ordering::Release);
            }
        }

        // Handle bar auto-hide debounce timer when cursor leaves bar
        if let Some(leave_time) = app.bar_last_leave {
            if leave_time.elapsed() >= autohide_delay {
                app.bar_last_leave = None;
                if let Err(e) = app.update_bar_visibility() {
                    error!("Failed to update bar auto-hide visibility: {}", e);
                }
                needs_redraw.store(true, Ordering::Release);
            }
        }

        if needs_redraw.load(Ordering::Acquire) && (!any_frame_pending || last_draw.elapsed() >= Duration::from_millis(8)) {
            needs_redraw.store(false, Ordering::Release);
            last_draw = std::time::Instant::now();
            if let Err(e) = app.request_redraw() {
                error!("Failed to redraw surfaces: {}", e);
            }
        }
    }

    if sock_path.exists() {
        let _ = fs::remove_file(&sock_path);
    }

    info!("Zenith Desktop Shell exited cleanly.");
    Ok(())
}

fn dirs_config_path() -> Option<PathBuf> {
    std::env::var("HOME").ok().map(|h| {
        PathBuf::from(h).join(".config/zenith/bar.luau")
    })
}

fn run_repl() -> Result<(), Box<dyn std::error::Error>> {
    let sock_path = resolve_socket_path();
    if !sock_path.exists() {
        eprintln!(
            "Error: Zenith daemon is not running (socket not found at {}).",
            sock_path.display()
        );
        std::process::exit(1);
    }

    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  🌟 Zenith Live REPL (Engine Base v3)                    ║");
    println!("║  Interactive Luau shell connected to active daemon       ║");
    println!("║  Commands: Zenith.Storage.all(), toggle <id>, quit      ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();

    let stdin = std::io::stdin();
    loop {
        print!("zenith> ");
        std::io::stdout().flush()?;

        let mut line = String::new();
        if stdin.read_line(&mut line)? == 0 {
            break;
        }

        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        if trimmed == "exit" || trimmed == "quit" {
            println!("Goodbye!");
            break;
        }

        let cmd_to_send = if trimmed.starts_with("toggle ")
            || trimmed.starts_with("open ")
            || trimmed == "close"
            || trimmed == "reload"
            || trimmed == "inspect"
            || trimmed == "inspect:toggle"
            || trimmed.starts_with("eval ")
            || trimmed.starts_with("settings:")
        {
            trimmed.to_string()
        } else if let Some(stripped) = trimmed.strip_prefix("settings ") {
            let parts: Vec<&str> = stripped.trim().split_whitespace().collect();
            match parts.as_slice() {
                ["get", key] => format!("settings:get {}", key),
                ["set", key, val] => format!("settings:set {} {}", key, val),
                ["list"] | ["all"] => "settings:list".to_string(),
                ["sync"] => "settings:sync".to_string(),
                ["reload"] => "settings:reload".to_string(),
                _ => format!("eval {}", trimmed),
            }
        } else {
            format!("eval {}", trimmed)
        };

        let mut stream = match UnixStream::connect(&sock_path) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("Lost connection to Zenith daemon: {}", e);
                break;
            }
        };

        stream.set_read_timeout(Some(Duration::from_secs(5)))?;
        stream.write_all(format!("{}\n", cmd_to_send).as_bytes())?;

        let mut reader = BufReader::new(stream);
        let mut response = String::new();
        while let Ok(n) = reader.read_line(&mut response) {
            if n == 0 { break; }
        }

        let trimmed_resp = response.trim();
        if let Some(ok_res) = trimmed_resp.strip_prefix("OK: ") {
            println!("{}", ok_res);
        } else if let Some(err_res) = trimmed_resp.strip_prefix("ERR: ") {
            eprintln!("Error: {}", err_res);
        } else if !trimmed_resp.is_empty() {
            println!("{}", trimmed_resp);
        }
    }

    Ok(())
}
