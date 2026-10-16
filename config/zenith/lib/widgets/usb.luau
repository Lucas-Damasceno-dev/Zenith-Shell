--!strict
-- Zenith UI Kit - USB Status Component (Quickshell Parity)
-- Matches BarUSBStatus.qml (USB storage & peripheral devices pill)

local Pill = Zenith.import("widgets/pill")

local function USBStatusWidget(props: { reactive: boolean? }?)
    local theme = Zenith.Theme()

    local mounted_count = 0
    local total_count = 0
    local has_devices_data = false

    if Zenith.Storage and Zenith.Storage.get then
        local raw_devs = Zenith.Storage.get("usb_devices", nil)
        local raw_mounted = Zenith.Storage.get("usb_mounted_count", nil) or Zenith.Storage.get("usb_mounted", nil)
        local raw_total = Zenith.Storage.get("usb_device_count", nil) or Zenith.Storage.get("usb_devices_count", nil)

        if type(raw_devs) == "table" then
            has_devices_data = true
            total_count = #raw_devs
            mounted_count = 0
            for _, dev in ipairs(raw_devs) do
                if type(dev) == "table" and (dev.mounted == true or dev.mountpoint ~= nil and dev.mountpoint ~= "") then
                    mounted_count = mounted_count + 1
                end
            end
        elseif type(raw_mounted) == "number" then
            has_devices_data = true
            mounted_count = raw_mounted
            total_count = if type(raw_total) == "number" then raw_total else raw_mounted
        end
    end

    local status_line: string
    if mounted_count > 0 then
        if total_count > mounted_count then
            status_line = string.format("• %d unidade(s) montada(s) de %d conectada(s)", mounted_count, total_count)
        else
            status_line = string.format("• %d unidade(s) montada(s)", mounted_count)
        end
    elseif has_devices_data and total_count > 0 then
        status_line = string.format("• 0 unidades montadas (%d dispositivo(s) desconectado(s)/não montado(s))", total_count)
    else
        status_line = "• 0 unidades montadas"
    end

    local tooltip = string.format(
        "Dispositivos USB\n%s\n• Clique: Gerenciar discos e mídias removíveis\n• Botão Direito: Desmontar com Segurança",
        status_line
    )

    local icon_color = if mounted_count > 0
        then Zenith.hex(theme.primary)
        else Zenith.hex(theme.on_surface_variant or theme.outline, 180)

    local badge_str: string? = if mounted_count > 0 then tostring(mounted_count) else nil

    return Pill({
        icon = "󰕓", -- USB storage icon
        icon_size = 12,
        icon_color = icon_color,
        badge = badge_str,
        badge_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        tooltip = tooltip,
        on_click = "popup:toggle:USBPopup",
        on_right_click = "cmd:udiskie-umount -a &",
    })
end

return USBStatusWidget
