--!strict
-- Zenith UI Kit - Quick Status & Connectivity Component (Quickshell / Caelestia style)

local function QuickStatus()
    local theme = Zenith.Theme()
    local battery = Zenith.Services.battery()
    local audio = Zenith.Services.audio()
    local net = Zenith.Services.network()
    local notifs = Zenith.Services.Notifications()

    local bat_icon = "󰂄"
    local bat_pct = 100
    if battery then
        bat_pct = battery.percentage
        if battery.is_charging then
            bat_icon = "󰂄"
        elseif bat_pct > 80 then
            bat_icon = "󰁹"
        elseif bat_pct > 50 then
            bat_icon = "󰁿"
        elseif bat_pct > 20 then
            bat_icon = "󰁼"
        else
            bat_icon = "󰂃"
        end
    end

    local is_net_connected = if net then (net.is_connected == true or net.connected == true) else false
    local net_type = if net and net.type then net.type else "none"
    local net_ssid = if net and net.ssid then net.ssid else ""

    local net_icon = if not is_net_connected then "󰤭" elseif net_type == "wifi" then "󰖩" else "󰈀"
    local net_color = if is_net_connected then Zenith.hex("#a6e3a1") else Zenith.hex("#e06c75")
    local audio_icon = if audio.is_muted then "󰝟" elseif audio.volume > 50 then "" else ""

    local notif_count = #notifs
    local notif_icon = if notif_count > 0 then "󰂚 " .. tostring(notif_count) else "󰂜"
    local notif_color = if notif_count > 0 then Zenith.hex(theme.primary) else Zenith.rgba(255, 255, 255, 120)

    local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366 }
    local screen_w = screen.width or 1366
    local pill_pad = if screen_w < 1440 then 6 else 7
    local pill_gap = if screen_w < 1440 then 3 else 4

    -- On compact displays (< 1440), network is icon-only to avoid pushing bar out of view
    local net_label = if screen_w < 1440 then "" elseif not is_net_connected then "" elseif #net_ssid > 0 then (if #net_ssid > 8 then net_ssid:sub(1, 6) .. ".." else net_ssid) else "Wired"

    return Zenith.Box({
        direction = "row",
        gap = pill_gap,
        children = {
            -- Network Pill
            Zenith.Box({
                direction = "row",
                gap = 3,
                padding = { x = if #net_label > 0 then pill_pad else (pill_pad - 1), y = 3 },
                border_radius = 12,
                background = Zenith.rgba(255, 255, 255, 10),
                border_color = Zenith.rgba(255, 255, 255, 18),
                border_width = 1,
                on_click = "popup:toggle:NetworkPopup",
                children = {
                    Zenith.Text({
                        text = net_icon,
                        font_size = 11,
                        color = net_color,
                    }),
                    if #net_label > 0 then Zenith.Text({
                        text = net_label,
                        font_size = 11,
                        color = Zenith.hex(theme.on_surface),
                    }) else nil,
                }
            }),

            -- Audio Pill
            Zenith.Box({
                direction = "row",
                gap = 3,
                padding = { x = pill_pad, y = 3 },
                border_radius = 12,
                background = Zenith.rgba(255, 255, 255, 10),
                border_color = Zenith.rgba(255, 255, 255, 18),
                border_width = 1,
                on_click = "popup:toggle:AudioPopup",
                on_right_click = "audio:toggle_mute",
                on_scroll_up = "audio:volume_step:5",
                on_scroll_down = "audio:volume_step:-5",
                children = {
                    Zenith.Text({
                        text = audio_icon,
                        font_size = 11,
                        color = audio.is_muted and Zenith.hex("#e06c75") or Zenith.hex(theme.primary),
                    }),
                    Zenith.Text({
                        text = string.format("%d%%", audio.volume),
                        font_size = 11,
                        color = audio.is_muted and Zenith.hex("#e06c75") or Zenith.hex(theme.on_surface),
                    }),
                }
            }),

            -- Bluetooth Pill
            Zenith.Box({
                direction = "row",
                gap = 3,
                padding = { x = pill_pad, y = 3 },
                border_radius = 12,
                background = Zenith.rgba(255, 255, 255, 10),
                border_color = Zenith.rgba(255, 255, 255, 18),
                border_width = 1,
                on_click = "popup:toggle:BluetoothPopup",
                children = {
                    Zenith.Text({
                        text = "󰂯",
                        font_size = 11,
                        color = Zenith.hex(theme.primary),
                    }),
                }
            }),

            -- Battery Pill
            Zenith.Box({
                direction = "row",
                gap = 3,
                padding = { x = pill_pad, y = 3 },
                border_radius = 12,
                background = Zenith.rgba(255, 255, 255, 10),
                border_color = Zenith.rgba(255, 255, 255, 18),
                border_width = 1,
                children = {
                    Zenith.Text({
                        text = bat_icon,
                        font_size = 11,
                        color = Zenith.hex(theme.primary),
                    }),
                    Zenith.Text({
                        text = string.format("%d%%", bat_pct),
                        font_size = 11,
                        color = Zenith.hex(theme.on_surface),
                    }),
                }
            }),

            -- Notification Center Bell Pill
            Zenith.Box({
                padding = { x = pill_pad, y = 3 },
                border_radius = 12,
                background = notif_count > 0 and Zenith.rgba(122, 162, 247, 30) or Zenith.rgba(255, 255, 255, 10),
                border_color = notif_count > 0 and Zenith.rgba(122, 162, 247, 80) or Zenith.rgba(255, 255, 255, 18),
                border_width = 1,
                on_click = "popup:toggle:NotificationCenter",
                children = {
                    Zenith.Text({
                        text = notif_icon,
                        font_size = 11,
                        color = notif_color,
                    })
                }
            }),

            -- Settings Hub Pill (iNiR style)
            Zenith.Box({
                padding = { x = pill_pad, y = 3 },
                border_radius = 12,
                background = Zenith.rgba(255, 255, 255, 10),
                border_color = Zenith.rgba(255, 255, 255, 18),
                border_width = 1,
                on_click = "popup:toggle:Settings",
                on_right_click = "cmd:/home/lucas/.local/bin/zenith-settings --quickshell",
                children = {
                    Zenith.Text({
                        text = "󰒓",
                        font_size = 11,
                        color = Zenith.hex(theme.primary),
                    })
                }
            }),

            -- Session / Power Button (End-4 style)
            Zenith.Box({
                padding = { x = pill_pad + 1, y = 3 },
                border_radius = 12,
                background = Zenith.rgba(230, 57, 70, 45),
                border_color = Zenith.rgba(230, 57, 70, 95),
                border_width = 1,
                on_click = "popup:toggle:PowerMenu",
                children = {
                    Zenith.Text({
                        text = "",
                        font_size = 11,
                        color = Zenith.hex("#ff7582"),
                    })
                }
            })
        }
    })
end

return QuickStatus
