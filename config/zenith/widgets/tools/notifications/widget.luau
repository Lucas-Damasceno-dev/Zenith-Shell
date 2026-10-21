--!strict
-- Zenith-Shell: Notification Status Widget

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")
local PopupManager = Zenith.import("core/popup_manager")

local function NotificationStatus()
    local theme = Theme.get()
    local notifs = Services.Notifications.list()
    local is_dnd = Services.Notifications.is_dnd()

    local notif_count = #notifs
    local icon = if is_dnd then "󰂛" elseif notif_count > 0 then "󰂚" else "󰂜"
    local icon_color = if is_dnd then Zenith.hex(theme.error or "#f38ba8")
        elseif notif_count > 0 then Zenith.hex(theme.primary)
        else Zenith.hex(theme.on_surface_variant or theme.outline, 160)

    local tooltip = (if is_dnd then
        string.format("Não Perturbe (DND) Ativo • %d notificações silenciadas\n• Clique: Abrir Central\n• Botão Direito: Desativar DND", notif_count)
    else
        string.format("Notificações: %d ativas\n• Clique: Abrir Central de Notificações\n• Botão Direito: Ativar Não Perturbe (DND)", notif_count)) .. "\n• Scroll: Limpar Todas"

    local badge_str = if notif_count > 0 then tostring(notif_count) else nil

    return Pill({
        icon = icon,
        icon_size = 12,
        icon_color = icon_color,
        badge = badge_str,
        badge_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { horizontal = 8, vertical = 2 },
        tooltip = tooltip,
        on_click = PopupManager.toggle_action("NotificationCenter"),
        on_right_click = "notification:toggle_dnd",
        on_scroll_up = "notification:clear",
        on_scroll_down = "notification:clear",
    })
end

return NotificationStatus
