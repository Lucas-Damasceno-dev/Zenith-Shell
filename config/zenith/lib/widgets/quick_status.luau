--!strict
-- Zenith UI Kit - Quick Status & Connectivity Component (Audio + Wifi + Battery + Power)

local function QuickStatus()
    local theme = Zenith.Theme()
    local battery = Zenith.Services.battery()
    local audio = Zenith.Services.audio()
    local net = Zenith.Services.network()

    local bat_icon = "󰂄"
    local bat_pct = 100
    if battery then
        bat_pct = battery.percentage
        if battery.is_charging then
            bat_icon = "󰂄"
        elseif bat_pct > 80 then
            bat_icon = "󰁹"
        elseif bat_pct > 50 then
            bat_icon = "󰁿"
        elseif bat_pct > 20 then
            bat_icon = "󰁼"
        else
            bat_icon = "󰂃"
        end
    end

    local net_text = net.is_connected and (net.type == "wifi" and "󰖩 " .. net.ssid or "󰈀 Wired") or "󰤭 Disconnected"
    local audio_text = audio.is_muted and "󰝟 Muted" or string.format(" %d%%", audio.volume)

    return Zenith.Box({
        direction = "row",
        gap = 6,
        children = {
            -- Network & Audio
            Zenith.Box({
                direction = "row",
                gap = 8,
                padding = { x = 10, y = 4 },
                border_radius = 8,
                background = Zenith.hex(theme.surface),
                border_color = Zenith.hex("#2d3748"),
                border_width = 1,
                on_click = "cmd:pavucontrol &",
                children = {
                    Zenith.Text({
                        text = net_text,
                        font_size = 11,
                        color = Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Text({
                        text = audio_text,
                        font_size = 11,
                        color = Zenith.hex(theme.on_surface),
                    }),
                }
            }),

            -- Battery
            Zenith.Box({
                padding = { x = 8, y = 4 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container),
                children = {
                    Zenith.Text({
                        text = string.format("%s %d%%", bat_icon, bat_pct),
                        font_size = 11,
                        color = Zenith.hex(theme.primary),
                    })
                }
            }),

            -- Power Button
            Zenith.Box({
                padding = { x = 10, y = 4 },
                border_radius = 8,
                background = Zenith.hex("#e63946"),
                on_click = "cmd:notify-send 'Zenith Shell' 'Power session requested' -u critical",
                children = {
                    Zenith.Text({
                        text = "⏻",
                        font_size = 12,
                        color = Zenith.hex("#FFFFFF"),
                    })
                }
            })
        }
    })
end

return QuickStatus
