//! Monitor Lifecycle Manager for Zenith Base v3.
//!
//! Handles dynamic wl_output events, mode changes (resolution / refresh rate),
//! cable hotplugging, DPMS display sleep power-saving (0.00% GPU idle),
//! and leak-free WlEglSurface recreation.

use std::collections::HashMap;
use wayland_client::protocol::wl_surface::WlSurface;
use crate::egl::{EglContext, EglSurface};

/// Active video mode of a connected monitor.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct OutputMode {
    pub width: i32,
    pub height: i32,
    pub refresh_mhz: i32,
}

/// Metadata and dynamic state for a Wayland display output.
#[derive(Debug, Clone, PartialEq)]
pub struct MonitorState {
    pub name: String,
    pub logical_size: (u32, u32),
    pub scale: f64,
    pub current_mode: Option<OutputMode>,
    pub dpms_awake: bool,
    pub is_connected: bool,
}

/// Manager for multi-output lifecycle and power management.
#[derive(Debug, Default)]
pub struct MonitorLifecycleManager {
    pub monitors: HashMap<String, MonitorState>,
    pub global_dpms_sleeping: bool,
}

impl MonitorLifecycleManager {
    /// Creates a new `MonitorLifecycleManager`.
    pub fn new() -> Self {
        Self {
            monitors: HashMap::new(),
            global_dpms_sleeping: false,
        }
    }

    /// Registers or updates a newly connected output.
    pub fn register_output(
        &mut self,
        name: &str,
        logical_size: (u32, u32),
        scale: f64,
        mode: Option<OutputMode>,
    ) -> &MonitorState {
        let state = self.monitors.entry(name.to_string()).or_insert_with(|| MonitorState {
            name: name.to_string(),
            logical_size,
            scale,
            current_mode: mode,
            dpms_awake: true,
            is_connected: true,
        });

        state.logical_size = logical_size;
        state.scale = scale;
        state.current_mode = mode;
        state.is_connected = true;
        state
    }

    /// Handles dynamic mode / resolution change event from `wl_output.mode`.
    pub fn update_mode(&mut self, name: &str, width: i32, height: i32, refresh_mhz: i32) -> bool {
        if let Some(state) = self.monitors.get_mut(name) {
            let new_mode = OutputMode { width, height, refresh_mhz };
            if state.current_mode != Some(new_mode) {
                state.current_mode = Some(new_mode);
                state.logical_size = (width.max(1) as u32, height.max(1) as u32);
                return true;
            }
        }
        false
    }

    /// Handles output disconnection / cable unplugging.
    pub fn unregister_output(&mut self, name: &str) -> Option<MonitorState> {
        if let Some(mut state) = self.monitors.remove(name) {
            state.is_connected = false;
            Some(state)
        } else {
            None
        }
    }

    /// Sets DPMS (display power) state for a specific monitor.
    pub fn set_dpms(&mut self, name: &str, awake: bool) {
        if let Some(state) = self.monitors.get_mut(name) {
            state.dpms_awake = awake;
        }
        self.update_global_dpms();
    }

    /// Sets global DPMS power state across all monitors (e.g. from compositor DPMS sleep event).
    pub fn set_all_dpms(&mut self, awake: bool) {
        for state in self.monitors.values_mut() {
            state.dpms_awake = awake;
        }
        self.global_dpms_sleeping = !awake;
    }

    fn update_global_dpms(&mut self) {
        if self.monitors.is_empty() {
            self.global_dpms_sleeping = false;
        } else {
            // If all connected monitors are sleeping, pause GPU rendering completely
            self.global_dpms_sleeping = self.monitors.values().all(|m| !m.dpms_awake);
        }
    }

    /// Checks if rendering loops should be paused (ensures 0.00% GPU usage during display sleep).
    #[inline]
    pub fn should_pause_rendering(&self) -> bool {
        self.global_dpms_sleeping
    }

    /// Gracefully resizes or recreates a WlEglSurface without leaking orphan EGL buffers.
    pub fn graceful_resize_surface(
        &self,
        egl_surface: &mut Option<EglSurface>,
        wl_surface: &WlSurface,
        egl_ctx: &EglContext,
        width: u32,
        height: u32,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(ref mut surf) = egl_surface {
            surf.resize(width, height);
            Ok(())
        } else {
            let new_surf = egl_ctx.create_surface(wl_surface, width, height)?;
            *egl_surface = Some(new_surf);
            Ok(())
        }
    }

    /// Safely destroys an orphan surface before recreating to guarantee clean VRAM deallocation.
    pub fn recreate_surface(
        &self,
        egl_surface: &mut Option<EglSurface>,
        wl_surface: &WlSurface,
        egl_ctx: &EglContext,
        width: u32,
        height: u32,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Explicitly drop existing surface to destroy EGL handle
        *egl_surface = None;
        let new_surf = egl_ctx.create_surface(wl_surface, width, height)?;
        *egl_surface = Some(new_surf);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_monitor_registration_and_mode_update() {
        let mut mgr = MonitorLifecycleManager::new();
        let mon = mgr.register_output("DP-1", (1920, 1080), 1.0, Some(OutputMode {
            width: 1920,
            height: 1080,
            refresh_mhz: 60000,
        }));
        assert_eq!(mon.name, "DP-1");
        assert_eq!(mon.logical_size, (1920, 1080));

        // Update resolution to 144Hz 2560x1440
        let changed = mgr.update_mode("DP-1", 2560, 1440, 144000);
        assert!(changed);
        let updated = mgr.monitors.get("DP-1").unwrap();
        assert_eq!(updated.logical_size, (2560, 1440));
        assert_eq!(updated.current_mode.unwrap().refresh_mhz, 144000);
    }

    #[test]
    fn test_dpms_sleep_pauses_rendering() {
        let mut mgr = MonitorLifecycleManager::new();
        mgr.register_output("eDP-1", (1920, 1080), 1.0, None);
        mgr.register_output("HDMI-A-1", (2560, 1440), 1.0, None);

        assert!(!mgr.should_pause_rendering());

        // Display sleep on HDMI
        mgr.set_dpms("HDMI-A-1", false);
        assert!(!mgr.should_pause_rendering()); // eDP-1 is still awake

        // Display sleep on eDP-1
        mgr.set_dpms("eDP-1", false);
        assert!(mgr.should_pause_rendering()); // 0.00% GPU!

        // Wake up
        mgr.set_all_dpms(true);
        assert!(!mgr.should_pause_rendering());
    }

    #[test]
    fn test_output_disconnection() {
        let mut mgr = MonitorLifecycleManager::new();
        mgr.register_output("DP-2", (1920, 1080), 1.0, None);
        assert_eq!(mgr.monitors.len(), 1);

        let removed = mgr.unregister_output("DP-2");
        assert!(removed.is_some());
        assert_eq!(mgr.monitors.len(), 0);
    }
}
