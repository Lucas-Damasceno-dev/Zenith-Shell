--!strict
-- Zenith Desktop Shell — Bar Left Cluster
-- Orchestrates Launcher, Workspaces, Overview and FocusedApp

local Store = Zenith.import("core/store")
local Widgets = Zenith.import("widgets/init")

local function LeftCluster(props: { compact: boolean?, height: number? }?)
    local children = {}

    local show_launcher = Store.get("showLauncherButton", true)
    local show_workspaces = Store.get("showWorkspaceSwitcher", true)
    local show_overview = Store.get("showOverviewButton", true)
    local show_focused_app = Store.get("showFocusedApp", true)

    if show_launcher then
        table.insert(children, Widgets.Launcher())
    end

    if show_workspaces then
        table.insert(children, Widgets.Workspaces())
    end

    if show_overview then
        table.insert(children, Widgets.Overview())
    end

    if show_focused_app then
        table.insert(children, Widgets.FocusedApp())
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = 6,
        children = children,
    })
end

return LeftCluster
