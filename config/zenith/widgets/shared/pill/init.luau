--!strict
local Widget = Zenith.import("widgets/shared/pill/widget")

local mod = {
    id = "pill",
    widget = Widget,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
