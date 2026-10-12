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

/// Local storage engine handling key-value state persistence.
pub struct StorageEngine {
    file_path: PathBuf,
    cache: Arc<RwLock<HashMap<String, JsonValue>>>,
}

impl StorageEngine {
    /// Initialize storage engine from default or explicit file path.
    pub fn new(custom_path: Option<PathBuf>) -> Self {
        let file_path = custom_path.unwrap_or_else(Self::default_storage_path);
        let mut initial_data = HashMap::new();

        if file_path.exists() {
            if let Ok(content) = fs::read_to_string(&file_path) {
                if let Ok(parsed) = serde_json::from_str::<HashMap<String, JsonValue>>(&content) {
                    initial_data = parsed;
                }
            }
        }

        Self {
            file_path,
            cache: Arc::new(RwLock::new(initial_data)),
        }
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

    /// Sets a value for key and persists atomically to disk.
    pub fn set(&self, key: &str, val: JsonValue) -> Result<(), std::io::Error> {
        {
            let mut writer = self.cache.write().unwrap();
            writer.insert(key.to_string(), val);
        }
        self.flush_atomic()
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
            self.flush_atomic()?;
        }
        Ok(removed)
    }

    /// Clears all keys from storage.
    pub fn clear(&self) -> Result<(), std::io::Error> {
        {
            let mut writer = self.cache.write().unwrap();
            writer.clear();
        }
        self.flush_atomic()
    }

    /// Returns a copy of all stored key-value pairs.
    pub fn all(&self) -> HashMap<String, JsonValue> {
        self.cache.read().unwrap().clone()
    }

    /// Atomically flushes the cache to disk via temporary file rename.
    fn flush_atomic(&self) -> Result<(), std::io::Error> {
        if let Some(parent) = self.file_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let temp_path = self.file_path.with_extension("tmp");
        let json_str = {
            let reader = self.cache.read().unwrap();
            serde_json::to_string_pretty(&*reader)
                .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?
        };

        {
            let mut file = File::create(&temp_path)?;
            file.write_all(json_str.as_bytes())?;
            file.sync_all()?;
        }

        fs::rename(&temp_path, &self.file_path)?;
        Ok(())
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
                for pair in tbl.pairs::<String, LuaValue>() {
                    if let Ok((k, v)) = pair {
                        map.insert(k, lua_to_json(v));
                    }
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

        let engine = StorageEngine::new(Some(file_path.clone()));
        assert!(!engine.has("theme"));

        engine.set("theme", JsonValue::String("catppuccin".into())).unwrap();
        assert!(engine.has("theme"));
        assert_eq!(engine.get("theme").unwrap(), JsonValue::String("catppuccin".into()));

        // Persistence check via new instance
        let loaded_engine = StorageEngine::new(Some(file_path.clone()));
        assert_eq!(loaded_engine.get("theme").unwrap(), JsonValue::String("catppuccin".into()));

        assert!(loaded_engine.remove("theme").unwrap());
        assert!(!loaded_engine.has("theme"));

        let _ = fs::remove_dir_all(temp_dir);
    }

    #[test]
    fn test_storage_luau_binding() -> Result<(), LuaError> {
        let temp_dir = std::env::temp_dir().join(format!("zenith_test_lua_storage_{}", std::process::id()));
        let file_path = temp_dir.join("storage.json");

        let engine = Arc::new(StorageEngine::new(Some(file_path)));
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
}
