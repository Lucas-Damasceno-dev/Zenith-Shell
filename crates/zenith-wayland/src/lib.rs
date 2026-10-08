//! Zenith Wayland - Protocol bindings and layer-shell integration.

use smithay_client_toolkit::{
    compositor::CompositorState,
    output::OutputState,
    registry::RegistryState,
    shell::wlr_layer::LayerShell,
};

/// Foundational state for Wayland connection and registries.
pub struct WaylandState {
    pub registry_state: RegistryState,
    pub output_state: OutputState,
    pub compositor_state: CompositorState,
    pub layer_shell: LayerShell,
    pub running: bool,
}

impl WaylandState {
    /// Create initial state after connecting and discovering globals.
    pub fn new(
        registry_state: RegistryState,
        output_state: OutputState,
        compositor_state: CompositorState,
        layer_shell: LayerShell,
    ) -> Self {
        Self {
            registry_state,
            output_state,
            compositor_state,
            layer_shell,
            running: true,
        }
    }
}
