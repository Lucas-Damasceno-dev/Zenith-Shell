--!strict
-- Zenith Desktop Shell — Cheatsheet & Keybindings HUD Overlay

local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function ShortcutRow(key: string, desc: string, icon: string)
    local theme = Theme.get()
    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space_between",
        padding = { horizontal = 10, vertical = 6 },
        border_radius = 8,
        background = Zenith.hex(theme.surface_container, 80),
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 8,
                children = {
                    Zenith.Text({
                        text = icon,
                        font_size = 13,
                        color = Zenith.hex(theme.primary),
                    }),
                    Zenith.Text({
                        text = desc,
                        font_size = 11,
                        color = Zenith.hex(theme.on_surface),
                    }),
                }
            }),
            Zenith.Box({
                padding = { horizontal = 8, vertical = 3 },
                border_radius = 6,
                background = Zenith.hex(theme.surface_container_highest, 180),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 40),
                border_width = 1,
                children = {
                    Zenith.Text({
                        text = key,
                        font_family = "JetBrainsMono Nerd Font",
                        font_size = 10,
                        font_weight = "bold",
                        color = Zenith.hex(theme.primary),
                    })
                }
            })
        }
    })
end

local function CheatSheetPopup()
    local theme = Theme.get()

    local shortcuts = {
        { key = "Super + Space", desc = "Universal App Launcher", icon = "󰀻" },
        { key = "Super + Tab", desc = "Visão Geral Exposé (Janelas)", icon = "󰖲" },
        { key = "Super + M", desc = "Controle de Mídia MPRIS", icon = "󰝚" },
        { key = "Super + Shift + M", desc = "Menu de Sessão / Energia", icon = "󰐥" },
        { key = "Super + S / ,", desc = "Painel de Configurações", icon = "󰒓" },
        { key = "Super + R", desc = "Captura de Tela & Gravação", icon = "󰹑" },
        { key = "Super + F7", desc = "Mixer & Seletor de Áudio", icon = "󰕾" },
        { key = "Super + /", desc = "Guia de Atalhos (Cheatsheet)", icon = "󰌌" },
        { key = "Super + 1..0", desc = "Navegação de Workspaces", icon = "󰮯" },
        { key = "Super + Shift + 1..0", desc = "Mover Janela para Workspace", icon = "󰆾" },
    }

    local rows = {}
    for _, sc in ipairs(shortcuts) do
        table.insert(rows, ShortcutRow(sc.key, sc.desc, sc.icon))
    end

    return Zenith.Box({
        direction = "column",
        width = 460,
        padding = { horizontal = 18, vertical = 16 },
        gap = 8,
        background = Zenith.hex(theme.surface, 240),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 70),
        border_width = 1,
        border_radius = 16,
        shadow = {
            color = Zenith.rgba(0, 0, 0, 180),
            blur = 28,
            offset_x = 0,
            offset_y = 10,
        },
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "space_between",
                padding = { horizontal = 4, vertical = 2 },
                children = {
                    Zenith.Box({
                        direction = "row",
                        align_items = "center",
                        gap = 8,
                        children = {
                            Zenith.Text({
                                text = "󰌌",
                                font_size = 16,
                                color = Zenith.hex(theme.primary),
                            }),
                            Zenith.Text({
                                text = "Zenith Shell — Atalhos Principais",
                                font_size = 13,
                                font_weight = "bold",
                                color = Zenith.hex(theme.on_surface),
                            }),
                        }
                    }),
                    Zenith.Box({
                        padding = { horizontal = 8, vertical = 4 },
                        border_radius = 6,
                        background = Zenith.hex(theme.surface_container, 180),
                        cursor = "pointer",
                        on_click = PopupManager.close_action(),
                        children = {
                            Zenith.Text({ text = "✕ ESC", font_size = 10, color = Zenith.hex(theme.on_surface) }),
                        }
                    })
                }
            }),
            Zenith.Box({
                direction = "column",
                gap = 5,
                children = rows,
            })
        }
    })
end

return CheatSheetPopup()
