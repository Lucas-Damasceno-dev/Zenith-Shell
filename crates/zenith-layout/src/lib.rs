//! Zenith Layout - Taffy Flexbox tree and cosmic-text layout calculations.

use taffy::prelude::*;
pub use taffy::style::ExpandedDimension;
pub use taffy::prelude::{AlignItems, Dimension, FlexDirection, JustifyContent, auto, length, percent};

/// Color representation in RGBA (0-255).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

impl Color {
    pub const fn rgba(r: u8, g: u8, b: u8, a: u8) -> Self {
        Self { r, g, b, a }
    }

    pub const fn rgb(r: u8, g: u8, b: u8) -> Self {
        Self { r, g, b, a: 255 }
    }

    pub const fn transparent() -> Self {
        Self { r: 0, g: 0, b: 0, a: 0 }
    }

    pub fn to_argb_u32(self) -> u32 {
        ((self.a as u32) << 24)
            | ((self.r as u32) << 16)
            | ((self.g as u32) << 8)
            | (self.b as u32)
    }
}

/// Viewport overflow behavior.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Overflow {
    #[default]
    Visible,
    Hidden,
    Scroll,
}

/// Layer-shell window surface placement metadata.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct WindowMeta {
    pub anchor_top: bool,
    pub anchor_bottom: bool,
    pub anchor_left: bool,
    pub anchor_right: bool,
    pub margin_top: i32,
    pub margin_right: i32,
    pub margin_bottom: i32,
    pub margin_left: i32,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub layer: Option<String>,
    pub exclusive_zone: Option<i32>,
    pub keyboard_mode: Option<String>,
}

pub mod editor;
pub use editor::{CursorDirection, TextEditorEngine};

/// Computed text input parameters for Wayland focus and text rendering.
#[derive(Debug, Clone, PartialEq)]
pub struct ComputedTextInput {
    pub id: Option<String>,
    pub text: String,
    pub placeholder: String,
    pub font_size: f32,
    pub color: Color,
    pub placeholder_color: Color,
    pub active: bool,
    pub cursor_pos: usize,
    pub selection_range: Option<(usize, usize)>,
    pub cursor_offset_x: f32,
    pub selection_rect: Option<(f32, f32, f32, f32)>,
    pub on_change: Option<String>,
    pub on_submit: Option<String>,
}

/// Computed slider parameters for interactive range controls.
#[derive(Debug, Clone, PartialEq)]
pub struct ComputedSlider {
    pub id: Option<String>,
    pub min: f32,
    pub max: f32,
    pub value: f32,
    pub track_height: f32,
    pub thumb_radius: f32,
    pub track_color: Color,
    pub active_track_color: Color,
    pub thumb_color: Color,
    pub on_change: Option<String>,
}

/// Computed switch parameters for animated toggle controls.
#[derive(Debug, Clone, PartialEq)]
pub struct ComputedSwitch {
    pub id: Option<String>,
    pub checked: bool,
    pub active_color: Color,
    pub inactive_color: Color,
    pub thumb_color: Color,
    pub on_toggle: Option<String>,
}

/// Shadow parameters for vector drop shadows.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ShadowStyle {
    pub color: Color,
    pub blur: f32,
    pub offset_x: f32,
    pub offset_y: f32,
}

/// Custom GLSL ES 3.0 fragment shader style.
#[derive(Debug, Clone, PartialEq)]
pub struct CustomShaderStyle {
    pub fragment: String,
    pub uniforms: Vec<(String, f32)>,
}

/// Node style properties for Zenith UI elements.
#[derive(Debug, Clone, PartialEq)]
pub struct NodeStyle {
    pub width: Option<Dimension>,
    pub height: Option<Dimension>,
    pub padding: [f32; 4], // top, right, bottom, left
    pub margin: [f32; 4],
    pub flex_direction: FlexDirection,
    pub justify_content: Option<JustifyContent>,
    pub align_items: Option<AlignItems>,
    pub gap: f32,
    pub background_color: Color,
    pub border_color: Color,
    pub border_width: f32,
    pub border_radius: f32,
    pub flex_grow: f32,
    pub flex_shrink: f32,
    pub max_width: Option<Dimension>,
    pub shadow: Option<ShadowStyle>,
    pub custom_shader: Option<CustomShaderStyle>,
    pub overflow: Overflow,
    pub scroll_offset_y: f32,
    pub opacity: Option<f32>,
    pub scale: Option<f32>,
}


impl Default for NodeStyle {
    fn default() -> Self {
        Self {
            width: None,
            height: None,
            padding: [0.0; 4],
            margin: [0.0; 4],
            flex_direction: FlexDirection::Row,
            justify_content: None,
            align_items: Some(AlignItems::CENTER),
            gap: 0.0,
            background_color: Color::transparent(),
            border_color: Color::transparent(),
            border_width: 0.0,
            border_radius: 0.0,
            flex_grow: 0.0,
            flex_shrink: 1.0,
            max_width: None,
            shadow: None,
            custom_shader: None,
            overflow: Overflow::Visible,
            scroll_offset_y: 0.0,
            opacity: None,
            scale: None,
        }
    }
}

/// Abstract representation of a UI element.
#[derive(Debug, Clone, PartialEq)]
pub enum UiNode {
    Box {
        style: NodeStyle,
        children: Vec<UiNode>,
        on_click: Option<String>,
        on_right_click: Option<String>,
        on_scroll_up: Option<String>,
        on_scroll_down: Option<String>,
        tooltip: Option<String>,
    },
    Text {
        text: String,
        font_size: f32,
        color: Color,
        style: NodeStyle,
    },
    TextInput {
        id: Option<String>,
        text: String,
        placeholder: String,
        font_size: f32,
        color: Color,
        placeholder_color: Color,
        active: bool,
        cursor_pos: usize,
        selection_range: Option<(usize, usize)>,
        style: NodeStyle,
        on_change: Option<String>,
        on_submit: Option<String>,
    },
    Image {
        src: String,
        style: NodeStyle,
    },
    Shader {
        fragment: String,
        uniforms: Vec<(String, f32)>,
        style: NodeStyle,
    },
    Slider {
        id: Option<String>,
        min: f32,
        max: f32,
        value: f32,
        track_height: f32,
        thumb_radius: f32,
        track_color: Color,
        active_track_color: Color,
        thumb_color: Color,
        style: NodeStyle,
        on_change: Option<String>,
    },
    Switch {
        id: Option<String>,
        checked: bool,
        active_color: Color,
        inactive_color: Color,
        thumb_color: Color,
        style: NodeStyle,
        on_toggle: Option<String>,
    },
    Window {
        meta: WindowMeta,
        style: NodeStyle,
        children: Vec<UiNode>,
    },
}

impl UiNode {
    pub fn window_meta(&self) -> Option<&WindowMeta> {
        match self {
            UiNode::Window { meta, .. } => Some(meta),
            _ => None,
        }
    }
}

/// Computed geometry ready for rendering.
#[derive(Debug, Clone, PartialEq)]
pub struct ComputedBox {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub background_color: Color,
    pub border_color: Color,
    pub border_width: f32,
    pub border_radius: f32,
    pub shadow: Option<ShadowStyle>,
    pub custom_shader: Option<CustomShaderStyle>,
    pub text: Option<(String, Color, f32)>,
    pub image: Option<String>,
    pub text_input: Option<ComputedTextInput>,
    pub slider: Option<ComputedSlider>,
    pub switch: Option<ComputedSwitch>,
    pub overflow: Overflow,
    pub scroll_offset_y: f32,
    pub clip_rect: Option<[f32; 4]>,
    pub on_click: Option<String>,
    pub on_right_click: Option<String>,
    pub on_scroll_up: Option<String>,
    pub on_scroll_down: Option<String>,
    pub tooltip: Option<String>,
    pub tooltip_active: bool,
}

impl Default for ComputedBox {
    fn default() -> Self {
        Self {
            x: 0.0,
            y: 0.0,
            width: 0.0,
            height: 0.0,
            background_color: Color::transparent(),
            border_color: Color::transparent(),
            border_width: 0.0,
            border_radius: 0.0,
            shadow: None,
            custom_shader: None,
            text: None,
            image: None,
            text_input: None,
            slider: None,
            switch: None,
            overflow: Overflow::Visible,
            scroll_offset_y: 0.0,
            clip_rect: None,
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
            tooltip_active: false,
        }
    }
}

impl ComputedBox {
    /// Computes horizontal center of this box.
    #[inline]
    pub fn center_x(&self) -> f32 {
        self.x + self.width * 0.5
    }

    /// Computes vertical center of this box.
    #[inline]
    pub fn center_y(&self) -> f32 {
        self.y + self.height * 0.5
    }

    /// Scales box dimensions in-place, anchoring either to bottom shelf or center.
    pub fn apply_magnification_scale(&mut self, scale: f32, anchor_bottom: bool) {
        if (scale - 1.0).abs() < 0.0001 {
            return;
        }
        let original_w = self.width;
        let original_h = self.height;
        let new_w = original_w * scale;
        let new_h = original_h * scale;

        if anchor_bottom {
            let baseline = self.y + original_h;
            self.y = baseline - new_h;
        } else {
            self.y -= (new_h - original_h) * 0.5;
        }

        self.width = new_w;
        self.height = new_h;
        self.border_radius = (self.border_radius * scale).min(new_h * 0.5);
    }
}

/// Applies smooth in-place dock magnification across a sequence of computed item boxes.
///
/// Modifies box dimensions and horizontal positions in-place without triggering a full
/// Taffy flexbox re-layout pass, enabling sub-microsecond deformation at 120Hz/240Hz with
/// zero heap allocation.
pub fn apply_dock_magnification(
    boxes: &mut [ComputedBox],
    model: &zenith_core::MagnificationModel,
    pointer_x: Option<f32>,
    anchor_bottom: bool,
) {
    if boxes.is_empty() {
        return;
    }

    let n = boxes.len();
    if n == 1 {
        if let Some(px) = pointer_x {
            let scale = model.compute_scale(px, boxes[0].center_x());
            boxes[0].apply_magnification_scale(scale, anchor_bottom);
        }
        return;
    }

    // Detect if `boxes` is a hierarchical pre-order tree from LayoutEngine::compute
    // (where boxes[0] is the root DockBar container encompassing boxes[1..])
    let is_tree = n > 2
        && boxes[1].x >= boxes[0].x
        && (boxes[1].x + boxes[1].width) <= (boxes[0].x + boxes[0].width) + 1.0;

    if is_tree {
        // Identify top-level child subtrees [start_idx, end_idx) inside boxes[0]
        let mut subtrees: [(usize, usize); 64] = [(0, 0); 64];
        let mut count = 0usize;
        let mut idx = 1usize;
        while idx < n && count < 64 {
            let p_x1 = boxes[idx].x - 0.5;
            let p_y1 = boxes[idx].y - 0.5;
            let p_x2 = boxes[idx].x + boxes[idx].width + 0.5;
            let p_y2 = boxes[idx].y + boxes[idx].height + 0.5;
            let mut end = idx + 1;
            while end < n {
                let c = &boxes[end];
                if c.x >= p_x1 && c.y >= p_y1 && (c.x + c.width) <= p_x2 && (c.y + c.height) <= p_y2 {
                    end += 1;
                } else {
                    break;
                }
            }
            subtrees[count] = (idx, end);
            count += 1;
            idx = end;
        }

        if count == 0 {
            return;
        }

        let first_idx = subtrees[0].0;
        let last_idx = subtrees[count - 1].0;
        let orig_first_x = boxes[first_idx].x;
        let orig_last_end = boxes[last_idx].x + boxes[last_idx].width;
        let orig_center_x = (orig_first_x + orig_last_end) * 0.5;

        let mut scales = [1.0f32; 64];
        let mut gaps = [0.0f32; 63];
        let mut new_widths = [0.0f32; 64];
        let mut total_new_width = 0.0f32;

        for i in 0..count {
            let root_i = subtrees[i].0;
            if let Some(px) = pointer_x {
                // Only magnify interactive dock app icons (skip 1px separators and wide widgets/pills)
                if boxes[root_i].width > 4.0 && boxes[root_i].width <= 72.0 {
                    scales[i] = model.compute_scale(px, boxes[root_i].center_x());
                }
            }
            if i + 1 < count {
                let next_i = subtrees[i + 1].0;
                gaps[i] = (boxes[next_i].x - (boxes[root_i].x + boxes[root_i].width)).max(0.0);
            }
            new_widths[i] = boxes[root_i].width * scales[i];
            total_new_width += new_widths[i];
            if i + 1 < count {
                total_new_width += gaps[i];
            }
        }

        // Ajusta o container raiz (boxes[0]) ao redor dos itens como uma pílula centralizada
        let dock_pad_x = 14.0f32;
        let pill_w = (total_new_width + dock_pad_x * 2.0).min(boxes[0].width);
        boxes[0].width = pill_w;
        boxes[0].x = orig_center_x - pill_w * 0.5;

        let mut cur_x = orig_center_x - (total_new_width * 0.5);
        for i in 0..count {
            let (start, end) = subtrees[i];
            let s = scales[i];
            let orig_px = boxes[start].x;
            let orig_py = boxes[start].y;
            let orig_ph = boxes[start].height;
            let new_ph = orig_ph * s;
            let new_py = if anchor_bottom {
                (orig_py + orig_ph) - new_ph
            } else {
                orig_py - (new_ph - orig_ph) * 0.5
            };

            boxes[start].x = cur_x;
            boxes[start].y = new_py;
            boxes[start].width = new_widths[i];
            boxes[start].height = new_ph;
            boxes[start].border_radius = (boxes[start].border_radius * s).min(new_ph * 0.5);

            // Transform all descendant boxes (inner background, icon glyph text, indicator dot)
            for child in &mut boxes[(start + 1)..end] {
                let rel_x = child.x - orig_px;
                let rel_y = child.y - orig_py;
                child.x = cur_x + rel_x * s;
                child.y = new_py + rel_y * s;
                child.width *= s;
                child.height *= s;
                child.border_radius = (child.border_radius * s).min(child.height * 0.5);
                if let Some((_, _, ref mut fsize)) = child.text {
                    *fsize *= s;
                }
            }

            if i + 1 < count {
                cur_x += new_widths[i] + gaps[i];
            }
        }
        return;
    }

    // Flat slice path (used by unit tests with standalone sibling boxes)
    let Some(px) = pointer_x else {
        return;
    };
    let orig_first_x = boxes[0].x;
    let orig_last_end = boxes[n - 1].x + boxes[n - 1].width;
    let orig_center_x = (orig_first_x + orig_last_end) * 0.5;

    let mut scales = [1.0f32; 64];
    let count = n.min(64);
    for i in 0..count {
        scales[i] = model.compute_scale(px, boxes[i].center_x());
    }

    let mut gaps = [0.0f32; 63];
    for i in 0..count.saturating_sub(1) {
        let gap = boxes[i + 1].x - (boxes[i].x + boxes[i].width);
        gaps[i] = gap.max(0.0);
    }

    let mut new_widths = [0.0f32; 64];
    let mut total_new_width = 0.0f32;
    for i in 0..count {
        let nw = boxes[i].width * scales[i];
        new_widths[i] = nw;
        total_new_width += nw;
        if i < count - 1 {
            total_new_width += gaps[i];
        }
    }

    let mut cur_x = orig_center_x - (total_new_width * 0.5);
    for i in 0..count {
        let original_h = boxes[i].height;
        let new_h = original_h * scales[i];

        if anchor_bottom {
            let baseline = boxes[i].y + original_h;
            boxes[i].y = baseline - new_h;
        } else {
            boxes[i].y -= (new_h - original_h) * 0.5;
        }

        boxes[i].x = cur_x;
        boxes[i].width = new_widths[i];
        boxes[i].height = new_h;
        boxes[i].border_radius = (boxes[i].border_radius * scales[i]).min(new_h * 0.5);

        if i < count - 1 {
            cur_x += new_widths[i] + gaps[i];
        }
    }
}

/// Updates scroll_offset_y recursively in any UiNode with Overflow::Scroll
pub fn update_scroll_offset_in_tree(root: &mut UiNode, delta: f32) -> bool {
    match root {
        UiNode::Box { style, children, .. } | UiNode::Window { style, children, .. } => {
            if style.overflow == Overflow::Scroll {
                style.scroll_offset_y = (style.scroll_offset_y + delta).max(0.0);
                return true;
            }
            for child in children {
                if update_scroll_offset_in_tree(child, delta) {
                    return true;
                }
            }
        }
        _ => {}
    }
    false
}

/// Sets scroll_offset_y recursively in any UiNode with Overflow::Scroll
pub fn set_scroll_offset_in_tree(root: &mut UiNode, offset: f32) -> bool {
    match root {
        UiNode::Box { style, children, .. } | UiNode::Window { style, children, .. } => {
            if style.overflow == Overflow::Scroll {
                style.scroll_offset_y = offset.max(0.0);
                return true;
            }
            for child in children {
                if set_scroll_offset_in_tree(child, offset) {
                    return true;
                }
            }
        }
        _ => {}
    }
    false
}


#[derive(Debug, Clone)]
struct LayoutNodeCache {
    node_id: NodeId,
    style: Style,
    children: Vec<LayoutNodeCache>,
}

/// Engine to calculate layout positions for an entire UI tree with incremental Taffy node recycling.
pub struct LayoutEngine {
    taffy: TaffyTree<()>,
    cached_root: Option<LayoutNodeCache>,
}

impl Default for LayoutEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[inline]
fn dim_to_lpa(dim: Dimension) -> LengthPercentageAuto {
    match dim.expand() {
        ExpandedDimension::Length(val) => LengthPercentageAuto::length(val),
        ExpandedDimension::Percent(val) => LengthPercentageAuto::percent(val),
        _ => LengthPercentageAuto::auto(),
    }
}

impl LayoutEngine {
    pub fn new() -> Self {
        Self {
            taffy: TaffyTree::new(),
            cached_root: None,
        }
    }

    /// Number of active nodes in the internal Taffy tree.
    pub fn node_count(&self) -> usize {
        self.taffy.total_node_count()
    }

    /// Root NodeId currently cached, if any.
    pub fn root_node_id(&self) -> Option<NodeId> {
        self.cached_root.as_ref().map(|c| c.node_id)
    }

    /// Clears cached layout tree and resets the Taffy tree.
    pub fn clear(&mut self) {
        self.cached_root = None;
        self.taffy.clear();
    }

    /// Compute absolute bounding boxes for a UI tree given available viewport bounds.
    /// Recycles existing Taffy nodes across incremental mutations instead of clearing the tree.
    pub fn compute(&mut self, root: &UiNode, viewport_width: f32, viewport_height: f32) -> Vec<ComputedBox> {
        let mut computed = Vec::with_capacity(32);
        self.compute_into(root, viewport_width, viewport_height, &mut computed);
        computed
    }

    /// Zero-allocation computation reusing an existing `Vec<ComputedBox>` buffer between frames.
    pub fn compute_into(
        &mut self,
        root: &UiNode,
        viewport_width: f32,
        viewport_height: f32,
        computed: &mut Vec<ComputedBox>,
    ) {
        computed.clear();
        let old_cache = self.cached_root.take();
        let mut root_cache = self.sync_node(root, old_cache);

        // Ensure root container expands to viewport bounds if not explicitly sized
        let mut root_style = root_cache.style.clone();
        let mut style_mutated = false;
        if root_style.size.width == auto() {
            root_style.size.width = length(viewport_width);
            style_mutated = true;
        }
        if root_style.size.height == auto() {
            root_style.size.height = length(viewport_height);
            style_mutated = true;
        }
        if style_mutated {
            let _ = self.taffy.set_style(root_cache.node_id, root_style.clone());
            root_cache.style = root_style;
        }

        let available_space = Size {
            width: AvailableSpace::Definite(viewport_width),
            height: AvailableSpace::Definite(viewport_height),
        };

        if let Err(e) = self.taffy.compute_layout(root_cache.node_id, available_space) {
            tracing::error!("Failed to compute Taffy layout: {:?}", e);
            self.cached_root = Some(root_cache);
            return;
        }

        self.collect_computed(root, root_cache.node_id, 0.0, 0.0, None, computed);
        self.cached_root = Some(root_cache);
    }

    fn remove_cache_tree(&mut self, cache: LayoutNodeCache) {
        for child in cache.children {
            self.remove_cache_tree(child);
        }
        let _ = self.taffy.remove(cache.node_id);
    }

    fn compute_taffy_style(node: &UiNode) -> Style {
        match node {
            UiNode::Box { style, .. } | UiNode::Window { style, .. } => Self::convert_style(style),
            UiNode::Text { style, text, font_size, .. } => {
                let mut taffy_style = Self::convert_style(style);
                if style.width.is_none() {
                    let char_count = text.chars().count();
                    let approx_width = (char_count as f32 * (*font_size * 0.62)).max(*font_size * 0.7);
                    taffy_style.size.width = length(approx_width);
                }
                if style.height.is_none() {
                    taffy_style.size.height = length(*font_size * 1.2);
                }
                taffy_style
            }
            UiNode::TextInput { style, text, placeholder, font_size, .. } => {
                let mut taffy_style = Self::convert_style(style);
                if style.width.is_none() {
                    let chars = text.chars().count().max(placeholder.chars().count()).max(10);
                    let approx_width = (chars as f32 * (*font_size * 0.62)).max(120.0);
                    taffy_style.size.width = length(approx_width);
                }
                if style.height.is_none() {
                    taffy_style.size.height = length((*font_size * 1.8).max(34.0));
                }
                taffy_style
            }
            UiNode::Image { style, .. } => {
                let mut taffy_style = Self::convert_style(style);
                if style.width.is_none() {
                    taffy_style.size.width = length(24.0);
                }
                if style.height.is_none() {
                    taffy_style.size.height = length(24.0);
                }
                taffy_style
            }
            UiNode::Shader { style, .. } => Self::convert_style(style),
            UiNode::Slider { style, .. } => {
                let mut taffy_style = Self::convert_style(style);
                let w_dim = style.width.unwrap_or_else(|| length(160.0));
                let h_dim = style.height.unwrap_or_else(|| length(24.0));
                taffy_style.size.width = w_dim;
                taffy_style.size.height = h_dim;
                taffy_style.min_size.width = dim_to_lpa(w_dim);
                taffy_style.min_size.height = dim_to_lpa(h_dim);
                taffy_style.flex_shrink = 0.0;
                taffy_style
            }
            UiNode::Switch { style, .. } => {
                let mut taffy_style = Self::convert_style(style);
                let w_dim = style.width.unwrap_or_else(|| length(44.0));
                let h_dim = style.height.unwrap_or_else(|| length(24.0));
                taffy_style.size.width = w_dim;
                taffy_style.size.height = h_dim;
                taffy_style.min_size.width = dim_to_lpa(w_dim);
                taffy_style.min_size.height = dim_to_lpa(h_dim);
                taffy_style.flex_shrink = 0.0;
                taffy_style
            }
        }
    }

    fn sync_node(&mut self, node: &UiNode, cached: Option<LayoutNodeCache>) -> LayoutNodeCache {
        let desired_style = Self::compute_taffy_style(node);
        let ui_children = match node {
            UiNode::Box { children, .. } | UiNode::Window { children, .. } => children.as_slice(),
            _ => &[],
        };

        match cached {
            Some(mut cache) => {
                // Recycle existing NodeId! Update style only if changed.
                if cache.style != desired_style {
                    let _ = self.taffy.set_style(cache.node_id, desired_style.clone());
                    cache.style = desired_style;
                }

                let mut new_children_caches = Vec::with_capacity(ui_children.len());
                let mut cached_children = cache.children;
                let mut drain = cached_children.drain(..);

                for ui_child in ui_children {
                    let cached_child = drain.next();
                    let child_cache = self.sync_node(ui_child, cached_child);
                    new_children_caches.push(child_cache);
                }

                // Remove leftover cached child nodes from Taffy
                for leftover in drain {
                    self.remove_cache_tree(leftover);
                }

                // Update child references only if children composition actually changed
                let current_child_ids = self.taffy.children(cache.node_id).unwrap_or_default();
                if !current_child_ids.iter().copied().eq(new_children_caches.iter().map(|c| c.node_id)) {
                    let new_child_ids: Vec<NodeId> = new_children_caches.iter().map(|c| c.node_id).collect();
                    let _ = self.taffy.set_children(cache.node_id, &new_child_ids);
                }

                cache.children = new_children_caches;
                cache
            }
            None => {
                if ui_children.is_empty() {
                    let node_id = self.taffy.new_leaf(desired_style.clone()).unwrap();
                    LayoutNodeCache {
                        node_id,
                        style: desired_style,
                        children: Vec::new(),
                    }
                } else {
                    let mut child_caches = Vec::with_capacity(ui_children.len());
                    for ui_child in ui_children {
                        child_caches.push(self.sync_node(ui_child, None));
                    }
                    let child_ids: Vec<NodeId> = child_caches.iter().map(|c| c.node_id).collect();
                    let node_id = self.taffy.new_with_children(desired_style.clone(), &child_ids).unwrap();
                    LayoutNodeCache {
                        node_id,
                        style: desired_style,
                        children: child_caches,
                    }
                }
            }
        }
    }

    fn convert_style(style: &NodeStyle) -> Style {
        Style {
            size: Size {
                width: style.width.unwrap_or_else(auto),
                height: style.height.unwrap_or_else(auto),
            },
            max_size: Size {
                width: style.max_width.map(dim_to_lpa).unwrap_or_else(LengthPercentageAuto::auto),
                height: LengthPercentageAuto::auto(),
            },
            padding: Rect {
                top: length(style.padding[0]),
                right: length(style.padding[1]),
                bottom: length(style.padding[2]),
                left: length(style.padding[3]),
            },
            margin: Rect {
                top: length(style.margin[0]),
                right: length(style.margin[1]),
                bottom: length(style.margin[2]),
                left: length(style.margin[3]),
            },
            flex_direction: style.flex_direction,
            justify_content: style.justify_content,
            align_items: style.align_items,
            flex_grow: style.flex_grow,
            flex_shrink: style.flex_shrink,
            gap: Size {
                width: length(style.gap),
                height: length(style.gap),
            },
            ..Default::default()
        }
    }

    fn collect_computed(
        &self,
        node: &UiNode,
        node_id: NodeId,
        parent_x: f32,
        parent_y: f32,
        active_clip: Option<[f32; 4]>,
        out: &mut Vec<ComputedBox>,
    ) {
        let layout = self.taffy.layout(node_id).unwrap();
        let abs_x = parent_x + layout.location.x;
        let abs_y = parent_y + layout.location.y;

        match node {
            UiNode::Box { style, children, .. }
            | UiNode::Window { style, children, .. } => {
                let (on_c, on_rc, on_su, on_sd, tip) = match node {
                    UiNode::Box { on_click, on_right_click, on_scroll_up, on_scroll_down, tooltip, .. } => (
                        on_click.clone(),
                        on_right_click.clone(),
                        on_scroll_up.clone(),
                        on_scroll_down.clone(),
                        tooltip.clone(),
                    ),
                    _ => (None, None, None, None, None),
                };

                out.push(ComputedBox {
                    x: abs_x,
                    y: abs_y,
                    width: layout.size.width,
                    height: layout.size.height,
                    background_color: style.background_color,
                    border_color: style.border_color,
                    border_width: style.border_width,
                    border_radius: style.border_radius,
                    shadow: style.shadow,
                    custom_shader: style.custom_shader.clone(),
                    text: None,
                    image: None,
                    text_input: None,
                    slider: None,
                    switch: None,
                    overflow: style.overflow,
                    scroll_offset_y: style.scroll_offset_y,
                    clip_rect: active_clip,
                    on_click: on_c,
                    on_right_click: on_rc,
                    on_scroll_up: on_su,
                    on_scroll_down: on_sd,
                    tooltip: tip,
                    tooltip_active: false,
                });

                let my_clip = if style.overflow == Overflow::Scroll || style.overflow == Overflow::Hidden {
                    let cur = [abs_x, abs_y, layout.size.width, layout.size.height];
                    match active_clip {
                        Some([cx, cy, cw, ch]) => {
                            let x1 = abs_x.max(cx);
                            let y1 = abs_y.max(cy);
                            let x2 = (abs_x + layout.size.width).min(cx + cw);
                            let y2 = (abs_y + layout.size.height).min(cy + ch);
                            Some([x1, y1, (x2 - x1).max(0.0), (y2 - y1).max(0.0)])
                        }
                        None => Some(cur),
                    }
                } else {
                    active_clip
                };

                let child_ids = self.taffy.children(node_id).unwrap();
                let scroll_y = if style.overflow == Overflow::Scroll {
                    style.scroll_offset_y
                } else {
                    0.0
                };

                for (child_node, child_id) in children.iter().zip(child_ids.iter()) {
                    self.collect_computed(child_node, *child_id, abs_x, abs_y - scroll_y, my_clip, out);
                }
            }
            UiNode::Text { style, text, color, font_size } => {
                out.push(ComputedBox {
                    x: abs_x,
                    y: abs_y,
                    width: layout.size.width,
                    height: layout.size.height,
                    background_color: style.background_color,
                    border_color: style.border_color,
                    border_width: style.border_width,
                    border_radius: style.border_radius,
                    shadow: style.shadow,
                    custom_shader: None,
                    text: Some((text.clone(), *color, *font_size)),
                    image: None,
                    text_input: None,
                    slider: None,
                    switch: None,
                    overflow: style.overflow,
                    scroll_offset_y: 0.0,
                    clip_rect: active_clip,
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                    tooltip_active: false,
                });
            }
            UiNode::TextInput {
                style,
                id,
                text,
                placeholder,
                font_size,
                color,
                placeholder_color,
                active,
                cursor_pos,
                selection_range,
                on_change,
                on_submit,
            } => {
                let char_w = font_size * 0.62;
                let line_h = font_size * 1.3;
                let cursor_chars = text.get(..*cursor_pos).map(|s| s.chars().count()).unwrap_or_else(|| text.chars().count());
                let cursor_offset_x = cursor_chars as f32 * char_w;

                let selection_rect = selection_range.as_ref().map(|&(s, e)| {
                    let s_chars = text.get(..s).map(|st| st.chars().count()).unwrap_or(0);
                    let e_chars = text.get(..e).map(|st| st.chars().count()).unwrap_or_else(|| text.chars().count());
                    let sel_x = s_chars as f32 * char_w;
                    let sel_w = ((e_chars.saturating_sub(s_chars)) as f32 * char_w).max(2.0);
                    let sel_y = ((layout.size.height - line_h) * 0.5).max(0.0);
                    (sel_x, sel_y, sel_w, line_h)
                });

                out.push(ComputedBox {
                    x: abs_x,
                    y: abs_y,
                    width: layout.size.width,
                    height: layout.size.height,
                    background_color: style.background_color,
                    border_color: style.border_color,
                    border_width: style.border_width,
                    border_radius: style.border_radius,
                    shadow: style.shadow,
                    custom_shader: None,
                    text: None,
                    image: None,
                    text_input: Some(ComputedTextInput {
                        id: id.clone(),
                        text: text.clone(),
                        placeholder: placeholder.clone(),
                        font_size: *font_size,
                        color: *color,
                        placeholder_color: *placeholder_color,
                        active: *active,
                        cursor_pos: *cursor_pos,
                        selection_range: *selection_range,
                        cursor_offset_x,
                        selection_rect,
                        on_change: on_change.clone(),
                        on_submit: on_submit.clone(),
                    }),
                    slider: None,
                    switch: None,
                    overflow: style.overflow,
                    scroll_offset_y: 0.0,
                    clip_rect: active_clip,
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                    tooltip_active: false,
                });
            }
            UiNode::Image { style, src } => {
                out.push(ComputedBox {
                    x: abs_x,
                    y: abs_y,
                    width: layout.size.width,
                    height: layout.size.height,
                    background_color: style.background_color,
                    border_color: style.border_color,
                    border_width: style.border_width,
                    border_radius: style.border_radius,
                    shadow: style.shadow,
                    custom_shader: None,
                    text: None,
                    image: Some(src.clone()),
                    text_input: None,
                    slider: None,
                    switch: None,
                    overflow: style.overflow,
                    scroll_offset_y: 0.0,
                    clip_rect: active_clip,
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                    tooltip_active: false,
                });
            }
            UiNode::Shader { style, fragment, uniforms } => {
                out.push(ComputedBox {
                    x: abs_x,
                    y: abs_y,
                    width: layout.size.width,
                    height: layout.size.height,
                    background_color: style.background_color,
                    border_color: style.border_color,
                    border_width: style.border_width,
                    border_radius: style.border_radius,
                    shadow: style.shadow,
                    custom_shader: Some(CustomShaderStyle {
                        fragment: fragment.clone(),
                        uniforms: uniforms.clone(),
                    }),
                    text: None,
                    image: None,
                    text_input: None,
                    slider: None,
                    switch: None,
                    overflow: style.overflow,
                    scroll_offset_y: 0.0,
                    clip_rect: active_clip,
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                    tooltip_active: false,
                });
            }
            UiNode::Slider {
                id,
                min,
                max,
                value,
                track_height,
                thumb_radius,
                track_color,
                active_track_color,
                thumb_color,
                style,
                on_change,
            } => {
                out.push(ComputedBox {
                    x: abs_x,
                    y: abs_y,
                    width: layout.size.width,
                    height: layout.size.height,
                    background_color: style.background_color,
                    border_color: style.border_color,
                    border_width: style.border_width,
                    border_radius: style.border_radius,
                    shadow: style.shadow,
                    custom_shader: None,
                    text: None,
                    image: None,
                    text_input: None,
                    slider: Some(ComputedSlider {
                        id: id.clone(),
                        min: *min,
                        max: *max,
                        value: *value,
                        track_height: *track_height,
                        thumb_radius: *thumb_radius,
                        track_color: *track_color,
                        active_track_color: *active_track_color,
                        thumb_color: *thumb_color,
                        on_change: on_change.clone(),
                    }),
                    switch: None,
                    overflow: style.overflow,
                    scroll_offset_y: 0.0,
                    clip_rect: active_clip,
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                    tooltip_active: false,
                });
            }
            UiNode::Switch {
                id,
                checked,
                active_color,
                inactive_color,
                thumb_color,
                style,
                on_toggle,
            } => {
                out.push(ComputedBox {
                    x: abs_x,
                    y: abs_y,
                    width: layout.size.width,
                    height: layout.size.height,
                    background_color: style.background_color,
                    border_color: style.border_color,
                    border_width: style.border_width,
                    border_radius: style.border_radius,
                    shadow: style.shadow,
                    custom_shader: None,
                    text: None,
                    image: None,
                    text_input: None,
                    slider: None,
                    switch: Some(ComputedSwitch {
                        id: id.clone(),
                        checked: *checked,
                        active_color: *active_color,
                        inactive_color: *inactive_color,
                        thumb_color: *thumb_color,
                        on_toggle: on_toggle.clone(),
                    }),
                    overflow: style.overflow,
                    scroll_offset_y: 0.0,
                    clip_rect: active_clip,
                    on_click: on_toggle.clone(),
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                    tooltip_active: false,
                });
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_root_layout_width() {
        let mut engine = LayoutEngine::new();
        let root = UiNode::Box {
            style: NodeStyle {
                height: Some(length(44.0)),
                ..Default::default()
            },
            children: vec![
                UiNode::Box {
                    style: NodeStyle {
                        flex_grow: 1.0,
                        height: Some(length(36.0)),
                        ..Default::default()
                    },
                    children: vec![],
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                }
            ],
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
        };
        let computed = engine.compute(&root, 1346.0, 44.0);
        println!("Computed boxes: {:?}", computed);
        assert_eq!(computed[0].width, 1346.0);
        assert_eq!(computed[1].width, 1346.0);
    }

    #[test]
    fn test_bar_clusters_distribution() {
        let mut engine = LayoutEngine::new();
        let root = UiNode::Box {
            style: NodeStyle {
                height: Some(length(44.0)),
                padding: [4.0, 12.0, 4.0, 12.0],
                ..Default::default()
            },
            children: vec![
                UiNode::Box {
                    style: NodeStyle {
                        flex_grow: 1.0,
                        height: Some(length(36.0)),
                        flex_direction: FlexDirection::Row,
                        ..Default::default()
                    },
                    children: vec![
                        UiNode::Box {
                            style: NodeStyle { width: Some(length(100.0)), height: Some(length(30.0)), ..Default::default() },
                            children: vec![],
                            on_click: None,
                            on_right_click: None,
                            on_scroll_up: None,
                            on_scroll_down: None,
                            tooltip: None,
                        },
                        UiNode::Box {
                            style: NodeStyle { flex_grow: 1.0, ..Default::default() },
                            children: vec![],
                            on_click: None,
                            on_right_click: None,
                            on_scroll_up: None,
                            on_scroll_down: None,
                            tooltip: None,
                        },
                        UiNode::Box {
                            style: NodeStyle { width: Some(length(80.0)), height: Some(length(30.0)), ..Default::default() },
                            children: vec![],
                            on_click: None,
                            on_right_click: None,
                            on_scroll_up: None,
                            on_scroll_down: None,
                            tooltip: None,
                        },
                        UiNode::Box {
                            style: NodeStyle { flex_grow: 1.0, ..Default::default() },
                            children: vec![],
                            on_click: None,
                            on_right_click: None,
                            on_scroll_up: None,
                            on_scroll_down: None,
                            tooltip: None,
                        },
                        UiNode::Box {
                            style: NodeStyle { width: Some(length(120.0)), height: Some(length(30.0)), ..Default::default() },
                            children: vec![],
                            on_click: None,
                            on_right_click: None,
                            on_scroll_up: None,
                            on_scroll_down: None,
                            tooltip: None,
                        },
                    ],
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                }
            ],
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
        };
        let computed = engine.compute(&root, 1346.0, 44.0);
        assert_eq!(computed[0].width, 1346.0);
        // Container width = 1346 - 24 = 1322
        assert_eq!(computed[1].width, 1322.0);
        // Right cluster (last element in computed) should end near 1346 - 12 = 1334
        let right_cluster = &computed[computed.len() - 1];
        assert_eq!(right_cluster.x + right_cluster.width, 1334.0);
    }

    #[test]
    fn test_text_input_image_and_scroll_layout() {
        let mut engine = LayoutEngine::new();
        let root = UiNode::Box {
            style: NodeStyle {
                width: Some(length(400.0)),
                height: Some(length(300.0)),
                overflow: Overflow::Scroll,
                scroll_offset_y: 50.0,
                flex_direction: FlexDirection::Column,
                ..Default::default()
            },
            children: vec![
                UiNode::TextInput {
                    id: Some("search_input".to_string()),
                    text: "hello".to_string(),
                    placeholder: "Search...".to_string(),
                    font_size: 14.0,
                    color: Color::rgb(255, 255, 255),
                    placeholder_color: Color::rgb(150, 150, 150),
                    active: true,
                    cursor_pos: 5,
                    selection_range: None,
                    style: NodeStyle {
                        width: Some(length(300.0)),
                        height: Some(length(36.0)),
                        ..Default::default()
                    },
                    on_change: Some("change_cb".to_string()),
                    on_submit: Some("submit_cb".to_string()),
                },
                UiNode::Image {
                    src: "/tmp/icon.png".to_string(),
                    style: NodeStyle {
                        width: Some(length(32.0)),
                        height: Some(length(32.0)),
                        ..Default::default()
                    },
                },
            ],
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
        };

        let computed = engine.compute(&root, 400.0, 300.0);
        assert_eq!(computed.len(), 3);
        assert_eq!(computed[0].overflow, Overflow::Scroll);
        assert_eq!(computed[0].scroll_offset_y, 50.0);

        let input_box = &computed[1];
        assert!(input_box.text_input.is_some());
        assert_eq!(input_box.text_input.as_ref().unwrap().text, "hello");
        // Due to scroll_offset_y: 50.0, children y should be offset by -50.0
        assert_eq!(input_box.y, -50.0);

        let img_box = &computed[2];
        assert_eq!(img_box.image.as_deref(), Some("/tmp/icon.png"));
    }

    #[test]
    fn test_box_tooltip_property() {
        let mut engine = LayoutEngine::new();
        let root = UiNode::Box {
            style: NodeStyle {
                width: Some(length(200.0)),
                height: Some(length(40.0)),
                ..Default::default()
            },
            children: vec![],
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: Some("Click to toggle Wi-Fi".to_string()),
        };

        let computed = engine.compute(&root, 200.0, 40.0);
        assert_eq!(computed.len(), 1);
        assert_eq!(computed[0].tooltip.as_deref(), Some("Click to toggle Wi-Fi"));
        assert!(!computed[0].tooltip_active);
    }

    #[test]
    fn test_taffy_node_recycling_on_incremental_mutations() {
        let mut engine = LayoutEngine::new();

        // 1. Initial UI Tree: Root Box with 2 children (Text + Box with child Image)
        let initial_root = UiNode::Box {
            style: NodeStyle {
                width: Some(length(500.0)),
                height: Some(length(300.0)),
                ..Default::default()
            },
            children: vec![
                UiNode::Text {
                    text: "Initial Title".to_string(),
                    font_size: 16.0,
                    color: Color::rgb(255, 255, 255),
                    style: NodeStyle::default(),
                },
                UiNode::Box {
                    style: NodeStyle {
                        width: Some(length(200.0)),
                        height: Some(length(50.0)),
                        ..Default::default()
                    },
                    children: vec![
                        UiNode::Image {
                            src: "/path/to/icon.png".to_string(),
                            style: NodeStyle::default(),
                        }
                    ],
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                },
            ],
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
        };

        let boxes1 = engine.compute(&initial_root, 500.0, 300.0);
        assert_eq!(boxes1.len(), 4);
        let root_id_1 = engine.root_node_id().expect("root node exists");
        let initial_count = engine.node_count();
        assert_eq!(initial_count, 4);

        // 2. Incremental Mutation: change text and width of the child box (preserving topology)
        let mutated_root = UiNode::Box {
            style: NodeStyle {
                width: Some(length(500.0)),
                height: Some(length(300.0)),
                ..Default::default()
            },
            children: vec![
                UiNode::Text {
                    text: "Updated Title".to_string(),
                    font_size: 16.0,
                    color: Color::rgb(200, 200, 200),
                    style: NodeStyle::default(),
                },
                UiNode::Box {
                    style: NodeStyle {
                        width: Some(length(220.0)), // width mutated
                        height: Some(length(50.0)),
                        background_color: Color::rgb(10, 20, 30),
                        ..Default::default()
                    },
                    children: vec![
                        UiNode::Image {
                            src: "/path/to/icon.png".to_string(),
                            style: NodeStyle::default(),
                        }
                    ],
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                },
            ],
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
        };

        let boxes2 = engine.compute(&mutated_root, 500.0, 300.0);
        assert_eq!(boxes2.len(), 4);
        // Root NodeId must be recycled across frame computations!
        assert_eq!(engine.root_node_id(), Some(root_id_1));
        // Node count must remain identical (zero node allocations/leakages)
        assert_eq!(engine.node_count(), initial_count);
        // Mutated width must be reflected in computed box
        assert_eq!(boxes2[2].width, 220.0);

        // 3. Child addition: add an extra box
        let expanded_root = UiNode::Box {
            style: NodeStyle {
                width: Some(length(500.0)),
                height: Some(length(300.0)),
                ..Default::default()
            },
            children: vec![
                UiNode::Text {
                    text: "Updated Title".to_string(),
                    font_size: 16.0,
                    color: Color::rgb(200, 200, 200),
                    style: NodeStyle::default(),
                },
                UiNode::Box {
                    style: NodeStyle {
                        width: Some(length(220.0)),
                        height: Some(length(50.0)),
                        ..Default::default()
                    },
                    children: vec![
                        UiNode::Image {
                            src: "/path/to/icon.png".to_string(),
                            style: NodeStyle::default(),
                        }
                    ],
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                },
                UiNode::Box {
                    style: NodeStyle {
                        width: Some(length(80.0)),
                        height: Some(length(40.0)),
                        ..Default::default()
                    },
                    children: vec![],
                    on_click: None,
                    on_right_click: None,
                    on_scroll_up: None,
                    on_scroll_down: None,
                    tooltip: None,
                },
            ],
            on_click: None,
            on_right_click: None,
            on_scroll_up: None,
            on_scroll_down: None,
            tooltip: None,
        };

        let boxes3 = engine.compute(&expanded_root, 500.0, 300.0);
        assert_eq!(boxes3.len(), 5);
        assert_eq!(engine.root_node_id(), Some(root_id_1));
        assert_eq!(engine.node_count(), initial_count + 1);

        // 4. Child removal: remove the last child, shrinking back
        let shrunk_root = mutated_root;
        let boxes4 = engine.compute(&shrunk_root, 500.0, 300.0);
        assert_eq!(boxes4.len(), 4);
        assert_eq!(engine.root_node_id(), Some(root_id_1));
        assert_eq!(engine.node_count(), initial_count);
    }
}
