--!strict
-- Zenith Desktop Shell — Application Launcher & Execution Service
-- Searches desktop applications, resolves icons, and launches subprocesses

local LauncherService = {
    name = "launcher",
    is_running = true,
}

export type ApplicationItem = {
    name: string,
    exec: string,
    icon: string,
    description: string,
    score: number?,
    id: string?,
    categories: { string }?,
}

function LauncherService.search(query: string?, limit: number?): { ApplicationItem }
    if Zenith.Services and Zenith.Services.Launcher then
        local raw = Zenith.Services.Launcher(query or "", limit or 30)
        local list = {}
        for _, app in ipairs(raw) do
            table.insert(list, {
                id = app.id or app.name,
                name = app.name or "",
                exec = app.exec or "",
                icon = app.icon or "application-default",
                description = app.comment or app.description or "",
                score = app.score or 0,
                categories = app.categories or {},
            })
        end
        return list
    end
    return {}
end

function LauncherService.launch(exec_cmd: string)
    if Zenith.Services and Zenith.Services.Launch then
        Zenith.Services.Launch(exec_cmd)
    elseif Zenith.launch then
        Zenith.launch(exec_cmd)
    elseif Zenith.exec then
        Zenith.exec(exec_cmd)
    end
end

function LauncherService.start()
    LauncherService.is_running = true
end

function LauncherService.stop()
    LauncherService.is_running = false
end

return LauncherService
