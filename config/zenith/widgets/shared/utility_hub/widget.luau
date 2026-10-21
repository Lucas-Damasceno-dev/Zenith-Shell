--!strict
-- Zenith-Shell: Utility Hub Quick Actions Widget

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function UtilityHub()
    local theme = Theme.get()

    return Pill({
        icon = "󰈈",
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { horizontal = 8, vertical = 2 },
        tooltip = "Central de Utilitários\n• Atalhos rápidos do sistema e ferramentas\n• Clique: Abrir Central",
        on_click = PopupManager.toggle_action("Settings"),
        on_right_click = "screenshot:area",
    })
end

return UtilityHub
