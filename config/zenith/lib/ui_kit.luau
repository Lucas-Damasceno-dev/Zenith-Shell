--!strict
-- Zenith Desktop Shell - Standard UI Kit & Design System
-- Comprehensive industrial component library integrated with Material 3 & Stylix

local Theme = Zenith.import("theme")
local Button = Zenith.import("button")
local Slider = Zenith.import("slider")
local Switch = Zenith.import("switch")
local Card = Zenith.import("card")
local VirtualList = Zenith.import("virtual_list")
local Pill = Zenith.import("widgets/pill")
local Cava = Zenith.import("widgets/cava")

local UIKit = {
    Theme = Theme,
    Button = Button,
    Slider = Slider,
    Switch = Switch,
    Card = Card,
    Surface = Card, -- Semantic alias
    VirtualList = VirtualList,
    Pill = Pill,
    Cava = Cava,
}

return UIKit
