--!strict
-- Zenith Desktop Shell — Master Canvas Surface Module
-- Returns environmental desktop widgets directly for 380x340 canvas viewport

local DesktopWidgets = Zenith.import("canvas/desktop_widgets")

local function DesktopCanvas()
    return DesktopWidgets()
end

local mod = {
    id = "canvas",
    widget = DesktopCanvas,
}

setmetatable(mod, {
    __call = function(_, props)
        return DesktopCanvas(props)
    end,
})

return mod
