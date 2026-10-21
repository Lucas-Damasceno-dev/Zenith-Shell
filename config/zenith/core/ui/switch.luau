--!strict
-- Zenith Desktop Shell — Styled Switch Component
-- Animated toggle pill with responsive Matugen / Stylix colors and label wrappers

local Theme = Zenith.import("core/theme")

export type SwitchProps = {
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
        width = w,
        height = h,
    })

    if not p.label and not p.subtitle and not p.icon then
        return Zenith.Box({
            width = w,
            height = h,
            children = { switch_core },
        })
    end

    local text_column: { any } = {}

    if p.label then
        table.insert(text_column, Zenith.Text({
            text = p.label,
            font_family = "JetBrainsMono Nerd Font",
            font_size = 13,
            color = t.on_surface or "#ffffff",
            font_weight = "medium",
        }))
    end

    if p.subtitle then
        table.insert(text_column, Zenith.Text({
            text = p.subtitle,
            font_family = "JetBrainsMono Nerd Font",
            font_size = 11,
            color = Theme.alpha(t.on_surface_variant or t.on_surface or "#ffffff", 150),
        }))
    end

    local left_group: { any } = {}
    if p.icon then
        table.insert(left_group, Zenith.Text({
            text = p.icon,
            font_family = "JetBrainsMono Nerd Font",
            font_size = 16,
            color = t.primary or "#ffffff",
        }))
    end

    table.insert(left_group, Zenith.Box({
        flex_direction = "column",
        gap = 2,
        children = text_column,
    }))

    return Zenith.Box({
        width = "100%",
        flex_direction = "row",
        align_items = "center",
        justify_content = "space_between",
        gap = 12,
        children = {
            Zenith.Box({
                flex_direction = "row",
                align_items = "center",
                gap = 10,
                children = left_group,
            }),
            switch_core,
        },
    })
end

return Switch
