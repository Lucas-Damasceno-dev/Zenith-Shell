//! Fine-grained reactive signals and persistent node tree cache for Zenith Base v3.
//! Implements SolidJS / Leptos style signals and effects with zero AST re-parsing.

use std::cell::RefCell;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, RwLock};
use mlua::{Function, Lua, RegistryKey, Result as LuaResult};
use zenith_layout::UiNode;

pub type SignalId = u64;
pub type EffectId = u64;

static NEXT_SIGNAL_ID: AtomicU64 = AtomicU64::new(1);
static NEXT_EFFECT_ID: AtomicU64 = AtomicU64::new(1);

thread_local! {
    static ACTIVE_EFFECT: RefCell<Option<EffectId>> = const { RefCell::new(None) };
    static CURRENT_MOUNTING_TREE: RefCell<Option<String>> = const { RefCell::new(None) };
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum BoundProperty {
    Text,
    Color,
    Background,
}

#[derive(Debug, Clone)]
pub struct NodeBinding {
    pub tree_id: String,
    pub node_path: Vec<usize>,
    pub property: BoundProperty,
}

#[derive(Clone)]
pub struct MountedTree {
    pub root: UiNode,
    pub is_dirty: bool,
    pub version: u64,
}

pub struct ReactiveGraph {
    /// Mapping of SignalId -> list of subscriber EffectIds
    subscribers: RwLock<HashMap<SignalId, Vec<EffectId>>>,
    /// Mapping of EffectId -> RegistryKey of Lua callback function
    effects: RwLock<HashMap<EffectId, Arc<RegistryKey>>>,
    /// Mapping of SignalId -> Node bindings in mounted UiNode trees
    node_bindings: RwLock<HashMap<SignalId, Vec<NodeBinding>>>,
    /// Mounted UI trees by name (e.g., "bar", "dock", "popup")
    mounted_trees: RwLock<HashMap<String, MountedTree>>,
    /// Signal values cached in Rust
    signal_values: RwLock<HashMap<SignalId, String>>,
}

impl Default for ReactiveGraph {
    fn default() -> Self {
        Self::new()
    }
}

impl ReactiveGraph {
    pub fn new() -> Self {
        Self {
            subscribers: RwLock::new(HashMap::new()),
            effects: RwLock::new(HashMap::new()),
            node_bindings: RwLock::new(HashMap::new()),
            mounted_trees: RwLock::new(HashMap::new()),
            signal_values: RwLock::new(HashMap::new()),
        }
    }

    pub fn next_signal_id() -> SignalId {
        NEXT_SIGNAL_ID.fetch_add(1, Ordering::Relaxed)
    }

    pub fn next_effect_id() -> EffectId {
        NEXT_EFFECT_ID.fetch_add(1, Ordering::Relaxed)
    }

    /// Records dependency between currently running effect and the accessed signal.
    pub fn track_access(&self, signal_id: SignalId) {
        ACTIVE_EFFECT.with(|eff| {
            if let Some(effect_id) = *eff.borrow() {
                let mut subs = self.subscribers.write().unwrap();
                let list = subs.entry(signal_id).or_default();
                if !list.contains(&effect_id) {
                    list.push(effect_id);
                }
            }
        });
    }

    /// Registers an effect and executes it immediately within an active effect scope.
    pub fn register_effect(&self, lua: &Lua, callback: Function) -> LuaResult<EffectId> {
        let effect_id = Self::next_effect_id();
        let key = lua.create_registry_value(callback.clone())?;

        self.effects.write().unwrap().insert(effect_id, Arc::new(key));

        // Run effect callback immediately with tracking enabled
        ACTIVE_EFFECT.with(|eff| {
            *eff.borrow_mut() = Some(effect_id);
        });

        let res = callback.call::<()>(());

        ACTIVE_EFFECT.with(|eff| {
            *eff.borrow_mut() = None;
        });

        res?;
        Ok(effect_id)
    }

    /// Binds a specific node in a mounted UI tree to a signal.
    pub fn bind_node(&self, signal_id: SignalId, binding: NodeBinding) {
        let mut bindings = self.node_bindings.write().unwrap();
        bindings.entry(signal_id).or_default().push(binding);
    }

    /// Stores current tree under tree_id and resets dirty flag.
    pub fn mount_tree(&self, tree_id: &str, root: UiNode) {
        let mut trees = self.mounted_trees.write().unwrap();
        trees.insert(
            tree_id.to_string(),
            MountedTree {
                root,
                is_dirty: true,
                version: 1,
            },
        );
    }

    /// Retrieves the current mounted tree root, if present.
    pub fn get_tree(&self, tree_id: &str) -> Option<UiNode> {
        let trees = self.mounted_trees.read().unwrap();
        trees.get(tree_id).map(|t| t.root.clone())
    }

    /// Checks whether a tree has been marked dirty by signal mutations.
    pub fn is_tree_dirty(&self, tree_id: &str) -> bool {
        let trees = self.mounted_trees.read().unwrap();
        trees.get(tree_id).map(|t| t.is_dirty).unwrap_or(true)
    }

    /// Clears the dirty flag after rendering a frame.
    pub fn mark_tree_clean(&self, tree_id: &str) {
        let mut trees = self.mounted_trees.write().unwrap();
        if let Some(t) = trees.get_mut(tree_id) {
            t.is_dirty = false;
        }
    }

    /// Notifies the graph that a signal value has changed.
    /// Updates bound node properties in-place without AST re-parsing,
    /// marks affected mounted trees dirty, and runs subscriber effects.
    pub fn notify_signal_change(&self, lua: &Lua, signal_id: SignalId, new_val_str: &str) {
        // 1. Update cached value in Rust
        self.signal_values.write().unwrap().insert(signal_id, new_val_str.to_string());

        // 2. Update bound nodes in mounted trees in-place
        let bindings = {
            let b = self.node_bindings.read().unwrap();
            b.get(&signal_id).cloned().unwrap_or_default()
        };

        if !bindings.is_empty() {
            let mut trees = self.mounted_trees.write().unwrap();
            for binding in bindings {
                if let Some(tree) = trees.get_mut(&binding.tree_id) {
                    Self::update_node_at_path(&mut tree.root, &binding.node_path, &binding.property, new_val_str);
                    tree.is_dirty = true;
                    tree.version = tree.version.wrapping_add(1);
                }
            }
        }

        // 3. Trigger subscriber effects
        let effect_ids = {
            let subs = self.subscribers.read().unwrap();
            subs.get(&signal_id).cloned().unwrap_or_default()
        };

        for effect_id in effect_ids {
            let maybe_key = {
                let effs = self.effects.read().unwrap();
                effs.get(&effect_id).cloned()
            };

            if let Some(key) = maybe_key {
                if let Ok(func) = lua.registry_value::<Function>(&key) {
                    ACTIVE_EFFECT.with(|eff| {
                        *eff.borrow_mut() = Some(effect_id);
                    });

                    if let Err(e) = func.call::<()>(()) {
                        tracing::error!("Error executing reactive effect {}: {}", effect_id, e);
                    }

                    ACTIVE_EFFECT.with(|eff| {
                        *eff.borrow_mut() = None;
                    });
                }
            }
        }
    }

    fn update_node_at_path(node: &mut UiNode, path: &[usize], property: &BoundProperty, new_val: &str) {
        if path.is_empty() {
            if *property == BoundProperty::Text {
                match node {
                    UiNode::Text { text, .. } => *text = new_val.to_string(),
                    UiNode::TextInput { text, .. } => *text = new_val.to_string(),
                    _ => {}
                }
            }
            return;
        }

        match node {
            UiNode::Box { children, .. } | UiNode::Window { children, .. } => {
                let idx = path[0];
                if let Some(child) = children.get_mut(idx) {
                    Self::update_node_at_path(child, &path[1..], property, new_val);
                }
            }
            _ => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_reactive_graph_default() {
        let graph = ReactiveGraph::default();
        assert!(graph.get_tree("nonexistent").is_none());
    }
}
