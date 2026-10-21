--!strict
-- Zenith Desktop Shell — Launcher App Card Item
-- Interactive application card with keyboard navigation highlight and launch action

local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")

export type AppCardProps = {
    app: {
        name: string,
        exec: string,
        icon: string,
        description: string,
        id: string?,
        score: number?,
    },
    index: number,
    is_selected: boolean,
}

local function AppCard(props: AppCardProps)
    local theme = Theme.get()
    local app = props.app
    local is_sel = props.is_selected

    local glyph = Icons.for_app(app.name, app.name)
    local desc = if app.description ~= "" then app.description else app.exec
    if #desc > 36 then
        desc = string.sub(desc, 1, 33) .. "…"
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space_between",
        width = "100%",
        height = 54,
        padding = { horizontal = 14, vertical = 6 },
        border_radius = 14,
        background = if is_sel
            then Zenith.hex(theme.primary_container, 180)
            else Zenith.hex(theme.surface_container_highest, 70),
        border_color = if is_sel
            then Zenith.hex(theme.primary, 190)
            else Zenith.hex(theme.outline_variant or theme.outline, 30),
        border_width = 1,
        cursor = "pointer",
        tooltip = app.name .. "\n" .. app.exec,
        on_click = "launch:" .. app.exec,
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 12,
                children = {
                    Zenith.Box({
                        width = 38,
                        height = 38,
                        border_radius = 10,
                        background = if is_sel
                            then Zenith.hex(theme.primary, 140)
                            else Zenith.hex(theme.surface_container, 120),
                        align_items = "center",
                        justify_content = "center",
                        children = {
                            Zenith.Text({
                                text = glyph,
                                font_family = "JetBrainsMono Nerd Font",
                                font_size = 18,
                                color = if is_sel
                                    then Zenith.hex(theme.on_primary)
                                    else Zenith.hex(theme.primary),
                            }),
                        },
                    }),
                    Zenith.Box({
                        direction = "column",
                        gap = 2,
                        children = {
                            Zenith.Text({
                                text = app.name,
                                font_family = "Inter",
                                font_size = 13,
                                font_weight = if is_sel then "bold" else "medium",
                                color = if is_sel
                                    then Zenith.hex(theme.on_primary_container or theme.on_surface)
                                    else Zenith.hex(theme.on_surface),
                            }),
                            Zenith.Text({
                                text = desc,
                                font_family = "Inter",
                                font_size = 11,
                                color = if is_sel
                                    then Zenith.hex(theme.on_primary_container or theme.on_surface_variant)
                                    else Zenith.hex(theme.on_surface_variant),
                            }),
                        },
                    }),
                },
            }),
            if is_sel then
                Zenith.Box({
                    padding = { horizontal = 6, vertical = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.primary, 120),
                    children = {
                        Zenith.Text({
                            text = "↵ Enter",
                            font_family = "JetBrainsMono Nerd Font",
                            font_size = 10,
                            color = Zenith.hex(theme.on_primary),
                        }),
                    },
                })
            else
                Zenith.Box({ width = 0, height = 0 }),
        },
    })
end

return AppCard
