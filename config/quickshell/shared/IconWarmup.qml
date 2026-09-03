import QtQuick
import "../core"

Item {
    id: root

    visible: false
    width: 0
    height: 0
    property bool isWarmupEnabled: true
    property bool warmupActive: false
    readonly property int warmupDelayMs: FeatureFlags.lowPowerUiMode ? 4000 : 1200
    readonly property var warmupEntries: [
        { source: "nix-snowflake", size: 18 },
        { source: "nix-snowflake", size: 24 },
        { source: "network-wireless", size: 18 },
        { source: "network-wireless", size: 24 },
        { source: "bluetooth-active", size: 18 },
        { source: "bluetooth-active", size: 24 },
        { source: "battery-good", size: 18 },
        { source: "battery-good", size: 24 },
        { source: "audio-volume-high", size: 18 },
        { source: "audio-volume-high", size: 24 },
        { source: "system-monitor", size: 18 },
        { source: "system-monitor", size: 24 },
        { source: "preferences-desktop-theme", size: 18 },
        { source: "preferences-desktop-theme", size: 24 },
        { source: "dialog-information", size: 18 },
        { source: "dialog-information", size: 24 },
        { source: "notifications", size: 18 },
        { source: "notifications", size: 24 },
        { source: "calendar", size: 18 },
        { source: "calendar", size: 24 },
        { source: "folder-open", size: 18 },
        { source: "folder-open", size: 24 },
        { source: "utilities-terminal", size: 18 },
        { source: "utilities-terminal", size: 24 }
    ]

    Timer {
        id: warmupTimer
        interval: root.warmupDelayMs
        repeat: false
        running: false
        onTriggered: root.warmupActive = root.isWarmupEnabled
    }

    Component.onCompleted: {
        if (root.isWarmupEnabled)
            warmupTimer.start();
    }

    Component.onDestruction: {
        warmupTimer.stop();
        root.warmupActive = false;
    }

    onIsWarmupEnabledChanged: {
        if (root.isWarmupEnabled) {
            root.warmupActive = false;
            warmupTimer.restart();
        } else {
            warmupTimer.stop();
            root.warmupActive = false;
        }
    }

    Component {
        id: warmupIconComponent
        SmartIcon {
            visible: false
        }
    }

    Repeater {
        model: root.warmupActive ? root.warmupEntries : []

        delegate: Loader {
            asynchronous: true
            active: root.warmupActive
            sourceComponent: warmupIconComponent

            onLoaded: {
                if (!item)
                    return;
                item.source = modelData.source || "";
                item.size = modelData.size || 24;
                item.useThemeProvider = true;
            }
        }
    }
}
