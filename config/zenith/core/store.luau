--!strict
-- Zenith Desktop Shell — Central Reactive Store & State Controller
-- Bridges local state, atomic persistence, bidirectional config.json sync and fine-grained signals

if _G.__zenith_store then
    return _G.__zenith_store
end

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
    barPosition = "Top Edge",
    barCornerStyle = "Floating Glass",
    barHeight = 42,
    barCompactHeight = 36,
    barMarginTop = 4,
    barRadius = 18,
    barPadding = 8,
    barFloatShadow = true,
    barAutoHideDelayMs = 200,
    trayMonochromeIcons = false,
    trayFilterPassive = false,
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
    dockIconSize = 40,
    dockMagnification = true,
    dockMaxScale = 1.5,
    dockSigma = 80,

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
    weatherCity = "auto",
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

local dotted_map: { [string]: string } = {
    accentColor = "quick.accentColor",
    darkMode = "quick.darkMode",
    layoutPreset = "quick.layoutPreset",
    colorScheme = "quick.colorScheme",
    fontSizeScale = "appearance.fontSizeScale",
    radiusScale = "appearance.radiusScale",
    barGlassOpacity = "appearance.blurOpacity",
    springStiffness = "appearance.springStiffness",
    springDamping = "appearance.springDamping",
    barHeight = "bar.height",
    barAutoHide = "bar.autoHide",
    barRadius = "bar.customRounding",
    barPosition = "bar.position",
    barCornerStyle = "bar.cornerStyle",
    barCompactHeight = "bar.compactHeight",
    barMarginTop = "bar.marginTop",
    barPadding = "bar.padding",
    barFloatShadow = "bar.floatStyleShadow",
    barAutoHideDelayMs = "bar.autoHideDelayMs",
    barCompactMode = "bar.compactMode",
    barZenMode = "bar.zenMode",
    dockHeight = "dock.height",
    dockAutoHide = "dock.autoHide",
    dockEnabled = "dock.enable",
    dockBlurGlass = "dock.enableBlurGlass",
    dockShowMpris = "dock.showMpris",
    dockShowTrash = "dock.showTrash",
    dockIconSize = "dock.iconSize",
    enableHotCorners = "panels.hotCornersEnable",
    hotcornerTL = "panels.hotCornerTopLeft",
    hotcornerTR = "panels.hotCornerTopRight",
    cornerDwellTime = "panels.hotCornerDwellMs",
    audioVolumeStep = "system.audioVolumeStep",
    audioProtection = "system.audioProtection",
    batteryChargeLimit = "system.batteryChargeLimit",
    batteryLowThreshold = "system.batteryLowThreshold",
    batteryCriticalThreshold = "system.batteryCriticalThreshold",
    batteryPowerProfile = "system.batteryPowerProfile",
    batteryNotifyFull = "system.batteryNotifyFull",
    autoSuspend = "system.batteryAutoSuspend",
    suspendTimeoutMin = "system.suspendTimeoutMin",
    timeFormat = "system.timeFormat",
    dateFormat = "system.dateFormat",
    nightLightEnabled = "system.nightLightEnabled",
    nightLightTemp = "system.nightLightValue",
    grayscaleIntensity = "system.grayscaleValue",
    hyprlockBlur = "system.hyprlockBlur",
    hyprlockGrace = "system.hyprlockGraceSec",
    hyprlockShowClock = "system.hyprlockShowClock",
    pomodoroFocus = "system.pomodoroFocusMin",
    pomodoroBreak = "system.pomodoroBreakMin",
    hyprLayout = "compositor.layout",
    gapsIn = "compositor.gapsIn",
    gapsOut = "compositor.gapsOut",
    borderSize = "compositor.borderSize",
    cursorSpeed = "compositor.cursorSensitivity",
    touchpadNaturalScroll = "compositor.touchpadNaturalScroll",
    touchpadTapToClick = "compositor.touchpadTapToClick",
    aiTemperature = "ai.temperature",
    aiProvider = "ai.provider",
    aiModel = "ai.model",
    advancedLogLevel = "advanced.logLevel",
    wallpaperBackend = "wallpaper.backend",
    wallpaperRefreshMin = "wallpaper.slideshowIntervalMin",
}

local WRITE_MAP: { [string]: string } = {
    accentColor = "quick.accentColor",
    darkMode = "quick.darkMode",
    layoutPreset = "quick.layoutPreset",
    colorScheme = "quick.colorScheme",
    fontSizeScale = "appearance.fontSizeScale",
    radiusScale = "appearance.radiusScale",
    barGlassOpacity = "appearance.blurOpacity",
    springStiffness = "appearance.springStiffness",
    springDamping = "appearance.springDamping",
    barHeight = "bar.height",
    barAutoHide = "bar.autoHide",
    barRadius = "bar.customRounding",
    barPosition = "bar.position",
    barCornerStyle = "bar.cornerStyle",
    barCompactHeight = "bar.compactHeight",
    barMarginTop = "bar.marginTop",
    barPadding = "bar.padding",
    barFloatShadow = "bar.floatStyleShadow",
    barAutoHideDelayMs = "bar.autoHideDelayMs",
    barCompactMode = "bar.compactMode",
    barZenMode = "bar.zenMode",
    dockHeight = "dock.height",
    dockAutoHide = "dock.autoHide",
    dockEnabled = "dock.enable",
    dockBlurGlass = "dock.enableBlurGlass",
    dockShowMpris = "dock.showMpris",
    dockShowTrash = "dock.showTrash",
    dockIconSize = "dock.iconSize",
    enableHotCorners = "panels.hotCornersEnable",
    hotcornerTL = "panels.hotCornerTopLeft",
    hotcornerTR = "panels.hotCornerTopRight",
    cornerDwellTime = "panels.hotCornerDwellMs",
    audioVolumeStep = "system.audioVolumeStep",
    audioProtection = "system.audioProtection",
    batteryChargeLimit = "system.batteryChargeLimit",
    batteryLowThreshold = "system.batteryLowThreshold",
    batteryCriticalThreshold = "system.batteryCriticalThreshold",
    batteryPowerProfile = "system.batteryPowerProfile",
    batteryNotifyFull = "system.batteryNotifyFull",
    autoSuspend = "system.batteryAutoSuspend",
    suspendTimeoutMin = "system.suspendTimeoutMin",
    timeFormat = "system.timeFormat",
    dateFormat = "system.dateFormat",
    nightLightEnabled = "system.nightLightEnabled",
    nightLightTemp = "system.nightLightValue",
    grayscaleIntensity = "system.grayscaleValue",
    hyprlockBlur = "system.hyprlockBlur",
    hyprlockGrace = "system.hyprlockGraceSec",
    hyprlockShowClock = "system.hyprlockShowClock",
    pomodoroFocus = "system.pomodoroFocusMin",
    pomodoroBreak = "system.pomodoroBreakMin",
    hyprLayout = "compositor.layout",
    gapsIn = "compositor.gapsIn",
    gapsOut = "compositor.gapsOut",
    borderSize = "compositor.borderSize",
    cursorSpeed = "compositor.cursorSensitivity",
    touchpadNaturalScroll = "compositor.touchpadNaturalScroll",
    touchpadTapToClick = "compositor.touchpadTapToClick",
    aiTemperature = "ai.temperature",
    aiProvider = "ai.provider",
    aiModel = "ai.model",
    advancedLogLevel = "advanced.logLevel",
    wallpaperBackend = "wallpaper.backend",
    wallpaperRefreshMin = "wallpaper.slideshowIntervalMin",
}

local signals_cache: { [string]: any } = {}
local bindings_cache: { [string]: { (any) -> () } } = {}

local Store = {}

function Store.get(key: string, fallback: any?): any
    local default_val = if fallback ~= nil then fallback else DEFAULTS[key]
    local val: any = nil

    if Zenith.Storage and Zenith.Storage.get then
        val = Zenith.Storage.get(key, nil)
        if val == nil then
            local mapped_k = dotted_map[key]
            if mapped_k then
                val = Zenith.Storage.get(mapped_k, nil)
            end
        end
    end

    local final_val = if val ~= nil then val else default_val

    -- Normalize normalized floats (0.0 .. 1.0) to integer percentages expected by Sliders
    if key == "fontSizeScale" and type(final_val) == "number" and final_val <= 2.0 then
        return math.floor(final_val * 100)
    elseif key == "radiusScale" and type(final_val) == "number" and final_val <= 2.0 then
        return math.floor(final_val * 100)
    elseif key == "springDamping" and type(final_val) == "number" and final_val <= 1.0 then
        return math.floor(final_val * 100)
    elseif key == "aiTemperature" and type(final_val) == "number" and final_val <= 1.0 then
        return math.floor(final_val * 100)
    elseif key == "audioVolumeStep" and type(final_val) == "number" and final_val <= 0.20 then
        return math.floor(final_val * 100)
    elseif key == "barGlassOpacity" and type(final_val) == "number" and final_val <= 1.0 then
        return math.floor(final_val * 100)
    end

    return final_val
end

function Store.set(key: string, val: any)
    if Zenith.Storage and Zenith.Storage.set then
        Zenith.Storage.set(key, val)
        local mapped = WRITE_MAP[key]
        if mapped then
            Zenith.Storage.set(mapped, val)
        end
    end

    if signals_cache[key] then
        signals_cache[key]:set(val)
    end

    if bindings_cache[key] then
        for _, cb in ipairs(bindings_cache[key]) do
            cb(val)
        end
    end
end

function Store.toggle(key: string): boolean
    local cur = Store.get(key, false)
    local next_val = not cur
    Store.set(key, next_val)
    return next_val
end

function Store.bind(key: string, callback: (any) -> ())
    if not bindings_cache[key] then
        bindings_cache[key] = {}
    end
    table.insert(bindings_cache[key], callback)
end

function Store.signal<T>(key: string, fallback: T?): any
    if signals_cache[key] then
        return signals_cache[key]
    end

    local initial = Store.get(key, fallback)
    local sig = nil
    if Zenith.Signal then
        local s, _ = Zenith.Signal(initial)
        sig = s
    elseif Zenith.signal then
        local s, _ = Zenith.signal(initial)
        sig = s
    else
        local cur = initial
        local subs: { (any) -> () } = {}
        sig = {
            get = function() return cur end,
            set = function(_, new_val: any)
                cur = new_val
                for _, cb in ipairs(subs) do cb(cur) end
            end,
            subscribe = function(_, cb: (any) -> ())
                table.insert(subs, cb)
                cb(cur)
                return function()
                    for idx, c in ipairs(subs) do
                        if c == cb then table.remove(subs, idx); break end
                    end
                end
            end
        }
    end

    signals_cache[key] = sig
    return sig
end

function Store.has(key: string): boolean
    if Zenith.Storage and Zenith.Storage.has then
        return Zenith.Storage.has(key)
    end
    return DEFAULTS[key] ~= nil
end

function Store.remove(key: string)
    if Zenith.Storage and Zenith.Storage.remove then
        Zenith.Storage.remove(key)
    end
end

function Store.sync()
    if Zenith.Storage and Zenith.Storage.sync_to_config then
        Zenith.Storage.sync_to_config()
    end
end

function Store.reload()
    if Zenith.Storage and Zenith.Storage.reload_from_config then
        Zenith.Storage.reload_from_config()
    end
end

function Store.flush()
    if Zenith.Storage and Zenith.Storage.flush then
        Zenith.Storage.flush()
    end
end

function Store.getAll(): { [string]: any }
    local result: { [string]: any } = {}
    for k, _ in pairs(DEFAULTS) do
        result[k] = Store.get(k)
    end
    return result
end

function Store.resetDefaults()
    for k, v in pairs(DEFAULTS) do
        Store.set(k, v)
    end
end

_G.__zenith_store = Store
return Store
