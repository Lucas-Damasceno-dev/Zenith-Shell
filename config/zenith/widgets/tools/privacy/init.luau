--!strict
local Widget = Zenith.import("widgets/tools/privacy/widget")

local mod = {
    id = "privacy",
    widget = Widget,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
