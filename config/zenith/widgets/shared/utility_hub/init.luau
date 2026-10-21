--!strict
local Widget = Zenith.import("widgets/shared/utility_hub/widget")

local mod = {
    id = "utility_hub",
    widget = Widget,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
