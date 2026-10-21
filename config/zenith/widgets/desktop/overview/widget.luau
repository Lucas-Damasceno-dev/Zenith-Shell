--!strict
-- Zenith-Shell: Overview / Mission Control Widget Button

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function Overview()
    local theme = Theme.get()

    return Pill({
        icon = "󰀉",
        icon_size = 13,
        icon_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { horizontal = 8, vertical = 2 },
        tooltip = "Visão Geral (Overview)\n• Clique: Alternar Exposé / Janelas\n• Botão Direito: Workspaces Especiais\n• Scroll: Alternar Workspaces",
        on_click = PopupManager.toggle_action("ExposePopup"),
        on_right_click = "dispatch:togglespecialworkspace:overview",
        on_scroll_up = "dispatch:workspace:m+1",
        on_scroll_down = "dispatch:workspace:m-1",
    })
end

return Overview
