--!strict
local Widget = Zenith.import("widgets/shared/kde_connect/widget")
local Popup = Zenith.import("widgets/shared/kde_connect/popup")

local mod = {
    id = "kde_connect",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
