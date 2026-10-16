--!strict
-- Zenith-Shell (Engine v2) - Window Exposé & Mission Control Overlay
-- 1:1 Parity with Quickshell ExposePopup.qml & ExposeUtils.js

local theme = Zenith.Theme()
local clients = if Zenith.Services and Zenith.Services.Clients then Zenith.Services.Clients() else {}
local active_win = if Zenith.Services and Zenith.Services.ActiveWindow then Zenith.Services.ActiveWindow() else nil
local workspaces_info = if Zenith.Services and Zenith.Services.Workspaces then Zenith.Services.Workspaces() else { active = 1 }

local current_ws = workspaces_info.active or 1
local filter_mode = _G.__expose_filter or "all" -- "all" | "current" | "special"
local search_query = (_G.__expose_search or ""):lower()

local function get_app_icon(raw_cls: string, title: string): string
    local cls = raw_cls:lower()
    local t = title:lower()

    if cls:find("kitty") or cls:find("alacritty") or cls:find("ghostty") or cls:find("wezterm") or cls:find("terminal") then
        return ""
    elseif cls:find("firefox") or cls:find("zen") then
        return "󰈹"
    elseif cls:find("chrome") or cls:find("chromium") or cls:find("brave") then
        return "󰖟"
    elseif cls:find("code") or cls:find("cursor") or cls:find("vscodium") or cls:find("zed") then
        return "󰨞"
    elseif cls:find("nvim") or cls:find("neovim") then
        return ""
    elseif cls:find("thunar") or cls:find("nautilus") or cls:find("dolphin") or cls:find("pcmanfm") then
        return "󰉋"
    elseif cls:find("discord") or cls:find("vesktop") then
        return "󰭹"
    elseif cls:find("telegram") then
        return ""
    elseif cls:find("spotify") then
        return "󰓇"
    elseif cls:find("obs") then
        return "󰑋"
    elseif cls:find("gimp") or cls:find("inkscape") or cls:find("blender") then
        return "󰽉"
    else
        return "󰖲"
    end
end

-- Filter clients
local filtered_clients = {}
for _, c in ipairs(clients) do
    local match_filter = true
    if filter_mode == "current" then
        match_filter = (c.workspace_id == current_ws)
    elseif filter_mode == "special" then
        match_filter = (c.workspace_id < 0 or (c.workspace_name and c.workspace_name:find("special")))
    end

    if match_filter and #search_query > 0 then
        local in_title = c.title and c.title:lower():find(search_query) ~= nil
        local in_class = c.class and c.class:lower():find(search_query) ~= nil
        if not in_title and not in_class then
            match_filter = false
        end
    end

    if match_filter then
        table.insert(filtered_clients, c)
    end
end

-- Render Window Cards
local client_cards = {}
local max_cards = 12
local visible_count = math.min(#filtered_clients, max_cards)

for i = 1, visible_count do
    local c = filtered_clients[i]
    local icon = get_app_icon(c.class or "", c.title or "")
    local is_active = active_win and (active_win.title == c.title or active_win.class == c.class)
    local ws_badge = if c.workspace_id < 0 or (c.workspace_name and c.workspace_name:find("special")) then "Special" else "WS " .. c.workspace_id

    table.insert(client_cards, Zenith.Box({
        direction = "column",
        width = 240,
        height = 140,
        padding = { x = 12, y = 10 },
        border_radius = 14,
        background = if is_active then Zenith.hex(theme.primary_container or theme.primary, 170) else Zenith.hex(theme.surface_container, 140),
        border_color = if is_active then Zenith.hex(theme.primary) else Zenith.rgba(255, 255, 255, 14),
        border_width = if is_active then 2 else 1,
        on_click = "focus:" .. c.address,
        tooltip = "Focar " .. (c.title or c.class or "Janela"),
        children = {
            -- Card Top Header: Icon, Class, WS Badge, Close Button
            Zenith.Box({
                direction = "row",
                align_items = "center",
                children = {
                    Zenith.Text({
                        text = icon,
                        font_size = 18,
                        color = if is_active then Zenith.hex(theme.primary) else Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Box({ width = 8 }),
                    Zenith.Text({
                        text = c.class or "App",
                        font_size = 12,
                        font_weight = "bold",
                        color = Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Box({ flex_grow = 1 }),
                    -- Workspace Badge
                    Zenith.Box({
                        padding = { x = 6, y = 2 },
                        border_radius = 6,
                        background = Zenith.hex(theme.surface_container_high or theme.surface, 180),
                        children = {
                            Zenith.Text({
                                text = ws_badge,
                                font_size = 9,
                                color = Zenith.hex(theme.outline),
                            }),
                        }
                    }),
                    Zenith.Box({ width = 6 }),
                    -- Close Window Button
                    Zenith.Box({
                        padding = { x = 5, y = 3 },
                        border_radius = 5,
                        background = Zenith.rgba(255, 80, 80, 30),
                        on_click = "window:close:" .. c.address,
                        tooltip = "Fechar Janela",
                        children = {
                            Zenith.Text({
                                text = "󰅖",
                                font_size = 10,
                                color = Zenith.hex("#e06c75"),
                            }),
                        }
                    })
                }
            }),

            Zenith.Box({ flex_grow = 1 }),

            -- Center Thumbnail Simulated Canvas / Window Title Preview
            Zenith.Box({
                direction = "column",
                align_items = "stretch",
                justify_content = "center",
                padding = { x = 8, y = 8 },
                border_radius = 8,
                background = Zenith.hex(theme.surface, 120),
                border_color = Zenith.rgba(255, 255, 255, 8),
                border_width = 1,
                children = {
                    Zenith.Text({
                        text = if #c.title > 35 then c.title:sub(1, 32) .. "..." else c.title,
                        font_size = 10,
                        color = Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Box({ height = 4 }),
                    Zenith.Box({
                        direction = "row",
                        gap = 6,
                        children = {
                            if c.floating then
                                Zenith.Text({ text = "󰉈 Flutuante", font_size = 8, color = Zenith.hex(theme.outline) })
                            else
                                Zenith.Text({ text = "󰹑 Tiled", font_size = 8, color = Zenith.hex(theme.outline) }),
                            if c.fullscreen then
                                Zenith.Text({ text = "󰊓 Tela Cheia", font_size = 8, color = Zenith.hex(theme.primary) })
                            else
                                Zenith.Box({ width = 0 })
                        }
                    })
                }
            })
        }
    }))
end

-- Empty state if no windows match
if #filtered_clients == 0 then
    table.insert(client_cards, Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        flex_grow = 1,
        height = 140,
        children = {
            Zenith.Text({
                text = "󰖲 Nenhuma janela encontrada",
                font_size = 14,
                color = Zenith.hex(theme.outline),
            }),
            Zenith.Box({ height = 4 }),
            Zenith.Text({
                text = "Tente alterar o filtro ou termo de busca",
                font_size = 11,
                color = Zenith.hex(theme.outline_variant or theme.outline),
            }),
        }
    }))
end

return Zenith.Window({
    direction = "column",
    width = 820,
    height = 540,
    padding = { x = 20, y = 16 },
    gap = 14,
    background = Zenith.hex(theme.surface, 240),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 70),
    border_width = 1,
    border_radius = 20,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 32,
        spread = 4,
        offset_y = 12,
    },
    children = {
        -- Header Toolbar: Title, Filter Pills, Close
        Zenith.Box({
            direction = "row",
            align_items = "center",
            children = {
                Zenith.Text({
                    text = "󰖲 Janelas Abertas (Exposé)",
                    font_size = 15,
                    font_weight = "bold",
                    color = Zenith.hex(theme.on_surface),
                }),
                Zenith.Box({ width = 16 }),
                -- Filter Pills
                Zenith.Box({
                    direction = "row",
                    gap = 6,
                    children = {
                        Zenith.Box({
                            padding = { x = 10, y = 5 },
                            border_radius = 8,
                            background = if filter_mode == "all" then Zenith.hex(theme.primary) else Zenith.hex(theme.surface_container, 140),
                            on_click = "expose:filter:all",
                            children = {
                                Zenith.Text({
                                    text = "Todas (" .. #clients .. ")",
                                    font_size = 10,
                                    font_weight = "medium",
                                    color = if filter_mode == "all" then Zenith.hex(theme.on_primary) else Zenith.hex(theme.on_surface),
                                }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 10, y = 5 },
                            border_radius = 8,
                            background = if filter_mode == "current" then Zenith.hex(theme.primary) else Zenith.hex(theme.surface_container, 140),
                            on_click = "expose:filter:current",
                            children = {
                                Zenith.Text({
                                    text = "Workspace " .. current_ws,
                                    font_size = 10,
                                    font_weight = "medium",
                                    color = if filter_mode == "current" then Zenith.hex(theme.on_primary) else Zenith.hex(theme.on_surface),
                                }),
                            }
                        }),
                        Zenith.Box({
                            padding = { x = 10, y = 5 },
                            border_radius = 8,
                            background = if filter_mode == "special" then Zenith.hex(theme.primary) else Zenith.hex(theme.surface_container, 140),
                            on_click = "expose:filter:special",
                            children = {
                                Zenith.Text({
                                    text = "Scratchpads",
                                    font_size = 10,
                                    font_weight = "medium",
                                    color = if filter_mode == "special" then Zenith.hex(theme.on_primary) else Zenith.hex(theme.on_surface),
                                }),
                            }
                        }),
                    }
                }),
                Zenith.Box({ flex_grow = 1 }),
                -- ESC Close Button
                Zenith.Box({
                    padding = { x = 8, y = 5 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container, 180),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "ESC", font_size = 10, color = Zenith.hex(theme.outline) }),
                    }
                })
            }
        }),

        -- Search Input Bar
        Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { x = 12, y = 8 },
            border_radius = 10,
            background = Zenith.hex(theme.surface_container, 150),
            border_color = Zenith.rgba(255, 255, 255, 12),
            border_width = 1,
            children = {
                Zenith.Text({ text = "󰍉", font_size = 14, color = Zenith.hex(theme.outline) }),
                Zenith.Box({ width = 8 }),
                Zenith.TextInput({
                    id = "expose_search_input",
                    placeholder = "Filtrar janelas por título ou aplicação...",
                    text = _G.__expose_search or "",
                    flex_grow = 1,
                    on_change = "expose:search:",
                }),
                if #search_query > 0 then
                    Zenith.Box({
                        padding = { x = 4, y = 2 },
                        on_click = "expose:search_clear",
                        children = {
                            Zenith.Text({ text = "󰅖", font_size = 11, color = Zenith.hex(theme.outline) }),
                        }
                    })
                else
                    Zenith.Box({ width = 0 })
            }
        }),

        -- Windows Grid
        Zenith.Box({
            direction = "row",
            flex_wrap = "wrap",
            gap = 12,
            flex_grow = 1,
            children = client_cards,
        }),

        -- Footer Navigation Hints
        Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "space_between",
            padding = { x = 4, y = 2 },
            children = {
                Zenith.Text({
                    text = #filtered_clients .. " janelas visíveis",
                    font_size = 10,
                    color = Zenith.hex(theme.outline),
                }),
                Zenith.Text({
                    text = "Clique para focar • 󰅖 Fechar Janela • ESC Sair",
                    font_size = 10,
                    color = Zenith.hex(theme.outline),
                }),
            }
        })
    }
})
