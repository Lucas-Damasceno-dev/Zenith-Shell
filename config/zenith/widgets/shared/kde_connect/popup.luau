--!strict
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function KdeConnectPopup()
    local theme = Theme.get()

    return Zenith.Box({
        direction = "column",
        width = 300,
        height = 200,
        padding = { horizontal = 16, vertical = 14 },
        gap = 10,
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
                        text = "󰄡 KDE Connect",
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
                direction = "column",
                align_items = "center",
                justify_content = "center",
                gap = 6,
                flex_grow = 1,
                children = {
                    Zenith.Text({
                        text = "󰄡 Procurando dispositivos...",
                        font_size = 12,
                        color = Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Text({
                        text = "Conecte seu smartphone na mesma rede",
                        font_size = 10,
                        color = Zenith.hex(theme.outline_variant or theme.outline),
                    }),
                }
            }),

            Zenith.Box({
                direction = "row",
                justify_content = "center",
                children = {
                    Zenith.Box({
                        padding = { horizontal = 10, vertical = 6 },
                        border_radius = 6,
                        background = Zenith.hex(theme.surface_container, 160),
                        cursor = "pointer",
                        on_click = "cmd:kdeconnect-app",
                        children = {
                            Zenith.Text({
                                text = "Abrir Configurações",
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

return KdeConnectPopup
