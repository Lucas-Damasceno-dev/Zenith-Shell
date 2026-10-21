--!strict
-- Zenith Desktop Shell — Hardware & System Metrics Service
-- Monitors CPU load, RAM usage, storage and screen brightness

local HardwareService = {
    name = "hardware",
    is_running = true,
}

export type CpuStatus = {
    usage_percent: number,
    percent: number, -- backward-compat alias
    cores: number,
    model: string,
}

export type MemoryStatus = {
    total_mb: number,
    used_mb: number,
    free_mb: number,
    percent: number,
}

export type DiskStatus = {
    total_gb: number,
    used_gb: number,
    free_gb: number,
    percent: number,
}

function HardwareService.cpu(): CpuStatus
    if Zenith.Services and Zenith.Services.Cpu then
        local res = Zenith.Services.Cpu()
        local pct = res.usage_percent or res.percent or 0
        return {
            usage_percent = pct,
            percent = pct,
            cores = res.cores or 1,
            model = res.model or "CPU",
        }
    end
    return { usage_percent = 0, percent = 0, cores = 1, model = "CPU" }
end

function HardwareService.memory(): MemoryStatus
    if Zenith.Services and Zenith.Services.Memory then
        local res = Zenith.Services.Memory()
        return {
            total_mb = res.total_mb or 0,
            used_mb = res.used_mb or 0,
            free_mb = res.free_mb or 0,
            percent = res.percent or 0,
        }
    end
    return { total_mb = 0, used_mb = 0, free_mb = 0, percent = 0 }
end

function HardwareService.disk(): DiskStatus
    if Zenith.Services and Zenith.Services.Disk then
        local res = Zenith.Services.Disk()
        return {
            total_gb = res.total_gb or 0,
            used_gb = res.used_gb or 0,
            free_gb = res.free_gb or 0,
            percent = res.percent or 0,
        }
    end
    return { total_gb = 0, used_gb = 0, free_gb = 0, percent = 0 }
end

function HardwareService.brightness(): number
    if Zenith.Services and Zenith.Services.Brightness then
        local b = Zenith.Services.Brightness()
        if typeof(b) == "table" and b.percent ~= nil then
            return b.percent
        elseif typeof(b) == "number" then
            return b
        end
    end
    return 100
end

function HardwareService.set_brightness(pct: number)
    local clamped = math.clamp(pct, 1, 100)
    if Zenith.Services and Zenith.Services.SetBrightness then
        Zenith.Services.SetBrightness(clamped)
    end
end

function HardwareService.step_brightness(delta: number)
    if Zenith.Services and Zenith.Services.StepBrightness then
        Zenith.Services.StepBrightness(delta)
    end
end

function HardwareService.start()
    HardwareService.is_running = true
end

function HardwareService.stop()
    HardwareService.is_running = false
end

return HardwareService
