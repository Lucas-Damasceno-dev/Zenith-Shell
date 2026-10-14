--!strict
-- Zenith UI Kit - Battery Status Component (Quickshell Parity)
-- Matches BarBatteryStatus.qml (Battery percentage, charging glyph, and BatteryPopup)

local Pill = Zenith.import("widgets/pill")

local function BatteryWidget()
    local theme = Zenith.Theme()
    local battery = Zenith.Services.battery()

    local bat_pct = 100
    local is_charging = false
    if battery then
        bat_pct = battery.percentage or 100
        is_charging = battery.is_charging or false
    end

    local bat_icon = "󰁹"
    local bat_color = Zenith.hex(theme.primary)

    if is_charging then
        bat_icon = "󰂄"
        bat_color = Zenith.hex(theme.green or "#a6e3a1")
    elseif bat_pct > 80 then
        bat_icon = "󰁹"
        bat_color = Zenith.hex(theme.primary)
    elseif bat_pct > 50 then
        bat_icon = "󰁿"
        bat_color = Zenith.hex(theme.primary)
    elseif bat_pct > 20 then
        bat_icon = "󰁼"
        bat_color = Zenith.hex(theme.yellow or "#f9e2af")
    else
        bat_icon = "󰂃"
        bat_color = Zenith.hex(theme.error or "#f38ba8")
    end

    local label_str = string.format("%d%%", bat_pct)
    local tooltip = string.format("Bateria: %d%%%s\n• Clique: Detalhes & Perfis de Energia\n• Botão Direito: Ativar Modo Performance",
        bat_pct, if is_charging then " (Carregando)" else "")

    return Pill({
        icon = bat_icon,
        icon_size = 12,
        icon_color = bat_color,
        label = label_str,
        label_size = 11,
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        gap = 4,
        tooltip = tooltip,
        on_click = "popup:toggle:BatteryPopup",
        on_right_click = "power:profile:performance",
    })
end

return BatteryWidget
