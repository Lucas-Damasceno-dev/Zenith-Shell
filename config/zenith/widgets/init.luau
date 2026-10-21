--!strict
-- Zenith-Shell: Unified Widgets Barrel Export

local Audio = Zenith.import("widgets/system/audio/init")
local Battery = Zenith.import("widgets/system/battery/init")
local Bluetooth = Zenith.import("widgets/system/bluetooth/init")
local Hardware = Zenith.import("widgets/system/hardware/init")
local Network = Zenith.import("widgets/system/network/init")

local Workspaces = Zenith.import("widgets/desktop/workspaces/init")
local Clock = Zenith.import("widgets/desktop/clock/init")
local Tray = Zenith.import("widgets/desktop/tray/init")
local FocusedApp = Zenith.import("widgets/desktop/focused_app/init")
local Overview = Zenith.import("widgets/desktop/overview/init")

local Mpris = Zenith.import("widgets/media/mpris/init")
local Media = Zenith.import("widgets/media/media/init")
local Cava = Zenith.import("widgets/media/cava/init")

local Notifications = Zenith.import("widgets/tools/notifications/init")
local Clipboard = Zenith.import("widgets/tools/clipboard/init")
local Weather = Zenith.import("widgets/tools/weather/init")
local Pomodoro = Zenith.import("widgets/tools/pomodoro/init")
local Privacy = Zenith.import("widgets/tools/privacy/init")
local USB = Zenith.import("widgets/tools/usb/init")
local Session = Zenith.import("widgets/tools/session/init")
local SettingsHub = Zenith.import("widgets/tools/settings_hub/init")

local Pill = Zenith.import("widgets/shared/pill/init")
local QuickStatus = Zenith.import("widgets/shared/quick_status/init")
local Tweaks = Zenith.import("widgets/shared/tweaks/init")
local KdeConnect = Zenith.import("widgets/shared/kde_connect/init")
local Keyboard = Zenith.import("widgets/shared/keyboard/init")
local Launcher = Zenith.import("widgets/shared/launcher/init")
local UtilityHub = Zenith.import("widgets/shared/utility_hub/init")

local Widgets = {
    -- System
    Audio = Audio,
    audio = Audio,
    Battery = Battery,
    battery = Battery,
    Bluetooth = Bluetooth,
    bluetooth = Bluetooth,
    Hardware = Hardware,
    hardware = Hardware,
    Network = Network,
    network = Network,

    -- Desktop
    Workspaces = Workspaces,
    workspaces = Workspaces,
    Clock = Clock,
    clock = Clock,
    Tray = Tray,
    tray = Tray,
    FocusedApp = FocusedApp,
    focused_app = FocusedApp,
    Overview = Overview,
    overview = Overview,

    -- Media
    Mpris = Mpris,
    mpris = Mpris,
    Media = Media,
    media = Media,
    Cava = Cava,
    cava = Cava,

    -- Tools
    Notifications = Notifications,
    notifications = Notifications,
    Clipboard = Clipboard,
    clipboard = Clipboard,
    Weather = Weather,
    weather = Weather,
    Pomodoro = Pomodoro,
    pomodoro = Pomodoro,
    Privacy = Privacy,
    privacy = Privacy,
    USB = USB,
    usb = USB,
    Session = Session,
    session = Session,
    SettingsHub = SettingsHub,
    settings_hub = SettingsHub,

    -- Shared
    Pill = Pill,
    pill = Pill,
    QuickStatus = QuickStatus,
    quick_status = QuickStatus,
    Tweaks = Tweaks,
    tweaks = Tweaks,
    KdeConnect = KdeConnect,
    kde_connect = KdeConnect,
    Keyboard = Keyboard,
    keyboard = Keyboard,
    Launcher = Launcher,
    launcher = Launcher,
    UtilityHub = UtilityHub,
    utility_hub = UtilityHub,
}

return Widgets
