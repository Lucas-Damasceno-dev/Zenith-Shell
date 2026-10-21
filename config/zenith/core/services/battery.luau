--!strict
-- Zenith Desktop Shell — Battery & Power Profile Service
-- Bridges UPower state, charge limits and performance profiles

local BatteryService = {
    name = "battery",
    is_running = true,
}

export type BatteryStatus = {
    percentage: number,
    percent: number,
    status: string,
    charging: boolean,
    is_charging: boolean,
    cycle_count: number?,
    health_pct: number?,
    model_name: string?,
    uptime_str: string?,
}

function BatteryService.status(): BatteryStatus
    local raw = if Zenith.Services and Zenith.Services.Battery then Zenith.Services.Battery() else nil
    local pct = if raw and (raw.percentage or raw.percent) then (raw.percentage or raw.percent) else 100
    local is_chg = if raw and (raw.charging ~= nil or raw.is_charging ~= nil) then (if raw.charging ~= nil then raw.charging else raw.is_charging) else false
    return {
        percentage = pct,
        percent = pct,
        status = if raw and raw.status then raw.status else (if is_chg then "Charging" else "Discharging"),
        charging = is_chg,
        is_charging = is_chg,
        cycle_count = if raw then raw.cycle_count else nil,
        health_pct = if raw then raw.health_pct else nil,
        model_name = if raw then raw.model_name else nil,
        uptime_str = if raw then raw.uptime_str else nil,
    }
end

function BatteryService.set_profile(profile: string)
    if Zenith.Services and Zenith.Services.SetPowerProfile then
        Zenith.Services.SetPowerProfile(profile)
    end
end

function BatteryService.start()
    BatteryService.is_running = true
end

function BatteryService.stop()
    BatteryService.is_running = false
end

return BatteryService
