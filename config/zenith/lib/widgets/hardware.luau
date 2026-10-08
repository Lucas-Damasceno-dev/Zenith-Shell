--!strict
-- Zenith UI Kit - Hardware Monitor Component (Quickshell / Caelestia style)

local function Hardware()
    local theme = Zenith.Theme()
    local mem = Zenith.Services.memory()
    local cpu = Zenith.Services.cpu()

    return Zenith.Box({
        direction = "row",
        gap = 8,
        padding = { x = 11, y = 3 },
        border_radius = 12,
        background = Zenith.rgba(255, 255, 255, 10),
        border_color = Zenith.rgba(255, 255, 255, 18),
        border_width = 1,
        on_click = "cmd:kitty -e btop &",
        children = {
            Zenith.Box({
                direction = "row",
                gap = 4,
                children = {
                    Zenith.Text({ text = "", font_size = 11, color = Zenith.hex(theme.primary) }),
                    Zenith.Text({ text = string.format("%d%%", cpu.percent), font_size = 11, color = Zenith.hex(theme.on_surface) }),
                }
            }),
            Zenith.Box({
                direction = "row",
                gap = 4,
                children = {
                    Zenith.Text({ text = "", font_size = 11, color = Zenith.hex(theme.primary) }),
                    Zenith.Text({ text = string.format("%d%%", mem.percent), font_size = 11, color = Zenith.hex(theme.on_surface) }),
                }
            }),
        }
    })
end

return Hardware
