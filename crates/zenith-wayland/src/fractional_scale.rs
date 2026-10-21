//! Fractional Scaling and Viewport Management (wp_fractional_scale_v1 & wp_viewport).
//!
//! Eliminates linear blur on fractional HiDPI scaling displays (e.g., 1.25x, 1.5x, 1.75x)
//! by decoupling buffer pixel dimensions from logical surface geometry using Wayland Viewporter.

use wayland_client::protocol::wl_surface::WlSurface;
use wayland_client::{Dispatch, Proxy, QueueHandle};
use wayland_protocols::wp::fractional_scale::v1::client::wp_fractional_scale_manager_v1::WpFractionalScaleManagerV1;
use wayland_protocols::wp::fractional_scale::v1::client::wp_fractional_scale_v1::WpFractionalScaleV1;
use wayland_protocols::wp::viewporter::client::wp_viewport::WpViewport;
use wayland_protocols::wp::viewporter::client::wp_viewporter::WpViewporter;

/// Surface attachment tracking fractional scale and destination viewport.
#[derive(Debug)]
pub struct SurfaceScaleTracker {
    pub surface_id: u32,
    pub fractional_scale: Option<WpFractionalScaleV1>,
    pub viewport: Option<WpViewport>,
    pub scale_factor: f32,
}

impl SurfaceScaleTracker {
    pub fn new(surface_id: u32) -> Self {
        Self {
            surface_id,
            fractional_scale: None,
            viewport: None,
            scale_factor: 1.0,
        }
    }

    /// Sets the destination viewport in logical coordinates to preserve crisp geometry.
    pub fn apply_destination(&self, logical_w: i32, logical_h: i32) {
        if let Some(ref vp) = self.viewport {
            vp.set_destination(logical_w, logical_h);
        }
    }

    /// Computes the physical pixel dimensions for a given logical size according to scale factor.
    pub fn physical_size(&self, logical_w: u32, logical_h: u32) -> (u32, u32) {
        let phys_w = ((logical_w as f32) * self.scale_factor).round() as u32;
        let phys_h = ((logical_h as f32) * self.scale_factor).round() as u32;
        (phys_w.max(1), phys_h.max(1))
    }
}

impl Drop for SurfaceScaleTracker {
    fn drop(&mut self) {
        if let Some(fs) = self.fractional_scale.take() {
            fs.destroy();
        }
        if let Some(vp) = self.viewport.take() {
            vp.destroy();
        }
    }
}

/// Global manager binding fractional scaling and viewporter protocols.
pub struct FractionalScaleManager {
    pub manager: Option<WpFractionalScaleManagerV1>,
    pub viewporter: Option<WpViewporter>,
}

impl FractionalScaleManager {
    pub fn new() -> Self {
        Self {
            manager: None,
            viewporter: None,
        }
    }

    /// Attaches fractional scale listener and viewport to a target Wayland surface.
    pub fn attach_surface<D>(
        &self,
        qh: &QueueHandle<D>,
        surface: &WlSurface,
    ) -> SurfaceScaleTracker
    where
        D: Dispatch<WpFractionalScaleV1, SurfaceData> + Dispatch<WpViewport, ()> + 'static,
    {
        let surface_id = surface.id().protocol_id();
        let mut tracker = SurfaceScaleTracker::new(surface_id);

        if let Some(ref mgr) = self.manager {
            let frac = mgr.get_fractional_scale(surface, qh, SurfaceData { surface_id });
            tracker.fractional_scale = Some(frac);
        }

        if let Some(ref vp) = self.viewporter {
            let viewport = vp.get_viewport(surface, qh, ());
            tracker.viewport = Some(viewport);
        }

        tracker
    }
}

impl Default for FractionalScaleManager {
    fn default() -> Self {
        Self::new()
    }
}

/// User data attached to fractional scale events.
#[derive(Debug, Clone, Copy)]
pub struct SurfaceData {
    pub surface_id: u32,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_surface_scale_tracker_default() {
        let tracker = SurfaceScaleTracker::new(42);
        assert_eq!(tracker.surface_id, 42);
        assert_eq!(tracker.scale_factor, 1.0);
        assert_eq!(tracker.physical_size(1920, 1080), (1920, 1080));
    }

    #[test]
    fn test_surface_scale_tracker_fractional() {
        let mut tracker = SurfaceScaleTracker::new(10);
        tracker.scale_factor = 1.25;
        assert_eq!(tracker.physical_size(1920, 32), (2400, 40));

        tracker.scale_factor = 1.5;
        assert_eq!(tracker.physical_size(100, 50), (150, 75));
    }
}
