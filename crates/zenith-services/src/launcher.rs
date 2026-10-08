//! XDG Desktop Entry parser and application launcher service.
//!
//! Indexes installed applications across standard XDG directories and NixOS
//! system profiles, providing fast search/fuzzy ranking and sub-process execution.

use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, OnceLock, RwLock};
use tracing::{debug, info};

/// Metadata representation of an indexed desktop application.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, PartialEq, Eq)]
pub struct AppEntry {
    pub id: String,
    pub name: String,
    pub comment: String,
    pub exec: String,
    pub icon: String,
    pub categories: Vec<String>,
    pub keywords: Vec<String>,
}

/// In-memory cache for fast launcher queries.
static APPS_CACHE: OnceLock<Arc<RwLock<Vec<AppEntry>>>> = OnceLock::new();

/// Service provider for desktop applications.
pub struct LauncherService;

impl LauncherService {
    /// Return all cached applications, initializing the cache on first access.
    pub fn get_apps() -> Vec<AppEntry> {
        let cache = APPS_CACHE.get_or_init(|| {
            let apps = Self::scan_all_desktop_entries();
            info!("LauncherService indexed {} desktop applications", apps.len());
            Arc::new(RwLock::new(apps))
        });
        cache.read().unwrap().clone()
    }

    /// Refresh the cached applications index.
    pub fn reload() {
        let apps = Self::scan_all_desktop_entries();
        if let Some(cache) = APPS_CACHE.get() {
            let mut w = cache.write().unwrap();
            *w = apps;
        } else {
            let _ = APPS_CACHE.set(Arc::new(RwLock::new(apps)));
        }
    }

    /// Search indexed applications matching query, returning up to `limit` entries.
    pub fn search(query: &str, limit: usize) -> Vec<AppEntry> {
        let apps = Self::get_apps();
        let q = query.trim().to_lowercase();

        if q.is_empty() {
            let mut res = apps;
            res.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
            res.truncate(limit);
            return res;
        }

        let mut scored: Vec<(i32, AppEntry)> = apps
            .into_iter()
            .filter_map(|app| {
                let score = Self::calculate_score(&app, &q);
                if score > 0 {
                    Some((score, app))
                } else {
                    None
                }
            })
            .collect();

        // Sort descending by score, then ascending by name
        scored.sort_by(|(s1, a1), (s2, a2)| {
            s2.cmp(s1).then_with(|| a1.name.to_lowercase().cmp(&a2.name.to_lowercase()))
        });

        scored.into_iter().take(limit).map(|(_, app)| app).collect()
    }

    /// Launch application command asynchronously in a detached process.
    pub fn launch(exec_cmd: &str) -> std::io::Result<()> {
        let clean_cmd = Self::clean_exec(exec_cmd);
        debug!("Launching application command: {}", clean_cmd);

        std::process::Command::new("sh")
            .arg("-c")
            .arg(format!("{} &", clean_cmd))
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn()?;

        Ok(())
    }

    fn calculate_score(app: &AppEntry, q: &str) -> i32 {
        let name_lower = app.name.to_lowercase();
        let comment_lower = app.comment.to_lowercase();
        let exec_lower = app.exec.to_lowercase();

        if name_lower == *q {
            return 1000;
        }

        if name_lower.starts_with(q) {
            return 500 + (100 - name_lower.len().min(100) as i32);
        }

        if name_lower.contains(q) {
            return 300;
        }

        for kw in &app.keywords {
            let kw_lower = kw.to_lowercase();
            if kw_lower == *q {
                return 250;
            }
            if kw_lower.starts_with(q) {
                return 200;
            }
            if kw_lower.contains(q) {
                return 150;
            }
        }

        if comment_lower.contains(q) {
            return 100;
        }

        if exec_lower.contains(q) {
            return 80;
        }

        // Fuzzy subsequence match in app name
        if Self::fuzzy_subsequence(&name_lower, q) {
            return 50;
        }

        0
    }

    fn fuzzy_subsequence(text: &str, pattern: &str) -> bool {
        let mut text_chars = text.chars();
        for p in pattern.chars() {
            if !text_chars.any(|c| c == p) {
                return false;
            }
        }
        true
    }

    /// Strip XDG field codes (%f, %u, %F, %U, etc.) from desktop Exec string.
    pub fn clean_exec(raw_exec: &str) -> String {
        let mut tokens = Vec::new();
        for part in raw_exec.split_whitespace() {
            if part.starts_with('%') {
                continue;
            }
            tokens.push(part);
        }
        tokens.join(" ")
    }

    /// Discover application directories respecting XDG specs and NixOS profiles.
    fn search_directories() -> Vec<PathBuf> {
        let mut dirs = Vec::new();

        // 1. User applications (~/.local/share/applications)
        if let Ok(home) = std::env::var("HOME") {
            dirs.push(PathBuf::from(home).join(".local/share/applications"));
        }

        // 2. XDG_DATA_HOME
        if let Ok(data_home) = std::env::var("XDG_DATA_HOME") {
            dirs.push(PathBuf::from(data_home).join("applications"));
        }

        // 3. NixOS Home Manager user profile
        if let (Ok(home), Ok(user)) = (std::env::var("HOME"), std::env::var("USER")) {
            dirs.push(PathBuf::from(format!("/etc/profiles/per-user/{}/share/applications", user)));
            dirs.push(PathBuf::from(home).join(".nix-profile/share/applications"));
        }

        // 4. NixOS system profile
        dirs.push(PathBuf::from("/run/current-system/sw/share/applications"));

        // 5. Standard XDG_DATA_DIRS
        if let Ok(data_dirs) = std::env::var("XDG_DATA_DIRS") {
            for dir in data_dirs.split(':') {
                dirs.push(PathBuf::from(dir).join("applications"));
            }
        }

        // 6. Generic Linux fallbacks
        dirs.push(PathBuf::from("/usr/local/share/applications"));
        dirs.push(PathBuf::from("/usr/share/applications"));

        dirs
    }

    /// Read all .desktop files and construct deduplicated list of applications.
    fn scan_all_desktop_entries() -> Vec<AppEntry> {
        let mut seen_ids = HashSet::new();
        let mut entries = Vec::new();

        for dir in Self::search_directories() {
            if !dir.is_dir() {
                continue;
            }

            let rd = match fs::read_dir(&dir) {
                Ok(r) => r,
                Err(_) => continue,
            };

            for item in rd.flatten() {
                let path = item.path();
                if path.extension().and_then(|s| s.to_str()) != Some("desktop") {
                    continue;
                }

                let file_name = path.file_stem().and_then(|s| s.to_str()).unwrap_or("");
                if file_name.is_empty() || seen_ids.contains(file_name) {
                    continue;
                }

                if let Some(app) = Self::parse_desktop_file(&path, file_name) {
                    seen_ids.insert(file_name.to_string());
                    entries.push(app);
                }
            }
        }

        entries
    }

    /// Parse a single .desktop file.
    pub fn parse_desktop_file(path: &Path, id: &str) -> Option<AppEntry> {
        let content = fs::read_to_string(path).ok()?;
        Self::parse_desktop_content(&content, id)
    }

    /// Parse content string from a desktop file.
    pub fn parse_desktop_content(content: &str, id: &str) -> Option<AppEntry> {
        let mut in_desktop_entry = false;
        let mut name = String::new();
        let mut comment = String::new();
        let mut exec = String::new();
        let mut icon = String::new();
        let mut categories = Vec::new();
        let mut keywords = Vec::new();
        let mut no_display = false;
        let mut is_application = false;

        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }

            if trimmed.starts_with('[') {
                if trimmed == "[Desktop Entry]" {
                    in_desktop_entry = true;
                } else if in_desktop_entry {
                    // Entered another group (e.g. [Desktop Action ...])
                    break;
                }
                continue;
            }

            if !in_desktop_entry {
                continue;
            }

            if let Some((key, val)) = trimmed.split_once('=') {
                let key = key.trim();
                let val = val.trim();

                match key {
                    "Type" => {
                        if val == "Application" {
                            is_application = true;
                        }
                    }
                    "Name" if name.is_empty() => {
                        name = val.to_string();
                    }
                    "Comment" if comment.is_empty() => {
                        comment = val.to_string();
                    }
                    "Exec" if exec.is_empty() => {
                        exec = val.to_string();
                    }
                    "Icon" if icon.is_empty() => {
                        icon = val.to_string();
                    }
                    "NoDisplay" | "Hidden" => {
                        if val.eq_ignore_ascii_case("true") {
                            no_display = true;
                        }
                    }
                    "Categories" => {
                        categories = val
                            .split(';')
                            .map(|s| s.trim().to_string())
                            .filter(|s| !s.is_empty())
                            .collect();
                    }
                    "Keywords" => {
                        keywords = val
                            .split(';')
                            .map(|s| s.trim().to_string())
                            .filter(|s| !s.is_empty())
                            .collect();
                    }
                    _ => {}
                }
            }
        }

        if !is_application || no_display || name.is_empty() || exec.is_empty() {
            return None;
        }

        let clean_exec_str = Self::clean_exec(&exec);

        Some(AppEntry {
            id: id.to_string(),
            name,
            comment,
            exec: clean_exec_str,
            icon,
            categories,
            keywords,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_desktop_content() {
        let sample = r#"
[Desktop Entry]
Name=Firefox Web Browser
Comment=Browse the World Wide Web
Exec=firefox %u
Icon=firefox
Terminal=false
Type=Application
Categories=Network;WebBrowser;
Keywords=web;browser;internet;
"#;

        let entry = LauncherService::parse_desktop_content(sample, "firefox")
            .expect("Expected entry to parse");
        assert_eq!(entry.name, "Firefox Web Browser");
        assert_eq!(entry.exec, "firefox");
        assert_eq!(entry.icon, "firefox");
        assert_eq!(entry.categories, vec!["Network", "WebBrowser"]);
        assert!(entry.keywords.contains(&"internet".to_string()));
    }

    #[test]
    fn test_nodisplay_ignored() {
        let sample = r#"
[Desktop Entry]
Name=Hidden App
Exec=hidden
Type=Application
NoDisplay=true
"#;
        assert!(LauncherService::parse_desktop_content(sample, "hidden").is_none());
    }

    #[test]
    fn test_search_and_ranking() {
        let app1 = AppEntry {
            id: "code".into(),
            name: "Visual Studio Code".into(),
            comment: "Code Editing. Redefined.".into(),
            exec: "code".into(),
            icon: "code".into(),
            categories: vec!["Development".into()],
            keywords: vec!["editor".into(), "ide".into()],
        };

        let app2 = AppEntry {
            id: "firefox".into(),
            name: "Firefox".into(),
            comment: "Web Browser".into(),
            exec: "firefox".into(),
            icon: "firefox".into(),
            categories: vec!["Network".into()],
            keywords: vec!["web".into()],
        };

        let score_code = LauncherService::calculate_score(&app1, "code");
        let score_firefox = LauncherService::calculate_score(&app2, "code");

        assert!(score_code > score_firefox);
        assert_eq!(score_firefox, 0);

        let score_editor = LauncherService::calculate_score(&app1, "editor");
        assert!(score_editor > 0);
    }
}
