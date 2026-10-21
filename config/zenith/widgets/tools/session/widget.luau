--!strict
-- Zenith-Shell: Session / Power Menu Button Widget

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function SessionWidget()
    local theme = Theme.get()

    return Pill({
        icon = "",
        icon_size = 12,
        icon_color = Zenith.hex(theme.error or "#f38ba8"),
        background = Zenith.hex(theme.error or "#f38ba8", 35),
        border_color = Zenith.hex(theme.error or "#f38ba8", 90),
        height = 26,
        border_radius = 13,
        padding = { horizontal = 9, vertical = 2 },
        tooltip = "Menu de Sessão\n• Clique: Abrir Menu de Energia\n• Botão Direito: Bloquear Tela (LockScreen)\n• Scroll: Suspender Sistema",
        on_click = PopupManager.toggle_action("PowerMenu"),
        on_right_click = "lock",
        on_scroll_down = "system:suspend",
    })
end

return SessionWidget
