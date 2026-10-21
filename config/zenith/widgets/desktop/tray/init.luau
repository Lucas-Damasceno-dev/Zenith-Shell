--!strict
local Widget = Zenith.import("widgets/desktop/tray/widget")

local mod = {
    id = "tray",
    widget = Widget,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
