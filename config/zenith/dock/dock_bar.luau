--!strict
-- Zenith Desktop Shell — Floating Dock Bar Container
-- Orchestrates pinned apps, unpinned running apps, separators, media and utilities

local Theme = Zenith.import("core/theme")
local Store = Zenith.import("core/store")
local DockDefaults = Zenith.import("dock/defaults")
local PinnedApps = Zenith.import("dock/pinned")
local RunningApps = Zenith.import("dock/running")
local DockAppIcon = Zenith.import("dock/items/app_icon")
local DockMprisPill = Zenith.import("dock/items/mpris_pill")
local DockUtilities = Zenith.import("dock/items/utilities")
local DockTrash = Zenith.import("dock/items/trash")

local function DockBar()
    local theme = Theme.get()
    local glass = Theme.glass("dock", Store.get("dockRadius", DockDefaults.border_radius))

    local pinned_list = PinnedApps.list()
    local running_map = RunningApps.get_active_apps()

    local children = {}
    local pinned_classes: { [string]: boolean } = {}

    -- 1. Pinned Applications
    for _, pinned in ipairs(pinned_list) do
        local key = string.lower(pinned.class_name)
        pinned_classes[key] = true
        local active = running_map[key]

        table.insert(children, DockAppIcon({
            name = pinned.name,
            class_name = pinned.class_name,
            exec = pinned.exec,
            icon = pinned.icon,
            is_running = active ~= nil,
            is_focused = active and active.is_active or false,
            instance_count = if active then active.instance_count else 0,
            address = if active then active.address else nil,
            scale = 1.0,
        }))
    end

    -- 2. Unpinned Running Applications
    local unpinned_children = {}
    for key, active in pairs(running_map) do
        if not pinned_classes[key] then
            table.insert(unpinned_children, DockAppIcon({
                name = active.title ~= "" and active.title or active.class_name,
                class_name = active.class_name,
                exec = active.class_name,
                is_running = true,
                is_focused = active.is_active,
                instance_count = active.instance_count,
                address = active.address,
                scale = 1.0,
            }))
        end
    end

    if #unpinned_children > 0 then
        -- Vertical separator
        table.insert(children, Zenith.Box({
            width = 1,
            height = 28,
            background = Zenith.hex(theme.outline_variant or theme.outline, 60),
        }))

        for _, item in ipairs(unpinned_children) do
            table.insert(children, item)
        end
    end

    -- 3. Utility Separator
    table.insert(children, Zenith.Box({
        width = 1,
        height = 28,
        background = Zenith.hex(theme.outline_variant or theme.outline, 60),
    }))

    -- 4. MPRIS Media Pill
    if Store.get("dockShowMpris", true) then
        table.insert(children, DockMprisPill())
    end

    -- 5. Quick Utilities (Terminal & Screenshot)
    table.insert(children, DockUtilities())

    -- 6. Trash Can
    if Store.get("dockShowTrash", false) then
        table.insert(children, DockTrash())
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "center",
        gap = DockDefaults.item_spacing,
        height = DockDefaults.get_height(),
        padding = {
            horizontal = DockDefaults.padding_horizontal,
            vertical = DockDefaults.padding_vertical,
        },
        background = glass.background,
        border_color = glass.border_color,
        border_width = glass.border_width,
        border_radius = glass.border_radius,
        shadow = glass.shadow,
        children = children,
    })
end

return DockBar
