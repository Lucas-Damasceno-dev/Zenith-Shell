--!strict
-- Zenith-Shell (Engine v2) - Fullscreen Lock Screen Overlay (ext-session-lock style)
-- Provides ambient biometric/password screen locker with clock, media, and power controls.

local theme = Zenith.Theme()
local time_str, date_str = Zenith.Services.time()
local weather = Zenith.Services.Weather()
local bat = Zenith.Services.battery()
local mpris = (Zenith.Services.Media and Zenith.Services.Media()) or { title = "", artist = "", status = "" }

local user_name = (Zenith.user and Zenith.user()) or "Zenith User"
local query = Zenith.get_search_query()
local pass_display = if #query > 0 then (string.rep("● ", #query) .. "▎") else "Enter password to unlock...▎"
local pass_color = if #query > 0 then Zenith.hex(theme.primary) else Zenith.rgba(255, 255, 255, 120)

local scr = (Zenith.Services.Screen and Zenith.Services.Screen()) or { width = 1366, height = 768 }
local screen_w = (scr.width and scr.width > 0) and scr.width or 1366
local screen_h = (scr.height and scr.height > 0) and scr.height or 768

return Zenith.Window({
    direction = "column",
    width = screen_w,
    height = screen_h,
    background = Zenith.rgba(12, 14, 20, 245),
    padding = { x = 60, y = 50 },
    children = {
        -- Top bar: status indicators
        Zenith.Box({
            direction = "row",
            align_items = "center",
            children = {
                Zenith.Box({
                    direction = "row",
                    gap = 8,
                    align_items = "center",
                    children = {
                        Zenith.Text({
                            text = "",
                            font_size = 14,
                            color = Zenith.hex(theme.primary),
                        }),
                        Zenith.Text({
                            text = "SECURE SESSION",
                            font_size = 11,
                            font_weight = "bold",
                            color = Zenith.rgba(255, 255, 255, 180),
                        }),
                    }
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    direction = "row",
                    gap = 14,
                    align_items = "center",
                    children = {
                        Zenith.Text({
                            text = string.format("%s %.0f°C", weather.icon, weather.temp),
                            font_size = 12,
                            color = Zenith.rgba(255, 255, 255, 200),
                        }),
                        Zenith.Text({
                            text = bat and string.format("󰂂 %d%%", bat.percentage) or "󰚥 AC",
                            font_size = 12,
                            color = Zenith.rgba(255, 255, 255, 200),
                        }),
                    }
                }),
            }
        }),

        Zenith.Box({ flex_grow = 1 }),

        -- Center: Clock, User Avatar, Password / Unlock Prompt
        Zenith.Box({
            direction = "column",
            align_items = "center",
            gap = 20,
            children = {
                -- Large Digital Clock
                Zenith.Text({
                    text = time_str,
                    font_size = 80,
                    font_weight = "bold",
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Text({
                    text = date_str,
                    font_size = 20,
                    color = Zenith.rgba(255, 255, 255, 220),
                }),

                -- User Profile Card
                Zenith.Box({
                    direction = "column",
                    align_items = "center",
                    gap = 10,
                    padding = { x = 32, y = 24 },
                    border_radius = 20,
                    background = Zenith.rgba(255, 255, 255, 8),
                    border_color = Zenith.rgba(255, 255, 255, 20),
                    border_width = 1,
                    shadow = {
                        blur = 30,
                        color = Zenith.rgba(0, 0, 0, 160),
                        offset_y = 12,
                    },
                    children = {
                        -- Avatar icon circle
                        Zenith.Box({
                            width = 64,
                            height = 64,
                            border_radius = 32,
                            background = Zenith.hex(theme.primary_container),
                            border_color = Zenith.hex(theme.primary),
                            border_width = 2,
                            align_items = "center",
                            justify_content = "center",
                            children = {
                                Zenith.Text({
                                    text = "",
                                    font_size = 28,
                                    color = Zenith.hex(theme.primary),
                                }),
                            }
                        }),
                        Zenith.Text({
                            text = user_name,
                            font_size = 16,
                            font_weight = "bold",
                            color = Zenith.rgba(255, 255, 255, 240),
                        }),

                        -- Password / Unlock Entry Box
                        Zenith.Box({
                            direction = "row",
                            align_items = "center",
                            gap = 12,
                            padding = { x = 16, y = 10 },
                            border_radius = 12,
                            background = Zenith.rgba(0, 0, 0, 140),
                            border_color = Zenith.hex(theme.primary),
                            border_width = 1,
                            children = {
                                Zenith.Text({
                                    text = "󰌌",
                                    font_size = 14,
                                    color = Zenith.hex(theme.primary),
                                }),
                                Zenith.Text({
                                    text = pass_display,
                                    font_size = 14,
                                    color = pass_color,
                                }),
                                Zenith.Box({
                                    padding = { x = 10, y = 4 },
                                    border_radius = 8,
                                    background = Zenith.hex(theme.primary),
                                    on_click = "lock:unlock",
                                    children = {
                                        Zenith.Text({
                                            text = "Unlock 󰁔",
                                            font_size = 11,
                                            font_weight = "bold",
                                            color = Zenith.hex(theme.on_primary),
                                        }),
                                    }
                                }),
                            }
                        }),
                    }
                }),

                -- Optional Ambient MPRIS Mini Card
                (#mpris.title > 0) and Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 12,
                    padding = { x = 16, y = 8 },
                    border_radius = 12,
                    background = Zenith.rgba(255, 255, 255, 10),
                    children = {
                        Zenith.Text({
                            text = (mpris.status == "Playing") and "󰐊" or "󰏤",
                            font_size = 14,
                            color = Zenith.hex(theme.primary),
                        }),
                        Zenith.Text({
                            text = string.format("%s - %s", mpris.artist, mpris.title),
                            font_size = 12,
                            color = Zenith.rgba(255, 255, 255, 200),
                        }),
                    }
                }) or nil,
            }
        }),

        Zenith.Box({ flex_grow = 1 }),

        -- Bottom Bar: Controls & Actions
        Zenith.Box({
            direction = "row",
            align_items = "center",
            children = {
                Zenith.Text({
                    text = "󰌌 Type password and press Enter or click Unlock to return to desktop session",
                    font_size = 11,
                    color = Zenith.rgba(255, 255, 255, 140),
                }),
                Zenith.Box({ flex_grow = 1 }),
                -- Power management actions
                Zenith.Box({
                    direction = "row",
                    gap = 12,
                    children = {
                        Zenith.Box({
                            padding = { x = 12, y = 8 },
                            border_radius = 10,
                            background = Zenith.rgba(255, 255, 255, 10),
                            on_click = "cmd:systemctl suspend",
                            children = {
                                Zenith.Text({ text = "󰒲 Sleep", font_size = 11, color = Zenith.rgba(255, 255, 255, 200) }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 12, y = 8 },
                            border_radius = 10,
                            background = Zenith.rgba(255, 255, 255, 10),
                            on_click = "cmd:systemctl reboot",
                            children = {
                                Zenith.Text({ text = "󰑐 Reboot", font_size = 11, color = Zenith.rgba(255, 255, 255, 200) }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 12, y = 8 },
                            border_radius = 10,
                            background = Zenith.rgba(224, 108, 117, 30),
                            border_color = Zenith.hex("#e06c75"),
                            border_width = 1,
                            on_click = "cmd:systemctl poweroff",
                            children = {
                                Zenith.Text({ text = "󰐥 Power Off", font_size = 11, color = Zenith.hex("#e06c75") }),
                            }
                        }),
                    }
                }),
            }
        }),
    }
})
