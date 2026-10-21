--!strict
local Widget = Zenith.import("widgets/system/audio/widget")
local Popup = Zenith.import("widgets/system/audio/popup")

local mod = {
    id = "audio",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
