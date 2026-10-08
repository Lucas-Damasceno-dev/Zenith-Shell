--!strict
-- Zenith-Shell (Engine v2) - Notification Center Overlay (Desktop Notifications & History & DND)

local theme = Zenith.Theme()
local notifs = Zenith.Services.Notifications()
local history = Zenith.Services.NotificationHistory()
local is_dnd = Zenith.Services.IsDND()

local notif_cards = {}

if #notifs == 0 and #history == 0 then
    table.insert(notif_cards, Zenith.Box({
        direction = "column",
        gap = 8,
        padding = { x = 20, y = 30 },
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
    -- Active Toasts
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
                Zenith.Text({
                    text = item.summary,
                    font_size = 13,
                    color = Zenith.hex(theme.on_surface),
                }),
                Zenith.Text({
                    text = (#item.body > 0) and item.body or "",
                    font_size = 11,
                    color = Zenith.rgba(255, 255, 255, 180),
                }),
            }
        }))
    end

    -- History Section if active is empty or has items
    if #history > 0 then
        table.insert(notif_cards, Zenith.Box({
            direction = "row",
            padding = { x = 4, y = 6 },
            children = {
                Zenith.Text({
                    text = string.format("󰋚 History (%d)", #history),
                    font_size = 11,
                    color = Zenith.hex(theme.outline),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 6, y = 2 },
                    border_radius = 4,
                    background = Zenith.rgba(255, 255, 255, 8),
                    on_click = "notification:clear_history",
                    children = {
                        Zenith.Text({ text = "Clear History", font_size = 9, color = Zenith.hex(theme.outline) })
                    }
                })
            }
        }))

        for i = 1, math.min(#history, 4) do
            local h = history[i]
            table.insert(notif_cards, Zenith.Box({
                direction = "column",
                gap = 2,
                padding = { x = 10, y = 6 },
                border_radius = 8,
                background = Zenith.rgba(255, 255, 255, 6),
                border_color = Zenith.rgba(255, 255, 255, 10),
                border_width = 1,
                children = {
                    Zenith.Text({
                        text = h.app_name .. " • " .. h.summary,
                        font_size = 11,
                        color = Zenith.rgba(255, 255, 255, 180),
                    }),
                }
            }))
        end
    end
end

return Zenith.Window({
    direction = "column",
    width = 390,
    height = 520,
    padding = { x = 16, y = 14 },
    gap = 12,
    background = Zenith.rgba(18, 20, 26, 230),
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
        -- Main Header: Title + DND Toggle + Clear All + Close
        Zenith.Box({
            direction = "row",
            children = {
                Zenith.Text({
                    text = string.format("󰂚 Notifications (%d)", #notifs),
                    font_size = 13,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                -- DND Button
                Zenith.Box({
                    padding = { x = 8, y = 4 },
                    border_radius = 6,
                    background = is_dnd and Zenith.rgba(224, 108, 117, 45) or Zenith.rgba(255, 255, 255, 12),
                    border_color = is_dnd and Zenith.hex("#e06c75") or Zenith.rgba(255, 255, 255, 20),
                    border_width = 1,
                    on_click = "notification:toggle_dnd",
                    children = {
                        Zenith.Text({
                            text = is_dnd and "󰂛 DND ON" or "󰂚 DND OFF",
                            font_size = 10,
                            color = is_dnd and Zenith.hex("#e06c75") or Zenith.hex(theme.on_surface),
                        }),
                    }
                }),
                Zenith.Box({ width = 6 }),
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
            gap = 6,
            flex_grow = 1,
            children = notif_cards,
        }),
    }
})
