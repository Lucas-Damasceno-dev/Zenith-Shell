--!strict
-- Zenith UI Kit - Audio Status Component (Quickshell Parity)
-- Matches BarAudioStatus.qml (Volume indicator, scroll control, mute toggle, popup)

local Pill = Zenith.import("widgets/pill")

export type AudioWidgetProps = {
    on_click: string?,
    on_right_click: string?,
    on_middle_click: string?,
    on_scroll_up: string?,
    on_scroll_down: string?,
    [string]: any,
}

local function AudioWidget(props: AudioWidgetProps?)
    local p = props or {}
    local theme = Zenith.Theme()
    local audio = Zenith.Services.audio()

    local is_muted = false
    local vol = 0
    if audio then
        is_muted = audio.is_muted or false
        vol = audio.volume or 0
    end

    local audio_icon = if is_muted then "󰝟"
        elseif vol > 60 then "󰕾"
        elseif vol > 25 then "󰖀"
        elseif vol > 0 then "󰕿"
        else "󰝟"

    local icon_color = if is_muted then Zenith.hex(theme.error or "#f38ba8")
        else Zenith.hex(theme.primary)

    local vol_label = if is_muted then "Mudo" else string.format("%d%%", vol)
    local tooltip = string.format("Volume: %d%%%s\n• Clique: Mixer de Áudio\n• Clique-Meio / Clique-Dir: Mutar / Desmutar\n• Scroll: Ajustar Volume (±2%%)",
        vol, if is_muted then " (Mutado)" else "")

    local on_click = p.on_click or "popup:toggle:AudioPopup"
    local on_middle_click = p.on_middle_click or "cmd:wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    local on_right_click = p.on_right_click or "cmd:wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    local on_scroll_up = p.on_scroll_up or "cmd:wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+"
    local on_scroll_down = p.on_scroll_down or "cmd:wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"

    return Pill({
        icon = p.icon or audio_icon,
        icon_size = 12,
        icon_color = p.icon_color or icon_color,
        label = p.label or vol_label,
        label_size = 11,
        label_color = if is_muted then Zenith.hex(theme.error or "#f38ba8") else Zenith.hex(theme.on_surface),
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        gap = 4,
        tooltip = tooltip,
        on_click = on_click,
        on_right_click = on_right_click,
        on_middle_click = on_middle_click,
        on_scroll_up = on_scroll_up,
        on_scroll_down = on_scroll_down,
    })
end

return AudioWidget
