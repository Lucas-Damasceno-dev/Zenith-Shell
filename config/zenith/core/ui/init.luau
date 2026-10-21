--!strict
-- Zenith Desktop Shell — Core UI Kit & Primitive Components
-- Barrel export uniting primitives, design tokens, typography, and widget catalog

local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")
local Button = Zenith.import("core/ui/button")
local Card = Zenith.import("core/ui/card")
local Slider = Zenith.import("core/ui/slider")
local Switch = Zenith.import("core/ui/switch")
local VirtualList = Zenith.import("core/ui/virtual_list")

local WidgetsCatalog: any = nil
local function get_catalog()
    if not WidgetsCatalog then
        local ok, cat = pcall(function() return Zenith.import("widgets/init") end)
        if ok and cat then
            WidgetsCatalog = cat
        else
            WidgetsCatalog = {}
        end
    end
    return WidgetsCatalog
end

local function call_widget(name: string, props: any?)
    local cat = get_catalog()
    local w = cat[name]
    if w then
        if type(w) == "function" then
            return w(props)
        elseif type(w) == "table" then
            if w.widget and type(w.widget) == "function" then
                return w.widget(props)
            else
                local mt = getmetatable(w)
                if mt and mt.__call then
                    return w(props)
                end
            end
        end
    end
    return Zenith.Box({ width = 0, height = 0 })
end

local Widgets = {
    Audio = function(props: any?) return call_widget("audio", props) end,
    Battery = function(props: any?) return call_widget("battery", props) end,
    Cava = function(props: any?) return call_widget("cava", props) end,
    Clipboard = function(props: any?) return call_widget("clipboard", props) end,
    Clock = function(props: any?) return call_widget("clock", props) end,
    FocusedApp = function(props: any?) return call_widget("focused_app", props) end,
    Hardware = function(props: any?) return call_widget("hardware", props) end,
    KdeConnect = function(props: any?) return call_widget("kde_connect", props) end,
    Keyboard = function(props: any?) return call_widget("keyboard", props) end,
    Launcher = function(props: any?) return call_widget("launcher", props) end,
    Media = function(props: any?) return call_widget("media", props) end,
    Network = function(props: any?) return call_widget("network", props) end,
    Notifications = function(props: any?) return call_widget("notifications", props) end,
    Overview = function(props: any?) return call_widget("overview", props) end,
    Pill = function(props: any?) return call_widget("pill", props) end,
    Pomodoro = function(props: any?) return call_widget("pomodoro", props) end,
    Privacy = function(props: any?) return call_widget("privacy", props) end,
    QuickStatus = function(props: any?) return call_widget("quick_status", props) end,
    Session = function(props: any?) return call_widget("session", props) end,
    SettingsHub = function(props: any?) return call_widget("settings_hub", props) end,
    Tray = function(props: any?) return call_widget("tray", props) end,
    Tweaks = function(props: any?) return call_widget("tweaks", props) end,
    USB = function(props: any?) return call_widget("usb", props) end,
    UtilityHub = function(props: any?) return call_widget("utility_hub", props) end,
    Weather = function(props: any?) return call_widget("weather", props) end,
    Workspaces = function(props: any?) return call_widget("workspaces", props) end,
}

local UIKit = {
    Theme = Theme,
    Icons = Icons,
    Button = Button,
    Card = Card,
    Slider = Slider,
    Switch = Switch,
    VirtualList = VirtualList,
    Widgets = Widgets,

    Tokens = {
        colors = Theme.tokens().colors,
        typography = Icons.typography,
        shapes = {
            radius_sm = 8,
            radius_md = 14,
            radius_lg = 20,
            radius_full = 9999,
        },
    },

    Signals = {
        Time = (Zenith.Signals and Zenith.Signals.Time) or (Zenith.Signals and Zenith.Signals.time),
        Date = (Zenith.Signals and Zenith.Signals.Date) or (Zenith.Signals and Zenith.Signals.date),
        Cpu = (Zenith.Signals and Zenith.Signals.Cpu) or (Zenith.Signals and Zenith.Signals.cpu),
        Memory = (Zenith.Signals and Zenith.Signals.Memory) or (Zenith.Signals and Zenith.Signals.memory),
        ActiveWindow = (Zenith.Signals and Zenith.Signals.ActiveWindow) or (Zenith.Signals and Zenith.Signals.active_window),
        Brightness = (Zenith.Signals and Zenith.Signals.Brightness) or (Zenith.Signals and Zenith.Signals.brightness),
        Idle = (Zenith.Signals and Zenith.Signals.Idle) or (Zenith.Signals and Zenith.Signals.idle),
        IsIdle = (Zenith.Signals and Zenith.Signals.IsIdle) or (Zenith.Signals and Zenith.Signals.is_idle),
        create = function<T>(initial: T)
            if Zenith.Signal then
                return Zenith.Signal(initial)
            elseif Zenith.signal then
                return Zenith.signal(initial)
            end
            error("Reactive runtime unavailable")
        end,
        effect = function(cb: () -> ())
            if Zenith.effect then Zenith.effect(cb)
            elseif Zenith.Effect then Zenith.Effect(cb) end
        end,
    },
}

return UIKit
