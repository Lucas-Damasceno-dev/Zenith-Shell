--!strict
-- Zenith-Shell: Calendar & Agenda Popup
-- Interactive monthly calendar grid with pomodoro integration

local Store = Zenith.import("core/store")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function CalendarPopup()
    local theme = Theme.get()
    local time_str, date_str = "00:00:00", "2026-10-18"
    if Zenith.Services and Zenith.Services.time then
        time_str, date_str = Zenith.Services.time()
    end
    local pomodoro_active = Store.get("pomodoroActive") or false
    local pomodoro_focus = Store.get("pomodoroFocus") or 25

    local current_date = (Zenith.Services and Zenith.Services.date and Zenith.Services.date()) or { year = 2026, month = 10, day = 8, weekday = 4 }

    local days_header = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" }
    local header_boxes = {}
    for _, day in ipairs(days_header) do
        table.insert(header_boxes, Zenith.Box({
            width = 38,
            padding = { horizontal = 4, vertical = 4 },
            align_items = "center",
            justify_content = "center",
            children = {
                Zenith.Text({ text = day, font_size = 10, color = Zenith.hex(theme.primary) })
            }
        }))
    end

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

    local today_wday = if current_date.weekday == 0 then 7 else current_date.weekday
    local first_day_wday = ((today_wday - 1 - ((current_date.day - 1) % 7)) % 7)
    if first_day_wday < 0 then
        first_day_wday = first_day_wday + 7
    end
    first_day_wday = first_day_wday + 1

    local grid_rows = {}
    local current_row = {}

    for _ = 1, (first_day_wday - 1) do
        table.insert(current_row, Zenith.Box({
            width = 38,
            height = 24,
        }))
    end

    for d = 1, total_days do
        local is_today = (d == current_date.day)
        local bg = is_today and Zenith.hex(theme.primary) or Zenith.hex("#00000000")
        local fg = is_today and Zenith.hex(theme.on_primary) or Zenith.hex(theme.on_surface)

        table.insert(current_row, Zenith.Box({
            width = 38,
            height = 24,
            border_radius = 6,
            background = bg,
            padding = { horizontal = 6, vertical = 3 },
            align_items = "center",
            justify_content = "center",
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

    return Zenith.Box({
        direction = "column",
        width = 340,
        height = 390,
        padding = { horizontal = 16, vertical = 14 },
        gap = 8,
        background = Zenith.hex(theme.surface, 235),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
        border_width = 1,
        border_radius = 16,
        shadow = {
            color = Zenith.rgba(0, 0, 0, 160),
            blur = 16,
            offset_x = 0,
            offset_y = 6,
        },
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                children = {
                    Zenith.Text({
                        text = "󰃭 " .. (date_str or ""),
                        font_size = 13,
                        font_weight = "bold",
                        color = Zenith.hex(theme.primary),
                    }),
                    Zenith.Box({ flex_grow = 1 }),
                    Zenith.Box({
                        padding = { horizontal = 8, vertical = 2 },
                        border_radius = 6,
                        background = Zenith.hex(theme.surface_container),
                        on_click = PopupManager.close_action(),
                        children = {
                            Zenith.Text({ text = "✕", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                        }
                    }),
                }
            }),

            Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "space_between",
                padding = { horizontal = 10, vertical = 6 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container_high or theme.surface),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 40),
                border_width = 1,
                children = {
                    Zenith.Text({
                        text = " " .. (time_str or ""),
                        font_size = 12,
                        color = Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Text({
                        text = string.format("%04d-%02d", current_date.year, current_date.month),
                        font_size = 11,
                        font_weight = "bold",
                        color = Zenith.hex(theme.primary),
                    }),
                }
            }),

            Zenith.Box({
                direction = "row",
                gap = 4,
                children = header_boxes,
            }),

            Zenith.Box({
                direction = "column",
                gap = 4,
                children = grid_rows,
            }),

            Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "space_between",
                padding = { horizontal = 10, vertical = 6 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container, 80),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 30),
                border_width = 1,
                children = {
                    Zenith.Box({
                        direction = "row",
                        align_items = "center",
                        gap = 8,
                        children = {
                            Zenith.Text({
                                text = "󰔛",
                                font_size = 14,
                                color = pomodoro_active and Zenith.hex(theme.primary) or Zenith.hex(theme.outline_variant or theme.outline),
                            }),
                            Zenith.Box({
                                direction = "column",
                                children = {
                                    Zenith.Text({
                                        text = "Pomodoro Timer (" .. tostring(pomodoro_focus) .. "m)",
                                        font_size = 11,
                                        color = Zenith.hex(theme.on_surface),
                                    }),
                                    Zenith.Text({
                                        text = pomodoro_active and "Sessão de foco ativa" or "Temporizador inativo",
                                        font_size = 9,
                                        color = pomodoro_active and Zenith.hex(theme.primary) or Zenith.hex(theme.outline_variant or theme.outline),
                                    }),
                                }
                            }),
                        }
                    }),
                    Zenith.Switch({
                        id = "switch_calendar_pomodoro",
                        checked = pomodoro_active,
                        active_color = theme.primary,
                        on_toggle = "storage:toggle:pomodoroActive",
                    }),
                }
            }),
        }
    })
end

return CalendarPopup
