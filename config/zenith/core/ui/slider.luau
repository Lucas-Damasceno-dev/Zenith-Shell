--!strict
-- Zenith Desktop Shell — Styled Slider Component
-- Physical track, draggable thumb, and responsive M3 / Stylix color tokens

local Theme = Zenith.import("core/theme")

export type SliderProps = {
    id: string?,
    label: string?,
    min: number?,
    max: number?,
    value: number?,
    show_value: boolean?,
    icon_left: string?,
    icon_right: string?,
    width: (number | string)?,
    height: number?,
    track_height: number?,
    thumb_radius: number?,
    track_color: any?,
    active_track_color: any?,
    thumb_color: any?,
    on_change: any?,
}

local function Slider(props: SliderProps?)
    local p = props or {}
    local t = Theme.get()

    local min_v = p.min or 0
    local max_v = p.max or 100
    local cur_v = p.value or min_v
    local track_h = p.track_height or 6
    local thumb_r = p.thumb_radius or 8
    local h = p.height or 28

    local track_col = p.track_color or Theme.alpha(t.surface_container_highest or t.surface, 150)
    local active_col = p.active_track_color or t.primary
    local thumb_col = p.thumb_color or t.on_primary or "#ffffff"

    local slider_core = Zenith.Slider({
        id = p.id,
        min = min_v,
        max = max_v,
        value = cur_v,
        track_height = track_h,
        thumb_radius = thumb_r,
        track_color = track_col,
        active_track_color = active_col,
        thumb_color = thumb_col,
        on_change = p.on_change,
        width = if p.label or p.icon_left or p.icon_right then "100%" else p.width,
    })

    if not p.label and not p.icon_left and not p.icon_right and not p.show_value then
        return slider_core
    end

    local row_children: { any } = {}

    if p.icon_left then
        table.insert(row_children, Zenith.Text({
            text = p.icon_left,
            font_family = "JetBrainsMono Nerd Font",
            font_size = 14,
            color = t.on_surface or "#ffffff",
        }))
    end

    if p.label then
        table.insert(row_children, Zenith.Text({
            text = p.label,
            font_family = "JetBrainsMono Nerd Font",
            font_size = 13,
            color = t.on_surface or "#ffffff",
            font_weight = "medium",
        }))
    end

    table.insert(row_children, Zenith.Box({
        width = "100%",
        flex_direction = "row",
        align_items = "center",
        children = { slider_core },
    }))

    if p.show_value then
        table.insert(row_children, Zenith.Text({
            text = string.format("%d%%", math.floor(cur_v)),
            font_family = "JetBrainsMono Nerd Font",
            font_size = 12,
            color = Theme.alpha(t.on_surface or "#ffffff", 180),
        }))
    end

    if p.icon_right then
        table.insert(row_children, Zenith.Text({
            text = p.icon_right,
            font_family = "JetBrainsMono Nerd Font",
            font_size = 14,
            color = t.on_surface or "#ffffff",
        }))
    end

    return Zenith.Box({
        width = p.width or "100%",
        height = h,
        flex_direction = "row",
        align_items = "center",
        gap = 8,
        children = row_children,
    })
end

return Slider
