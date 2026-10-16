--!strict
-- Zenith UI Kit - Quick Status & Connectivity Component (Quickshell / Caelestia style)

local function QuickStatus(props: { compact: boolean?, micro_cluster: boolean?, show_actions: boolean? }?)
    local theme = Zenith.Theme()
    local battery = (Zenith.Services.battery and Zenith.Services.battery()) or (Zenith.Services.Battery and Zenith.Services.Battery())
    local audio = (Zenith.Services.audio and Zenith.Services.audio()) or (Zenith.Services.Audio and Zenith.Services.Audio()) or { volume = 0, is_muted = false, muted = false }
    local net = (Zenith.Services.network and Zenith.Services.network()) or (Zenith.Services.Network and Zenith.Services.Network())
    local notifs = (Zenith.Services.Notifications and Zenith.Services.Notifications()) or (Zenith.Services.notifications and Zenith.Services.notifications()) or {}
    local is_dnd = if Zenith.Services.IsDND then Zenith.Services.IsDND() elseif Zenith.Services.is_dnd then Zenith.Services.is_dnd() else false

    -- Battery state & micro-icon synchronization
    local bat_pct = 100
    local is_charging = false
    if battery then
        bat_pct = battery.percentage or 100
        is_charging = battery.is_charging == true or battery.charging == true
    end

    local bat_icon = if is_charging then "󰂄"
        elseif bat_pct > 80 then "󰁹"
        elseif bat_pct > 50 then "󰁿"
        elseif bat_pct > 20 then "󰁼"
        else "󰂃"

    local bat_color = if is_charging then Zenith.hex(theme.green or "#a6e3a1")
        elseif bat_pct <= 20 then Zenith.hex(theme.error or "#f38ba8")
        elseif bat_pct <= 40 then Zenith.hex(theme.yellow or "#f9e2af")
        else Zenith.hex(theme.primary)

    -- Connectivity (Network & Bluetooth) micro-icon synchronization
    local is_net_connected = if net then (net.is_connected == true or net.connected == true) else false
    local net_type = if net and net.type then net.type else "none"
    local net_ssid = if net and net.ssid then net.ssid else ""

    local net_icon = if not is_net_connected then "󰤭"
        elseif net_type == "wifi" or #net_ssid > 0 then "󰖩"
        else "󰈀"
    local net_color = if is_net_connected then Zenith.hex(theme.green or "#a6e3a1") else Zenith.hex(theme.error or "#e06c75")

    -- Audio state & micro-icon synchronization
    local is_muted = if audio then (audio.is_muted == true or audio.muted == true) else false
    local vol = if audio and audio.volume then audio.volume else 0
    local audio_icon = if is_muted or vol == 0 then "󰝟"
        elseif vol > 60 then "󰕾"
        elseif vol > 25 then "󰖀"
        else "󰕿"
    local audio_color = if is_muted then Zenith.hex(theme.error or "#f38ba8") else Zenith.hex(theme.primary)

    -- DND & Notification micro-icon synchronization
    local notif_count = #notifs
    local notif_icon = if is_dnd then "󰂛"
        elseif notif_count > 0 then "󰂚"
        else "󰂜"
    local notif_color = if is_dnd then Zenith.hex(theme.error or "#f38ba8")
        elseif notif_count > 0 then Zenith.hex(theme.primary)
        else Zenith.hex(theme.on_surface_variant or theme.outline, 160)

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

    local net_tooltip = if is_net_connected then ("Rede: " .. (if #net_ssid > 0 then net_ssid else "Ethernet") .. " (" .. (net.ip or "Conectado") .. ")\n• Clique: Painel de Rede") else "Rede: Desconectado\n• Clique: Painel de Rede"
    local audio_tooltip = string.format("Volume: %d%%%s\n• Clique: Mixer de Áudio\n• Botão Direito: Mutar / Desmutar\n• Scroll: Ajustar Volume (±5%%)", vol, if is_muted then " (Mutado)" else "")
    local bat_tooltip = string.format("Bateria: %d%%%s\n• Clique: Detalhes de Bateria & Perfis de Energia", bat_pct, if is_charging then " (Carregando)" else "")
    local notif_tooltip = if is_dnd then
        string.format("Não Perturbe (DND) Ativo • %d notificações silenciadas\n• Clique: Central de Notificações\n• Botão Direito: Desativar DND", notif_count)
    else
        string.format("Notificações: %d ativas%s\n• Clique: Central de Notificações\n• Botão Direito: Ativar Não Perturbe (DND)", notif_count, if notif_count > 0 then "" else " (Nenhuma pendente)")

    -- Micro-cluster compact mode (integrated single container with 4 status icons)
    if props and props.micro_cluster == true then
        return Zenith.Box({
            direction = "row",
            align_items = "center",
            height = 26,
            gap = 5,
            padding = { x = 8, y = 2 },
            border_radius = 13,
            background = Zenith.hex(theme.surface_container, 130),
            border_color = if is_dnd then Zenith.hex(theme.error or "#f38ba8", 75) else Zenith.hex(theme.outline_variant or theme.outline, 45),
            border_width = 1,
            tooltip = string.format("%s\n%s\n%s\n%s", net_tooltip, audio_tooltip, bat_tooltip, notif_tooltip),
            children = {
                -- 1. Connectivity micro-icon
                Zenith.Text({
                    text = net_icon,
                    font_size = 12,
                    color = net_color,
                    on_click = "popup:toggle:NetworkPopup",
                }),
                -- 2. Audio micro-icon
                Zenith.Text({
                    text = audio_icon,
                    font_size = 12,
                    color = audio_color,
                    on_click = "popup:toggle:AudioPopup",
                    on_right_click = "audio:toggle_mute",
                }),
                -- 3. Battery micro-icon
                Zenith.Text({
                    text = bat_icon,
                    font_size = 12,
                    color = bat_color,
                    on_click = "popup:toggle:BatteryPopup",
                }),
                -- 4. DND / Notification micro-icon
                Zenith.Text({
                    text = notif_icon,
                    font_size = 12,
                    color = notif_color,
                    on_click = "popup:toggle:NotificationCenter",
                    on_right_click = "notification:toggle_dnd",
                }),
            }
        })
    end

    local status_children = {
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
                border_color = is_muted and Zenith.hex(theme.error or "#f38ba8", 80) or Zenith.hex(theme.outline_variant or theme.outline, 45),
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
                        color = audio_color,
                    }),
                    Zenith.Text({
                        text = string.format("%d%%", vol),
                        font_size = 11,
                        color = is_muted and Zenith.hex(theme.error or "#f38ba8") or Zenith.hex(theme.on_surface),
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

            -- Notification / DND Center Bell Pill
            Zenith.Box({
                direction = "row",
                align_items = "center",
                height = 26,
                gap = 3,
                padding = { x = pill_pad, y = 2 },
                border_radius = 13,
                background = if is_dnd then Zenith.hex(theme.error or "#f38ba8", 35) elseif notif_count > 0 then Zenith.hex(theme.primary, 40) else Zenith.hex(theme.surface_container, 130),
                border_color = if is_dnd then Zenith.hex(theme.error or "#f38ba8", 90) elseif notif_count > 0 then Zenith.hex(theme.primary, 100) else Zenith.hex(theme.outline_variant or theme.outline, 45),
                border_width = 1,
                tooltip = notif_tooltip,
                on_click = "popup:toggle:NotificationCenter",
                on_right_click = "notification:toggle_dnd",
                children = {
                    Zenith.Text({
                        text = notif_icon,
                        font_size = 12,
                        color = notif_color,
                    }),
                    if notif_count > 0 then Zenith.Text({
                        text = tostring(notif_count),
                        font_size = 10,
                        color = if is_dnd then Zenith.hex(theme.error or "#f38ba8") else Zenith.hex(theme.primary),
                    }) else nil,
                }
            }),

    }

    local show_actions = if props and props.show_actions ~= nil then props.show_actions else true
    if show_actions then
        table.insert(status_children, Zenith.Box({
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
        }))

        table.insert(status_children, Zenith.Box({
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
        }))
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = pill_gap,
        children = status_children,
    })
end

return QuickStatus
