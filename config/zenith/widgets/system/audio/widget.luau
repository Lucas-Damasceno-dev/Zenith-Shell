--!strict
local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")
local PopupManager = Zenith.import("core/popup_manager")
local Services = Zenith.import("core/services/init")

return function(props: any?)
    local s = Services.Audio.status()
    local vol = s.volume or 0
    local muted = s.is_muted or s.muted or false
    local t = Theme.get()

    local icon = Icons.volume(vol, muted)
    local col = if muted then (t.error or "#f38ba8") else (t.on_surface or "#ffffff")

    return Zenith.Box({
        flex_direction = "row",
        align_items = "center",
        gap = 6,
        padding = { horizontal = 8, vertical = 4 },
        background = Theme.alpha(t.surface_container or t.surface, 150),
        border_radius = 12,
        on_click = PopupManager.toggle_action("audio"),
        on_right_click = "audio:toggle_mute",
        tooltip = string.format("Volume: %d%%%s (Clique: Painel | Direto: Mute)", vol, muted and " [Mudo]" or ""),
        children = {
            Zenith.Text({
                text = icon,
                font_family = "JetBrainsMono Nerd Font",
                font_size = 14,
                color = col,
            }),
            Zenith.Text({
                text = string.format("%d%%", vol),
                font_family = "JetBrainsMono Nerd Font",
                font_size = 12,
                color = col,
                font_weight = "medium",
            }),
        },
    })
end
