//! Zenith Layout - Taffy Flexbox tree and cosmic-text layout calculations.

use taffy::prelude::*;
pub use taffy::prelude::{AlignItems, FlexDirection, JustifyContent};

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
    pub width: Option<f32>,
    pub height: Option<f32>,
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
    pub max_width: Option<f32>,
    pub shadow: Option<ShadowStyle>,
    pub custom_shader: Option<CustomShaderStyle>,
    pub overflow: Overflow,
    pub scroll_offset_y: f32,
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
    pub on_click: Option<String>,
    pub on_right_click: Option<String>,
    pub on_scroll_up: Option<String>,
    pub on_scroll_down: Option<String>,
    pub tooltip: Option<String>,
    pub tooltip_active: bool,
}


/// Engine to calculate layout positions for an entire UI tree.
pub struct LayoutEngine {
    taffy: TaffyTree<()>,
}

impl Default for LayoutEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl LayoutEngine {
    pub fn new() -> Self {
        Self {
            taffy: TaffyTree::new(),
        }
    }

    /// Compute absolute bounding boxes for a UI tree given available viewport bounds.
    pub fn compute(&mut self, root: &UiNode, viewport_width: f32, viewport_height: f32) -> Vec<ComputedBox> {
        self.taffy.clear();
        let root_node = self.build_taffy_node(root);

        // Ensure root container expands to viewport bounds if not explicitly sized
        if let Ok(mut root_style) = self.taffy.style(root_node).cloned() {
            if root_style.size.width == auto() {
                root_style.size.width = length(viewport_width);
            }
            if root_style.size.height == auto() {
                root_style.size.height = length(viewport_height);
            }
            let _ = self.taffy.set_style(root_node, root_style);
        }

        let available_space = Size {
            width: AvailableSpace::Definite(viewport_width),
            height: AvailableSpace::Definite(viewport_height),
        };

        if let Err(e) = self.taffy.compute_layout(root_node, available_space) {
            tracing::error!("Failed to compute Taffy layout: {:?}", e);
            return Vec::new();
        }

        let mut computed = Vec::new();
        self.collect_computed(root, root_node, 0.0, 0.0, &mut computed);
        computed
    }

    fn build_taffy_node(&mut self, node: &UiNode) -> NodeId {
        match node {
            UiNode::Box { style, children, .. } | UiNode::Window { style, children, .. } => {
                let child_nodes: Vec<NodeId> = children.iter().map(|c| self.build_taffy_node(c)).collect();
                let taffy_style = Self::convert_style(style);
                self.taffy.new_with_children(taffy_style, &child_nodes).unwrap()
            }

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
                self.taffy.new_leaf(taffy_style).unwrap()
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
                self.taffy.new_leaf(taffy_style).unwrap()
            }

            UiNode::Image { style, .. } => {
                let mut taffy_style = Self::convert_style(style);
                if style.width.is_none() {
                    taffy_style.size.width = length(24.0);
                }
                if style.height.is_none() {
                    taffy_style.size.height = length(24.0);
                }
                self.taffy.new_leaf(taffy_style).unwrap()
            }

            UiNode::Shader { style, .. } => {
                let taffy_style = Self::convert_style(style);
                self.taffy.new_leaf(taffy_style).unwrap()
            }

            UiNode::Slider { style, .. } => {
                let mut taffy_style = Self::convert_style(style);
                if style.width.is_none() {
                    taffy_style.size.width = length(160.0);
                }
                if style.height.is_none() {
                    taffy_style.size.height = length(24.0);
                }
                self.taffy.new_leaf(taffy_style).unwrap()
            }

            UiNode::Switch { style, .. } => {
                let mut taffy_style = Self::convert_style(style);
                if style.width.is_none() {
                    taffy_style.size.width = length(44.0);
                }
                if style.height.is_none() {
                    taffy_style.size.height = length(24.0);
                }
                self.taffy.new_leaf(taffy_style).unwrap()
            }
        }
    }

    fn convert_style(style: &NodeStyle) -> Style {
        Style {
            size: Size {
                width: style.width.map(length).unwrap_or(auto()),
                height: style.height.map(length).unwrap_or(auto()),
            },
            max_size: Size {
                width: style.max_width.map(length).unwrap_or(auto()),
                height: auto(),
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
                    on_click: on_c,
                    on_right_click: on_rc,
                    on_scroll_up: on_su,
                    on_scroll_down: on_sd,
                    tooltip: tip,
                    tooltip_active: false,
                });

                let child_ids = self.taffy.children(node_id).unwrap();
                let scroll_y = if style.overflow == Overflow::Scroll {
                    style.scroll_offset_y
                } else {
                    0.0
                };

                for (child_node, child_id) in children.iter().zip(child_ids.iter()) {
                    self.collect_computed(child_node, *child_id, abs_x, abs_y - scroll_y, out);
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
                height: Some(44.0),
                ..Default::default()
            },
            children: vec![
                UiNode::Box {
                    style: NodeStyle {
                        flex_grow: 1.0,
                        height: Some(36.0),
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
                height: Some(44.0),
                padding: [4.0, 12.0, 4.0, 12.0],
                ..Default::default()
            },
            children: vec![
                UiNode::Box {
                    style: NodeStyle {
                        flex_grow: 1.0,
                        height: Some(36.0),
                        flex_direction: FlexDirection::Row,
                        ..Default::default()
                    },
                    children: vec![
                        UiNode::Box {
                            style: NodeStyle { width: Some(100.0), height: Some(30.0), ..Default::default() },
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
                            style: NodeStyle { width: Some(80.0), height: Some(30.0), ..Default::default() },
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
                            style: NodeStyle { width: Some(120.0), height: Some(30.0), ..Default::default() },
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
                width: Some(400.0),
                height: Some(300.0),
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
                        width: Some(300.0),
                        height: Some(36.0),
                        ..Default::default()
                    },
                    on_change: Some("change_cb".to_string()),
                    on_submit: Some("submit_cb".to_string()),
                },
                UiNode::Image {
                    src: "/tmp/icon.png".to_string(),
                    style: NodeStyle {
                        width: Some(32.0),
                        height: Some(32.0),
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
                width: Some(200.0),
                height: Some(40.0),
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
}
