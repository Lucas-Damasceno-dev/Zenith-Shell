--!strict
-- Zenith-Shell: Settings Hub Component

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function SettingsHub()
    local theme = Theme.get()

    return Pill({
        icon = "󰒓",
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { horizontal = 8, vertical = 2 },
        tooltip = "Menu de Configurações (Zenith Shell)\n• Clique: Central de Configurações\n• Botão Direito: Página Inicial",
        on_click = PopupManager.toggle_action("Settings"),
        on_right_click = "settings:page:0",
    })
end

return SettingsHub
