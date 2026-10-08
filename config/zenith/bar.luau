--!strict
-- Zenith-Shell (v2) Status Bar Configuration in Luau
-- Dynamic Material You Theming via Matugen / Stylix

local theme = Zenith.Theme()
local time_str, date_str = Zenith.Services.time()
local mem = Zenith.Services.memory()
local compositor = Zenith.Services.compositor()
local battery = Zenith.Services.battery()

local battery_text = battery and string.format("🔋 %d%%", battery.percentage) or "⚡ AC"

return Zenith.Box({
    direction = "row",
    height = 38,
    padding = { x = 14, y = 4 },
    gap = 10,
    background = Zenith.hex(theme.background),
    border_color = Zenith.hex(theme.primary),
    border_width = 1,
    children = {
        -- Logo / Compositor pill styled with Matugen primary accent
        Zenith.Box({
            padding = { x = 12, y = 4 },
            border_radius = 6,
            background = Zenith.hex(theme.primary),
            children = {
                Zenith.Text({
                    text = "ZENITH • " .. compositor,
                    font_size = 12,
                    color = Zenith.hex(theme.on_primary),
                })
            }
        }),

        -- Memory telemetry pill styled with Matugen surface
        Zenith.Box({
            padding = { x = 14, y = 4 },
            border_radius = 6,
            background = Zenith.hex(theme.surface),
            border_color = Zenith.hex(theme.outline),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = string.format("RAM: %d MB (%d%%)", mem.used_mb, mem.percent),
                    font_size = 12,
                    color = Zenith.hex(theme.on_surface),
                })
            }
        }),

        -- Clock / Date / Power pill styled with Matugen surface container
        Zenith.Box({
            padding = { x = 14, y = 4 },
            border_radius = 6,
            background = Zenith.hex(theme.surface_container),
            border_color = Zenith.hex(theme.outline),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = string.format("🕒 %s • %s • %s", time_str, date_str, battery_text),
                    font_size = 12,
                    color = Zenith.hex(theme.on_surface),
                })
            }
        })
    }
})
