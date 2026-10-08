//! Zenith Desktop Shell CLI & Entrypoint.

use tracing::info;
use zenith_core::init_logging;

fn main() {
    init_logging();
    info!("Starting Zenith Desktop Shell (Engine v2)...");
    info!("Wayland & Luau runtime initialization placeholder");
}
