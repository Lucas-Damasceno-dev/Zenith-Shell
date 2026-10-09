--!strict
-- Zenith-Shell (Engine v2) - Calendar & Agenda Overlay

local theme = Zenith.Theme()
local time_str, date_str = Zenith.Services.time()

local current_date = (Zenith.Services.date and Zenith.Services.date()) or { year = 2026, month = 10, day = 8, weekday = 4 }

-- Days of week header
local days_header = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" }
local header_boxes = {}
for _, day in ipairs(days_header) do
    table.insert(header_boxes, Zenith.Box({
        width = 38,
        padding = { x = 4, y = 4 },
        children = {
            Zenith.Text({ text = day, font_size = 10, color = Zenith.hex(theme.primary) })
        }
    }))
end

-- Calculate days in current month
local function get_days_in_month(m: number, y: number): number
    if m == 2 then
        local is_leap = (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
        return if is_leap then 29 else 28
    elseif m == 4 or m == 6 or m == 9 or m == 11 then
        return 30
    else
        return 31
    end
end

local total_days = get_days_in_month(current_date.month, current_date.year)

-- Calculate 1st day of month day of week (1=Mo..7=Su)
local today_wday = if current_date.weekday == 0 then 7 else current_date.weekday
local first_day_wday = ((today_wday - 1 - ((current_date.day - 1) % 7)) % 7)
if first_day_wday < 0 then
    first_day_wday = first_day_wday + 7
end
first_day_wday = first_day_wday + 1

local grid_rows = {}
local current_row = {}

-- Padding empty cells before day 1
for _ = 1, (first_day_wday - 1) do
    table.insert(current_row, Zenith.Box({
        width = 38,
        height = 24,
    }))
end

-- Fill days
for d = 1, total_days do
    local is_today = (d == current_date.day)
    local bg = is_today and Zenith.hex(theme.primary) or Zenith.hex("#00000000")
    local fg = is_today and Zenith.hex(theme.on_primary) or Zenith.hex(theme.on_surface)

    table.insert(current_row, Zenith.Box({
        width = 38,
        height = 24,
        border_radius = 6,
        background = bg,
        padding = { x = 6, y = 3 },
        children = {
            Zenith.Text({ text = tostring(d), font_size = 11, color = fg })
        }
    }))

    if #current_row == 7 then
        table.insert(grid_rows, Zenith.Box({
            direction = "row",
            gap = 4,
            children = current_row,
        }))
        current_row = {}
    end
end

if #current_row > 0 then
    while #current_row < 7 do
        table.insert(current_row, Zenith.Box({ width = 38, height = 24 }))
    end
    table.insert(grid_rows, Zenith.Box({
        direction = "row",
        gap = 4,
        children = current_row,
    }))
end

return Zenith.Window({
    direction = "column",
    width = 340,
    height = 330,
    padding = { x = 16, y = 14 },
    gap = 8,
    background = Zenith.rgba(18, 20, 26, 235),
    border_color = Zenith.rgba(255, 255, 255, 28),
    border_width = 1,
    border_radius = 16,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 160),
        blur = 16,
        offset_x = 0,
        offset_y = 6,
    },
    children = {
        -- Header with title and close button
        Zenith.Box({
            direction = "row",
            children = {
                Zenith.Text({
                    text = "󰃭 " .. date_str,
                    font_size = 13,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 8, y = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "✕", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            }
        }),

        -- Time badge
        Zenith.Box({
            padding = { x = 10, y = 6 },
            border_radius = 8,
            background = Zenith.hex(theme.surface),
            border_color = Zenith.hex("#2d3748"),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = " Local Time: " .. time_str,
                    font_size = 12,
                    color = Zenith.hex(theme.on_surface),
                })
            }
        }),

        -- Days header (Mo Tu We Th Fr Sa Su)
        Zenith.Box({
            direction = "row",
            gap = 4,
            children = header_boxes,
        }),

        -- Days matrix
        Zenith.Box({
            direction = "column",
            gap = 4,
            children = grid_rows,
        }),
    }
})
