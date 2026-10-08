-- DesktopCanvas: Ambient Desktop Surface Widget (Caelestia Desktop Canvas Parity)
-- Renders a modern glassmorphic dashboard card with large typography and hardware telemetry.

local theme = Zenith.Theme()
local time_str, date_str = Zenith.Services.time()
local mem = Zenith.Services.memory()
local weather = Zenith.Services.Weather()

return Zenith.Box({
    direction = "column",
    padding = { x = 24, y = 20 },
    gap = 16,
    border_radius = 24,
    background = Zenith.hex("#161922c0"),
    border_color = theme.outline,
    border_width = 1,
    shadow = {
        blur = 30,
        color = Zenith.hex("#00000066"),
        offset_y = 8,
    },
    children = {
        -- 1. Large Clock & Date & Weather
        Zenith.Box({
            direction = "column",
            gap = 4,
            children = {
                Zenith.Text({
                    text = time_str,
                    font_size = 40,
                    font_weight = "bold",
                    font_family = "JetBrainsMono Nerd Font",
                    color = theme.primary,
                }),
                Zenith.Box({
                    direction = "row",
                    gap = 8,
                    children = {
                        Zenith.Text({
                            text = date_str,
                            font_size = 14,
                            color = theme.on_surface,
                        }),
                        Zenith.Text({
                            text = "•",
                            font_size = 12,
                            color = theme.outline,
                        }),
                        Zenith.Text({
                            text = string.format("%s %.0f°C %s", weather.icon, weather.temp, weather.condition),
                            font_size = 13,
                            color = theme.primary,
                        }),
                    }
                }),
            }
        }),

        -- 2. Separator
        Zenith.Box({
            width = 300,
            height = 1,
            background = theme.outline,
            children = {},
        }),

        -- 3. Telemetry Gauges Card
        Zenith.Box({
            direction = "column",
            gap = 10,
            children = {
                -- RAM Usage Row
                Zenith.Box({
                    direction = "row",
                    justify_content = "space-between",
                    align_items = "center",
                    children = {
                        Zenith.Box({
                            direction = "row",
                            gap = 8,
                            align_items = "center",
                            children = {
                                Zenith.Text({
                                    text = "󰘚",
                                    font_size = 14,
                                    font_family = "JetBrainsMono Nerd Font",
                                    color = theme.primary,
                                }),
                                Zenith.Text({
                                    text = "Memory Active",
                                    font_size = 12,
                                    color = theme.on_surface,
                                }),
                            }
                        }),
                        Zenith.Text({
                            text = tostring(mem.percent) .. "% (" .. tostring(mem.used_mb) .. " MB)",
                            font_size = 12,
                            font_weight = "bold",
                            color = theme.primary,
                        }),
                    }
                }),

                -- Shell Status Row
                Zenith.Box({
                    direction = "row",
                    justify_content = "space-between",
                    align_items = "center",
                    children = {
                        Zenith.Box({
                            direction = "row",
                            gap = 8,
                            align_items = "center",
                            children = {
                                Zenith.Text({
                                    text = "⚡",
                                    font_size = 14,
                                    color = theme.primary,
                                    children = {},
                                }),
                                Zenith.Text({
                                    text = "Zenith Engine v2",
                                    font_size = 12,
                                    color = theme.on_surface,
                                    children = {},
                                }),
                            }
                        }),
                        Zenith.Text({
                            text = "sub-10ms | <15MB",
                            font_size = 11,
                            color = Zenith.hex("#a6accd"),
                            children = {},
                        }),
                    }
                }),
            }
        }),

        -- 4. Audio Visualizer Spectrum (CAVA)
        Zenith.Box({
            direction = "column",
            gap = 6,
            children = {
                Zenith.Box({
                    direction = "row",
                    justify_content = "space-between",
                    children = {
                        Zenith.Text({
                            text = "󰎈 Spectrum Visualizer",
                            font_size = 11,
                            color = theme.on_surface,
                            children = {},
                        }),
                    }
                }),
                Zenith.Box({
                    direction = "row",
                    gap = 4,
                    height = 24,
                    children = (function()
                        local bars = {}
                        local spec = Zenith.Services.Spectrum(16)
                        for _, val in ipairs(spec) do
                            local h = math.clamp(math.floor(val * 22) + 2, 2, 24)
                            table.insert(bars, Zenith.Box({
                                width = 14,
                                height = h,
                                border_radius = 2,
                                background = Zenith.hex(theme.primary),
                                children = {},
                            }))
                        end
                        return bars
                    end)(),
                })
            }
        }),
    }
})
