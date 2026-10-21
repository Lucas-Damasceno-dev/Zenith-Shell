--!strict
local Widget = Zenith.import("widgets/tools/weather/widget")
local Popup = Zenith.import("widgets/tools/weather/popup")

local mod = {
    id = "weather",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
