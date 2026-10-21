--!strict
-- Zenith Desktop Shell — System Tray (StatusNotifierItem) Service
-- Manages DBus StatusNotifierItem items, icon resolution and context menu actions

local TrayService = {
    name = "tray",
    is_running = true,
}

export type TrayItem = {
    id: string,
    title: string,
    icon: string,
    icon_name: string?,
    service: string,
    action: string?,
    context_action: string?,
    secondary_action: string?,
}

function TrayService.items(): { TrayItem }
    if Zenith.Services and Zenith.Services.Tray then
        return Zenith.Services.Tray()
    end
    return {}
end

function TrayService.activate(service: string)
    if Zenith.Services and Zenith.Services.TrayActivate then
        Zenith.Services.TrayActivate(service)
    end
end

function TrayService.context_menu(service: string)
    if Zenith.Services and Zenith.Services.TrayContextMenu then
        Zenith.Services.TrayContextMenu(service)
    end
end

function TrayService.secondary_activate(service: string)
    if Zenith.Services and Zenith.Services.TraySecondaryActivate then
        Zenith.Services.TraySecondaryActivate(service)
    end
end

function TrayService.scroll(service: string, delta: number, orientation: string?)
    if Zenith.Services and Zenith.Services.TrayScroll then
        Zenith.Services.TrayScroll(service, delta, orientation or "vertical")
    end
end

function TrayService.start()
    TrayService.is_running = true
end

function TrayService.stop()
    TrayService.is_running = false
end

return TrayService
