--!strict
-- Zenith Desktop Shell — Dock MPRIS Media Pill Item
-- Quick media controller embedded in dock

local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")

local function DockMprisPill()
    local theme = Theme.get()
    local media = Services.Mpris.snapshot()

    local title = if media.title ~= "" then media.title else "Sem reprodução"
    if #title > 16 then
        title = string.sub(title, 1, 14) .. "…"
    end

    local is_playing = media.is_playing or false

    local album_art_box = if media.art_url ~= "" then
        Zenith.Image({
            src = media.art_url,
            width = 24,
            height = 24,
            border_radius = 6,
        })
    else
        Zenith.Box({
            width = 24,
            height = 24,
            border_radius = 6,
            background = Zenith.hex(theme.surface_container_highest, 120),
            align_items = "center",
            justify_content = "center",
            children = {
                Zenith.Text({ text = "󰎈", font_size = 12, color = Zenith.hex(theme.primary) }),
            },
        })

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        height = 36,
        gap = 6,
        padding = { horizontal = 8, vertical = 2 },
        border_radius = 18,
        background = Zenith.hex(theme.surface_container_highest or theme.surface_container, 140),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 40),
        border_width = 1,
        tooltip = "Mídia: " .. media.title .. " — " .. media.artist,
        children = {
            album_art_box,
            Zenith.Text({
                text = title,
                font_family = "Inter",
                font_size = 11,
                font_weight = "medium",
                color = Zenith.hex(theme.on_surface),
            }),
            Zenith.Box({
                cursor = "pointer",
                on_click = "media:previous",
                padding = 4,
                children = {
                    Zenith.Text({ text = "󰒮", font_size = 12, color = Zenith.hex(theme.on_surface_variant) }),
                },
            }),
            Zenith.Box({
                cursor = "pointer",
                on_click = "media:play-pause",
                padding = 4,
                children = {
                    Zenith.Text({
                        text = if is_playing then "󰏤" else "󰐊",
                        font_size = 13,
                        color = Zenith.hex(theme.primary),
                    }),
                },
            }),
            Zenith.Box({
                cursor = "pointer",
                on_click = "media:next",
                padding = 4,
                children = {
                    Zenith.Text({ text = "󰒭", font_size = 12, color = Zenith.hex(theme.on_surface_variant) }),
                },
            }),
        },
    })
end

return DockMprisPill
