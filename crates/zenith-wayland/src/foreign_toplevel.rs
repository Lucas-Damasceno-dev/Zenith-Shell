//! Foreign Toplevel Management Protocol (`zwlr_foreign_toplevel_management_v1`).
//!
//! Provides a compositor-agnostic interface for discovering, tracking, and controlling
//! toplevel application windows across Wayland compositors (Hyprland, Sway, River,
//! Labwc, Niri, Wayfire, and Cosmic).

use std::collections::HashMap;
use std::sync::{OnceLock, RwLock};
use tracing::debug;
use wayland_client::protocol::{wl_output::WlOutput, wl_seat::WlSeat};
use wayland_protocols_wlr::foreign_toplevel::v1::client::{
    zwlr_foreign_toplevel_handle_v1::{self, ZwlrForeignToplevelHandleV1},
    zwlr_foreign_toplevel_manager_v1::ZwlrForeignToplevelManagerV1,
};
pub use zenith_services::{ToplevelAction, ToplevelInfo as ForeignToplevelInfo, ToplevelService};

/// Internal tracked state for an individual toplevel window handle.
#[derive(Debug)]
pub struct ForeignToplevelData {
    pub id: u32,
    pub handle: ZwlrForeignToplevelHandleV1,
    pub title: String,
    pub app_id: String,
    pub maximized: bool,
    pub minimized: bool,
    pub activated: bool,
    pub fullscreen: bool,
    pub pending_title: Option<String>,
    pub pending_app_id: Option<String>,
    pub pending_maximized: Option<bool>,
    pub pending_minimized: Option<bool>,
    pub pending_activated: Option<bool>,
    pub pending_fullscreen: Option<bool>,
}

impl ForeignToplevelData {
    pub fn new(id: u32, handle: ZwlrForeignToplevelHandleV1) -> Self {
        Self {
            id,
            handle,
            title: String::new(),
            app_id: String::new(),
            maximized: false,
            minimized: false,
            activated: false,
            fullscreen: false,
            pending_title: None,
            pending_app_id: None,
            pending_maximized: None,
            pending_minimized: None,
            pending_activated: None,
            pending_fullscreen: None,
        }
    }

    /// Commits double-buffered pending state sent by compositor upon `done` event.
    pub fn apply_done(&mut self) {
        if let Some(t) = self.pending_title.take() {
            self.title = t;
        }
        if let Some(a) = self.pending_app_id.take() {
            self.app_id = a;
        }
        if let Some(m) = self.pending_maximized.take() {
            self.maximized = m;
        }
        if let Some(m) = self.pending_minimized.take() {
            self.minimized = m;
        }
        if let Some(a) = self.pending_activated.take() {
            self.activated = a;
        }
        if let Some(f) = self.pending_fullscreen.take() {
            self.fullscreen = f;
        }
    }

    pub fn snapshot(&self) -> ForeignToplevelInfo {
        ForeignToplevelInfo {
            id: self.id,
            title: self.title.clone(),
            app_id: self.app_id.clone(),
            maximized: self.maximized,
            minimized: self.minimized,
            activated: self.activated,
            fullscreen: self.fullscreen,
        }
    }
}

/// Global cache allowing lock-free zero-subprocess inspection from Luau and services.
static GLOBAL_TOPLEVEL_CACHE: OnceLock<RwLock<Vec<ForeignToplevelInfo>>> = OnceLock::new();

/// Returns a thread-safe snapshot of all currently active Wayland foreign toplevel windows.
pub fn global_foreign_toplevels_snapshot() -> Vec<ForeignToplevelInfo> {
    GLOBAL_TOPLEVEL_CACHE
        .get_or_init(|| RwLock::new(Vec::new()))
        .read()
        .map(|r| r.clone())
        .unwrap_or_default()
}

/// Updates the global cache with current toplevel snapshot.
fn update_global_cache(toplevels: Vec<ForeignToplevelInfo>) {
    if let Ok(mut lock) = GLOBAL_TOPLEVEL_CACHE
        .get_or_init(|| RwLock::new(Vec::new()))
        .write()
    {
        *lock = toplevels;
    }
}

/// Universal Wayland foreign toplevel manager.
#[derive(Debug, Default)]
pub struct ForeignToplevelManager {
    pub manager: Option<ZwlrForeignToplevelManagerV1>,
    pub toplevels: HashMap<u32, ForeignToplevelData>,
}

impl ForeignToplevelManager {
    pub fn new() -> Self {
        Self {
            manager: None,
            toplevels: HashMap::new(),
        }
    }

    /// Registers a newly announced toplevel from `zwlr_foreign_toplevel_manager_v1::toplevel`.
    pub fn register_toplevel(&mut self, id: u32, handle: ZwlrForeignToplevelHandleV1) {
        debug!("Foreign toplevel discovered: id={}", id);
        self.toplevels.insert(id, ForeignToplevelData::new(id, handle));
        self.sync_cache();
    }

    /// Removes a closed toplevel window.
    pub fn unregister_toplevel(&mut self, id: u32) {
        debug!("Foreign toplevel closed: id={}", id);
        self.toplevels.remove(&id);
        self.sync_cache();
    }

    /// Handles events from `ZwlrForeignToplevelHandleV1`.
    pub fn handle_toplevel_event(&mut self, id: u32, event: zwlr_foreign_toplevel_handle_v1::Event) {
        let Some(toplevel) = self.toplevels.get_mut(&id) else {
            return;
        };

        match event {
            zwlr_foreign_toplevel_handle_v1::Event::Title { title } => {
                toplevel.pending_title = Some(title);
            }
            zwlr_foreign_toplevel_handle_v1::Event::AppId { app_id } => {
                toplevel.pending_app_id = Some(app_id);
            }
            zwlr_foreign_toplevel_handle_v1::Event::State { state } => {
                let mut max = false;
                let mut min = false;
                let mut act = false;
                let mut full = false;

                // State array contains serialized u32 enum entries:
                // 0 = Maximized, 1 = Minimized, 2 = Activated, 3 = Fullscreen
                for chunk in state.chunks_exact(4) {
                    let val = u32::from_ne_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
                    match val {
                        0 => max = true,
                        1 => min = true,
                        2 => act = true,
                        3 => full = true,
                        _ => {}
                    }
                }

                toplevel.pending_maximized = Some(max);
                toplevel.pending_minimized = Some(min);
                toplevel.pending_activated = Some(act);
                toplevel.pending_fullscreen = Some(full);
            }
            zwlr_foreign_toplevel_handle_v1::Event::Done => {
                toplevel.apply_done();
                self.sync_cache();
            }
            zwlr_foreign_toplevel_handle_v1::Event::Closed => {
                self.toplevels.remove(&id);
                self.sync_cache();
            }
            _ => {}
        }
    }

    /// Synchronizes internal toplevel list to the global thread-safe snapshot.
    pub fn sync_cache(&self) {
        let snapshot = self.snapshot();
        update_global_cache(snapshot.clone());
        ToplevelService::update_toplevels(snapshot);
    }

    /// Returns a snapshot of all active toplevel windows.
    pub fn snapshot(&self) -> Vec<ForeignToplevelInfo> {
        self.toplevels.values().map(|t| t.snapshot()).collect()
    }

    /// Requests the compositor to activate (focus) a toplevel window.
    pub fn activate(&self, id: u32, seat: &WlSeat) {
        if let Some(t) = self.toplevels.get(&id) {
            t.handle.activate(seat);
        }
    }

    /// Requests the compositor to maximize a toplevel window.
    pub fn set_maximized(&self, id: u32) {
        if let Some(t) = self.toplevels.get(&id) {
            t.handle.set_maximized();
        }
    }

    /// Requests the compositor to unmaximize a toplevel window.
    pub fn unset_maximized(&self, id: u32) {
        if let Some(t) = self.toplevels.get(&id) {
            t.handle.unset_maximized();
        }
    }

    /// Requests the compositor to minimize a toplevel window.
    pub fn set_minimized(&self, id: u32) {
        if let Some(t) = self.toplevels.get(&id) {
            t.handle.set_minimized();
        }
    }

    /// Requests the compositor to unminimize a toplevel window.
    pub fn unset_minimized(&self, id: u32) {
        if let Some(t) = self.toplevels.get(&id) {
            t.handle.unset_minimized();
        }
    }

    /// Requests the compositor to set fullscreen state.
    pub fn set_fullscreen(&self, id: u32, output: Option<&WlOutput>) {
        if let Some(t) = self.toplevels.get(&id) {
            t.handle.set_fullscreen(output);
        }
    }

    /// Requests the compositor to unset fullscreen state.
    pub fn unset_fullscreen(&self, id: u32) {
        if let Some(t) = self.toplevels.get(&id) {
            t.handle.unset_fullscreen();
        }
    }

    /// Requests the compositor to close a toplevel window.
    pub fn close(&self, id: u32) {
        if let Some(t) = self.toplevels.get(&id) {
            t.handle.close();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_foreign_toplevel_info_default() {
        let info = ForeignToplevelInfo::default();
        assert_eq!(info.id, 0);
        assert_eq!(info.title, "");
        assert_eq!(info.app_id, "");
        assert!(!info.activated);
        assert!(!info.maximized);
        assert!(!info.minimized);
        assert!(!info.fullscreen);
    }

    #[test]
    fn test_global_cache_synchronization() {
        let test_info = vec![ForeignToplevelInfo {
            id: 101,
            title: "Terminal - Ghostty".to_string(),
            app_id: "com.mitchellh.ghostty".to_string(),
            maximized: false,
            minimized: false,
            activated: true,
            fullscreen: false,
        }];

        update_global_cache(test_info);
        let snapshot = global_foreign_toplevels_snapshot();
        assert_eq!(snapshot.len(), 1);
        assert_eq!(snapshot[0].id, 101);
        assert_eq!(snapshot[0].title, "Terminal - Ghostty");
        assert_eq!(snapshot[0].app_id, "com.mitchellh.ghostty");
        assert!(snapshot[0].activated);
    }
}
