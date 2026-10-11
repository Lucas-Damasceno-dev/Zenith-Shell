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

local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366, height = 768 }
local screen_w = screen.width or 1366

local is_compact = screen_w < 1440
local is_narrow = screen_w < 1200
local max_title_len = if is_narrow then 0 elseif is_compact then 14 elseif screen_w < 1920 then 22 else 36

local active_win = Zenith.Services.ActiveWindow()
local win_text = "󰘔 Zenith Shell"
if active_win and active_win.title and #active_win.title > 0 then
    local prefix = if active_win.class and #active_win.class > 0 then
        active_win.class .. " : "
    else
        ""
    local full_title = prefix .. active_win.title
    if #full_title > max_title_len then
        win_text = " " .. string.sub(full_title, 1, math.max(max_title_len - 2, 4)) .. ".."
    else
        win_text = " " .. full_title
    end
elseif active_win and active_win.class and #active_win.class > 0 then
    win_text = " " .. (if #active_win.class > 12 then active_win.class:sub(1, 10) .. ".." else active_win.class)
end

local left_cluster_children = {
    Launcher({ text = "󱄅" }),
    Workspaces(),
}

if not is_narrow then
    table.insert(left_cluster_children, Zenith.Box({
        padding = { x = if is_compact then 7 else 8, y = 3 },
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
    }))
end

local right_cluster_children = {
    Zenith.Box({
        padding = { x = if is_compact then 5 else 6, y = 3 },
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
}

if Zenith.Services.IsRecording() then
    table.insert(right_cluster_children, Zenith.Box({
        padding = { x = if is_compact then 6 else 8, y = 3 },
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
    }))
end

table.insert(right_cluster_children, Hardware())
local tray_widget = Tray()
if tray_widget then
    table.insert(right_cluster_children, tray_widget)
end
table.insert(right_cluster_children, QuickStatus())

return Zenith.Box({
    direction = "row",
    height = 44,
    padding = { x = if is_compact then 6 else 12, y = 4 },
    background = Zenith.rgba(0, 0, 0, 0), -- Transparent wrapper for floating aesthetic
    children = {
        -- Floating Glassmorphic Pill Container
        Zenith.Box({
            direction = "row",
            flex_grow = 1,
            height = 36,
            padding = { x = if is_compact then 6 else 8, y = 3 },
            gap = if is_compact then 4 else 6,
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
                    gap = if is_compact then 4 else 5,
                    children = left_cluster_children,
                }),

                -- Spacer
                Zenith.Box({ flex_grow = 1 }),

                -- 2. CENTER CLUSTER: MPRIS2 Media + Clock & Date
                Zenith.Box({
                    direction = "row",
                    gap = if is_compact then 4 else 5,
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
                    gap = if is_compact then 3 else 4,
                    children = right_cluster_children,
                }),
            }
        })
    }
})

