--!strict
-- Zenith Desktop Shell — Dynamic Island Component & Overlay
-- Adaptive contextual island supporting idle, media playback, alerts and expanded state

local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")
local Store = Zenith.import("core/store")
local Icons = Zenith.import("core/ui/icons")

local function DynamicIsland(props: { expanded: boolean?, width: number?, height: number? }?)
    local theme = Theme.get()
    local is_expanded = if props and props.expanded ~= nil then props.expanded else false
    local media = Services.Mpris.snapshot()

    local has_media = media.is_playing or (media.title ~= "" and media.title ~= "No Media")

    if not is_expanded then
        -- Compact Pill Mode (Bar-integrated)
        local icon = if media.is_playing then Icons.glyphs.play else "󰏤"
        local title_short = if media.title ~= "" then media.title else "Zenith OS"
        if #title_short > 20 then
            title_short = string.sub(title_short, 1, 18) .. "…"
        end

        return Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "space_between",
            height = 30,
            padding = { horizontal = 10, vertical = 2 },
            border_radius = 15,
            background = Zenith.hex(theme.surface_container_highest or theme.surface_container, 200),
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 60),
            border_width = 1,
            cursor = "pointer",
            on_click = "popup:toggle:MediaPopup",
            children = {
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 6,
                    children = {
                        Zenith.Text({
                            text = icon,
                            font_size = 11,
                            color = Zenith.hex(theme.primary),
                        }),
                        Zenith.Text({
                            text = title_short,
                            font_family = "Inter",
                            font_size = 11,
                            font_weight = "medium",
                            color = Zenith.hex(theme.on_surface),
                        }),
                    },
                }),
                if has_media then
                    Zenith.Box({
                        direction = "row",
                        align_items = "center",
                        gap = 4,
                        children = {
                            Zenith.Text({
                                text = "󰐊",
                                font_size = 11,
                                color = Zenith.hex(theme.on_surface_variant),
                            }),
                        },
                    })
                else
                    Zenith.Box({ width = 0, height = 0 }),
            },
        })
    else
        -- Expanded Overlay Mode
        local art_url = media.art_url
        local width = if props and props.width then props.width else 360
        local height = if props and props.height then props.height else 140

        local art_node = if art_url ~= "" then
            Zenith.Image({
                src = art_url,
                width = 54,
                height = 54,
                border_radius = 12,
            })
        else
            Zenith.Box({
                width = 54,
                height = 54,
                border_radius = 12,
                background = Zenith.hex(theme.surface_container_highest, 120),
                align_items = "center",
                justify_content = "center",
                children = {
                    Zenith.Text({
                        text = "󰎈",
                        font_size = 24,
                        color = Zenith.hex(theme.primary),
                    }),
                },
            })

        return Zenith.Box({
            direction = "column",
            width = width,
            height = height,
            padding = 16,
            border_radius = 24,
            background = Zenith.hex(theme.surface_container_highest or theme.surface, 240),
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
            border_width = 1,
            shadow = {
                color = Zenith.rgba(0, 0, 0, 160),
                blur = 24,
                offset_x = 0,
                offset_y = 8,
            },
            gap = 12,
            children = {
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 14,
                    width = "100%",
                    children = {
                        art_node,
                        Zenith.Box({
                            direction = "column",
                            justify_content = "center",
                            gap = 3,
                            width = width - 110,
                            children = {
                                Zenith.Text({
                                    text = if media.title ~= "" then media.title else "Nenhuma Mídia",
                                    font_family = "Inter",
                                    font_size = 14,
                                    font_weight = "bold",
                                    color = Zenith.hex(theme.on_surface),
                                }),
                                Zenith.Text({
                                    text = if media.artist ~= "" then media.artist else "Zenith Island",
                                    font_family = "Inter",
                                    font_size = 12,
                                    color = Zenith.hex(theme.on_surface_variant),
                                }),
                            },
                        }),
                    },
                }),
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    justify_content = "center",
                    gap = 18,
                    width = "100%",
                    children = {
                        Zenith.Box({
                            cursor = "pointer",
                            on_click = "media:previous",
                            padding = 6,
                            children = {
                                Zenith.Text({ text = "󰒮", font_size = 18, color = Zenith.hex(theme.on_surface) }),
                            },
                        }),
                        Zenith.Box({
                            cursor = "pointer",
                            on_click = "media:play-pause",
                            padding = 8,
                            border_radius = 18,
                            background = Zenith.hex(theme.primary),
                            children = {
                                Zenith.Text({
                                    text = if media.is_playing then "󰏤" else "󰐊",
                                    font_size = 18,
                                    color = Zenith.hex(theme.on_primary),
                                }),
                            },
                        }),
                        Zenith.Box({
                            cursor = "pointer",
                            on_click = "media:next",
                            padding = 6,
                            children = {
                                Zenith.Text({ text = "󰒭", font_size = 18, color = Zenith.hex(theme.on_surface) }),
                            },
                        }),
                    },
                }),
            },
        })
    end
end

local mod = {
    id = "island",
    widget = DynamicIsland,
}

setmetatable(mod, {
    __call = function(_, props)
        return DynamicIsland(props)
    end,
})

return mod
