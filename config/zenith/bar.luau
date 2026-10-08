--!strict
-- Zenith-Shell (Engine v2) - Declarative Top Bar Configuration
-- Composed cleanly with modular Zenith UI Kit components

local theme = Zenith.Theme()

-- Import reusable UI kit components
local Launcher = Zenith.import("widgets/launcher")
local Workspaces = Zenith.import("widgets/workspaces")
local Clock = Zenith.import("widgets/clock")
local Hardware = Zenith.import("widgets/hardware")
local QuickStatus = Zenith.import("widgets/quick_status")

return Zenith.Box({
    direction = "row",
    height = 38,
    padding = { x = 14, y = 4 },
    gap = 8,
    background = Zenith.hex(theme.background),
    border_color = Zenith.hex("#252c38"),
    border_width = 1,
    children = {
        -- 1. LEFT CLUSTER: Launcher + Workspaces + Focused App
        Launcher({ text = "󱄅 NixOS" }),
        Workspaces({ active = 1, count = 4 }),

        Zenith.Box({
            padding = { x = 10, y = 4 },
            border_radius = 8,
            background = Zenith.hex(theme.surface),
            border_color = Zenith.hex("#2d3748"),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = " kitty : dev@nixos",
                    font_size = 11,
                    color = Zenith.hex(theme.on_surface),
                })
            }
        }),

        -- Flexible spacer
        Zenith.Box({ flex_grow = 1 }),

        -- 2. CENTER CLUSTER: Media + Clock & Date
        Zenith.Box({
            direction = "row",
            gap = 6,
            children = {
                Zenith.Box({
                    padding = { x = 10, y = 4 },
                    border_radius = 8,
                    background = Zenith.hex(theme.surface),
                    border_color = Zenith.hex("#2d3748"),
                    border_width = 1,
                    children = {
                        Zenith.Text({
                            text = "󰎆 Spotify: Playing...",
                            font_size = 11,
                            color = Zenith.hex(theme.primary),
                        })
                    }
                }),
                Clock(),
            }
        }),

        -- Flexible spacer
        Zenith.Box({ flex_grow = 1 }),

        -- 3. RIGHT CLUSTER: Hardware (CPU/RAM) + Quick Status (Net/Audio/Bat/Power)
        Hardware(),
        QuickStatus(),
    }
})
