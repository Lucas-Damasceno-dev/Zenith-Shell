--!strict
-- Zenith-Shell (Engine v2) - PipeWire Audio Mixer, Microphone & Device Switcher Overlay
-- Ported and refined from VolumeMixerPopup.qml & BarAudioStatus.qml

local theme = Zenith.Theme()
local UIKit = Zenith.import("ui_kit")
local audio = Zenith.Services.audio()
local sinks = Zenith.Services.AudioSinks()
local media = (Zenith.Services.Media and Zenith.Services.Media()) or { is_available = false, player_name = "", title = "", artist = "" }
local clients = (Zenith.Services.Clients and Zenith.Services.Clients()) or {}

-- ── 1. Master Volume & State ──
local vol = audio.volume or 0
local is_muted = audio.is_muted or false
local vol_icon = if is_muted then "󰝟"
    elseif vol > 60 then ""
    elseif vol > 20 then ""
    elseif vol > 0 then ""
    else "󰝟"

-- ── 2. Active Tab Filter ("all", "master", "apps", "sinks") ──
local active_tab = "all"
if Zenith.Storage and Zenith.Storage.get then
    active_tab = Zenith.Storage.get("audio_popup_tab", "all")
end

-- ── 3. Microphone (System Audio Source) State ──
local mic_vol = 100
local mic_muted = false
if Zenith.Storage and Zenith.Storage.get then
    mic_vol = tonumber(Zenith.Storage.get("audio_mic_volume", 100)) or 100
    mic_muted = Zenith.Storage.get("audio_mic_muted", false) == true
end
local mic_icon = if mic_muted then "󰍭" else "󰍬"

-- ── 4. Dispositivos de Saída (Sinks) ──
local sink_boxes = {}
for _, s in ipairs(sinks) do
    local is_headphone = s.name:lower():find("fone") or s.name:lower():find("headphone") or s.name:lower():find("jack")
    local is_hdmi = s.name:lower():find("hdmi") or s.name:lower():find("displayport") or s.name:lower():find("dp")
    local icon = if is_headphone then "󰋋" elseif is_hdmi then "󰡁" else "󰓃"
    local name = s.name
    if #name > 28 then
        name = name:sub(1, 25) .. "..."
    end

    table.insert(sink_boxes, Zenith.Box({
        direction = "row",
        align_items = "center",
        padding = { x = 10, y = 6 },
        border_radius = 6,
        background = s.is_default and Zenith.hex(theme.primary, 35) or Zenith.hex(theme.surface_container, 80),
        border_color = s.is_default and Zenith.hex(theme.primary) or Zenith.hex(theme.outline, 30),
        border_width = 1,
        on_click = "audio:set_sink:" .. tostring(s.id),
        children = {
            Zenith.Text({
                text = icon,
                font_size = 13,
                color = s.is_default and Zenith.hex(theme.primary) or Zenith.hex(theme.on_surface),
            }),
            Zenith.Box({ width = 8 }),
            Zenith.Text({
                text = name,
                font_size = 11,
                color = s.is_default and Zenith.hex(theme.primary) or Zenith.hex(theme.on_surface),
            }),
            Zenith.Box({ flex_grow = 1 }),
            Zenith.Text({
                text = s.is_default and "● ATIVO" or "○ SELECIONAR",
                font_size = 9,
                color = s.is_default and Zenith.hex(theme.primary) or Zenith.hex(theme.outline),
            }),
        }
    }))
end

-- ── 5. Detecção do Mixer por Aplicação (PipeWire Audio Streams) ──
local known_audio_apps = {
    spotify = { name = "Spotify", icon = "󰓇", color = "#1db954" },
    brave = { name = "Brave Browser", icon = "󰖟", color = "#fb542b" },
    firefox = { name = "Firefox", icon = "󰖟", color = "#ff7139" },
    chromium = { name = "Chromium", icon = "󰖟", color = "#4285f4" },
    chrome = { name = "Google Chrome", icon = "󰖟", color = "#4285f4" },
    discord = { name = "Discord", icon = "󰭹", color = "#5865f2" },
    telegram = { name = "Telegram", icon = "󰭹", color = "#24a1de" },
    vlc = { name = "VLC Media Player", icon = "󰎆", color = "#ff8800" },
    mpv = { name = "MPV Player", icon = "󰎆", color = "#7b32a8" },
    steam = { name = "Steam Games", icon = "󰓓", color = "#1b2838" },
    obs = { name = "OBS Studio", icon = "󰕾", color = "#302c34" },
}

local app_streams = {}
local seen_apps = {}

-- A. Detecta aplicativo em reprodução MPRIS ativa
if media.is_available and #media.player_name > 0 then
    local p_lower = media.player_name:lower()
    local app_info = known_audio_apps[p_lower] or {
        name = media.player_name:sub(1, 1):upper() .. media.player_name:sub(2),
        icon = "󰎆",
        color = theme.primary,
    }
    seen_apps[p_lower] = true
    local sub = if #media.title > 0 then
        (if #media.artist > 0 then media.artist .. " • " .. media.title else media.title)
    else
        "Reprodução de áudio ativa"
    if #sub > 30 then
        sub = sub:sub(1, 28) .. ".."
    end

    table.insert(app_streams, {
        id = p_lower,
        name = app_info.name,
        icon = app_info.icon,
        color = app_info.color,
        subtitle = sub,
        volume = 100,
        muted = false,
    })
end

-- B. Detecta clientes Hyprland abertos que geram fluxos de áudio
for _, c in ipairs(clients) do
    local class_lower = (c.class or ""):lower()
    local initial_lower = (c.initial_class or ""):lower()
    for app_key, info in pairs(known_audio_apps) do
        if not seen_apps[app_key] and (class_lower:find(app_key) or initial_lower:find(app_key)) then
            seen_apps[app_key] = true
            local sub = c.title or "Fluxo de áudio PipeWire"
            if #sub > 30 then
                sub = sub:sub(1, 28) .. ".."
            end
            table.insert(app_streams, {
                id = app_key,
                name = info.name,
                icon = info.icon,
                color = info.color,
                subtitle = sub,
                volume = 100,
                muted = false,
            })
            break
        end
    end
end

-- C. Se nenhum aplicativo específico foi detectado, prover fluxos padrão do sistema
if #app_streams == 0 then
    table.insert(app_streams, {
        id = "system",
        name = "Áudio do Sistema",
        icon = "󰕾",
        color = theme.primary,
        subtitle = "Sons do sistema e alertas",
        volume = 100,
        muted = false,
    })
    table.insert(app_streams, {
        id = "media",
        name = "Mídia / Navegador Web",
        icon = "󰖟",
        color = theme.secondary or theme.primary,
        subtitle = "Fluxo multimídia padrão",
        volume = 100,
        muted = false,
    })
end

-- Renderização dos cards de mixer por aplicação
local app_mixer_boxes = {}
for _, app in ipairs(app_streams) do
    local app_vol_key = "audio_app_vol_" .. app.id
    local app_mute_key = "audio_app_muted_" .. app.id
    local app_v = 100
    local app_m = false
    if Zenith.Storage and Zenith.Storage.get then
        app_v = tonumber(Zenith.Storage.get(app_vol_key, 100)) or 100
        app_m = Zenith.Storage.get(app_mute_key, false) == true
    end

    table.insert(app_mixer_boxes, Zenith.Box({
        direction = "column",
        gap = 6,
        padding = { x = 10, y = 8 },
        border_radius = 8,
        background = Zenith.hex(theme.surface_container, 70),
        border_color = Zenith.rgba(255, 255, 255, 14),
        border_width = 1,
        children = {
            -- Header do App: Ícone, Nome, Subtítulo e Toggle de Mute
            Zenith.Box({
                direction = "row",
                align_items = "center",
                children = {
                    Zenith.Text({
                        text = app.icon,
                        font_size = 14,
                        color = Zenith.hex(app.color or theme.primary),
                    }),
                    Zenith.Box({ width = 8 }),
                    Zenith.Box({
                        direction = "column",
                        gap = 1,
                        children = {
                            Zenith.Text({
                                text = app.name,
                                font_size = 11,
                                color = Zenith.hex(theme.on_surface),
                            }),
                            Zenith.Text({
                                text = app.subtitle,
                                font_size = 9,
                                color = Zenith.hex(theme.outline),
                            }),
                        }
                    }),
                    Zenith.Box({ flex_grow = 1 }),
                    Zenith.Text({
                        text = if app_m then "Mudo" else string.format("%d%%", app_v),
                        font_size = 10,
                        color = if app_m then Zenith.hex("#e06c75") else Zenith.hex(theme.outline),
                    }),
                    Zenith.Box({ width = 6 }),
                    Zenith.Box({
                        padding = { x = 6, y = 3 },
                        border_radius = 4,
                        background = if app_m then Zenith.hex("#e06c75", 40) else Zenith.hex(theme.surface_container_highest or theme.surface, 120),
                        border_color = if app_m then Zenith.hex("#e06c75") else Zenith.hex(theme.outline, 40),
                        border_width = 1,
                        on_click = "cmd:wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
                        children = {
                            Zenith.Text({
                                text = if app_m then "󰝟" else "󰕾",
                                font_size = 10,
                                color = if app_m then Zenith.hex("#e06c75") else Zenith.hex(theme.on_surface),
                            }),
                        }
                    }),
                }
            }),

            -- Slider tátil de volume do app
            Zenith.Slider({
                id = "slider_app_" .. app.id,
                min = 0,
                max = 100,
                value = app_v,
                track_height = 5,
                thumb_radius = 6,
                track_color = Zenith.rgba(255, 255, 255, 20),
                active_track_color = if app_m then Zenith.hex("#e06c75") else Zenith.hex(theme.primary),
                thumb_color = Zenith.hex("#ffffff"),
                on_change = function(new_val)
                    local v = math.floor(tonumber(new_val) or 0)
                    if Zenith.Storage and Zenith.Storage.set then
                        Zenith.Storage.set("audio_app_vol_" .. app.id, v)
                    end
                end,
            }),

            -- Botões de ajuste rápido (-5%, +5%)
            Zenith.Box({
                direction = "row",
                gap = 4,
                children = {
                    Zenith.Box({
                        flex_grow = 1,
                        padding = { x = 4, y = 3 },
                        border_radius = 4,
                        background = Zenith.hex(theme.surface_container),
                        on_click = "cmd:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
                        children = {
                            Zenith.Text({ text = "-5%", font_size = 9, color = Zenith.hex(theme.outline) })
                        }
                    }),
                    Zenith.Box({
                        flex_grow = 1,
                        padding = { x = 4, y = 3 },
                        border_radius = 4,
                        background = Zenith.hex(theme.surface_container),
                        on_click = "cmd:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
                        children = {
                            Zenith.Text({ text = "+5%", font_size = 9, color = Zenith.hex(theme.outline) })
                        }
                    }),
                }
            }),
        }
    }))
end

-- ── 6. Montagem dos Blocos de Conteúdo ──
local show_master = active_tab == "all" or active_tab == "master"
local show_apps = active_tab == "all" or active_tab == "apps"
local show_sinks = active_tab == "all" or active_tab == "sinks"

local main_children = {
    -- Header com título, badge e botão fechar
    Zenith.Box({
        direction = "row",
        align_items = "center",
        children = {
            Zenith.Text({
                text = "󰕾 Áudio & Mixer PipeWire",
                font_size = 13,
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

    -- Segmented Tabs Bar para Navegação
    Zenith.Box({
        direction = "row",
        gap = 4,
        padding = { x = 3, y = 3 },
        border_radius = 8,
        background = Zenith.hex(theme.surface_container_highest or theme.surface, 90),
        children = {
            Zenith.Box({
                flex_grow = 1,
                padding = { x = 6, y = 4 },
                border_radius = 6,
                background = if active_tab == "all" then Zenith.hex(theme.primary, 35) else "transparent",
                border_color = if active_tab == "all" then Zenith.hex(theme.primary) else "transparent",
                border_width = 1,
                on_click = "storage:set:audio_popup_tab:all",
                children = {
                    Zenith.Text({
                        text = "Todos",
                        font_size = 10,
                        color = if active_tab == "all" then Zenith.hex(theme.primary) else Zenith.hex(theme.outline),
                    }),
                }
            }),
            Zenith.Box({
                flex_grow = 1,
                padding = { x = 6, y = 4 },
                border_radius = 6,
                background = if active_tab == "master" then Zenith.hex(theme.primary, 35) else "transparent",
                border_color = if active_tab == "master" then Zenith.hex(theme.primary) else "transparent",
                border_width = 1,
                on_click = "storage:set:audio_popup_tab:master",
                children = {
                    Zenith.Text({
                        text = "Master & Mic",
                        font_size = 10,
                        color = if active_tab == "master" then Zenith.hex(theme.primary) else Zenith.hex(theme.outline),
                    }),
                }
            }),
            Zenith.Box({
                flex_grow = 1,
                padding = { x = 6, y = 4 },
                border_radius = 6,
                background = if active_tab == "apps" then Zenith.hex(theme.primary, 35) else "transparent",
                border_color = if active_tab == "apps" then Zenith.hex(theme.primary) else "transparent",
                border_width = 1,
                on_click = "storage:set:audio_popup_tab:apps",
                children = {
                    Zenith.Text({
                        text = "Apps (" .. tostring(#app_streams) .. ")",
                        font_size = 10,
                        color = if active_tab == "apps" then Zenith.hex(theme.primary) else Zenith.hex(theme.outline),
                    }),
                }
            }),
            Zenith.Box({
                flex_grow = 1,
                padding = { x = 6, y = 4 },
                border_radius = 6,
                background = if active_tab == "sinks" then Zenith.hex(theme.primary, 35) else "transparent",
                border_color = if active_tab == "sinks" then Zenith.hex(theme.primary) else "transparent",
                border_width = 1,
                on_click = "storage:set:audio_popup_tab:sinks",
                children = {
                    Zenith.Text({
                        text = "Saídas",
                        font_size = 10,
                        color = if active_tab == "sinks" then Zenith.hex(theme.primary) else Zenith.hex(theme.outline),
                    }),
                }
            }),
        }
    }),
}

-- Bloco Master & Microfone
if show_master then
    table.insert(main_children, Zenith.Box({
        direction = "column",
        gap = 8,
        padding = { x = 12, y = 10 },
        border_radius = 10,
        background = Zenith.hex(theme.surface),
        border_color = Zenith.rgba(255, 255, 255, 14),
        border_width = 1,
        children = {
            -- Master Output Header & Mute Button
            Zenith.Box({
                direction = "row",
                align_items = "center",
                children = {
                    Zenith.Text({
                        text = string.format("%s  Saída Master: %d%%", vol_icon, vol),
                        font_size = 12,
                        color = if is_muted then Zenith.hex("#e06c75") else Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Box({ flex_grow = 1 }),
                    UIKit.Button({
                        label = if is_muted then "DESMUTAR" else "MUTAR",
                        icon = if is_muted then "󰝟" else "󰕾",
                        variant = if is_muted then "danger" else "tonal",
                        size = "sm",
                        on_click = "audio:toggle_mute",
                    }),
                }
            }),

            -- Continuous Interactive Hardware Volume Slider
            Zenith.Slider({
                id = "audio_volume_slider",
                min = 0,
                max = 100,
                value = vol,
                track_height = 7,
                thumb_radius = 9,
                track_color = Zenith.hex(theme.surface_container_highest or theme.surface_container, 180),
                active_track_color = if is_muted then Zenith.hex("#e06c75") else Zenith.hex(theme.primary),
                thumb_color = Zenith.hex("#ffffff"),
                on_change = function(new_val)
                    local v = math.floor(tonumber(new_val) or 0)
                    Zenith.Services.SetVolume(v)
                end,
            }),

            -- Quick step controls (-10%, -5%, +5%, +10%)
            Zenith.Box({
                direction = "row",
                gap = 4,
                children = {
                    Zenith.Box({
                        flex_grow = 1,
                        padding = { x = 4, y = 4 },
                        border_radius = 5,
                        background = Zenith.hex(theme.surface_container),
                        on_click = "audio:volume_step:-10",
                        children = {
                            Zenith.Text({ text = "-10%", font_size = 10, color = Zenith.hex(theme.on_surface) })
                        }
                    }),
                    Zenith.Box({
                        flex_grow = 1,
                        padding = { x = 4, y = 4 },
                        border_radius = 5,
                        background = Zenith.hex(theme.surface_container),
                        on_click = "audio:volume_step:-5",
                        children = {
                            Zenith.Text({ text = "-5%", font_size = 10, color = Zenith.hex(theme.on_surface) })
                        }
                    }),
                    Zenith.Box({
                        flex_grow = 1,
                        padding = { x = 4, y = 4 },
                        border_radius = 5,
                        background = Zenith.hex(theme.surface_container),
                        on_click = "audio:volume_step:5",
                        children = {
                            Zenith.Text({ text = "+5%", font_size = 10, color = Zenith.hex(theme.on_surface) })
                        }
                    }),
                    Zenith.Box({
                        flex_grow = 1,
                        padding = { x = 4, y = 4 },
                        border_radius = 5,
                        background = Zenith.hex(theme.surface_container),
                        on_click = "audio:volume_step:10",
                        children = {
                            Zenith.Text({ text = "+10%", font_size = 10, color = Zenith.hex(theme.on_surface) })
                        }
                    }),
                }
            }),

            -- Microfone (Entrada Padrão / Source)
            Zenith.Box({
                direction = "row",
                align_items = "center",
                padding = { x = 0, y = 4 },
                children = {
                    Zenith.Text({
                        text = string.format("%s  Microfone: %d%%", mic_icon, mic_vol),
                        font_size = 12,
                        color = if mic_muted then Zenith.hex("#e06c75") else Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Box({ flex_grow = 1 }),
                    UIKit.Button({
                        label = if mic_muted then "DESMUTAR" else "MUTAR",
                        icon = mic_icon,
                        variant = if mic_muted then "danger" else "tonal",
                        size = "sm",
                        on_click = "cmd:wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
                    }),
                }
            }),

            -- Slider tátil de volume do Microfone
            Zenith.Slider({
                id = "audio_mic_volume_slider",
                min = 0,
                max = 100,
                value = mic_vol,
                track_height = 6,
                thumb_radius = 8,
                track_color = Zenith.rgba(255, 255, 255, 25),
                active_track_color = if mic_muted then Zenith.hex("#e06c75") else Zenith.hex(theme.tertiary or theme.primary),
                thumb_color = Zenith.hex("#ffffff"),
                on_change = function(new_val)
                    local v = math.floor(tonumber(new_val) or 0)
                    if Zenith.Storage and Zenith.Storage.set then
                        Zenith.Storage.set("audio_mic_volume", v)
                    end
                end,
            }),

            -- Quick step controls do Microfone (-10%, +10%)
            Zenith.Box({
                direction = "row",
                gap = 6,
                children = {
                    Zenith.Box({
                        flex_grow = 1,
                        padding = { x = 4, y = 4 },
                        border_radius = 5,
                        background = Zenith.hex(theme.surface_container),
                        on_click = "cmd:wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 10%-",
                        children = {
                            Zenith.Text({ text = "-10% Mic", font_size = 10, color = Zenith.hex(theme.outline) })
                        }
                    }),
                    Zenith.Box({
                        flex_grow = 1,
                        padding = { x = 4, y = 4 },
                        border_radius = 5,
                        background = Zenith.hex(theme.surface_container),
                        on_click = "cmd:wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 10%+",
                        children = {
                            Zenith.Text({ text = "+10% Mic", font_size = 10, color = Zenith.hex(theme.outline) })
                        }
                    }),
                }
            }),
        }
    }))
end

-- Bloco Mixer por Aplicação (PipeWire Active Streams)
if show_apps then
    table.insert(main_children, Zenith.Text({
        text = "MIXER DE APLICATIVOS (PIPEWIRE)",
        font_size = 10,
        color = Zenith.hex(theme.outline),
    }))

    table.insert(main_children, Zenith.Box({
        direction = "column",
        align_items = "stretch",
        gap = 6,
        children = app_mixer_boxes,
    }))
end

-- Bloco Dispositivos de Saída (Sinks)
if show_sinks then
    table.insert(main_children, Zenith.Text({
        text = "DISPOSITIVOS DE SAÍDA (SINKS)",
        font_size = 10,
        color = Zenith.hex(theme.outline),
    }))

    table.insert(main_children, Zenith.Box({
        direction = "column",
        align_items = "stretch",
        gap = 5,
        children = sink_boxes,
    }))
end

-- Pavucontrol launcher button
table.insert(main_children, UIKit.Button({
    label = "Mixer de Áudio Avançado (pavucontrol)",
    icon = "󰓃",
    variant = "outlined",
    size = "md",
    on_click = "launch:pavucontrol",
}))

return Zenith.Window({
    direction = "column",
    align_items = "stretch",
    width = 380,
    height = if active_tab == "all" then 620 else 460,
    padding = { x = 14, y = 12 },
    gap = 10,
    background = Zenith.hex(theme.surface, 235),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
    border_width = 1,
    border_radius = 14,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 160),
        blur = 18,
        offset_x = 0,
        offset_y = 6,
    },
    children = main_children,
})
