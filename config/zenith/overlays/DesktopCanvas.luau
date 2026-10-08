-- DesktopCanvas: Ambient Desktop Surface Widget (Caelestia Desktop Canvas Parity)
-- Renders a modern glassmorphic dashboard card with large typography and hardware telemetry.

local theme = Zenith.Theme()
local time_str, date_str = Zenith.Services.time()
local mem = Zenith.Services.memory()

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
        -- 1. Large Clock & Date
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
                Zenith.Text({
                    text = date_str,
                    font_size = 14,
                    color = theme.on_surface,
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
                                }),
                                Zenith.Text({
                                    text = "Zenith Engine v2",
                                    font_size = 12,
                                    color = theme.on_surface,
                                }),
                            }
                        }),
                        Zenith.Text({
                            text = "sub-10ms | <15MB",
                            font_size = 11,
                            color = Zenith.hex("#a6accd"),
                        }),
                    }
                }),
            }
        }),
    }
})
