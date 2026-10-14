--!strict
-- Zenith UI Kit - KDE Connect Component (Quickshell Parity)
-- Matches BarKdeConnect.qml (Mobile devices integration pill)

local Pill = Zenith.import("widgets/pill")

local function KdeConnectWidget()
    local theme = Zenith.Theme()

    return Pill({
        icon = "󰄡", -- Smartphone / KDE Connect icon
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        tooltip = "KDE Connect (Mobile)\n• Clique: Abrir Gerenciador de Dispositivos\n• Botão Direito: Atualizar Dispositivos",
        on_click = "cmd:kdeconnect-app &",
        on_right_click = "cmd:kdeconnect-cli --refresh &",
    })
end

return KdeConnectWidget
