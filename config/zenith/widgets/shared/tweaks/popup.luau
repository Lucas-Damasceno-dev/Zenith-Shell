--!strict
-- Zenith-Shell: Quick Tweaks Popup

local Store = Zenith.import("core/store")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function TweaksPopup()
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
                        text = "󰏞 Ajustes Rápidos",
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
                padding = { horizontal = 10, vertical = 8 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container, 120),
                children = {
                    Zenith.Text({ text = "Modo Noturno (Filtro Azul)", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                    Zenith.Switch({
                        id = "tweaks_night_mode_switch",
                        checked = Store.get("nightLightEnabled") or false,
                        active_color = theme.primary,
                        on_toggle = "storage:toggle:nightLightEnabled",
                    }),
                }
            }),

            Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "space_between",
                padding = { horizontal = 10, vertical = 8 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container, 120),
                children = {
                    Zenith.Text({ text = "Efeito de Blur no Vidro", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                    Zenith.Switch({
                        id = "tweaks_blur_switch",
                        checked = Store.get("glassEffect", true),
                        active_color = theme.primary,
                        on_toggle = "storage:toggle:glassEffect",
                    }),
                }
            }),
        }
    })
end

return TweaksPopup
