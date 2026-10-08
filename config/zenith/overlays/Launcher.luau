--!strict
-- Zenith-Shell (Engine v2) - Universal Application Launcher Overlay

local theme = Zenith.Theme()
local apps = Zenith.Services.Launcher("", 8)

-- Icon heuristic based on categories, name, or keywords
local function resolve_app_icon(name: string, comment: string): string
    local s = (name .. " " .. comment):lower()
    if s:find("browser") or s:find("firefox") or s:find("chrome") or s:find("web") then
        return "󰈹"
    elseif s:find("code") or s:find("develop") or s:find("editor") or s:find("rust") then
        return "󰨞"
    elseif s:find("terminal") or s:find("console") or s:find("kitty") or s:find("alacritty") then
        return ""
    elseif s:find("audio") or s:find("music") or s:find("spotify") or s:find("sound") or s:find("volume") then
        return "󰓃"
    elseif s:find("video") or s:find("stream") or s:find("moonlight") or s:find("sunshine") then
        return "󰕼"
    elseif s:find("file") or s:find("thunar") or s:find("nautilus") or s:find("manager") then
        return "󰉋"
    elseif s:find("setting") or s:find("config") or s:find("control") then
        return "󰒓"
    else
        return ""
    end
end

local app_boxes = {}
for idx, app in ipairs(apps) do
    local icon = resolve_app_icon(app.name, app.comment)
    local subtext = (#app.comment > 0) and app.comment or app.id
    if #subtext > 40 then
        subtext = subtext:sub(1, 37) .. "..."
    end

    table.insert(app_boxes, Zenith.Box({
        direction = "row",
        padding = { x = 12, y = 8 },
        gap = 12,
        border_radius = 8,
        background = Zenith.hex(theme.surface_container),
        border_color = Zenith.hex("#2a2e3d"),
        border_width = 1,
        on_click = "launch:" .. app.exec,
        children = {
            Zenith.Text({
                text = icon,
                font_size = 18,
                color = Zenith.hex(theme.primary),
            }),
            Zenith.Box({
                direction = "column",
                gap = 2,
                flex_grow = 1,
                children = {
                    Zenith.Text({
                        text = app.name,
                        font_size = 13,
                        color = Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Text({
                        text = subtext,
                        font_size = 10,
                        color = Zenith.hex(theme.outline),
                    }),
                }
            }),
            Zenith.Box({
                padding = { x = 6, y = 2 },
                border_radius = 4,
                background = Zenith.rgba(255, 255, 255, 12),
                children = {
                    Zenith.Text({
                        text = "RUN 󰁔",
                        font_size = 9,
                        color = Zenith.hex(theme.primary),
                    })
                }
            })
        }
    }))
end

return Zenith.Window({
    direction = "column",
    width = 460,
    height = 540,
    padding = { x = 16, y = 14 },
    gap = 10,
    background = Zenith.rgba(18, 20, 26, 225),
    border_color = Zenith.hex(theme.primary),
    border_width = 1,
    border_radius = 16,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 24,
        offset_x = 0,
        offset_y = 10,
    },
    children = {
        -- Search Bar Header
        Zenith.Box({
            direction = "row",
            padding = { x = 12, y = 10 },
            border_radius = 10,
            background = Zenith.hex(theme.surface),
            border_color = Zenith.hex(theme.primary),
            border_width = 1,
            gap = 10,
            children = {
                Zenith.Text({
                    text = "",
                    font_size = 14,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Text({
                    text = "Type to search applications...",
                    font_size = 13,
                    color = Zenith.hex(theme.outline),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 6, y = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "ESC", font_size = 9, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            }
        }),

        -- Applications List
        Zenith.Box({
            direction = "column",
            gap = 6,
            flex_grow = 1,
            children = app_boxes,
        }),

        -- Footer info chip
        Zenith.Box({
            direction = "row",
            padding = { x = 6, y = 4 },
            children = {
                Zenith.Text({
                    text = string.format("󰌌 %d applications indexed • Click outside to dismiss", #apps),
                    font_size = 10,
                    color = Zenith.hex(theme.outline),
                }),
            }
        })
    }
})
