--!strict
-- Zenith UI Kit - Launcher Pill Component (NixOS / End-4 style)

local Pill = Zenith.import("widgets/pill")

local function Launcher(props: { text: string?, on_click: string? }?)
    local theme = Zenith.Theme()
    local text = props and props.text or ""
    local on_click = props and props.on_click or "popup:toggle:Launcher"

    return Pill({
        icon = text,
        icon_size = 13,
        icon_color = Zenith.hex(theme.primary),
        variant = "accent_chip",
        height = 26,
        border_radius = 13,
        padding = { x = 9, y = 2 },
        tooltip = "Menu de Aplicativos (Launcher)\n• Clique: Abrir Launcher\n• Botão Direito: Alternar Modo Compacto\n• Scroll: Alternar Workspaces",
        on_click = on_click,
        on_right_click = "bar:toggle_compact",
        on_scroll_up = "dispatch:workspace:m+1",
        on_scroll_down = "dispatch:workspace:m-1",
    })
end

return Launcher
