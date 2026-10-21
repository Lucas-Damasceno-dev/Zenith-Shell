--!strict
local Widget = Zenith.import("widgets/shared/launcher/widget")

local mod = {
    id = "launcher",
    widget = Widget,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
