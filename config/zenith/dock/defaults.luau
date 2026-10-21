--!strict
-- Zenith Desktop Shell — Floating Dock Defaults & Constants

local Store = Zenith.import("core/store")

local DockDefaults = {
    height = 58,
    icon_size = 40,
    max_scale = 1.45,
    sigma = 80,
    item_spacing = 8,
    border_radius = 24,
    padding_horizontal = 14,
    padding_vertical = 6,
    autohide = true,
}

function DockDefaults.get_height(): number
    return Store.get("dockHeight", DockDefaults.height)
end

function DockDefaults.get_icon_size(): number
    return Store.get("dockIconSize", DockDefaults.icon_size)
end

function DockDefaults.is_autohide(): boolean
    return Store.get("dockAutoHide", DockDefaults.autohide)
end

function DockDefaults.is_enabled(): boolean
    return Store.get("dockEnabled", true)
end

return DockDefaults
