--!strict
-- Zenith-Shell (Engine v2) - Power & Session Control Overlay

local theme = Zenith.Theme()

return Zenith.Window({
    direction = "column",
    width = 280,
    height = 220,
    padding = { x = 14, y = 12 },
    gap = 8,
    background = Zenith.rgba(18, 20, 26, 220),
    border_color = Zenith.hex("#e06c75"),
    border_width = 1,
    border_radius = 12,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 160),
        blur = 16,
        offset_x = 0,
        offset_y = 6,
    },
    children = {
        -- Header with title and close button
        Zenith.Box({
            direction = "row",
            children = {
                Zenith.Text({
                    text = "⏻ Session Control",
                    font_size = 13,
                    color = Zenith.hex("#e06c75"),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 8, y = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "✕", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            }
        }),

        -- 4 Power Action options
        Zenith.Box({
            padding = { x = 10, y = 6 },
            border_radius = 8,
            background = Zenith.hex(theme.surface),
            on_click = "cmd:loginctl lock-session",
            children = {
                Zenith.Text({ text = "󰌾  Lock Screen", font_size = 11, color = Zenith.hex(theme.on_surface) }),
            }
        }),

        Zenith.Box({
            padding = { x = 10, y = 6 },
            border_radius = 8,
            background = Zenith.hex(theme.surface),
            on_click = "cmd:systemctl suspend",
            children = {
                Zenith.Text({ text = "󰒲  Suspend", font_size = 11, color = Zenith.hex(theme.on_surface) }),
            }
        }),

        Zenith.Box({
            padding = { x = 10, y = 6 },
            border_radius = 8,
            background = Zenith.hex(theme.surface),
            on_click = "cmd:systemctl reboot",
            children = {
                Zenith.Text({ text = "  Reboot System", font_size = 11, color = Zenith.hex(theme.primary) }),
            }
        }),

        Zenith.Box({
            padding = { x = 10, y = 6 },
            border_radius = 8,
            background = Zenith.hex("#e06c75"),
            on_click = "cmd:systemctl poweroff",
            children = {
                Zenith.Text({ text = "⏻  Power Off", font_size = 11, color = Zenith.hex("#ffffff") }),
            }
        }),
    }
})
