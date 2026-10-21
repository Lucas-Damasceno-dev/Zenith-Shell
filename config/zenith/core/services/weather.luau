--!strict
-- Zenith Desktop Shell — Weather Information Service
-- Provides temperature, condition descriptions, weather icons and city location

local WeatherService = {
    name = "weather",
    is_running = true,
}

export type WeatherSnapshot = {
    temp: number,
    condition: string,
    icon: string,
    city: string,
}

function WeatherService.get(): WeatherSnapshot
    if Zenith.Services and Zenith.Services.Weather then
        return Zenith.Services.Weather()
    end
    return {
        temp = 20,
        condition = "Clear",
        icon = "󰖙",
        city = "Local",
    }
end

WeatherService.current = WeatherService.get

function WeatherService.start()
    WeatherService.is_running = true
end

function WeatherService.stop()
    WeatherService.is_running = false
end

return WeatherService
