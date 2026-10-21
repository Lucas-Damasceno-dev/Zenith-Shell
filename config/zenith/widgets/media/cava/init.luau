--!strict
local Widget = Zenith.import("widgets/media/cava/widget")

local mod = {
    id = "cava",
    widget = Widget,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
