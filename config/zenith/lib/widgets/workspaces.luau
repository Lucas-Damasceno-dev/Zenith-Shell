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

    local clients = (Zenith.Services.Clients and Zenith.Services.Clients()) or {}
    local clients_by_ws: { [number]: { string } } = {}
    
    local function resolve_client_icon(class: string?, initial_class: string?, title: string?): string
        local s = string.lower(string.format("%s %s %s", class or "", initial_class or "", title or ""))
        if s:find("terminal") or s:find("foot") or s:find("kitty") or s:find("alacritty") or s:find("ghostty") or s:find("wezterm") then
            return ""
        elseif s:find("firefox") or s:find("chrome") or s:find("brave") or s:find("zen") or s:find("chromium") or s:find("browser") then
            return "󰈹"
        elseif s:find("code") or s:find("vscodium") or s:find("cursor") or s:find("zed") or s:find("nvim") or s:find("editor") then
            return "󰨞"
        elseif s:find("thunar") or s:find("nautilus") or s:find("dolphin") or s:find("pcmanfm") or s:find("files") then
            return "󰉋"
        elseif s:find("discord") or s:find("vesktop") or s:find("telegram") or s:find("slack") or s:find("chat") then
            return "󰭹"
        elseif s:find("spotify") or s:find("ncspot") or s:find("music") then
            return "󰎆"
        elseif s:find("obs") or s:find("mpv") or s:find("vlc") or s:find("video") then
            return "󰕼"
        elseif s:find("steam") or s:find("lutris") or s:find("heroic") or s:find("game") then
            return ""
        elseif s:find("gimp") or s:find("inkscape") or s:find("blender") or s:find("paint") then
            return "󰽉"
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

    local cur_output = (Zenith.current_output and Zenith.current_output()) or "default"
    local has_monitor_binding = false
    for _, ws in ipairs(ws_list) do
        if ws.monitor and ws.monitor ~= "" then
            has_monitor_binding = true
            break
        end
    end

    -- Filter: Only show active workspace OR workspaces that have windows/clients (never special workspaces)
    local filtered_workspaces = {}
    local seen = {}
    for _, ws in ipairs(ws_list) do
        if ws.id < 0 or (ws.name and ws.name:find("^special")) then
            continue
        end
        if has_monitor_binding and cur_output ~= "default" and ws.monitor and ws.monitor ~= "" and ws.monitor ~= cur_output then
            continue
        end
        local wid = ws.id
        local is_active = (wid == active_id) or ws.active
        local has_win = (ws.windows and ws.windows > 0) or (clients_by_ws[wid] and #clients_by_ws[wid] > 0)
        if is_active or has_win then
            table.insert(filtered_workspaces, ws)
            seen[wid] = true
        end
    end

    -- Ensure active workspace is always present
    if not seen[active_id] then
        table.insert(filtered_workspaces, {
            id = active_id,
            name = tostring(active_id),
            active = true,
            urgent = false,
            windows = 0,
        })
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
        local default_icon = ws_default_icons[ws.id] or ""
        local label_text: string

        if app_icons and #app_icons > 0 then
            label_text = string.format("%d %s", ws.id, table.concat(app_icons, " "))
        elseif is_active then
            label_text = string.format("%s %d", default_icon, ws.id)
        else
            label_text = string.format("%s", default_icon)
        end

        if is_active then
            table.insert(children, Zenith.Box({
                height = 22,
                direction = "row",
                align_items = "center",
                justify_content = "center",
                padding = { x = 9, y = 1 },
                border_radius = 11,
                background = Zenith.hex(theme.primary, 220),
                border_color = Zenith.hex(theme.primary, 255),
                border_width = 1,
                on_click = string.format("dispatch:workspace:%d", ws.id),
                children = {
                    Zenith.Text({
                        text = label_text,
                        font_size = 11,
                        color = Zenith.hex(theme.on_primary),
                    })
                }
            }))
        elseif is_urgent then
            table.insert(children, Zenith.Box({
                height = 22,
                direction = "row",
                align_items = "center",
                justify_content = "center",
                padding = { x = 8, y = 1 },
                border_radius = 11,
                background = Zenith.hex(theme.error or "#f38ba8", 180),
                border_color = Zenith.hex(theme.error or "#f38ba8"),
                border_width = 1,
                on_click = string.format("dispatch:workspace:%d", ws.id),
                children = {
                    Zenith.Text({
                        text = label_text,
                        font_size = 11,
                        color = Zenith.hex("#ffffff"),
                    })
                }
            }))
        else
            table.insert(children, Zenith.Box({
                height = 22,
                direction = "row",
                align_items = "center",
                justify_content = "center",
                padding = { x = 8, y = 1 },
                border_radius = 11,
                background = Zenith.hex(theme.surface_container_high or theme.surface_container, 120),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 35),
                border_width = 1,
                on_click = string.format("dispatch:workspace:%d", ws.id),
                children = {
                    Zenith.Text({
                        text = label_text,
                        font_size = 11,
                        color = Zenith.hex(theme.on_surface, 210),
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
        on_scroll_up = "dispatch:workspace:e+1",
        on_scroll_down = "dispatch:workspace:e-1",
        children = children,
    })
end

return Workspaces
