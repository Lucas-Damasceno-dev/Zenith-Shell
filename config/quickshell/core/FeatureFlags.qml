pragma Singleton
import QtQuick

QtObject {
    // ── Center bar modules ─────────────────────────────────────
    property bool showCenterMedia: true
    property bool showCenterNotifications: true
    property bool showCenterClock: true
    property bool showCenterWeather: true
    property bool showCenterUtilityHub: true

    // ── Right bar modules (granular) ───────────────────────────
    property bool showRightBarModules: true
    property bool showSystemTray: true
    property bool showHardwareMonitors: true
    property bool showContextTile: false
    property bool showClipboardTile: true
    property bool showContextProfile: true
    property bool showSessionButton: true

    // ── Dock behaviour & modules ──────────────────────────────
    property bool dockEnabled: true
    property bool dockInBar: false
    property bool dockShowMpris: true
    property bool dockShowScratchpad: true
    property bool dockShowTrash: true
    property bool dockShowRecentFiles: false
    property bool dockShowUtilities: false

    // ── Bar behaviour ──────────────────────────────────────────
    property bool barCompactMode: false
    property bool barAutoHide: true
    property bool barDndVisualMode: true
    property bool reducedMotion: false
    property bool privacyMode: false
    property bool lowPowerUiMode: false
    property bool focusMode: false
    property bool enableHotCorners: false
}
