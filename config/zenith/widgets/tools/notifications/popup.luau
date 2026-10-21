--!strict
-- Zenith-Shell: Notification Center Popup

local Store = Zenith.import("core/store")
local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")
local PopupManager = Zenith.import("core/popup_manager")

local function NotificationCenterPopup()
    local theme = Theme.get()
    local notifs = Services.Notifications.list()
    local history = Services.Notifications.history()
    local is_dnd = Services.Notifications.is_dnd() or (Store.get("dndEnabled") == true)

    local total_notifs = #notifs
    local notif_cards = {}

    if total_notifs == 0 and #history == 0 then
        table.insert(notif_cards, Zenith.Box({
            direction = "column",
            align_items = "center",
            justify_content = "center",
            gap = 8,
            height = 140,
            children = {
                Zenith.Text({
                    text = "󰂚",
                    font_size = 28,
                    color = Zenith.hex(theme.outline_variant or theme.outline, 120),
                }),
                Zenith.Text({
                    text = "Nenhuma notificação recente",
                    font_size = 11,
                    color = Zenith.hex(theme.outline_variant or theme.outline),
                }),
            }
        }))
    else
        for idx, n in ipairs(notifs) do
            if idx <= 5 then
                table.insert(notif_cards, Zenith.Box({
                    direction = "column",
                    gap = 4,
                    padding = { horizontal = 12, vertical = 10 },
                    border_radius = 10,
                    background = Zenith.hex(theme.surface_container, 140),
                    border_color = Zenith.hex(theme.outline_variant or theme.outline, 40),
                    border_width = 1,
                    children = {
                        Zenith.Box({
                            direction = "row",
                            align_items = "center",
                            children = {
                                Zenith.Text({
                                    text = n.app_name or "Notificação",
                                    font_size = 10,
                                    font_weight = "bold",
                                    color = Zenith.hex(theme.primary),
                                }),
                                Zenith.Box({ flex_grow = 1 }),
                                Zenith.Box({
                                    padding = { horizontal = 6, vertical = 2 },
                                    border_radius = 4,
                                    background = Zenith.hex(theme.surface_container_highest or theme.surface_container),
                                    on_click = string.format("notification:dismiss:%s", tostring(n.id or idx)),
                                    children = {
                                        Zenith.Text({ text = "✕", font_size = 9, color = Zenith.hex(theme.on_surface) }),
                                    }
                                })
                            }
                        }),
                        Zenith.Text({
                            text = n.summary or "",
                            font_size = 11,
                            font_weight = "medium",
                            color = Zenith.hex(theme.on_surface),
                        }),
                        Zenith.Text({
                            text = n.body or "",
                            font_size = 10,
                            color = Zenith.hex(theme.on_surface_variant or theme.outline),
                        }),
                    }
                }))
            end
        end
    end

    return Zenith.Box({
        direction = "column",
        width = 360,
        height = 420,
        padding = { horizontal = 16, vertical = 14 },
        gap = 12,
        background = Zenith.hex(theme.surface, 235),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
        border_width = 1,
        border_radius = 16,
        shadow = {
            color = Zenith.rgba(0, 0, 0, 180),
            blur = 20,
            offset_x = 0,
            offset_y = 8,
        },
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                children = {
                    Zenith.Text({
                        text = "󰂚 Notificações",
                        font_size = 13,
                        font_weight = "bold",
                        color = Zenith.hex(theme.primary),
                    }),
                    Zenith.Box({ flex_grow = 1 }),
                    Zenith.Box({
                        padding = { horizontal = 8, vertical = 2 },
                        border_radius = 6,
                        background = Zenith.hex(theme.surface_container),
                        on_click = PopupManager.close_action(),
                        children = {
                            Zenith.Text({ text = "✕", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                        }
                    }),
                }
            }),

            Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "space_between",
                padding = { horizontal = 10, vertical = 6 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container, 80),
                children = {
                    Zenith.Box({
                        direction = "row",
                        align_items = "center",
                        gap = 6,
                        children = {
                            Zenith.Text({
                                text = "󰂛",
                                font_size = 12,
                                color = if is_dnd then Zenith.hex(theme.error or "#f38ba8") else Zenith.hex(theme.outline_variant or theme.outline),
                            }),
                            Zenith.Text({
                                text = "Não Perturbe (DND)",
                                font_size = 11,
                                color = Zenith.hex(theme.on_surface),
                            }),
                        }
                    }),
                    Zenith.Switch({
                        id = "notif_dnd_switch",
                        checked = is_dnd,
                        active_color = theme.error or theme.primary,
                        on_toggle = "notification:toggle_dnd",
                    }),
                }
            }),

            Zenith.Box({
                direction = "column",
                gap = 8,
                flex_grow = 1,
                children = notif_cards,
            }),

            Zenith.Box({
                direction = "row",
                justify_content = "space_between",
                align_items = "center",
                padding = { horizontal = 4, vertical = 2 },
                children = {
                    Zenith.Text({
                        text = string.format("%d notificações", total_notifs),
                        font_size = 10,
                        color = Zenith.hex(theme.outline_variant or theme.outline),
                    }),
                    Zenith.Box({
                        padding = { horizontal = 8, vertical = 4 },
                        border_radius = 6,
                        background = Zenith.hex(theme.surface_container, 160),
                        cursor = "pointer",
                        on_click = "notification:clear",
                        children = {
                            Zenith.Text({
                                text = "Limpar Todas",
                                font_size = 10,
                                color = Zenith.hex(theme.primary),
                            })
                        }
                    })
                }
            })
        }
    })
end

return NotificationCenterPopup
