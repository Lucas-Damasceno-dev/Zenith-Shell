//! Zenith Services - Foreign Toplevel Management Service.
//!
//! Provides thread-safe snapshot caching and action dispatching between
//! Wayland foreign toplevel protocols and the Luau runtime.

use std::sync::{Arc, Mutex, OnceLock, RwLock};
use serde::{Deserialize, Serialize};

/// Lightweight metadata snapshot for a toplevel window.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct ToplevelInfo {
    pub id: u32,
    pub title: String,
    pub app_id: String,
    pub maximized: bool,
    pub minimized: bool,
    pub activated: bool,
    pub fullscreen: bool,
}

/// Commands dispatched from Luau runtime to the Wayland toplevel manager.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ToplevelAction {
    Activate(u32),
    Close(u32),
    SetMinimized(u32, bool),
    SetMaximized(u32, bool),
}

static TOPLEVEL_SNAPSHOT: OnceLock<RwLock<Vec<ToplevelInfo>>> = OnceLock::new();
static TOPLEVEL_ACTIONS: OnceLock<Arc<Mutex<Vec<ToplevelAction>>>> = OnceLock::new();

pub struct ToplevelService;

impl ToplevelService {
    fn actions_queue() -> &'static Arc<Mutex<Vec<ToplevelAction>>> {
        TOPLEVEL_ACTIONS.get_or_init(|| Arc::new(Mutex::new(Vec::new())))
    }

    /// Retrieve the current snapshot of all active foreign toplevel windows.
    pub fn get_toplevels() -> Vec<ToplevelInfo> {
        TOPLEVEL_SNAPSHOT
            .get_or_init(|| RwLock::new(Vec::new()))
            .read()
            .map(|r| r.clone())
            .unwrap_or_default()
    }

    /// Update the current snapshot from Wayland event callbacks.
    pub fn update_toplevels(list: Vec<ToplevelInfo>) {
        if let Ok(mut lock) = TOPLEVEL_SNAPSHOT
            .get_or_init(|| RwLock::new(Vec::new()))
            .write()
        {
            *lock = list;
        }
    }

    /// Queue an action to be dispatched by Wayland foreign toplevel handle.
    pub fn send_action(action: ToplevelAction) {
        if let Ok(mut q) = Self::actions_queue().lock() {
            q.push(action);
        }
    }

    /// Drain all queued toplevel actions for processing on the Wayland thread.
    pub fn drain_actions() -> Vec<ToplevelAction> {
        if let Ok(mut q) = Self::actions_queue().lock() {
            q.drain(..).collect()
        } else {
            Vec::new()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_toplevel_service_queue_and_drain() {
        ToplevelService::send_action(ToplevelAction::Activate(42));
        let actions = ToplevelService::drain_actions();
        assert_eq!(actions, vec![ToplevelAction::Activate(42)]);
        assert!(ToplevelService::drain_actions().is_empty());
    }
}
