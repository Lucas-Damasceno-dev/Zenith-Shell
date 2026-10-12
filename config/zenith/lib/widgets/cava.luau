--!strict
-- Zenith UI Kit - Standalone CAVA Audio Spectrum Visualizer Widget

local Pill = Zenith.import("widgets/pill")

local function CavaWidget(props: { bar_count: number?, on_click: string? }?)
    local theme = Zenith.Theme()
    local bar_count = (props and props.bar_count) or 8
    local on_click = (props and props.on_click) or "popup:toggle:MediaPopup"

    local spectrum = (Zenith.Services.Spectrum and Zenith.Services.Spectrum(bar_count)) or (Zenith.Services.spectrum and Zenith.Services.spectrum(bar_count)) or {}
    
    local bars = {}
    for idx = 1, bar_count do
        local val = spectrum[idx] or 0.05
        local bar_h = math.clamp(math.floor(val * 14) + 2, 2, 16)
        local bar_color = if val > 0.75 then Zenith.hex(theme.secondary or theme.primary) else Zenith.hex(theme.primary)

        table.insert(bars, Zenith.Box({
            width = 2,
            height = bar_h,
            border_radius = 1,
            background = bar_color,
        }))
    end

    return Pill({
        height = 26,
        border_radius = 13,
        padding = { x = 7, y = 2 },
        gap = 2,
        tooltip = "Visualizador de Áudio (CAVA)",
        on_click = on_click,
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "flex-end",
                justify_content = "center",
                gap = 2,
                height = 16,
                children = bars,
            })
        }
    })
end

return CavaWidget
