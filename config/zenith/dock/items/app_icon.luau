--!strict
-- Zenith Desktop Shell — Interactive Dock App Icon
-- Supports Gaussian magnification, focus dot indicators, focus/launch dispatch

local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")
local DockDefaults = Zenith.import("dock/defaults")

export type AppIconProps = {
    name: string,
    class_name: string,
    exec: string?,
    icon: string?,
    is_running: boolean?,
    is_focused: boolean?,
    instance_count: number?,
    address: string?,
    scale: number?,
    rise: number?,
}

local function DockAppIcon(props: AppIconProps)
    local theme = Theme.get()
    local is_running = props.is_running or false
    local is_focused = props.is_focused or false
    local scale = props.scale or 1.0

    local icon_glyph = props.icon or Icons.for_app(props.class_name, props.name)

    local on_click_action: string
    if is_running and props.address and props.address ~= "" then
        on_click_action = "focus:" .. props.address
    elseif props.exec and props.exec ~= "" then
        on_click_action = "launch:" .. props.exec
    else
        on_click_action = "launch:" .. props.class_name
    end

    local on_right_click_action: string
    if is_running and props.address and props.address ~= "" then
        on_right_click_action = "dispatch:closewindow:address:" .. props.address
    else
        on_right_click_action = on_click_action
    end

    local indicator_dot = if is_running then
        Zenith.Box({
            width = if is_focused then 12 else 4,
            height = 4,
            border_radius = 2,
            background = if is_focused
                then Zenith.hex(theme.primary)
                else Zenith.hex(theme.on_surface_variant, 140),
        })
    else
        Zenith.Box({ width = 4, height = 4, background = Zenith.rgba(0, 0, 0, 0) })

    local base_size = DockDefaults.get_icon_size()
    local final_size = math.round(base_size * scale)
    local font_sz = math.round(base_size * 0.5 * scale)

    return Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        gap = 2,
        width = base_size + 8,
        height = base_size + 8,
        cursor = "pointer",
        tooltip = string.format("%s%s", props.name, is_running and " (Executando)" or ""),
        on_click = on_click_action,
        on_right_click = on_right_click_action,
        children = {
            Zenith.Box({
                align_items = "center",
                justify_content = "center",
                width = final_size,
                height = final_size,
                border_radius = math.round(final_size * 0.28),
                background = if is_focused
                    then Zenith.hex(theme.primary_container, 150)
                    else Zenith.hex(theme.surface_container_highest, 90),
                border_color = if is_focused
                    then Zenith.hex(theme.primary, 180)
                    else Zenith.hex(theme.outline_variant or theme.outline, 35),
                border_width = 1,
                children = {
                    Zenith.Text({
                        text = icon_glyph,
                        font_family = "JetBrainsMono Nerd Font",
                        font_size = font_sz,
                        color = if is_focused
                            then Zenith.hex(theme.primary)
                            else Zenith.hex(theme.on_surface),
                    }),
                },
            }),
            indicator_dot,
        },
    })
end

return DockAppIcon
