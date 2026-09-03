pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../core"
import "../../../shared"

/**
 * WorkspaceIndicator - Modern, reactive workspace pill cluster with mini-app previews,
 * scroll switching, urgent alerting, and overview integration.
 *
 * Inspired by Caelestia, end-4 (illogical-impulse), and Dank Material Shell.
 */
Item {
    id: root

    // ─── Public API ──────────────────────────────────────────────
    property var screenData: null
    property var overviewInstance: null
    property color accentColor: ColorScheme.accent
    property color inactiveColor: ColorScheme.withAlpha(ColorScheme.text, 0.15)
    property color occupiedColor: ColorScheme.withAlpha(ColorScheme.text, 0.38)
    property color textColor: ColorScheme.foreground
    property color specialColor: ColorScheme.mauve
    property color urgentColor: ColorScheme.red

    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion

    // ─── Themed Icons (Nerd Font) per workspace slot ────────────
    readonly property var wsIcons: [
        "\u{f120}",  // 1: Terminal
        "\u{f0ac}",  // 2: Browser / Globe
        "\u{f07b}",  // 3: Files
        "\u{db84}\u{de1e}",  // 4: Code
        "\u{f15c}",  // 5: Document / Office
        "\u{f086}",  // 6: Chat
        "\u{f001}",  // 7: Music
        "\u{f008}",  // 8: Video
        "\u{f11b}",  // 9: Game
        "\u{f013}"   // 10: Settings
    ]

    // ─── Internal Reactivity & Caching ───────────────────────────
    property int _stateVersion: 0
    property string _activeSpecialName: ""
    property var _wsWindowCounts: ({})
    property var _specialFlags: ({})
    property var _urgentFlags: ({})
    property var _wsAppIcons: ({})

    // Monitor matching helper
    function _matchesScreen(c) {
        if (!c || !root.screenData) return true;
        var sName = String(root.screenData.name || "");
        if (sName === "") return true;
        if (c.monitor && c.monitor.name) {
            return String(c.monitor.name) === sName;
        }
        if (c.workspace && c.workspace.monitor && c.workspace.monitor.name) {
            return String(c.workspace.monitor.name) === sName;
        }
        return true;
    }

    function _rebuildCache() {
        var counts = {};
        var specFlags = {};
        var urgFlags = {};
        var appIcons = {};

        var vals = Hyprland.toplevels ? Hyprland.toplevels.values : null;
        if (vals && vals.length > 0) {
            for (var i = 0; i < vals.length; i++) {
                var c = vals[i];
                if (!c || !c.workspace) continue;
                if (!root._matchesScreen(c)) continue;

                var wid = String(c.workspace.id);
                counts[wid] = (counts[wid] || 0) + 1;

                // Track urgency
                var isUrgent = !!(c.urgent || (c.lastIpcObject && c.lastIpcObject.urgent));
                if (isUrgent) {
                    urgFlags[wid] = true;
                }

                // Track special workspaces
                var wname = String(c.workspace.name || "");
                if (wname.startsWith("special:")) {
                    specFlags[wname] = true;
                    if (isUrgent) urgFlags[wname] = true;
                }

                // Cache up to 3 icons per workspace for quick visual cues
                if (!appIcons[wid]) appIcons[wid] = [];
                if (appIcons[wid].length < 3) {
                    var appId = String(c.waylandSurface && c.waylandSurface.appId ? c.waylandSurface.appId : (c.appId || "")).toLowerCase();
                    if (appId === "" && c.lastIpcObject && c.lastIpcObject["class"]) {
                        appId = String(c.lastIpcObject["class"]).toLowerCase();
                    }
                    if (appId !== "") {
                        var iconSrc = "image://icon/" + appId;
                        if (typeof DesktopEntries !== "undefined" && DesktopEntries && DesktopEntries.byId) {
                            var entry = DesktopEntries.byId(appId);
                            if (entry && entry.icon) iconSrc = "image://icon/" + entry.icon;
                        }
                        if (appIcons[wid].indexOf(iconSrc) === -1) {
                            appIcons[wid].push(iconSrc);
                        }
                    }
                }
            }
        }

        root._wsWindowCounts = counts;
        root._specialFlags = specFlags;
        root._urgentFlags = urgFlags;
        root._wsAppIcons = appIcons;
        root._stateVersion++;
    }

    // Debounce rapid Hyprland window/workspace events
    Timer {
        id: eventDebounce
        interval: 20
        repeat: false
        onTriggered: root._rebuildCache()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event && event.name ? String(event.name) : "";
            if (n === "workspace" || n === "createworkspace" || n === "destroyworkspace" ||
                n === "openwindow" || n === "closewindow" || n === "movewindow" ||
                n === "activewindow" || n === "urgent" || n === "focusedmon") {
                eventDebounce.restart();
            }
            if (n === "activespecial" || n === "activespecialv2") {
                var data = (event.data || "").toString();
                var parts = data.split(",");
                if (n === "activespecialv2") {
                    root._activeSpecialName = (parts.length > 1 && parts[1] !== "") ? parts[1] : "";
                } else {
                    root._activeSpecialName = (parts.length > 0 && parts[0] !== "") ? parts[0] : "";
                }
                eventDebounce.restart();
            }
        }
    }

    Component.onCompleted: root._rebuildCache()

    // ─── Workspace Model ─────────────────────────────────────────
    readonly property var workspaceList: {
        var _v = root._stateVersion; // explicit reactive track
        var items = [];
        var focusedId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;

        for (var i = 0; i < 10; i++) {
            var wsId = i + 1;
            var widStr = String(wsId);
            var count = root._wsWindowCounts[widStr] || 0;
            var hasWindows = count > 0;
            var isFocused = focusedId === wsId;
            var spName = "special:sp" + wsId;
            var specialHasWindows = !!(root._specialFlags[spName]);
            var isUrgent = !!(root._urgentFlags[widStr] || root._urgentFlags[spName]);

            // Keep workspace visible if it has windows, is focused, or has special content
            if (!hasWindows && !isFocused && !specialHasWindows && !isUrgent) {
                continue;
            }

            items.push({
                index: i,
                wsId: wsId,
                isFocused: isFocused,
                hasWindows: hasWindows,
                windowCount: count,
                specialHasWindows: specialHasWindows,
                isUrgent: isUrgent,
                icons: root._wsAppIcons[widStr] || []
            });
        }

        // Always show at least the current workspace if everything is empty
        if (items.length === 0) {
            items.push({
                index: Math.max(0, focusedId - 1),
                wsId: focusedId > 0 ? focusedId : 1,
                isFocused: true,
                hasWindows: false,
                windowCount: 0,
                specialHasWindows: false,
                isUrgent: false,
                icons: []
            });
        }

        return items;
    }

    // Sizing
    implicitWidth: rowLayout.implicitWidth
    implicitHeight: DesignTokens.barItemHeight

    // ─── Smooth Wheel Scroll Switching ───────────────────────────
    property real _lastScrollTime: 0

    WheelHandler {
        id: wheelHandler
        target: root
        orientation: Qt.Vertical
        onWheel: (event) => {
            var now = Date.now();
            if (now - root._lastScrollTime < 110) return;
            root._lastScrollTime = now;

            var dir = event.angleDelta.y > 0 ? "-1" : "+1";
            Hyprland.dispatch("workspace " + (dir === "+1" ? "+1" : "-1"));
        }
    }

    // ─── Workspace Items Row ─────────────────────────────────────
    Row {
        id: rowLayout
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: root.workspaceList

            delegate: Rectangle {
                id: pill
                required property var modelData

                readonly property int wsId: modelData.wsId
                readonly property int slotIndex: modelData.index
                readonly property bool isFocused: modelData.isFocused
                readonly property bool hasWindows: modelData.hasWindows
                readonly property int windowCount: modelData.windowCount
                readonly property bool isUrgent: modelData.isUrgent
                readonly property bool specialHasWindows: modelData.specialHasWindows
                readonly property var appIcons: modelData.icons || []

                // Sizing & Spring physics
                implicitHeight: DesignTokens.barItemHeight - 4
                implicitWidth: isFocused
                    ? Math.max(34, contentRow.implicitWidth + 16)
                    : (hasWindows ? (appIcons.length > 0 ? Math.max(26, contentRow.implicitWidth + 12) : 24) : 22)
                radius: height / 2

                Behavior on implicitWidth {
                    enabled: !root.reducedEffects
                    SpringAnimation { spring: 4.8; damping: 0.55; epsilon: 0.3 }
                }

                // Background Color
                color: {
                    if (isUrgent) return ColorScheme.withAlpha(root.urgentColor, 0.85);
                    if (isFocused) return root.accentColor;
                    if (specialHasWindows) return ColorScheme.withAlpha(root.specialColor, 0.35);
                    if (hasWindows) return root.occupiedColor;
                    return root.inactiveColor;
                }

                border.width: 1
                border.color: {
                    if (isUrgent) return root.urgentColor;
                    if (isFocused) return ColorScheme.withAlpha(ColorScheme.text, 0.20);
                    if (pillMa.containsMouse) return ColorScheme.withAlpha(ColorScheme.foreground, DesignTokens.hoverBorderOpacity);
                    return ColorScheme.glassBorder;
                }

                Behavior on color {
                    enabled: !root.reducedEffects
                    ColorAnimation { duration: DesignTokens.durationNormal }
                }
                Behavior on border.color {
                    enabled: !root.reducedEffects
                    ColorAnimation { duration: DesignTokens.durationNormal }
                }

                // Micro scale on hover
                scale: (!root.reducedEffects && pillMa.containsMouse) ? 1.06 : 1.0
                Behavior on scale {
                    enabled: !root.reducedEffects
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }

                // Content Row: Category icon + mini app icons
                Row {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: 4

                    // Category Icon / Workspace Number
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (pill.slotIndex >= 0 && pill.slotIndex < root.wsIcons.length)
                            ? root.wsIcons[pill.slotIndex]
                            : String(pill.wsId)
                        font.family: DesignTokens.fontFamilyMono
                        font.pixelSize: pill.isFocused ? 12 : 10
                        color: {
                            if (pill.isUrgent) return ColorScheme.background;
                            if (pill.isFocused) return ColorScheme.background;
                            return ColorScheme.withAlpha(root.textColor, pill.hasWindows ? 0.90 : 0.50);
                        }
                    }

                    // Mini App Icons (shown inside active or occupied pill)
                    Repeater {
                        model: (pill.isFocused || pill.hasWindows) ? Math.min(2, pill.appIcons.length) : 0

                        delegate: Image {
                            required property int index
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                            width: 12
                            height: 12
                            sourceSize.width: 16
                            sourceSize.height: 16
                            source: pill.appIcons[index]
                            fillMode: Image.PreserveAspectFit
                            opacity: pill.isFocused ? 0.95 : 0.70
                        }
                    }
                }

                // Special workspace dot indicator (top-right badge)
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: -1
                    anchors.rightMargin: -1
                    width: 6
                    height: 6
                    radius: 3
                    visible: pill.specialHasWindows
                    color: root.specialColor
                    border.color: ColorScheme.background
                    border.width: 1
                    z: 10
                }

                // Urgent Pulse Animation
                SequentialAnimation on opacity {
                    running: pill.isUrgent && !root.reducedEffects
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.55; duration: 400 }
                    NumberAnimation { from: 0.55; to: 1.0; duration: 400 }
                }

                // Click & Hover Interaction
                MouseArea {
                    id: pillMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            // Right click: toggle special workspace for this slot
                            Hyprland.dispatch("togglespecialworkspace sp" + pill.wsId);
                            return;
                        }

                        if (mouse.button === Qt.MiddleButton) {
                            // Middle click: toggle overview
                            if (root.overviewInstance) {
                                ShellController.togglePopup(root, root.overviewInstance);
                            }
                            return;
                        }

                        // Left click: if already focused, toggle Overview; otherwise switch workspace
                        if (pill.isFocused && root.overviewInstance) {
                            ShellController.togglePopup(root, root.overviewInstance);
                        } else {
                            Hyprland.dispatch("workspace " + pill.wsId);
                        }
                    }
                }
            }
        }
    }
}
