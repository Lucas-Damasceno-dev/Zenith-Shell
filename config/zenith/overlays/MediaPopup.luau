--!strict
-- Zenith-Shell (Engine v2) - MPRIS2 Media Player Control Overlay

local theme = Zenith.Theme()
local Store = Zenith.import("settings_store")
local media = Zenith.Services.Media()
local audio = Zenith.Services.audio()
local show_lyrics = Store.get("mediaShowLyrics") or false

local is_playing = media.status == "Playing"
local play_icon = is_playing and "󰏤" or "󰐊"
local status_color = is_playing and Zenith.hex(theme.primary) or Zenith.hex(theme.outline)

local title_text = (#media.title > 0) and media.title or "No Track Playing"
local artist_text = (#media.artist > 0) and media.artist or "Unknown Artist"
local album_text = (#media.album > 0) and media.album or "Unknown Album"
local player_label = (#media.player_name > 0) and media.player_name:upper() or "MEDIA"

local total_secs = media.length_seconds or 0
local total_min = math.floor(total_secs / 60)
local total_sec_rem = total_secs % 60
local duration_str = string.format("%02d:%02d", total_min, total_sec_rem)

return Zenith.Window({
    direction = "column",
    width = 360,
    height = 360,
    padding = { x = 16, y = 14 },
    gap = 12,
    background = Zenith.hex(theme.surface, 235),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
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

        -- Track Progress Bar / Slider
        Zenith.Box({
            direction = "column",
            gap = 4,
            children = {
                Zenith.Slider({
                    id = "media_progress_slider",
                    min = 0,
                    max = math.max(10, total_secs),
                    value = math.min(total_secs, math.floor(total_secs * 0.35)),
                    track_height = 4,
                    thumb_radius = 5,
                    track_color = Zenith.rgba(255, 255, 255, 30),
                    active_track_color = Zenith.hex(theme.primary),
                    thumb_color = Zenith.hex("#ffffff"),
                }),
                Zenith.Box({
                    direction = "row",
                    justify_content = "space-between",
                    children = {
                        Zenith.Text({
                            text = "00:00",
                            font_size = 9,
                            color = Zenith.hex(theme.outline),
                        }),
                        Zenith.Text({
                            text = duration_str,
                            font_size = 9,
                            color = Zenith.hex(theme.outline),
                        }),
                    }
                }),
            }
        }),

        -- Volume Slider Row
        Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 8,
            children = {
                Zenith.Text({
                    text = "󰕾",
                    font_size = 13,
                    color = Zenith.hex(theme.outline),
                }),
                Zenith.Box({
                    flex_grow = 1,
                    children = {
                        Zenith.Slider({
                            id = "media_volume_slider",
                            min = 0,
                            max = 100,
                            value = audio.volume or 50,
                            track_height = 5,
                            thumb_radius = 6,
                            track_color = Zenith.rgba(255, 255, 255, 25),
                            active_track_color = Zenith.hex(theme.primary),
                            thumb_color = Zenith.hex("#ffffff"),
                            on_change = function(new_val)
                                local v = math.floor(tonumber(new_val) or 0)
                                Zenith.Services.SetVolume(v)
                            end,
                        }),
                    }
                }),
                Zenith.Text({
                    text = string.format("%d%%", audio.volume or 0),
                    font_size = 10,
                    color = Zenith.hex(theme.outline),
                }),
            }
        }),

        -- Lyrics Toggle Switch Row
        Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "space-between",
            padding = { x = 6, y = 2 },
            children = {
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 8,
                    children = {
                        Zenith.Text({
                            text = "󰎈",
                            font_size = 13,
                            color = show_lyrics and Zenith.hex(theme.primary) or Zenith.hex(theme.outline),
                        }),
                        Zenith.Text({
                            text = "Modo Letras / Karaokê",
                            font_size = 10,
                            color = Zenith.hex(theme.on_surface),
                        }),
                    }
                }),
                Zenith.Switch({
                    id = "switch_media_lyrics",
                    checked = show_lyrics,
                    active_color = theme.primary,
                    on_toggle = "storage:toggle:mediaShowLyrics",
                }),
            }
        }),
    }
})
