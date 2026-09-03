import QtQuick
import QtCore
import Quickshell.Io
import "../core"

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property bool ready: false
    property bool dirty: false
    property string configPath: RuntimePaths.appDataFile("config.json")
    readonly property int latestSchemaVersion: 12

    function get(key, fallbackValue) {
        if (storeAdapter[key] === undefined) return fallbackValue;
        return storeAdapter[key];
    }

    function set(key, value) {
        if (storeAdapter[key] === undefined) return;
        if (storeAdapter[key] === value) return;
        storeAdapter[key] = value;
        scheduleWrite();
    }

    function scheduleWrite() {
        dirty = true;
        writeDebounce.restart();
    }

    function flush() {
        if (!dirty) return;
        storeFile.writeAdapter();
        dirty = false;
    }

    function migrateIfNeeded() {
        var currentSchema = Number(storeAdapter.schemaVersion || 0);
        if (currentSchema >= latestSchemaVersion) return;

        if (currentSchema < 1) {
            // Base migration: ensure utility flags exist with safe defaults.
            storeAdapter.utilityMicEnabled = !!storeAdapter.utilityMicEnabled;
            storeAdapter.utilitySystemEnabled = !!storeAdapter.utilitySystemEnabled;
        }

        if (currentSchema < 2) {
            storeAdapter.barCompactMode = !!storeAdapter.barCompactMode;
            storeAdapter.barAutoHide = !!storeAdapter.barAutoHide;
            storeAdapter.barDndVisualMode = storeAdapter.barDndVisualMode !== false;
            storeAdapter.mediaPreferredPlayer = storeAdapter.mediaPreferredPlayer || "";
            storeAdapter.mediaSpectrumEnabled = !!storeAdapter.mediaSpectrumEnabled;
            storeAdapter.privacyMode = !!storeAdapter.privacyMode;
            storeAdapter.audioPreferredSink = storeAdapter.audioPreferredSink || "";
            storeAdapter.audioPreferredSource = storeAdapter.audioPreferredSource || "";
        }

        if (currentSchema < 3) {
            if (typeof storeAdapter.audioAppMixerPresetsJson === "string") {
                try {
                    storeAdapter.audioAppMixerPresetsJson = JSON.parse(storeAdapter.audioAppMixerPresetsJson);
                } catch (e) {
                    storeAdapter.audioAppMixerPresetsJson = {};
                }
            } else if (!storeAdapter.audioAppMixerPresetsJson) {
                storeAdapter.audioAppMixerPresetsJson = {};
            }
        }

        if (currentSchema < 4) {
            storeAdapter.utilityAnonymizeCapture = !!storeAdapter.utilityAnonymizeCapture;
        }

        if (currentSchema < 5) {
            storeAdapter.utilityScreenshotFormat = storeAdapter.utilityScreenshotFormat || "png";
            storeAdapter.utilityVideoContainer = storeAdapter.utilityVideoContainer || "mkv";
            storeAdapter.utilityVideoCodec = storeAdapter.utilityVideoCodec || "libx264";
            storeAdapter.utilityVideoFps = Number(storeAdapter.utilityVideoFps || 30);
            storeAdapter.utilityVideoQuality = Number(storeAdapter.utilityVideoQuality || 23);
            storeAdapter.utilityScreenshotDir = storeAdapter.utilityScreenshotDir || "";
            storeAdapter.utilityVideoDir = storeAdapter.utilityVideoDir || "";
            storeAdapter.utilityFileTemplate = storeAdapter.utilityFileTemplate || "{type}_{timestamp}";
            storeAdapter.utilityCopyPathThumb = !!storeAdapter.utilityCopyPathThumb;
            storeAdapter.utilityLensProvider = storeAdapter.utilityLensProvider || "google";
            storeAdapter.utilityOcrLang = storeAdapter.utilityOcrLang || "eng";
        }

        if (currentSchema < 6) {
            storeAdapter.contextProfile = storeAdapter.contextProfile || "work";
            storeAdapter.networkActiveView = storeAdapter.networkActiveView || "wifi";
            storeAdapter.systemMonitorSortMode = storeAdapter.systemMonitorSortMode || "cpu";
            storeAdapter.systemMonitorFilter = storeAdapter.systemMonitorFilter || "";
            storeAdapter.systemMonitorActiveTab = storeAdapter.systemMonitorActiveTab || "processes";
            storeAdapter.popupCenterOffsetY = Number(storeAdapter.popupCenterOffsetY || 46);
        }

        if (currentSchema < 7) {
            storeAdapter.batteryPrefsInitialized = !!storeAdapter.batteryPrefsInitialized;
            storeAdapter.batteryNightLightValue = Number(storeAdapter.batteryNightLightValue || 0);
            storeAdapter.batteryGrayscaleValue = Number(storeAdapter.batteryGrayscaleValue || 0);
            storeAdapter.batteryPowerProfile = storeAdapter.batteryPowerProfile || "balanced";
            storeAdapter.batteryLimitActive = !!storeAdapter.batteryLimitActive;
            storeAdapter.batteryCaffeineActive = !!storeAdapter.batteryCaffeineActive;
        }

        if (currentSchema < 8) {
            if (typeof storeAdapter.launcherStateJson === "string") {
                try {
                    storeAdapter.launcherStateJson = JSON.parse(storeAdapter.launcherStateJson);
                } catch (e) {
                    storeAdapter.launcherStateJson = {};
                }
            } else if (!storeAdapter.launcherStateJson) {
                storeAdapter.launcherStateJson = {};
            }
        }

        if (currentSchema < 9) {
            storeAdapter.focusMode = !!storeAdapter.focusMode;
        }

        if (currentSchema < 10) {
            if (typeof storeAdapter.launcherFavoritesJson === "string") {
                try {
                    storeAdapter.launcherFavoritesJson = JSON.parse(storeAdapter.launcherFavoritesJson);
                } catch (e) {
                    storeAdapter.launcherFavoritesJson = [];
                }
            } else if (!storeAdapter.launcherFavoritesJson) {
                storeAdapter.launcherFavoritesJson = [];
            }
        }

        if (currentSchema < 11) {
            storeAdapter.utilityScreenshotMode = storeAdapter.utilityScreenshotMode || "full";
            storeAdapter.utilityScreenshotDelaySec = Number(storeAdapter.utilityScreenshotDelaySec || 0);
        }

        if (currentSchema < 12) {
            if (typeof storeAdapter.aiChatStateJson === "string") {
                try {
                    storeAdapter.aiChatStateJson = JSON.parse(storeAdapter.aiChatStateJson);
                } catch (e) {
                    storeAdapter.aiChatStateJson = {};
                }
            } else if (!storeAdapter.aiChatStateJson) {
                storeAdapter.aiChatStateJson = {};
            }
        }

        storeAdapter.schemaVersion = latestSchemaVersion;
        dirty = true;
        flush();
    }

    FileView {
        id: storeFile
        path: root.configPath
        preload: true
        printErrors: false

        onLoaded: {
            root.ready = true;
            root.migrateIfNeeded();
        }
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) {
                storeFile.writeAdapter();
                root.ready = true;
            }
        }

        onAdapterUpdated: if (root.ready && root.dirty) writeDebounce.restart()

        JsonAdapter {
            id: storeAdapter
            property int schemaVersion: 12
            property bool utilityMicEnabled: false
            property bool utilitySystemEnabled: false
            property bool utilityAnonymizeCapture: false
            property var utilityScreenshotFormat: "png"
            property var utilityScreenshotMode: "full"
            property int utilityScreenshotDelaySec: 0
            property var utilityVideoContainer: "mkv"
            property var utilityVideoCodec: "libx264"
            property int utilityVideoFps: 30
            property int utilityVideoQuality: 23
            property var utilityScreenshotDir: ""
            property var utilityVideoDir: ""
            property var utilityFileTemplate: "{type}_{timestamp}"
            property bool utilityCopyPathThumb: false
            property var utilityLensProvider: "google"
            property var utilityOcrLang: "eng"
            property bool barCompactMode: false
            property bool barAutoHide: true
            property bool barDndVisualMode: true
            property var mediaPreferredPlayer: ""
            property bool mediaSpectrumEnabled: false
            property bool privacyMode: false
            property bool focusMode: false
            property var audioPreferredSink: ""
            property var audioPreferredSource: ""
            property var audioAppMixerPresetsJson: ({})
            property var contextProfile: "work"
            property var networkActiveView: "wifi"
            property var systemMonitorSortMode: "cpu"
            property var systemMonitorFilter: ""
            property var systemMonitorActiveTab: "processes"
            property int popupCenterOffsetY: 46
            property bool batteryPrefsInitialized: false
            property int batteryNightLightValue: 0
            property int batteryGrayscaleValue: 0
            property var batteryPowerProfile: "balanced"
            property bool batteryLimitActive: false
            property bool batteryCaffeineActive: false
            property var launcherStateJson: ({})
            property var launcherFavoritesJson: []
            property var aiChatStateJson: ({})
        }
    }

    Timer {
        id: writeDebounce
        interval: 2000
        repeat: false
        onTriggered: root.flush()
    }

    Component.onDestruction: root.flush()
}
