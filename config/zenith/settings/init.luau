--!strict
-- Zenith Desktop Shell — Inir-Style Unified Settings Surface & Control Center
-- Combines identity header, live pill search, categorized navigation rail and deep modular pages

local Store = Zenith.import("core/store")
local Components = Zenith.import("settings/components")
local Navigation = Zenith.import("settings/navigation")

-- Core Pages (0 to 7)
local GeneralPage = Zenith.import("settings/pages/general")
local AppearancePage = Zenith.import("settings/pages/appearance")
local WallpaperPage = Zenith.import("settings/pages/wallpaper")
local BarPage = Zenith.import("settings/pages/bar")
local DockPage = Zenith.import("settings/pages/dock")
local LauncherPage = Zenith.import("settings/pages/launcher")
local OsdPage = Zenith.import("settings/pages/osd")
local WidgetsPage = Zenith.import("settings/pages/widgets")

-- Extra System Pages (8 to 16)
local ExtraPages = Zenith.import("settings/pages/extra")

local function SettingsWindow(props: { active_page: number? }?)
    local pal = Components.get_palette()

    local active_page: number
    if props and props.active_page ~= nil then
        active_page = props.active_page
    else
        active_page = Store.get("settings_active_page", 0)
    end

    local search_query = Store.get("settings_search_query", "")
    local easy_mode = Store.get("settingsEasyMode", false)
    local cur_page_meta = Navigation.get_page(active_page)

    local page_content: any
    if active_page == 0 then
        page_content = GeneralPage()
    elseif active_page == 1 then
        page_content = AppearancePage()
    elseif active_page == 2 then
        page_content = WallpaperPage()
    elseif active_page == 3 then
        page_content = BarPage()
    elseif active_page == 4 then
        page_content = DockPage()
    elseif active_page == 5 then
        page_content = LauncherPage()
    elseif active_page == 6 then
        page_content = OsdPage()
    elseif active_page == 7 then
        page_content = WidgetsPage()
    else
        page_content = ExtraPages.render(active_page)
    end

    return Zenith.Box({
        direction = "column",
        width = 1040,
        height = 660,
        padding = 10,
        gap = 10,
        border_radius = 20,
        background = pal.colLayer0,
        border_color = pal.colBorderSubtle,
        border_width = 1,
        shadow = {
            color = Zenith.hex("#000000", 110),
            blur = 28,
            offset_x = 0,
            offset_y = 12,
        },
        children = {
            -- Inir Master Top Header Bar (Identity + Search Pill + Actions)
            Components.Header({
                active_page_name = if cur_page_meta then cur_page_meta.name else "Geral",
                search_query = search_query,
                results_count = #Navigation.search_pages(search_query),
                easy_mode = easy_mode,
            }),

            -- Body: Left Navigation Rail + Right Content Area
            Zenith.Box({
                direction = "row",
                width = "100%",
                height = 588,
                gap = 10,
                children = {
                    -- Left Navigation Rail
                    Navigation.component({
                        active_page = active_page,
                        search_query = search_query,
                        easy_mode = easy_mode,
                    }),

                    -- Right Content Card Container
                    Zenith.Box({
                        direction = "column",
                        width = 788,
                        height = "100%",
                        padding = 16,
                        gap = 12,
                        background = pal.colLayer1,
                        border_width = 1,
                        border_color = pal.colBorderSubtle,
                        border_radius = 16,
                        children = {
                            page_content,
                        },
                    }),
                },
            }),
        },
    })
end

local mod = {
    id = "settings",
    widget = SettingsWindow,
}

setmetatable(mod, {
    __call = function(_, props)
        return SettingsWindow(props)
    end,
})

return mod
