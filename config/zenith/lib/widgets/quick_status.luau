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

    local net_icon = if not net.is_connected then "󰤭" elseif net.type == "wifi" then "󰖩" else "󰈀"
    local audio_icon = if audio.is_muted then "󰝟" elseif audio.volume > 50 then "" else ""

    local notif_count = #notifs
    local notif_icon = if notif_count > 0 then "󰂚 " .. tostring(notif_count) else "󰂜"
    local notif_color = if notif_count > 0 then Zenith.hex(theme.primary) else Zenith.rgba(255, 255, 255, 120)

    return Zenith.Box({
        direction = "row",
        gap = 5,
        children = {
            -- Network Pill
            Zenith.Box({
                direction = "row",
                gap = 5,
                padding = { x = 9, y = 3 },
                border_radius = 12,
                background = Zenith.rgba(255, 255, 255, 10),
                border_color = Zenith.rgba(255, 255, 255, 18),
                border_width = 1,
                on_click = "popup:toggle:NetworkPopup",
                children = {
                    Zenith.Text({
                        text = net_icon,
                        font_size = 11,
                        color = net.is_connected and Zenith.hex("#a6e3a1") or Zenith.hex("#e06c75"),
                    }),
                    Zenith.Text({
                        text = net.is_connected and (#net.ssid > 0 and net.ssid or "Wired") or "Offline",
                        font_size = 11,
                        color = Zenith.hex(theme.on_surface),
                    }),
                }
            }),

            -- Audio Pill
            Zenith.Box({
                direction = "row",
                gap = 5,
                padding = { x = 9, y = 3 },
                border_radius = 12,
                background = Zenith.rgba(255, 255, 255, 10),
                border_color = Zenith.rgba(255, 255, 255, 18),
                border_width = 1,
                on_click = "popup:toggle:AudioPopup",
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
                gap = 5,
                padding = { x = 9, y = 3 },
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
                gap = 5,
                padding = { x = 9, y = 3 },
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
                padding = { x = 9, y = 3 },
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

            -- Session / Power Button (End-4 style)
            Zenith.Box({
                padding = { x = 10, y = 3 },
                border_radius = 12,
                background = Zenith.rgba(230, 57, 70, 45),
                border_color = Zenith.rgba(230, 57, 70, 95),
                border_width = 1,
                on_click = "popup:toggle:PowerMenu",
                children = {
                    Zenith.Text({
                        text = "",
                        font_size = 12,
                        color = Zenith.hex("#ff7582"),
                    })
                }
            })
        }
    })
end

return QuickStatus
