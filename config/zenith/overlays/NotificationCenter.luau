--!strict
-- Zenith-Shell (Engine v2) - Notification Center Overlay (Desktop Notifications & History & DND)

local theme = Zenith.Theme()
local Store = Zenith.import("settings_store")
local UIKit = Zenith.import("ui_kit")
local notifs = Zenith.Services.Notifications()
local history = Zenith.Services.NotificationHistory()
local is_dnd = Zenith.Services.IsDND() or (Store.get("dndEnabled") == true)

local total_notifs = #notifs
local max_visible = 5

if total_notifs == 0 then
    _G.__notif_scroll = 0
end

local scroll_offset = _G.__notif_scroll or 0
if scroll_offset > math.max(0, total_notifs - max_visible) then
    scroll_offset = math.max(0, total_notifs - max_visible)
end
if scroll_offset < 0 then
    scroll_offset = 0
end

local start_idx = scroll_offset + 1
local end_idx = math.min(total_notifs, start_idx + max_visible - 1)

local function scroll_up()
    _G.__notif_scroll = math.max(0, (_G.__notif_scroll or 0) - 1)
end

local function scroll_down()
    local max_s = math.max(0, total_notifs - max_visible)
    _G.__notif_scroll = math.min(max_s, (_G.__notif_scroll or 0) + 1)
end

local notif_cards = {}

if total_notifs == 0 and #history == 0 then
    table.insert(notif_cards, Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
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
    if total_notifs > max_visible then
        table.insert(notif_cards, Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { x = 2, y = 2 },
            children = {
                Zenith.Text({
                    text = string.format("Showing %d–%d of %d active • scroll", start_idx, end_idx, total_notifs),
                    font_size = 10,
                    color = Zenith.hex(theme.outline),
                }),
            }
        }))
    end

    -- Active Toasts (sliced by scroll offset)
    for i = start_idx, end_idx do
        local item = notifs[i]
        if not item then break end

        local is_critical = item.urgency == 2
        local border_c = is_critical and Zenith.hex("#e06c75") or Zenith.rgba(255, 255, 255, 18)
        local icon = (#item.app_icon > 0) and "󰵆" or "󰂚"

        local card_children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
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
        }

        if #item.body > 0 then
            table.insert(card_children, Zenith.Text({
                text = item.body,
                font_size = 11,
                color = Zenith.rgba(255, 255, 255, 180),
            }))
        end

        table.insert(notif_cards, Zenith.Box({
            direction = "column",
            align_items = "stretch",
            gap = 4,
            padding = { x = 12, y = 10 },
            border_radius = 10,
            background = Zenith.hex(theme.surface_container),
            border_color = border_c,
            border_width = 1,
            children = card_children,
        }))
    end

    -- History Section if active is empty or has room
    if total_notifs == 0 and #history > 0 then
        table.insert(notif_cards, Zenith.Box({
            direction = "row",
            align_items = "center",
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
                align_items = "stretch",
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

local win_height = if total_notifs == 0 and #history == 0 then 230
    elseif total_notifs == 0 then math.min(520, 130 + math.min(#history, 4) * 44)
    else math.min(540, 110 + ((end_idx - start_idx + 1) * 78))

return Zenith.Window({
    direction = "column",
    align_items = "stretch",
    width = 390,
    height = win_height,
    padding = { x = 16, y = 14 },
    gap = 12,
    background = Zenith.hex(theme.surface, 235),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
    border_width = 1,
    border_radius = 16,
    on_scroll_up = scroll_up,
    on_scroll_down = scroll_down,
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
            align_items = "center",
            children = {
                Zenith.Text({
                    text = string.format("󰂚 Notifications (%d)", total_notifs),
                    font_size = 13,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                -- DND Interactive Switch
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 4,
                    padding = { x = 6, y = 2 },
                    border_radius = 6,
                    background = is_dnd and Zenith.rgba(243, 139, 168, 35) or Zenith.hex(theme.surface_container),
                    children = {
                        Zenith.Text({
                            text = is_dnd and "󰂛 DND" or "󰂚 DND",
                            font_size = 10,
                            font_weight = "bold",
                            color = is_dnd and Zenith.hex(theme.error or "#f38ba8") or Zenith.hex(theme.outline),
                        }),
                        Zenith.Switch({
                            id = "switch_dnd_notif",
                            checked = is_dnd,
                            active_color = theme.error or "#f38ba8",
                            on_toggle = "notification:toggle_dnd",
                        }),
                    }
                }),
                Zenith.Box({ width = 6 }),
                -- Clear All Button
                UIKit.Button({
                    label = "Limpar Tudo",
                    icon = "󰃢",
                    variant = "outlined",
                    size = "sm",
                    on_click = "notification:clear",
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
            align_items = "stretch",
            gap = 6,
            flex_grow = 1,
            on_scroll_up = scroll_up,
            on_scroll_down = scroll_down,
            children = notif_cards,
        }),
    }
})
