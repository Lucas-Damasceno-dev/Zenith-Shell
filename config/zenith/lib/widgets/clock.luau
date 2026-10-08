--!strict
-- Zenith UI Kit - Clock & Date Component

local function Clock()
    local theme = Zenith.Theme()
    local time_str, date_str = Zenith.Services.time()

    return Zenith.Box({
        padding = { x = 12, y = 4 },
        border_radius = 8,
        background = Zenith.hex(theme.surface_container),
        border_color = Zenith.hex(theme.primary),
        border_width = 1,
        on_click = "cmd:notify-send 'Calendar' 'Calendar requested'",
        children = {
            Zenith.Text({
                text = string.format("󰃭 %s  •   %s", date_str, time_str),
                font_size = 11,
                color = Zenith.hex(theme.primary),
            })
        }
    })
end

return Clock
