--!strict
-- Zenith Desktop Shell — Environmental Desktop Widgets
-- Ambient clock, detailed calendar date, weather status and greeting

local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")
local CanvasDefaults = Zenith.import("canvas/defaults")

local function DesktopWidgets()
    local theme = Theme.get()
    local weather = Services.Weather.current()
    local time_str = os.date("%H:%M")
    local date_str = os.date("%A, %d de %B de %Y")

    local glass = Theme.glass("canvas_card", 28)

    return Zenith.Box({
        direction = "column",
        padding = CanvasDefaults.widget_padding,
        border_radius = glass.border_radius,
        background = glass.background,
        border_color = glass.border_color,
        border_width = glass.border_width,
        shadow = glass.shadow,
        gap = 14,
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "flex_end",
                gap = 16,
                children = {
                    Zenith.Text({
                        text = time_str,
                        font_family = "Inter",
                        font_size = CanvasDefaults.clock_font_size,
                        font_weight = "bold",
                        color = Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Box({
                        direction = "column",
                        gap = 4,
                        children = {
                            Zenith.Text({
                                text = date_str,
                                font_family = "Inter",
                                font_size = CanvasDefaults.date_font_size,
                                font_weight = "semibold",
                                color = Zenith.hex(theme.primary),
                            }),
                            Zenith.Box({
                                direction = "row",
                                align_items = "center",
                                gap = 8,
                                children = {
                                    Zenith.Text({
                                        text = weather.icon,
                                        font_size = 18,
                                        color = Zenith.hex(theme.primary),
                                    }),
                                    Zenith.Text({
                                        text = string.format("%d°C • %s (%s)", weather.temp, weather.condition, weather.city),
                                        font_family = "Inter",
                                        font_size = 13,
                                        color = Zenith.hex(theme.on_surface_variant),
                                    }),
                                },
                            }),
                        },
                    }),
                },
            }),
        },
    })
end

return DesktopWidgets
