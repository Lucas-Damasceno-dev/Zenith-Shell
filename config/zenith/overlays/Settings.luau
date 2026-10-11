--!strict
-- Zenith-Shell (Engine v2) - Settings & Customization Hub Overlay
-- Modeled after iNiR configuration architecture for universal shell customization

local theme = Zenith.Theme()
local audio = Zenith.Services.audio()
local battery = Zenith.Services.battery()
local net = Zenith.Services.network()
local is_dnd = Zenith.Services.IsDND()
local is_rec = Zenith.Services.IsRecording()

local bat_pct = if battery then battery.percentage else 100
local bat_status = if battery and battery.is_charging then "Charging" else "Discharging"
local vol_pct = if audio then audio.volume else 50
local net_name = if net and (net.is_connected or net.connected) then (if #net.ssid > 0 then net.ssid else "Ethernet") else "Offline"

return Zenith.Window({
    direction = "column",
    width = 720,
    height = 540,
    padding = { x = 20, y = 16 },
    gap = 14,
    background = Zenith.rgba(18, 20, 26, 235),
    border_color = Zenith.hex(theme.primary),
    border_width = 1,
    border_radius = 16,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 200),
        blur = 28,
        offset_x = 0,
        offset_y = 8,
    },
    children = {
        -- 1. HEADER: Title + Subtitle + Close Button
        Zenith.Box({
            direction = "row",
            children = {
                Zenith.Box({
                    direction = "column",
                    gap = 2,
                    children = {
                        Zenith.Box({
                            direction = "row",
                            gap = 8,
                            children = {
                                Zenith.Text({
                                    text = "󰒓 Zenith Shell Settings",
                                    font_size = 16,
                                    color = Zenith.hex(theme.primary),
                                }),
                                Zenith.Box({
                                    padding = { x = 6, y = 1 },
                                    border_radius = 4,
                                    background = Zenith.rgba(122, 162, 247, 30),
                                    children = {
                                        Zenith.Text({
                                            text = "v2.0-engine",
                                            font_size = 9,
                                            color = Zenith.hex(theme.primary),
                                        })
                                    }
                                })
                            }
                        }),
                        Zenith.Text({
                            text = "Centralized desktop customization hub & system control",
                            font_size = 11,
                            color = Zenith.hex(theme.outline),
                        }),
                    }
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 10, y = 4 },
                    border_radius = 8,
                    background = Zenith.hex(theme.surface_container),
                    border_color = Zenith.rgba(255, 255, 255, 15),
                    border_width = 1,
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({
                            text = "✕ Close",
                            font_size = 11,
                            color = Zenith.hex(theme.on_surface),
                        }),
                    }
                }),
            }
        }),

        -- 2. QUICK ACTIONS & ESSENTIALS CARD (iNiR Quick Page)
        Zenith.Box({
            direction = "column",
            gap = 8,
            padding = { x = 14, y = 12 },
            border_radius = 12,
            background = Zenith.rgba(255, 255, 255, 8),
            border_color = Zenith.rgba(255, 255, 255, 14),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = "󰍜 QUICK TOGGLES & ESSENTIALS",
                    font_size = 10,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({
                    direction = "row",
                    gap = 8,
                    children = {
                        -- Random Wallpaper
                        Zenith.Box({
                            flex_grow = 1,
                            padding = { x = 10, y = 8 },
                            border_radius = 8,
                            background = Zenith.hex(theme.surface),
                            on_click = "cmd:~/.config/hypr/scripts/random-wallpaper.sh",
                            children = {
                                Zenith.Text({ text = "󰸉 Next Wallpaper", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        -- Focus / DND
                        Zenith.Box({
                            flex_grow = 1,
                            padding = { x = 10, y = 8 },
                            border_radius = 8,
                            background = is_dnd and Zenith.rgba(122, 162, 247, 40) or Zenith.hex(theme.surface),
                            on_click = "notification:toggle_dnd",
                            children = {
                                Zenith.Text({ text = is_dnd and "󰂛 DND Active" or "󰂚 Enable DND", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        -- Screen Snipping
                        Zenith.Box({
                            flex_grow = 1,
                            padding = { x = 10, y = 8 },
                            border_radius = 8,
                            background = Zenith.hex(theme.surface),
                            on_click = "screenshot:area",
                            children = {
                                Zenith.Text({ text = "󰄀 Snip Screenshot", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        -- Screen Recording
                        Zenith.Box({
                            flex_grow = 1,
                            padding = { x = 10, y = 8 },
                            border_radius = 8,
                            background = is_rec and Zenith.rgba(224, 108, 117, 60) or Zenith.hex(theme.surface),
                            on_click = "record:toggle",
                            children = {
                                Zenith.Text({ text = is_rec and "󰻃 Stop Recording" or "󰻂 Start Recording", font_size = 11, color = is_rec and Zenith.hex("#ffffff") or Zenith.hex(theme.on_surface) }),
                            }
                        }),
                    }
                })
            }
        }),

        -- 3. SYSTEM & HARDWARE STATUS (Audio, Battery, Network)
        Zenith.Box({
            direction = "row",
            gap = 10,
            children = {
                -- Power & Battery Profile
                Zenith.Box({
                    flex_grow = 1,
                    direction = "column",
                    gap = 8,
                    padding = { x = 14, y = 12 },
                    border_radius = 12,
                    background = Zenith.rgba(255, 255, 255, 8),
                    border_color = Zenith.rgba(255, 255, 255, 14),
                    border_width = 1,
                    children = {
                        Zenith.Text({
                            text = "󰁹 POWER PROFILE & BATTERY",
                            font_size = 10,
                            color = Zenith.hex(theme.primary),
                        }),
                        Zenith.Text({
                            text = string.format("Battery: %d%% (%s)", bat_pct, bat_status),
                            font_size = 12,
                            color = Zenith.hex(theme.on_surface),
                        }),
                        Zenith.Box({
                            direction = "row",
                            gap = 6,
                            children = {
                                Zenith.Box({
                                    padding = { x = 8, y = 4 },
                                    border_radius = 6,
                                    background = Zenith.hex(theme.surface),
                                    on_click = "cmd:powerprofilesctl set power-saver",
                                    children = { Zenith.Text({ text = "Saver", font_size = 10, color = Zenith.hex(theme.on_surface) }) }
                                }),
                                Zenith.Box({
                                    padding = { x = 8, y = 4 },
                                    border_radius = 6,
                                    background = Zenith.hex(theme.surface),
                                    on_click = "cmd:powerprofilesctl set balanced",
                                    children = { Zenith.Text({ text = "Balanced", font_size = 10, color = Zenith.hex(theme.on_surface) }) }
                                }),
                                Zenith.Box({
                                    padding = { x = 8, y = 4 },
                                    border_radius = 6,
                                    background = Zenith.hex(theme.surface),
                                    on_click = "cmd:powerprofilesctl set performance",
                                    children = { Zenith.Text({ text = "Perf", font_size = 10, color = Zenith.hex("#e06c75") }) }
                                }),
                            }
                        })
                    }
                }),

                -- Audio & Connectivity
                Zenith.Box({
                    flex_grow = 1,
                    direction = "column",
                    gap = 8,
                    padding = { x = 14, y = 12 },
                    border_radius = 12,
                    background = Zenith.rgba(255, 255, 255, 8),
                    border_color = Zenith.rgba(255, 255, 255, 14),
                    border_width = 1,
                    children = {
                        Zenith.Text({
                            text = "󰓃 AUDIO & CONNECTIVITY",
                            font_size = 10,
                            color = Zenith.hex(theme.primary),
                        }),
                        Zenith.Text({
                            text = string.format("Volume: %d%% | Network: %s", vol_pct, net_name),
                            font_size = 12,
                            color = Zenith.hex(theme.on_surface),
                        }),
                        Zenith.Box({
                            direction = "row",
                            gap = 6,
                            children = {
                                Zenith.Box({
                                    padding = { x = 8, y = 4 },
                                    border_radius = 6,
                                    background = Zenith.hex(theme.surface),
                                    on_click = "cmd:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
                                    children = { Zenith.Text({ text = "Vol +5%", font_size = 10, color = Zenith.hex(theme.on_surface) }) }
                                }),
                                Zenith.Box({
                                    padding = { x = 8, y = 4 },
                                    border_radius = 6,
                                    background = Zenith.hex(theme.surface),
                                    on_click = "cmd:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
                                    children = { Zenith.Text({ text = "Vol -5%", font_size = 10, color = Zenith.hex(theme.on_surface) }) }
                                }),
                                Zenith.Box({
                                    padding = { x = 8, y = 4 },
                                    border_radius = 6,
                                    background = Zenith.hex(theme.surface),
                                    on_click = "popup:toggle:NetworkPopup",
                                    children = { Zenith.Text({ text = "Wi-Fi Hub", font_size = 10, color = Zenith.hex(theme.primary) }) }
                                }),
                            }
                        })
                    }
                }),
            }
        }),

        -- 4. HYPRLAND COMPOSITOR & WINDOW MANAGEMENT
        Zenith.Box({
            direction = "column",
            gap = 8,
            padding = { x = 14, y = 12 },
            border_radius = 12,
            background = Zenith.rgba(255, 255, 255, 8),
            border_color = Zenith.rgba(255, 255, 255, 14),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = "󰖲 HYPRLAND COMPOSITOR & TILING",
                    font_size = 10,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({
                    direction = "row",
                    gap = 8,
                    children = {
                        Zenith.Box({
                            flex_grow = 1,
                            padding = { x = 10, y = 8 },
                            border_radius = 8,
                            background = Zenith.hex(theme.surface),
                            on_click = "cmd:~/.config/hypr/scripts/cycle_layout.sh",
                            children = {
                                Zenith.Text({ text = "󰕰 Cycle Layout", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        Zenith.Box({
                            flex_grow = 1,
                            padding = { x = 10, y = 8 },
                            border_radius = 8,
                            background = Zenith.hex(theme.surface),
                            on_click = "cmd:~/.config/hypr/scripts/center_window.sh",
                            children = {
                                Zenith.Text({ text = "󰨃 Center Window", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        Zenith.Box({
                            flex_grow = 1,
                            padding = { x = 10, y = 8 },
                            border_radius = 8,
                            background = Zenith.hex(theme.surface),
                            on_click = "cmd:~/.config/hypr/scripts/gamemode.sh",
                            children = {
                                Zenith.Text({ text = "󰊴 Game Mode", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        Zenith.Box({
                            flex_grow = 1,
                            padding = { x = 10, y = 8 },
                            border_radius = 8,
                            background = Zenith.hex(theme.surface),
                            on_click = "cmd:~/.config/hypr/scripts/emergency_reset.sh",
                            children = {
                                Zenith.Text({ text = "󰁨 Reset Window Rules", font_size = 11, color = Zenith.hex("#e06c75") }),
                            }
                        }),
                    }
                })
            }
        }),

        -- 5. ADVANCED & SHELL MAINTENANCE
        Zenith.Box({
            direction = "row",
            gap = 8,
            children = {
                Zenith.Box({
                    flex_grow = 1,
                    padding = { x = 10, y = 8 },
                    border_radius = 8,
                    background = Zenith.hex(theme.primary),
                    on_click = "cmd:zenith reload",
                    children = {
                        Zenith.Text({ text = "󰑐 Instant Hot-Reload Shell", font_size = 11, color = Zenith.hex(theme.on_primary) }),
                    }
                }),
                Zenith.Box({
                    flex_grow = 1,
                    padding = { x = 10, y = 8 },
                    border_radius = 8,
                    background = Zenith.hex(theme.surface),
                    on_click = "cmd:~/.config/hypr/scripts/system_diagnose.sh",
                    children = {
                        Zenith.Text({ text = "󰒋 Run System Diagnostics", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            }
        })
    }
})
