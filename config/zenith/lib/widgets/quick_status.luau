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
    local net_color = if is_net_connected then Zenith.hex(theme.green or "#a6e3a1") else Zenith.hex(theme.error or "#e06c75")
    local audio_icon = if audio.is_muted then "󰝟" elseif audio.volume > 50 then "" elseif audio.volume > 20 then "" else ""

    local notif_count = #notifs
    local notif_icon = if notif_count > 0 then "󰂚" else "󰂜"
    local notif_color = if notif_count > 0 then Zenith.hex(theme.primary) else Zenith.hex(theme.on_surface_variant or theme.outline, 160)

    local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366 }
    local screen_w = screen.width or 1366
    local pill_pad = if screen_w < 1440 then 7 else 8
    local pill_gap = if screen_w < 1440 then 3 else 4

    -- On compact displays (< 1440), network is icon-only to avoid pushing bar out of view
    local net_label = if screen_w < 1440 then "" elseif not is_net_connected then "" elseif #net_ssid > 0 then (if #net_ssid > 8 then net_ssid:sub(1, 6) .. ".." else net_ssid) else "Wired"

    local bt = (Zenith.Services.Bluetooth and Zenith.Services.Bluetooth()) or (Zenith.Services.bluetooth and Zenith.Services.bluetooth()) or { powered = false, devices = {} }
    local bt_connected_dev = nil
    if bt and bt.devices then
        for _, d in ipairs(bt.devices) do
            if d.connected then
                bt_connected_dev = d
                break
            end
        end
    end
    local bt_icon = if bt_connected_dev then "󰂱" elseif bt.powered then "󰂯" else "󰂲"
    local bt_color = if bt_connected_dev then Zenith.hex(theme.primary) elseif bt.powered then Zenith.hex(theme.on_surface) else Zenith.hex(theme.outline)
    local bt_tooltip = if bt_connected_dev then ("Bluetooth: Conectado a " .. bt_connected_dev.name) elseif bt.powered then "Bluetooth: Ativado (Sem dispositivos)" else "Bluetooth: Desativado"

    local net_tooltip = if is_net_connected then ("Rede: " .. (if #net_ssid > 0 then net_ssid else "Ethernet") .. " (" .. (net.ip or "Conectado") .. ")") else "Rede: Desconectado"
    local audio_tooltip = string.format("Volume: %d%%%s", audio.volume, if audio.is_muted then " (Mutado)" else "")
    local bat_tooltip = string.format("Bateria: %d%%%s", bat_pct, if battery and battery.is_charging then " (Carregando)" else "")

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = pill_gap,
        children = {
            -- Network Pill
            Zenith.Box({
                direction = "row",
                align_items = "center",
                height = 26,
                gap = 3,
                padding = { x = if #net_label > 0 then pill_pad else (pill_pad - 1), y = 2 },
                border_radius = 13,
                background = Zenith.hex(theme.surface_container, 130),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
                border_width = 1,
                tooltip = net_tooltip,
                on_click = "popup:toggle:NetworkPopup",
                children = {
                    Zenith.Text({
                        text = net_icon,
                        font_size = 12,
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
                align_items = "center",
                height = 26,
                gap = 4,
                padding = { x = pill_pad, y = 2 },
                border_radius = 13,
                background = Zenith.hex(theme.surface_container, 130),
                border_color = audio.is_muted and Zenith.hex(theme.error or "#f38ba8", 80) or Zenith.hex(theme.outline_variant or theme.outline, 45),
                border_width = 1,
                tooltip = audio_tooltip,
                on_click = "popup:toggle:AudioPopup",
                on_right_click = "audio:toggle_mute",
                on_scroll_up = "audio:volume_step:5",
                on_scroll_down = "audio:volume_step:-5",
                children = {
                    Zenith.Text({
                        text = audio_icon,
                        font_size = 12,
                        color = audio.is_muted and Zenith.hex(theme.error or "#f38ba8") or Zenith.hex(theme.primary),
                    }),
                    Zenith.Text({
                        text = string.format("%d%%", audio.volume),
                        font_size = 11,
                        color = audio.is_muted and Zenith.hex(theme.error or "#f38ba8") or Zenith.hex(theme.on_surface),
                    }),
                }
            }),

            -- Bluetooth Pill
            Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "center",
                height = 26,
                padding = { x = pill_pad, y = 2 },
                border_radius = 13,
                background = Zenith.hex(theme.surface_container, 130),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
                border_width = 1,
                tooltip = bt_tooltip,
                on_click = "popup:toggle:BluetoothPopup",
                children = {
                    Zenith.Text({
                        text = bt_icon,
                        font_size = 12,
                        color = bt_color,
                    }),
                }
            }),

            -- Battery Pill
            Zenith.Box({
                direction = "row",
                align_items = "center",
                height = 26,
                gap = 3,
                padding = { x = pill_pad, y = 2 },
                border_radius = 13,
                background = Zenith.hex(theme.surface_container, 130),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
                border_width = 1,
                tooltip = bat_tooltip,
                on_click = "popup:toggle:BatteryPopup",
                children = {
                    Zenith.Text({
                        text = bat_icon,
                        font_size = 12,
                        color = bat_color,
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
                direction = "row",
                align_items = "center",
                height = 26,
                gap = 3,
                padding = { x = pill_pad, y = 2 },
                border_radius = 13,
                background = notif_count > 0 and Zenith.hex(theme.primary, 40) or Zenith.hex(theme.surface_container, 130),
                border_color = notif_count > 0 and Zenith.hex(theme.primary, 100) or Zenith.hex(theme.outline_variant or theme.outline, 45),
                border_width = 1,
                tooltip = string.format("Notificações: %d ativas", notif_count),
                on_click = "popup:toggle:NotificationCenter",
                children = {
                    Zenith.Text({
                        text = notif_icon,
                        font_size = 12,
                        color = notif_color,
                    }),
                    if notif_count > 0 then Zenith.Text({
                        text = tostring(notif_count),
                        font_size = 10,
                        color = Zenith.hex(theme.primary),
                    }) else nil,
                }
            }),

            -- Settings Hub Pill
            Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "center",
                height = 26,
                padding = { x = pill_pad, y = 2 },
                border_radius = 13,
                background = Zenith.hex(theme.surface_container, 130),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
                border_width = 1,
                tooltip = "Configurações do Sistema",
                on_click = "popup:toggle:Settings",
                on_right_click = "cmd:/home/lucas/.local/bin/zenith-settings --quickshell",
                children = {
                    Zenith.Text({
                        text = "󰒓",
                        font_size = 12,
                        color = Zenith.hex(theme.primary),
                    })
                }
            }),

            -- Session / Power Button (End-4 style)
            Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "center",
                height = 26,
                padding = { x = pill_pad + 1, y = 2 },
                border_radius = 13,
                background = Zenith.rgba(230, 57, 70, 40),
                border_color = Zenith.rgba(230, 57, 70, 95),
                border_width = 1,
                tooltip = "Menu de Sessão & Energia",
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
