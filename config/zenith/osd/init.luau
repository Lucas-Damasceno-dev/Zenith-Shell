--!strict
-- Zenith Desktop Shell — Master OSD Module
-- Dispatches Volume, Brightness, Notification Toast and Power alerts

local Store = Zenith.import("core/store")
local VolumeBrightnessOsd = Zenith.import("osd/volume_brightness")
local NotificationToast = Zenith.import("osd/notification_toast")
local PowerAlert = Zenith.import("osd/power_alert")

local function Osd(props: { mode: string? }?)
    local osd_type = if props and props.mode then props.mode else Store.get("osd_type", "volume_brightness")

    if osd_type == "power" then
        return PowerAlert()
    elseif osd_type == "toast" then
        return NotificationToast()
    else
        return VolumeBrightnessOsd()
    end
end

local mod = {
    id = "osd",
    widget = Osd,
}

setmetatable(mod, {
    __call = function(_, props)
        return Osd(props)
    end,
})

return mod
