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

/// Node style properties for Zenith UI elements.
#[derive(Debug, Clone)]
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
        }

    }
}

/// Abstract representation of a UI element.
#[derive(Debug, Clone)]
pub enum UiNode {
    Box {
        style: NodeStyle,
        children: Vec<UiNode>,
    },
    Text {
        text: String,
        font_size: f32,
        color: Color,
        style: NodeStyle,
    },
}

/// Computed geometry ready for rendering.
#[derive(Debug, Clone)]
pub struct ComputedBox {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub background_color: Color,
    pub border_color: Color,
    pub border_width: f32,
    pub border_radius: f32,
    pub text: Option<(String, Color, f32)>,
}

/// Engine to calculate layout positions for an entire UI tree.
pub struct LayoutEngine {
    taffy: TaffyTree<()>,
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
            UiNode::Box { style, children } => {
                let child_nodes: Vec<NodeId> = children.iter().map(|c| self.build_taffy_node(c)).collect();
                let taffy_style = Self::convert_style(style);
                self.taffy.new_with_children(taffy_style, &child_nodes).unwrap()
            }
            UiNode::Text { style, text, font_size, .. } => {
                let mut taffy_style = Self::convert_style(style);
                if style.width.is_none() {
                    let approx_width = text.len() as f32 * (font_size * 0.6);
                    taffy_style.size.width = length(approx_width);
                }
                if style.height.is_none() {
                    taffy_style.size.height = length(*font_size * 1.2);
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
            UiNode::Box { style, children } => {
                out.push(ComputedBox {
                    x: abs_x,
                    y: abs_y,
                    width: layout.size.width,
                    height: layout.size.height,
                    background_color: style.background_color,
                    border_color: style.border_color,
                    border_width: style.border_width,
                    border_radius: style.border_radius,
                    text: None,
                });

                let child_ids = self.taffy.children(node_id).unwrap();
                for (child_node, child_id) in children.iter().zip(child_ids.iter()) {
                    self.collect_computed(child_node, *child_id, abs_x, abs_y, out);
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
                    text: Some((text.clone(), *color, *font_size)),
                });
            }
        }
    }
}
