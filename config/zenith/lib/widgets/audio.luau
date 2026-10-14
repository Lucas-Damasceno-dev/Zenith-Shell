--!strict
-- Zenith UI Kit - Audio Status Component (Quickshell Parity)
-- Matches BarAudioStatus.qml (Volume indicator, scroll control, mute toggle, popup)

local Pill = Zenith.import("widgets/pill")

local function AudioWidget()
    local theme = Zenith.Theme()
    local audio = Zenith.Services.audio()

    local is_muted = audio.is_muted or false
    local vol = audio.volume or 0

    local audio_icon = if is_muted then "󰝟"
        elseif vol > 60 then "󰕾"
        elseif vol > 25 then "󰖀"
        elseif vol > 0 then "󰕿"
        else "󰝟"

    local icon_color = if is_muted then Zenith.hex(theme.error or "#f38ba8")
        else Zenith.hex(theme.primary)

    local vol_label = string.format("%d%%", vol)
    local tooltip = string.format("Volume: %d%%%s\n• Clique: Mixer de Áudio\n• Botão Direito: Mutar / Desmutar\n• Scroll: Ajustar Volume (±5%%)",
        vol, if is_muted then " (Mutado)" else "")

    return Pill({
        icon = audio_icon,
        icon_size = 12,
        icon_color = icon_color,
        label = vol_label,
        label_size = 11,
        label_color = if is_muted then Zenith.hex(theme.error or "#f38ba8") else Zenith.hex(theme.on_surface),
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        gap = 4,
        tooltip = tooltip,
        on_click = "popup:toggle:AudioPopup",
        on_right_click = "audio:toggle_mute",
        on_scroll_up = "audio:volume_step:5",
        on_scroll_down = "audio:volume_step:-5",
    })
end

return AudioWidget
