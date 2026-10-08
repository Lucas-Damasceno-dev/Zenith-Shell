--!strict
-- Zenith UI Kit - Launcher Pill Component (NixOS / End-4 style)

local function Launcher(props: { text: string?, on_click: string? }?)
    local theme = Zenith.Theme()
    local text = props and props.text or "󱄅 NixOS"
    local on_click = props and props.on_click or "popup:toggle:Launcher"

    return Zenith.Box({
        direction = "row",
        padding = { x = 11, y = 3 },
        gap = 6,
        border_radius = 12,
        background = Zenith.rgba(122, 162, 247, 35),
        border_color = Zenith.rgba(122, 162, 247, 90),
        border_width = 1,
        on_click = on_click,
        children = {
            Zenith.Text({
                text = text,
                font_size = 12,
                color = Zenith.hex(theme.primary),
            })
        }
    })
end

return Launcher
