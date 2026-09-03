import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../core"
import "../shared"
import "../services"

/**
 * VolumeMixerPopup - Per-app volume control
 * Uses native Pipewire stream integration for zero-overhead reactive control.
 */
PopupWindow {
    id: root

    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.text
    property real popupMargin: DesignTokens.spacingLG
    property var settingsStore

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    showScrim: false
    glassRadius: 0
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0
    originY: 0.0
    originX: 1.0
    slideY: 12

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        onClicked: (mouse) => {
            var p = mapToItem(popupCard, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > popupCard.width || p.y > popupCard.height) {
                root.isOpen = false;
            }
        }
    }

    Item {
        id: popupCard
        width: 360
        height: Math.min(500, Math.max(160, contentCol.implicitHeight + 36))
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: popupTopMargin
        anchors.rightMargin: root.popupMargin
        z: 1

        Rectangle {
            id: popupBg
            anchors.fill: parent
            radius: 16
            color: ColorScheme.glassPopup
            border.width: 1
            border.color: ColorScheme.outlineVariant
        }

        // Drop shadow
        Rectangle {
            anchors.fill: popupBg
            anchors.topMargin: 6
            radius: popupBg.radius
            color: Qt.rgba(0, 0, 0, 0.18)
            z: -1
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "\u{f028}"
                    font.family: DesignTokens.fontFamilyMono
                    font.pixelSize: 18
                    color: root.accentColor
                }

                Text {
                    text: "Mixer de Volume"
                    font.pixelSize: 14
                    font.bold: true
                    font.family: Style.fontUI
                    color: root.textColor
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: closeMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.text, 0.12) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f00d}"
                        font.family: DesignTokens.fontFamilyMono
                        font.pixelSize: 11
                        color: ColorScheme.withAlpha(root.textColor, 0.7)
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.isOpen = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: ColorScheme.withAlpha(root.textColor, 0.08)
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                AppVolumeMixer {
                    width: parent.width
                    accentColor: root.accentColor
                    textColor: root.textColor
                    settingsStore: root.settingsStore
                }
            }
        }
    }
}
