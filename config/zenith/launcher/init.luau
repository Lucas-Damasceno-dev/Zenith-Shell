--!strict
-- Zenith Desktop Shell — Master Application Launcher Surface
-- Full keyboard navigation, live search, categories, and native compositor integration

local Theme = Zenith.import("core/theme")
local Store = Zenith.import("core/store")
local Services = Zenith.import("core/services/init")
local LauncherDefaults = Zenith.import("launcher/defaults")
local LauncherHeader = Zenith.import("launcher/header")
local LauncherCategories = Zenith.import("launcher/categories")
local LauncherGrid = Zenith.import("launcher/grid")
local LauncherActions = Zenith.import("launcher/actions")

local function Launcher(props: { query: string?, selected_index: number? }?)
    local theme = Theme.get()
    local glass = Theme.glass("dock", LauncherDefaults.border_radius)

    local query = if props and props.query ~= nil
        then props.query
        elseif Zenith.get_search_query then Zenith.get_search_query()
        else ""

    local selected_index = if props and props.selected_index ~= nil
        then props.selected_index
        elseif Zenith.get_selected_index then Zenith.get_selected_index()
        else 1

    local apps = Services.Launcher.search(query, LauncherDefaults.max_results)

    local active_category = Store.get("launcher_category", "Todos")
    local category_map: { [string]: { string } } = {
        Desenvolvimento = { "development", "ide", "programming" },
        Internet = { "network", "webbrowser", "internet" },
        ["Multimídia"] = { "audiovideo", "audio", "video", "multimedia", "graphics" },
        ["Utilitários"] = { "utility", "accessories", "utilities" },
        Sistema = { "system", "settings" },
    }

    local filtered_apps = {}
    if active_category == "Todos" or active_category == "" then
        filtered_apps = apps
    else
        local allowed = category_map[active_category] or { string.lower(active_category) }
        for _, app in ipairs(apps) do
            local matched = false
            if app.categories and type(app.categories) == "table" then
                for _, cat in ipairs(app.categories) do
                    local cl = string.lower(cat)
                    for _, target in ipairs(allowed) do
                        if string.find(cl, target, 1, true) then
                            matched = true
                            break
                        end
                    end
                    if matched then break end
                end
            end
            if matched then
                table.insert(filtered_apps, app)
            end
        end
    end

    return Zenith.Box({
        direction = "column",
        width = LauncherDefaults.width,
        height = LauncherDefaults.height,
        padding = 16,
        gap = 12,
        background = glass.background,
        border_color = glass.border_color,
        border_width = glass.border_width,
        border_radius = glass.border_radius,
        shadow = glass.shadow,
        children = {
            LauncherHeader({
                query = query,
                result_count = #filtered_apps,
            }),
            LauncherCategories({ active = active_category }),
            Zenith.Box({
                direction = "column",
                width = "100%",
                height = 360,
                children = {
                    LauncherGrid({
                        apps = filtered_apps,
                        selected_index = selected_index,
                    }),
                },
            }),
            LauncherActions(),
        },
    })
end

local mod = {
    id = "launcher",
    widget = Launcher,
}

setmetatable(mod, {
    __call = function(_, props)
        return Launcher(props)
    end,
})

return mod
