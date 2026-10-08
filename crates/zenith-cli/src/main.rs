//! Zenith Desktop Shell CLI & Entrypoint.

use std::fs;
use std::path::Path;
use tracing::info;
use zenith_core::init_logging;
use zenith_wayland::WaylandApp;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    init_logging();
    info!("Starting Zenith Desktop Shell (Engine v2)...");

    let (mut app, _conn, mut event_queue) = WaylandApp::init()?;

    // Load custom config from local repo or user home if available
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

    if let Some(path) = script_path {
        info!("Loading Luau config from: {}", path.display());
        if let Ok(code) = fs::read_to_string(&path) {
            if let Err(e) = app.reload_script(&code) {
                tracing::error!("Failed to execute Luau script {}: {}", path.display(), e);
            }
        }
    }

    info!("Wayland connection established. Entering event loop...");

    while app.running {
        event_queue.blocking_dispatch(&mut app)?;
    }

    info!("Zenith Desktop Shell exited cleanly.");
    Ok(())
}

fn dirs_config_path() -> Option<std::path::PathBuf> {
    std::env::var("HOME").ok().map(|h| {
        std::path::PathBuf::from(h).join(".config/zenith/bar.luau")
    })
}
