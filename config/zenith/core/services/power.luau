--!strict
-- Zenith Desktop Shell — Power Management & Idle Service
-- Controls system power profiles, suspend, reboot, power-off and screen idle inhibition

local PowerService = {
    name = "power",
    is_running = true,
}

export type IdleState = {
    is_idle: boolean,
    idle: boolean,
}

function PowerService.profile(): string
    if Zenith.Services and Zenith.Services.PowerProfile then
        return Zenith.Services.PowerProfile()
    end
    return "balanced"
end

function PowerService.set_profile(profile: string)
    if Zenith.Services and Zenith.Services.SetPowerProfile then
        Zenith.Services.SetPowerProfile(profile)
    end
end

function PowerService.suspend()
    if Zenith.Services and Zenith.Services.Suspend then
        Zenith.Services.Suspend()
    elseif Zenith.exec then
        Zenith.exec("systemctl suspend")
    end
end

function PowerService.reboot()
    if Zenith.Services and Zenith.Services.Reboot then
        Zenith.Services.Reboot()
    elseif Zenith.exec then
        Zenith.exec("systemctl reboot")
    end
end

function PowerService.power_off()
    if Zenith.Services and Zenith.Services.PowerOff then
        Zenith.Services.PowerOff()
    elseif Zenith.exec then
        Zenith.exec("systemctl poweroff")
    end
end

function PowerService.idle(): IdleState
    if Zenith.Services and Zenith.Services.Idle then
        return Zenith.Services.Idle()
    end
    local i = PowerService.is_idle()
    return { is_idle = i, idle = i }
end

function PowerService.is_idle(): boolean
    if Zenith.Services and Zenith.Services.IsIdle then
        return Zenith.Services.IsIdle()
    elseif Zenith.is_idle then
        return Zenith.is_idle()
    end
    return false
end

function PowerService.set_idle(idle: boolean)
    if Zenith.Services and Zenith.Services.SetIdle then
        Zenith.Services.SetIdle(idle)
    elseif Zenith.set_idle then
        Zenith.set_idle(idle)
    end
end

function PowerService.start()
    PowerService.is_running = true
end

function PowerService.stop()
    PowerService.is_running = false
end

return PowerService
