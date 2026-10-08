--!strict
-- Zenith UI Kit - Clock & Date Component (Quickshell / Caelestia style)

local function Clock()
    local theme = Zenith.Theme()
    local time_str, date_str = Zenith.Services.time()

    return Zenith.Box({
        direction = "row",
        padding = { x = 12, y = 3 },
        gap = 8,
        border_radius = 12,
        background = Zenith.rgba(255, 255, 255, 12),
        border_color = Zenith.rgba(255, 255, 255, 22),
        border_width = 1,
        on_click = "popup:toggle:CalendarPopup",
        children = {
            Zenith.Text({
                text = " " .. time_str,
                font_size = 12,
                color = Zenith.hex(theme.primary),
            }),
            Zenith.Text({
                text = date_str,
                font_size = 11,
                color = Zenith.rgba(255, 255, 255, 160),
            }),
        }
    })
end

return Clock
