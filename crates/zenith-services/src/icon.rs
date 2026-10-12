//! XDG Desktop Icon Theme Resolver & VRAM Cache for Zenith Shell.
//!
//! Complies with the Freedesktop.org Icon Theme Specification:
//! Resolves generic icon names (e.g. `firefox`, `utilities-terminal`, `audio-volume-high`)
//! to absolute raster/vector filesystem paths across user and system theme directories.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, OnceLock, RwLock};

type IconCache = Arc<RwLock<HashMap<String, Option<PathBuf>>>>;
static ICON_CACHE: OnceLock<IconCache> = OnceLock::new();

/// Service for resolving desktop icon names to real asset file paths.
pub struct XdgIconResolver;

impl XdgIconResolver {
    /// Invalidate in-memory icon resolution cache.
    pub fn invalidate_cache() {
        if let Some(c) = ICON_CACHE.get() {
            if let Ok(mut lock) = c.write() {
                lock.clear();
            }
        }
    }

    /// Resolves an icon name to an absolute SVG or PNG file path.
    pub fn resolve(icon_name: &str, preferred_size: u32) -> Option<PathBuf> {
        let trimmed = icon_name.trim();
        if trimmed.is_empty() {
            return None;
        }

        // If it's already an existing absolute or relative path, return immediately
        let direct_path = Path::new(trimmed);
        if direct_path.is_absolute() && direct_path.exists() {
            return Some(direct_path.to_path_buf());
        }

        let cache = ICON_CACHE.get_or_init(|| Arc::new(RwLock::new(HashMap::new())));
        let key = format!("{}_{}", trimmed, preferred_size);

        if let Ok(guard) = cache.read() {
            if let Some(cached) = guard.get(&key) {
                return cached.clone();
            }
        }

        let resolved = Self::resolve_uncached(trimmed, preferred_size);

        if let Ok(mut writer) = cache.write() {
            writer.insert(key, resolved.clone());
        }

        resolved
    }

    fn resolve_uncached(name: &str, size: u32) -> Option<PathBuf> {
        let base_dirs = Self::get_icon_search_paths();
        let size_str = format!("{}x{}", size, size);
        let size_fallbacks = ["scalable", &size_str, "48x48", "64x64", "32x32", "24x24", "16x16", "128x128", "256x256"];
        let categories = ["apps", "devices", "status", "categories", "actions", "places", "mimetypes"];
        let extensions = ["svg", "png", "xpm"];

        // Common themes to probe: hicolor is universal standard fallback
        let themes = ["hicolor", "Papirus", "breeze", "Adwaita", "elementary"];

        for base in &base_dirs {
            for theme in &themes {
                let theme_dir = base.join(theme);
                if !theme_dir.exists() {
                    continue;
                }

                for s in &size_fallbacks {
                    for cat in &categories {
                        let candidate_dir = theme_dir.join(s).join(cat);
                        for ext in &extensions {
                            let candidate = candidate_dir.join(format!("{}.{}", name, ext));
                            if candidate.exists() {
                                return Some(candidate);
                            }
                        }
                    }
                }
            }

            // Direct pixmaps directory lookup (e.g. /usr/share/pixmaps/firefox.png)
            let pixmaps = base.parent().unwrap_or(base).join("pixmaps");
            for ext in &extensions {
                let candidate = pixmaps.join(format!("{}.{}", name, ext));
                if candidate.exists() {
                    return Some(candidate);
                }
            }
        }

        None
    }

    /// Enumerate all standard Freedesktop icon search directories.
    pub fn get_icon_search_paths() -> Vec<PathBuf> {
        let mut paths = Vec::new();

        // 1. $XDG_DATA_HOME/icons (typically ~/.local/share/icons)
        if let Ok(data_home) = std::env::var("XDG_DATA_HOME") {
            paths.push(PathBuf::from(data_home).join("icons"));
        } else if let Ok(home) = std::env::var("HOME") {
            paths.push(PathBuf::from(&home).join(".local/share/icons"));
            paths.push(PathBuf::from(&home).join(".icons"));
        }

        // 2. $XDG_DATA_DIRS/icons
        let data_dirs = std::env::var("XDG_DATA_DIRS")
            .unwrap_or_else(|_| "/usr/local/share:/usr/share:/nix/var/nix/profiles/default/share".to_string());
        for dir in data_dirs.split(':') {
            if !dir.is_empty() {
                paths.push(PathBuf::from(dir).join("icons"));
            }
        }

        // 3. Fallback standard Linux system paths
        paths.push(PathBuf::from("/usr/share/icons"));
        paths.push(PathBuf::from("/run/current-system/sw/share/icons"));

        paths
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_icon_search_paths_populated() {
        let paths = XdgIconResolver::get_icon_search_paths();
        assert!(!paths.is_empty());
        assert!(paths.iter().any(|p| p.to_string_lossy().contains("icons")));
    }

    #[test]
    fn test_direct_path_bypass() {
        let p = XdgIconResolver::resolve("/bin/sh", 32);
        assert_eq!(p, Some(PathBuf::from("/bin/sh")));
    }

    #[test]
    fn test_nonexistent_icon_returns_none() {
        let p = XdgIconResolver::resolve("non_existent_app_icon_xyz_9999", 32);
        assert_eq!(p, None);
    }
}
