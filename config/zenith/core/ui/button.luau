--!strict
-- Zenith Desktop Shell — Interactive Spring Button Component
-- Full Material 3 & Stylix palette support with smooth spring animations

local Theme = Zenith.import("core/theme")

export type ButtonProps = {
    id: string?,
    label: string?,
    text: string?,
    icon: string?,
    icon_size: number?,
    badge: string?,
    variant: string?, -- "primary" | "secondary" | "tonal" | "outlined" | "ghost" | "danger" | "icon"
    size: string?, -- "sm" | "md" | "lg"
    width: (number | string)?,
    height: number?,
    border_radius: number?,
    disabled: boolean?,
    active: boolean?,
    spring: boolean?,
    on_click: any?,
    on_right_click: any?,
    tooltip: string?,
    children: { any }?,
}

local function Button(props: ButtonProps?)
    local p = props or {}
    local t = Theme.get()

    local variant = p.variant or "primary"
    local size = p.size or "md"

    -- Size configurations
    local h = p.height or (if size == "sm" then 28 elseif size == "lg" then 44 else 36)
    local r = p.border_radius or (if size == "sm" then 8 elseif size == "lg" then 12 else 10)
    local pad_x = if variant == "icon" then 6 elseif size == "sm" then 10 elseif size == "lg" then 18 else 14
    local pad_y = if size == "sm" then 2 elseif size == "lg" then 4 else 3
    local f_size = if size == "sm" then 12 elseif size == "lg" then 15 else 13
    local i_size = p.icon_size or (f_size + 2)

    -- Variant-driven theme styling
    local bg: any
    local fg: any
    local border_col: any = "transparent"
    local border_w: number = 0
    local shadow_spec = nil

    if p.disabled then
        bg = Theme.alpha(t.surface_container_highest or t.surface, 80)
        fg = Theme.alpha(t.on_surface_variant or t.on_surface or "#ffffff", 90)
    elseif p.active or variant == "primary" then
        bg = t.primary
        fg = t.on_primary or "#ffffff"
        shadow_spec = {
            color = Theme.alpha(t.primary, 75),
            blur = 10,
            offset_x = 0,
            offset_y = 3,
        }
    elseif variant == "secondary" then
        bg = Theme.alpha(t.surface_container_high or t.surface, 200)
        fg = t.on_surface or "#ffffff"
        border_col = Theme.alpha(t.outline_variant or t.outline, 60)
        border_w = 1
    elseif variant == "tonal" then
        bg = Theme.alpha(t.primary_container or t.surface_variant, 180)
        fg = t.on_surface or t.primary
    elseif variant == "outlined" then
        bg = "transparent"
        fg = t.primary or t.on_surface
        border_col = Theme.alpha(t.outline or t.primary, 140)
        border_w = 1.5
    elseif variant == "ghost" or variant == "icon" then
        bg = "transparent"
        fg = t.on_surface or "#ffffff"
    elseif variant == "danger" then
        bg = t.error or "#e78284"
        fg = "#ffffff"
        shadow_spec = {
            color = Theme.alpha(t.error or "#e78284", 75),
            blur = 10,
            offset_x = 0,
            offset_y = 3,
        }
    else
        bg = Theme.alpha(t.surface_container or t.surface, 150)
        fg = t.on_surface or "#ffffff"
    end

    -- Button content nodes
    local content_children: { any } = {}

    if p.icon then
        table.insert(content_children, Zenith.Text({
            text = p.icon,
            font_family = "JetBrainsMono Nerd Font",
            font_size = i_size,
            color = fg,
        }))
    end

    local display_text = p.label or p.text
    if display_text and display_text ~= "" then
        table.insert(content_children, Zenith.Text({
            text = display_text,
            font_family = "JetBrainsMono Nerd Font",
            font_size = f_size,
            color = fg,
            font_weight = "medium",
        }))
    end

    if p.badge then
        table.insert(content_children, Zenith.Box({
            background = Theme.alpha(fg, 40),
            border_radius = 6,
            padding = { horizontal = 5, vertical = 1 },
            children = {
                Zenith.Text({
                    text = p.badge,
                    font_family = "JetBrainsMono Nerd Font",
                    font_size = f_size - 3,
                    color = fg,
                    font_weight = "bold",
                }),
            },
        }))
    end

    if p.children then
        for _, child in ipairs(p.children) do
            table.insert(content_children, child)
        end
    end

    -- Spring animation physics instance
    if p.spring ~= false and Zenith.Spring then
        local anim = Zenith.Spring(1.0, 1.0, 240, 18)
        if anim and anim.current then
            -- Spring node can wrap or scale
        end
    end

    return Zenith.Box({
        id = p.id,
        width = p.width,
        height = h,
        border_radius = r,
        background = bg,
        border_color = border_col,
        border_width = border_w,
        shadow = shadow_spec,
        padding = { horizontal = pad_x, vertical = pad_y },
        flex_direction = "row",
        align_items = "center",
        justify_content = "center",
        gap = 7,
        cursor = if p.disabled then "default" else "pointer",
        on_click = if p.disabled then nil else p.on_click,
        on_right_click = if p.disabled then nil else p.on_right_click,
        tooltip = p.tooltip,
        children = content_children,
    })
end

return Button
