import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"

/**
 * DockTrash — Trash icon that participates in magnification.
 */
Item {
    id: root

    property real baseSize: 48
    property int trashCount: 0
    property real magnification: 1.0
    property real riseOffset: 0
    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion
    
    readonly property real displaySize: baseSize * magnification

    Behavior on magnification {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 72; easing.type: Easing.OutCubic }
    }
    Behavior on riseOffset {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 72; easing.type: Easing.OutCubic }
    }

    width: displaySize
    height: displaySize

    signal hovered(bool isHovered)

    Timer {
        id: trashPollTimer
        interval: 60000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: trashProc.running = true
    }

    onHovered: function(isHov) {
        if (isHov) trashPollTimer.restart();
    }

    Process {
        id: trashProc
        command: ["ls", "-1", RuntimePaths.appDataDir + "/Trash/files"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (text || "").trim().split("\n");
                root.trashCount = (lines.length === 1 && lines[0] === "") ? 0 : lines.length;
            }
        }
    }

    property bool dropHovered: false

    Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.riseOffset
        width: root.displaySize * 0.85
        height: root.displaySize * 0.85
        radius: 12 * magnification
        color: (trashMouse.containsMouse || root.dropHovered)
            ? ColorScheme.withAlpha(ColorScheme.surface, 0.35)
            : "transparent"
        border.width: root.dropHovered ? 2 : 0
        border.color: ColorScheme.red
        Behavior on color {
            enabled: !root.reducedEffects
            ColorAnimation { duration: 120 }
        }
        Behavior on border.width {
            enabled: !root.reducedEffects
            NumberAnimation { duration: 100 }
        }
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.riseOffset
        text: root.trashCount > 0 ? "\u{f1f8}" : "\u{f2ed}"
        font.pixelSize: root.displaySize * 0.45
        font.family: Style.fontMono
        color: root.dropHovered ? ColorScheme.red : (root.trashCount > 0 ? ColorScheme.peach : ColorScheme.overlay)
        opacity: (trashMouse.containsMouse || root.dropHovered) ? 1.0 : 0.7
        Behavior on opacity {
            enabled: !root.reducedEffects
            NumberAnimation { duration: 120 }
        }
        Behavior on color {
            enabled: !root.reducedEffects
            ColorAnimation { duration: 200 }
        }
    }

    // Badge
    Rectangle {
        visible: root.trashCount > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 2 * magnification
        anchors.rightMargin: 2 * magnification
        anchors.verticalCenterOffset: -root.riseOffset
        width: Math.max(16 * magnification, badgeText.width + 8 * magnification)
        height: 16 * magnification
        radius: height / 2
        color: ColorScheme.red

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.trashCount > 99 ? "99+" : String(root.trashCount)
            color: ColorScheme.base00
            font.pixelSize: 9 * magnification
            font.bold: true
            font.family: Style.fontUI
        }
    }

    scale: trashMouse.pressed ? DesignTokens.pressedScale : 1.0
    Behavior on scale {
        enabled: !root.reducedEffects
        SpringAnimation { spring: DesignTokens.springSnappy; damping: DesignTokens.dampingSnappy; epsilon: 0.01 }
    }

    DropArea {
        anchors.fill: parent
        onEntered: function(drag) {
            root.dropHovered = true;
            drag.accepted = true;
        }
        onExited: {
            root.dropHovered = false;
        }
        onDropped: function(drop) {
            root.dropHovered = false;
            if (drop.hasUrls) {
                var files = [];
                for (var i = 0; i < drop.urls.length; i++) {
                    files.push("'" + drop.urls[i].toString().replace(/^file:\/\//, "") + "'");
                }
                if (files.length > 0) {
                    moveTrashProc.command = ["bash", "-c", "for f in " + files.join(" ") + "; do gio trash \"$f\" 2>/dev/null || rm -rf \"$f\"; done"];
                    moveTrashProc.running = true;
                }
                drop.acceptProposedAction();
            }
        }
    }

    Process {
        id: moveTrashProc
        onExited: trashPollTimer.restart()
    }

    MouseArea {
        id: trashMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onContainsMouseChanged: root.hovered(containsMouse)

        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (root.trashCount > 0) emptyTrashProc.running = true;
            } else {
                openTrashProc.running = true;
            }
        }
    }

    Process {
        id: emptyTrashProc
        command: [
            "bash",
            "-c",
            "trash_dir=\"" + RuntimePaths.appDataDir + "/Trash\"; rm -rf \"$trash_dir\"/files/* \"$trash_dir\"/info/*"
        ]
        stdout: StdioCollector { onStreamFinished: root.trashCount = 0 }
    }

    Process {
        id: openTrashProc
        command: ["xdg-open", "trash:///"]
    }
}
