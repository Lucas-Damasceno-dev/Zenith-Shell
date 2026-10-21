--!strict
-- Zenith Desktop Shell — Status Bar Defaults & Configuration Schema

local Store = Zenith.import("core/store")

local BarDefaults = {
    height = 42,
    compact_height = 36,
    margin_top = 4,
    margin_horizontal = 8,
    border_radius = 18,
    padding_horizontal = 10,
    padding_vertical = 4,
    cluster_gap = 8,
    item_gap = 6,
    glass_opacity = 85,
    corner_style = "Floating Glass",
    position = "Top Edge",
}

function BarDefaults.get_height(): number
    local is_compact = Store.get("barCompactMode", false)
    if is_compact then
        return Store.get("barCompactHeight", BarDefaults.compact_height)
    end
    return Store.get("barHeight", BarDefaults.height)
end

function BarDefaults.is_zen(): boolean
    return Store.get("barZenMode", false)
end

return BarDefaults
