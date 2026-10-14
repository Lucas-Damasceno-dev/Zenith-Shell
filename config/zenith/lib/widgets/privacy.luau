--!strict
-- Zenith UI Kit - Privacy Indicator Component (Quickshell Parity)
-- Matches BarPrivacyIndicator.qml (Mic, Camera & Screen Recording state)

local Pill = Zenith.import("widgets/pill")

local function PrivacyIndicator()
    local theme = Zenith.Theme()
    local is_recording = Zenith.Services.IsRecording and Zenith.Services.IsRecording() or false

    if is_recording then
        return Pill({
            variant = "danger",
            label = "● REC",
            label_size = 11,
            label_color = Zenith.hex("#ffffff"),
            height = 26,
            border_radius = 13,
            padding = { x = 9, y = 2 },
            tooltip = "Gravação de Tela Ativa\n• Clique: Interromper gravação",
            on_click = "record:toggle",
        })
    end

    -- Idle snip / privacy shortcut
    return Pill({
        icon = "󰄀", -- Camera / snip icon
        icon_size = 12,
        icon_color = Zenith.hex(theme.on_surface_variant or theme.outline, 180),
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        tooltip = "Captura de Tela (Região)\n• Clique: Selecionar área da tela\n• Botão Direito: Captura de tela inteira",
        on_click = "screenshot:area",
        on_right_click = "screenshot:full",
    })
end

return PrivacyIndicator
