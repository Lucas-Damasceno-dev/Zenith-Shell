--!strict
local Widget = Zenith.import("widgets/system/network/widget")
local Popup = Zenith.import("widgets/system/network/popup")

local mod = {
    id = "network",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
