--!strict
-- Zenith Desktop Shell — Dock Trash Can Item
-- Quick access to trash directory and empty trash action

local Theme = Zenith.import("core/theme")

local function DockTrash()
    local theme = Theme.get()

    return Zenith.Box({
        cursor = "pointer",
        tooltip = "Lixeira • Clique: Abrir • Botão Direito: Esvaziar",
        on_click = "trash:///",
        on_right_click = "trash-empty",
        width = 34,
        height = 34,
        border_radius = 10,
        background = Zenith.hex(theme.surface_container_highest, 90),
        align_items = "center",
        justify_content = "center",
        children = {
            Zenith.Text({
                text = "󰩹",
                font_size = 16,
                color = Zenith.hex(theme.on_surface_variant),
            }),
        },
    })
end

return DockTrash
