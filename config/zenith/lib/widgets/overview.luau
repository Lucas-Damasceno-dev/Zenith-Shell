--!strict
-- Zenith UI Kit - Overview / Mission Control Button (Quickshell Parity)
-- Matches BarOverviewButton.qml (Workspace grid overview & Exposé)

local Pill = Zenith.import("widgets/pill")

local function Overview()
    local theme = Zenith.Theme()

    return Pill({
        icon = "󰀉", -- \u{f009} 4-square grid / Mission Control
        icon_size = 13,
        icon_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        tooltip = "Visão Geral (Overview)\n• Clique: Workspaces (Mission Control)\n• Botão Direito: Exposé / Janelas\n• Scroll: Alternar Workspaces",
        on_click = "dispatch:togglespecialworkspace:overview",
        on_right_click = "cmd:hyprctl dispatch hyprexpo:expo toggle &",
        on_scroll_up = "dispatch:workspace:m+1",
        on_scroll_down = "dispatch:workspace:m-1",
    })
end

return Overview
