--!strict
local Widget = Zenith.import("widgets/media/mpris/widget")
local Popup = Zenith.import("widgets/media/mpris/popup")

local mod = {
    id = "mpris",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
