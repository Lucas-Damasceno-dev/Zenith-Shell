--!strict
-- Zenith Desktop Shell — Bar Center Cluster
-- Orchestrates Clock, Media/DynamicIsland, Weather and Pomodoro

local Store = Zenith.import("core/store")
local Widgets = Zenith.import("widgets/init")

local function CenterCluster(props: { compact: boolean?, height: number? }?)
    local children = {}

    local show_weather = Store.get("showCenterWeather", true)
    local show_clock = Store.get("showCenterClock", true)
    local show_media = Store.get("showCenterMedia", true)
    local show_pomodoro = Store.get("showPomodoro", false)

    if show_weather then
        table.insert(children, Widgets.Weather())
    end

    if show_clock then
        table.insert(children, Widgets.Clock())
    end

    if show_media then
        table.insert(children, Widgets.Mpris())
    end

    if show_pomodoro then
        table.insert(children, Widgets.Pomodoro())
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "center",
        gap = 6,
        children = children,
    })
end

return CenterCluster
