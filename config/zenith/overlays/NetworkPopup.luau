--!strict
-- Zenith-Shell (Engine v2) - Network & Wi-Fi Management Overlay

local theme = Zenith.Theme()
local net = Zenith.Services.Network()
local wifis = Zenith.Services.WifiScan()

local total_wifis = #wifis
local max_visible = 6
local scroll_offset = _G.__network_scroll or 0
if scroll_offset > math.max(0, total_wifis - max_visible) then
    scroll_offset = math.max(0, total_wifis - max_visible)
end
if scroll_offset < 0 then
    scroll_offset = 0
end

local start_idx = scroll_offset + 1
local end_idx = math.min(total_wifis, start_idx + max_visible - 1)

local wifi_items = {}
if total_wifis == 0 then
    table.insert(wifi_items, Zenith.Box({
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
                text = "󰤮 No networks in range",
                font_size = 11,
                color = Zenith.hex(theme.outline),
            }),
        }
    }))
else
    for i = start_idx, end_idx do
        local ap = wifis[i]
        if not ap then break end

        local sig_icon = if ap.signal >= 75 then "󰤨"
            elseif ap.signal >= 50 then "󰤥"
            elseif ap.signal >= 25 then "󰤢"
            else "󰤟"

        table.insert(wifi_items, Zenith.Box({
            direction = "row",
            align_items = "center",
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
                    align_items = "stretch",
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
end

local visible_count = if total_wifis == 0 then 1 else (end_idx - start_idx + 1)
local win_height = math.min(500, 180 + (visible_count * 52))

local section_header_text = if total_wifis > max_visible
    then string.format("AVAILABLE NETWORKS (%d–%d of %d • scroll)", start_idx, end_idx, total_wifis)
    else string.format("AVAILABLE NETWORKS (%d)", total_wifis)

local function scroll_up()
    _G.__network_scroll = math.max(0, (_G.__network_scroll or 0) - 1)
end

local function scroll_down()
    local max_s = math.max(0, total_wifis - max_visible)
    _G.__network_scroll = math.min(max_s, (_G.__network_scroll or 0) + 1)
end

return Zenith.Window({
    direction = "column",
    align_items = "stretch",
    width = 360,
    height = win_height,
    padding = { x = 16, y = 14 },
    gap = 12,
    background = Zenith.rgba(18, 20, 26, 230),
    border_color = Zenith.hex(theme.primary),
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
        -- Header: Title + Close
        Zenith.Box({
            direction = "row",
            align_items = "center",
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
            align_items = "stretch",
            gap = 4,
            padding = { x = 12, y = 10 },
            border_radius = 10,
            background = Zenith.hex(theme.surface_container),
            border_color = Zenith.rgba(255, 255, 255, 16),
            border_width = 1,
            children = {
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
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
            text = section_header_text,
            font_size = 10,
            color = Zenith.hex(theme.outline),
        }),

        -- Wi-Fi Access Points List
        Zenith.Box({
            direction = "column",
            align_items = "stretch",
            gap = 6,
            flex_grow = 1,
            on_scroll_up = scroll_up,
            on_scroll_down = scroll_down,
            children = wifi_items,
        }),
    }
})
