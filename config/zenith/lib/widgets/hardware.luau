--!strict
-- Zenith UI Kit - Hardware Monitor Component

local function Hardware()
    local theme = Zenith.Theme()
    local mem = Zenith.Services.memory()
    local cpu = Zenith.Services.cpu()

    return Zenith.Box({
        direction = "row",
        gap = 6,
        padding = { x = 10, y = 4 },
        border_radius = 8,
        background = Zenith.hex(theme.surface),
        border_color = Zenith.hex("#2d3748"),
        border_width = 1,
        on_click = "cmd:kitty -e btop &",
        children = {
            Zenith.Text({
                text = string.format(" CPU: %d%%  •  󰍛 RAM: %dMB (%d%%)", cpu.percent, mem.used_mb, mem.percent),
                font_size = 11,
                color = Zenith.hex(theme.on_surface),
            })
        }
    })
end

return Hardware
