pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * WallpaperService - Context-aware wallpaper management
 * Bridges Quickshell with the random-wallpaper.sh engine
 */
Singleton {
    id: root

    // Public properties
    readonly property string currentWallpaper: _currentWallpaper
    readonly property string currentMode: _mode
    readonly property string timeOfDay: _timeOfDay
    readonly property var wallpaperHistory: _history

    // Private state
    property string _currentWallpaper: ""
    property string _mode: "auto" // auto, manual, schedule
    property string _timeOfDay: "day" // dawn, day, dusk, night
    property var _history: []
    property string _wallpaperScript: RuntimePaths.userHome + "/.config/hypr/scripts/random-wallpaper.sh"

    // Signals
    signal wallpaperChanged(string path)
    signal modeChanged(string mode)

    function nextWallpaper() {
        wallpaperProc.exec(["bash", _wallpaperScript, "--next"]);
    }

    function previousWallpaper() {
        wallpaperProc.exec(["bash", _wallpaperScript, "--prev"]);
    }

    function randomFavorite() {
        wallpaperProc.exec(["bash", _wallpaperScript, "--fav"]);
    }

    function setWallpaper(path) {
        if (!path) return;
        wallpaperProc.exec(["bash", _wallpaperScript, "--file", path]);
    }

    function updateTimeOfDay() {
        var hour = new Date().getHours();
        if (hour >= 5 && hour < 7) {
            _timeOfDay = "dawn";
        } else if (hour >= 7 && hour < 17) {
            _timeOfDay = "day";
        } else if (hour >= 17 && hour < 20) {
            _timeOfDay = "dusk";
        } else {
            _timeOfDay = "night";
        }
    }

    function syncCurrentWallpaper() {
        syncProc.exec(["bash", "-c", "readlink -f ~/.cache/wallpaper/current-media 2>/dev/null || true"]);
    }

    TimedProcess {
        id: wallpaperProc
        timeoutMs: 15000
        timeoutLabel: "WallpaperEngine"
        stdout: StdioCollector {
            onStreamFinished: {
                root.syncCurrentWallpaper();
            }
        }
    }

    TimedProcess {
        id: syncProc
        timeoutMs: 3000
        timeoutLabel: "SyncWallpaper"
        stdout: StdioCollector {
            onStreamFinished: {
                var path = text.trim();
                if (path && path !== root._currentWallpaper) {
                    root._currentWallpaper = path;
                    root.wallpaperChanged(path);
                }
            }
        }
    }

    // Check time every 30 minutes for auto mode
    Timer {
        id: timeCheckTimer
        interval: 30 * 60 * 1000 // 30 minutes
        running: root._mode === "auto"
        repeat: true
        onTriggered: {
            var oldTime = root._timeOfDay;
            root.updateTimeOfDay();
            if (oldTime !== root._timeOfDay) {
                root.nextWallpaper();
            }
        }
    }

    Component.onCompleted: {
        updateTimeOfDay();
        syncCurrentWallpaper();
    }
}
