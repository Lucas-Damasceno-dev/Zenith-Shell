--!strict
local Widget = Zenith.import("widgets/desktop/clock/widget")
local Popup = Zenith.import("widgets/desktop/clock/popup")

local mod = {
    id = "clock",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
