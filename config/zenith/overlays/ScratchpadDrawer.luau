--!strict
-- Zenith Desktop Shell — Scratchpad Drawer Overlay
-- Manages Hyprland special workspace windows and rapid scratchpads

local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")
local Button = Zenith.import("core/ui/button")
local Card = Zenith.import("core/ui/card")

local function ScratchpadDrawer()
    local theme = Theme.get()
    local clients = Services.Hyprland.clients()

    local scratch_items = {}
    for _, c in ipairs(clients) do
        table.insert(scratch_items, Button({
            label = if c.title ~= "" then c.title else c.class,
            icon = "󰖲",
            variant = if c.focused then "primary" else "tonal",
            width = "100%",
            on_click = "focus:" .. c.address,
        }))
    end

    return Card({
        variant = "glass",
        width = 420,
        padding = 18,
        gap = 14,
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "space_between",
                width = "100%",
                children = {
                    Zenith.Box({
                        direction = "row",
                        align_items = "center",
                        gap = 8,
                        children = {
                            Zenith.Text({ text = "󰖲", font_size = 18, color = Zenith.hex(theme.primary) }),
                            Zenith.Text({
                                text = "Área Especial (Scratchpad)",
                                font_family = "Inter",
                                font_size = 14,
                                font_weight = "bold",
                                color = Zenith.hex(theme.on_surface),
                            }),
                        },
                    }),
                    Zenith.Box({
                        cursor = "pointer",
                        tooltip = "Fechar",
                        on_click = "popup:close",
                        padding = 4,
                        children = {
                            Zenith.Text({ text = "󰅖", font_size = 14, color = Zenith.hex(theme.on_surface_variant) }),
                        },
                    }),
                },
            }),
            Zenith.Box({
                direction = "row",
                gap = 10,
                width = "100%",
                children = {
                    Button({
                        label = "Alternar Visibilidade",
                        icon = "󰈈",
                        variant = "primary",
                        on_click = "cmd:hyprctl dispatch togglespecialworkspace",
                    }),
                    Button({
                        label = "Mover Janela Ativa",
                        icon = "󰆒",
                        variant = "outlined",
                        on_click = "cmd:hyprctl dispatch movetoworkspace special",
                    }),
                },
            }),
            Zenith.Box({
                direction = "column",
                width = "100%",
                gap = 6,
                children = scratch_items,
            }),
        },
    })
end

return ScratchpadDrawer()
