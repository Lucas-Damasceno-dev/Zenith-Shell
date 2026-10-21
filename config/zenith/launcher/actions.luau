--!strict
-- Zenith Desktop Shell — Launcher Footer & Keybinding Actions
-- Displays keyboard navigation hints and quick power/system actions

local Theme = Zenith.import("core/theme")

local function LauncherActions()
    local theme = Theme.get()

    local function KeyTip(key: string, label: string)
        return Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 4,
            children = {
                Zenith.Box({
                    padding = { horizontal = 5, vertical = 2 },
                    border_radius = 4,
                    background = Zenith.hex(theme.surface_container, 140),
                    children = {
                        Zenith.Text({
                            text = key,
                            font_family = "JetBrainsMono Nerd Font",
                            font_size = 10,
                            font_weight = "bold",
                            color = Zenith.hex(theme.primary),
                        }),
                    },
                }),
                Zenith.Text({
                    text = label,
                    font_family = "Inter",
                    font_size = 11,
                    color = Zenith.hex(theme.on_surface_variant),
                }),
            },
        })
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space_between",
        width = "100%",
        padding = { horizontal = 8, vertical = 4 },
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 12,
                children = {
                    KeyTip("↑↓", "Navegar"),
                    KeyTip("↵", "Executar"),
                    KeyTip("ESC", "Fechar"),
                },
            }),
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 8,
                children = {
                    Zenith.Box({
                        cursor = "pointer",
                        tooltip = "Configurações",
                        on_click = "popup:toggle:Settings",
                        padding = 4,
                        children = {
                            Zenith.Text({ text = "󰒓", font_size = 13, color = Zenith.hex(theme.on_surface_variant) }),
                        },
                    }),
                    Zenith.Box({
                        cursor = "pointer",
                        tooltip = "Bloquear Tela",
                        on_click = "lock",
                        padding = 4,
                        children = {
                            Zenith.Text({ text = "󰌾", font_size = 13, color = Zenith.hex(theme.on_surface_variant) }),
                        },
                    }),
                },
            }),
        },
    })
end

return LauncherActions
