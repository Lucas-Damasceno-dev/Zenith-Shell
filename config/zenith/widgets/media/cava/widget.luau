--!strict
-- Zenith-Shell: CAVA Audio Spectrum Visualizer Widget

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")
local PopupManager = Zenith.import("core/popup_manager")

type CavaWidgetProps = {
    bar_count: number?,
    on_click: string?,
}

local function CavaWidget(props: CavaWidgetProps?)
    local theme = Theme.get()
    local bar_count = (props and props.bar_count) or 8
    local on_click = (props and props.on_click) or PopupManager.toggle_action("MediaPopup")

    local spectrum = Services.Audio.spectrum(bar_count)
    
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
        padding = { horizontal = 7, vertical = 2 },
        gap = 2,
        tooltip = "Visualizador de Áudio (CAVA)",
        on_click = on_click,
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "flex_end",
                justify_content = "center",
                gap = 2,
                height = 16,
                children = bars,
            })
        }
    })
end

return CavaWidget
