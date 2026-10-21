--!strict
-- Zenith Desktop Shell — Core Services Registry
-- Lazy-loaded system singletons unified with memory cache in _G

if _G.__zenith_services then
    return _G.__zenith_services
end

local Services = {
    Hyprland = Zenith.import("core/services/hyprland"),
    Audio = Zenith.import("core/services/audio"),
    Network = Zenith.import("core/services/network"),
    Bluetooth = Zenith.import("core/services/bluetooth"),
    Hardware = Zenith.import("core/services/hardware"),
    Battery = Zenith.import("core/services/battery"),
    Mpris = Zenith.import("core/services/mpris"),
    Notifications = Zenith.import("core/services/notifications"),
    Tray = Zenith.import("core/services/tray"),
    Weather = Zenith.import("core/services/weather"),
    Power = Zenith.import("core/services/power"),
    Launcher = Zenith.import("core/services/launcher"),
}

function Services.start()
    for _, srv in pairs(Services) do
        if type(srv) == "table" and type(srv.start) == "function" then
            pcall(function() srv.start() end)
        end
    end
end

function Services.stop()
    for _, srv in pairs(Services) do
        if type(srv) == "table" and type(srv.stop) == "function" then
            pcall(function() srv.stop() end)
        end
    end
end

_G.__zenith_services = Services
return Services
