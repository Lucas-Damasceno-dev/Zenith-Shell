--!strict
-- Zenith Desktop Shell — Desktop Notification Daemon Service
-- Manages active notifications, notification history, and DND mode

local NotificationService = {
    name = "notifications",
    is_running = true,
}

export type NotificationItem = {
    id: number,
    app_name: string,
    app_icon: string?,
    summary: string,
    body: string,
    urgency: number,
    timestamp: number,
}

function NotificationService.list(): { NotificationItem }
    if Zenith.Services and Zenith.Services.Notifications then
        return Zenith.Services.Notifications()
    end
    return {}
end

function NotificationService.history(): { NotificationItem }
    if Zenith.Services and Zenith.Services.NotificationHistory then
        return Zenith.Services.NotificationHistory()
    end
    return {}
end

function NotificationService.close(id: number)
    if Zenith.Services and Zenith.Services.NotificationClose then
        Zenith.Services.NotificationClose(id)
    end
end

function NotificationService.clear_all()
    if Zenith.Services and Zenith.Services.NotificationClear then
        Zenith.Services.NotificationClear()
    end
end

function NotificationService.clear_history()
    if Zenith.Services and Zenith.Services.ClearNotificationHistory then
        Zenith.Services.ClearNotificationHistory()
    elseif Zenith.Services and Zenith.Services.ClearHistory then
        Zenith.Services.ClearHistory()
    end
end

function NotificationService.toggle_dnd(): boolean
    if Zenith.Services and Zenith.Services.ToggleDND then
        return Zenith.Services.ToggleDND()
    end
    return false
end

function NotificationService.is_dnd(): boolean
    if Zenith.Services and Zenith.Services.IsDND then
        return Zenith.Services.IsDND()
    end
    return false
end

function NotificationService.start()
    NotificationService.is_running = true
end

function NotificationService.stop()
    NotificationService.is_running = false
end

return NotificationService
