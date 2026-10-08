--!strict
-- Zenith-Shell (Engine v2) - Bluetooth Management Overlay

local theme = Zenith.Theme()
local bt = Zenith.Services.Bluetooth()

local device_items = {}
for _, dev in ipairs(bt.devices) do
    local icon = if dev.name:lower():find("headphone") or dev.name:lower():find("wh-") or dev.name:lower():find("buds") then "󰋋"
        elseif dev.name:lower():find("keyboard") or dev.name:lower():find("keychron") then "󰌌"
        elseif dev.name:lower():find("mouse") or dev.name:lower():find("master") then "󰍽"
        else "󰂯"

    local is_conn = dev.connected
    local action = if is_conn then "bluetooth:disconnect:" .. dev.mac else "bluetooth:connect:" .. dev.mac

    table.insert(device_items, Zenith.Box({
        direction = "row",
        padding = { x = 12, y = 8 },
        border_radius = 8,
        background = is_conn and Zenith.rgba(124, 77, 255, 35) or Zenith.hex(theme.surface_container),
        border_color = is_conn and Zenith.hex(theme.primary) or Zenith.rgba(255, 255, 255, 12),
        border_width = 1,
        on_click = action,
        children = {
            Zenith.Text({
                text = icon,
                font_size = 14,
                color = is_conn and Zenith.hex(theme.primary) or Zenith.hex(theme.on_surface),
            }),
            Zenith.Box({ width = 10 }),
            Zenith.Box({
                direction = "column",
                gap = 2,
                flex_grow = 1,
                children = {
                    Zenith.Text({
                        text = dev.name,
                        font_size = 12,
                        color = Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Text({
                        text = is_conn and (dev.battery > 0 and string.format("Connected • 󰁹 %d%%", dev.battery) or "Connected") or "Disconnected",
                        font_size = 10,
                        color = is_conn and Zenith.hex(theme.primary) or Zenith.hex(theme.outline),
                    }),
                }
            }),
            Zenith.Box({
                padding = { x = 6, y = 2 },
                border_radius = 4,
                background = is_conn and Zenith.rgba(224, 108, 117, 30) or Zenith.rgba(255, 255, 255, 12),
                children = {
                    Zenith.Text({
                        text = is_conn and "Disconnect" or "Connect",
                        font_size = 9,
                        color = is_conn and Zenith.hex("#e06c75") or Zenith.hex(theme.on_surface),
                    })
                }
            })
        }
    }))
end

return Zenith.Window({
    direction = "column",
    width = 360,
    height = 420,
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
        -- Header: Title + Power Toggle + Close
        Zenith.Box({
            direction = "row",
            children = {
                Zenith.Text({
                    text = "󰂯 Bluetooth Devices",
                    font_size = 13,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                -- Power toggle
                Zenith.Box({
                    padding = { x = 8, y = 3 },
                    border_radius = 6,
                    background = bt.powered and Zenith.rgba(124, 77, 255, 40) or Zenith.rgba(255, 255, 255, 10),
                    border_color = bt.powered and Zenith.hex(theme.primary) or Zenith.rgba(255, 255, 255, 16),
                    border_width = 1,
                    on_click = "bluetooth:toggle",
                    children = {
                        Zenith.Text({
                            text = bt.powered and "POWER ON" or "POWER OFF",
                            font_size = 9,
                            color = bt.powered and Zenith.hex(theme.primary) or Zenith.hex(theme.outline),
                        })
                    }
                }),
                Zenith.Box({ width = 6 }),
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

        -- Devices list header
        Zenith.Text({
            text = string.format("PAIRED PERIPHERALS (%d)", #bt.devices),
            font_size = 10,
            color = Zenith.hex(theme.outline),
        }),

        -- Devices List
        Zenith.Box({
            direction = "column",
            gap = 6,
            flex_grow = 1,
            children = device_items,
        }),
    }
})
