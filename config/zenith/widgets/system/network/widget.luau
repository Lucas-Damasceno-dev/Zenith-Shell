--!strict
local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")
local PopupManager = Zenith.import("core/popup_manager")
local Services = Zenith.import("core/services/init")

return function(props: any?)
    local net = Services.Network.status()
    local is_conn = net.connected or net.is_connected or false
    local str = net.strength or net.signal or 0
    local t = Theme.get()

    local icon = if net.ethernet then Icons.glyphs.ethernet else Icons.wifi(str, is_conn)
    local label = if is_conn then (net.ssid or "Conectado") else "Desconectado"

    return Zenith.Box({
        flex_direction = "row",
        align_items = "center",
        gap = 6,
        padding = { horizontal = 8, vertical = 4 },
        background = Theme.alpha(t.surface_container or t.surface, 150),
        border_radius = 12,
        on_click = PopupManager.toggle_action("network"),
        on_right_click = "wifi:toggle",
        tooltip = string.format("Rede: %s (%d%% sinal)", label, str),
        children = {
            Zenith.Text({
                text = icon,
                font_family = "JetBrainsMono Nerd Font",
                font_size = 14,
                color = if is_conn then (t.on_surface or "#ffffff") else (t.outline or "#888888"),
            }),
            Zenith.Text({
                text = label,
                font_family = "JetBrainsMono Nerd Font",
                font_size = 12,
                color = t.on_surface or "#ffffff",
                font_weight = "medium",
            }),
        },
    })
end
