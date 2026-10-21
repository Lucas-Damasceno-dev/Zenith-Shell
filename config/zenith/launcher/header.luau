--!strict
-- Zenith Desktop Shell — Launcher Search Header
-- Search input bar, active query display, clear action and result counter

local Theme = Zenith.import("core/theme")

local function LauncherHeader(props: { query: string, result_count: number })
    local theme = Theme.get()
    local q = props.query
    local count = props.result_count
    local has_query = q ~= ""

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space_between",
        width = "100%",
        height = 48,
        padding = { horizontal = 16, vertical = 6 },
        border_radius = 16,
        background = Zenith.hex(theme.surface_container_highest or theme.surface_container, 140),
        border_color = if has_query
            then Zenith.hex(theme.primary, 150)
            else Zenith.hex(theme.outline_variant or theme.outline, 45),
        border_width = 1,
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 12,
                children = {
                    Zenith.Text({
                        text = "󰍉",
                        font_family = "JetBrainsMono Nerd Font",
                        font_size = 18,
                        color = if has_query
                            then Zenith.hex(theme.primary)
                            else Zenith.hex(theme.on_surface_variant),
                    }),
                    Zenith.Text({
                        text = if has_query then q else "Pesquisar aplicativos, arquivos ou comandos...",
                        font_family = "Inter",
                        font_size = 14,
                        font_weight = if has_query then "semibold" else "normal",
                        color = if has_query
                            then Zenith.hex(theme.on_surface)
                            else Zenith.hex(theme.on_surface_variant, 120),
                    }),
                },
            }),
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 8,
                children = {
                    if has_query then
                        Zenith.Box({
                            cursor = "pointer",
                            on_click = "search:clear",
                            padding = { horizontal = 6, vertical = 2 },
                            border_radius = 8,
                            background = Zenith.hex(theme.surface_container, 120),
                            children = {
                                Zenith.Text({
                                    text = "󰅖",
                                    font_size = 12,
                                    color = Zenith.hex(theme.on_surface_variant),
                                }),
                            },
                        })
                    else
                        Zenith.Box({ width = 0, height = 0 }),
                    Zenith.Box({
                        padding = { horizontal = 8, vertical = 2 },
                        border_radius = 10,
                        background = Zenith.hex(theme.primary_container, 90),
                        children = {
                            Zenith.Text({
                                text = string.format("%d apps", count),
                                font_family = "Inter",
                                font_size = 11,
                                font_weight = "medium",
                                color = Zenith.hex(theme.primary),
                            }),
                        },
                    }),
                },
            }),
        },
    })
end

return LauncherHeader
