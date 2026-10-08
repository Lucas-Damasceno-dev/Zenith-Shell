--!strict
-- Zenith-Shell (v2) Default Status Bar Configuration in Luau

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
    background = Zenith.hex("#11121bf2"),
    border_color = Zenith.hex("#7c4dff"),
    border_width = 1,
    children = {
        -- Logo / Compositor pill
        Zenith.Box({
            padding = { x = 12, y = 4 },
            border_radius = 6,
            background = Zenith.hex("#7c4dff"),
            children = {
                Zenith.Text({
                    text = "ZENITH • " .. compositor,
                    font_size = 12,
                    color = Zenith.hex("#FFFFFF"),
                })
            }
        }),

        -- Memory telemetry pill
        Zenith.Box({
            padding = { x = 14, y = 4 },
            border_radius = 6,
            background = Zenith.hex("#1e202fcc"),
            border_color = Zenith.hex("#33364f"),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = string.format("RAM: %d MB (%d%%)", mem.used_mb, mem.percent),
                    font_size = 12,
                    color = Zenith.hex("#c5c9de"),
                })
            }
        }),

        -- Clock / Date / Power pill
        Zenith.Box({
            padding = { x = 14, y = 4 },
            border_radius = 6,
            background = Zenith.hex("#181926"),
            border_color = Zenith.hex("#2c2e42"),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = string.format("🕒 %s • %s • %s", time_str, date_str, battery_text),
                    font_size = 12,
                    color = Zenith.hex("#a6accd"),
                })
            }
        })
    }
})
