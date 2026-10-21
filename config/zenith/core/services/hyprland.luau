--!strict
-- Zenith Desktop Shell — Hyprland & Compositor Service
-- Bridges Hyprland IPC socket2, workspaces, windows, foreign toplevels and gaps

local HyprlandService = {
    name = "hyprland",
    is_running = true,
}

export type WorkspaceItem = {
    id: number,
    name: string,
    monitor: string?,
    active: boolean,
    urgent: boolean,
    windows: number,
}

export type WorkspacesData = {
    active: number,
    workspaces: { WorkspaceItem },
}

export type ActiveWindowData = {
    title: string,
    class: string,
    address: string?,
}

export type ClientItem = {
    address: string,
    title: string,
    class: string,
    workspace: number,
    workspace_id: number,
    focused: boolean,
}

export type ToplevelState = {
    active: boolean,
    minimized: boolean,
    maximized: boolean,
    fullscreen: boolean,
}

export type ToplevelHandle = {
    id: string,
    title: string,
    app_id: string,
    workspace: number?,
    state: ToplevelState,
    thumbnail_uri: string?,
    thumbnail_texture_id: number?,
}

function HyprlandService.workspaces(): WorkspacesData
    if Zenith.Services and Zenith.Services.Workspaces then
        return Zenith.Services.Workspaces()
    end
    return { active = 1, workspaces = {} }
end

function HyprlandService.active_window(): ActiveWindowData
    if Zenith.Services and Zenith.Services.ActiveWindow then
        return Zenith.Services.ActiveWindow()
    end
    return { title = "", class = "", address = "" }
end

function HyprlandService.clients(): { ClientItem }
    local list = {}
    local raw = if Zenith.Services and Zenith.Services.Clients then Zenith.Services.Clients() else {}
    for _, c in ipairs(raw) do
        local ws = c.workspace_id or c.workspace or 1
        table.insert(list, {
            address = c.address or "",
            title = c.title or "",
            class = c.class or "",
            workspace = ws,
            workspace_id = ws,
            focused = c.focused or false,
        })
    end
    return list
end

function HyprlandService.focus_window(address: string)
    if Zenith.Services and Zenith.Services.FocusWindow then
        Zenith.Services.FocusWindow(address)
    elseif Zenith.focus_window then
        Zenith.focus_window(address)
    end
end

-- Foreign Toplevel Management (zwlr_foreign_toplevel_management_v1)
function HyprlandService.toplevels(): { ToplevelHandle }
    if Zenith.Services and Zenith.Services.Toplevels then
        return Zenith.Services.Toplevels()
    end
    -- Fallback synthesis from Clients if foreign toplevel protocol not bound
    local clients = HyprlandService.clients()
    local list = {}
    for _, c in ipairs(clients) do
        table.insert(list, {
            id = c.address,
            title = c.title,
            app_id = c.class,
            workspace = c.workspace,
            state = {
                active = c.focused or false,
                minimized = false,
                maximized = false,
                fullscreen = false,
            },
            thumbnail_uri = nil,
            thumbnail_texture_id = nil,
        })
    end
    return list
end

function HyprlandService.toplevel_activate(id: string)
    if Zenith.Services and Zenith.Services.ToplevelActivate then
        Zenith.Services.ToplevelActivate(id)
    else
        HyprlandService.focus_window(id)
    end
end

function HyprlandService.toplevel_close(id: string)
    if Zenith.Services and Zenith.Services.ToplevelClose then
        Zenith.Services.ToplevelClose(id)
    else
        HyprlandService.dispatch("closewindow", "address:" .. id)
    end
end

function HyprlandService.toplevel_set_minimized(id: string, minimized: boolean)
    if Zenith.Services and Zenith.Services.ToplevelSetMinimized then
        Zenith.Services.ToplevelSetMinimized(id, minimized)
    end
end

function HyprlandService.toplevel_set_maximized(id: string, maximized: boolean)
    if Zenith.Services and Zenith.Services.ToplevelSetMaximized then
        Zenith.Services.ToplevelSetMaximized(id, maximized)
    end
end

function HyprlandService.gaps(): { inner: number, outer: number, gaps_in: number?, gaps_out: number? }
    if Zenith.Services and Zenith.Services.HyprlandGaps then
        return Zenith.Services.HyprlandGaps()
    end
    return { inner = 5, outer = 10, gaps_in = 5, gaps_out = 10 }
end

function HyprlandService.dispatch(dispatcher: string, arg: string?)
    if Zenith.dispatch then
        Zenith.dispatch(dispatcher, arg or "")
    end
end

function HyprlandService.switch_workspace(id: number)
    HyprlandService.dispatch("workspace", tostring(id))
end

function HyprlandService.start()
    HyprlandService.is_running = true
end

function HyprlandService.stop()
    HyprlandService.is_running = false
end

return HyprlandService
