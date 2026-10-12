--!strict
-- Zenith-Shell (Engine v2) - Universal Application Launcher Overlay
-- 1:1 Parity with Quickshell Launcher, native TextInput, XdgIconResolver & keyboard navigation

local function resolve_app_icon(name: string, comment: string?): string
    local n = (name .. " " .. (comment or "")):lower()
    if n:find("terminal") or n:find("foot") or n:find("kitty") or n:find("alacritty") or n:find("ghostty") or n:find("wezterm") then
        return ""
    elseif n:find("browser") or n:find("brave") or n:find("firefox") or n:find("chrome") or n:find("zen") or n:find("chromium") then
        return "󰈹"
    elseif n:find("code") or n:find("nvim") or n:find("vscodium") or n:find("cursor") or n:find("zed") or n:find("editor") then
        return "󰨞"
    elseif n:find("file") or n:find("thunar") or n:find("nautilus") or n:find("dolphin") then
        return "󰉋"
    elseif n:find("audio") or n:find("music") or n:find("spotify") or n:find("pavucontrol") then
        return "󰓇"
    elseif n:find("video") or n:find("media") or n:find("vlc") or n:find("mpv") then
        return "󰕼"
    elseif n:find("discord") or n:find("vesktop") or n:find("telegram") or n:find("chat") then
        return "󰭹"
    elseif n:find("settings") or n:find("config") or n:find("control") then
        return "󰒓"
    else
        return "󰵆"
    end
end

local function clamp(v: number, min: number, max: number): number
    if v < min then return min end
    if v > max then return max end
    return v
end

local theme = Zenith.Theme()
local query = Zenith.get_search_query()
local selected_idx = Zenith.get_selected_index()
local app_limit = (#query == 0) and 20 or 30
local apps = Zenith.Services.Launcher(query, app_limit)
local total = #apps
local cur_sel = selected_idx or 1
if total > 0 then
    if cur_sel > total then cur_sel = total end
    if cur_sel < 1 then cur_sel = 1 end
else
    cur_sel = 1
end

local max_visible = 8
local start_idx = 1
if total > max_visible then
    start_idx = clamp(cur_sel - math.floor(max_visible / 2), 1, total - max_visible + 1)
end
local end_idx = math.min(start_idx + max_visible - 1, total)

local app_boxes = {}
for idx = start_idx, end_idx do
    local app = apps[idx]
    if not app then break end
    local is_selected = (idx == cur_sel)
    local glyph = resolve_app_icon(app.name, app.comment)
    local subtext = (#app.comment > 0) and app.comment or app.id
    if #subtext > 48 then
        subtext = subtext:sub(1, 45) .. "..."
    end

    local icon_element = if app.icon and #app.icon > 0 then
        Zenith.Image({
            src = app.icon,
            width = 24,
            height = 24,
        })
    else
        Zenith.Text({
            text = glyph,
            font_size = 18,
            color = Zenith.hex(theme.primary),
        })

    table.insert(app_boxes, Zenith.Box({
        direction = "row",
        width = 468,
        align_items = "center",
        padding = { x = 12, y = 8 },
        gap = 12,
        border_radius = 10,
        background = Zenith.hex(is_selected and theme.primary_container or theme.surface_container, is_selected and 210 or 120),
        border_color = Zenith.hex(is_selected and theme.primary or (theme.outline_variant or theme.outline), is_selected and 255 or 40),
        border_width = 1,
        on_click = "launch:" .. app.exec,
        children = {
            Zenith.Box({
                width = 28,
                height = 28,
                align_items = "center",
                justify_content = "center",
                children = { icon_element },
            }),
            Zenith.Box({
                direction = "column",
                gap = 2,
                flex_grow = 1,
                children = {
                    Zenith.Text({
                        text = app.name,
                        font_size = 13,
                        color = Zenith.hex(is_selected and (theme.on_primary_container or theme.primary) or theme.on_surface),
                    }),
                    Zenith.Text({
                        text = subtext,
                        font_size = 10,
                        color = Zenith.hex(theme.outline),
                    }),
                }
            }),
            Zenith.Box({
                padding = { x = 7, y = 3 },
                border_radius = 5,
                background = is_selected and Zenith.hex(theme.primary) or Zenith.rgba(255, 255, 255, 12),
                children = {
                    Zenith.Text({
                        text = is_selected and "ENTER 󰁔" or "RUN",
                        font_size = 9,
                        color = is_selected and Zenith.hex(theme.on_primary) or Zenith.hex(theme.outline),
                    })
                }
            })
        }
    }))
end

return Zenith.Window({
    direction = "column",
    width = 500,
    height = 580,
    padding = { x = 16, y = 14 },
    gap = 10,
    background = Zenith.hex(theme.surface, 235),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
    border_width = 1,
    border_radius = 16,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 24,
        offset_x = 0,
        offset_y = 10,
    },
    children = {
        -- Search Bar Header with native TextInput
        Zenith.Box({
            direction = "row",
            width = 468,
            align_items = "center",
            padding = { x = 12, y = 8 },
            border_radius = 10,
            background = Zenith.hex(theme.surface_container),
            border_color = Zenith.hex(theme.primary, 120),
            border_width = 1,
            gap = 10,
            children = {
                Zenith.Text({
                    text = "",
                    font_size = 15,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({
                    flex_grow = 1,
                    children = {
                        Zenith.TextInput({
                            id = "launcher_search",
                            placeholder = "Buscar aplicativos...",
                            text = query,
                            active = true,
                            font_size = 13,
                            color = Zenith.hex(theme.on_surface),
                        })
                    }
                }),
                if #query > 0 then Zenith.Box({
                    padding = { x = 6, y = 2 },
                    border_radius = 6,
                    background = Zenith.rgba(255, 255, 255, 14),
                    on_click = "search:clear",
                    children = {
                        Zenith.Text({ text = "󰅖", font_size = 11, color = Zenith.hex(theme.outline) }),
                    }
                }) else nil,
                Zenith.Box({
                    padding = { x = 6, y = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container_high or theme.surface_container),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "ESC", font_size = 9, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            },
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
            align_items = "center",
            padding = { x = 6, y = 4 },
            children = {
                Zenith.Text({
                    text = string.format("󰌌 %d aplicativos • %d de %d selecionado", total, total > 0 and cur_sel or 0, total),
                    font_size = 10,
                    color = Zenith.hex(theme.outline),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Text({
                    text = "↑/↓ Navegar  •  Enter Executar  •  Esc Fechar",
                    font_size = 9,
                    color = Zenith.hex(theme.outline),
                }),
            }
        })
    }
})
