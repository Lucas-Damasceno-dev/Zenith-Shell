--!strict
-- Zenith-Shell: Application Launcher Pill Widget

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

type LauncherProps = {
    text: string?,
    on_click: string?,
}

local function Launcher(props: LauncherProps?)
    local theme = Theme.get()
    local text = (props and props.text) or ""
    local on_click = (props and props.on_click) or PopupManager.toggle_action("Launcher")

    return Pill({
        icon = text,
        icon_size = 13,
        icon_color = Zenith.hex(theme.primary),
        variant = "accent_chip",
        height = 26,
        border_radius = 13,
        padding = { horizontal = 9, vertical = 2 },
        tooltip = "Menu de Aplicativos (Launcher)\n• Clique: Abrir Launcher\n• Botão Direito: Alternar Modo Compacto\n• Scroll: Alternar Workspaces",
        on_click = on_click,
        on_right_click = "bar:toggle_compact",
        on_scroll_up = "dispatch:workspace:m+1",
        on_scroll_down = "dispatch:workspace:m-1",
    })
end

return Launcher
