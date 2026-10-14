--!strict
-- Zenith UI Kit - Clipboard Status Component (Quickshell Parity)
-- Matches BarClipboardStatus.qml (Clipboard history launcher pill)

local Pill = Zenith.import("widgets/pill")

local function ClipboardWidget()
    local theme = Zenith.Theme()

    return Pill({
        icon = "󰅍", -- Clipboard icon
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        tooltip = "Área de Transferência (Clipboard)\n• Clique ou Super+V: Histórico de Cópias\n• Botão Direito: Limpar Histórico",
        on_click = "cmd:cliphist list | rofi -dmenu | cliphist decode | wl-copy &",
        on_right_click = "cmd:cliphist wipe &",
    })
end

return ClipboardWidget
