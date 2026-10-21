--!strict
local Widget = Zenith.import("widgets/tools/clipboard/widget")
local Popup = Zenith.import("widgets/tools/clipboard/popup")

local mod = {
    id = "clipboard",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
