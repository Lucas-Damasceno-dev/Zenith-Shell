//! Zenith Desktop Shell CLI & Entrypoint.

use tracing::info;
use zenith_core::init_logging;
use zenith_wayland::WaylandApp;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    init_logging();
    info!("Starting Zenith Desktop Shell (Engine v2)...");

    let (mut app, _conn, mut event_queue) = WaylandApp::init()?;
    info!("Wayland connection established. Entering event loop...");

    while app.running {
        event_queue.blocking_dispatch(&mut app)?;
    }

    info!("Zenith Desktop Shell exited cleanly.");
    Ok(())
}
