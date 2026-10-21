--!strict
local Widget = Zenith.import("widgets/system/hardware/widget")
local Popup = Zenith.import("widgets/system/hardware/popup")

local mod = {
    id = "hardware",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
