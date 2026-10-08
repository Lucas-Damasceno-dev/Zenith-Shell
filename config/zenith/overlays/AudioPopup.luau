--!strict
-- Zenith-Shell (Engine v2) - Audio & Volume Control Overlay with Output Device Switcher

local theme = Zenith.Theme()
local audio = Zenith.Services.audio()
local sinks = Zenith.Services.AudioSinks()

local vol = audio.volume
local is_muted = audio.is_muted
local vol_icon = is_muted and "󰝟" or (vol > 60 and "" or (vol > 20 and "" or ""))

local sink_boxes = {}
for _, s in ipairs(sinks) do
    local is_headphone = s.name:lower():find("fone") or s.name:lower():find("headphone") or s.name:lower():find("jack")
    local icon = is_headphone and "󰋋" or "󰓃"
    local name = s.name
    if #name > 26 then
        name = name:sub(1, 23) .. "..."
    end

    table.insert(sink_boxes, Zenith.Box({
        direction = "row",
        padding = { x = 10, y = 6 },
        border_radius = 6,
        background = s.is_default and Zenith.rgba(124, 77, 255, 40) or Zenith.rgba(255, 255, 255, 8),
        border_color = s.is_default and Zenith.hex(theme.primary) or Zenith.rgba(255, 255, 255, 12),
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
                text = s.is_default and "● ACTIVE" or "○",
                font_size = 9,
                color = s.is_default and Zenith.hex(theme.primary) or Zenith.hex(theme.outline),
            }),
        }
    }))
end

return Zenith.Window({
    direction = "column",
    width = 330,
    height = 340,
    padding = { x = 14, y = 12 },
    gap = 10,
    background = Zenith.rgba(18, 20, 26, 230),
    border_color = Zenith.hex(theme.primary),
    border_width = 1,
    border_radius = 14,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 160),
        blur = 18,
        offset_x = 0,
        offset_y = 6,
    },
    children = {
        -- Header with title and close button
        Zenith.Box({
            direction = "row",
            children = {
                Zenith.Text({
                    text = "󰕾 Audio & Volume",
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

        -- Volume level display & quick mute
        Zenith.Box({
            direction = "row",
            gap = 10,
            padding = { x = 12, y = 10 },
            border_radius = 8,
            background = Zenith.hex(theme.surface),
            border_color = Zenith.hex("#2d3748"),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = string.format("%s  %d%%", vol_icon, vol),
                    font_size = 18,
                    color = is_muted and Zenith.hex("#e06c75") or Zenith.hex(theme.on_surface),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 10, y = 4 },
                    border_radius = 6,
                    background = is_muted and Zenith.hex("#e06c75") or Zenith.hex(theme.surface_container),
                    on_click = "cmd:wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
                    children = {
                        Zenith.Text({
                            text = is_muted and "UNMUTE" or "MUTE",
                            font_size = 10,
                            color = is_muted and Zenith.hex("#ffffff") or Zenith.hex(theme.on_surface),
                        })
                    }
                }),
            }
        }),

        -- Quick step controls (-10%, -5%, +5%, +10%)
        Zenith.Box({
            direction = "row",
            gap = 6,
            children = {
                Zenith.Box({
                    flex_grow = 1,
                    padding = { x = 4, y = 6 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "cmd:wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-",
                    children = {
                        Zenith.Text({ text = "-10%", font_size = 11, color = Zenith.hex(theme.on_surface) })
                    }
                }),
                Zenith.Box({
                    flex_grow = 1,
                    padding = { x = 4, y = 6 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "cmd:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
                    children = {
                        Zenith.Text({ text = "-5%", font_size = 11, color = Zenith.hex(theme.on_surface) })
                    }
                }),
                Zenith.Box({
                    flex_grow = 1,
                    padding = { x = 4, y = 6 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "cmd:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
                    children = {
                        Zenith.Text({ text = "+5%", font_size = 11, color = Zenith.hex(theme.on_surface) })
                    }
                }),
                Zenith.Box({
                    flex_grow = 1,
                    padding = { x = 4, y = 6 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "cmd:wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+",
                    children = {
                        Zenith.Text({ text = "+10%", font_size = 11, color = Zenith.hex(theme.on_surface) })
                    }
                }),
            }
        }),

        -- Output Devices Section Header
        Zenith.Text({
            text = "OUTPUT DEVICES",
            font_size = 10,
            color = Zenith.hex(theme.outline),
        }),

        -- Output Devices List
        Zenith.Box({
            direction = "column",
            gap = 5,
            children = sink_boxes,
        }),

        -- Pavucontrol launcher button
        Zenith.Box({
            padding = { x = 10, y = 6 },
            border_radius = 6,
            background = Zenith.hex(theme.surface),
            border_color = Zenith.hex("#2d3748"),
            border_width = 1,
            on_click = "cmd:pavucontrol &",
            children = {
                Zenith.Text({
                    text = "󰓃 Open Audio Mixer (pavucontrol)",
                    font_size = 10,
                    color = Zenith.hex(theme.on_surface),
                })
            }
        }),
    }
})
