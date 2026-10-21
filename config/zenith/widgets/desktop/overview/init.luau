--!strict
local Widget = Zenith.import("widgets/desktop/overview/widget")
local Popup = Zenith.import("widgets/desktop/overview/popup")

local mod = {
    id = "overview",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
