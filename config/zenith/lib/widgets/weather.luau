--!strict
-- Zenith UI Kit - Weather Status Component (Quickshell Parity)
-- Matches BarWeatherStatus.qml (Live temperature & weather condition pill)

local Pill = Zenith.import("widgets/pill")

local function WeatherWidget()
    local theme = Zenith.Theme()
    local weather_snap = (Zenith.Services.Weather and Zenith.Services.Weather()) or (Zenith.Services.weather and Zenith.Services.weather()) or { temp = 22, condition = "Limpo", icon = "󰖐", city = "Local" }

    local temp_c = weather_snap.temp or 22
    local cond = weather_snap.condition or "Limpo"
    local city = weather_snap.city or "Local"

    local weather_icon = weather_snap.icon or "󰖐"
    if #weather_icon == 0 then
        local c = string.lower(cond)
        if c:find("chuva") or c:find("rain") then
            weather_icon = "󰖗"
        elseif c:find("nuvem") or c:find("cloud") or c:find("nublado") then
            weather_icon = "󰖐"
        elseif c:find("sol") or c:find("clear") or c:find("limpo") then
            weather_icon = "󰖙"
        elseif c:find("neve") or c:find("snow") then
            weather_icon = "󰖘"
        elseif c:find("trovoada") or c:find("storm") then
            weather_icon = "󰖒"
        else
            weather_icon = "󰖐"
        end
    end

    local temp_str = string.format("%d°C", temp_c)
    local tooltip = string.format("Clima: %s, %s • %s\n• Clique: Detalhes do Clima\n• Botão Direito: Atualizar Previsão", city, cond, temp_str)

    return Pill({
        icon = weather_icon,
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        label = temp_str,
        label_size = 11,
        height = 26,
        border_radius = 13,
        padding = { x = 8, y = 2 },
        gap = 4,
        tooltip = tooltip,
        on_click = "cmd:notify-send -a 'Previsão do Tempo' '" .. city .. "' '" .. cond .. " (" .. temp_str .. ")' &",
        on_right_click = "cmd:notify-send -a 'Previsão do Tempo' 'Atualizando previsão...' &",
    })
end

return WeatherWidget
