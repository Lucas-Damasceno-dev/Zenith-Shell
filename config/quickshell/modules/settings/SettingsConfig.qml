pragma Singleton
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import "../../core"

/**
 * SettingsConfig - Centralized configuration singleton for Zenith-Shell.
 * Provides deep dot-notation get/set, disk persistence, and reactive signals.
 */
Item {
    id: root

    property string configPath: RuntimePaths.configFile("zenith/config.json")
    property string fallbackPath: RuntimePaths.appDataFile("config.json")
    property bool ready: false
    property bool dirty: false
    property var configData: ({})
    property int revision: 0

    signal configChanged(string path, var value)
    signal loaded()

    readonly property string defaultJsonContent: `{
  "quick": {
    "wallpaperPath": "",
    "layoutPreset": "default",
    "accentColor": "#7aa2f7",
    "colorScheme": "tonal_spot",
    "darkMode": true,
    "barAutoHide": true,
    "barCompactMode": false,
    "reducedMotion": false,
    "privacyMode": false,
    "focusMode": false,
    "lowPowerMode": false
  },
  "appearance": {
    "globalStyle": "material",
    "colorInvert": false,
    "accentColor": "#7aa2f7",
    "fontUI": "Inter",
    "fontMono": "JetBrainsMono Nerd Font",
    "fontSizeScale": 1.0,
    "radiusScale": 1.0,
    "blurOpacity": 0.85,
    "glassEffect": true,
    "motionProfile": "snappy",
    "springStiffness": 4.0,
    "springDamping": 0.70
  },
  "bar": {
    "position": "top",
    "height": 44,
    "compactHeight": 36,
    "autoHide": true,
    "autoHideDelayMs": 300,
    "compactMode": false,
    "borderless": false,
    "cornerStyle": "floating",
    "customRounding": 16,
    "floatStyleShadow": true,
    "showCenterClock": true,
    "showCenterMedia": true,
    "showCenterWeather": true,
    "showCenterNotifications": true,
    "showCenterUtilityHub": true,
    "showSystemTray": true,
    "showHardwareMonitors": true,
    "showClipboardTile": true,
    "showPrivacyIndicator": true,
    "showSessionButton": true,
    "trayMonochromeIcons": true,
    "trayFilterPassive": true
  },
  "dock": {
    "enable": true,
    "position": "bottom",
    "height": 52,
    "iconSize": 36,
    "hoverRegionHeight": 6,
    "hoverToReveal": true,
    "enableBlurGlass": true,
    "monochromeIcons": false,
    "showMpris": true,
    "showScratchpad": true,
    "showTrash": true,
    "showRecentFiles": false,
    "pinnedApps": [
      "firefox.desktop",
      "kitty.desktop",
      "codium.desktop",
      "thunar.desktop",
      "spotify.desktop"
    ]
  },
  "wallpaper": {
    "backend": "swww",
    "wallpaperPath": "",
    "slideshow": false,
    "slideshowIntervalMin": 30,
    "effects": "none",
    "pauseAnimationOnBattery": true,
    "hideWhenFullscreen": true,
    "parallax": false,
    "blurRadius": 0,
    "dimOpacity": 0.0
  },
  "system": {
    "audioPreferredSink": "",
    "audioPreferredSource": "",
    "audioVolumeStep": 0.05,
    "audioProtection": true,
    "batteryChargeLimit": 80,
    "batteryNotifyFull": true,
    "batteryLowThreshold": 20,
    "batteryCriticalThreshold": 5,
    "batteryPowerProfile": "balanced",
    "batteryAutoSuspend": false,
    "suspendTimeoutMin": 15,
    "screenOffTimeoutMin": 5,
    "nightLightEnabled": false,
    "nightLightValue": 3500,
    "grayscaleValue": 0,
    "hyprlockBlur": 8,
    "hyprlockDim": 0.2,
    "hyprlockGraceSec": 5,
    "hyprlockShowClock": true,
    "timeFormat": "24h",
    "dateFormat": "ddd, dd/MM",
    "secondPrecision": false,
    "pomodoroFocusMin": 25,
    "pomodoroBreakMin": 5
  },
  "panels": {
    "overviewColumns": 4,
    "overviewRows": 2,
    "overviewBlur": true,
    "overviewDim": 0.4,
    "exposeScale": 0.85,
    "hotCornersEnable": false,
    "hotCornerTopLeft": "overview",
    "hotCornerTopRight": "dashboard",
    "hotCornerBottomLeft": "launcher",
    "hotCornerBottomRight": "session",
    "hotCornerDwellMs": 150,
    "workspaceStripEnable": false,
    "workspaceStripSide": "right",
    "workspaceStripWidth": 420
  },
  "tools": {
    "screenRecordFps": 60,
    "screenRecordVideoCodec": "libx264",
    "screenRecordAudioCodec": "aac",
    "screenRecordContainer": "mkv",
    "screenRecordQualityPreset": "balanced",
    "screenRecordAudioSource": "both",
    "screenRecordSavePath": "",
    "screenRecordShowOsd": true,
    "screenRecordDiscordCompress": false,
    "screenshotFormat": "png",
    "screenshotMode": "full",
    "screenshotDelaySec": 0,
    "screenshotSavePath": "",
    "screenshotCopyThumb": true,
    "ocrLanguage": "eng",
    "lensProvider": "google",
    "crosshairEnable": false,
    "crosshairColor": "#00ffcc",
    "crosshairSize": 16
  },
  "services": {
    "weatherProvider": "open-meteo",
    "weatherCity": "",
    "weatherUnits": "metric",
    "weatherRefreshMin": 30,
    "mediaPreferredPlayer": "",
    "mediaFilterDuplicates": true,
    "mediaSpectrumEnabled": false,
    "calendarExternalSync": false,
    "calendarUpcomingDays": 7,
    "appTerminal": "kitty",
    "appBrowser": "firefox",
    "appFileManager": "thunar",
    "appEditor": "codium",
    "appTaskManager": "btop"
  },
  "compositor": {
    "layout": "dwindle",
    "gapsIn": 5,
    "gapsOut": 10,
    "borderSize": 2,
    "activeBorderColor": "#7aa2f7",
    "inactiveBorderColor": "#1f2335",
    "cursorSensitivity": 1.0,
    "touchpadNaturalScroll": true,
    "touchpadTapToClick": true,
    "animationSpeed": "snappy"
  },
  "ai": {
    "provider": "gemini",
    "model": "gemini-2.5-flash",
    "apiKey": "",
    "systemPrompt": "You are a concise, helpful desktop assistant.",
    "temperature": 0.7,
    "voiceSearchEnabled": false,
    "voiceProvider": "whisper",
    "voiceLanguage": "auto"
  },
  "dashboard": {
    "enable": true,
    "showHeader": true,
    "showPowerButtons": true,
    "greetingText": "Welcome back",
    "widthRatio": 0.45,
    "showWeatherSection": true,
    "showMediaSection": true,
    "showSystemSection": true,
    "showQuickNotes": true
  },
  "autostart": {
    "entries": [
      { "id": "hypridle", "name": "Hypridle", "command": "hypridle", "enabled": true, "desc": "Idle management daemon" },
      { "id": "swww", "name": "Swww Daemon", "command": "swww-daemon", "enabled": true, "desc": "Wallpaper animation daemon" },
      { "id": "mpris", "name": "Playerctl Daemon", "command": "playerctld daemon", "enabled": true, "desc": "MPRIS media tracking" },
      { "id": "polkit", "name": "Polkit Agent", "command": "/usr/lib/polkit-kde-authentication-agent-1", "enabled": true, "desc": "Privilege escalation agent" }
    ]
  },
  "modules": {
    "bar": true,
    "dock": true,
    "launcher": true,
    "overview": true,
    "dashboard": true,
    "hotcorners": false,
    "cheatsheet": true,
    "notifications": true,
    "osd": true,
    "mediaControls": true,
    "audioSpectrum": false,
    "sessionScreen": true,
    "quickNotes": true,
    "systemMonitor": true,
    "mascot": false
  },
  "advanced": {
    "jsgcThresholdMb": 128,
    "lowPowerThreshold": 20,
    "memoryMonitoring": true,
    "memoryWarningNotification": true,
    "compositorBlur": true,
    "logLevel": "info",
    "debugOverlays": false
  }
}`

    FileView {
        id: configFileView
        path: root.configPath
        preload: true
        printErrors: false

        onLoaded: {
            root._parseAndLoad(configFileView.text());
        }

        onLoadFailed: function(error) {
            // If primary doesn't exist, try loading default and save
            root._loadDefault();
            root.flush();
        }
    }

    Timer {
        id: saveDebounce
        interval: 400
        repeat: false
        onTriggered: root.flush()
    }

    function _clone(obj) {
        try {
            return JSON.parse(JSON.stringify(obj));
        } catch (e) {
            return {};
        }
    }

    function _loadDefault() {
        try {
            root.configData = JSON.parse(root.defaultJsonContent);
        } catch (e) {
            root.configData = {};
        }
        root.ready = true;
        root.loaded();
    }

    function _parseAndLoad(text) {
        try {
            var raw = JSON.parse(text);
            var defaults = JSON.parse(root.defaultJsonContent);
            // Merge defaults with loaded
            root.configData = _deepMerge(defaults, raw);
        } catch (e) {
            console.warn("[SettingsConfig] Failed to parse config JSON, loading defaults", e);
            root._loadDefault();
        }
        root.ready = true;
        root.loaded();
        root._syncFeatureFlags();
    }

    function _deepMerge(target, source) {
        if (!source || typeof source !== "object") return target;
        var out = _clone(target);
        for (var key in source) {
            if (source.hasOwnProperty(key)) {
                if (source[key] !== null && typeof source[key] === "object" && !Array.isArray(source[key]) && typeof out[key] === "object" && !Array.isArray(out[key])) {
                    out[key] = _deepMerge(out[key], source[key]);
                } else {
                    out[key] = source[key];
                }
            }
        }
        return out;
    }

    function get(path, fallbackValue) {
        if (!path) return fallbackValue;
        var parts = path.split(".");
        var curr = root.configData;
        for (var i = 0; i < parts.length; i++) {
            if (curr === undefined || curr === null || typeof curr !== "object")
                return fallbackValue;
            curr = curr[parts[i]];
        }
        return curr !== undefined ? curr : fallbackValue;
    }

    function set(path, value) {
        if (!path) return;
        var parts = path.split(".");
        var curr = root.configData;
        for (var i = 0; i < parts.length - 1; i++) {
            var key = parts[i];
            if (!curr[key] || typeof curr[key] !== "object") {
                curr[key] = {};
            }
            curr = curr[key];
        }
        var lastKey = parts[parts.length - 1];
        if (curr[lastKey] === value) return;
        curr[lastKey] = value;
        root.dirty = true;
        root.revision = (root.revision + 1) % 1000000;
        root.configChanged(path, value);
        root._syncFeatureFlags();
        saveDebounce.restart();
    }

    function getBoolean(path, fallbackValue) {
        return root.get(path, fallbackValue === true) === true;
    }

    function getNumber(path, fallbackValue) {
        var val = Number(root.get(path, fallbackValue));
        return isFinite(val) ? val : Number(fallbackValue || 0);
    }

    function getString(path, fallbackValue) {
        var val = root.get(path, fallbackValue !== undefined ? fallbackValue : "");
        return val !== undefined && val !== null ? String(val) : "";
    }

    function flush() {
        if (!root.dirty && configFileView.loaded) return;
        try {
            var content = JSON.stringify(root.configData, null, 2);
            configFileView.setText(content);
            root.dirty = false;
        } catch (e) {
            console.warn("[SettingsConfig] Error saving config file:", e);
        }
    }

    function resetDefaults() {
        root._loadDefault();
        root.dirty = true;
        root.flush();
        root._syncFeatureFlags();
    }

    function exportJson() {
        return JSON.stringify(root.configData, null, 2);
    }

    function importJson(rawText) {
        try {
            var parsed = JSON.parse(rawText);
            var defaults = JSON.parse(root.defaultJsonContent);
            root.configData = _deepMerge(defaults, parsed);
            root.dirty = true;
            root.flush();
            root._syncFeatureFlags();
            return true;
        } catch (e) {
            console.warn("[SettingsConfig] Failed to import config JSON:", e);
            return false;
        }
    }

    function _syncFeatureFlags() {
        // Live synchronize core FeatureFlags singleton
        try {
            FeatureFlags.barAutoHide = root.getBoolean("bar.autoHide", true);
            FeatureFlags.dockAutoHide = root.getBoolean("dock.hoverToReveal", true);
            FeatureFlags.barCompactMode = root.getBoolean("bar.compactMode", false);
            FeatureFlags.dockEnabled = root.getBoolean("dock.enable", true);
            FeatureFlags.reducedMotion = root.getBoolean("quick.reducedMotion", false);
            FeatureFlags.privacyMode = root.getBoolean("quick.privacyMode", false);
            FeatureFlags.focusMode = root.getBoolean("quick.focusMode", false);
            FeatureFlags.lowPowerUiMode = root.getBoolean("quick.lowPowerMode", false);
            FeatureFlags.enableHotCorners = root.getBoolean("panels.hotCornersEnable", false);
            FeatureFlags.showCenterMedia = root.getBoolean("bar.showCenterMedia", true);
            FeatureFlags.showCenterNotifications = root.getBoolean("bar.showCenterNotifications", true);
            FeatureFlags.showCenterClock = root.getBoolean("bar.showCenterClock", true);
            FeatureFlags.showCenterWeather = root.getBoolean("bar.showCenterWeather", true);
            FeatureFlags.showCenterUtilityHub = root.getBoolean("bar.showCenterUtilityHub", true);
            FeatureFlags.showSystemTray = root.getBoolean("bar.showSystemTray", true);
            FeatureFlags.showHardwareMonitors = root.getBoolean("bar.showHardwareMonitors", true);
            FeatureFlags.showClipboardTile = root.getBoolean("bar.showClipboardTile", true);
            FeatureFlags.showSessionButton = root.getBoolean("bar.showSessionButton", true);
        } catch (e) {}
    }

    Component.onCompleted: {
        if (!configFileView.loaded) {
            root._loadDefault();
        }
    }

    Component.onDestruction: {
        root.flush();
    }
}
