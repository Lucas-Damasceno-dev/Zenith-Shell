-- DynamicIsland: Reactive Floating Top Center Notch / Pill HUD (iOS / macOS style)
-- Reactively expands for incoming notifications, active media playback, and hardware alerts.

local theme = Zenith.Theme()
local time_str, date_str = Zenith.Services.time()
local media = Zenith.Services.Media()
local notifs = Zenith.Services.Notifications()
local bat = Zenith.Services.battery()

local island_children = {}

-- 1. High Priority: Desktop Notification active
if #notifs > 0 then
    local n = notifs[1]
    local truncated_summary = string.sub(n.summary or "Notification", 1, 26)
    local urgency_color = n.urgency == "critical" and Zenith.hex("#f38ba8") or theme.primary

    table.insert(island_children, Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space-between",
        flex_grow = 1,
        gap = 10,
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 8,
                children = {
                    Zenith.Text({
                        text = "󰂚",
                        font_size = 15,
                        font_family = "JetBrainsMono Nerd Font",
                        color = urgency_color,
                    }),
                    Zenith.Text({
                        text = truncated_summary,
                        font_size = 11,
                        font_weight = "bold",
                        color = theme.on_surface,
                    }),
                }
            }),
            Zenith.Box({
                padding = { x = 8, y = 3 },
                border_radius = 8,
                background = Zenith.hex("#ffffff12"),
                on_click = "notification:close:" .. tostring(n.id),
                children = {
                    Zenith.Text({
                        text = "󰅖",
                        font_size = 11,
                        font_family = "JetBrainsMono Nerd Font",
                        color = Zenith.hex("#a6accd"),
                    })
                }
            })
        }
    }))

-- 2. Medium Priority: Active Media Playing
elseif media.is_available and media.status == "Playing" then
    local title = media.title ~= "" and media.title or "Unknown Title"
    local artist = media.artist ~= "" and media.artist or "Unknown Artist"
    local marquee = string.sub(artist .. " — " .. title, 1, 28)

    table.insert(island_children, Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space-between",
        flex_grow = 1,
        gap = 8,
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 8,
                on_click = "cmd:zenith toggle MediaPopup &",
                children = {
                    Zenith.Text({
                        text = "󰎆",
                        font_size = 14,
                        font_family = "JetBrainsMono Nerd Font",
                        color = theme.primary,
                    }),
                    Zenith.Text({
                        text = marquee,
                        font_size = 11,
                        color = theme.on_surface,
                    }),
                }
            }),
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 6,
                children = {
                    Zenith.Box({
                        padding = { x = 6, y = 2 },
                        border_radius = 6,
                        background = Zenith.hex("#ffffff10"),
                        on_click = "media:prev",
                        children = {
                            Zenith.Text({
                                text = "󰒮",
                                font_size = 11,
                                font_family = "JetBrainsMono Nerd Font",
                                color = theme.on_surface,
                            })
                        }
                    }),
                    Zenith.Box({
                        padding = { x = 6, y = 2 },
                        border_radius = 6,
                        background = theme.primary,
                        on_click = "media:play-pause",
                        children = {
                            Zenith.Text({
                                text = "󰏤",
                                font_size = 11,
                                font_family = "JetBrainsMono Nerd Font",
                                color = theme.background,
                            })
                        }
                    }),
                    Zenith.Box({
                        padding = { x = 6, y = 2 },
                        border_radius = 6,
                        background = Zenith.hex("#ffffff10"),
                        on_click = "media:next",
                        children = {
                            Zenith.Text({
                                text = "󰒭",
                                font_size = 11,
                                font_family = "JetBrainsMono Nerd Font",
                                color = theme.on_surface,
                            })
                        }
                    }),
                }
            })
        }
    }))

-- 3. Default Idle State: Clock + Battery / System Badge
else
    local bat_str = bat and (tostring(bat.percentage) .. "%") or "AC"
    local bat_icon = bat and (bat.is_charging and "󰂄" or "󰁹") or "󰚥"

    table.insert(island_children, Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space-between",
        flex_grow = 1,
        on_click = "cmd:zenith toggle Launcher &",
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 6,
                children = {
                    Zenith.Text({
                        text = "󰥔",
                        font_size = 13,
                        font_family = "JetBrainsMono Nerd Font",
                        color = theme.primary,
                    }),
                    Zenith.Text({
                        text = time_str,
                        font_size = 12,
                        font_weight = "bold",
                        color = theme.on_surface,
                    }),
                }
            }),
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 6,
                padding = { x = 8, y = 3 },
                border_radius = 10,
                background = Zenith.hex("#ffffff0c"),
                children = {
                    Zenith.Text({
                        text = bat_icon,
                        font_size = 12,
                        font_family = "JetBrainsMono Nerd Font",
                        color = theme.primary,
                    }),
                    Zenith.Text({
                        text = bat_str,
                        font_size = 11,
                        color = theme.on_surface,
                    }),
                }
            })
        }
    }))
end

return Zenith.Box({
    direction = "row",
    align_items = "center",
    justify_content = "center",
    padding = { x = 14, y = 6 },
    border_radius = 24,
    background = Zenith.hex("#161922f0"),
    border_color = theme.outline,
    border_width = 1,
    shadow = {
        blur = 20,
        color = Zenith.hex("#00000088"),
        offset_y = 4,
    },
    children = island_children,
})
