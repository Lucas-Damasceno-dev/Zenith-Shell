--!strict
-- Zenith Desktop Shell — Bluetooth & BlueZ Service
-- Handles adapter power, paired and connected devices

local BluetoothService = {
    name = "bluetooth",
    is_running = true,
}

export type BluetoothDevice = {
    mac: string,
    name: string,
    connected: boolean,
    battery: number?,
}

export type BluetoothStatus = {
    powered: boolean,
    connected: boolean,
    device_name: string?,
    devices: { BluetoothDevice },
}

function BluetoothService.status(): BluetoothStatus
    local raw = if Zenith.Services and Zenith.Services.Bluetooth then Zenith.Services.Bluetooth() else nil
    if not raw then
        return { powered = false, connected = false, device_name = nil, devices = {} }
    end

    local powered = raw.powered == true
    local connected = raw.connected == true
    local device_name = raw.device_name
    local devices = raw.devices or {}

    if not connected then
        for _, d in ipairs(devices) do
            if d.connected then
                connected = true
                device_name = device_name or d.name
                break
            end
        end
    end

    if #devices == 0 and connected and device_name and #device_name > 0 then
        table.insert(devices, {
            mac = "default",
            name = device_name,
            connected = true,
            battery = nil,
        })
    end

    return {
        powered = powered,
        connected = connected,
        device_name = device_name,
        devices = devices,
    }
end

function BluetoothService.toggle()
    if Zenith.action then
        Zenith.action("bluetooth:toggle")
    elseif Zenith.exec then
        Zenith.exec("zenith bluetooth-toggle")
    end
end

function BluetoothService.start()
    BluetoothService.is_running = true
end

function BluetoothService.stop()
    BluetoothService.is_running = false
end

return BluetoothService
