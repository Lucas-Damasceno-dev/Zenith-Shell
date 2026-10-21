--!strict
-- Zenith Desktop Shell — Launcher Applications Grid / List
-- Container managing layout and selection states of app cards

local Theme = Zenith.import("core/theme")
local AppCard = Zenith.import("launcher/app_card")

local function LauncherGrid(props: {
    apps: { any },
    selected_index: number,
})
    local theme = Theme.get()
    local apps = props.apps
    local sel = props.selected_index

    if #apps == 0 then
        return Zenith.Box({
            direction = "column",
            align_items = "center",
            justify_content = "center",
            width = "100%",
            height = 200,
            gap = 8,
            children = {
                Zenith.Text({
                    text = "󰛉",
                    font_family = "JetBrainsMono Nerd Font",
                    font_size = 32,
                    color = Zenith.hex(theme.outline_variant or theme.outline, 120),
                }),
                Zenith.Text({
                    text = "Nenhum aplicativo correspondente",
                    font_family = "Inter",
                    font_size = 13,
                    color = Zenith.hex(theme.on_surface_variant),
                }),
            },
        })
    end

    local children = {}
    for idx, app in ipairs(apps) do
        table.insert(children, AppCard({
            app = app,
            index = idx,
            is_selected = idx == sel,
        }))
    end

    return Zenith.Box({
        direction = "column",
        width = "100%",
        gap = 6,
        children = children,
    })
end

return LauncherGrid
