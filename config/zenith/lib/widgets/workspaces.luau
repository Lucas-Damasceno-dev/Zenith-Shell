--!strict
-- Zenith UI Kit - Dynamic Workspaces Cluster Component (Quickshell / Caelestia style)

local function Workspaces(props: { active: number?, count: number? }?)
    local theme = Zenith.Theme()
    local snap = Zenith.Services.Workspaces()
    local active_id = (props and props.active) or (snap and snap.active) or 1
    local ws_list = (snap and snap.workspaces) or {}

    -- Fallback to default slots if empty
    if #ws_list == 0 then
        local count = props and props.count or 4
        for i = 1, count do
            table.insert(ws_list, {
                id = i,
                name = tostring(i),
                active = (i == active_id),
                urgent = false,
                windows = (i == 1 and 1 or 0),
            })
        end
    end

    local ws_icons: { [number]: string } = {
        [1] = "",  -- Terminal
        [2] = "󰈹",  -- Web / Browser
        [3] = "󰉋",  -- Files
        [4] = "󰨞",  -- Code / IDE
        [5] = "󰭹",  -- Chat / Social
        [6] = "󰎆",  -- Music
        [7] = "󰕼",  -- Video / Media
        [8] = "",  -- Gaming
        [9] = "",  -- Settings
    }

    local children = {}

    for _, ws in ipairs(ws_list) do
        local is_active = (ws.id == active_id) or ws.active
        local is_urgent = ws.urgent
        local has_windows = (ws.windows and ws.windows > 0)

        local icon = ws_icons[ws.id] or tostring(ws.id)

        if is_active then
            table.insert(children, Zenith.Box({
                padding = { x = 9, y = 2 },
                border_radius = 9,
                background = Zenith.hex(theme.primary),
                on_click = string.format("dispatch:workspace:%d", ws.id),
                children = {
                    Zenith.Text({
                        text = string.format("%d %s", ws.id, icon),
                        font_size = 11,
                        color = Zenith.hex(theme.on_primary),
                    })
                }
            }))
        elseif is_urgent then
            table.insert(children, Zenith.Box({
                padding = { x = 8, y = 2 },
                border_radius = 9,
                background = Zenith.hex("#e06c75"),
                on_click = string.format("dispatch:workspace:%d", ws.id),
                children = {
                    Zenith.Text({
                        text = string.format("%d %s", ws.id, icon),
                        font_size = 11,
                        color = Zenith.hex("#ffffff"),
                    })
                }
            }))
        elseif has_windows then
            table.insert(children, Zenith.Box({
                padding = { x = 8, y = 2 },
                border_radius = 9,
                background = Zenith.rgba(255, 255, 255, 18),
                on_click = string.format("dispatch:workspace:%d", ws.id),
                children = {
                    Zenith.Text({
                        text = string.format("%d %s", ws.id, icon),
                        font_size = 11,
                        color = Zenith.rgba(255, 255, 255, 210),
                    })
                }
            }))
        else
            table.insert(children, Zenith.Box({
                padding = { x = 6, y = 2 },
                border_radius = 9,
                background = Zenith.rgba(255, 255, 255, 6),
                on_click = string.format("dispatch:workspace:%d", ws.id),
                children = {
                    Zenith.Text({
                        text = tostring(ws.id),
                        font_size = 10,
                        color = Zenith.rgba(255, 255, 255, 75),
                    })
                }
            }))
        end
    end

    return Zenith.Box({
        direction = "row",
        gap = 4,
        padding = { x = 5, y = 2 },
        border_radius = 12,
        background = Zenith.rgba(255, 255, 255, 10),
        border_color = Zenith.rgba(255, 255, 255, 18),
        border_width = 1,
        children = children,
    })
end

return Workspaces
