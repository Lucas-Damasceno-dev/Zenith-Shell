--!strict
-- Zenith-Shell (v2) Default Status Bar Configuration in Luau

return Zenith.Box({
    direction = "row",
    height = 38,
    padding = { x = 14, y = 4 },
    gap = 10,
    background = Zenith.hex("#11121bf2"),
    border_color = Zenith.hex("#7c4dff"),
    border_width = 1,
    children = {
        -- Logo / Workspaces pill
        Zenith.Box({
            padding = { x = 12, y = 4 },
            border_radius = 6,
            background = Zenith.hex("#7c4dff"),
            children = {
                Zenith.Text({
                    text = "ZENITH",
                    font_size = 12,
                    color = Zenith.hex("#FFFFFF"),
                })
            }
        }),

        -- Active Window Title / Status Pill
        Zenith.Box({
            padding = { x = 18, y = 4 },
            border_radius = 6,
            background = Zenith.hex("#1e202fcc"),
            border_color = Zenith.hex("#33364f"),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = "Engine v2 (Rust + Luau + Taffy + Wayland)",
                    font_size = 12,
                    color = Zenith.hex("#c5c9de"),
                })
            }
        }),

        -- Clock / Telemetry Pill
        Zenith.Box({
            padding = { x = 14, y = 4 },
            border_radius = 6,
            background = Zenith.hex("#181926"),
            border_color = Zenith.hex("#2c2e42"),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = "⚡ 144Hz | 100%",
                    font_size = 12,
                    color = Zenith.hex("#a6accd"),
                })
            }
        })
    }
})
