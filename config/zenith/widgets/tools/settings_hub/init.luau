--!strict
local Widget = Zenith.import("widgets/tools/settings_hub/widget")

local mod = {
    id = "settings_hub",
    widget = Widget,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
