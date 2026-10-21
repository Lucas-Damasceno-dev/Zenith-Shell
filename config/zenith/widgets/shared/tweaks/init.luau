--!strict
local Widget = Zenith.import("widgets/shared/tweaks/widget")
local Popup = Zenith.import("widgets/shared/tweaks/popup")

local mod = {
    id = "tweaks",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
