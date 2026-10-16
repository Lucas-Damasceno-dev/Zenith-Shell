--!strict
-- Zenith-Shell (Engine v2) - Scratchpad Drawer Overlay
-- 1:1 Parity with Quickshell ScratchpadDrawer.qml & ScratchpadUtils.js

local theme = Zenith.Theme()
local clients = if Zenith.Services and Zenith.Services.Clients then Zenith.Services.Clients() else {}

local function get_app_icon(raw_cls: string, title: string): string
    local cls = raw_cls:lower()
    if cls:find("kitty") or cls:find("alacritty") or cls:find("ghostty") or cls:find("wezterm") or cls:find("terminal") then
        return ""
    elseif cls:find("firefox") or cls:find("zen") or cls:find("chrome") or cls:find("brave") then
        return "󰖟"
    elseif cls:find("code") or cls:find("cursor") or cls:find("vscodium") or cls:find("zed") then
        return "󰨞"
    elseif cls:find("thunar") or cls:find("nautilus") or cls:find("dolphin") then
        return "󰉋"
    elseif cls:find("discord") or cls:find("vesktop") or cls:find("telegram") then
        return "󰭹"
    elseif cls:find("spotify") then
        return "󰓇"
    else
        return "󰖲"
    end
end

-- Filter clients that belong to special workspaces (scratchpads)
local scratchpad_clients = {}
for _, c in ipairs(clients) do
    if c.workspace_id < 0 or (c.workspace_name and c.workspace_name:find("special")) then
        table.insert(scratchpad_clients, c)
    end
end

local scratch_items = {}
if #scratchpad_clients == 0 then
    table.insert(scratch_items, Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        flex_grow = 1,
        height = 180,
        gap = 8,
        children = {
            Zenith.Text({
                text = "󰀻",
                font_size = 28,
                color = Zenith.hex(theme.outline),
            }),
            Zenith.Text({
                text = "Nenhuma janela no Scratchpad",
                font_size = 13,
                font_weight = "medium",
                color = Zenith.hex(theme.on_surface),
            }),
            Zenith.Text({
                text = "Envie janelas ativas com Super+Shift+S",
                font_size = 10,
                color = Zenith.hex(theme.outline),
            }),
        }
    }))
else
    for _, c in ipairs(scratchpad_clients) do
        local icon = get_app_icon(c.class or "", c.title or "")
        local spec_name = c.workspace_name or "special"

        table.insert(scratch_items, Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { x = 12, y = 10 },
            border_radius = 12,
            background = Zenith.hex(theme.surface_container, 140),
            border_color = Zenith.rgba(255, 255, 255, 12),
            border_width = 1,
            on_click = "focus:" .. c.address,
            tooltip = "Trazer " .. (c.title or c.class or "janela") .. " para o foco",
            children = {
                Zenith.Box({
                    width = 36,
                    height = 36,
                    border_radius = 18,
                    background = Zenith.hex(theme.primary_container or theme.primary, 150),
                    align_items = "center",
                    justify_content = "center",
                    children = {
                        Zenith.Text({
                            text = icon,
                            font_size = 16,
                            color = Zenith.hex(theme.on_primary or theme.primary),
                        }),
                    }
                }),
                Zenith.Box({ width = 10 }),
                Zenith.Box({
                    direction = "column",
                    flex_grow = 1,
                    children = {
                        Zenith.Text({
                            text = c.class or "App",
                            font_size = 12,
                            font_weight = "bold",
                            color = Zenith.hex(theme.on_surface),
                        }),
                        Zenith.Text({
                            text = if #c.title > 30 then c.title:sub(1, 28) .. "..." else c.title,
                            font_size = 10,
                            color = Zenith.hex(theme.outline),
                        }),
                        Zenith.Box({ height = 2 }),
                        Zenith.Text({
                            text = "󰌵 " .. spec_name,
                            font_size = 9,
                            color = Zenith.hex(theme.primary),
                        }),
                    }
                }),
                -- Action Buttons
                Zenith.Box({
                    direction = "row",
                    gap = 6,
                    children = {
                        -- Restore to current workspace
                        Zenith.Box({
                            padding = { x = 8, y = 6 },
                            border_radius = 6,
                            background = Zenith.hex(theme.surface_container_high or theme.surface, 180),
                            on_click = "hyprland:dispatch:movetoworkspace,current," .. c.address,
                            tooltip = "Mover para workspace atual",
                            children = {
                                Zenith.Text({ text = "󰁝", font_size = 12, color = Zenith.hex(theme.on_surface) }),
                            }
                        }),
                        -- Close
                        Zenith.Box({
                            padding = { x = 6, y = 6 },
                            border_radius = 6,
                            background = Zenith.rgba(255, 80, 80, 25),
                            on_click = "window:close:" .. c.address,
                            tooltip = "Fechar Janela",
                            children = {
                                Zenith.Text({ text = "󰅖", font_size = 11, color = Zenith.hex("#e06c75") }),
                            }
                        }),
                    }
                })
            }
        }))
    end
end

return Zenith.Window({
    direction = "column",
    width = 380,
    height = 520,
    padding = { x = 16, y = 14 },
    gap = 12,
    background = Zenith.hex(theme.surface, 238),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 70),
    border_width = 1,
    border_radius = 18,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 160),
        blur = 28,
        spread = 2,
        offset_y = 10,
    },
    children = {
        -- Header
        Zenith.Box({
            direction = "row",
            align_items = "center",
            children = {
                Zenith.Text({
                    text = "󰀻 Scratchpad Drawer",
                    font_size = 14,
                    font_weight = "bold",
                    color = Zenith.hex(theme.on_surface),
                }),
                Zenith.Box({ width = 8 }),
                Zenith.Box({
                    padding = { x = 6, y = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.primary_container or theme.primary, 140),
                    children = {
                        Zenith.Text({
                            text = #scratchpad_clients .. " ativas",
                            font_size = 9,
                            color = Zenith.hex(theme.on_primary or theme.primary),
                        }),
                    }
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 6, y = 6 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container, 140),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "󰅖", font_size = 12, color = Zenith.hex(theme.outline) }),
                    }
                })
            }
        }),

        -- Quick Action Banner
        Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "space_between",
            padding = { x = 10, y = 8 },
            border_radius = 10,
            background = Zenith.hex(theme.surface_container, 120),
            border_color = Zenith.rgba(255, 255, 255, 10),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = "Janela atual para scratchpad:",
                    font_size = 10,
                    color = Zenith.hex(theme.outline),
                }),
                Zenith.Box({
                    padding = { x = 8, y = 4 },
                    border_radius = 6,
                    background = Zenith.hex(theme.primary, 200),
                    on_click = "hyprland:dispatch:movetoscratchpad",
                    children = {
                        Zenith.Text({
                            text = "󰁔 Enviar",
                            font_size = 9,
                            font_weight = "bold",
                            color = Zenith.hex(theme.on_primary),
                        }),
                    }
                })
            }
        }),

        -- Scrollable Scratchpad Items List
        Zenith.Box({
            direction = "column",
            gap = 8,
            flex_grow = 1,
            children = scratch_items,
        }),

        -- Footer Info
        Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "space_between",
            padding = { x = 4, y = 2 },
            children = {
                Zenith.Text({
                    text = "Super + S: Alternar visibilidade",
                    font_size = 9,
                    color = Zenith.hex(theme.outline),
                }),
                Zenith.Box({
                    padding = { x = 6, y = 3 },
                    border_radius = 4,
                    background = Zenith.hex(theme.surface_container, 120),
                    on_click = "hyprland:dispatch:togglespecialworkspace",
                    children = {
                        Zenith.Text({ text = "Toggle Global", font_size = 9, color = Zenith.hex(theme.on_surface) }),
                    }
                })
            }
        })
    }
})
