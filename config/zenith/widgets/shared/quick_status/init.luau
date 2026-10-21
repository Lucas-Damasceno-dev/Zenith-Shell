--!strict
local Widget = Zenith.import("widgets/shared/quick_status/widget")

local mod = {
    id = "quick_status",
    widget = Widget,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
