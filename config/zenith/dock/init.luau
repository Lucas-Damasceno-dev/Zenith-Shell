--!strict
-- Zenith Desktop Shell — Dock Surface Module

local DockBar = Zenith.import("dock/dock_bar")

local mod = {
    id = "dock",
    widget = DockBar,
}

setmetatable(mod, {
    __call = function(_, props)
        return DockBar(props)
    end,
})

return mod
