--!strict
-- Zenith-Shell (Engine v2) - Calendar & Agenda Overlay

local theme = Zenith.Theme()
local time_str, date_str = Zenith.Services.time()

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

-- Generate calendar day cells (1 to 31)
local grid_rows = {}
local current_row = {}
local active_day = 8

for d = 1, 31 do
    local is_today = (d == active_day)
    local bg = is_today and Zenith.hex(theme.primary) or Zenith.hex("#00000000")
    local fg = is_today and Zenith.hex(theme.on_primary) or Zenith.hex(theme.on_surface)

    table.insert(current_row, Zenith.Box({
        width = 38,
        height = 26,
        border_radius = 6,
        background = bg,
        padding = { x = 6, y = 4 },
        children = {
            Zenith.Text({ text = tostring(d), font_size = 11, color = fg })
        }
    }))

    if #current_row == 7 or d == 31 then
        table.insert(grid_rows, Zenith.Box({
            direction = "row",
            gap = 4,
            children = current_row,
        }))
        current_row = {}
    end
end

return Zenith.Window({
    direction = "column",
    width = 340,
    height = 360,
    padding = { x = 16, y = 14 },
    gap = 10,
    background = Zenith.rgba(18, 20, 26, 220),
    border_color = Zenith.hex(theme.primary),
    border_width = 1,
    border_radius = 12,
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
