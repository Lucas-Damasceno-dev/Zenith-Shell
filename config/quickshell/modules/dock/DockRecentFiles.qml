import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../core"

/**
 * DockRecentFiles — Shows recent files from the Downloads folder as a dock icon with popup.
 */
Item {
    id: root

    property real baseSize: 48
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

    property var _recentFiles: []
    property bool _popupOpen: false

    // Refresh recent files every 60s
    Process {
        id: _recentProc
        command: ["bash", "-c", "ls -1t \"" + RuntimePaths.downloadsDir + "\" 2>/dev/null | head -8"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (text || "").trim().split("\n").filter(function(l) { return l.length > 0; });
                root._recentFiles = lines;
            }
        }
    }

    Timer {
        interval: 60000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: _recentProc.running = true
    }

    // Icon button
    Rectangle {
        id: iconBg
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.riseOffset
        width: root.displaySize * 0.85
        height: width
        radius: 12 * root.magnification
        color: iconMouse.containsMouse ? ColorScheme.stateHover : ColorScheme.withAlpha(ColorScheme.surface, 0.25)

        Behavior on color {
            enabled: !root.reducedEffects
            ColorAnimation { duration: DesignTokens.durationNormal }
        }

        Text {
            anchors.centerIn: parent
            text: "\u{f07b}"
            font.family: Style.fontMono
            font.pixelSize: parent.width * 0.45
            color: ColorScheme.accent
        }

        // Badge with count
        Rectangle {
            visible: root._recentFiles.length > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -3
            anchors.rightMargin: -3
            width: 16; height: 16; radius: 8
            color: ColorScheme.accent

            Text {
                anchors.centerIn: parent
                text: root._recentFiles.length
                color: ColorScheme.background
                font.pixelSize: 9
                font.weight: Font.Bold
                font.family: Style.fontUI
            }
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: root.hovered(containsMouse)
            onClicked: root._popupOpen = !root._popupOpen
        }
    }

    signal hovered(bool isHov)

    // Popup showing recent files
    PanelWindow {
        id: recentPopup
        visible: root._popupOpen && root._recentFiles.length > 0
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-popup"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { left: false; right: false; top: false; bottom: false }

        implicitWidth: recentCol.width + 16
        implicitHeight: recentCol.height + 16

        margins {
            left: Math.max(0, root.mapToItem(null, root.width / 2, 0).x - width / 2)
            bottom: 76
        }

        // Shadow
        Rectangle {
            anchors.fill: recentCard
            anchors.topMargin: 4
            radius: recentCard.radius
            color: Qt.rgba(0, 0, 0, 0.16)
            z: -1
        }

        Rectangle {
            id: recentCard
            anchors.fill: parent
            radius: DesignTokens.radiusMD
            color: ColorScheme.glassPopup
            border.width: 1
            border.color: ColorScheme.glassBorder

            opacity: root._popupOpen ? 1.0 : 0.0
            scale: root._popupOpen ? 1.0 : 0.90
            Behavior on opacity {
                enabled: !root.reducedEffects
                NumberAnimation { duration: 160 }
            }
            Behavior on scale {
                enabled: !root.reducedEffects
                SpringAnimation { spring: DesignTokens.springBouncy; damping: DesignTokens.dampingBouncy; epsilon: 0.01 }
            }
            transformOrigin: Item.Bottom

            Column {
                id: recentCol
                anchors.centerIn: parent
                width: 220
                spacing: 4

                Text {
                    width: parent.width
                    text: "Downloads Recentes (" + root._recentFiles.length + ")"
                    color: ColorScheme.textAlt
                    font.pixelSize: 11
                    font.family: Style.fontUI
                    font.weight: Font.DemiBold
                    leftPadding: 8; topPadding: 4; bottomPadding: 4
                }

                Rectangle { width: parent.width; height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.06) }

                Repeater {
                    model: root._recentFiles

                    delegate: Rectangle {
                        width: 220; height: 30; radius: DesignTokens.radiusXS
                        color: fileMouse.containsMouse ? ColorScheme.stateHover : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: 8; spacing: 6

                            Text {
                                text: "\u{f15b}"
                                font.family: Style.fontMono
                                font.pixelSize: 12
                                color: ColorScheme.accent
                            }

                            Text {
                                text: modelData
                                color: ColorScheme.text
                                font.pixelSize: 11
                                font.family: Style.fontUI
                                width: 180
                                elide: Text.ElideMiddle
                            }
                        }

                        MouseArea {
                            id: fileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                _openFileProc.command = ["xdg-open", RuntimePaths.downloadsDir + "/" + modelData];
                                _openFileProc.running = true;
                                root._popupOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }

    Process { id: _openFileProc }

    // Close popup when clicking elsewhere
    Timer {
        running: root._popupOpen
        interval: 8000
        onTriggered: root._popupOpen = false
    }
}
