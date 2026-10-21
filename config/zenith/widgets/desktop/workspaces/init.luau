--!strict
local Widget = Zenith.import("widgets/desktop/workspaces/widget")

local mod = {
    id = "workspaces",
    widget = Widget,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
