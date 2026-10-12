--!strict
-- Zenith-Shell (Engine v2) - Bluetooth Management Overlay

local theme = Zenith.Theme()
local bt = Zenith.Services.Bluetooth()

local total_devices = #bt.devices
local max_visible = 6
local scroll_offset = _G.__bt_scroll or 0
if scroll_offset > math.max(0, total_devices - max_visible) then
    scroll_offset = math.max(0, total_devices - max_visible)
end
if scroll_offset < 0 then
    scroll_offset = 0
end

local start_idx = scroll_offset + 1
local end_idx = math.min(total_devices, start_idx + max_visible - 1)

local function scroll_up()
    _G.__bt_scroll = math.max(0, (_G.__bt_scroll or 0) - 1)
end

local function scroll_down()
    local max_s = math.max(0, total_devices - max_visible)
    _G.__bt_scroll = math.min(max_s, (_G.__bt_scroll or 0) + 1)
end

local device_items = {}
if total_devices == 0 then
    table.insert(device_items, Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "center",
        padding = { x = 12, y = 14 },
        border_radius = 8,
        background = Zenith.hex(theme.surface_container),
        border_color = Zenith.rgba(255, 255, 255, 12),
        border_width = 1,
        children = {
            Zenith.Text({
                text = "󰂲 No paired devices found",
                font_size = 11,
                color = Zenith.hex(theme.outline),
            }),
        }
    }))
else
    for i = start_idx, end_idx do
        local dev = bt.devices[i]
        if not dev then break end

        local icon = if dev.name:lower():find("headphone") or dev.name:lower():find("wh-") or dev.name:lower():find("buds") then "󰋋"
            elseif dev.name:lower():find("keyboard") or dev.name:lower():find("keychron") then "󰌌"
            elseif dev.name:lower():find("mouse") or dev.name:lower():find("master") then "󰍽"
            else "󰂯"

        local is_conn = dev.connected
        local action = if is_conn then "bluetooth:disconnect:" .. dev.mac else "bluetooth:connect:" .. dev.mac

        table.insert(device_items, Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { x = 12, y = 8 },
            border_radius = 8,
            background = is_conn and Zenith.hex(theme.primary, 35) or Zenith.hex(theme.surface_container),
            border_color = is_conn and Zenith.hex(theme.primary) or Zenith.hex(theme.outline, 30),
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
                    align_items = "stretch",
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
end

local visible_count = if total_devices == 0 then 1 else (end_idx - start_idx + 1)
local win_height = math.min(480, 110 + (visible_count * 52))

local section_header = if total_devices > max_visible
    then string.format("PAIRED PERIPHERALS (%d–%d of %d • scroll)", start_idx, end_idx, total_devices)
    else string.format("PAIRED PERIPHERALS (%d)", total_devices)

return Zenith.Window({
    direction = "column",
    align_items = "stretch",
    width = 360,
    height = win_height,
    padding = { x = 16, y = 14 },
    gap = 12,
    background = Zenith.hex(theme.surface, 235),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
    border_width = 1,
    border_radius = 16,
    on_scroll_up = scroll_up,
    on_scroll_down = scroll_down,
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
            align_items = "center",
            children = {
                Zenith.Text({
                    text = "󰂯 Bluetooth Devices",
                    font_size = 13,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                -- Power toggle switch
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 6,
                    children = {
                        Zenith.Switch({
                            id = "bt_power_switch",
                            checked = bt.powered,
                            active_color = theme.primary,
                            on_toggle = "bluetooth:toggle",
                        }),
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
            text = section_header,
            font_size = 10,
            color = Zenith.hex(theme.outline),
        }),

        -- Devices List
        Zenith.Box({
            direction = "column",
            align_items = "stretch",
            gap = 6,
            flex_grow = 1,
            on_scroll_up = scroll_up,
            on_scroll_down = scroll_down,
            children = device_items,
        }),
    }
})
