--!strict
-- Zenith UI Kit - USB Status Component (Quickshell Parity)
-- Matches BarUSBStatus.qml (USB storage & peripheral devices pill)

local Pill = Zenith.import("widgets/pill")

local function USBStatusWidget()
    local theme = Zenith.Theme()

    return Pill({
        icon = "󰕓", -- USB storage icon
        icon_size = 12,
        icon_color = Zenith.hex(theme.on_surface_variant or theme.outline, 180),
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        tooltip = "Dispositivos USB\n• Clique: Gerenciar discos e mídias removíveis\n• Botão Direito: Desmontar com Segurança",
        on_click = "cmd:udiskie-mount &",
        on_right_click = "cmd:udiskie-umount -a &",
    })
end

return USBStatusWidget
