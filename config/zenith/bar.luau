--!strict
-- Zenith-Shell (Engine v2) - Declarative Top Bar Configuration
-- 1:1 Parity with Quickshell Bar.qml & RightBarModules.qml Layout and Organization

local UIKit = Zenith.import("ui_kit")
local theme = UIKit.Theme.get()
local Widgets = UIKit.Widgets

-- ── 1. Left Section Modules ──
local Launcher = Widgets.Launcher
local Workspaces = Widgets.Workspaces
local Overview = Widgets.Overview
local FocusedApp = Widgets.FocusedApp

-- ── 2. Center Section Modules ──
local Media = Widgets.Media
local Notifications = Widgets.Notifications
local Clock = Widgets.Clock
local Pomodoro = Widgets.Pomodoro
local Weather = Widgets.Weather
local UtilityHub = Widgets.UtilityHub
local SettingsHub = Widgets.SettingsHub

-- ── 3. Right Section Modules ──
local Privacy = Widgets.Privacy
local KdeConnect = Widgets.KdeConnect
local Tray = Widgets.Tray
local USBStatus = Widgets.Usb
local Clipboard = Widgets.Clipboard
local Hardware = Widgets.Hardware
local QuickStatus = Widgets.QuickStatus
local Cava = Widgets.Cava
local Network = Widgets.Network
local Audio = Widgets.Audio
local Battery = Widgets.Battery
local KeyboardLayout = Widgets.Keyboard
local Tweaks = Widgets.Tweaks
local Session = Widgets.Session

local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366, height = 768 }
local screen_w = screen.width or 1366
local is_compact = screen_w < 1440
local is_tight = screen_w < 1280
local is_very_tight = screen_w < 1024

local function Separator()
    return Zenith.Box({
        width = 1,
        height = 14,
        background = Zenith.hex(theme.outline_variant or theme.outline, 45),
        margin = { x = 2, y = 0 },
        children = {},
    })
end

-- ═════════════════════════════════════════════════════════════════
-- 1. LEFT CLUSTER: Launcher -> Workspaces -> FocusedApp
-- ═════════════════════════════════════════════════════════════════
local left_cluster_children = {
    Launcher({ text = "" }),
    Workspaces(),
    FocusedApp({ reactive = true }),
}

-- ═════════════════════════════════════════════════════════════════
-- 2. CENTER CLUSTER: Media pill -> Clock & Calendar pill -> Weather pill
-- ═════════════════════════════════════════════════════════════════
local center_cluster_children = {
    Media(),
    Clock({ reactive = true }),
    Weather(),
}

-- ═════════════════════════════════════════════════════════════════
-- 3. RIGHT CLUSTER: Clipboard -> USB -> Hardware -> QuickStatus -> Tray -> Session
-- ═════════════════════════════════════════════════════════════════
local right_cluster_children = {}

-- Privacy Indicator (Screen Recording active indicator)
local is_recording = Zenith.Services.IsRecording and Zenith.Services.IsRecording() or false
if is_recording then
    table.insert(right_cluster_children, Privacy())
end

-- 1. Clipboard
table.insert(right_cluster_children, Clipboard())

-- 2. USB
table.insert(right_cluster_children, USBStatus())

-- 3. Hardware monitor
table.insert(right_cluster_children, Hardware({ reactive = true }))

-- 4. QuickStatus cluster
table.insert(right_cluster_children, QuickStatus({ micro_cluster = is_compact, show_actions = false }))

-- 5. System Tray (SNI)
local tray_widget = Tray()
if tray_widget then
    table.insert(right_cluster_children, Separator())
    table.insert(right_cluster_children, tray_widget)
end

-- 6. Session / Power button
table.insert(right_cluster_children, Session())

-- ═════════════════════════════════════════════════════════════════
-- ROOT BAR CONTAINER (Floating Glassmorphic Pill)
-- ═════════════════════════════════════════════════════════════════
return Zenith.Box({
    direction = "row",
    height = if is_compact then 42 else 48,
    padding = { x = if is_compact then 12 else 16, y = 3 },
    background = Zenith.rgba(0, 0, 0, 0), -- Transparent wrapper for floating aesthetic
    children = {
        -- Floating Glassmorphic Pill Container (Parity with Quickshell Bar.qml)
        Zenith.Box({
            direction = "row",
            align_items = "center",
            flex_grow = 1,
            height = if is_compact then 36 else 40,
            padding = { x = if is_compact then 8 else 12, y = 2 },
            gap = if is_compact then 4 else 6,
            border_radius = if is_compact then 18 else 20,
            background = Zenith.hex(theme.surface, 215), -- Matugen warm frosted glass with Kawase blur
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
            border_width = 1,
            shadow = {
                color = Zenith.rgba(0, 0, 0, 160),
                blur = 18,
                offset_x = 0,
                offset_y = 4,
            },
            children = {
                -- 1. LEFT CLUSTER: Launcher + Workspaces + FocusedApp
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = if is_compact then 6 else 8,
                    children = left_cluster_children,
                }),

                -- Left Spacer (Flexbox expansion to center module)
                Zenith.Box({ flex_grow = 1 }),

                -- 2. CENTER CLUSTER: Media + Clock & Calendar + Weather
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = if is_compact then 6 else 8,
                    children = center_cluster_children,
                }),

                -- Right Spacer (Flexbox expansion to right module)
                Zenith.Box({ flex_grow = 1 }),

                -- 3. RIGHT CLUSTER: Clipboard + USB + Hardware + QuickStatus + Tray + Session
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = if is_compact then 4 else 6,
                    children = right_cluster_children,
                }),
            }
        })
    }
})
