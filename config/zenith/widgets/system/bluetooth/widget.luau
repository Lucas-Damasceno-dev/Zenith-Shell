--!strict
local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")
local PopupManager = Zenith.import("core/popup_manager")
local Services = Zenith.import("core/services/init")

return function(props: any?)
    local bt = Services.Bluetooth.status()
    local t = Theme.get()
    local devs = bt.devices or {}
    local has_conn = bt.connected or (#devs > 0 and devs[1].connected)

    local icon = if not bt.powered then Icons.glyphs.bluetooth_off
        elseif has_conn then Icons.glyphs.bluetooth_conn
        else Icons.glyphs.bluetooth

    return Zenith.Box({
        flex_direction = "row",
        align_items = "center",
        gap = 6,
        padding = { horizontal = 8, vertical = 4 },
        background = Theme.alpha(t.surface_container or t.surface, 150),
        border_radius = 12,
        on_click = PopupManager.toggle_action("bluetooth"),
        on_right_click = "bluetooth:toggle",
        tooltip = string.format("Bluetooth: %s", bt.powered and (has_conn and "Conectado" or "Ativo") or "Desligado"),
        children = {
            Zenith.Text({
                text = icon,
                font_family = "JetBrainsMono Nerd Font",
                font_size = 14,
                color = if bt.powered then (t.on_surface or "#ffffff") else (t.outline or "#888888"),
            }),
        },
    })
end
