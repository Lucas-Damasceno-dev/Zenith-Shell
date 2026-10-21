--!strict
local Widget = Zenith.import("widgets/shared/keyboard/widget")

local mod = {
    id = "keyboard",
    widget = Widget,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
