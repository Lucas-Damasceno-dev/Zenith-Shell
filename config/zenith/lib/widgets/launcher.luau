--!strict
-- Zenith UI Kit - Launcher Pill Component

local function Launcher(props: { text: string?, on_click: string? }?)
    local theme = Zenith.Theme()
    local text = props and props.text or "󱄅 NixOS"
    local on_click = props and props.on_click or "cmd:notify-send 'Zenith Shell' 'Launcher opened' -i preferences-system"

    return Zenith.Box({
        padding = { x = 12, y = 4 },
        border_radius = 8,
        background = Zenith.hex(theme.primary),
        on_click = on_click,
        children = {
            Zenith.Text({
                text = text,
                font_size = 11,
                color = Zenith.hex(theme.on_primary),
            })
        }
    })
end

return Launcher
