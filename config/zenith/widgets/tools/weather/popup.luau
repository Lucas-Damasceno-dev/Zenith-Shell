--!strict
-- Zenith-Shell: Weather Details Popup

local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")
local PopupManager = Zenith.import("core/popup_manager")

local function WeatherPopup()
    local theme = Theme.get()
    local weather = Services.Weather.current()

    local temp_str = string.format("%d°C", weather.temp or 22)
    local city_str = weather.city or "Local"
    local cond_str = weather.condition or "Limpo"

    return Zenith.Box({
        direction = "column",
        width = 320,
        height = 240,
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
                        text = "󰖐 Previsão do Tempo",
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
                gap = 16,
                padding = { horizontal = 12, vertical = 10 },
                border_radius = 12,
                background = Zenith.hex(theme.surface_container_high or theme.surface_container, 120),
                children = {
                    Zenith.Text({
                        text = weather.icon or "󰖐",
                        font_size = 36,
                        color = Zenith.hex(theme.primary),
                    }),
                    Zenith.Box({
                        direction = "column",
                        gap = 2,
                        children = {
                            Zenith.Text({
                                text = temp_str,
                                font_size = 22,
                                font_weight = "bold",
                                color = Zenith.hex(theme.on_surface),
                            }),
                            Zenith.Text({
                                text = cond_str .. " • " .. city_str,
                                font_size = 11,
                                color = Zenith.hex(theme.on_surface_variant or theme.outline),
                            }),
                        }
                    })
                }
            }),

            Zenith.Box({
                direction = "row",
                justify_content = "space_between",
                padding = { horizontal = 10, vertical = 6 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container, 80),
                children = {
                    Zenith.Text({
                        text = string.format("Umidade: %d%%", weather.humidity or 60),
                        font_size = 10,
                        color = Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Text({
                        text = string.format("Vento: %d km/h", weather.wind or 12),
                        font_size = 10,
                        color = Zenith.hex(theme.on_surface),
                    }),
                }
            })
        }
    })
end

return WeatherPopup
