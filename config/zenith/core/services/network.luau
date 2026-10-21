--!strict
-- Zenith Desktop Shell — Network & Connectivity Service
-- Provides NetworkManager / iwd connection state, Wi-Fi SSID, strength and scan

local NetworkService = {
    name = "network",
    is_running = true,
}

export type NetworkStatus = {
    connected: boolean,
    is_connected: boolean,
    ssid: string?,
    strength: number?,
    signal: number, -- alias for strength
    ethernet: boolean,
    type: string,
    ip: string?,
}

export type WifiScanItem = {
    ssid: string,
    strength: number,
    signal: number, -- alias for strength
    security: string,
    in_use: boolean?,
}

function NetworkService.status(): NetworkStatus
    if Zenith.Services and Zenith.Services.Network then
        local s = Zenith.Services.Network()
        local strength_val = s.strength or s.signal or 0
        local is_conn = if s.connected ~= nil then s.connected else (s.is_connected or false)
        return {
            connected = is_conn,
            is_connected = is_conn,
            ssid = s.ssid,
            strength = strength_val,
            signal = strength_val,
            ethernet = s.ethernet or (s.type == "ethernet"),
            type = s.type or (if is_conn then "wifi" else "none"),
            ip = s.ip or s.ip_address,
        }
    end
    return {
        connected = false,
        is_connected = false,
        ssid = nil,
        strength = 0,
        signal = 0,
        ethernet = false,
        type = "none",
        ip = nil,
    }
end

function NetworkService.scan(): { WifiScanItem }
    if Zenith.Services and Zenith.Services.WifiScan then
        local raw = Zenith.Services.WifiScan()
        local list = {}
        for idx, item in ipairs(raw) do
            local str = item.strength or item.signal or 0
            table.insert(list, {
                ssid = item.ssid or "",
                strength = str,
                signal = str,
                security = item.security or "WPA2",
                in_use = item.in_use,
            })
        end
        return list
    end
    return {}
end

function NetworkService.set_wifi_enabled(enabled: boolean)
    if Zenith.Services and Zenith.Services.SetWifiEnabled then
        Zenith.Services.SetWifiEnabled(enabled)
    end
end

function NetworkService.start()
    NetworkService.is_running = true
end

function NetworkService.stop()
    NetworkService.is_running = false
end

return NetworkService
