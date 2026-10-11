--!strict
-- Zenith UI Kit - Hardware Monitor Component (Quickshell / Caelestia style)

local function Hardware()
    local theme = Zenith.Theme()
    local mem = Zenith.Services.memory()
    local cpu = Zenith.Services.cpu()

    local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366 }
    local screen_w = screen.width or 1366
    local pad_x = if screen_w < 1440 then 6 else 8
    local gap_val = if screen_w < 1440 then 4 else 6

    return Zenith.Box({
        direction = "row",
        gap = gap_val,
        padding = { x = pad_x, y = 3 },
        border_radius = 12,
        background = Zenith.rgba(255, 255, 255, 10),
        border_color = Zenith.rgba(255, 255, 255, 18),
        border_width = 1,
        on_click = "cmd:foot btop &",
        children = {
            Zenith.Box({
                direction = "row",
                gap = 3,
                children = {
                    Zenith.Text({ text = "", font_size = 11, color = Zenith.hex(theme.primary) }),
                    Zenith.Text({ text = string.format("%d%%", cpu.percent), font_size = 11, color = Zenith.hex(theme.on_surface) }),
                }
            }),
            Zenith.Box({
                direction = "row",
                gap = 3,
                children = {
                    Zenith.Text({ text = "", font_size = 11, color = Zenith.hex(theme.primary) }),
                    Zenith.Text({ text = string.format("%d%%", mem.percent), font_size = 11, color = Zenith.hex(theme.on_surface) }),
                }
            }),
        }
    })
end

return Hardware
