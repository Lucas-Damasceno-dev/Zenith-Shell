--!strict
-- Zenith-Shell: Privacy & Screen Capture Indicator Widget

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")

local function PrivacyIndicator()
    local theme = Theme.get()
    local is_recording = if Zenith.Services and Zenith.Services.IsRecording then Zenith.Services.IsRecording() else false

    if is_recording then
        return Pill({
            variant = "danger",
            label = "● REC",
            label_size = 11,
            label_color = Zenith.hex("#ffffff"),
            height = 26,
            border_radius = 13,
            padding = { horizontal = 9, vertical = 2 },
            tooltip = "Gravação de Tela Ativa\n• Clique: Interromper gravação",
            on_click = "record:toggle",
        })
    end

    return Pill({
        icon = "󰄀",
        icon_size = 12,
        icon_color = Zenith.hex(theme.on_surface_variant or theme.outline, 180),
        height = 26,
        border_radius = 13,
        padding = { horizontal = 8, vertical = 2 },
        tooltip = "Captura de Tela (Região)\n• Clique: Selecionar área da tela\n• Botão Direito: Captura de tela inteira",
        on_click = "screenshot:area",
        on_right_click = "screenshot:full",
    })
end

return PrivacyIndicator
