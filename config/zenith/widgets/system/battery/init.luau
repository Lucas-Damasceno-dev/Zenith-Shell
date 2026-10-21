--!strict
local Widget = Zenith.import("widgets/system/battery/widget")
local Popup = Zenith.import("widgets/system/battery/popup")

local mod = {
    id = "battery",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
