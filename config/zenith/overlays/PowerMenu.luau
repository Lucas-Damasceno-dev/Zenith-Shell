--!strict
-- Zenith-Shell (Engine v2) - Power & Session Control Overlay
-- 1:1 Parity with Quickshell SessionPopup (Lock, Suspend, Reboot, Poweroff)

local theme = Zenith.Theme()

local function PowerCard(props: {
    icon: string,
    title: string,
    subtitle: string,
    color: string,
    bg_color: string?,
    action: string,
})
    return Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        flex_grow = 1,
        height = 76,
        gap = 4,
        padding = { x = 10, y = 8 },
        border_radius = 12,
        background = props.bg_color or Zenith.hex(theme.surface_container, 130),
        border_color = Zenith.hex(props.color, 90),
        border_width = 1,
        tooltip = props.title .. " (" .. props.subtitle .. ")",
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
                font_weight = "medium",
                color = Zenith.hex(theme.on_surface),
            }),
            Zenith.Text({
                text = props.subtitle,
                font_size = 9,
                color = Zenith.hex(theme.outline),
            }),
        }
    })
end

return Zenith.Window({
    direction = "column",
    width = 330,
    height = 250,
    padding = { x = 16, y = 14 },
    gap = 12,
    background = Zenith.hex(theme.surface, 235),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
    border_width = 1,
    border_radius = 18,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 22,
        offset_x = 0,
        offset_y = 8,
    },
    children = {
        -- Header with title and close button
        Zenith.Box({
            direction = "row",
            align_items = "center",
            children = {
                Zenith.Text({
                    text = "⏻ Menu de Sessão",
                    font_size = 13,
                    font_weight = "medium",
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 6, y = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "ESC", font_size = 9, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            }
        }),

        -- 2x2 Grid of Actions
        Zenith.Box({
            direction = "column",
            gap = 8,
            children = {
                -- Row 1: Lock & Suspend
                Zenith.Box({
                    direction = "row",
                    gap = 8,
                    children = {
                        PowerCard({
                            icon = "󰌾",
                            title = "Bloquear",
                            subtitle = "lock",
                            color = theme.primary,
                            action = "lock",
                        }),
                        PowerCard({
                            icon = "󰒲",
                            title = "Suspender",
                            subtitle = "suspend",
                            color = theme.secondary or theme.primary,
                            action = "system:suspend",
                        }),
                    }
                }),

                -- Row 2: Reboot & Poweroff
                Zenith.Box({
                    direction = "row",
                    gap = 8,
                    children = {
                        PowerCard({
                            icon = "",
                            title = "Reiniciar",
                            subtitle = "reboot",
                            color = theme.yellow or "#e5c07b",
                            action = "system:reboot",
                        }),
                        PowerCard({
                            icon = "⏻",
                            title = "Desligar",
                            subtitle = "poweroff",
                            color = theme.error or "#f38ba8",
                            bg_color = Zenith.hex(theme.error or "#f38ba8", 40),
                            action = "system:poweroff",
                        }),
                    }
                }),
            }
        }),

        -- Footer helper
        Zenith.Box({
            direction = "row",
            justify_content = "center",
            padding = { x = 0, y = 2 },
            children = {
                Zenith.Text({
                    text = "Atalhos rápidos: Super+L Bloquear • Esc Fechar",
                    font_size = 9,
                    color = Zenith.hex(theme.outline),
                })
            }
        })
    }
})
