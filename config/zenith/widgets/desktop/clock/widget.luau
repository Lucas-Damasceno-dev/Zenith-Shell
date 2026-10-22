--!strict
-- Zenith-Shell: Clock Widget
-- Digital time/date display with Calendar popup trigger

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")
local Store = Zenith.import("core/store")

type ClockProps = {
    reactive: boolean?,
}

local function Clock(props: ClockProps?)
    local theme = Theme.get()
    local time_str, date_str = "00:00:00", "2026-10-18"
    if Zenith.Services and Zenith.Services.time then
        time_str, date_str = Zenith.Services.time()
    end
    local hm = if #time_str >= 5 then time_str:sub(1, 5) else time_str

    local second_precision = Store.get("secondPrecision", false)
    local display_time = if second_precision then time_str else hm

    local screen = if Zenith.Services and Zenith.Services.Screen then Zenith.Services.Screen() else { width = 1366 }
    local screen_w = screen.width or 1366
    local show_date = screen_w >= 1200

    local time_binding = if Zenith.Signals and Zenith.Signals.Time then Zenith.Signals.Time else display_time
    local date_binding = if Zenith.Signals and Zenith.Signals.Date then Zenith.Signals.Date else date_str

    local children = {
        Zenith.Text({
            text = "",
            font_size = 12,
            color = Zenith.hex(theme.primary),
        }),
        Zenith.Text({
            text = time_binding,
            font_size = 11,
            color = Zenith.hex(theme.on_surface),
        }),
    }

    if show_date then
        table.insert(children, Zenith.Box({
            width = 1,
            height = 12,
            background = Zenith.hex(theme.outline_variant or theme.outline, 60),
            padding = { horizontal = 2, vertical = 0 },
            children = {},
        }))
        table.insert(children, Zenith.Text({
            text = date_binding,
            font_size = 11,
            color = Zenith.hex(theme.on_surface_variant or theme.outline, 200),
        }))
    end

    local full_date_tooltip = (if date_str and #date_str > 0 then (date_str .. " • " .. time_str) else "Data e Hora") 
        .. "\n• Clique: Abrir Calendário\n• Scroll: Ajustar Brilho da Tela (±5%)\n• Botão Direito: Configurações"

    return Pill({
        height = 26,
        border_radius = 13,
        padding = { horizontal = 9, vertical = 2 },
        gap = 5,
        tooltip = full_date_tooltip,
        on_click = PopupManager.toggle_action("CalendarPopup"),
        on_right_click = PopupManager.toggle_action("Settings"),
        on_scroll_up = "brightness:step:5",
        on_scroll_down = "brightness:step:-5",
        children = children,
    })
end

return Clock
