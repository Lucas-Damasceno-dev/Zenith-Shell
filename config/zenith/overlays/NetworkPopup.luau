--!strict
-- Zenith-Shell (Engine v2) - Network & Wi-Fi Control Overlay

local theme = Zenith.Theme()
local net = Zenith.Services.network()

local is_conn = net.is_connected
local net_type = net.type or "disconnected"
local ssid = (#net.ssid > 0) and net.ssid or "Ethernet"
local icon = if not is_conn then "󰤭" elseif net_type == "wifi" then "󰖩" else "󰈀"
local status_label = if is_conn then "Connected to " .. ssid else "No Active Connection"
local status_color = if is_conn then Zenith.hex("#a6e3a1") else Zenith.hex("#e06c75")

return Zenith.Window({
    direction = "column",
    width = 320,
    height = 280,
    padding = { x = 14, y = 12 },
    gap = 10,
    background = Zenith.rgba(18, 20, 26, 220),
    border_color = Zenith.hex(theme.primary),
    border_width = 1,
    border_radius = 12,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 160),
        blur = 16,
        offset_x = 0,
        offset_y = 6,
    },
    children = {
        -- Header with title and close button
        Zenith.Box({
            direction = "row",
            children = {
                Zenith.Text({
                    text = "󰖩 Network & Wi-Fi",
                    font_size = 13,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 8, y = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "✕", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            }
        }),

        -- Status card
        Zenith.Box({
            direction = "column",
            gap = 4,
            padding = { x = 12, y = 10 },
            border_radius = 8,
            background = Zenith.hex(theme.surface),
            border_color = Zenith.hex("#2d3748"),
            border_width = 1,
            children = {
                Zenith.Box({
                    direction = "row",
                    gap = 8,
                    children = {
                        Zenith.Text({ text = icon, font_size = 16, color = status_color }),
                        Zenith.Text({ text = status_label, font_size = 12, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
                Zenith.Text({
                    text = "Interface: " .. net_type .. " (NetworkManager)",
                    font_size = 10,
                    color = Zenith.hex("#7f849c"),
                }),
            }
        }),

        -- Wi-Fi toggle & rescan actions
        Zenith.Box({
            direction = "row",
            gap = 8,
            children = {
                Zenith.Box({
                    flex_grow = 1,
                    padding = { x = 8, y = 8 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "cmd:nmcli device wifi rescan",
                    children = {
                        Zenith.Text({ text = "󰑐 Rescan Wi-Fi", font_size = 11, color = Zenith.hex(theme.on_surface) })
                    }
                }),
                Zenith.Box({
                    flex_grow = 1,
                    padding = { x = 8, y = 8 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "cmd:nmcli radio wifi | grep -q enabled && nmcli radio wifi off || nmcli radio wifi on",
                    children = {
                        Zenith.Text({ text = "󰤨 Toggle Wi-Fi", font_size = 11, color = Zenith.hex(theme.on_surface) })
                    }
                }),
            }
        }),

        -- Open NMTUI Terminal tool
        Zenith.Box({
            padding = { x = 10, y = 8 },
            border_radius = 8,
            background = Zenith.hex(theme.surface),
            border_color = Zenith.hex("#2d3748"),
            border_width = 1,
            on_click = "cmd:kitty -e nmtui &",
            children = {
                Zenith.Text({
                    text = "󰒍 Open Connections Tool (nmtui)",
                    font_size = 11,
                    color = Zenith.hex(theme.on_surface),
                })
            }
        }),
    }
})
