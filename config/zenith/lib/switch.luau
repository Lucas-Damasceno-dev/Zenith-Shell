--!strict
-- Zenith Design System - Styled Switch Component
-- Animated toggle pill with responsive Matugen / Stylix colors and label wrappers

local Theme = Zenith.import("theme")

type SwitchProps = {
    id: string?,
    checked: boolean?,
    label: string?,
    subtitle: string?,
    icon: string?,
    width: number?,
    height: number?,
    active_color: any?,
    inactive_color: any?,
    thumb_color: any?,
    on_toggle: any?,
}

local function Switch(props: SwitchProps?)
    local p = props or {}
    local t = Theme.get()

    local is_checked = p.checked or false
    local w = p.width or 44
    local h = p.height or 24

    local active_col = p.active_color or t.primary
    local inactive_col = p.inactive_color or Theme.alpha(t.surface_container_highest or t.surface, 160)
    local thumb_col = p.thumb_color or t.on_primary or "#ffffff"

    local switch_core = Zenith.Switch({
        id = p.id,
        checked = is_checked,
        active_color = active_col,
        inactive_color = inactive_col,
        thumb_color = thumb_col,
        on_toggle = p.on_toggle,
    })

    -- Bare switch widget if no labels/icons requested
    if not p.label and not p.subtitle and not p.icon then
        return Zenith.Box({
            width = w,
            height = h,
            children = { switch_core },
        })
    end

    -- Compound row with title/description on left and switch on right
    local text_column: { any } = {}

    if p.label then
        table.insert(text_column, Zenith.Text({
            text = p.label,
            font_size = 13,
            color = t.on_surface or "#ffffff",
            font_weight = "medium",
        }))
    end

    if p.subtitle then
        table.insert(text_column, Zenith.Text({
            text = p.subtitle,
            font_size = 11,
            color = Theme.alpha(t.on_surface_variant or t.on_surface or "#ffffff", 160),
        }))
    end

    local row_elements: { any } = {}

    if p.icon then
        table.insert(row_elements, Zenith.Text({
            text = p.icon,
            font_size = 16,
            color = if is_checked then active_col else Theme.alpha(t.on_surface or "#ffffff", 180),
        }))
    end

    table.insert(row_elements, Zenith.Box({
        flex_grow = 1,
        flex_direction = "column",
        gap = 2,
        children = text_column,
    }))

    table.insert(row_elements, Zenith.Box({
        width = w,
        height = h,
        children = { switch_core },
    }))

    return Zenith.Box({
        flex_direction = "row",
        align_items = "center",
        justify_content = "space_between",
        gap = 10,
        children = row_elements,
    })
end

return Switch
