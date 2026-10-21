--!strict
local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")
local Card = Zenith.import("core/ui/card")
local Switch = Zenith.import("core/ui/switch")
local Button = Zenith.import("core/ui/button")
local Services = Zenith.import("core/services/init")

return function()
    local net = Services.Network.status()
    local is_conn = net.connected or net.is_connected or false
    local scan_list = Services.Network.scan()
    local t = Theme.get()

    local wifi_items = {}
    for _, ap in ipairs(scan_list) do
        table.insert(wifi_items, Button({
            label = string.format("%s (%d%%)", ap.ssid, ap.strength or ap.signal or 0),
            icon = Icons.glyphs.wifi,
            variant = if ap.in_use then "primary" else "tonal",
            width = "100%",
            on_click = "wifi:connect:" .. ap.ssid,
        }))
    end

    return Card({
        variant = "glass",
        width = 320,
        gap = 12,
        padding = 16,
        children = {
            Switch({
                label = "Wi-Fi",
                subtitle = if is_conn then (net.ssid or "Conectado") else "Desconectado",
                icon = Icons.glyphs.wifi,
                checked = is_conn,
                on_toggle = "wifi:toggle",
            }),
            Zenith.Box({
                width = "100%",
                flex_direction = "column",
                gap = 4,
                children = {
                    Zenith.Text({
                        text = string.format("IP: %s", net.ip or "Nenhum"),
                        font_family = "JetBrainsMono Nerd Font",
                        font_size = 11,
                        color = Theme.alpha(t.on_surface or "#ffffff", 160),
                    }),
                },
            }),
            Zenith.Text({
                text = "Redes Disponíveis",
                font_family = "JetBrainsMono Nerd Font",
                font_size = 12,
                font_weight = "medium",
                color = Theme.alpha(t.on_surface or "#ffffff", 180),
            }),
            Zenith.Box({
                width = "100%",
                flex_direction = "column",
                gap = 6,
                children = wifi_items,
            }),
        },
    })
end
