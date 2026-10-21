--!strict
-- Zenith-Shell: Keyboard Layout Indicator Widget

local Theme = Zenith.import("core/theme")
local Pill = Zenith.import("widgets/shared/pill/init")

local function KeyboardLayoutWidget()
    local theme = Theme.get()

    return Pill({
        icon = "󰌌",
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        label = "BR",
        label_size = 11,
        height = 26,
        border_radius = 13,
        padding = { horizontal = 8, vertical = 2 },
        gap = 4,
        tooltip = "Layout do Teclado: Português (Brasil / ABNT2)\n• Clique: Próximo Layout\n• Botão Direito: Layout Anterior",
        on_click = "cmd:hyprctl switchxkblayout all next &",
        on_right_click = "cmd:hyprctl switchxkblayout all prev &",
    })
end

return KeyboardLayoutWidget
