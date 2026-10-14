--!strict
-- Zenith Desktop Shell - Standard UI Kit & Design System (Engine Base v3)
-- Comprehensive industrial component library integrated with Material 3, Matugen & Stylix

local Theme = Zenith.import("theme")
local Button = Zenith.import("button")
local Slider = Zenith.import("slider")
local Switch = Zenith.import("switch")
local Card = Zenith.import("card")
local VirtualList = Zenith.import("virtual_list")
local SettingsStore = Zenith.import("settings_store")

-- ── 1. Granular Reactive Signals Subsystem ──
local Signals = {
    -- Signal constructor: returns (signal, setter) or Signal table
    create = function<T>(initial: T)
        if Zenith.signal then
            return Zenith.signal(initial)
        elseif Zenith.Signal then
            local s = Zenith.Signal(initial)
            return s, function(val: T) s:set(val) end
        end
        error("Zenith reactive runtime does not expose signal primitive")
    end,
    signal = function<T>(initial: T)
        if Zenith.Signal then
            return Zenith.Signal(initial)
        elseif Zenith.signal then
            local s, _ = Zenith.signal(initial)
            return s
        end
        error("Zenith reactive runtime does not expose signal primitive")
    end,
    effect = function(callback: () -> ())
        if Zenith.effect then
            Zenith.effect(callback)
        elseif Zenith.Effect then
            Zenith.Effect(callback)
        end
    end,
    -- Native fine-grained system signals from Zenith Engine (C/Rust bound)
    Time = (Zenith.Signals and Zenith.Signals.Time) or (Zenith.Signals and Zenith.Signals.time),
    Date = (Zenith.Signals and Zenith.Signals.Date) or (Zenith.Signals and Zenith.Signals.date),
    Cpu = (Zenith.Signals and Zenith.Signals.Cpu) or (Zenith.Signals and Zenith.Signals.cpu),
    Memory = (Zenith.Signals and Zenith.Signals.Memory) or (Zenith.Signals and Zenith.Signals.memory),
    ActiveWindow = (Zenith.Signals and Zenith.Signals.ActiveWindow) or (Zenith.Signals and Zenith.Signals.active_window),
    Brightness = (Zenith.Signals and Zenith.Signals.Brightness) or (Zenith.Signals and Zenith.Signals.brightness),
    Idle = (Zenith.Signals and Zenith.Signals.Idle) or (Zenith.Signals and Zenith.Signals.idle),
    IsIdle = (Zenith.Signals and Zenith.Signals.IsIdle) or (Zenith.Signals and Zenith.Signals.is_idle),
}

-- ── 2. Full 1:1 Modular Widgets Registry ──
local widget_cache: { [string]: any } = {}
local function get_widget(name: string)
    if not widget_cache[name] then
        widget_cache[name] = Zenith.import("widgets/" .. name)
    end
    return widget_cache[name]
end

local Widgets = {
    Audio = function(props: any?) return get_widget("audio")(props) end,
    Battery = function(props: any?) return get_widget("battery")(props) end,
    Cava = function(props: any?) return get_widget("cava")(props) end,
    Clipboard = function(props: any?) return get_widget("clipboard")(props) end,
    Clock = function(props: any?) return get_widget("clock")(props) end,
    FocusedApp = function(props: any?) return get_widget("focused_app")(props) end,
    Hardware = function(props: any?) return get_widget("hardware")(props) end,
    KdeConnect = function(props: any?) return get_widget("kde_connect")(props) end,
    Keyboard = function(props: any?) return get_widget("keyboard")(props) end,
    Launcher = function(props: any?) return get_widget("launcher")(props) end,
    Media = function(props: any?) return get_widget("media")(props) end,
    Network = function(props: any?) return get_widget("network")(props) end,
    Notifications = function(props: any?) return get_widget("notifications")(props) end,
    Overview = function(props: any?) return get_widget("overview")(props) end,
    Pill = function(props: any?) return get_widget("pill")(props) end,
    Pomodoro = function(props: any?) return get_widget("pomodoro")(props) end,
    Privacy = function(props: any?) return get_widget("privacy")(props) end,
    QuickStatus = function(props: any?) return get_widget("quick_status")(props) end,
    Session = function(props: any?) return get_widget("session")(props) end,
    SettingsHub = function(props: any?) return get_widget("settings_hub")(props) end,
    Tray = function(props: any?) return get_widget("tray")(props) end,
    Tweaks = function(props: any?) return get_widget("tweaks")(props) end,
    Usb = function(props: any?) return get_widget("usb")(props) end,
    UtilityHub = function(props: any?) return get_widget("utility_hub")(props) end,
    Weather = function(props: any?) return get_widget("weather")(props) end,
    Workspaces = function(props: any?) return get_widget("workspaces")(props) end,
}

-- ── 3. Unified UIKit Export ──
local UIKit = {
    -- Design tokens & theme synchronization
    Theme = Theme,
    Tokens = Theme.tokens(),
    tokens = Theme.tokens,
    alpha = Theme.alpha,
    glass = Theme.glass,
    color = Theme.color,
    elevation = Theme.elevation,

    -- Core UI Primitives
    Button = Button,
    Slider = Slider,
    Switch = Switch,
    Card = Card,
    Surface = Card, -- Semantic alias
    VirtualList = VirtualList,
    SettingsStore = SettingsStore,

    -- Reactive Signals API
    Signals = Signals,

    -- Complete 1:1 Modular Widgets
    Widgets = Widgets,
    Audio = Widgets.Audio,
    Battery = Widgets.Battery,
    Cava = Widgets.Cava,
    Clipboard = Widgets.Clipboard,
    Clock = Widgets.Clock,
    FocusedApp = Widgets.FocusedApp,
    Hardware = Widgets.Hardware,
    KdeConnect = Widgets.KdeConnect,
    Keyboard = Widgets.Keyboard,
    Launcher = Widgets.Launcher,
    Media = Widgets.Media,
    Network = Widgets.Network,
    Notifications = Widgets.Notifications,
    Overview = Widgets.Overview,
    Pill = Widgets.Pill,
    Pomodoro = Widgets.Pomodoro,
    Privacy = Widgets.Privacy,
    QuickStatus = Widgets.QuickStatus,
    Session = Widgets.Session,
    SettingsHub = Widgets.SettingsHub,
    Tray = Widgets.Tray,
    Tweaks = Widgets.Tweaks,
    Usb = Widgets.Usb,
    UtilityHub = Widgets.UtilityHub,
    Weather = Widgets.Weather,
    Workspaces = Widgets.Workspaces,
}

return UIKit
