--!strict
-- Zenith UI Kit - System Tweaks & Settings Button (Quickshell Parity)
-- Matches tweaksTile in RightBarModules.qml

local Pill = Zenith.import("widgets/pill")

local function TweaksWidget()
    local theme = Zenith.Theme()

    return Pill({
        icon = "󰏞", -- Sliders / tweaks icon (\u{f1de})
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        tooltip = "Ajustes do Sistema (Tweaks)\n• Clique: Central de Configurações\n• Botão Direito: Página de Ajustes e Tweaks",
        on_click = "popup:toggle:Settings",
        on_right_click = "settings:page:14",
    })
end

return TweaksWidget
