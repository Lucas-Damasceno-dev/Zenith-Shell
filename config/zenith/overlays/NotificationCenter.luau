--!strict
-- Zenith-Shell (Engine v2) - Notification Center Overlay (Desktop Notifications)

local theme = Zenith.Theme()
local notifs = Zenith.Services.Notifications()

local notif_cards = {}

if #notifs == 0 then
    table.insert(notif_cards, Zenith.Box({
        direction = "column",
        gap = 8,
        padding = { x = 20, y = 40 },
        border_radius = 12,
        background = Zenith.rgba(255, 255, 255, 8),
        children = {
            Zenith.Text({
                text = "󰂜",
                font_size = 28,
                color = Zenith.hex(theme.outline),
            }),
            Zenith.Text({
                text = "No Notifications",
                font_size = 14,
                color = Zenith.hex(theme.on_surface),
            }),
            Zenith.Text({
                text = "You're all caught up!",
                font_size = 11,
                color = Zenith.hex(theme.outline),
            }),
        }
    }))
else
    for _, item in ipairs(notifs) do
        local is_critical = item.urgency == 2
        local border_c = is_critical and Zenith.hex("#e06c75") or Zenith.rgba(255, 255, 255, 18)
        local icon = (#item.app_icon > 0) and "󰵆" or "󰂚"

        table.insert(notif_cards, Zenith.Box({
            direction = "column",
            gap = 4,
            padding = { x = 12, y = 10 },
            border_radius = 10,
            background = Zenith.hex(theme.surface_container),
            border_color = border_c,
            border_width = 1,
            children = {
                -- Header: App name + Close toast button
                Zenith.Box({
                    direction = "row",
                    children = {
                        Zenith.Text({
                            text = icon .. " " .. item.app_name:upper(),
                            font_size = 10,
                            color = is_critical and Zenith.hex("#e06c75") or Zenith.hex(theme.primary),
                        }),
                        Zenith.Box({ flex_grow = 1 }),
                        Zenith.Box({
                            padding = { x = 6, y = 2 },
                            border_radius = 4,
                            background = Zenith.rgba(255, 255, 255, 10),
                            on_click = string.format("notification:close:%d", item.id),
                            children = {
                                Zenith.Text({ text = "✕", font_size = 10, color = Zenith.hex(theme.outline) })
                            }
                        })
                    }
                }),

                -- Summary / Title
                Zenith.Text({
                    text = item.summary,
                    font_size = 13,
                    color = Zenith.hex(theme.on_surface),
                }),

                -- Body text
                Zenith.Text({
                    text = (#item.body > 0) and item.body or "",
                    font_size = 11,
                    color = Zenith.rgba(255, 255, 255, 180),
                }),
            }
        }))
    end
end

return Zenith.Window({
    direction = "column",
    width = 380,
    height = 500,
    padding = { x = 16, y = 14 },
    gap = 12,
    background = Zenith.rgba(18, 20, 26, 225),
    border_color = Zenith.hex(theme.primary),
    border_width = 1,
    border_radius = 16,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 22,
        offset_x = 0,
        offset_y = 8,
    },
    children = {
        -- Main Header: Title + Clear All + Close
        Zenith.Box({
            direction = "row",
            children = {
                Zenith.Text({
                    text = string.format("󰂚 Notifications (%d)", #notifs),
                    font_size = 13,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 8, y = 4 },
                    border_radius = 6,
                    background = Zenith.rgba(255, 255, 255, 12),
                    on_click = "notification:clear",
                    children = {
                        Zenith.Text({ text = "Clear All", font_size = 10, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
                Zenith.Box({ width = 6 }),
                Zenith.Box({
                    padding = { x = 8, y = 4 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "✕", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            }
        }),

        -- Notification Cards Scroll/Stack
        Zenith.Box({
            direction = "column",
            gap = 8,
            flex_grow = 1,
            children = notif_cards,
        }),
    }
})
