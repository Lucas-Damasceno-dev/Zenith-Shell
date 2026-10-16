--!strict
-- Zenith-Shell (Engine v2) - Unified Control Center Overlay
-- 1:1 Parity with Quickshell ControlCenterPopup.qml

local theme = Zenith.Theme()
local audio = Zenith.Services.Audio()
local net = Zenith.Services.Network()
local bt = Zenith.Services.Bluetooth()
local media = Zenith.Services.Media()
local battery = Zenith.Services.Battery()
local brightness = Zenith.Services.Brightness and Zenith.Services.Brightness() or { percent = 80 }
local power = Zenith.Services.Power and Zenith.Services.Power() or { profile = "balanced" }

local function QuickToggleTile(props: {
    icon: string,
    label: string,
    sublabel: string,
    active: boolean,
    toggle_action: string,
    open_action: string?,
})
    local bg = if props.active then Zenith.hex(theme.primary, 220) else Zenith.hex(theme.surface_container, 140)
    local fg = if props.active then Zenith.hex(theme.on_primary) else Zenith.hex(theme.on_surface)
    local sub_fg = if props.active then Zenith.hex(theme.on_primary, 190) else Zenith.hex(theme.outline)

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        flex_grow = 1,
        height = 54,
        padding = { x = 10, y = 8 },
        border_radius = 12,
        background = bg,
        border_color = if props.active then Zenith.hex(theme.primary) else Zenith.rgba(255, 255, 255, 14),
        border_width = 1,
        on_click = props.toggle_action,
        children = {
            Zenith.Box({
                width = 34,
                height = 34,
                border_radius = 17,
                align_items = "center",
                justify_content = "center",
                background = if props.active then Zenith.rgba(255, 255, 255, 30) else Zenith.hex(theme.surface_container_high or theme.surface, 160),
                children = {
                    Zenith.Text({
                        text = props.icon,
                        font_size = 15,
                        color = fg,
                    }),
                }
            }),
            Zenith.Box({ width = 8 }),
            Zenith.Box({
                direction = "column",
                flex_grow = 1,
                children = {
                    Zenith.Text({
                        text = props.label,
                        font_size = 11,
                        font_weight = "bold",
                        color = fg,
                    }),
                    Zenith.Text({
                        text = props.sublabel,
                        font_size = 9,
                        color = sub_fg,
                    }),
                }
            }),
            if props.open_action then
                Zenith.Box({
                    padding = { x = 6, y = 6 },
                    border_radius = 6,
                    on_click = props.open_action,
                    children = {
                        Zenith.Text({
                            text = "󰅂",
                            font_size = 12,
                            color = fg,
                        }),
                    }
                })
            else
                Zenith.Box({ width = 0 })
        }
    })
end

local is_wifi_active = net.connected and net.type == "wifi"
local is_bt_active = bt.powered
local is_dnd_active = _G.__dnd_active or false
local is_night_active = _G.__night_active or false
local is_gray_active = _G.__gray_active or false
local is_game_active = _G.__game_active or false

return Zenith.Window({
    direction = "column",
    width = 380,
    height = 620,
    padding = { x = 16, y = 14 },
    gap = 12,
    background = Zenith.hex(theme.surface, 238),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 70),
    border_width = 1,
    border_radius = 18,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 160),
        blur = 28,
        spread = 2,
        offset_y = 10,
    },
    children = {
        -- 1. Header Profile & System Actions
        Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { x = 6, y = 4 },
            children = {
                Zenith.Box({
                    width = 40,
                    height = 40,
                    border_radius = 20,
                    align_items = "center",
                    justify_content = "center",
                    background = Zenith.hex(theme.primary_container or theme.primary, 180),
                    children = {
                        Zenith.Text({
                            text = "󰀉",
                            font_size = 18,
                            color = Zenith.hex(theme.on_primary or theme.primary),
                        }),
                    }
                }),
                Zenith.Box({ width = 10 }),
                Zenith.Box({
                    direction = "column",
                    flex_grow = 1,
                    children = {
                        Zenith.Text({
                            text = "lucas@meu-nixos",
                            font_size = 12,
                            font_weight = "bold",
                            color = Zenith.hex(theme.on_surface),
                        }),
                        Zenith.Text({
                            text = "Zenith Control Center",
                            font_size = 10,
                            color = Zenith.hex(theme.outline),
                        }),
                    }
                }),
                -- Action Buttons
                Zenith.Box({
                    direction = "row",
                    gap = 6,
                    children = {
                        Zenith.Box({
                            padding = { x = 8, y = 6 },
                            border_radius = 8,
                            background = Zenith.hex(theme.surface_container, 180),
                            on_click = "popup:toggle:Settings",
                            tooltip = "Configurações",
                            children = {
                                Zenith.Text({ text = "󰒓", font_size = 13, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 8, y = 6 },
                            border_radius = 8,
                            background = Zenith.hex(theme.surface_container, 180),
                            on_click = "zenith:lock",
                            tooltip = "Bloquear Tela",
                            children = {
                                Zenith.Text({ text = "󰌾", font_size = 13, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 8, y = 6 },
                            border_radius = 8,
                            background = Zenith.hex(theme.surface_container, 180),
                            on_click = "popup:toggle:PowerMenu",
                            tooltip = "Energia & Sessão",
                            children = {
                                Zenith.Text({ text = "󰐥", font_size = 13, color = Zenith.hex("#e06c75") }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 6, y = 6 },
                            border_radius = 8,
                            background = Zenith.hex(theme.surface_container, 140),
                            on_click = "popup:close",
                            children = {
                                Zenith.Text({ text = "󰅖", font_size = 12, color = Zenith.hex(theme.outline) }),
                            }
                        }),
                    }
                })
            }
        }),

        -- 2. Quick Toggles Grid (3x2)
        Zenith.Box({
            direction = "column",
            gap = 8,
            children = {
                Zenith.Box({
                    direction = "row",
                    gap = 8,
                    children = {
                        QuickToggleTile({
                            icon = if is_wifi_active then "󰤨" else "󰤮",
                            label = "Wi-Fi",
                            sublabel = if net.connected then (net.ssid or "Conectado") else "Desconectado",
                            active = is_wifi_active,
                            toggle_action = "network:toggle_wifi",
                            open_action = "popup:open:NetworkPopup",
                        }),
                        QuickToggleTile({
                            icon = if is_bt_active then "󰂯" else "󰂲",
                            label = "Bluetooth",
                            sublabel = if is_bt_active then (#bt.devices .. " dispositivos") else "Desativado",
                            active = is_bt_active,
                            toggle_action = "bluetooth:toggle",
                            open_action = "popup:open:BluetoothPopup",
                        }),
                    }
                }),
                Zenith.Box({
                    direction = "row",
                    gap = 8,
                    children = {
                        QuickToggleTile({
                            icon = if is_dnd_active then "󰂛" else "󰂚",
                            label = "Não Perturbe",
                            sublabel = if is_dnd_active then "Ativado" else "Desativado",
                            active = is_dnd_active,
                            toggle_action = "quickstatus:toggle_dnd",
                            open_action = nil,
                        }),
                        QuickToggleTile({
                            icon = if is_night_active then "󰖔" else "󰖙",
                            label = "Luz Noturna",
                            sublabel = if is_night_active then "Quente (4500K)" else "Desativado",
                            active = is_night_active,
                            toggle_action = "quickstatus:toggle_night",
                            open_action = nil,
                        }),
                    }
                }),
                Zenith.Box({
                    direction = "row",
                    gap = 8,
                    children = {
                        QuickToggleTile({
                            icon = if is_gray_active then "󰈙" else "󰂲",
                            label = "Modo Leitura",
                            sublabel = if is_gray_active then "Monocromático" else "Padrão",
                            active = is_gray_active,
                            toggle_action = "quickstatus:toggle_grayscale",
                            open_action = nil,
                        }),
                        QuickToggleTile({
                            icon = if is_game_active then "󰊴" else "󰊵",
                            label = "Modo Jogo",
                            sublabel = if is_game_active then "Sem Animações" else "Normal",
                            active = is_game_active,
                            toggle_action = "quickstatus:toggle_gamemode",
                            open_action = nil,
                        }),
                    }
                }),
            }
        }),

        -- 3. Sliders (Volume & Brightness)
        Zenith.Box({
            direction = "column",
            gap = 10,
            padding = { x = 12, y = 10 },
            border_radius = 14,
            background = Zenith.hex(theme.surface_container, 130),
            border_color = Zenith.rgba(255, 255, 255, 12),
            border_width = 1,
            children = {
                -- Volume Slider Row
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 10,
                    children = {
                        Zenith.Box({
                            padding = { x = 6, y = 4 },
                            border_radius = 6,
                            on_click = "audio:toggle_mute",
                            children = {
                                Zenith.Text({
                                    text = if audio.muted then "󰖁" elseif audio.volume > 50 then "󰕾" else "󰕿",
                                    font_size = 15,
                                    color = if audio.muted then Zenith.hex("#e06c75") else Zenith.hex(theme.primary),
                                }),
                            }
                        }),
                        Zenith.Slider({
                            id = "cc_volume_slider",
                            value = audio.volume,
                            min = 0,
                            max = 100,
                            step = 1,
                            flex_grow = 1,
                            accent_color = theme.primary,
                            on_change = "audio:set_volume:",
                        }),
                        Zenith.Text({
                            text = math.floor(audio.volume) .. "%",
                            font_size = 11,
                            color = Zenith.hex(theme.on_surface),
                            width = 32,
                        }),
                    }
                }),
                -- Brightness Slider Row
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 10,
                    children = {
                        Zenith.Text({
                            text = "󰃟",
                            font_size = 15,
                            color = Zenith.hex(theme.primary),
                        }),
                        Zenith.Slider({
                            id = "cc_brightness_slider",
                            value = brightness.percent,
                            min = 5,
                            max = 100,
                            step = 1,
                            flex_grow = 1,
                            accent_color = theme.primary,
                            on_change = "brightness:set:",
                        }),
                        Zenith.Text({
                            text = math.floor(brightness.percent) .. "%",
                            font_size = 11,
                            color = Zenith.hex(theme.on_surface),
                            width = 32,
                        }),
                    }
                }),
            }
        }),

        -- 4. MPRIS Mini Media Player
        Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { x = 12, y = 10 },
            border_radius = 14,
            background = Zenith.hex(theme.surface_container, 130),
            border_color = Zenith.rgba(255, 255, 255, 12),
            border_width = 1,
            children = {
                Zenith.Box({
                    width = 38,
                    height = 38,
                    border_radius = 8,
                    background = Zenith.hex(theme.primary_container or theme.primary, 140),
                    align_items = "center",
                    justify_content = "center",
                    children = {
                        Zenith.Text({
                            text = "󰎈",
                            font_size = 18,
                            color = Zenith.hex(theme.on_primary or theme.primary),
                        }),
                    }
                }),
                Zenith.Box({ width = 10 }),
                Zenith.Box({
                    direction = "column",
                    flex_grow = 1,
                    children = {
                        Zenith.Text({
                            text = if media.title and #media.title > 0 then media.title else "Nenhuma mídia ativa",
                            font_size = 11,
                            font_weight = "bold",
                            color = Zenith.hex(theme.on_surface),
                        }),
                        Zenith.Text({
                            text = if media.artist and #media.artist > 0 then media.artist else "MPRIS daemon ocioso",
                            font_size = 9,
                            color = Zenith.hex(theme.outline),
                        }),
                    }
                }),
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 6,
                    children = {
                        Zenith.Box({
                            padding = { x = 6, y = 4 },
                            border_radius = 6,
                            on_click = "media:prev",
                            children = {
                                Zenith.Text({ text = "󰒮", font_size = 14, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        Zenith.Box({
                            width = 30,
                            height = 30,
                            border_radius = 15,
                            background = Zenith.hex(theme.primary),
                            align_items = "center",
                            justify_content = "center",
                            on_click = "media:play_pause",
                            children = {
                                Zenith.Text({
                                    text = if media.playing then "󰏤" else "󰐊",
                                    font_size = 12,
                                    color = Zenith.hex(theme.on_primary),
                                }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 6, y = 4 },
                            border_radius = 6,
                            on_click = "media:next",
                            children = {
                                Zenith.Text({ text = "󰒭", font_size = 14, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                    }
                })
            }
        }),

        -- 5. Battery & Power Profile Footer
        Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "space_between",
            padding = { x = 8, y = 4 },
            children = {
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 6,
                    children = {
                        Zenith.Text({
                            text = if battery.charging then "󰂄" elseif battery.percent > 80 then "󰁹" elseif battery.percent > 40 then "󰁾" else "󰁺",
                            font_size = 13,
                            color = if battery.percent < 20 then Zenith.hex("#e06c75") else Zenith.hex(theme.primary),
                        }),
                        Zenith.Text({
                            text = battery.percent .. "% " .. (if battery.charging then "(Carregando)" else ""),
                            font_size = 10,
                            color = Zenith.hex(theme.on_surface),
                        }),
                    }
                }),
                Zenith.Box({
                    direction = "row",
                    gap = 4,
                    children = {
                        Zenith.Box({
                            padding = { x = 8, y = 4 },
                            border_radius = 6,
                            background = if power.profile == "power-saver" then Zenith.hex(theme.primary, 180) else Zenith.hex(theme.surface_container, 140),
                            on_click = "power:set_profile:power-saver",
                            children = {
                                Zenith.Text({
                                    text = "󰌪 Eco",
                                    font_size = 9,
                                    color = if power.profile == "power-saver" then Zenith.hex(theme.on_primary) else Zenith.hex(theme.outline),
                                }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 8, y = 4 },
                            border_radius = 6,
                            background = if power.profile == "balanced" then Zenith.hex(theme.primary, 180) else Zenith.hex(theme.surface_container, 140),
                            on_click = "power:set_profile:balanced",
                            children = {
                                Zenith.Text({
                                    text = "󰗑 Bal",
                                    font_size = 9,
                                    color = if power.profile == "balanced" then Zenith.hex(theme.on_primary) else Zenith.hex(theme.outline),
                                }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 8, y = 4 },
                            border_radius = 6,
                            background = if power.profile == "performance" then Zenith.hex(theme.primary, 180) else Zenith.hex(theme.surface_container, 140),
                            on_click = "power:set_profile:performance",
                            children = {
                                Zenith.Text({
                                    text = "󰓅 Perf",
                                    font_size = 9,
                                    color = if power.profile == "performance" then Zenith.hex(theme.on_primary) else Zenith.hex(theme.outline),
                                }),
                            }
                        }),
                    }
                })
            }
        })
    }
})
