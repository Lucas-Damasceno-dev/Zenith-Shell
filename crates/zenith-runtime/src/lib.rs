//! Zenith Runtime - Luau VM integration and declarative UI parsing via mlua.

use mlua::prelude::*;
use tracing::info;
use zenith_layout::{Color, FlexDirection, NodeStyle, UiNode};

/// Runtime environment executing user Luau configs.
pub struct LuauRuntime {
    lua: Lua,
}

impl LuauRuntime {
    /// Initialize the Luau virtual machine with Zenith standard library bindings.
    pub fn new() -> Result<Self, LuaError> {
        let lua = Lua::new();

        // Inject global `Zenith` module
        let zenith_table = lua.create_table()?;

        // Zenith.rgba(r, g, b, a)
        let rgba_fn = lua.create_function(|lua, (r, g, b, a): (u8, u8, u8, Option<u8>)| {
            let table = lua.create_table()?;
            table.set("__type", "Color")?;
            table.set("r", r)?;
            table.set("g", g)?;
            table.set("b", b)?;
            table.set("a", a.unwrap_or(255))?;
            Ok(table)
        })?;
        zenith_table.set("rgba", rgba_fn)?;

        // Zenith.hex(str)
        let hex_fn = lua.create_function(|lua, hex: String| {
            let table = lua.create_table()?;
            let hex_clean = hex.trim_start_matches('#');
            let (r, g, b, a) = if hex_clean.len() == 6 {
                let r = u8::from_str_radix(&hex_clean[0..2], 16).unwrap_or(0);
                let g = u8::from_str_radix(&hex_clean[2..4], 16).unwrap_or(0);
                let b = u8::from_str_radix(&hex_clean[4..6], 16).unwrap_or(0);
                (r, g, b, 255)
            } else if hex_clean.len() == 8 {
                let r = u8::from_str_radix(&hex_clean[0..2], 16).unwrap_or(0);
                let g = u8::from_str_radix(&hex_clean[2..4], 16).unwrap_or(0);
                let b = u8::from_str_radix(&hex_clean[4..6], 16).unwrap_or(0);
                let a = u8::from_str_radix(&hex_clean[6..8], 16).unwrap_or(255);
                (r, g, b, a)
            } else {
                (255, 255, 255, 255)
            };
            table.set("__type", "Color")?;
            table.set("r", r)?;
            table.set("g", g)?;
            table.set("b", b)?;
            table.set("a", a)?;
            Ok(table)
        })?;
        zenith_table.set("hex", hex_fn)?;

        // Zenith.Box(props)
        let box_fn = lua.create_function(|_, props: LuaTable| {
            props.set("__type", "Box")?;
            Ok(props)
        })?;
        zenith_table.set("Box", box_fn)?;

        // Zenith.Text(props)
        let text_fn = lua.create_function(|_, props: LuaTable| {
            props.set("__type", "Text")?;
            Ok(props)
        })?;
        zenith_table.set("Text", text_fn)?;

        lua.globals().set("Zenith", zenith_table)?;

        info!("Luau Runtime initialized successfully");
        Ok(Self { lua })
    }

    /// Load and evaluate a Luau script string, returning the root UI node.
    pub fn eval_ui(&self, script: &str) -> Result<UiNode, LuaError> {
        let val: LuaValue = self.lua.load(script).eval()?;
        match val {
            LuaValue::Table(tbl) => Self::parse_ui_node(&tbl),
            _ => Err(LuaError::runtime("Script must return a Zenith UI node table")),
        }
    }

    fn parse_ui_node(tbl: &LuaTable) -> Result<UiNode, LuaError> {
        let node_type: String = tbl.get("__type").unwrap_or_else(|_| "Box".to_string());
        let style = Self::parse_style(tbl)?;

        if node_type == "Text" {
            let text: String = tbl.get("text").unwrap_or_default();
            let font_size: f32 = tbl.get("font_size").unwrap_or(14.0);
            let color = tbl.get("color").map(|c: LuaTable| Self::parse_color(&c)).unwrap_or(Color::rgb(255, 255, 255));

            Ok(UiNode::Text {
                text,
                font_size,
                color,
                style,
            })
        } else {
            let mut children = Vec::new();
            if let Ok(child_tbl) = tbl.get::<LuaTable>("children") {
                for pair in child_tbl.sequence_values::<LuaTable>() {
                    if let Ok(child) = pair {
                        children.push(Self::parse_ui_node(&child)?);
                    }
                }
            }

            Ok(UiNode::Box { style, children })
        }
    }

    fn parse_style(tbl: &LuaTable) -> Result<NodeStyle, LuaError> {
        let mut style = NodeStyle::default();

        if let Ok(w) = tbl.get::<f32>("width") {
            style.width = Some(w);
        }
        if let Ok(h) = tbl.get::<f32>("height") {
            style.height = Some(h);
        }

        if let Ok(dir) = tbl.get::<String>("direction") {
            if dir == "column" {
                style.flex_direction = FlexDirection::Column;
            }
        }

        if let Ok(gap) = tbl.get::<f32>("gap") {
            style.gap = gap;
        }

        if let Ok(pad) = tbl.get::<f32>("padding") {
            style.padding = [pad, pad, pad, pad];
        } else if let Ok(pad_tbl) = tbl.get::<LuaTable>("padding") {
            let x: f32 = pad_tbl.get("x").unwrap_or(0.0);
            let y: f32 = pad_tbl.get("y").unwrap_or(0.0);
            style.padding = [y, x, y, x];
        }

        if let Ok(radius) = tbl.get::<f32>("border_radius") {
            style.border_radius = radius;
        }

        if let Ok(bg_tbl) = tbl.get::<LuaTable>("background") {
            style.background_color = Self::parse_color(&bg_tbl);
        }

        if let Ok(border_tbl) = tbl.get::<LuaTable>("border_color") {
            style.border_color = Self::parse_color(&border_tbl);
        }

        if let Ok(bw) = tbl.get::<f32>("border_width") {
            style.border_width = bw;
        }

        Ok(style)
    }

    fn parse_color(tbl: &LuaTable) -> Color {
        let r: u8 = tbl.get("r").unwrap_or(0);
        let g: u8 = tbl.get("g").unwrap_or(0);
        let b: u8 = tbl.get("b").unwrap_or(0);
        let a: u8 = tbl.get("a").unwrap_or(255);
        Color::rgba(r, g, b, a)
    }
}
