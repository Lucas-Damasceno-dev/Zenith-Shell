--!strict
-- Zenith Design System - Glassmorphic Card & Surface Component
-- Material 3 elevation & Stylix base16 theme integration with frosted glass effects

local Theme = Zenith.import("theme")

type CardProps = {
    id: string?,
    variant: string?, -- "glass" | "elevated" | "filled" | "outlined"
    width: (number | string)?,
    height: (number | string)?,
    border_radius: number?,
    padding: any?, -- number | { horizontal: number?, vertical: number? } | etc.
    gap: number?,
    flex_direction: string?,
    align_items: string?,
    justify_content: string?,
    on_click: any?,
    on_right_click: any?,
    children: { any }?,
}

local function Card(props: CardProps?)
    local p = props or {}
    local r = p.border_radius or 14
    local v = p.variant or "glass"

    local glass_spec = Theme.glass(v, r)

    local pad_spec = p.padding or { horizontal = 14, vertical = 12 }
    if typeof(pad_spec) == "number" then
        pad_spec = { horizontal = pad_spec, vertical = pad_spec }
    end

    return Zenith.Box({
        id = p.id,
        width = p.width,
        height = p.height,
        background = glass_spec.background,
        border_color = glass_spec.border_color,
        border_width = glass_spec.border_width,
        border_radius = glass_spec.border_radius,
        shadow = glass_spec.shadow,
        padding = pad_spec,
        gap = p.gap or 8,
        flex_direction = p.flex_direction or "column",
        align_items = p.align_items,
        justify_content = p.justify_content,
        on_click = p.on_click,
        on_right_click = p.on_right_click,
        children = p.children,
    })
end

return Card
