--!strict
-- Zenith-Shell: KDE Connect Mobile Integration Widget

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")

local function KdeConnectWidget()
    local theme = Theme.get()

    return Pill({
        icon = "󰄡",
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { horizontal = 8, vertical = 2 },
        tooltip = "KDE Connect (Mobile)\n• Clique: Abrir Gerenciador de Dispositivos\n• Botão Direito: Atualizar Dispositivos",
        on_click = "cmd:kdeconnect-app &",
        on_right_click = "cmd:kdeconnect-cli --refresh &",
    })
end

return KdeConnectWidget
