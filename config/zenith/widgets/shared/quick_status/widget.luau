--!strict
local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")
local PopupManager = Zenith.import("core/popup_manager")

local function QuickStatus(props: { show_actions: boolean? }?)
    local theme = Theme.get()
    local net = Services.Network.status()
    local audio = Services.Audio.status()
    local bt = Services.Bluetooth.status()
    local bat = Services.Battery.status()
    local notifs = Services.Notifications.list()
    local is_dnd = Services.Notifications.is_dnd()

    local vol = audio.volume or 0
    local is_muted = audio.muted or false
    local audio_icon = if is_muted then "󰝟" elseif vol >= 50 then "󰕾" elseif vol > 0 then "󰖀" else "󰕿"
    local audio_color = if is_muted then Zenith.hex(theme.error or "#f38ba8") else Zenith.hex(theme.primary)

    local is_conn = net.is_connected or false
    local net_icon = if not is_conn then "󰤮" elseif net.type == "wifi" or not net.ethernet then "󰤨" else "󰈀"
    local net_color = if is_conn then Zenith.hex(theme.primary) else Zenith.hex(theme.outline_variant or theme.outline)

    local bt_on = bt.powered or false
    local bt_icon = if not bt_on then "󰂲" elseif bt.connected then "󰂱" else "󰂯"
    local bt_color = if bt_on then Zenith.hex(theme.primary) else Zenith.hex(theme.outline_variant or theme.outline)

    local bat_pct = bat.percent or 100
    local bat_charging = bat.is_charging or false
    local bat_icon = if bat_charging then "󰂄" elseif bat_pct > 80 then "󰁹" elseif bat_pct > 30 then "󰁽" else "󰁺"
    local bat_color = if bat_pct < 20 and not bat_charging then Zenith.hex(theme.error or "#f38ba8") else Zenith.hex(theme.primary)

    local notif_count = #notifs
    local notif_icon = if is_dnd then "󰂛" elseif notif_count > 0 then "󰂚" else "󰂜"
    local notif_color = if is_dnd then Zenith.hex(theme.error or "#f38ba8") elseif notif_count > 0 then Zenith.hex(theme.primary) else Zenith.hex(theme.outline_variant or theme.outline)

    local status_children = {
        Zenith.Box({
            direction = "row",
            align_items = "center",
            height = 26,
            padding = { horizontal = 6, vertical = 2 },
            border_radius = 13,
            background = Zenith.hex(theme.surface_container, 130),
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
            border_width = 1,
            tooltip = "Rede • Clique: Painel de Rede",
            cursor = "pointer",
            on_click = PopupManager.toggle_action("NetworkPopup"),
            children = {
                Zenith.Text({ text = net_icon, font_size = 12, color = net_color }),
            }
        }),

        Zenith.Box({
            direction = "row",
            align_items = "center",
            height = 26,
            gap = 4,
            padding = { horizontal = 7, vertical = 2 },
            border_radius = 13,
            background = Zenith.hex(theme.surface_container, 130),
            border_color = if is_muted then Zenith.hex(theme.error or "#f38ba8", 80) else Zenith.hex(theme.outline_variant or theme.outline, 45),
            border_width = 1,
            tooltip = "Áudio • " .. tostring(vol) .. "%",
            cursor = "pointer",
            on_click = PopupManager.toggle_action("AudioPopup"),
            on_right_click = "audio:toggle_mute",
            children = {
                Zenith.Text({ text = audio_icon, font_size = 12, color = audio_color }),
                Zenith.Text({ text = string.format("%d%%", vol), font_size = 11, color = Zenith.hex(theme.on_surface) }),
            }
        }),

        Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "center",
            height = 26,
            padding = { horizontal = 6, vertical = 2 },
            border_radius = 13,
            background = Zenith.hex(theme.surface_container, 130),
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
            border_width = 1,
            tooltip = "Bluetooth • Clique: Dispositivos",
            cursor = "pointer",
            on_click = PopupManager.toggle_action("BluetoothPopup"),
            children = {
                Zenith.Text({ text = bt_icon, font_size = 12, color = bt_color }),
            }
        }),

        Zenith.Box({
            direction = "row",
            align_items = "center",
            height = 26,
            gap = 3,
            padding = { horizontal = 7, vertical = 2 },
            border_radius = 13,
            background = Zenith.hex(theme.surface_container, 130),
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
            border_width = 1,
            tooltip = "Bateria • " .. tostring(bat_pct) .. "%",
            cursor = "pointer",
            on_click = PopupManager.toggle_action("BatteryPopup"),
            children = {
                Zenith.Text({ text = bat_icon, font_size = 12, color = bat_color }),
                Zenith.Text({ text = string.format("%d%%", bat_pct), font_size = 11, color = Zenith.hex(theme.on_surface) }),
            }
        }),

        Zenith.Box({
            direction = "row",
            align_items = "center",
            height = 26,
            gap = 3,
            padding = { horizontal = 6, vertical = 2 },
            border_radius = 13,
            background = if is_dnd then Zenith.hex(theme.error or "#f38ba8", 35) elseif notif_count > 0 then Zenith.hex(theme.primary, 40) else Zenith.hex(theme.surface_container, 130),
            border_color = if is_dnd then Zenith.hex(theme.error or "#f38ba8", 90) elseif notif_count > 0 then Zenith.hex(theme.primary, 100) else Zenith.hex(theme.outline_variant or theme.outline, 45),
            border_width = 1,
            tooltip = "Notificações",
            cursor = "pointer",
            on_click = PopupManager.toggle_action("NotificationCenter"),
            on_right_click = "notification:toggle_dnd",
            children = {
                Zenith.Text({ text = notif_icon, font_size = 12, color = notif_color }),
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
            padding = { horizontal = 7, vertical = 2 },
            border_radius = 13,
            background = Zenith.hex(theme.surface_container, 130),
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
            border_width = 1,
            tooltip = "Configurações",
            cursor = "pointer",
            on_click = PopupManager.toggle_action("Settings"),
            children = {
                Zenith.Text({ text = "󰒓", font_size = 12, color = Zenith.hex(theme.primary) }),
            }
        }))

        table.insert(status_children, Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "center",
            height = 26,
            padding = { horizontal = 8, vertical = 2 },
            border_radius = 13,
            background = Zenith.hex(theme.error or "#f38ba8", 35),
            border_color = Zenith.hex(theme.error or "#f38ba8", 90),
            border_width = 1,
            tooltip = "Menu de Sessão & Energia",
            cursor = "pointer",
            on_click = PopupManager.toggle_action("PowerMenu"),
            children = {
                Zenith.Text({ text = "", font_size = 12, color = Zenith.hex(theme.error or "#f38ba8") }),
            }
        }))
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = 4,
        children = status_children,
    })
end

return QuickStatus
