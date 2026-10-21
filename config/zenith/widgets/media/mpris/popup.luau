--!strict
-- Zenith-Shell: MPRIS2 Media Player Popup Control

local Store = Zenith.import("core/store")
local Services = Zenith.import("core/services/init")
local Theme = Zenith.import("core/theme")

local function MediaPopup()
    local theme = Theme.get()
    local media = Services.Mpris.snapshot()
    local audio = Services.Audio.status()
    local show_lyrics = Store.get("mediaShowLyrics") or false

    local is_playing = media.status == "Playing"
    local play_icon = if is_playing then "󰏤" else "󰐊"

    local raw_title = media.title or ""
    local raw_artist = media.artist or ""
    local raw_album = media.album or ""
    local raw_player = media.player_name or ""

    local title_text = if #raw_title > 0 then raw_title else "Nenhuma música em reprodução"
    local artist_text = if #raw_artist > 0 then raw_artist else "Artista desconhecido"
    local album_text = if #raw_album > 0 then raw_album else "Álbum desconhecido"
    local player_raw = if #raw_player > 0 then raw_player else "MPRIS"

    local player_lower = player_raw:lower()
    local player_icon = if player_lower:find("spotify") then "󰓇"
        elseif player_lower:find("brave") or player_lower:find("chrome") or player_lower:find("firefox") then "󰖟"
        elseif player_lower:find("vlc") or player_lower:find("mpv") then "󰎆"
        else "󰎆"

    local total_secs = media.length or 0
    local total_min = math.floor(total_secs / 60)
    local total_sec_rem = total_secs % 60
    local duration_str = string.format("%02d:%02d", total_min, total_sec_rem)

    local current_secs = media.position or 0
    if current_secs == 0 and Zenith.Storage and Zenith.Storage.get then
        current_secs = tonumber(Zenith.Storage.get("media_current_pos", 0)) or 0
    end
    if current_secs > total_secs and total_secs > 0 then
        current_secs = total_secs
    end
    local cur_min = math.floor(current_secs / 60)
    local cur_sec_rem = current_secs % 60
    local current_str = string.format("%02d:%02d", cur_min, cur_sec_rem)

    local popup_children = {
        Zenith.Box({
            direction = "row",
            align_items = "center",
            children = {
                Zenith.Text({
                    text = player_icon .. " " .. player_raw:upper(),
                    font_size = 12,
                    font_weight = "bold",
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { horizontal = 8, vertical = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "✕", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            }
        }),

        Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 14,
            padding = { horizontal = 10, vertical = 8 },
            border_radius = 12,
            background = Zenith.hex(theme.surface_container_high or theme.surface_container, 120),
            children = {
                Zenith.Box({
                    width = 56,
                    height = 56,
                    border_radius = 10,
                    background = Zenith.hex(theme.primary, 40),
                    align_items = "center",
                    justify_content = "center",
                    children = {
                        Zenith.Text({
                            text = "󰎆",
                            font_size = 28,
                            color = Zenith.hex(theme.primary),
                        })
                    }
                }),
                Zenith.Box({
                    direction = "column",
                    flex_grow = 1,
                    gap = 2,
                    children = {
                        Zenith.Text({
                            text = title_text,
                            font_size = 12,
                            font_weight = "bold",
                            color = Zenith.hex(theme.on_surface),
                        }),
                        Zenith.Text({
                            text = artist_text,
                            font_size = 11,
                            color = Zenith.hex(theme.on_surface_variant or theme.outline),
                        }),
                        Zenith.Text({
                            text = album_text,
                            font_size = 9,
                            color = Zenith.hex(theme.outline_variant or theme.outline),
                        }),
                    }
                })
            }
        }),

        Zenith.Box({
            direction = "column",
            gap = 4,
            children = {
                Zenith.Box({
                    height = 4,
                    border_radius = 2,
                    background = Zenith.rgba(255, 255, 255, 25),
                    children = {
                        Zenith.Box({
                            width = if total_secs > 0 then math.clamp(math.floor((current_secs / total_secs) * 340), 4, 340) else 4,
                            height = 4,
                            border_radius = 2,
                            background = Zenith.hex(theme.primary),
                        })
                    }
                }),
                Zenith.Box({
                    direction = "row",
                    justify_content = "space_between",
                    children = {
                        Zenith.Text({ text = current_str, font_size = 9, color = Zenith.hex(theme.outline_variant or theme.outline) }),
                        Zenith.Text({ text = duration_str, font_size = 9, color = Zenith.hex(theme.outline_variant or theme.outline) }),
                    }
                })
            }
        }),

        Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "space_between",
            gap = 8,
            children = {
                Zenith.Box({
                    flex_grow = 1,
                    padding = { horizontal = 8, vertical = 8 },
                    border_radius = 8,
                    background = Zenith.hex(theme.surface_container),
                    align_items = "center",
                    justify_content = "center",
                    on_click = "media:previous",
                    children = {
                        Zenith.Text({ text = "󰒮 Prev", font_size = 11, color = Zenith.hex(theme.on_surface) })
                    }
                }),

                Zenith.Box({
                    flex_grow = 2,
                    padding = { horizontal = 12, vertical = 9 },
                    border_radius = 10,
                    background = if is_playing then Zenith.hex(theme.primary) else Zenith.hex(theme.surface_container_highest or theme.surface_container),
                    border_color = Zenith.hex(theme.primary),
                    border_width = 1,
                    align_items = "center",
                    justify_content = "center",
                    on_click = "media:play-pause",
                    children = {
                        Zenith.Text({
                            text = play_icon .. " " .. (if is_playing then "Pause" else "Play"),
                            font_size = 12,
                            font_weight = "bold",
                            color = if is_playing then Zenith.hex(theme.on_primary) else Zenith.hex(theme.on_surface),
                        })
                    }
                }),

                Zenith.Box({
                    flex_grow = 1,
                    padding = { horizontal = 8, vertical = 8 },
                    border_radius = 8,
                    background = Zenith.hex(theme.surface_container),
                    align_items = "center",
                    justify_content = "center",
                    on_click = "media:next",
                    children = {
                        Zenith.Text({ text = "Next 󰒭", font_size = 11, color = Zenith.hex(theme.on_surface) })
                    }
                }),
            }
        }),

        Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 8,
            children = {
                Zenith.Text({
                    text = "󰕾",
                    font_size = 13,
                    color = Zenith.hex(theme.outline_variant or theme.outline),
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
                                if Services.Audio.set_volume then
                                    Services.Audio.set_volume(v)
                                elseif Zenith.Services and Zenith.Services.SetVolume then
                                    Zenith.Services.SetVolume(v)
                                end
                            end,
                        }),
                    }
                }),
                Zenith.Text({
                    text = string.format("%d%%", audio.volume or 0),
                    font_size = 10,
                    color = Zenith.hex(theme.outline_variant or theme.outline),
                }),
            }
        }),
    }

    return Zenith.Box({
        direction = "column",
        width = 360,
        height = 360,
        padding = { horizontal = 16, vertical = 14 },
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
        children = popup_children,
    })
end

return MediaPopup
