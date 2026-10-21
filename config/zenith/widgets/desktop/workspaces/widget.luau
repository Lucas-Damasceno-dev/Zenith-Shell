--!strict
-- Zenith-Shell: Workspaces Cluster Component
-- Dynamic multi-monitor workspace indicators with active pill expansion

local Icons = Zenith.import("core/ui/icons")
local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")

type WorkspacesProps = {
    active: number?,
    count: number?,
    output: string?,
}

local WS_DEFAULT_ICONS = {
    [1] = "",
    [2] = "󰈹",
    [3] = "󰉋",
    [4] = "󰨞",
    [5] = "󰈙",
    [6] = "󰭹",
    [7] = "󰎆",
    [8] = "󰕼",
    [9] = "",
    [10] = "󰒓",
}

local function Workspaces(props: WorkspacesProps?)
    local theme = Theme.get()
    local snap = Services.Hyprland.workspaces()
    local active_id = (props and props.active) or (snap and snap.active) or 1
    local ws_list = (snap and snap.workspaces) or {}

    local cur_output = (props and props.output) 
        or (Zenith.current_output and Zenith.current_output()) 
        or (Zenith.get_current_output and Zenith.get_current_output()) 
        or "default"

    local clients = Services.Hyprland.clients()
    local clients_by_ws: { [number]: { string } } = {}

    for _, c in ipairs(clients) do
        local ws_id = c.workspace_id or 1
        if not clients_by_ws[ws_id] then
            clients_by_ws[ws_id] = {}
        end
        if #clients_by_ws[ws_id] < 3 then
            local icon = Icons.for_app(c.class, c.title)
            table.insert(clients_by_ws[ws_id], icon)
        end
    end

    local filtered_workspaces = {}
    local seen = {}

    for _, ws in ipairs(ws_list) do
        local ws_monitor = ws.monitor or "default"
        if cur_output == "default" or ws_monitor == cur_output then
            table.insert(filtered_workspaces, ws)
            seen[ws.id] = true
        end
    end

    local min_slots = (props and props.count) or 5
    for i = 1, min_slots do
        if not seen[i] then
            table.insert(filtered_workspaces, {
                id = i,
                name = tostring(i),
                monitor = cur_output,
                active = (i == active_id),
                urgent = false,
                windows = 0,
            })
            seen[i] = true
        end
    end

    if not seen[active_id] then
        table.insert(filtered_workspaces, {
            id = active_id,
            name = tostring(active_id),
            monitor = cur_output,
            active = true,
            urgent = false,
            windows = 0,
        })
        seen[active_id] = true
    end

    table.sort(filtered_workspaces, function(a, b) return a.id < b.id end)

    local children = {}

    for _, ws in ipairs(filtered_workspaces) do
        local is_active = (ws.id == active_id) or ws.active
        local is_urgent = ws.urgent
        local app_icons = clients_by_ws[ws.id]
        local has_win = (ws.windows and ws.windows > 0) or (app_icons and #app_icons > 0)
        local default_icon = WS_DEFAULT_ICONS[ws.id] or ""
        local label_text: string

        if is_active then
            if app_icons and #app_icons > 0 then
                label_text = string.format("%d %s", ws.id, table.concat(app_icons, " "))
            else
                label_text = string.format("%s %d", default_icon, ws.id)
            end

            table.insert(children, Zenith.Box({
                height = 22,
                direction = "row",
                align_items = "center",
                justify_content = "center",
                padding = { horizontal = 11, vertical = 1 },
                border_radius = 11,
                background = Zenith.hex(theme.primary, 230),
                border_color = Zenith.hex(theme.primary, 255),
                border_width = 1,
                cursor = "pointer",
                tooltip = string.format("Workspace %d (Ativo)\n• Clique: Focar Workspace\n• Botão Direito: Alternar Especial (sp%d)\n• Scroll: Alternar Workspaces", ws.id, ws.id),
                on_click = string.format("dispatch:workspace:%d", ws.id),
                on_right_click = string.format("dispatch:togglespecialworkspace:sp%d", ws.id),
                children = {
                    Zenith.Text({
                        text = label_text,
                        font_size = 11,
                        font_weight = "bold",
                        color = Zenith.hex(theme.on_primary),
                    })
                }
            }))
        elseif is_urgent then
            if app_icons and #app_icons > 0 then
                label_text = string.format("%d %s", ws.id, table.concat(app_icons, " "))
            else
                label_text = string.format("%s %d", default_icon, ws.id)
            end

            table.insert(children, Zenith.Box({
                height = 22,
                direction = "row",
                align_items = "center",
                justify_content = "center",
                padding = { horizontal = 8, vertical = 1 },
                border_radius = 11,
                background = Zenith.hex(theme.error or "#f38ba8", 200),
                border_color = Zenith.hex(theme.error or "#f38ba8", 255),
                border_width = 1,
                cursor = "pointer",
                tooltip = string.format("Workspace %d (Urgente)\n• Clique: Atender Janela", ws.id),
                on_click = string.format("dispatch:workspace:%d", ws.id),
                on_right_click = string.format("dispatch:togglespecialworkspace:sp%d", ws.id),
                children = {
                    Zenith.Text({
                        text = label_text,
                        font_size = 11,
                        color = Zenith.hex("#ffffff"),
                    })
                }
            }))
        elseif has_win then
            if app_icons and #app_icons > 0 then
                label_text = string.format("%d %s", ws.id, table.concat(app_icons, " "))
            else
                label_text = string.format("%s", default_icon)
            end

            table.insert(children, Zenith.Box({
                height = 22,
                direction = "row",
                align_items = "center",
                justify_content = "center",
                padding = { horizontal = 8, vertical = 1 },
                border_radius = 11,
                background = Zenith.hex(theme.surface_container_highest or theme.surface_container_high or theme.surface_container, 170),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 65),
                border_width = 1,
                cursor = "pointer",
                tooltip = string.format("Workspace %d (%d janelas)\n• Clique: Mudar para Workspace %d\n• Scroll: Alternar Workspaces", ws.id, ws.windows or (app_icons and #app_icons) or 1, ws.id),
                on_click = string.format("dispatch:workspace:%d", ws.id),
                on_right_click = string.format("dispatch:togglespecialworkspace:sp%d", ws.id),
                children = {
                    Zenith.Text({
                        text = label_text,
                        font_size = 11,
                        color = Zenith.hex(theme.on_surface, 225),
                    })
                }
            }))
        else
            label_text = string.format("%s", default_icon)

            table.insert(children, Zenith.Box({
                height = 22,
                direction = "row",
                align_items = "center",
                justify_content = "center",
                padding = { horizontal = 6, vertical = 1 },
                border_radius = 11,
                background = Zenith.hex(theme.surface_container_low or theme.surface_container, 70),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 25),
                border_width = 1,
                cursor = "pointer",
                tooltip = string.format("Workspace %d (Vazio)\n• Clique: Abrir Workspace %d\n• Scroll: Alternar Workspaces", ws.id, ws.id),
                on_click = string.format("dispatch:workspace:%d", ws.id),
                on_right_click = string.format("dispatch:togglespecialworkspace:sp%d", ws.id),
                children = {
                    Zenith.Text({
                        text = label_text,
                        font_size = 10,
                        color = Zenith.hex(theme.on_surface, 105),
                    })
                }
            }))
        end
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        height = 26,
        gap = 4,
        padding = { horizontal = 4, vertical = 2 },
        border_radius = 13,
        background = Zenith.hex(theme.surface_container, 110),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 40),
        border_width = 1,
        tooltip = "Workspaces • Scroll para navegar (m+1/m-1)",
        on_scroll_up = "dispatch:workspace:m+1",
        on_scroll_down = "dispatch:workspace:m-1",
        children = children,
    })
end

return Workspaces
