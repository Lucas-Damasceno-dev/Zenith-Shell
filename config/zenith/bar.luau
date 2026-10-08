--!strict
-- Zenith-Shell (Engine v2) - Declarative Status Bar Configuration
-- Replicating Quickshell Bar layout: Left (Launcher + Workspaces + App), Center (Clock/Date), Right (Hardware + Status)
-- Dynamic Material You Theming via Matugen / Stylix

local theme = Zenith.Theme()
local time_str, date_str = Zenith.Services.time()
local mem = Zenith.Services.memory()
local compositor = Zenith.Services.compositor()
local battery = Zenith.Services.battery()
local audio = Zenith.Services.audio()
local net = Zenith.Services.network()
local cpu = Zenith.Services.cpu()



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

-- Primary accent color from current wallpaper Matugen palette
local c_bg = Zenith.hex(theme.background)
local c_primary = Zenith.hex(theme.primary)
local c_surface = Zenith.hex(theme.surface)
local c_surface_container = Zenith.hex(theme.surface_container)
local c_outline = Zenith.hex(theme.outline)
local c_on_surface = Zenith.hex(theme.on_surface)
local c_on_primary = Zenith.hex(theme.on_primary)

return Zenith.Box({
    direction = "row",
    height = 38,
    padding = { x = 14, y = 4 },
    gap = 8,
    background = c_bg,
    border_color = Zenith.hex("#252c38"),
    border_width = 1,
    children = {
        -- ═════════════════════════════════════════════════════════════
        -- 1. LEFT CLUSTER: Launcher + Workspaces + Active App
        -- ═════════════════════════════════════════════════════════════
        -- NixOS Launcher Pill (Interactive)
        Zenith.Box({
            padding = { x = 12, y = 4 },
            border_radius = 8,
            background = c_primary,
            on_click = "cmd:notify-send 'Zenith Shell' 'Launcher clicked!' -i preferences-system",
            children = {
                Zenith.Text({
                    text = "󱄅 NixOS",
                    font_size = 11,
                    color = c_on_primary,
                })
            }
        }),


        -- Workspace Indicator Cluster
        Zenith.Box({
            direction = "row",
            gap = 3,
            padding = { x = 4, y = 3 },
            border_radius = 8,
            background = c_surface,
            border_color = Zenith.hex("#2d3748"),
            border_width = 1,
            children = {
                Zenith.Box({
                    padding = { x = 8, y = 2 },
                    border_radius = 6,
                    background = c_primary,
                    children = {
                        Zenith.Text({
                            text = "1 ",
                            font_size = 10,
                            color = c_on_primary,
                        })
                    }
                }),
                Zenith.Box({
                    padding = { x = 7, y = 2 },
                    border_radius = 6,
                    background = c_surface_container,
                    children = {
                        Zenith.Text({
                            text = "2 ",
                            font_size = 10,
                            color = c_on_surface,
                        })
                    }
                }),
                Zenith.Box({
                    padding = { x = 7, y = 2 },
                    border_radius = 6,
                    background = c_surface_container,
                    children = {
                        Zenith.Text({
                            text = "3 ",
                            font_size = 10,
                            color = c_on_surface,
                        })
                    }
                }),
                Zenith.Box({
                    padding = { x = 6, y = 2 },
                    border_radius = 6,
                    background = Zenith.hex("#00000000"),
                    children = {
                        Zenith.Text({
                            text = "4",
                            font_size = 10,
                            color = Zenith.hex("#6c757d"),
                        })
                    }
                }),
            }
        }),

        -- Focused App Pill
        Zenith.Box({
            padding = { x = 10, y = 4 },
            border_radius = 8,
            background = c_surface,
            border_color = Zenith.hex("#2d3748"),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = " kitty : dev@nixos",
                    font_size = 11,
                    color = c_on_surface,
                })
            }
        }),

        -- Flexible Spacer (Left -> Center)
        Zenith.Box({
            flex_grow = 1,
        }),

        -- ═════════════════════════════════════════════════════════════
        -- 2. CENTER CLUSTER: Media + Clock Pill
        -- ═════════════════════════════════════════════════════════════
        Zenith.Box({
            direction = "row",
            gap = 6,
            children = {
                Zenith.Box({
                    padding = { x = 10, y = 4 },
                    border_radius = 8,
                    background = c_surface,
                    border_color = Zenith.hex("#2d3748"),
                    border_width = 1,
                    children = {
                        Zenith.Text({
                            text = "󰎆 Spotify: Playing...",
                            font_size = 11,
                            color = c_primary,
                        })
                    }
                }),

                Zenith.Box({
                    padding = { x = 12, y = 4 },
                    border_radius = 8,
                    background = c_surface_container,
                    border_color = c_primary,
                    border_width = 1,
                    children = {
                        Zenith.Text({
                            text = string.format("󰃭 %s  •   %s", date_str, time_str),
                            font_size = 11,
                            color = c_primary,
                        })
                    }
                }),
            }
        }),

        -- Flexible Spacer (Center -> Right)
        Zenith.Box({
            flex_grow = 1,
        }),

        -- ═════════════════════════════════════════════════════════════
        -- 3. RIGHT CLUSTER: Hardware Monitors + Status + Quick Settings
        -- ═════════════════════════════════════════════════════════════
        Zenith.Box({
            direction = "row",
            gap = 6,
            padding = { x = 10, y = 4 },
            border_radius = 8,
            background = c_surface,
            border_color = Zenith.hex("#2d3748"),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = string.format(" CPU: %d%%  •  󰍛 RAM: %dMB (%d%%)", cpu.percent, mem.used_mb, mem.percent),
                    font_size = 11,
                    color = c_on_surface,
                })
            }
        }),

        Zenith.Box({
            direction = "row",
            gap = 8,
            padding = { x = 10, y = 4 },
            border_radius = 8,
            background = c_surface,
            border_color = Zenith.hex("#2d3748"),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = net.is_connected and (net.type == "wifi" and "󰖩 " .. net.ssid or "󰈀 Wired") or "󰤭 Disconnected",
                    font_size = 11,
                    color = c_on_surface,
                }),
                Zenith.Text({
                    text = audio.is_muted and "󰝟 Muted" or string.format(" %d%%", audio.volume),
                    font_size = 11,
                    color = c_on_surface,
                }),
            }
        }),


        Zenith.Box({
            padding = { x = 8, y = 4 },
            border_radius = 8,
            background = c_surface_container,
            children = {
                Zenith.Text({
                    text = string.format("%s %d%%", bat_icon, bat_pct),
                    font_size = 11,
                    color = c_primary,
                })
            }
        }),

        Zenith.Box({
            padding = { x = 10, y = 4 },
            border_radius = 8,
            background = Zenith.hex("#e63946"),
            on_click = "cmd:notify-send 'Zenith Shell' 'Power menu triggered' -u critical",
            children = {
                Zenith.Text({
                    text = "⏻",
                    font_size = 12,
                    color = Zenith.hex("#FFFFFF"),
                })
            }
        }),

    }
})


