--!strict
-- Zenith UI Kit - Utility Hub Status Component (Quickshell Parity)
-- Matches UtilityHubStatus.qml (Tools & utility actions pill)

local Pill = Zenith.import("widgets/pill")

local function UtilityHub()
    local theme = Zenith.Theme()

    return Pill({
        icon = "󰈈",
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        tooltip = "Central de Utilitários\n• Atalhos rápidos do sistema e ferramentas\n• Clique: Abrir Central",
        on_click = "popup:toggle:Settings",
        on_right_click = "screenshot:area",
    })
end

return UtilityHub
