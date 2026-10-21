//! Persistent State Storage Engine for Zenith Shell.
//!
//! Exposes `Zenith.Storage` to Luau scripts with in-memory caching and atomic
//! disk persistence to prevent file corruption during sudden system shutdowns.

use std::collections::HashMap;
use std::fs::{self, File};
use std::io::Write;
use std::path::PathBuf;
use std::sync::{Arc, RwLock};

use mlua::prelude::*;
use serde_json::Value as JsonValue;
use tracing::{error, info};

use std::sync::mpsc::{channel, Sender};
use std::time::Duration;

enum StorageMsg {
    SyncKey { key: String, val: JsonValue },
    Flush(Sender<()>),
    Shutdown,
}

/// Local storage engine handling key-value state persistence with bidirectional config.json sync.
pub struct StorageEngine {
    file_path: PathBuf,
    config_path: Option<PathBuf>,
    cache: Arc<RwLock<HashMap<String, JsonValue>>>,
    tx: Sender<StorageMsg>,
}

impl StorageEngine {
    /// Resolves canonical path for central config.json (~/.config/zenith/config.json or project config).
    pub fn resolve_config_path() -> Option<PathBuf> {
        let mut candidates = Vec::new();
        if let Ok(home) = std::env::var("HOME") {
            candidates.push(PathBuf::from(home).join(".config/zenith/config.json"));
        }
        candidates.push(PathBuf::from("config/zenith/config.json"));
        candidates.push(PathBuf::from("../../config/zenith/config.json"));

        candidates.into_iter().find(|p| p.exists())
    }

    /// Recursively flattens and maps config.json sections into cache.
    fn load_from_config(config_path: &std::path::Path, data: &mut HashMap<String, JsonValue>) {
        if let Ok(content) = fs::read_to_string(config_path) {
            if let Ok(JsonValue::Object(map)) = serde_json::from_str::<JsonValue>(&content) {
                for (section_name, section_val) in map {
                    if let JsonValue::Object(inner_map) = section_val {
                        for (inner_k, inner_v) in inner_map {
                            let dotted = format!("{}.{}", section_name, inner_k);
                            data.insert(dotted, inner_v.clone());

                            let flat_key = Self::canonical_flat_key(&section_name, &inner_k);
                            data.insert(flat_key, inner_v);
                        }
                    } else {
                        data.insert(section_name, section_val);
                    }
                }
            }
        }
    }

    /// Maps section and key to canonical flat settings key.
    fn canonical_flat_key(section: &str, key: &str) -> String {
        match (section, key) {
            ("quick", "accentColor") | ("appearance", "accentColor") => "accentColor".to_string(),
            ("quick", "layoutPreset") => "layoutPreset".to_string(),
            ("quick", "colorScheme") => "colorScheme".to_string(),
            ("quick", "darkMode") => "darkMode".to_string(),
            ("quick", "barAutoHide") | ("bar", "autoHide") => "barAutoHide".to_string(),
            ("quick", "barCompactMode") | ("bar", "compactMode") => "barCompactMode".to_string(),
            ("quick", "reducedMotion") => "reducedMotion".to_string(),
            ("quick", "privacyMode") => "privacyMode".to_string(),
            ("quick", "focusMode") => "focusMode".to_string(),
            ("quick", "lowPowerMode") => "lowPowerMode".to_string(),
            ("bar", "height") => "barHeight".to_string(),
            ("bar", "customRounding") => "barRadius".to_string(),
            ("bar", "position") => "barPosition".to_string(),
            ("bar", "autoHideDelayMs") | ("quick", "barAutoHideDelayMs") => "barAutoHideDelayMs".to_string(),
            ("appearance", "blurOpacity") => "barGlassOpacity".to_string(),
            ("dock", "enable") => "dockEnabled".to_string(),
            ("dock", "height") => "dockHeight".to_string(),
            ("quick", "dockAutoHide") | ("dock", "autoHide") => "dockAutoHide".to_string(),
            ("dock", "enableBlurGlass") => "dockBlurGlass".to_string(),
            ("dock", "showMpris") => "dockShowMpris".to_string(),
            ("dock", "showTrash") => "dockShowTrash".to_string(),
            ("wallpaper", "backend") => "wallpaperBackend".to_string(),
            ("wallpaper", "slideshow") => "wallpaperSlideshow".to_string(),
            ("system", "audioVolumeStep") => "audioVolumeStep".to_string(),
            ("system", "audioProtection") => "audioProtection".to_string(),
            ("system", "batteryChargeLimit") => "batteryChargeLimit".to_string(),
            ("system", "batteryPowerProfile") => "batteryPowerProfile".to_string(),
            ("system", "batteryLowThreshold") => "batteryLowThreshold".to_string(),
            ("system", "batteryCriticalThreshold") => "batteryCriticalThreshold".to_string(),
            ("system", "batteryNotifyFull") => "batteryNotifyFull".to_string(),
            ("system", "nightLightEnabled") => "nightLightEnabled".to_string(),
            ("system", "nightLightValue") => "nightLightTemp".to_string(),
            ("system", "grayscaleValue") => "grayscaleIntensity".to_string(),
            ("system", "hyprlockBlur") => "hyprlockBlur".to_string(),
            ("compositor", "layout") => "hyprLayout".to_string(),
            ("compositor", "gapsIn") => "gapsIn".to_string(),
            ("compositor", "gapsOut") => "gapsOut".to_string(),
            ("compositor", "borderSize") => "borderSize".to_string(),
            ("tools", "ocrLanguage") => "toolsOcrLang".to_string(),
            ("tools", "crosshairEnable") => "toolsCrosshair".to_string(),
            ("services", "weatherProvider") => "weatherProvider".to_string(),
            ("services", "weatherUnits") => "weatherUnits".to_string(),
            ("services", "appTerminal") => "appTerminal".to_string(),
            ("services", "appBrowser") => "appBrowser".to_string(),
            ("services", "appFileManager") => "appFileManager".to_string(),
            ("services", "appEditor") => "appEditor".to_string(),
            ("ai", "provider") => "aiProvider".to_string(),
            ("ai", "model") => "aiModel".to_string(),
            ("ai", "temperature") => "aiTemperature".to_string(),
            ("appearance", "springStiffness") => "springStiffness".to_string(),
            ("appearance", "springDamping") => "springDamping".to_string(),
            _ => key.to_string(),
        }
    }

    /// Maps flat key back to (section, key) target locations in config.json.
    fn flat_key_to_sections(key: &str) -> Vec<(&'static str, &'static str)> {
        match key {
            "accentColor" => vec![("quick", "accentColor"), ("appearance", "accentColor")],
            "layoutPreset" => vec![("quick", "layoutPreset")],
            "colorScheme" => vec![("quick", "colorScheme")],
            "darkMode" => vec![("quick", "darkMode")],
            "barAutoHide" => vec![("quick", "barAutoHide"), ("bar", "autoHide")],
            "barCompactMode" => vec![("quick", "barCompactMode"), ("bar", "compactMode")],
            "reducedMotion" => vec![("quick", "reducedMotion")],
            "privacyMode" => vec![("quick", "privacyMode")],
            "focusMode" => vec![("quick", "focusMode")],
            "lowPowerMode" => vec![("quick", "lowPowerMode")],
            "barHeight" => vec![("bar", "height")],
            "barRadius" => vec![("bar", "customRounding")],
            "barPosition" => vec![("bar", "position")],
            "barAutoHideDelayMs" => vec![("bar", "autoHideDelayMs")],
            "barGlassOpacity" => vec![("appearance", "blurOpacity")],
            "dockEnabled" => vec![("dock", "enable")],
            "dockHeight" => vec![("dock", "height")],
            "dockAutoHide" => vec![("quick", "dockAutoHide"), ("dock", "autoHide")],
            "dockBlurGlass" => vec![("dock", "enableBlurGlass")],
            "dockShowMpris" => vec![("dock", "showMpris")],
            "dockShowTrash" => vec![("dock", "showTrash")],
            "wallpaperBackend" => vec![("wallpaper", "backend")],
            "wallpaperSlideshow" => vec![("wallpaper", "slideshow")],
            "audioVolumeStep" => vec![("system", "audioVolumeStep")],
            "audioProtection" => vec![("system", "audioProtection")],
            "batteryChargeLimit" => vec![("system", "batteryChargeLimit")],
            "batteryPowerProfile" => vec![("system", "batteryPowerProfile")],
            "batteryLowThreshold" => vec![("system", "batteryLowThreshold")],
            "batteryCriticalThreshold" => vec![("system", "batteryCriticalThreshold")],
            "batteryNotifyFull" => vec![("system", "batteryNotifyFull")],
            "nightLightEnabled" => vec![("system", "nightLightEnabled")],
            "nightLightTemp" => vec![("system", "nightLightValue")],
            "grayscaleIntensity" => vec![("system", "grayscaleValue")],
            "hyprlockBlur" => vec![("system", "hyprlockBlur")],
            "hyprLayout" => vec![("compositor", "layout")],
            "gapsIn" => vec![("compositor", "gapsIn")],
            "gapsOut" => vec![("compositor", "gapsOut")],
            "borderSize" => vec![("compositor", "borderSize")],
            "toolsOcrLang" => vec![("tools", "ocrLanguage")],
            "toolsCrosshair" => vec![("tools", "crosshairEnable")],
            "weatherProvider" => vec![("services", "weatherProvider")],
            "weatherUnits" => vec![("services", "weatherUnits")],
            "appTerminal" => vec![("services", "appTerminal")],
            "appBrowser" => vec![("services", "appBrowser")],
            "appFileManager" => vec![("services", "appFileManager")],
            "appEditor" => vec![("services", "appEditor")],
            "aiProvider" => vec![("ai", "provider")],
            "aiModel" => vec![("ai", "model")],
            "aiTemperature" => vec![("ai", "temperature")],
            "springStiffness" => vec![("appearance", "springStiffness")],
            "springDamping" => vec![("appearance", "springDamping")],
            _ => Vec::new(),
        }
    }

    /// Atomically syncs a single modified key into config.json.
    fn sync_key_to_config(config_path: &std::path::Path, key: &str, val: &JsonValue) -> Result<(), std::io::Error> {
        if !config_path.exists() {
            return Ok(());
        }
        let content = fs::read_to_string(config_path)?;
        let mut root: JsonValue = match serde_json::from_str(&content) {
            Ok(v) => v,
            Err(_) => return Ok(()),
        };

        if let JsonValue::Object(ref mut root_map) = root {
            if let Some((section, inner_k)) = key.split_once('.') {
                if let Some(JsonValue::Object(ref mut sec_map)) = root_map.get_mut(section) {
                    sec_map.insert(inner_k.to_string(), val.clone());
                }
            } else {
                let targets = Self::flat_key_to_sections(key);
                if !targets.is_empty() {
                    for (sec, target_k) in targets {
                        if let Some(JsonValue::Object(ref mut sec_map)) = root_map.get_mut(sec) {
                            sec_map.insert(target_k.to_string(), val.clone());
                        }
                    }
                } else {
                    let mut found = false;
                    for sec_val in root_map.values_mut() {
                        if let JsonValue::Object(ref mut sec_map) = sec_val {
                            if sec_map.contains_key(key) {
                                sec_map.insert(key.to_string(), val.clone());
                                found = true;
                            }
                        }
                    }
                    if !found {
                        // Do not inject unknown/ephemeral session keys into config.json.
                        // Ephemeral state remains safely persisted only in storage.json.
                        return Ok(());
                    }
                }
            }
        }

        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0);
        let temp_path = config_path.with_extension(format!("tmp.{}.{}", std::process::id(), nanos));
        let json_str = serde_json::to_string_pretty(&root)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;

        {
            let mut file = File::create(&temp_path)?;
            file.write_all(json_str.as_bytes())?;
        }
        fs::rename(&temp_path, config_path)?;
        Ok(())
    }

    /// Initialize storage engine from default or explicit file path.
    pub fn new(custom_path: Option<PathBuf>) -> Self {
        let file_path = custom_path.unwrap_or_else(Self::default_storage_path);
        let config_path = Self::resolve_config_path();
        let mut initial_data = HashMap::new();

        // 1. Load defaults and schema values from config.json
        if let Some(ref cp) = config_path {
            Self::load_from_config(cp, &mut initial_data);
        }

        // 2. Layer local state storage overrides from storage.json
        if file_path.exists() {
            if let Ok(content) = fs::read_to_string(&file_path) {
                if let Ok(parsed) = serde_json::from_str::<HashMap<String, JsonValue>>(&content) {
                    for (k, v) in parsed {
                        initial_data.insert(k, v);
                    }
                }
            }
        }

        let cache = Arc::new(RwLock::new(initial_data));
        let tx = Self::start_worker(cache.clone(), file_path.clone(), config_path.clone());

        Self {
            file_path,
            config_path,
            cache,
            tx,
        }
    }

    /// Starts a dedicated debounced persistence worker thread.
    fn start_worker(
        cache: Arc<RwLock<HashMap<String, JsonValue>>>,
        file_path: PathBuf,
        config_path: Option<PathBuf>,
    ) -> Sender<StorageMsg> {
        let (tx, rx) = channel();
        std::thread::Builder::new()
            .name("zenith-storage-debouncer".into())
            .spawn(move || {
                let debounce_duration = Duration::from_millis(100);
                let mut pending_keys: HashMap<String, JsonValue> = HashMap::new();

                loop {
                    if !pending_keys.is_empty() {
                        match rx.recv_timeout(debounce_duration) {
                            Ok(StorageMsg::SyncKey { key, val }) => {
                                pending_keys.insert(key, val);
                            }
                            Ok(StorageMsg::Flush(ack)) => {
                                let _ = Self::flush_to_path(&cache, &file_path);
                                if let Some(ref cp) = config_path {
                                    for (k, v) in pending_keys.drain() {
                                        let _ = Self::sync_key_to_config(cp, &k, &v);
                                    }
                                }
                                let _ = ack.send(());
                            }
                            Ok(StorageMsg::Shutdown) => {
                                let _ = Self::flush_to_path(&cache, &file_path);
                                if let Some(ref cp) = config_path {
                                    for (k, v) in pending_keys.drain() {
                                        let _ = Self::sync_key_to_config(cp, &k, &v);
                                    }
                                }
                                break;
                            }
                            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {
                                let _ = Self::flush_to_path(&cache, &file_path);
                                if let Some(ref cp) = config_path {
                                    for (k, v) in pending_keys.drain() {
                                        let _ = Self::sync_key_to_config(cp, &k, &v);
                                    }
                                }
                            }
                            Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => {
                                let _ = Self::flush_to_path(&cache, &file_path);
                                if let Some(ref cp) = config_path {
                                    for (k, v) in pending_keys.drain() {
                                        let _ = Self::sync_key_to_config(cp, &k, &v);
                                    }
                                }
                                break;
                            }
                        }
                    } else {
                        match rx.recv() {
                            Ok(StorageMsg::SyncKey { key, val }) => {
                                pending_keys.insert(key, val);
                            }
                            Ok(StorageMsg::Flush(ack)) => {
                                let _ = Self::flush_to_path(&cache, &file_path);
                                let _ = ack.send(());
                            }
                            Ok(StorageMsg::Shutdown) => {
                                break;
                            }
                            Err(_) => {
                                break;
                            }
                        }
                    }
                }
            })
            .expect("Failed to spawn zenith-storage debouncer thread");

        tx
    }

    /// Sets explicit config path (for testing and isolation).
    pub fn with_config_path(mut self, path: Option<PathBuf>) -> Self {
        let _ = self.tx.send(StorageMsg::Shutdown);
        self.config_path = path;
        let mut new_data = HashMap::new();
        if let Some(ref cp) = self.config_path {
            Self::load_from_config(cp, &mut new_data);
        }
        if self.file_path.exists() {
            if let Ok(content) = fs::read_to_string(&self.file_path) {
                if let Ok(parsed) = serde_json::from_str::<HashMap<String, JsonValue>>(&content) {
                    for (k, v) in parsed {
                        new_data.insert(k, v);
                    }
                }
            }
        }
        *self.cache.write().unwrap() = new_data;
        self.tx = Self::start_worker(self.cache.clone(), self.file_path.clone(), self.config_path.clone());
        self
    }

    /// Resolves the canonical file path ($XDG_STATE_HOME/zenith/storage.json).
    pub fn default_storage_path() -> PathBuf {
        let base_dir = if let Ok(state_home) = std::env::var("XDG_STATE_HOME") {
            PathBuf::from(state_home)
        } else if let Ok(home) = std::env::var("HOME") {
            PathBuf::from(home).join(".local").join("state")
        } else {
            PathBuf::from("/tmp")
        };
        base_dir.join("zenith").join("storage.json")
    }

    /// Retrieves a value by key.
    pub fn get(&self, key: &str) -> Option<JsonValue> {
        self.cache.read().unwrap().get(key).cloned()
    }

    /// Sets a value for key and persists with debounced flush (100ms) to disk.
    pub fn set(&self, key: &str, val: JsonValue) -> Result<(), std::io::Error> {
        {
            let mut writer = self.cache.write().unwrap();
            writer.insert(key.to_string(), val.clone());
            if let Some((section, inner_k)) = key.split_once('.') {
                let flat_k = Self::canonical_flat_key(section, inner_k);
                if flat_k != key {
                    writer.insert(flat_k.clone(), val.clone());
                    for (s, k) in Self::flat_key_to_sections(&flat_k) {
                        let dot_k = format!("{}.{}", s, k);
                        writer.insert(dot_k, val.clone());
                    }
                }
            } else {
                for (s, k) in Self::flat_key_to_sections(key) {
                    let dot_k = format!("{}.{}", s, k);
                    writer.insert(dot_k, val.clone());
                }
            }
        }

        let _ = self.tx.send(StorageMsg::SyncKey {
            key: key.to_string(),
            val,
        });
        Ok(())
    }

    /// Reloads current values from central config.json into cache.
    pub fn reload_from_config(&self) -> Result<(), std::io::Error> {
        if let Some(ref cp) = self.config_path {
            let mut new_data = HashMap::new();
            Self::load_from_config(cp, &mut new_data);
            let mut writer = self.cache.write().unwrap();
            for (k, v) in new_data {
                writer.insert(k, v);
            }
        }
        Ok(())
    }

    /// Forces immediate bidirectional flush of all cache keys to config.json.
    pub fn sync_to_config(&self) -> Result<(), std::io::Error> {
        if let Some(ref cp) = self.config_path {
            let reader = self.cache.read().unwrap();
            for (k, v) in reader.iter() {
                let _ = Self::sync_key_to_config(cp, k, v);
            }
        }
        Ok(())
    }

    /// Checks if a key exists.
    pub fn has(&self, key: &str) -> bool {
        self.cache.read().unwrap().contains_key(key)
    }

    /// Removes a key from storage.
    pub fn remove(&self, key: &str) -> Result<bool, std::io::Error> {
        let removed = {
            let mut writer = self.cache.write().unwrap();
            writer.remove(key).is_some()
        };
        if removed {
            let (ack_tx, ack_rx) = channel();
            let _ = self.tx.send(StorageMsg::Flush(ack_tx));
            let _ = ack_rx.recv();
        }
        Ok(removed)
    }

    /// Clears all keys from storage.
    pub fn clear(&self) -> Result<(), std::io::Error> {
        {
            let mut writer = self.cache.write().unwrap();
            writer.clear();
        }
        let (ack_tx, ack_rx) = channel();
        let _ = self.tx.send(StorageMsg::Flush(ack_tx));
        let _ = ack_rx.recv();
        Ok(())
    }

    /// Returns a copy of all stored key-value pairs.
    pub fn all(&self) -> HashMap<String, JsonValue> {
        self.cache.read().unwrap().clone()
    }

    /// Explicitly flushes the cache to disk synchronously.
    pub fn flush(&self) -> Result<(), std::io::Error> {
        let (ack_tx, ack_rx) = channel();
        if self.tx.send(StorageMsg::Flush(ack_tx)).is_ok() {
            let _ = ack_rx.recv();
        } else {
            Self::flush_to_path(&self.cache, &self.file_path)?;
        }
        Ok(())
    }

    /// Atomically flushes the cache to disk via temporary file rename.
    fn flush_to_path(cache: &Arc<RwLock<HashMap<String, JsonValue>>>, file_path: &std::path::Path) -> Result<(), std::io::Error> {
        if let Some(parent) = file_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0);
        let temp_path = file_path.with_extension(format!("tmp.{}.{}", std::process::id(), nanos));
        let json_str = {
            let reader = cache.read().unwrap();
            serde_json::to_string_pretty(&*reader)
                .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?
        };

        {
            let mut file = File::create(&temp_path)?;
            file.write_all(json_str.as_bytes())?;
            file.flush()?;
            file.sync_all()?;
        }

        fs::rename(&temp_path, file_path)?;
        Ok(())
    }
}

impl Drop for StorageEngine {
    fn drop(&mut self) {
        let _ = self.tx.send(StorageMsg::Shutdown);
    }
}

/// Converts LuaValue to serde_json::Value.
pub fn lua_to_json(val: LuaValue) -> JsonValue {
    match val {
        LuaValue::Nil => JsonValue::Null,
        LuaValue::Boolean(b) => JsonValue::Bool(b),
        LuaValue::Integer(i) => JsonValue::from(i),
        LuaValue::Number(n) => serde_json::Number::from_f64(n)
            .map(JsonValue::Number)
            .unwrap_or(JsonValue::Null),
        LuaValue::String(s) => JsonValue::String(s.to_str().map(|b| b.to_string()).unwrap_or_default()),
        LuaValue::Table(tbl) => {
            // Check if array or map
            let len = tbl.raw_len();
            if len > 0 {
                let mut vec = Vec::with_capacity(len);
                for i in 1..=len {
                    if let Ok(v) = tbl.raw_get(i) {
                        vec.push(lua_to_json(v));
                    }
                }
                JsonValue::Array(vec)
            } else {
                let mut map = serde_json::Map::new();
                for (k, v) in tbl.pairs::<String, LuaValue>().flatten() {
                    map.insert(k, lua_to_json(v));
                }
                JsonValue::Object(map)
            }
        }
        _ => JsonValue::Null,
    }
}

/// Converts serde_json::Value to mlua::Value.
pub fn json_to_lua(lua: &Lua, val: &JsonValue) -> LuaResult<LuaValue> {
    match val {
        JsonValue::Null => Ok(LuaValue::Nil),
        JsonValue::Bool(b) => Ok(LuaValue::Boolean(*b)),
        JsonValue::Number(n) => {
            if let Some(i) = n.as_i64() {
                Ok(LuaValue::Integer(i))
            } else if let Some(f) = n.as_f64() {
                Ok(LuaValue::Number(f))
            } else {
                Ok(LuaValue::Nil)
            }
        }
        JsonValue::String(s) => Ok(LuaValue::String(lua.create_string(s)?)),
        JsonValue::Array(arr) => {
            let tbl = lua.create_table()?;
            for (idx, item) in arr.iter().enumerate() {
                tbl.raw_set(idx + 1, json_to_lua(lua, item)?)?;
            }
            Ok(LuaValue::Table(tbl))
        }
        JsonValue::Object(obj) => {
            let tbl = lua.create_table()?;
            for (k, v) in obj {
                tbl.set(k.as_str(), json_to_lua(lua, v)?)?;
            }
            Ok(LuaValue::Table(tbl))
        }
    }
}

/// Binds `Zenith.Storage` table into the given Zenith table.
pub fn setup_storage_bindings(
    lua: &Lua,
    zenith_table: &LuaTable,
    engine: Arc<StorageEngine>,
) -> Result<(), LuaError> {
    let storage_table = lua.create_table()?;

    // Zenith.Storage.get(key, default)
    let eng_get = Arc::clone(&engine);
    let get_fn = lua.create_function(move |lua, (key, default_val): (String, Option<LuaValue>)| {
        if let Some(json_val) = eng_get.get(&key) {
            json_to_lua(lua, &json_val)
        } else {
            Ok(default_val.unwrap_or(LuaValue::Nil))
        }
    })?;
    storage_table.set("get", get_fn)?;

    // Zenith.Storage.set(key, val)
    let eng_set = Arc::clone(&engine);
    let set_fn = lua.create_function(move |_, (key, val): (String, LuaValue)| {
        let json_val = lua_to_json(val);
        if let Err(e) = eng_set.set(&key, json_val) {
            error!("Zenith.Storage failed to persist key '{}': {}", key, e);
        }
        Ok(())
    })?;
    storage_table.set("set", set_fn)?;

    // Zenith.Storage.has(key)
    let eng_has = Arc::clone(&engine);
    let has_fn = lua.create_function(move |_, key: String| {
        Ok(eng_has.has(&key))
    })?;
    storage_table.set("has", has_fn)?;

    // Zenith.Storage.remove(key)
    let eng_rem = Arc::clone(&engine);
    let remove_fn = lua.create_function(move |_, key: String| {
        let _ = eng_rem.remove(&key);
        Ok(())
    })?;
    storage_table.set("remove", remove_fn.clone())?;
    storage_table.set("delete", remove_fn)?;

    // Zenith.Storage.clear()
    let eng_clr = Arc::clone(&engine);
    let clear_fn = lua.create_function(move |_, ()| {
        let _ = eng_clr.clear();
        Ok(())
    })?;
    storage_table.set("clear", clear_fn)?;

    // Zenith.Storage.all()
    let eng_all = Arc::clone(&engine);
    let all_fn = lua.create_function(move |lua, ()| {
        let data = eng_all.all();
        let tbl = lua.create_table()?;
        for (k, v) in data {
            tbl.set(k.as_str(), json_to_lua(lua, &v)?)?;
        }
        Ok(tbl)
    })?;
    storage_table.set("all", all_fn)?;

    // Zenith.Storage.sync_to_config()
    let eng_sync = Arc::clone(&engine);
    let sync_fn = lua.create_function(move |_, ()| {
        let _ = eng_sync.sync_to_config();
        Ok(())
    })?;
    storage_table.set("sync_to_config", sync_fn)?;

    // Zenith.Storage.reload_from_config()
    let eng_reload = Arc::clone(&engine);
    let reload_fn = lua.create_function(move |_, ()| {
        let _ = eng_reload.reload_from_config();
        Ok(())
    })?;
    storage_table.set("reload_from_config", reload_fn)?;

    zenith_table.set("Storage", storage_table.clone())?;
    zenith_table.set("storage", storage_table)?;

    info!("Zenith.Storage engine initialized at {}", engine.file_path.display());
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_storage_engine_crud() {
        let temp_dir = std::env::temp_dir().join(format!("zenith_test_storage_{}", std::process::id()));
        let file_path = temp_dir.join("storage.json");

        let engine = StorageEngine::new(Some(file_path.clone())).with_config_path(None);
        assert!(!engine.has("theme"));

        engine.set("theme", JsonValue::String("catppuccin".into())).unwrap();
        assert!(engine.has("theme"));
        assert_eq!(engine.get("theme").unwrap(), JsonValue::String("catppuccin".into()));

        engine.flush().unwrap();
        // Persistence check via new instance
        let loaded_engine = StorageEngine::new(Some(file_path.clone())).with_config_path(None);
        assert_eq!(loaded_engine.get("theme").unwrap(), JsonValue::String("catppuccin".into()));

        assert!(loaded_engine.remove("theme").unwrap());
        assert!(!loaded_engine.has("theme"));

        let _ = fs::remove_dir_all(temp_dir);
    }

    #[test]
    fn test_storage_luau_binding() -> Result<(), LuaError> {
        let temp_dir = std::env::temp_dir().join(format!("zenith_test_lua_storage_{}", std::process::id()));
        let file_path = temp_dir.join("storage.json");

        let engine = Arc::new(StorageEngine::new(Some(file_path)).with_config_path(None));
        let lua = Lua::new();
        let zenith_tbl = lua.create_table()?;

        setup_storage_bindings(&lua, &zenith_tbl, engine)?;
        lua.globals().set("Zenith", zenith_tbl)?;

        let script = r#"
            Zenith.Storage.set("counter", 42)
            Zenith.Storage.set("accent", "lavender")
            local c = Zenith.Storage.get("counter", 0)
            local a = Zenith.Storage.get("accent", "default")
            local def = Zenith.Storage.get("missing", "fallback")
            return c, a, def
        "#;

        let (c, a, def): (i64, String, String) = lua.load(script).eval()?;
        assert_eq!(c, 42);
        assert_eq!(a, "lavender");
        assert_eq!(def, "fallback");

        let _ = fs::remove_dir_all(temp_dir);
        Ok(())
    }

    #[test]
    fn test_storage_bidirectional_config_json_sync() {
        let temp_dir = std::env::temp_dir().join(format!("zenith_test_cfg_sync_{}", std::process::id()));
        let _ = fs::create_dir_all(&temp_dir);
        let storage_file = temp_dir.join("storage.json");
        let config_file = temp_dir.join("config.json");

        let initial_cfg = serde_json::json!({
            "quick": {
                "accentColor": "#fcbc00",
                "darkMode": true,
                "barAutoHide": true
            },
            "appearance": {
                "accentColor": "#fcbc00",
                "springStiffness": 4.0
            },
            "bar": {
                "height": 44,
                "autoHide": true
            }
        });
        fs::write(&config_file, serde_json::to_string_pretty(&initial_cfg).unwrap()).unwrap();

        // 1. StorageEngine initializes and absorbs config.json values
        let engine = StorageEngine::new(Some(storage_file.clone()))
            .with_config_path(Some(config_file.clone()));

        assert_eq!(engine.get("accentColor").unwrap(), JsonValue::String("#fcbc00".into()));
        assert_eq!(engine.get("quick.accentColor").unwrap(), JsonValue::String("#fcbc00".into()));
        assert_eq!(engine.get("barHeight").unwrap(), JsonValue::from(44));
        assert_eq!(engine.get("barAutoHide").unwrap(), JsonValue::Bool(true));

        // 2. Modify value in storage and sync back to config.json
        engine.set("accentColor", JsonValue::String("#7aa2f7".into())).unwrap();
        engine.set("barHeight", JsonValue::from(48)).unwrap();
        engine.sync_to_config().unwrap();

        // 3. Inspect modified config.json on disk
        let disk_content = fs::read_to_string(&config_file).unwrap();
        let parsed: JsonValue = serde_json::from_str(&disk_content).unwrap();

        assert_eq!(parsed["quick"]["accentColor"], "#7aa2f7");
        assert_eq!(parsed["appearance"]["accentColor"], "#7aa2f7");
        assert_eq!(parsed["bar"]["height"], 48);

        let _ = fs::remove_dir_all(temp_dir);
    }
}
