--!strict
-- Zenith-Shell: Keyboard Layout Indicator Widget

local Theme = Zenith.import("core/theme")
local Pill = Zenith.import("widgets/shared/pill/init")

local function KeyboardLayoutWidget()
    local theme = Theme.get()

    local layout_label = "BR"
    if Zenith.Signals and Zenith.Signals.Keyboard then
        layout_label = Zenith.Signals.Keyboard
    elseif Zenith.Services and Zenith.Services.Hyprland and Zenith.Services.Hyprland.active_layout then
        local raw = Zenith.Services.Hyprland.active_layout()
        if raw and #raw > 0 then
            layout_label = raw:sub(1, 2):upper()
        end
    end

    return Pill({
        icon = "󰌌",
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        label = layout_label,
        label_size = 11,
        height = 26,
        border_radius = 13,
        padding = { horizontal = 8, vertical = 2 },
        gap = 4,
        tooltip = "Layout do Teclado\n• Clique: Próximo Layout\n• Botão Direito: Layout Anterior",
        on_click = "dispatch:switchxkblayout:all next",
        on_right_click = "dispatch:switchxkblayout:all prev",
    })
end

return KeyboardLayoutWidget
