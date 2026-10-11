--!strict
-- Zenith UI Kit - Clock & Date Component (Quickshell / Caelestia style)

local function Clock()
    local theme = Zenith.Theme()
    local time_str, date_str = Zenith.Services.time()
    local hm = if #time_str >= 5 then time_str:sub(1, 5) else time_str

    local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366 }
    local screen_w = screen.width or 1366
    local show_date = screen_w >= 1600

    local children = {
        Zenith.Text({
            text = " " .. hm,
            font_size = 11,
            color = Zenith.hex(theme.primary),
        }),
    }

    if show_date and date_str and #date_str > 0 then
        table.insert(children, Zenith.Text({
            text = date_str,
            font_size = 11,
            color = Zenith.rgba(255, 255, 255, 160),
        }))
    end

    return Zenith.Box({
        direction = "row",
        padding = { x = 8, y = 3 },
        gap = 5,
        border_radius = 12,
        background = Zenith.rgba(255, 255, 255, 12),
        border_color = Zenith.rgba(255, 255, 255, 22),
        border_width = 1,
        on_click = "popup:toggle:CalendarPopup",
        children = children,
    })
end

return Clock
