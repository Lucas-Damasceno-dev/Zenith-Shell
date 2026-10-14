--!strict
-- Zenith UI Kit - Clock & Date Component (Quickshell / Caelestia style)

local Pill = Zenith.import("widgets/pill")

local function Clock(props: { reactive: boolean? }?)
    local theme = Zenith.Theme()
    local time_str, date_str = Zenith.Services.time()
    local hm = if #time_str >= 5 then time_str:sub(1, 5) else time_str

    local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366 }
    local screen_w = screen.width or 1366
    local show_date = screen_w >= 1200

    -- Granular reactive text binding to eliminate top-bar AST rebuilds
    local time_binding = if Zenith.Signals and Zenith.Signals.Time then Zenith.Signals.Time else hm
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
            margin = { x = 2, y = 0 },
            children = {},
        }))
        table.insert(children, Zenith.Text({
            text = date_binding,
            font_size = 11,
            color = Zenith.hex(theme.on_surface_variant or theme.outline, 200),
        }))
    end

    local full_date_tooltip = (if date_str and #date_str > 0 then (date_str .. " • " .. time_str) else "Data e Hora") .. "\n• Clique: Abrir Calendário\n• Scroll: Ajustar Brilho da Tela (±5%)\n• Botão Direito: Configurações"

    return Pill({
        height = 26,
        border_radius = 13,
        padding = { x = 9, y = 2 },
        gap = 5,
        tooltip = full_date_tooltip,
        on_click = "popup:toggle:CalendarPopup",
        on_right_click = "popup:toggle:Settings",
        on_scroll_up = "brightness:step:5",
        on_scroll_down = "brightness:step:-5",
        children = children,
    })
end

return Clock
