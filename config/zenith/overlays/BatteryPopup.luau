--!strict
-- Zenith-Shell (Engine v2) - Battery & Power Profile Overlay
-- 1:1 Parity with Quickshell BatteryPopup (Battery Stats, Health & Power Profiles)

local theme = Zenith.Theme()
local battery = Zenith.Services.battery()
local power_profile = (Zenith.Services.PowerProfile and Zenith.Services.PowerProfile()) or "balanced"

local bat_pct = 100
local is_charging = false
local bat_status = "Desconhecido"

if battery then
    bat_pct = battery.percentage or 100
    is_charging = battery.is_charging or false
    bat_status = battery.status or (if is_charging then "Carregando" else "Descarregando")
end

local bat_icon = "󰁹"
local bat_color = theme.primary
if is_charging then
    bat_icon = "󰂄"
    bat_color = theme.green or "#a6e3a1"
elseif bat_pct > 80 then
    bat_icon = "󰁹"
    bat_color = theme.primary
elseif bat_pct > 50 then
    bat_icon = "󰁿"
    bat_color = theme.primary
elseif bat_pct > 20 then
    bat_icon = "󰁼"
    bat_color = theme.yellow or "#f9e2af"
else
    bat_icon = "󰂃"
    bat_color = theme.error or "#f38ba8"
end

local current_prof = string.lower(power_profile)

local function ProfileButton(props: {
    id: string,
    name: string,
    icon: string,
    profile_key: string,
})
    local is_active = (current_prof == props.profile_key)
    local bg = is_active and Zenith.hex(theme.primary, 45) or Zenith.hex(theme.surface_container, 100)
    local border = is_active and Zenith.hex(theme.primary) or Zenith.hex(theme.outline_variant or theme.outline, 40)
    local text_color = is_active and Zenith.hex(theme.primary) or Zenith.hex(theme.on_surface)

    return Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        flex_grow = 1,
        height = 68,
        gap = 4,
        padding = { x = 6, y = 6 },
        border_radius = 12,
        background = bg,
        border_color = border,
        border_width = 1,
        tooltip = "Definir modo " .. props.name,
        on_click = "cmd:powerprofilesctl set " .. props.profile_key .. " &",
        children = {
            Zenith.Text({
                text = props.icon,
                font_size = 18,
                color = text_color,
            }),
            Zenith.Text({
                text = props.name,
                font_size = 10,
                font_weight = is_active and "medium" or "normal",
                color = text_color,
            }),
            Zenith.Text({
                text = is_active and "● ATIVO" or " ",
                font_size = 8,
                color = is_active and Zenith.hex(theme.primary) or Zenith.rgba(0, 0, 0, 0),
            }),
        }
    })
end

return Zenith.Window({
    direction = "column",
    width = 340,
    height = 360,
    padding = { x = 16, y = 14 },
    gap = 12,
    background = Zenith.hex(theme.surface, 235),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
    border_width = 1,
    border_radius = 18,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 22,
        offset_x = 0,
        offset_y = 8,
    },
    children = {
        -- Header: Title + Close Button
        Zenith.Box({
            direction = "row",
            align_items = "center",
            children = {
                Zenith.Text({
                    text = "󰂄 Bateria & Energia",
                    font_size = 13,
                    font_weight = "medium",
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 7, y = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "ESC", font_size = 9, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            }
        }),

        -- Main Battery Status Big Card
        Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { x = 14, y = 14 },
            border_radius = 14,
            background = Zenith.hex(theme.surface_container_high or theme.surface_container, 140),
            border_color = Zenith.hex(bat_color, 80),
            border_width = 1,
            gap = 14,
            children = {
                Zenith.Box({
                    width = 48,
                    height = 48,
                    align_items = "center",
                    justify_content = "center",
                    border_radius = 24,
                    background = Zenith.hex(bat_color, 35),
                    children = {
                        Zenith.Text({
                            text = bat_icon,
                            font_size = 24,
                            color = Zenith.hex(bat_color),
                        }),
                    }
                }),
                Zenith.Box({
                    direction = "column",
                    gap = 2,
                    flex_grow = 1,
                    children = {
                        Zenith.Box({
                            direction = "row",
                            align_items = "baseline",
                            gap = 6,
                            children = {
                                Zenith.Text({
                                    text = string.format("%d%%", bat_pct),
                                    font_size = 20,
                                    font_weight = "bold",
                                    color = Zenith.hex(theme.on_surface),
                                }),
                                Zenith.Text({
                                    text = if is_charging then "(Carregando)" else "(Bateria)",
                                    font_size = 11,
                                    color = Zenith.hex(bat_color),
                                }),
                            }
                        }),
                        Zenith.Text({
                            text = "Status: " .. bat_status,
                            font_size = 10,
                            color = Zenith.hex(theme.outline),
                        }),
                    }
                }),
            }
        }),

        -- Power Profiles Section Header
        Zenith.Box({
            direction = "row",
            align_items = "center",
            children = {
                Zenith.Text({
                    text = "PERFIS DE DESEMPENHO",
                    font_size = 10,
                    font_weight = "bold",
                    color = Zenith.hex(theme.outline),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Text({
                    text = "power-profiles-daemon",
                    font_size = 9,
                    color = Zenith.hex(theme.outline, 160),
                }),
            }
        }),

        -- Profile Buttons: Power Saver, Balanced
        Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 8,
            children = {
                ProfileButton({
                    id = "btn_power_saver",
                    name = "Economia",
                    icon = "󰌪",
                    profile_key = "power-saver",
                }),
                ProfileButton({
                    id = "btn_balanced",
                    name = "Equilíbrio",
                    icon = "󰓅",
                    profile_key = "balanced",
                }),
            }
        }),

        -- Quick Action Tile: Economia Noturna / Suspender
        Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { x = 12, y = 8 },
            border_radius = 10,
            background = Zenith.hex(theme.surface_container, 100),
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 35),
            border_width = 1,
            on_click = "cmd:systemctl suspend &",
            children = {
                Zenith.Text({
                    text = "󰒲",
                    font_size = 14,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ width = 10 }),
                Zenith.Text({
                    text = "Suspender Sistema",
                    font_size = 11,
                    color = Zenith.hex(theme.on_surface),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Text({
                    text = "Modo Baixo Consumo",
                    font_size = 9,
                    color = Zenith.hex(theme.outline),
                }),
            }
        })
    }
})
