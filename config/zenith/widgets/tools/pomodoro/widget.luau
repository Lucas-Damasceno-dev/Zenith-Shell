--!strict
-- Zenith-Shell: Pomodoro Status Widget

local Pill = Zenith.import("widgets/shared/pill/init")
local Store = Zenith.import("core/store")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function Pomodoro()
    local theme = Theme.get()
    local active = Store.get("pomodoroActive") or false
    local focus_min = Store.get("pomodoroFocus") or 25
    local label_str = tostring(focus_min) .. "m"

    return Pill({
        icon = "󰅐",
        icon_size = 12,
        icon_color = if active then Zenith.hex(theme.primary) else Zenith.hex(theme.tertiary or theme.primary),
        label = label_str,
        label_size = 11,
        height = 26,
        border_radius = 13,
        padding = { horizontal = 8, vertical = 2 },
        gap = 4,
        tooltip = "Pomodoro: Foco Produtivo\n• Clique: Alternar Timer\n• Botão Direito: Detalhes do Pomodoro",
        on_click = "storage:toggle:pomodoroActive",
        on_right_click = PopupManager.toggle_action("PomodoroPopup"),
    })
end

return Pomodoro
