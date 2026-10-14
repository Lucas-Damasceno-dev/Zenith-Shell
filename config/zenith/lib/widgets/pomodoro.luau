--!strict
-- Zenith UI Kit - Pomodoro Status Component (Quickshell Parity)
-- Matches BarPomodoro.qml (Focus timer pill for top bar)

local Pill = Zenith.import("widgets/pill")

local function Pomodoro()
    local theme = Zenith.Theme()

    return Pill({
        icon = "󰅐",
        icon_size = 12,
        icon_color = Zenith.hex(theme.tertiary or theme.primary),
        label = "25m",
        label_size = 11,
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        gap = 4,
        tooltip = "Pomodoro: Foco Produtivo\n• Clique: Iniciar Ciclo de Foco (25min)\n• Botão Direito: Pausar / Reiniciar Ciclo",
        on_click = "cmd:notify-send -a 'Pomodoro' 'Ciclo de Foco' 'Iniciando bloco de 25 minutos de produtividade!' &",
        on_right_click = "cmd:notify-send -a 'Pomodoro' 'Pausa' 'Intervalo de 5 minutos iniciado.' &",
    })
end

return Pomodoro
