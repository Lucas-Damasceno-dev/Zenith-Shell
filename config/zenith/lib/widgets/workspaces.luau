--!strict
-- Zenith UI Kit - Dynamic Workspaces Cluster Component (Quickshell / Caelestia style)
-- Matches WorkspaceIndicator.qml (Multi-monitor filtering, active pill expansion, occupied/empty states & m+1/m-1 scroll)

local function Workspaces(props: { active: number?, count: number?, output: string? }?)
    local theme = Zenith.Theme()
    local snap = Zenith.Services.Workspaces()
    local active_id = (props and props.active) or (snap and snap.active) or 1
    local ws_list = (snap and snap.workspaces) or {}

    local cur_output = (props and props.output) 
        or (Zenith.current_output and Zenith.current_output()) 
        or (Zenith.get_current_output and Zenith.get_current_output()) 
        or "default"

    local clients = (Zenith.Services.Clients and Zenith.Services.Clients()) or {}
    local clients_by_ws: { [number]: { string } } = {}

    local function resolve_client_icon(class: string?, initial_class: string?, title: string?): string
        local s = string.lower(string.format("%s %s %s", class or "", initial_class or "", title or ""))
        -- Foot & Terminals
        if s:find("foot") or s:find("kitty") or s:find("alacritty") or s:find("ghostty") or s:find("wezterm") or s:find("terminal") then
            return ""
        -- Browsers
        elseif s:find("brave") then
            return "󰖟"
        elseif s:find("firefox") or s:find("zen") then
            return "󰈹"
        elseif s:find("chrome") or s:find("chromium") or s:find("browser") then
            return ""
        -- Editors / IDEs
        elseif s:find("code") or s:find("vscode") or s:find("vscodium") or s:find("cursor") or s:find("zed") then
            return "󰨞"
        elseif s:find("nvim") or s:find("neovim") then
            return ""
        -- File Managers
        elseif s:find("thunar") or s:find("nautilus") or s:find("dolphin") or s:find("pcmanfm") or s:find("files") then
            return "󰉋"
        -- Communication
        elseif s:find("discord") or s:find("vesktop") then
            return "󰭹"
        elseif s:find("telegram") then
            return ""
        elseif s:find("slack") then
            return "󰒱"
        -- Audio / Media
        elseif s:find("spotify") or s:find("ncspot") or s:find("music") then
            return "󰎆"
        elseif s:find("obs") or s:find("mpv") or s:find("vlc") or s:find("video") then
            return "󰕼"
        -- Gaming
        elseif s:find("steam") or s:find("lutris") or s:find("heroic") or s:find("game") then
            return ""
        -- Creativity
        elseif s:find("gimp") or s:find("inkscape") or s:find("blender") or s:find("paint") then
            return "󰽉"
        elseif s:find("obsidian") then
            return "󰠮"
        -- System
        elseif s:find("settings") or s:find("control") or s:find("pavucontrol") then
            return "󰒓"
        else
            return ""
        end
    end

    for _, c in ipairs(clients) do
        local wid = c.workspace_id or 1
        if wid < 0 and c.workspace_name then
            local orig = tonumber(c.workspace_name:match("special:minimized_(%d+)"))
            if orig then
                wid = orig
            end
        end
        if wid > 0 then
            if not clients_by_ws[wid] then
                clients_by_ws[wid] = {}
            end
            local icon = resolve_client_icon(c.class, c.initial_class, c.title)
            local exists = false
            for _, existing in ipairs(clients_by_ws[wid]) do
                if existing == icon then
                    exists = true
                    break
                end
            end
            if not exists and #clients_by_ws[wid] < 3 then
                table.insert(clients_by_ws[wid], icon)
            end
        end
    end

    -- Check if workspaces carry monitor metadata
    local has_monitor_binding = false
    for _, ws in ipairs(ws_list) do
        if ws.monitor and ws.monitor ~= "" then
            has_monitor_binding = true
            break
        end
    end

    -- Strict filtering of workspaces by current_output
    local filtered_workspaces = {}
    local seen: { [number]: boolean } = {}

    for _, ws in ipairs(ws_list) do
        -- Skip special scratchpads or negative ids
        if ws.id < 0 or (ws.name and ws.name:find("^special")) then
            continue
        end

        -- Multi-monitor strict filter: if monitor binding exists, match only current_output
        if has_monitor_binding and cur_output ~= "default" and ws.monitor and ws.monitor ~= "" and ws.monitor ~= cur_output then
            continue
        end

        table.insert(filtered_workspaces, ws)
        seen[ws.id] = true
    end

    -- Ensure minimum workspace slots (default 5 slots or props.count) for visual continuity
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

    -- Ensure active workspace is always present
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

    local ws_default_icons = {
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

    local children = {}

    for _, ws in ipairs(filtered_workspaces) do
        local is_active = (ws.id == active_id) or ws.active
        local is_urgent = ws.urgent
        local app_icons = clients_by_ws[ws.id]
        local has_win = (ws.windows and ws.windows > 0) or (app_icons and #app_icons > 0)
        local default_icon = ws_default_icons[ws.id] or ""
        local label_text: string

        if is_active then
            -- 1. Active Workspace: Expanded pill with primary theme color
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
                padding = { x = 11, y = 1 },
                border_radius = 11,
                background = Zenith.hex(theme.primary, 230),
                border_color = Zenith.hex(theme.primary, 255),
                border_width = 1,
                cursor = "pointer",
                tooltip = string.format("Workspace %d (Ativo)\n• Clique: Focar Workspace\n• Botão Direito: Toggle Especial (sp%d)\n• Scroll: Alternar Workspaces", ws.id, ws.id),
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
            -- 2. Urgent Workspace: Alerting error color pill
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
                padding = { x = 8, y = 1 },
                border_radius = 11,
                background = Zenith.hex(theme.error or "#f38ba8", 200),
                border_color = Zenith.hex(theme.error or "#f38ba8", 255),
                border_width = 1,
                cursor = "pointer",
                tooltip = string.format("Workspace %d (Atenção / Urgente)\n• Clique: Atender Janela", ws.id),
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
            -- 3. Occupied Workspace (com janelas): Surface container highlight com ícones dos apps
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
                padding = { x = 8, y = 1 },
                border_radius = 11,
                background = Zenith.hex(theme.surface_container_highest or theme.surface_container_high or theme.surface_container, 170),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 65),
                border_width = 1,
                cursor = "pointer",
                tooltip = string.format("Workspace %d (%d janelas)\n• Clique: Mudar para Workspace %d\n• Botão Direito: Toggle Especial (sp%d)\n• Scroll: Alternar Workspaces", ws.id, ws.windows or (app_icons and #app_icons) or 1, ws.id, ws.id),
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
            -- 4. Empty Workspace (vazio): Indicador compacto sutil
            label_text = string.format("%s", default_icon)

            table.insert(children, Zenith.Box({
                height = 22,
                direction = "row",
                align_items = "center",
                justify_content = "center",
                padding = { x = 6, y = 1 },
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
        padding = { x = 4, y = 2 },
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
