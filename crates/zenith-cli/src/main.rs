//! Zenith Desktop Shell CLI & Entrypoint with Sub-ms Hot-Reload.

use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;

use calloop::EventLoop;
use calloop_wayland_source::WaylandSource;
use notify::{Config, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use tracing::{error, info};
use zenith_core::init_logging;
use zenith_wayland::WaylandApp;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    init_logging();
    info!("Starting Zenith Desktop Shell (Engine v2)...");

    let (mut app, conn, event_queue) = WaylandApp::init()?;

    // Locate Luau configuration file
    let local_cfg = Path::new("config/zenith/bar.luau");
    let home_cfg = dirs_config_path();

    let script_path = if local_cfg.exists() {
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

    // Create channel for hot-reload notifications
    let (reload_sender, reload_channel) = calloop::channel::channel::<String>();

    loop_handle.insert_source(reload_channel, |event, _, app: &mut WaylandApp| {
        if let calloop::channel::Event::Msg(code) = event {
            info!("Hot-reload event received! Recomputing Luau UI tree...");
            let start = std::time::Instant::now();
            if let Err(e) = app.reload_script(&code) {
                error!("Luau script error on hot-reload: {}", e);
            } else {
                let elapsed = start.elapsed();
                info!("Hot-reload applied in {:?}!", elapsed);
            }
        }
    })?;

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

    info!("Zenith Desktop Shell exited cleanly.");
    Ok(())
}

fn dirs_config_path() -> Option<PathBuf> {
    std::env::var("HOME").ok().map(|h| {
        PathBuf::from(h).join(".config/zenith/bar.luau")
    })
}
