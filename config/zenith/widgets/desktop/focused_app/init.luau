--!strict
local Widget = Zenith.import("widgets/desktop/focused_app/widget")

local mod = {
    id = "focused_app",
    widget = Widget,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
