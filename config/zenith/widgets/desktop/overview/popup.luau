--!strict
-- Zenith-Shell: Window Exposé & Mission Control Popup

local Icons = Zenith.import("core/ui/icons")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")
local Services = Zenith.import("core/services/init")

local function OverviewPopup()
    local theme = Theme.get()
    local clients = Services.Hyprland.clients()
    local active_win = Services.Hyprland.active_window()
    local workspaces_info = Services.Hyprland.workspaces()

    local current_ws = workspaces_info.active or 1
    local filter_mode = _G.__expose_filter or "all"
    local search_query = (_G.__expose_search or ""):lower()

    local filtered_clients = {}
    for _, c in ipairs(clients) do
        local matches_filter = false
        if filter_mode == "all" then
            matches_filter = true
        elseif filter_mode == "current" then
            matches_filter = (c.workspace_id == current_ws)
        elseif filter_mode == "special" then
            matches_filter = (c.workspace_id and c.workspace_id < 0) or (c.special == true)
        end

        local matches_search = true
        if #search_query > 0 then
            local text = string.lower(string.format("%s %s", c.title or "", c.class or ""))
            matches_search = text:find(search_query, 1, true) ~= nil
        end

        if matches_filter and matches_search then
            table.insert(filtered_clients, c)
        end
    end

    local client_cards = {}
    for _, c in ipairs(filtered_clients) do
        local is_focused = active_win and (active_win.address == c.address or active_win.title == c.title)
        local icon = Icons.for_app(c.class, c.title)
        local title = c.title or "Sem título"
        if #title > 35 then
            title = string.sub(title, 1, 32) .. "..."
        end

        local border_c = if is_focused then Zenith.hex(theme.primary) else Zenith.hex(theme.outline_variant or theme.outline, 40)
        local bg_c = if is_focused then Zenith.hex(theme.surface_container_highest or theme.surface_container, 220) else Zenith.hex(theme.surface_container, 140)

        table.insert(client_cards, Zenith.Box({
            width = 240,
            height = 80,
            padding = { horizontal = 10, vertical = 8 },
            border_radius = 12,
            background = bg_c,
            border_color = border_c,
            border_width = 1,
            direction = "row",
            align_items = "center",
            gap = 10,
            cursor = "pointer",
            on_click = string.format("dispatch:focuswindow:address:%s", c.address or ""),
            children = {
                Zenith.Box({
                    width = 40,
                    height = 40,
                    border_radius = 8,
                    background = Zenith.hex(theme.surface_container_high or theme.surface_container),
                    align_items = "center",
                    justify_content = "center",
                    children = {
                        Zenith.Text({
                            text = icon,
                            font_size = 20,
                            color = Zenith.hex(theme.primary),
                        }),
                    }
                }),
                Zenith.Box({
                    direction = "column",
                    flex_grow = 1,
                    gap = 2,
                    children = {
                        Zenith.Text({
                            text = title,
                            font_size = 11,
                            font_weight = "bold",
                            color = Zenith.hex(theme.on_surface),
                        }),
                        Zenith.Text({
                            text = string.format("%s • WS %d", c.class or "App", c.workspace_id or 1),
                            font_size = 9,
                            color = Zenith.hex(theme.on_surface_variant or theme.outline),
                        }),
                    }
                }),
                Zenith.Box({
                    padding = { horizontal = 6, vertical = 4 },
                    border_radius = 6,
                    background = Zenith.hex(theme.error or "#f38ba8", 30),
                    cursor = "pointer",
                    on_click = string.format("dispatch:closewindow:address:%s", c.address or ""),
                    children = {
                        Zenith.Text({
                            text = "󰅖",
                            font_size = 10,
                            color = Zenith.hex(theme.error or "#f38ba8"),
                        })
                    }
                })
            }
        }))
    end

    if #client_cards == 0 then
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
                    color = Zenith.hex(theme.outline_variant or theme.outline),
                }),
            }
        }))
    end

    return Zenith.Box({
        direction = "column",
        width = 780,
        height = 480,
        padding = { horizontal = 20, vertical = 16 },
        gap = 12,
        background = Zenith.hex(theme.surface, 240),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 70),
        border_width = 1,
        border_radius = 20,
        shadow = {
            color = Zenith.rgba(0, 0, 0, 180),
            blur = 32,
            offset_x = 0,
            offset_y = 12,
        },
        children = {
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
                    Zenith.Box({
                        direction = "row",
                        gap = 6,
                        children = {
                            Zenith.Box({
                                padding = { horizontal = 10, vertical = 4 },
                                border_radius = 8,
                                background = if filter_mode == "all" then Zenith.hex(theme.primary) else Zenith.hex(theme.surface_container, 140),
                                on_click = "expose:filter:all",
                                children = {
                                    Zenith.Text({
                                        text = string.format("Todas (%d)", #clients),
                                        font_size = 10,
                                        font_weight = "medium",
                                        color = if filter_mode == "all" then Zenith.hex(theme.on_primary) else Zenith.hex(theme.on_surface),
                                    }),
                                }
                            }),
                            Zenith.Box({
                                padding = { horizontal = 10, vertical = 4 },
                                border_radius = 8,
                                background = if filter_mode == "current" then Zenith.hex(theme.primary) else Zenith.hex(theme.surface_container, 140),
                                on_click = "expose:filter:current",
                                children = {
                                    Zenith.Text({
                                        text = string.format("Workspace %d", current_ws),
                                        font_size = 10,
                                        font_weight = "medium",
                                        color = if filter_mode == "current" then Zenith.hex(theme.on_primary) else Zenith.hex(theme.on_surface),
                                    }),
                                }
                            }),
                        }
                    }),
                    Zenith.Box({ flex_grow = 1 }),
                    Zenith.Box({
                        padding = { horizontal = 8, vertical = 4 },
                        border_radius = 6,
                        background = Zenith.hex(theme.surface_container, 180),
                        on_click = PopupManager.close_action(),
                        children = {
                            Zenith.Text({ text = "✕ ESC", font_size = 10, color = Zenith.hex(theme.on_surface) }),
                        }
                    })
                }
            }),

            Zenith.Box({
                direction = "row",
                flex_wrap = "wrap",
                gap = 10,
                flex_grow = 1,
                children = client_cards,
            }),

            Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "space_between",
                padding = { horizontal = 4, vertical = 2 },
                children = {
                    Zenith.Text({
                        text = string.format("%d janelas visíveis", #filtered_clients),
                        font_size = 10,
                        color = Zenith.hex(theme.outline_variant or theme.outline),
                    }),
                    Zenith.Text({
                        text = "Clique para focar • 󰅖 Fechar Janela • ESC Sair",
                        font_size = 10,
                        color = Zenith.hex(theme.outline_variant or theme.outline),
                    }),
                }
            })
        }
    })
end

return OverviewPopup
