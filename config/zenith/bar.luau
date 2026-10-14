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
-- 1. LEFT CLUSTER: Launcher -> Workspaces -> Overview -> FocusedApp
-- ═════════════════════════════════════════════════════════════════
local left_cluster_children = {
    Launcher({ text = "" }),
    Workspaces(),
    Overview(),
    FocusedApp({ reactive = true }),
}

-- ═════════════════════════════════════════════════════════════════
-- 2. CENTER CLUSTER: Media -> Notifications -> Clock -> Pomodoro -> Weather -> UtilityHub
-- ═════════════════════════════════════════════════════════════════
local center_cluster_children = {
    Media(),
    Notifications(),
    Clock({ reactive = true }),
}

if not is_compact then
    table.insert(center_cluster_children, Pomodoro())
end

if not is_tight then
    table.insert(center_cluster_children, Weather())
    table.insert(center_cluster_children, UtilityHub())
    table.insert(center_cluster_children, SettingsHub())
end

-- ═════════════════════════════════════════════════════════════════
-- 3. RIGHT CLUSTER: Privacy -> SystemCluster -> StatusCluster -> ActionCluster
-- ═════════════════════════════════════════════════════════════════
local right_cluster_children = {}

-- Privacy Indicator (Mic, Camera, REC)
table.insert(right_cluster_children, Privacy())

-- System Cluster (KDE Connect, Tray, USB, Clipboard, Hardware, CAVA)
local system_cluster_children = {}
if not is_compact then
    table.insert(system_cluster_children, KdeConnect())
end

local tray_widget = Tray()
if tray_widget then
    table.insert(system_cluster_children, tray_widget)
end

if not is_compact then
    table.insert(system_cluster_children, USBStatus())
end

if #system_cluster_children > 0 then
    table.insert(system_cluster_children, Separator())
end

table.insert(system_cluster_children, Clipboard())
table.insert(system_cluster_children, Hardware({ reactive = true }))

if not is_tight then
    local cava_widget = Cava({ bar_count = 6 })
    if cava_widget then
        table.insert(system_cluster_children, cava_widget)
    end
end

table.insert(right_cluster_children, Zenith.Box({
    direction = "row",
    align_items = "center",
    gap = 4,
    children = system_cluster_children,
}))

-- Status Cluster (Network, Audio, Battery, Keyboard Layout)
local status_cluster_children = {
    Network(),
    Audio(),
    Battery(),
}

if not is_tight then
    table.insert(status_cluster_children, KeyboardLayout())
end

table.insert(right_cluster_children, Zenith.Box({
    direction = "row",
    align_items = "center",
    gap = 4,
    children = status_cluster_children,
}))

-- Action Cluster (Tweaks & Session)
table.insert(right_cluster_children, Zenith.Box({
    direction = "row",
    align_items = "center",
    gap = 4,
    children = {
        Tweaks(),
        Session(),
    },
}))

-- ═════════════════════════════════════════════════════════════════
-- ROOT BAR CONTAINER (Floating Glassmorphic Pill)
-- ═════════════════════════════════════════════════════════════════
return Zenith.Box({
    direction = "row",
    height = 42,
    padding = { x = if is_compact then 10 else 16, y = 3 },
    background = Zenith.rgba(0, 0, 0, 0), -- Transparent wrapper for floating aesthetic
    children = {
        -- Floating Glassmorphic Pill Container
        Zenith.Box({
            direction = "row",
            align_items = "center",
            flex_grow = 1,
            height = 36,
            padding = { x = if is_compact then 6 else 8, y = 3 },
            gap = if is_compact then 4 else 6,
            border_radius = 18,
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
                -- 1. LEFT CLUSTER: Launcher + Workspaces + Overview + FocusedApp
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = if is_compact then 4 else 5,
                    children = left_cluster_children,
                }),

                -- Left Spacer
                Zenith.Box({ flex_grow = 1 }),

                -- 2. CENTER CLUSTER: Media + Notifications + Clock + Pomodoro + Weather + UtilityHub
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = if is_compact then 4 else 5,
                    children = center_cluster_children,
                }),

                -- Right Spacer
                Zenith.Box({ flex_grow = 1 }),

                -- 3. RIGHT CLUSTER: Privacy + System + Status + Action
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = if is_compact then 3 else 4,
                    children = right_cluster_children,
                }),
            }
        })
    }
})
