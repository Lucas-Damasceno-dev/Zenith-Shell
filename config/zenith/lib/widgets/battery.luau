--!strict
-- Zenith UI Kit - Battery Status Component (Quickshell Parity)
-- Matches BarBatteryStatus.qml (Battery percentage, charging glyph, caffeine badge, power profile cycling, brightness scroll)

local Pill = Zenith.import("widgets/pill")
local Store = Zenith.import("settings_store")

export type BatteryWidgetProps = {
    on_click: string?,
    on_right_click: string?,
    on_middle_click: string?,
    on_scroll_up: string?,
    on_scroll_down: string?,
    caffeine_action: string?,
    replace_icon: boolean?,
    [string]: any,
}

local function BatteryWidget(props: BatteryWidgetProps?)
    local p = props or {}
    local theme = Zenith.Theme()
    local battery = Zenith.Services.battery()

    -- Power profile detection & cycling: power-saver -> balanced -> performance -> power-saver
    local current_prof = "balanced"
    if Zenith.Services.power_profile then
        current_prof = Zenith.Services.power_profile()
    elseif Zenith.Services.PowerProfile then
        current_prof = Zenith.Services.PowerProfile()
    else
        current_prof = Store.get("batteryPowerProfile") or "balanced"
    end
    current_prof = string.lower(current_prof or "balanced")

    local next_prof = if current_prof == "power-saver" or current_prof == "low-power" then "balanced"
        elseif current_prof == "balanced" then "performance"
        else "power-saver"

    -- Caffeine mode state: check Zenith.Storage then SettingsStore
    local caffeine_active = false
    if Zenith.Storage and Zenith.Storage.get then
        local st_val = Zenith.Storage.get("batteryCaffeineActive", nil)
        if st_val ~= nil then
            caffeine_active = (st_val == true or st_val == "true" or st_val == 1)
        else
            caffeine_active = Store.get("batteryCaffeineActive") or false
        end
    else
        caffeine_active = Store.get("batteryCaffeineActive") or false
    end

    local bat_pct = 100
    local is_charging = false
    local has_bat = false

    if battery and battery.percentage ~= nil then
        bat_pct = battery.percentage
        is_charging = battery.is_charging or false
        has_bat = (bat_pct >= 0)
    end

    -- Dynamic contextual glyph (Quickshell BarBatteryStatus.qml parity)
    local bat_icon = "󰁹"
    local bat_color = Zenith.hex(theme.primary)

    if not has_bat then
        bat_icon = if current_prof == "power-saver" then "\u{f06c}"
            elseif current_prof == "performance" then "\u{f135}"
            else "\u{f24e}"
        bat_color = Zenith.hex(theme.primary)
    elseif is_charging then
        bat_icon = "󰂄"
        bat_color = Zenith.hex(theme.green or "#a6e3a1")
    elseif bat_pct > 80 then
        bat_icon = "󰁹"
        bat_color = Zenith.hex(theme.primary)
    elseif bat_pct > 50 then
        bat_icon = "󰁿"
        bat_color = Zenith.hex(theme.primary)
    elseif bat_pct > 25 then
        bat_icon = "󰁼"
        bat_color = Zenith.hex(theme.yellow or "#f9e2af")
    elseif bat_pct > 15 then
        bat_icon = "󰁼"
        bat_color = Zenith.hex(theme.peach or "#fab387")
    else
        bat_icon = "󰂃"
        bat_color = Zenith.hex(theme.error or "#f38ba8")
    end

    -- Caffeine visual highlight (peach/primary)
    if caffeine_active and not is_charging then
        bat_color = Zenith.hex(theme.peach or theme.primary or "#fab387")
    end

    if caffeine_active and p.replace_icon then
        bat_icon = "\u{f0f4}"
    end

    local badge_text: string? = nil
    local badge_color: any = nil

    if caffeine_active then
        badge_text = "\u{f0f4}"
        badge_color = Zenith.hex(theme.peach or theme.primary or "#fab387")
    elseif current_prof == "power-saver" then
        badge_text = "\u{f06c}"
        badge_color = Zenith.hex(theme.teal or theme.green or "#94e2d5")
    elseif current_prof == "performance" then
        badge_text = "\u{f0e7}"
        badge_color = Zenith.hex(theme.primary)
    end

    local label_str = if has_bat then string.format("%d%%", bat_pct) else "AC"

    local time_info = ""
    if battery and battery.time_remaining and #battery.time_remaining > 0 then
        time_info = " · " .. battery.time_remaining
    end

    local tooltip = if has_bat then
        string.format("Bateria: %d%%%s%s · Perfil: %s\n• Clique: Detalhes & Popup\n• Botão Direito: Alternar Perfil (%s)\n• Clique do Meio: Alternar Caffeine%s\n• Scroll: Ajustar Brilho da Tela (±5%%)",
            bat_pct,
            if is_charging then " (Carregando)" else "",
            time_info,
            current_prof,
            next_prof,
            if caffeine_active then " [Ativo]" else "")
    else
        string.format("Alimentação AC · Perfil: %s\n• Clique: Detalhes & Popup\n• Botão Direito: Alternar Perfil (%s)\n• Clique do Meio: Alternar Caffeine%s\n• Scroll: Ajustar Brilho da Tela (±5%%)",
            current_prof,
            next_prof,
            if caffeine_active then " [Ativo]" else "")

    local on_middle = p.on_middle_click or p.caffeine_action or "storage:toggle:batteryCaffeineActive"
    local on_right = p.on_right_click or ("power:profile:" .. next_prof)
    local on_click = p.on_click or "popup:toggle:BatteryPopup"
    local on_scroll_up = p.on_scroll_up or "cmd:brightnessctl set 5%+ &"
    local on_scroll_down = p.on_scroll_down or "cmd:brightnessctl set 5%- &"

    return Pill({
        icon = p.icon or bat_icon,
        icon_size = 12,
        icon_color = p.icon_color or bat_color,
        label = p.label or label_str,
        label_size = 11,
        badge = badge_text,
        badge_color = badge_color,
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        gap = 4,
        tooltip = tooltip,
        on_click = on_click,
        on_right_click = on_right,
        on_middle_click = on_middle,
        on_scroll_up = on_scroll_up,
        on_scroll_down = on_scroll_down,
    })
end

return BatteryWidget
