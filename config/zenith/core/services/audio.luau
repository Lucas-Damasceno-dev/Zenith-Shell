--!strict
-- Zenith Desktop Shell — Audio & PipeWire Service
-- Manages volume, mute state, default sinks, switcher and CAVA spectrum

local AudioService = {
    name = "audio",
    is_running = true,
}

export type AudioStatus = {
    volume: number,
    is_muted: boolean,
    muted: boolean,
}

export type AudioSinkItem = {
    id: number,
    name: string,
    is_default: boolean,
}

function AudioService.status(): AudioStatus
    if Zenith.Services and Zenith.Services.Audio then
        return Zenith.Services.Audio()
    end
    return { volume = 50, is_muted = false, muted = false }
end

function AudioService.sinks(): { AudioSinkItem }
    if Zenith.Services and Zenith.Services.AudioSinks then
        return Zenith.Services.AudioSinks()
    end
    return {}
end

function AudioService.set_sink(id: number)
    if Zenith.Services and Zenith.Services.SetAudioSink then
        Zenith.Services.SetAudioSink(id)
    end
end

function AudioService.set_volume(pct: number)
    local clamped = math.clamp(pct, 0, 100)
    if Zenith.Services and Zenith.Services.SetVolume then
        Zenith.Services.SetVolume(clamped)
    end
end

function AudioService.toggle_mute()
    if Zenith.Services and Zenith.Services.ToggleMute then
        Zenith.Services.ToggleMute()
    end
end

function AudioService.spectrum(count: number?): { number }
    if Zenith.Services and Zenith.Services.Spectrum then
        return Zenith.Services.Spectrum(count or 8)
    end
    return {}
end

function AudioService.start()
    AudioService.is_running = true
end

function AudioService.stop()
    AudioService.is_running = false
end

return AudioService
