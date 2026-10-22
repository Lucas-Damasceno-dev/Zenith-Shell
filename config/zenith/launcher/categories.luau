--!strict
-- Zenith Desktop Shell — Launcher Categories Filter
-- Horizontal filter chips for quick category sorting

local Theme = Zenith.import("core/theme")
local LauncherDefaults = Zenith.import("launcher/defaults")

local function LauncherCategories(props: { active: string? }?)
    local theme = Theme.get()
    local active = if props and props.active then props.active else "Todos"

    local chips = {}
    for _, cat in ipairs(LauncherDefaults.categories) do
        local is_sel = cat == active
        table.insert(chips, Zenith.Box({
            cursor = "pointer",
            padding = { horizontal = 12, vertical = 4 },
            border_radius = 12,
            background = if is_sel
                then Zenith.hex(theme.primary)
                else Zenith.hex(theme.surface_container_highest, 90),
            border_color = if is_sel
                then Zenith.hex(theme.primary)
                else Zenith.hex(theme.outline_variant or theme.outline, 35),
            border_width = 1,
            on_click = "storage:set:launcher_category:" .. cat,
            children = {
                Zenith.Text({
                    text = cat,
                    font_family = "Inter",
                    font_size = 12,
                    font_weight = if is_sel then "semibold" else "normal",
                    color = if is_sel
                        then Zenith.hex(theme.on_primary)
                        else Zenith.hex(theme.on_surface_variant),
                }),
            },
        }))
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = 8,
        width = "100%",
        children = chips,
    })
end

return LauncherCategories
