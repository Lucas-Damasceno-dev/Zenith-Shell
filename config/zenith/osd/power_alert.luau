--!strict
-- Zenith Desktop Shell — OSD Low Battery Warning Alert
-- Displays urgent notification when power reserves fall below safety thresholds

local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")

local function PowerAlert(props: { percent: number?, is_critical: boolean? }?)
    local theme = Theme.get()
    local bat = Services.Battery.status()
    local pct = if props and props.percent then props.percent else bat.percentage
    local is_crit = if props and props.is_critical ~= nil then props.is_critical else (pct <= 5)

    local alert_color = Zenith.hex(theme.error or "#f38ba8")

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        width = 300,
        height = 70,
        padding = { horizontal = 16, vertical = 10 },
        border_radius = 20,
        background = Zenith.hex(theme.surface_container_highest or theme.surface, 240),
        border_color = alert_color,
        border_width = 1,
        shadow = {
            color = Zenith.rgba(0, 0, 0, 160),
            blur = 22,
            offset_x = 0,
            offset_y = 6,
        },
        gap = 14,
        children = {
            Zenith.Box({
                width = 40,
                height = 40,
                border_radius = 20,
                background = Zenith.hex(theme.error or "#f38ba8", 40),
                align_items = "center",
                justify_content = "center",
                children = {
                    Zenith.Text({
                        text = if is_crit then "󰂃" else "󰁺",
                        font_size = 22,
                        color = alert_color,
                    }),
                },
            }),
            Zenith.Box({
                direction = "column",
                gap = 2,
                children = {
                    Zenith.Text({
                        text = if is_crit then "Bateria Crítica!" else "Bateria Fraca",
                        font_family = "Inter",
                        font_size = 13,
                        font_weight = "bold",
                        color = alert_color,
                    }),
                    Zenith.Text({
                        text = string.format("%d%% restantes • Conecte o carregador", pct),
                        font_family = "Inter",
                        font_size = 11,
                        color = Zenith.hex(theme.on_surface_variant),
                    }),
                },
            }),
        },
    })
end

return PowerAlert
