import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../core"
import "../../core/TrayIconUtils.js" as TrayIconUtils

/**
 * DockScratchpad — Badge showing minimized window count with restore popup.
 */
Item {
    id: root

    property real baseSize: 48
    property real magnification: 1.0
    property real riseOffset: 0
    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion

    readonly property real displaySize: baseSize * magnification
    readonly property int scratchCount: DockService.scratchpadCount

    Behavior on magnification {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 72; easing.type: Easing.OutCubic }
    }
    Behavior on riseOffset {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 72; easing.type: Easing.OutCubic }
    }

    visible: scratchCount > 0
    width: scratchCount > 0 ? displaySize : 0
    height: displaySize

    Behavior on width {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
    }

    signal hovered(bool isHovered)

    Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.riseOffset
        width: root.displaySize * 0.85
        height: root.displaySize * 0.85
        radius: 12 * magnification
        color: scratchMouse.containsMouse
            ? ColorScheme.withAlpha(ColorScheme.surface, 0.35)
            : "transparent"
        Behavior on color {
            enabled: !root.reducedEffects
            ColorAnimation { duration: 120 }
        }
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.riseOffset
        text: "\u{f2d2}"
        font.pixelSize: root.displaySize * 0.45
        font.family: Style.fontMono
        color: ColorScheme.mauve
        opacity: scratchMouse.containsMouse ? 1.0 : 0.7
        Behavior on opacity {
            enabled: !root.reducedEffects
            NumberAnimation { duration: 120 }
        }
    }

    // Badge
    Rectangle {
        visible: root.scratchCount > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 2 * magnification
        anchors.rightMargin: 2 * magnification
        width: Math.max(16 * magnification, scratchBadgeText.width + 8 * magnification)
        height: 16 * magnification
        radius: height / 2
        color: ColorScheme.mauve

        Text {
            id: scratchBadgeText
            anchors.centerIn: parent
            text: root.scratchCount > 99 ? "99+" : String(root.scratchCount)
            color: ColorScheme.base00
            font.pixelSize: 9 * magnification
            font.bold: true
            font.family: Style.fontUI
        }
    }

    scale: scratchMouse.pressed ? DesignTokens.pressedScale : 1.0
    Behavior on scale {
        enabled: !root.reducedEffects
        SpringAnimation { spring: DesignTokens.springSnappy; damping: DesignTokens.dampingSnappy; epsilon: 0.01 }
    }

    MouseArea {
        id: scratchMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onContainsMouseChanged: root.hovered(containsMouse)

        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                DockService.restoreAllFromScratchpad();
            } else {
                // Toggle scratchpad popup visibility
                scratchPopup.showPopup = !scratchPopup.showPopup;
            }
        }
    }

    // ── Scratchpad Popup ─────────────────────────────────────
    PanelWindow {
        id: scratchPopup

        property bool showPopup: false

        visible: showPopup && root.scratchCount > 0
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-popup"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { left: false; right: false; top: false; bottom: false }

        implicitWidth: scratchCol.width + 16
        implicitHeight: scratchCol.height + 16

        margins {
            left: Math.max(0, root.mapToItem(null, root.width / 2, 0).x - width / 2)
            bottom: 76
        }

        // Shadow
        Rectangle {
            anchors.fill: scratchCard
            anchors.topMargin: 4
            radius: scratchCard.radius
            color: Qt.rgba(0, 0, 0, 0.16)
            z: -1
        }

        Rectangle {
            id: scratchCard
            anchors.fill: parent
            radius: DesignTokens.radiusMD
            color: ColorScheme.glassPopup
            border.width: 1
            border.color: ColorScheme.glassBorder

            opacity: scratchPopup.showPopup ? 1.0 : 0.0
            scale: scratchPopup.showPopup ? 1.0 : 0.90
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
                id: scratchCol
                anchors.centerIn: parent
                width: 200
                spacing: 4

                Text {
                    width: parent.width
                    text: "Minimized (" + root.scratchCount + ")"
                    color: ColorScheme.textAlt
                    font.pixelSize: 11
                    font.family: Style.fontUI
                    font.weight: Font.DemiBold
                    leftPadding: 8; topPadding: 4; bottomPadding: 4
                }

                Rectangle { width: parent.width; height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.06) }

                Repeater {
                    model: DockService.scratchpadWindows

                    delegate: Rectangle {
                        width: 200; height: 32; radius: DesignTokens.radiusXS
                        color: spItemMouse.containsMouse ? ColorScheme.stateHover : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: 8; spacing: 6

                            Image {
                                width: 18; height: 18
                                property var iconHints: ({ icon: modelData.icon || "", id: modelData.appId || "", title: modelData.title || "" })
                                property string primaryIconSource: TrayIconUtils.primaryIconSource(iconHints)
                                property string fallbackIconSource: TrayIconUtils.fallbackSource(iconHints)
                                source: primaryIconSource !== "" ? primaryIconSource : fallbackIconSource
                                sourceSize: Qt.size(32, 32)
                                fillMode: Image.PreserveAspectFit
                                onStatusChanged: {
                                    if (status === Image.Error && source !== fallbackIconSource)
                                        source = fallbackIconSource;
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.title || "Window"
                                color: ColorScheme.text
                                font.pixelSize: 11; font.family: Style.fontUI
                                elide: Text.ElideRight
                                width: 150
                            }
                        }

                        MouseArea {
                            id: spItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                DockService.restoreFromScratchpad(modelData.address);
                                scratchPopup.showPopup = false;
                            }
                        }
                    }
                }

                // Restore All button
                Rectangle {
                    width: 200; height: 28; radius: DesignTokens.radiusXS
                    visible: root.scratchCount > 1
                    color: restoreAllMouse.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.15) : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 8
                        text: "Restore All"
                        color: ColorScheme.accent
                        font.pixelSize: 12; font.family: Style.fontUI
                    }
                    MouseArea {
                        id: restoreAllMouse; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            DockService.restoreAllFromScratchpad();
                            scratchPopup.showPopup = false;
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: scratchPopup.showPopup = false
        }
    }
}
