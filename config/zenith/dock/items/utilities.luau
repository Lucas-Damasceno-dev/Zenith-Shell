--!strict
-- Zenith Desktop Shell — Dock Utility Shortcuts Item
-- Provides terminal dropdown and screenshot capture actions

local Theme = Zenith.import("core/theme")

local function DockUtilities()
    local theme = Theme.get()

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = 4,
        children = {
            Zenith.Box({
                cursor = "pointer",
                tooltip = "Terminal Rápido (Dropdown)",
                on_click = "quick-term",
                width = 32,
                height = 32,
                border_radius = 8,
                background = Zenith.hex(theme.surface_container_highest, 100),
                align_items = "center",
                justify_content = "center",
                children = {
                    Zenith.Text({ text = "", font_size = 14, color = Zenith.hex(theme.primary) }),
                },
            }),
            Zenith.Box({
                cursor = "pointer",
                tooltip = "Captura de Região (Slurp)",
                on_click = "screenshot:area",
                width = 32,
                height = 32,
                border_radius = 8,
                background = Zenith.hex(theme.surface_container_highest, 100),
                align_items = "center",
                justify_content = "center",
                children = {
                    Zenith.Text({ text = "󰄀", font_size = 14, color = Zenith.hex(theme.on_surface) }),
                },
            }),
            Zenith.Box({
                cursor = "pointer",
                tooltip = "Captura de Tela Inteira (Grim)",
                on_click = "screenshot:full",
                width = 32,
                height = 32,
                border_radius = 8,
                background = Zenith.hex(theme.surface_container_highest, 100),
                align_items = "center",
                justify_content = "center",
                children = {
                    Zenith.Text({ text = "󰹑", font_size = 14, color = Zenith.hex(theme.on_surface) }),
                },
            }),
        },
    })
end

return DockUtilities
