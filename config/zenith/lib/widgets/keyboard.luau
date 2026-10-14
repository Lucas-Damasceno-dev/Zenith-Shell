--!strict
-- Zenith UI Kit - Keyboard Layout Component (Quickshell Parity)
-- Matches BarKeyboardLayout.qml (Shows current active keyboard layout e.g. BR/US)

local Pill = Zenith.import("widgets/pill")

local function KeyboardLayoutWidget()
    local theme = Zenith.Theme()

    return Pill({
        icon = "󰌌",
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        label = "BR",
        label_size = 11,
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        gap = 4,
        tooltip = "Layout do Teclado: Português (Brasil / ABNT2)\n• Clique: Próximo Layout\n• Botão Direito: Layout Anterior",
        on_click = "cmd:hyprctl switchxkblayout all next &",
        on_right_click = "cmd:hyprctl switchxkblayout all prev &",
    })
end

return KeyboardLayoutWidget
