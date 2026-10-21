--!strict
local Widget = Zenith.import("widgets/tools/notifications/widget")
local Popup = Zenith.import("widgets/tools/notifications/popup")

local mod = {
    id = "notifications",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
