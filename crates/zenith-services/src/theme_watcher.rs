//! Dynamic Theme Watcher for Matugen / Stylix Color Palettes.
//!
//! Watches theme JSON configuration files (e.g. `~/.config/zenith/theme.json`,
//! `~/.config/matugen/colors.json`, Stylix palettes) and triggers instant reactive
//! signal invalidation when the system theme shifts from light to dark or wallpaper changes.

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::SystemTime;

static THEME_WATCHER: OnceLock<Mutex<ThemeWatcher>> = OnceLock::new();
static THEME_LISTENER: OnceLock<Arc<dyn Fn() + Send + Sync>> = OnceLock::new();

/// Dynamic watcher monitoring theme files for mtime updates.
pub struct ThemeWatcher {
    watched_paths: Vec<PathBuf>,
    last_mtime: Option<SystemTime>,
}

impl Default for ThemeWatcher {
    fn default() -> Self {
        Self::new()
    }
}

impl ThemeWatcher {
    /// Creates a new `ThemeWatcher` with default Matugen / Stylix probe locations.
    pub fn new() -> Self {
        let mut watched = Vec::new();

        if let Ok(config_home) = std::env::var("XDG_CONFIG_HOME") {
            watched.push(PathBuf::from(&config_home).join("zenith/theme.json"));
            watched.push(PathBuf::from(&config_home).join("zenith/colors.json"));
            watched.push(PathBuf::from(&config_home).join("matugen/colors.json"));
        } else if let Ok(home) = std::env::var("HOME") {
            watched.push(PathBuf::from(&home).join(".config/zenith/theme.json"));
            watched.push(PathBuf::from(&home).join(".config/zenith/colors.json"));
            watched.push(PathBuf::from(&home).join(".config/matugen/colors.json"));
        }

        if let Ok(cache_home) = std::env::var("XDG_CACHE_HOME") {
            watched.push(PathBuf::from(&cache_home).join("quickshell/matugen/colors.json"));
            watched.push(PathBuf::from(&cache_home).join("matugen/colors.json"));
        } else if let Ok(home) = std::env::var("HOME") {
            watched.push(PathBuf::from(&home).join(".cache/quickshell/matugen/colors.json"));
            watched.push(PathBuf::from(&home).join(".cache/matugen/colors.json"));
        }

        watched.push(PathBuf::from("/etc/stylix/palette.json"));

        let initial_mtime = Self::probe_latest_mtime(&watched);

        Self {
            watched_paths: watched,
            last_mtime: initial_mtime,
        }
    }

    /// Add a custom theme file to watch.
    pub fn watch_path(&mut self, path: impl AsRef<Path>) {
        self.watched_paths.push(path.as_ref().to_path_buf());
    }

    /// Checks if any watched theme configuration file was modified since last check.
    pub fn check_for_changes(&mut self) -> bool {
        let latest = Self::probe_latest_mtime(&self.watched_paths);
        if latest.is_some() && latest != self.last_mtime {
            self.last_mtime = latest;
            crate::SystemService::invalidate_theme_cache();
            if let Some(listener) = THEME_LISTENER.get() {
                listener();
            }
            return true;
        }
        false
    }

    fn probe_latest_mtime(paths: &[PathBuf]) -> Option<SystemTime> {
        let mut max_time: Option<SystemTime> = None;
        for p in paths {
            if let Ok(meta) = std::fs::metadata(p) {
                if let Ok(mtime) = meta.modified() {
                    max_time = Some(match max_time {
                        Some(t) => t.max(mtime),
                        None => mtime,
                    });
                }
            }
        }
        max_time
    }

    /// Register a callback invoked whenever the theme palette file changes.
    pub fn set_change_listener<F: Fn() + Send + Sync + 'static>(listener: F) {
        let _ = THEME_LISTENER.set(Arc::new(listener));
    }

    /// Global tick checking for theme changes in background frame loop.
    pub fn poll_global() -> bool {
        let watcher_lock = THEME_WATCHER.get_or_init(|| Mutex::new(ThemeWatcher::new()));
        if let Ok(mut guard) = watcher_lock.try_lock() {
            guard.check_for_changes()
        } else {
            false
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_theme_watcher_initialization() {
        let mut watcher = ThemeWatcher::new();
        assert!(!watcher.watched_paths.is_empty());
        // Second check with no filesystem mutation should return false
        assert!(!watcher.check_for_changes());
    }
}
