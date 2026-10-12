--!strict
-- Zenith UI Kit - Launcher Pill Component (NixOS / End-4 style)

local Pill = Zenith.import("widgets/pill")

local function Launcher(props: { text: string?, on_click: string? }?)
    local text = props and props.text or ""
    local on_click = props and props.on_click or "popup:toggle:Launcher"

    return Pill({
        icon = text,
        icon_size = 13,
        variant = "accent_chip",
        height = 26,
        border_radius = 13,
        padding = { x = 9, y = 2 },
        on_click = on_click,
    })
end

return Launcher
