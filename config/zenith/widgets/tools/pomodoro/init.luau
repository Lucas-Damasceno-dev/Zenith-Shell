--!strict
local Widget = Zenith.import("widgets/tools/pomodoro/widget")
local Popup = Zenith.import("widgets/tools/pomodoro/popup")

local mod = {
    id = "pomodoro",
    widget = Widget,
    popup = Popup,
}

setmetatable(mod, {
    __call = function(_, props)
        return Widget(props)
    end,
})

return mod
