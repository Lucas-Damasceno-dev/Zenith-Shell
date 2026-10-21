--!strict
local Widget = Zenith.import("widgets/tools/usb/widget")
local Popup = Zenith.import("widgets/tools/usb/popup")

local mod = {
    id = "usb",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
