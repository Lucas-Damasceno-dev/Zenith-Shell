--!strict
-- Zenith UI Kit - Workspaces Cluster Component

local function Workspaces(props: { active: number?, count: number? }?)
    local theme = Zenith.Theme()
    local active = props and props.active or 1
    local total = props and props.count or 4

    local icons = { "1 ", "2 ", "3 ", "4 󰎆", "5 󰣇" }
    local children = {}

    for i = 1, total do
        local is_active = (i == active)
        local bg = is_active and Zenith.hex(theme.primary) or (i <= 3 and Zenith.hex(theme.surface_container) or Zenith.hex("#00000000"))
        local fg = is_active and Zenith.hex(theme.on_primary) or (i <= 3 and Zenith.hex(theme.on_surface) or Zenith.hex("#6c757d"))
        local label = icons[i] or tostring(i)

        table.insert(children, Zenith.Box({
            padding = { x = is_active and 8 or 7, y = 2 },
            border_radius = 6,
            background = bg,
            on_click = string.format("cmd:notify-send 'Workspace' 'Switched to workspace %d'", i),
            children = {
                Zenith.Text({
                    text = label,
                    font_size = 10,
                    color = fg,
                })
            }
        }))
    end

    return Zenith.Box({
        direction = "row",
        gap = 3,
        padding = { x = 4, y = 3 },
        border_radius = 8,
        background = Zenith.hex(theme.surface),
        border_color = Zenith.hex("#2d3748"),
        border_width = 1,
        children = children,
    })
end

return Workspaces
