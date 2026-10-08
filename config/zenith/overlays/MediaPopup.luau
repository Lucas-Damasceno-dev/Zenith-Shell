--!strict
-- Zenith-Shell (Engine v2) - MPRIS2 Media Player Control Overlay

local theme = Zenith.Theme()
local media = Zenith.Services.Media()

local is_playing = media.status == "Playing"
local play_icon = is_playing and "󰏤" or "󰐊"
local status_color = is_playing and Zenith.hex(theme.primary) or Zenith.hex(theme.outline)

local title_text = (#media.title > 0) and media.title or "No Track Playing"
local artist_text = (#media.artist > 0) and media.artist or "Unknown Artist"
local album_text = (#media.album > 0) and media.album or "Unknown Album"
local player_label = (#media.player_name > 0) and media.player_name:upper() or "MEDIA"

return Zenith.Window({
    direction = "column",
    width = 340,
    height = 240,
    padding = { x = 16, y = 14 },
    gap = 12,
    background = Zenith.rgba(18, 20, 26, 225),
    border_color = Zenith.hex(theme.primary),
    border_width = 1,
    border_radius = 16,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 20,
        offset_x = 0,
        offset_y = 8,
    },
    children = {
        -- Header: Player identity + Close button
        Zenith.Box({
            direction = "row",
            children = {
                Zenith.Text({
                    text = "󰎆 " .. player_label,
                    font_size = 12,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 8, y = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "✕", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            }
        }),

        -- Track Information Card
        Zenith.Box({
            direction = "column",
            gap = 4,
            padding = { x = 12, y = 10 },
            border_radius = 10,
            background = Zenith.hex(theme.surface),
            border_color = Zenith.hex("#2a2e3d"),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = title_text,
                    font_size = 14,
                    color = Zenith.hex(theme.on_surface),
                }),
                Zenith.Text({
                    text = artist_text,
                    font_size = 12,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Text({
                    text = album_text,
                    font_size = 10,
                    color = Zenith.hex(theme.outline),
                }),
            }
        }),

        -- Transport Controls Bar
        Zenith.Box({
            direction = "row",
            gap = 10,
            children = {
                -- Previous Track
                Zenith.Box({
                    flex_grow = 1,
                    padding = { x = 8, y = 10 },
                    border_radius = 8,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "media:previous",
                    children = {
                        Zenith.Text({ text = "󰒮 Prev", font_size = 12, color = Zenith.hex(theme.on_surface) })
                    }
                }),

                -- Play / Pause
                Zenith.Box({
                    flex_grow = 1,
                    padding = { x = 8, y = 10 },
                    border_radius = 8,
                    background = is_playing and Zenith.hex(theme.primary) or Zenith.hex(theme.surface_container),
                    on_click = "media:play-pause",
                    children = {
                        Zenith.Text({
                            text = play_icon .. " " .. (is_playing and "Pause" or "Play"),
                            font_size = 12,
                            color = is_playing and Zenith.hex(theme.on_primary) or Zenith.hex(theme.on_surface),
                        })
                    }
                }),

                -- Next Track
                Zenith.Box({
                    flex_grow = 1,
                    padding = { x = 8, y = 10 },
                    border_radius = 8,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "media:next",
                    children = {
                        Zenith.Text({ text = "Next 󰒭", font_size = 12, color = Zenith.hex(theme.on_surface) })
                    }
                }),
            }
        }),
    }
})
