--!strict
local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")
local PopupManager = Zenith.import("core/popup_manager")
local Services = Zenith.import("core/services/init")

return function(props: any?)
    local b = Services.Battery.status()
    local pct = if b then (b.percentage or b.percent or 100) else 100
    local charging = if b then (b.charging or b.is_charging or false) else false
    local t = Theme.get()

    local icon = Icons.battery(pct, charging)
    local col = if pct <= 15 and not charging then (t.error or "#f38ba8") else (t.on_surface or "#ffffff")

    return Zenith.Box({
        flex_direction = "row",
        align_items = "center",
        gap = 6,
        padding = { horizontal = 8, vertical = 4 },
        background = Theme.alpha(t.surface_container or t.surface, 150),
        border_radius = 12,
        on_click = PopupManager.toggle_action("battery"),
        on_right_click = "power:profile:performance",
        tooltip = string.format("Bateria: %d%%%s (Clique: Perfis)", pct, charging and " [Carregando]" or ""),
        children = {
            Zenith.Text({
                text = icon,
                font_family = "JetBrainsMono Nerd Font",
                font_size = 14,
                color = col,
            }),
            Zenith.Text({
                text = string.format("%d%%", pct),
                font_family = "JetBrainsMono Nerd Font",
                font_size = 12,
                color = col,
                font_weight = "medium",
            }),
        },
    })
end
