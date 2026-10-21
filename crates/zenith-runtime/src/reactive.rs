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
    static BATCH_DEPTH: RefCell<usize> = const { RefCell::new(0) };
    static PENDING_CHANGES: RefCell<Vec<(SignalId, SignalValue)>> = const { RefCell::new(Vec::new()) };
}

/// Strongly-typed signal value avoiding heap string conversions and parsing in animation hot paths.
#[derive(Debug, Clone, PartialEq)]
pub enum SignalValue {
    Float(f32),
    Text(String),
    Color(zenith_layout::Color),
    Boolean(bool),
}

impl SignalValue {
    #[inline]
    pub fn as_f32(&self) -> Option<f32> {
        match self {
            SignalValue::Float(f) => Some(*f),
            SignalValue::Text(s) => s.trim().parse::<f32>().ok(),
            SignalValue::Boolean(b) => Some(if *b { 1.0 } else { 0.0 }),
            SignalValue::Color(_) => None,
        }
    }

    #[inline]
    pub fn as_str(&self) -> std::borrow::Cow<'_, str> {
        match self {
            SignalValue::Text(s) => std::borrow::Cow::Borrowed(s.as_str()),
            SignalValue::Float(f) => std::borrow::Cow::Owned(f.to_string()),
            SignalValue::Boolean(b) => std::borrow::Cow::Borrowed(if *b { "true" } else { "false" }),
            SignalValue::Color(_) => std::borrow::Cow::Borrowed(""),
        }
    }

    #[inline]
    pub fn as_color(&self) -> Option<zenith_layout::Color> {
        match self {
            SignalValue::Color(c) => Some(*c),
            SignalValue::Text(s) => ReactiveGraph::parse_color_str(s),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum BoundProperty {
    Text,
    Color,
    Background,
    Width,
    Height,
    Opacity,
    Scale,
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
    signal_values: RwLock<HashMap<SignalId, SignalValue>>,
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

    /// Runs a subscriber effect by its ID safely in the Lua context.
    fn run_effect(&self, lua: &Lua, effect_id: EffectId) {
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

    /// Accesses the mounted tree root by reference without cloning, executing `f` under a read lock.
    pub fn with_tree<F, R>(&self, tree_id: &str, f: F) -> Option<R>
    where
        F: FnOnce(&UiNode) -> R,
    {
        let trees = self.mounted_trees.read().unwrap();
        trees.get(tree_id).map(|t| f(&t.root))
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

    /// Batches multiple signal mutations together, coalescing node property updates
    /// and running subscriber effects only once after the batch closure completes.
    pub fn batch<F, R>(&self, lua: &Lua, f: F) -> LuaResult<R>
    where
        F: FnOnce() -> LuaResult<R>,
    {
        BATCH_DEPTH.with(|d| {
            let mut depth = d.borrow_mut();
            *depth += 1;
        });

        let result = f();

        let is_outermost = BATCH_DEPTH.with(|d| {
            let mut depth = d.borrow_mut();
            *depth = depth.saturating_sub(1);
            *depth == 0
        });

        if is_outermost {
            let pending = PENDING_CHANGES.with(|p| std::mem::take(&mut *p.borrow_mut()));
            if !pending.is_empty() {
                // Deduplicate changes by SignalId (keep latest value)
                let mut latest_by_signal = HashMap::new();
                for (sig_id, val) in pending {
                    latest_by_signal.insert(sig_id, val);
                }

                let mut affected_effects = std::collections::HashSet::new();

                for (&sig_id, val) in &latest_by_signal {
                    self.signal_values.write().unwrap().insert(sig_id, val.clone());

                    let bindings = {
                        let b = self.node_bindings.read().unwrap();
                        b.get(&sig_id).cloned().unwrap_or_default()
                    };

                    if !bindings.is_empty() {
                        let mut trees = self.mounted_trees.write().unwrap();
                        for binding in bindings {
                            if let Some(tree) = trees.get_mut(&binding.tree_id) {
                                Self::update_node_at_path(&mut tree.root, &binding.node_path, &binding.property, val);
                                tree.is_dirty = true;
                                tree.version = tree.version.wrapping_add(1);
                            }
                        }
                    }

                    let subs = self.subscribers.read().unwrap();
                    if let Some(effects) = subs.get(&sig_id) {
                        for &eff_id in effects {
                            affected_effects.insert(eff_id);
                        }
                    }
                }

                // Execute coalesced unique subscriber effects
                for eff_id in affected_effects {
                    self.run_effect(lua, eff_id);
                }
            }
        }

        result
    }

    /// Notifies the graph that a signal value has changed.
    /// Updates bound node properties in-place without AST re-parsing,
    /// marks affected mounted trees dirty, and runs subscriber effects.
    pub fn notify_signal_change(&self, lua: &Lua, signal_id: SignalId, new_val_str: &str) {
        self.notify_signal_value_change(lua, signal_id, SignalValue::Text(new_val_str.to_string()));
    }

    /// High-performance typed signal notification avoiding intermediate string formatting and parsing.
    pub fn notify_signal_value_change(&self, lua: &Lua, signal_id: SignalId, val: SignalValue) {
        let in_batch = BATCH_DEPTH.with(|d| *d.borrow() > 0);
        if in_batch {
            PENDING_CHANGES.with(|p| {
                p.borrow_mut().push((signal_id, val));
            });
            return;
        }

        self.apply_signal_value_change(lua, signal_id, val);
    }

    fn apply_signal_value_change(&self, lua: &Lua, signal_id: SignalId, val: SignalValue) {
        // 1. Update cached value in Rust
        self.signal_values.write().unwrap().insert(signal_id, val.clone());

        // 2. Update bound nodes in mounted trees in-place
        let bindings = {
            let b = self.node_bindings.read().unwrap();
            b.get(&signal_id).cloned().unwrap_or_default()
        };

        if !bindings.is_empty() {
            let mut trees = self.mounted_trees.write().unwrap();
            for binding in bindings {
                if let Some(tree) = trees.get_mut(&binding.tree_id) {
                    Self::update_node_at_path(&mut tree.root, &binding.node_path, &binding.property, &val);
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
            self.run_effect(lua, effect_id);
        }
    }

    pub fn parse_color_str(val: &str) -> Option<zenith_layout::Color> {
        let s = val.trim();
        if let Some(hex) = s.strip_prefix('#') {
            match hex.len() {
                6 => {
                    let r = u8::from_str_radix(&hex[0..2], 16).ok()?;
                    let g = u8::from_str_radix(&hex[2..4], 16).ok()?;
                    let b = u8::from_str_radix(&hex[4..6], 16).ok()?;
                    Some(zenith_layout::Color::rgb(r, g, b))
                }
                8 => {
                    let r = u8::from_str_radix(&hex[0..2], 16).ok()?;
                    let g = u8::from_str_radix(&hex[2..4], 16).ok()?;
                    let b = u8::from_str_radix(&hex[4..6], 16).ok()?;
                    let a = u8::from_str_radix(&hex[6..8], 16).ok()?;
                    Some(zenith_layout::Color::rgba(r, g, b, a))
                }
                _ => None,
            }
        } else {
            None
        }
    }

    fn get_node_style_mut(node: &mut UiNode) -> Option<&mut zenith_layout::NodeStyle> {
        match node {
            UiNode::Box { style, .. } => Some(style),
            UiNode::Text { style, .. } => Some(style),
            UiNode::TextInput { style, .. } => Some(style),
            UiNode::Image { style, .. } => Some(style),
            UiNode::Shader { style, .. } => Some(style),
            UiNode::Slider { style, .. } => Some(style),
            UiNode::Switch { style, .. } => Some(style),
            UiNode::Window { style, .. } => Some(style),
        }
    }

    fn update_node_at_path(node: &mut UiNode, path: &[usize], property: &BoundProperty, val: &SignalValue) {
        if path.is_empty() {
            match property {
                BoundProperty::Text => match node {
                    UiNode::Text { text, .. } => *text = val.as_str().into_owned(),
                    UiNode::TextInput { text, .. } => *text = val.as_str().into_owned(),
                    _ => {}
                },
                BoundProperty::Color => match node {
                    UiNode::Text { color, .. } => {
                        if let Some(c) = val.as_color() {
                            *color = c;
                        }
                    }
                    _ => {}
                },
                BoundProperty::Background => {
                    if let (Some(style), Some(c)) = (Self::get_node_style_mut(node), val.as_color()) {
                        style.background_color = c;
                    }
                }
                BoundProperty::Width => {
                    if let Some(style) = Self::get_node_style_mut(node) {
                        if let Some(w) = val.as_f32() {
                            style.width = Some(zenith_layout::length(w));
                        }
                    }
                }
                BoundProperty::Height => {
                    if let Some(style) = Self::get_node_style_mut(node) {
                        if let Some(h) = val.as_f32() {
                            style.height = Some(zenith_layout::length(h));
                        }
                    }
                }
                BoundProperty::Opacity => {
                    if let Some(style) = Self::get_node_style_mut(node) {
                        if let Some(op) = val.as_f32() {
                            style.opacity = Some(op);
                        }
                    }
                }
                BoundProperty::Scale => {
                    if let Some(style) = Self::get_node_style_mut(node) {
                        if let Some(sc) = val.as_f32() {
                            style.scale = Some(sc);
                        }
                    }
                }
            }
            return;
        }

        match node {
            UiNode::Box { children, .. } | UiNode::Window { children, .. } => {
                let idx = path[0];
                if let Some(child) = children.get_mut(idx) {
                    Self::update_node_at_path(child, &path[1..], property, val);
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

    #[test]
    fn test_zero_ast_inplace_property_updates() {
        let graph = ReactiveGraph::new();
        let sig_w = ReactiveGraph::next_signal_id();
        let sig_h = ReactiveGraph::next_signal_id();
        let sig_op = ReactiveGraph::next_signal_id();
        let sig_sc = ReactiveGraph::next_signal_id();

        let root = UiNode::Box {
            style: zenith_layout::NodeStyle {
                width: Some(zenith_layout::length(100.0)),
                height: Some(zenith_layout::length(40.0)),
                opacity: Some(1.0),
                scale: Some(1.0),
                ..Default::default()
            },
            children: vec![],
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
        };

        graph.mount_tree("dock", root);
        graph.bind_node(sig_w, NodeBinding {
            tree_id: "dock".to_string(),
            node_path: vec![],
            property: BoundProperty::Width,
        });
        graph.bind_node(sig_h, NodeBinding {
            tree_id: "dock".to_string(),
            node_path: vec![],
            property: BoundProperty::Height,
        });
        graph.bind_node(sig_op, NodeBinding {
            tree_id: "dock".to_string(),
            node_path: vec![],
            property: BoundProperty::Opacity,
        });
        graph.bind_node(sig_sc, NodeBinding {
            tree_id: "dock".to_string(),
            node_path: vec![],
            property: BoundProperty::Scale,
        });

        graph.mark_tree_clean("dock");
        assert!(!graph.is_tree_dirty("dock"));

        let lua = Lua::new();
        graph.notify_signal_change(&lua, sig_w, "144.5");
        graph.notify_signal_change(&lua, sig_h, "58.0");
        graph.notify_signal_change(&lua, sig_op, "0.85");
        graph.notify_signal_change(&lua, sig_sc, "1.45");

        assert!(graph.is_tree_dirty("dock"));
        let updated = graph.get_tree("dock").unwrap();
        match updated {
            UiNode::Box { style, .. } => {
                assert_eq!(style.width, Some(zenith_layout::length(144.5)));
                assert_eq!(style.height, Some(zenith_layout::length(58.0)));
                assert_eq!(style.opacity, Some(0.85));
                assert_eq!(style.scale, Some(1.45));
            }
            _ => panic!("Expected UiNode::Box"),
        }
    }

    #[test]
    fn test_batch_coalescence() -> LuaResult<()> {
        let graph = Arc::new(ReactiveGraph::new());
        let sig = ReactiveGraph::next_signal_id();

        let root = UiNode::Box {
            style: zenith_layout::NodeStyle::default(),
            children: vec![],
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
        };

        graph.mount_tree("test_tree", root);
        graph.bind_node(sig, NodeBinding {
            tree_id: "test_tree".to_string(),
            node_path: vec![],
            property: BoundProperty::Width,
        });

        let lua = Lua::new();
        let counter = Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let c_clone = counter.clone();

        let g_clone = graph.clone();
        let cb = lua.create_function(move |_, ()| {
            g_clone.track_access(sig);
            c_clone.fetch_add(1, Ordering::Relaxed);
            Ok(())
        })?;

        graph.register_effect(&lua, cb)?;
        // Initial effect execution happened during registration: counter == 1
        assert_eq!(counter.load(Ordering::Relaxed), 1);

        // Run batch with multiple rapid mutations
        graph.batch(&lua, || {
            graph.notify_signal_change(&lua, sig, "50.0");
            graph.notify_signal_change(&lua, sig, "75.0");
            graph.notify_signal_change(&lua, sig, "120.0");
            Ok(())
        })?;

        // Effect ran exactly once for the batch
        assert_eq!(counter.load(Ordering::Relaxed), 2);

        // Final width matches last mutation
        let tree = graph.get_tree("test_tree").unwrap();
        match tree {
            UiNode::Box { style, .. } => assert_eq!(style.width, Some(zenith_layout::length(120.0))),
            _ => panic!("Expected UiNode::Box"),
        }

        Ok(())
    }
}
