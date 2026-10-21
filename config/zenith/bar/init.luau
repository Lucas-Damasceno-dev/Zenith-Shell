--!strict
-- Zenith Desktop Shell — Master Status Bar Orchestrator
-- Composes Left, Center and Right clusters in an edge-to-edge or floating glass container

local Theme = Zenith.import("core/theme")
local Store = Zenith.import("core/store")
local BarDefaults = Zenith.import("bar/defaults")
local LeftCluster = Zenith.import("bar/clusters/left")
local CenterCluster = Zenith.import("bar/clusters/center")
local RightCluster = Zenith.import("bar/clusters/right")

local function Bar(props: {
    height: number?,
    compact: boolean?,
    zen_mode: boolean?,
    monitor: string?,
}?)
    local height = if props and props.height then props.height else BarDefaults.get_height()
    local is_compact = if props and props.compact ~= nil then props.compact else Store.get("barCompactMode", false)
    local is_zen = if props and props.zen_mode ~= nil then props.zen_mode else BarDefaults.is_zen()

    local custom_radius = Store.get("barRadius", BarDefaults.border_radius)
    local border_width = Store.get("barBorderWidth", 1)
    local border_color = Store.get("barBorderColor", nil)
    local glass = Theme.glass("island", custom_radius)
    local theme = Theme.get()

    -- Bare chassis: clusters detached for granular styling and position tuning
    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space_between",
        width = "100%",
        height = height,
        padding = {
            horizontal = Store.get("barPadding", BarDefaults.padding_horizontal),
            vertical = BarDefaults.padding_vertical,
        },
        background = glass.background,
        border_color = if border_color then Zenith.hex(border_color) else glass.border_color,
        border_width = border_width,
        border_radius = custom_radius,
        shadow = if Store.get("barFloatShadow", true) then glass.shadow else nil,
        children = {
            LeftCluster({ compact = is_compact, height = height }),
            CenterCluster({ compact = is_compact, height = height }),
            RightCluster({ compact = is_compact, zen_mode = is_zen, height = height }),
        },
    })
end

return Bar
