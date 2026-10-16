--!strict
-- Zenith-Shell (Engine v2) - Screen Drawing & Annotation Overlay
-- 1:1 Parity with Quickshell ScreenDrawOverlay.qml & ScreenDrawUtils.js

local theme = Zenith.Theme()

local active_tool = _G.__draw_tool or "pen" -- "pen" | "highlighter" | "arrow" | "rect" | "text"
local active_color = _G.__draw_color or "#f38ba8"
local stroke_width = _G.__draw_width or 3

local colors = {
    { hex = "#f38ba8", name = "Vermelho" },
    { hex = "#fab387", name = "Laranja" },
    { hex = "#f9e2af", name = "Amarelo" },
    { hex = "#a6e3a1", name = "Verde" },
    { hex = "#89b4fa", name = "Azul" },
    { hex = "#cba6f7", name = "Roxo" },
    { hex = "#cdd6f4", name = "Branco" },
}

local function ToolButton(props: {
    tool: string,
    icon: string,
    label: string,
})
    local is_sel = active_tool == props.tool
    return Zenith.Box({
        padding = { x = 10, y = 8 },
        border_radius = 8,
        background = if is_sel then Zenith.hex(theme.primary) else Zenith.hex(theme.surface_container, 140),
        border_color = if is_sel then Zenith.hex(theme.primary) else Zenith.rgba(255, 255, 255, 12),
        border_width = 1,
        on_click = "screendraw:tool:" .. props.tool,
        tooltip = props.label,
        children = {
            Zenith.Text({
                text = props.icon,
                font_size = 14,
                color = if is_sel then Zenith.hex(theme.on_primary) else Zenith.hex(theme.on_surface),
            }),
        }
    })
end

local color_dots = {}
for _, c in ipairs(colors) do
    local is_active = (active_color == c.hex)
    table.insert(color_dots, Zenith.Box({
        width = 22,
        height = 22,
        border_radius = 11,
        background = Zenith.hex(c.hex),
        border_color = if is_active then Zenith.hex("#ffffff") else Zenith.rgba(0, 0, 0, 80),
        border_width = if is_active then 2 else 1,
        on_click = "screendraw:color:" .. c.hex,
        tooltip = c.name,
    }))
end

return Zenith.Window({
    direction = "column",
    width = 540,
    height = 110,
    padding = { x = 14, y = 10 },
    gap = 8,
    background = Zenith.hex(theme.surface, 240),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
    border_width = 1,
    border_radius = 16,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 32,
        spread = 2,
        offset_y = 10,
    },
    children = {
        -- Row 1: Tools, Separator, History Actions, Save, Exit
        Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 6,
            children = {
                ToolButton({ tool = "pen", icon = "󰏬", label = "Caneta Livre (P)" }),
                ToolButton({ tool = "highlighter", icon = "󰈙", label = "Marca-texto (H)" }),
                ToolButton({ tool = "arrow", icon = "󰁔", label = "Seta Direcional (A)" }),
                ToolButton({ tool = "rect", icon = "󰹑", label = "Retângulo (R)" }),
                ToolButton({ tool = "text", icon = "󰬴", label = "Texto (T)" }),

                -- Separator
                Zenith.Box({ width = 1, height = 26, background = Zenith.rgba(255, 255, 255, 20) }),

                -- Stroke Width Selector
                Zenith.Box({
                    direction = "row",
                    gap = 4,
                    children = {
                        Zenith.Box({
                            padding = { x = 6, y = 6 },
                            border_radius = 6,
                            background = if stroke_width == 2 then Zenith.hex(theme.primary, 180) else Zenith.hex(theme.surface_container, 120),
                            on_click = "screendraw:width:2",
                            tooltip = "Espessura Fina",
                            children = {
                                Zenith.Text({ text = "•", font_size = 12, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 6, y = 6 },
                            border_radius = 6,
                            background = if stroke_width == 5 then Zenith.hex(theme.primary, 180) else Zenith.hex(theme.surface_container, 120),
                            on_click = "screendraw:width:5",
                            tooltip = "Espessura Média",
                            children = {
                                Zenith.Text({ text = "●", font_size = 13, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 6, y = 6 },
                            border_radius = 6,
                            background = if stroke_width == 9 then Zenith.hex(theme.primary, 180) else Zenith.hex(theme.surface_container, 120),
                            on_click = "screendraw:width:9",
                            tooltip = "Espessura Grossa",
                            children = {
                                Zenith.Text({ text = "󰪥", font_size = 14, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                    }
                }),

                Zenith.Box({ flex_grow = 1 }),

                -- History & Output Actions
                Zenith.Box({
                    direction = "row",
                    gap = 6,
                    children = {
                        Zenith.Box({
                            padding = { x = 8, y = 6 },
                            border_radius = 6,
                            background = Zenith.hex(theme.surface_container, 140),
                            on_click = "screendraw:undo",
                            tooltip = "Desfazer (Ctrl+Z)",
                            children = {
                                Zenith.Text({ text = "󰕌", font_size = 13, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 8, y = 6 },
                            border_radius = 6,
                            background = Zenith.hex(theme.surface_container, 140),
                            on_click = "screendraw:clear",
                            tooltip = "Limpar Desenho (Ctrl+L)",
                            children = {
                                Zenith.Text({ text = "󰃢", font_size = 13, color = Zenith.hex("#e06c75") }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 8, y = 6 },
                            border_radius = 6,
                            background = Zenith.hex(theme.primary),
                            on_click = "screendraw:save",
                            tooltip = "Capturar / Salvar Anotações",
                            children = {
                                Zenith.Text({ text = "󰄀", font_size = 13, color = Zenith.hex(theme.on_primary) }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 6, y = 6 },
                            border_radius = 6,
                            background = Zenith.hex(theme.surface_container, 160),
                            on_click = "screendraw:close",
                            tooltip = "Sair do Desenho (ESC)",
                            children = {
                                Zenith.Text({ text = "󰅖", font_size = 12, color = Zenith.hex(theme.outline) }),
                            }
                        }),
                    }
                })
            }
        }),

        -- Row 2: Color Palette Dots & Quick Shortcuts Hint
        Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "space_between",
            children = {
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 8,
                    children = color_dots,
                }),
                Zenith.Text({
                    text = "Desenho em tempo real • ESC para sair",
                    font_size = 9,
                    color = Zenith.hex(theme.outline),
                }),
            }
        })
    }
})
