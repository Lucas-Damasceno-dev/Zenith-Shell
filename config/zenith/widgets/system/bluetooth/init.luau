--!strict
local Widget = Zenith.import("widgets/system/bluetooth/widget")
local Popup = Zenith.import("widgets/system/bluetooth/popup")

local mod = {
    id = "bluetooth",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
