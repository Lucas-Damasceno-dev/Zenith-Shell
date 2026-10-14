--!strict
-- Zenith Design System - Settings Store & State Controller
-- Bridges local state, atomic persistence, and Quickshell parity configurations

local SettingsStore = {}

local DEFAULTS: { [string]: any } = {
    -- Quick & Essentials
    wallpaperPath = "",
    layoutPreset = "Default",
    accentColor = "#fcbc00",
    colorScheme = "Tonal Spot",
    darkMode = true,
    barAutoHide = true,
    barCompactMode = false,
    barZenMode = false,
    reducedMotion = false,
    privacyMode = false,
    focusMode = false,
    lowPowerMode = false,
    enableHotCorners = true,

    -- Geometry & Appearance
    barHeight = 42,
    barMarginTop = 4,
    barRadius = 18,
    barPadding = 8,
    barGlassOpacity = 85,
    glassEffect = true,
    fontUI = "Inter",
    fontMono = "JetBrainsMono Nerd Font",

    -- Wallpaper Engine
    wallpaperBackend = "swww",
    wallpaperSlideshow = false,
    pauseAnimationOnBattery = true,
    hideWhenFullscreen = true,

    -- Dock
    dockEnabled = true,
    dockAutoHide = true,
    dockBlurGlass = true,
    dockHeight = 52,
    dockShowMpris = true,
    dockShowTrash = false,

    -- Panels & Popups
    popupBackdropBlur = true,
    popupAnimationsEnabled = true,
    overviewDim = 40,

    -- Modules Visibility
    showLauncherButton = true,
    showWorkspaceSwitcher = true,
    showOverviewButton = true,
    showFocusedApp = true,
    showCenterClock = true,
    showCenterMedia = true,
    showCenterNotifications = true,
    showCenterWeather = true,
    showCenterUtilityHub = true,
    showSettingsHub = true,
    showPomodoro = false,
    showPrivacyIndicator = true,
    showSystemTray = true,
    showHardwareMonitors = true,
    showClipboardTile = true,
    showNetworkStatus = true,
    showAudioStatus = true,
    showBatteryStatus = true,
    showKeyboardLayout = true,
    showSessionButton = true,
    showCavaVisualizer = true,

    -- Audio & System
    audioVolumeStep = 5,
    audioProtection = true,
    batteryChargeLimit = 80,
    batteryLimitActive = true,
    batteryCaffeineActive = false,
    batteryPowerProfile = "balanced",
    batteryLowThreshold = 20,
    batteryCriticalThreshold = 5,
    batteryNotifyFull = true,
    autoSuspend = false,
    suspendTimeoutMin = 15,
    brightness = 100,
    nightLightEnabled = false,
    nightLightTemp = 4000,
    grayscaleIntensity = 0,
    hyprlockBlur = 8,
    hyprlockGrace = 5,
    hyprlockShowClock = true,
    timeFormat = "24h",
    secondPrecision = false,
    pomodoroFocus = 25,
    pomodoroBreak = 5,
    pomodoroActive = false,
    dndEnabled = false,
    wifiEnabled = true,
    bluetoothEnabled = true,
    fontSizeScale = 100,
    mediaShowLyrics = false,
    osd_mode = "volume",

    -- Compositor & Hyprland
    hyprLayout = "dwindle",
    gapsIn = 5,
    gapsOut = 10,
    borderSize = 2,
    cursorSpeed = 1.0,
    touchpadNaturalScroll = true,
    touchpadTapToClick = true,

    -- Tools & Capture
    toolsFps = 60,
    toolsCodec = "libx264",
    toolsAudioSource = "both",
    toolsContainer = "mkv",
    toolsDiscordCompress = false,
    toolsFormat = "png",
    toolsSnipMode = "region",
    toolsDelay = 0,
    toolsOcrLang = "por",
    toolsLensProvider = "google",
    toolsCrosshair = false,
    toolsCrosshairSize = 16,

    -- Services & Applications
    weatherProvider = "open-meteo",
    weatherUnits = "metric",
    weatherRefreshMin = 30,
    mediaFilterDuplicates = true,
    appTerminal = "foot",
    appBrowser = "firefox",
    appFileManager = "thunar",
    appEditor = "codium",

    -- AI & Voice
    aiProvider = "gemini",
    aiModel = "gemini-2.5-flash",
    aiTemperature = 0.7,
    aiVoiceInput = false,
    aiVoiceProvider = "whisper",
    aiVoiceLanguage = "auto",

    -- Autostart Daemons
    autostartHypridle = true,
    autostartSwww = true,
    autostartPlayerctl = true,
    autostartPolkit = true,
    autostartCliphist = true,

    -- Advanced & Engine
    advancedLowPower = 20,
    advancedBlur = true,
    advancedLogLevel = "info",
    advancedMemWarning = true,

    -- Active Navigation Page
    settings_active_page = 0,
    settings_search = "",
}

function SettingsStore.get(key: string): any
    local fallback = DEFAULTS[key]
    if Zenith.Storage and Zenith.Storage.get then
        local val = Zenith.Storage.get(key, nil)
        if val ~= nil then
            return val
        end
        -- Dotted key fallback if flat key not yet populated
        local dotted_map = {
            accentColor = "quick.accentColor",
            darkMode = "quick.darkMode",
            layoutPreset = "quick.layoutPreset",
            colorScheme = "quick.colorScheme",
            barHeight = "bar.height",
            barAutoHide = "bar.autoHide",
            barRadius = "bar.customRounding",
            dockHeight = "dock.height",
            dockAutoHide = "dock.autoHide",
            dockEnabled = "dock.enable",
            springStiffness = "appearance.springStiffness",
            springDamping = "appearance.springDamping",
        }
        local mapped_k = dotted_map[key]
        if mapped_k then
            val = Zenith.Storage.get(mapped_k, nil)
            if val ~= nil then
                return val
            end
        end
    end
    return fallback
end

function SettingsStore.set(key: string, val: any)
    if Zenith.Storage and Zenith.Storage.set then
        Zenith.Storage.set(key, val)
    end
end

function SettingsStore.has(key: string): boolean
    if Zenith.Storage and Zenith.Storage.has then
        return Zenith.Storage.has(key)
    end
    return DEFAULTS[key] ~= nil
end

function SettingsStore.remove(key: string)
    if Zenith.Storage and Zenith.Storage.remove then
        Zenith.Storage.remove(key)
    end
end

function SettingsStore.save(key: string, val: any)
    SettingsStore.set(key, val)
    SettingsStore.sync()
end

function SettingsStore.getDefault(key: string): any
    return DEFAULTS[key]
end

local _bindings: { [string]: { (any) -> () } } = {}

function SettingsStore.bind(key: string, callback: (any) -> ())
    if not _bindings[key] then
        _bindings[key] = {}
    end
    table.insert(_bindings[key], callback)
end

function SettingsStore.sync()
    if Zenith.Storage and Zenith.Storage.sync_to_config then
        Zenith.Storage.sync_to_config()
    end
end

function SettingsStore.reload()
    if Zenith.Storage and Zenith.Storage.reload_from_config then
        Zenith.Storage.reload_from_config()
    end
end

function SettingsStore.toggle(key: string): boolean
    local cur = SettingsStore.get(key)
    local next_val = not cur
    SettingsStore.set(key, next_val)
    if _bindings[key] then
        for _, cb in ipairs(_bindings[key]) do
            cb(next_val)
        end
    end
    return next_val
end

function SettingsStore.getActivePage(): number
    local p = SettingsStore.get("settings_active_page")
    if typeof(p) == "number" then
        return p
    end
    return 0
end

function SettingsStore.setActivePage(page: number)
    SettingsStore.set("settings_active_page", page)
end

function SettingsStore.getSearch(): string
    local s = SettingsStore.get("settings_search")
    if typeof(s) == "string" then
        return s
    end
    return ""
end

function SettingsStore.setSearch(query: string)
    SettingsStore.set("settings_search", query)
end

function SettingsStore.resetDefaults()
    for k, v in pairs(DEFAULTS) do
        SettingsStore.set(k, v)
    end
end

function SettingsStore.getAll(): { [string]: any }
    local result: { [string]: any } = {}
    for k, v in pairs(DEFAULTS) do
        result[k] = SettingsStore.get(k)
    end
    return result
end

return SettingsStore
