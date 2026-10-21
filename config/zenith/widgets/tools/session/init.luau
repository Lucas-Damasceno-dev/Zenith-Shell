--!strict
local Widget = Zenith.import("widgets/tools/session/widget")
local Popup = Zenith.import("widgets/tools/session/popup")

local mod = {
    id = "session",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
