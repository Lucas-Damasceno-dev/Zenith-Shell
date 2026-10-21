--!strict
local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")
local Card = Zenith.import("core/ui/card")
local Button = Zenith.import("core/ui/button")
local Slider = Zenith.import("core/ui/slider")
local Services = Zenith.import("core/services/init")

return function()
    local s = Services.Audio.status()
    local sinks = Services.Audio.sinks()
    local vol = s.volume or 0
    local muted = s.is_muted or s.muted or false
    local t = Theme.get()

    local sink_items = {}
    for _, sink in ipairs(sinks) do
        local is_def = sink.is_default
        table.insert(sink_items, Button({
            label = sink.name,
            icon = if is_def then Icons.glyphs.check else Icons.glyphs.chevron_right,
            variant = if is_def then "primary" else "tonal",
            width = "100%",
            on_click = "audio:set_sink:" .. tostring(sink.id),
        }))
    end

    local spec_bars = Services.Audio.spectrum(16)
    local spectrum_nodes = {}
    for _, h in ipairs(spec_bars) do
        local bar_h = math.clamp(math.floor(h * 24), 2, 24)
        table.insert(spectrum_nodes, Zenith.Box({
            width = 6,
            height = bar_h,
            background = t.primary or "#7c4dff",
            border_radius = 3,
        }))
    end

    return Card({
        variant = "glass",
        width = 340,
        gap = 12,
        padding = 16,
        children = {
            Zenith.Box({
                width = "100%",
                flex_direction = "row",
                align_items = "center",
                justify_content = "space_between",
                children = {
                    Zenith.Text({
                        text = "Controle de Áudio",
                        font_family = "JetBrainsMono Nerd Font",
                        font_size = 15,
                        font_weight = "bold",
                        color = t.on_surface or "#ffffff",
                    }),
                    Button({
                        icon = if muted then Icons.glyphs.volume_mute else Icons.glyphs.volume_high,
                        variant = if muted then "danger" else "tonal",
                        size = "sm",
                        on_click = "audio:toggle_mute",
                    }),
                },
            }),
            Slider({
                min = 0,
                max = 100,
                value = vol,
                show_value = true,
                icon_left = Icons.glyphs.volume_low,
                icon_right = Icons.glyphs.volume_high,
                on_change = "audio:set_volume:",
            }),
            Zenith.Text({
                text = "Saídas de Áudio (PipeWire)",
                font_family = "JetBrainsMono Nerd Font",
                font_size = 12,
                color = Theme.alpha(t.on_surface or "#ffffff", 180),
                font_weight = "medium",
            }),
            Zenith.Box({
                width = "100%",
                flex_direction = "column",
                gap = 6,
                children = sink_items,
            }),
            Zenith.Box({
                width = "100%",
                height = 26,
                flex_direction = "row",
                align_items = "flex_end",
                justify_content = "center",
                gap = 4,
                children = spectrum_nodes,
            }),
        },
    })
end
