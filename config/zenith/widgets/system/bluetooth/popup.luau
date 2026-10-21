--!strict
local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")
local Card = Zenith.import("core/ui/card")
local Switch = Zenith.import("core/ui/switch")
local Button = Zenith.import("core/ui/button")
local Services = Zenith.import("core/services/init")

local function BluetoothPopup()
    local bt = Services.Bluetooth.status()
    local t = Theme.get()
    local devs = bt.devices or {}

    local dev_items = {}
    for _, d in ipairs(devs) do
        table.insert(dev_items, Button({
            label = string.format("%s%s", d.name or d.mac, d.connected and " (Conectado)" or ""),
            icon = Icons.glyphs.bluetooth,
            variant = if d.connected then "primary" else "tonal",
            width = "100%",
            on_click = if d.connected then ("bluetooth:disconnect:" .. d.mac) else ("bluetooth:connect:" .. d.mac),
        }))
    end

    return Card({
        variant = "glass",
        width = 300,
        gap = 12,
        padding = 16,
        children = {
            Switch({
                label = "Bluetooth",
                subtitle = if bt.powered then "Adaptador ligado" else "Desligado",
                icon = Icons.glyphs.bluetooth,
                checked = bt.powered,
                on_toggle = "bluetooth:toggle",
            }),
            Zenith.Text({
                text = "Dispositivos Conhecidos",
                font_family = "JetBrainsMono Nerd Font",
                font_size = 12,
                font_weight = "medium",
                color = Theme.alpha(t.on_surface or "#ffffff", 180),
            }),
            Zenith.Box({
                width = "100%",
                flex_direction = "column",
                gap = 6,
                children = dev_items,
            }),
        },
    })
end

return BluetoothPopup
