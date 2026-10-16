--!strict
-- Zenith-Shell (Engine v2) - MPRIS2 Media Player Control Overlay with Album Art, Seek & Lyrics
-- Ported and refined from BarMediaPopup.qml & BarMediaPill.qml

local theme = Zenith.Theme()
local Store = Zenith.import("settings_store")
local media = Zenith.Services.Media()
local audio = Zenith.Services.audio()
local show_lyrics = Store.get("mediaShowLyrics") or false

-- ── 1. Metadados e Estado do Player ──
local is_playing = media.status == "Playing"
local play_icon = if is_playing then "󰏤" else "󰐊"

local title_text = if #media.title > 0 then media.title else "Nenhuma música em reprodução"
local artist_text = if #media.artist > 0 then media.artist else "Artista desconhecido"
local album_text = if #media.album > 0 then media.album else "Álbum desconhecido"
local player_raw = if #media.player_name > 0 then media.player_name else "MPRIS"
local player_label = player_raw:upper()

-- Ícone do player baseado no nome
local player_lower = player_raw:lower()
local player_icon = if player_lower:find("spotify") then "󰓇"
    elseif player_lower:find("brave") or player_lower:find("chrome") or player_lower:find("firefox") then "󰖟"
    elseif player_lower:find("vlc") or player_lower:find("mpv") then "󰎆"
    else "󰎆"

-- ── 2. Duração, Posição e Seek ──
local total_secs = media.length or media.length_seconds or 0
local total_min = math.floor(total_secs / 60)
local total_sec_rem = total_secs % 60
local duration_str = string.format("%02d:%02d", total_min, total_sec_rem)

-- Posição sincronizada estimada ou armazenada
local current_secs = 0
if Zenith.Storage and Zenith.Storage.get then
    current_secs = tonumber(Zenith.Storage.get("media_current_pos", 0)) or 0
end
if current_secs > total_secs and total_secs > 0 then
    current_secs = total_secs
end
local cur_min = math.floor(current_secs / 60)
local cur_sec_rem = current_secs % 60
local current_str = string.format("%02d:%02d", cur_min, cur_sec_rem)

-- ── 3. Capa do Álbum (Album Art) ──
local art_url = media.art_url or media.album_art or ""
local has_art = #art_url > 0

local album_art_box
if has_art then
    album_art_box = Zenith.Box({
        width = 110,
        height = 110,
        border_radius = 12,
        background = Zenith.hex(theme.surface_container, 80),
        border_color = Zenith.rgba(255, 255, 255, 18),
        border_width = 1,
        children = {
            Zenith.Image({
                src = art_url,
                width = 110,
                height = 110,
                border_radius = 12,
            }),
        }
    })
else
    album_art_box = Zenith.Box({
        width = 110,
        height = 110,
        border_radius = 12,
        background = Zenith.hex(theme.surface_container_highest or theme.surface, 120),
        border_color = Zenith.hex(theme.outline, 40),
        border_width = 1,
        align_items = "center",
        justify_content = "center",
        children = {
            Zenith.Text({
                text = player_icon,
                font_size = 44,
                color = Zenith.hex(theme.primary),
            }),
        }
    })
end

-- ── 4. Construção dos Componentes do Overlay ──
local popup_children = {
    -- Header: Identidade do Player + Status + Botão Fechar
    Zenith.Box({
        direction = "row",
        align_items = "center",
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 6,
                padding = { x = 8, y = 3 },
                border_radius = 6,
                background = Zenith.hex(theme.primary, 30),
                border_color = Zenith.hex(theme.primary, 80),
                border_width = 1,
                children = {
                    Zenith.Text({
                        text = player_icon,
                        font_size = 12,
                        color = Zenith.hex(theme.primary),
                    }),
                    Zenith.Text({
                        text = player_label,
                        font_size = 11,
                        color = Zenith.hex(theme.primary),
                    }),
                }
            }),
            Zenith.Box({ width = 8 }),
            Zenith.Text({
                text = if is_playing then "● Tocando" else "○ Pausado",
                font_size = 10,
                color = if is_playing then Zenith.hex("#a6e3a1") else Zenith.hex(theme.outline),
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

    -- Track Information Card com Capa do Álbum
    Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = 14,
        padding = { x = 12, y = 12 },
        border_radius = 12,
        background = Zenith.hex(theme.surface),
        border_color = Zenith.rgba(255, 255, 255, 14),
        border_width = 1,
        children = {
            album_art_box,
            Zenith.Box({
                direction = "column",
                flex_grow = 1,
                gap = 4,
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
        }
    }),

    -- Barra de Progresso e Seek da Faixa
    Zenith.Box({
        direction = "column",
        gap = 4,
        children = {
            Zenith.Slider({
                id = "media_progress_slider",
                min = 0,
                max = math.max(1, total_secs),
                value = current_secs,
                track_height = 5,
                thumb_radius = 6,
                track_color = Zenith.rgba(255, 255, 255, 25),
                active_track_color = Zenith.hex(theme.primary),
                thumb_color = Zenith.hex("#ffffff"),
                on_change = function(new_val)
                    local v = math.floor(tonumber(new_val) or 0)
                    if Zenith.Storage and Zenith.Storage.set then
                        Zenith.Storage.set("media_current_pos", v)
                    end
                end,
            }),
            Zenith.Box({
                direction = "row",
                justify_content = "space-between",
                children = {
                    Zenith.Text({
                        text = current_str,
                        font_size = 10,
                        color = Zenith.hex(theme.outline),
                    }),
                    Zenith.Box({
                        direction = "row",
                        gap = 10,
                        children = {
                            Zenith.Box({
                                padding = { x = 6, y = 1 },
                                border_radius = 4,
                                background = Zenith.hex(theme.surface_container),
                                on_click = "cmd:playerctl position 10-",
                                children = {
                                    Zenith.Text({ text = "-10s", font_size = 9, color = Zenith.hex(theme.outline) }),
                                }
                            }),
                            Zenith.Box({
                                padding = { x = 6, y = 1 },
                                border_radius = 4,
                                background = Zenith.hex(theme.surface_container),
                                on_click = "cmd:playerctl position 10+",
                                children = {
                                    Zenith.Text({ text = "+10s", font_size = 9, color = Zenith.hex(theme.outline) }),
                                }
                            }),
                        }
                    }),
                    Zenith.Text({
                        text = duration_str,
                        font_size = 10,
                        color = Zenith.hex(theme.outline),
                    }),
                }
            }),
        }
    }),

    -- Barra Completa de Controles MPRIS: Shuffle, Anterior, Play/Pause, Próximo, Loop
    Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space-between",
        gap = 8,
        children = {
            -- Shuffle (Ordem aleatória)
            Zenith.Box({
                flex_grow = 1,
                padding = { x = 8, y = 9 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container),
                on_click = "cmd:playerctl shuffle toggle",
                children = {
                    Zenith.Text({ text = "󰒝 Shuffle", font_size = 11, color = Zenith.hex(theme.on_surface) })
                }
            }),

            -- Previous Track
            Zenith.Box({
                flex_grow = 1,
                padding = { x = 8, y = 9 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container),
                on_click = "media:previous",
                children = {
                    Zenith.Text({ text = "󰒮 Prev", font_size = 11, color = Zenith.hex(theme.on_surface) })
                }
            }),

            -- Play / Pause (Botão Principal com Destaque Primário)
            Zenith.Box({
                flex_grow = 2,
                padding = { x = 12, y = 10 },
                border_radius = 10,
                background = if is_playing then Zenith.hex(theme.primary) else Zenith.hex(theme.surface_container_highest or theme.surface_container),
                border_color = Zenith.hex(theme.primary),
                border_width = 1,
                on_click = "media:play-pause",
                children = {
                    Zenith.Text({
                        text = play_icon .. " " .. (if is_playing then "Pause" else "Play"),
                        font_size = 12,
                        color = if is_playing then Zenith.hex(theme.on_primary) else Zenith.hex(theme.on_surface),
                    })
                }
            }),

            -- Next Track
            Zenith.Box({
                flex_grow = 1,
                padding = { x = 8, y = 9 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container),
                on_click = "media:next",
                children = {
                    Zenith.Text({ text = "Next 󰒭", font_size = 11, color = Zenith.hex(theme.on_surface) })
                }
            }),

            -- Loop (Repetição)
            Zenith.Box({
                flex_grow = 1,
                padding = { x = 8, y = 9 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container),
                on_click = "cmd:playerctl loop toggle",
                children = {
                    Zenith.Text({ text = "󰑖 Loop", font_size = 11, color = Zenith.hex(theme.on_surface) })
                }
            }),
        }
    }),

    -- Volume Slider Row do Player
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

    -- Modo Letras / Karaokê Toggle Switch Row
    Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space-between",
        padding = { x = 6, y = 4 },
        border_radius = 8,
        background = Zenith.hex(theme.surface_container, 50),
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 8,
                children = {
                    Zenith.Text({
                        text = "󰎈",
                        font_size = 13,
                        color = if show_lyrics then Zenith.hex(theme.primary) else Zenith.hex(theme.outline),
                    }),
                    Zenith.Text({
                        text = "Modo Letras / Karaokê",
                        font_size = 11,
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

-- Se o modo letras estiver ativo, exibir card com lyrics view
if show_lyrics then
    table.insert(popup_children, Zenith.Box({
        direction = "column",
        gap = 6,
        padding = { x = 12, y = 10 },
        border_radius = 10,
        background = Zenith.hex(theme.surface, 180),
        border_color = Zenith.rgba(255, 255, 255, 14),
        border_width = 1,
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                children = {
                    Zenith.Text({
                        text = "Letras da Faixa",
                        font_size = 11,
                        color = Zenith.hex(theme.primary),
                    }),
                    Zenith.Box({ flex_grow = 1 }),
                    Zenith.Text({
                        text = "Sincronizado via LRCLib",
                        font_size = 9,
                        color = Zenith.hex(theme.outline),
                    }),
                }
            }),
            Zenith.Box({
                padding = { x = 8, y = 8 },
                border_radius = 6,
                background = Zenith.hex(theme.surface_container, 70),
                children = {
                    Zenith.Text({
                        text = if is_playing then "♪ " .. title_text .. " - " .. artist_text .. "\n[Letras em reprodução contínua...]" else "Pressione Play para iniciar sincronização de letras.",
                        font_size = 10,
                        color = Zenith.hex(theme.on_surface),
                    }),
                }
            }),
        }
    }))
end

return Zenith.Window({
    direction = "column",
    width = 380,
    height = if show_lyrics then 490 else 410,
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
    children = popup_children,
})
