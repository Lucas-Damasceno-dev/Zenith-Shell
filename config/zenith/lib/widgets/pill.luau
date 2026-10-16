--!strict
-- Zenith UI Kit - Reusable Glassmorphic Pill Component
-- Inspired by Quickshell PillWidget.qml (DesignTokens + Material You)

type PillProps = {
    icon: any?,
    icon_color: any?,
    icon_size: number?,
    icon_chip: boolean?,
    label: any?,
    label_color: any?,
    label_size: number?,
    badge: any?,
    badge_color: any?,
    variant: string?,
    height: number?,
    border_radius: number?,
    padding: { x: number, y: number }?,
    gap: number?,
    tooltip: any?,
    on_click: string?,
    on_right_click: string?,
    on_middle_click: string?,
    on_scroll_up: string?,
    on_scroll_down: string?,
    children: { any }?,
}

local function Pill(props: PillProps?)
    local theme = Zenith.Theme()
    local p = props or {}

    local h = p.height or 26
    local r = p.border_radius or math.floor(h / 2)
    local pad = p.padding or { x = 8, y = 2 }
    local g = p.gap or 5

    local variant = p.variant or "default"

    -- Variant-driven color system
    local bg: any
    local border_col: any
    local icon_default_col = theme.primary
    local label_default_col = theme.on_surface

    if variant == "primary" or variant == "active" then
        bg = Zenith.hex(theme.primary, 190)
        border_col = Zenith.hex(theme.primary, 230)
        icon_default_col = theme.on_primary
        label_default_col = theme.on_primary
    elseif variant == "secondary" then
        bg = Zenith.hex(theme.surface_container_high or theme.surface_container, 160)
        border_col = Zenith.hex(theme.outline_variant or theme.outline, 50)
        icon_default_col = theme.secondary or theme.primary
        label_default_col = theme.on_surface
    elseif variant == "danger" or variant == "urgent" then
        bg = Zenith.hex(theme.error or "#f38ba8", 45)
        border_col = Zenith.hex(theme.error or "#f38ba8", 120)
        icon_default_col = theme.error or "#f38ba8"
        label_default_col = theme.on_surface
    elseif variant == "accent_chip" then
        bg = Zenith.hex(theme.primary, 35)
        border_col = Zenith.hex(theme.primary, 100)
        icon_default_col = theme.primary
        label_default_col = theme.primary
    else -- "default" glass surface
        bg = p.background or Zenith.hex(theme.surface_container, 130)
        border_col = p.border_color or Zenith.hex(theme.outline_variant or theme.outline, 45)
    end

    if p.background then bg = p.background end
    if p.border_color then border_col = p.border_color end

    local content_children = {}

    local function has_content(val: any): boolean
        if val == nil then
            return false
        end
        if type(val) == "string" then
            return #val > 0
        end
        return true -- Signals, functions reativas, números
    end

    -- Custom children override
    if p.children and #p.children > 0 then
        content_children = p.children
    else
        -- Icon
        if has_content(p.icon) then
            local icol = p.icon_color or icon_default_col
            local isize = p.icon_size or 12
            local icon_text_node = Zenith.Text({
                text = p.icon,
                font_size = isize,
                color = if type(icol) == "string" then Zenith.hex(icol) else icol,
            })

            if p.icon_chip then
                table.insert(content_children, Zenith.Box({
                    padding = { x = 4, y = 1 },
                    border_radius = math.floor(h / 2),
                    background = if type(icol) == "string" then Zenith.hex(icol, 30) else Zenith.rgba(255, 255, 255, 20),
                    children = { icon_text_node },
                }))
            else
                table.insert(content_children, icon_text_node)
            end
        end

        -- Label
        if has_content(p.label) then
            local lcol = p.label_color or label_default_col
            local lsize = p.label_size or 11
            table.insert(content_children, Zenith.Text({
                text = p.label,
                font_size = lsize,
                color = if type(lcol) == "string" then Zenith.hex(lcol) else lcol,
            }))
        end

        -- Badge counter
        if has_content(p.badge) then
            local bcol = p.badge_color or theme.primary
            table.insert(content_children, Zenith.Box({
                padding = { x = 4, y = 1 },
                border_radius = 8,
                background = if type(bcol) == "string" then Zenith.hex(bcol, 60) else Zenith.rgba(255, 255, 255, 40),
                children = {
                    Zenith.Text({
                        text = p.badge,
                        font_size = 9,
                        color = if type(bcol) == "string" then Zenith.hex(bcol) else bcol,
                    })
                }
            }))
        end
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "center",
        height = h,
        padding = pad,
        gap = g,
        border_radius = r,
        background = bg,
        border_color = border_col,
        border_width = 1,
        tooltip = p.tooltip,
        on_click = p.on_click,
        on_right_click = p.on_right_click,
        on_middle_click = p.on_middle_click,
        on_scroll_up = p.on_scroll_up,
        on_scroll_down = p.on_scroll_down,
        badge = p.badge,
        badge_color = p.badge_color,
        icon = p.icon,
        icon_color = p.icon_color,
        label = p.label,
        children = content_children,
    })
end

return Pill
