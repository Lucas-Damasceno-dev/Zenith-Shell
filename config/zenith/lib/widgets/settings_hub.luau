--!strict
-- Zenith UI Kit - Settings Hub Component
-- Opens the replicated Zenith Settings Menu (.luau)

local Pill = Zenith.import("widgets/pill")

local function SettingsHub()
    local theme = Zenith.Theme()

    return Pill({
        icon = "󰒓", -- M3 / Nerd Font settings gear
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        tooltip = "Menu de Configurações (Zenith Shell)\n• Clique: Central de Configurações\n• Botão Direito: Página Inicial",
        on_click = "popup:toggle:Settings",
        on_right_click = "settings:page:0",
    })
end

return SettingsHub
