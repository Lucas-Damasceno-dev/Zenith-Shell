--!strict
-- Zenith-Shell: System Tweaks & Settings Widget Button

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function TweaksWidget()
    local theme = Theme.get()

    return Pill({
        icon = "󰏞",
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { horizontal = 8, vertical = 2 },
        tooltip = "Ajustes do Sistema (Tweaks)\n• Clique: Central de Configurações\n• Botão Direito: Página de Ajustes e Tweaks",
        on_click = PopupManager.toggle_action("Settings"),
        on_right_click = "settings:page:14",
    })
end

return TweaksWidget
