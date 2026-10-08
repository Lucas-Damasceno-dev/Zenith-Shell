--!strict
-- Zenith-Shell (Engine v2) - Declarative Top Bar Configuration
-- Floating glassmorphic desktop bar inspired by Quickshell / Caelestia / end4 design

local theme = Zenith.Theme()

-- Import reusable UI kit components
local Launcher = Zenith.import("widgets/launcher")
local Workspaces = Zenith.import("widgets/workspaces")
local Clock = Zenith.import("widgets/clock")
local Hardware = Zenith.import("widgets/hardware")
local QuickStatus = Zenith.import("widgets/quick_status")
local Media = Zenith.import("widgets/media")
local Tray = Zenith.import("widgets/tray")

local active_win = Zenith.Services.ActiveWindow()
local win_text = "󰘔 Zenith Shell"
if active_win and active_win.title and #active_win.title > 0 then
    local prefix = if active_win.class and #active_win.class > 0 then
        active_win.class .. " : "
    else
        ""
    local full_title = prefix .. active_win.title
    if #full_title > 36 then
        win_text = " " .. string.sub(full_title, 1, 33) .. "..."
    else
        win_text = " " .. full_title
    end
elseif active_win and active_win.class and #active_win.class > 0 then
    win_text = " " .. active_win.class
end

return Zenith.Box({
    direction = "row",
    height = 44,
    padding = { x = 12, y = 4 },
    background = Zenith.rgba(0, 0, 0, 0), -- Transparent wrapper for floating aesthetic
    children = {
        -- Floating Glassmorphic Pill Container
        Zenith.Box({
            direction = "row",
            flex_grow = 1,
            height = 36,
            padding = { x = 10, y = 3 },
            gap = 8,
            border_radius = 16,
            background = Zenith.rgba(18, 20, 26, 215), -- Frosted glass with compositor Kawase blur
            border_color = Zenith.rgba(255, 255, 255, 28),
            border_width = 1,
            shadow = {
                color = Zenith.rgba(0, 0, 0, 160),
                blur = 16,
                offset_x = 0,
                offset_y = 4,
            },
            children = {
                -- 1. LEFT CLUSTER: Launcher + Dynamic Workspaces + Focused App Chip
                Zenith.Box({
                    direction = "row",
                    gap = 6,
                    children = {
                        Launcher({ text = "󱄅 NixOS" }),
                        Workspaces(),
                        Zenith.Box({
                            padding = { x = 10, y = 3 },
                            border_radius = 12,
                            background = Zenith.rgba(255, 255, 255, 10),
                            border_color = Zenith.rgba(255, 255, 255, 18),
                            border_width = 1,
                            children = {
                                Zenith.Text({
                                    text = win_text,
                                    font_size = 11,
                                    color = Zenith.hex(theme.on_surface),
                                }),
                            }
                        }),
                    }
                }),

                -- Spacer
                Zenith.Box({ flex_grow = 1 }),

                -- 2. CENTER CLUSTER: MPRIS2 Media + Clock & Date
                Zenith.Box({
                    direction = "row",
                    gap = 6,
                    children = {
                        Media(),
                        Clock(),
                    }
                }),

                -- Spacer
                Zenith.Box({ flex_grow = 1 }),

                -- 3. RIGHT CLUSTER: Snipping + Recording + Hardware Monitors (CPU/RAM) + Tray + Quick Status
                Zenith.Box({
                    direction = "row",
                    gap = 6,
                    children = {
                        Zenith.Box({
                            padding = { x = 8, y = 3 },
                            border_radius = 12,
                            background = Zenith.rgba(255, 255, 255, 10),
                            border_color = Zenith.rgba(255, 255, 255, 18),
                            border_width = 1,
                            on_click = "screenshot:area",
                            children = {
                                Zenith.Text({
                                    text = "󰄀",
                                    font_size = 11,
                                    color = Zenith.hex(theme.on_surface),
                                }),
                            }
                        }),
                        if Zenith.Services.IsRecording() then
                            Zenith.Box({
                                padding = { x = 8, y = 3 },
                                border_radius = 12,
                                background = Zenith.rgba(224, 108, 117, 60),
                                border_color = Zenith.hex("#e06c75"),
                                border_width = 1,
                                on_click = "record:toggle",
                                children = {
                                    Zenith.Text({
                                        text = "● REC",
                                        font_size = 11,
                                        color = Zenith.hex("#ffffff"),
                                    }),
                                }
                            })
                        else
                            nil :: any,
                        Hardware(),
                        Tray(),
                        QuickStatus(),
                    }
                }),
            }
        })
    }
})
