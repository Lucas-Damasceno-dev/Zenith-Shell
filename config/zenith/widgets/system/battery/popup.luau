--!strict
local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")
local Card = Zenith.import("core/ui/card")
local Button = Zenith.import("core/ui/button")
local Services = Zenith.import("core/services/init")

return function()
    local b = Services.Battery.status()
    local pct = if b then (b.percentage or b.percent or 100) else 100
    local charging = if b then (b.charging or b.is_charging or false) else false
    local status_str = if b then (b.status or (charging and "Carregando" or "Descarregando")) else "Plugado"
    local t = Theme.get()

    return Card({
        variant = "glass",
        width = 300,
        gap = 12,
        padding = 16,
        children = {
            Zenith.Box({
                width = "100%",
                flex_direction = "row",
                align_items = "center",
                gap = 10,
                children = {
                    Zenith.Text({
                        text = Icons.battery(pct, charging),
                        font_family = "JetBrainsMono Nerd Font",
                        font_size = 28,
                        color = t.primary or "#7c4dff",
                    }),
                    Zenith.Box({
                        flex_direction = "column",
                        gap = 2,
                        children = {
                            Zenith.Text({
                                text = string.format("%d%% • %s", pct, status_str),
                                font_family = "JetBrainsMono Nerd Font",
                                font_size = 15,
                                font_weight = "bold",
                                color = t.on_surface or "#ffffff",
                            }),
                            Zenith.Text({
                                text = if b and b.model_name then b.model_name else "Bateria Interna",
                                font_family = "JetBrainsMono Nerd Font",
                                font_size = 11,
                                color = Theme.alpha(t.on_surface or "#ffffff", 160),
                            }),
                        },
                    }),
                },
            }),
            Zenith.Text({
                text = "Perfil de Energia (power-profiles-daemon)",
                font_family = "JetBrainsMono Nerd Font",
                font_size = 12,
                font_weight = "medium",
                color = Theme.alpha(t.on_surface or "#ffffff", 180),
            }),
            Zenith.Box({
                width = "100%",
                flex_direction = "column",
                gap = 6,
                children = {
                    Button({
                        label = "Economia de Energia",
                        icon = Icons.glyphs.leaf or "󰌪",
                        variant = "tonal",
                        width = "100%",
                        on_click = "power:profile:power-saver",
                    }),
                    Button({
                        label = "Equilibrado (Padrão)",
                        icon = Icons.glyphs.balance or "󰗑",
                        variant = "primary",
                        width = "100%",
                        on_click = "power:profile:balanced",
                    }),
                    Button({
                        label = "Alto Desempenho",
                        icon = Icons.glyphs.rocket or "󰓅",
                        variant = "tonal",
                        width = "100%",
                        on_click = "power:profile:performance",
                    }),
                },
            }),
        },
    })
end
