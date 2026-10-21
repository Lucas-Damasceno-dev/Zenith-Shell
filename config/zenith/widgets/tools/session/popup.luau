--!strict
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function PowerCard(props: {
    icon: string,
    title: string,
    subtitle: string,
    color: string,
    action: string,
})
    local theme = Theme.get()
    return Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        flex_grow = 1,
        height = 76,
        gap = 4,
        padding = { horizontal = 10, vertical = 8 },
        border_radius = 12,
        background = Zenith.hex(theme.surface_container, 130),
        border_color = Zenith.hex(props.color, 90),
        border_width = 1,
        tooltip = props.title .. " (" .. props.subtitle .. ")",
        cursor = "pointer",
        on_click = props.action,
        children = {
            Zenith.Text({
                text = props.icon,
                font_size = 22,
                color = Zenith.hex(props.color),
            }),
            Zenith.Text({
                text = props.title,
                font_size = 11,
                font_weight = "bold",
                color = Zenith.hex(theme.on_surface),
            }),
            Zenith.Text({
                text = props.subtitle,
                font_size = 9,
                color = Zenith.hex(theme.outline_variant or theme.outline),
            }),
        }
    })
end

local function PowerMenuPopup()
    local theme = Theme.get()

    return Zenith.Box({
        direction = "column",
        width = 380,
        height = 240,
        padding = { horizontal = 16, vertical = 14 },
        gap = 14,
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
                        text = " Menu de Sessão",
                        font_size = 13,
                        font_weight = "bold",
                        color = Zenith.hex(theme.error or "#f38ba8"),
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
                gap = 10,
                children = {
                    PowerCard({
                        icon = "",
                        title = "Bloquear",
                        subtitle = "LockScreen",
                        color = theme.primary,
                        action = "lock",
                    }),
                    PowerCard({
                        icon = "󰤄",
                        title = "Suspender",
                        subtitle = "Sleep",
                        color = theme.secondary or theme.primary,
                        action = "system:suspend",
                    }),
                    PowerCard({
                        icon = "󰑐",
                        title = "Reiniciar",
                        subtitle = "Reboot",
                        color = theme.tertiary or theme.primary,
                        action = "system:reboot",
                    }),
                    PowerCard({
                        icon = "",
                        title = "Desligar",
                        subtitle = "Power Off",
                        color = theme.error or "#f38ba8",
                        action = "system:poweroff",
                    }),
                }
            }),

            Zenith.Box({
                direction = "row",
                justify_content = "center",
                children = {
                    Zenith.Box({
                        padding = { horizontal = 12, vertical = 6 },
                        border_radius = 8,
                        background = Zenith.hex(theme.surface_container, 90),
                        cursor = "pointer",
                        on_click = "system:logout",
                        children = {
                            Zenith.Text({
                                text = "󰗼 Encerrar Sessão (Logout)",
                                font_size = 10,
                                color = Zenith.hex(theme.outline_variant or theme.outline),
                            })
                        }
                    })
                }
            })
        }
    })
end

return PowerMenuPopup
