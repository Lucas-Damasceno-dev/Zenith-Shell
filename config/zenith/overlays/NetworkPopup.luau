--!strict
-- Zenith-Shell (Engine v2) - Network & Wi-Fi Management Overlay

local theme = Zenith.Theme()
local net = Zenith.Services.Network()
local wifis = Zenith.Services.WifiScan()

local wifi_items = {}
for _, ap in ipairs(wifis) do
    local sig_icon = if ap.signal >= 75 then "󰤨"
        elseif ap.signal >= 50 then "󰤥"
        elseif ap.signal >= 25 then "󰤢"
        else "󰤟"

    table.insert(wifi_items, Zenith.Box({
        direction = "row",
        padding = { x = 12, y = 8 },
        border_radius = 8,
        background = ap.in_use and Zenith.rgba(124, 77, 255, 40) or Zenith.hex(theme.surface_container),
        border_color = ap.in_use and Zenith.hex(theme.primary) or Zenith.rgba(255, 255, 255, 12),
        border_width = 1,
        on_click = "wifi:connect:" .. ap.ssid,
        children = {
            Zenith.Text({
                text = sig_icon,
                font_size = 14,
                color = ap.in_use and Zenith.hex(theme.primary) or Zenith.hex(theme.on_surface),
            }),
            Zenith.Box({ width = 10 }),
            Zenith.Box({
                direction = "column",
                gap = 2,
                flex_grow = 1,
                children = {
                    Zenith.Text({
                        text = ap.ssid,
                        font_size = 12,
                        color = Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Text({
                        text = ap.security .. (ap.in_use and " • Connected" or ""),
                        font_size = 10,
                        color = ap.in_use and Zenith.hex(theme.primary) or Zenith.hex(theme.outline),
                    }),
                }
            }),
            Zenith.Text({
                text = string.format("%d%%", ap.signal),
                font_size = 10,
                color = Zenith.hex(theme.outline),
            }),
        }
    }))
end

return Zenith.Window({
    direction = "column",
    width = 360,
    height = 460,
    padding = { x = 16, y = 14 },
    gap = 12,
    background = Zenith.rgba(18, 20, 26, 230),
    border_color = Zenith.hex(theme.primary),
    border_width = 1,
    border_radius = 16,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 22,
        offset_x = 0,
        offset_y = 8,
    },
    children = {
        -- Header: Title + Close
        Zenith.Box({
            direction = "row",
            children = {
                Zenith.Text({
                    text = "󰤨 Network & Wi-Fi",
                    font_size = 13,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 6, y = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "ESC", font_size = 9, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            }
        }),

        -- Current Connection Card
        Zenith.Box({
            direction = "column",
            gap = 4,
            padding = { x = 12, y = 10 },
            border_radius = 10,
            background = Zenith.hex(theme.surface_container),
            border_color = Zenith.rgba(255, 255, 255, 16),
            border_width = 1,
            children = {
                Zenith.Box({
                    direction = "row",
                    children = {
                        Zenith.Text({
                            text = net.connected and "󰈀 Connected" or "󰌙 Disconnected",
                            font_size = 12,
                            color = net.connected and Zenith.hex("#98c379") or Zenith.hex("#e06c75"),
                        }),
                        Zenith.Box({ flex_grow = 1 }),
                        Zenith.Text({
                            text = net.type:upper(),
                            font_size = 10,
                            color = Zenith.hex(theme.outline),
                        }),
                    }
                }),
                Zenith.Text({
                    text = "SSID: " .. (net.ssid or "Ethernet"),
                    font_size = 12,
                    color = Zenith.hex(theme.on_surface),
                }),
                Zenith.Text({
                    text = "IP: " .. (net.ip or "Unknown"),
                    font_size = 10,
                    color = Zenith.hex(theme.outline),
                }),
            }
        }),

        -- Wi-Fi Scan Section Header
        Zenith.Text({
            text = "AVAILABLE NETWORKS",
            font_size = 10,
            color = Zenith.hex(theme.outline),
        }),

        -- Wi-Fi Access Points List
        Zenith.Box({
            direction = "column",
            gap = 6,
            flex_grow = 1,
            children = wifi_items,
        }),
    }
})
