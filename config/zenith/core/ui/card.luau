--!strict
-- Zenith Desktop Shell — Glassmorphic Card & Surface Component
-- Material 3 elevation & Stylix base16 theme integration with frosted glass effects

local Theme = Zenith.import("core/theme")

export type CardProps = {
    id: string?,
    variant: string?, -- "glass" | "elevated" | "filled" | "outlined" | "dock" | "island"
    width: (number | string)?,
    height: (number | string)?,
    border_radius: number?,
    padding: any?, -- number | { horizontal: number?, vertical: number? }
    gap: number?,
    direction: string?,
    flex_direction: string?,
    align_items: string?,
    justify_content: string?,
    on_click: any?,
    on_right_click: any?,
    tooltip: string?,
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

    local align_it = p.align_items or "flex_start"
    if align_it == "flex-start" then align_it = "flex_start"
    elseif align_it == "flex-end" then align_it = "flex_end" end

    local just_ct = p.justify_content or "flex_start"
    if just_ct == "flex-start" then just_ct = "flex_start"
    elseif just_ct == "flex-end" then just_ct = "flex_end" end

    local f_dir = p.flex_direction or p.direction or "column"

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
        flex_direction = f_dir,
        align_items = align_it,
        justify_content = just_ct,
        on_click = p.on_click,
        on_right_click = p.on_right_click,
        tooltip = p.tooltip,
        children = p.children,
    })
end

return Card
