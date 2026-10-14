--!strict
-- Zenith UI Kit - Session / Power Menu Button (Quickshell Parity)
-- Matches sessionTile in RightBarModules.qml

local Pill = Zenith.import("widgets/pill")

local function SessionWidget()
    local theme = Zenith.Theme()

    return Pill({
        icon = "", -- Power icon (\u{f011})
        icon_size = 12,
        icon_color = Zenith.hex(theme.error or "#f38ba8"),
        background = Zenith.hex(theme.error or "#f38ba8", 35),
        border_color = Zenith.hex(theme.error or "#f38ba8", 90),
        height = 26,
        border_radius = 13,
        padding = { x = 9, y = 2 },
        tooltip = "Menu de Sessão\n• Clique: Abrir Menu de Energia\n• Botão Direito: Bloquear Tela (LockScreen)\n• Scroll: Suspender Sistema",
        on_click = "popup:toggle:PowerMenu",
        on_right_click = "lock",
        on_scroll_down = "system:suspend",
    })
end

return SessionWidget
