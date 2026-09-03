import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../shared"
import "../services"

/**
 * USBPopup - Popup showing connected USB devices with mount/eject options,
 * storage usage progress bars, async busy spinners and Material You theming.
 */
PopupWindow {
    id: root

    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.text
    property real popupMargin: DesignTokens.spacingLG

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
        onClicked: function(mouse) {
            var p = mapToItem(popupCard, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > popupCard.width || p.y > popupCard.height) {
                root.isOpen = false;
            }
        }
    }

    Item {
        id: popupCard
        width: 320
        height: Math.min(460, Math.max(160, 100 + (devicesList.count * 76)))
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: popupTopMargin
        anchors.rightMargin: root.popupMargin
        z: 1

        Rectangle {
            id: popupBg
            anchors.fill: parent
            radius: DesignTokens.radiusLG
            color: ColorScheme.glassPopup
            border.width: 1
            border.color: ColorScheme.outlineVariant
        }

        // Lightweight drop shadow
        Rectangle {
            anchors.fill: popupBg
            anchors.topMargin: 6
            radius: popupBg.radius
            color: Qt.rgba(0, 0, 0, 0.18)
            z: -1
        }

        Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: DesignTokens.spacingMD
                spacing: DesignTokens.spacingSM

                // ── Header ──────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: DesignTokens.spacingSM

                    Text {
                        text: "\u{f287}"
                        font.family: DesignTokens.fontFamilyMono
                        font.pixelSize: 18
                        color: root.accentColor
                    }

                    Text {
                        text: "Dispositivos USB"
                        font.pixelSize: DesignTokens.fontSizeMD
                        font.bold: true
                        font.family: DesignTokens.fontFamily
                        color: root.textColor
                        Layout.fillWidth: true
                    }

                    // Eject All Button (if multiple devices present)
                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        visible: USBService.deviceCount > 1
                        color: ejectAllMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.red, 0.15) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\u{f052}"
                            font.family: DesignTokens.fontFamilyMono
                            font.pixelSize: 12
                            color: ColorScheme.red
                        }

                        MouseArea {
                            id: ejectAllMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: USBService.ejectAll()
                        }

                        ToolTip.visible: ejectAllMa.containsMouse
                        ToolTip.text: "Ejetar todos os dispositivos"
                        ToolTip.delay: 300
                    }

                    // Refresh button
                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: refreshMa.containsMouse ? ColorScheme.withAlpha(root.textColor, 0.12) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\u{f021}"
                            font.family: DesignTokens.fontFamilyMono
                            font.pixelSize: 12
                            color: root.textColor
                            opacity: refreshMa.containsMouse ? 1.0 : 0.65
                            rotation: USBService.isBusy ? 360 : 0

                            Behavior on rotation {
                                NumberAnimation { duration: 600; loops: Animation.Infinite }
                            }
                        }

                        MouseArea {
                            id: refreshMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: USBService.refresh()
                        }

                        ToolTip.visible: refreshMa.containsMouse
                        ToolTip.text: "Atualizar lista"
                        ToolTip.delay: 300
                    }

                    // Close button
                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: closeMa.containsMouse ? ColorScheme.withAlpha(root.textColor, 0.12) : "transparent"

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

                // ── Devices list ────────────────────────────────────────────
                ListView {
                    id: devicesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: USBService.devices

                    delegate: Rectangle {
                        id: cardItem
                        width: devicesList.width
                        height: 68
                        radius: DesignTokens.radiusMD
                        color: deviceMa.containsMouse ? ColorScheme.glassHover : ColorScheme.glassCard
                        border.width: 1
                        border.color: modelData.mounted ? ColorScheme.withAlpha(root.accentColor, 0.25) : ColorScheme.outlineVariant

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }

                        readonly property bool isBusy: USBService.isDeviceBusy(modelData.name) || USBService.isDeviceBusy(modelData.parentDisk)

                        MouseArea {
                            id: deviceMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: modelData.mounted ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (modelData.mounted && modelData.mountpoint) {
                                    USBService.openInFileManager(modelData.mountpoint);
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            // Device icon badge
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 8
                                color: modelData.mounted ? ColorScheme.withAlpha(root.accentColor, 0.15) : ColorScheme.withAlpha(root.textColor, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.type === "disk" ? "\u{f0a0}" : "\u{f15b}"
                                    font.family: DesignTokens.fontFamilyMono
                                    font.pixelSize: 16
                                    color: modelData.mounted ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.6)
                                }
                            }

                            // Device info & storage meter
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.label || modelData.model || modelData.name
                                    font.pixelSize: DesignTokens.fontSizeSM
                                    font.bold: true
                                    font.family: DesignTokens.fontFamily
                                    color: root.textColor
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: {
                                        var info = modelData.size;
                                        if (modelData.fstype) info += " (" + modelData.fstype + ")";
                                        if (modelData.mounted && modelData.mountpoint) {
                                            info += " \u2022 " + modelData.mountpoint;
                                        } else {
                                            info += " \u2022 [Desmontado]";
                                        }
                                        return info;
                                    }
                                    font.pixelSize: DesignTokens.fontSizeXS
                                    font.family: DesignTokens.fontFamily
                                    color: root.textColor
                                    opacity: 0.65
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                // Mini storage capacity bar (if mounted with percentage)
                                Item {
                                    Layout.fillWidth: true
                                    height: 4
                                    visible: modelData.mounted && modelData.fsusepct !== ""

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 2
                                        color: ColorScheme.withAlpha(root.textColor, 0.1)
                                    }

                                    Rectangle {
                                        height: parent.height
                                        radius: 2
                                        width: {
                                            var pct = parseInt(modelData.fsusepct, 10);
                                            if (isNaN(pct) || pct < 0) return 0;
                                            return Math.min(parent.width, parent.width * (pct / 100.0));
                                        }
                                        color: {
                                            var pct = parseInt(modelData.fsusepct, 10);
                                            if (pct >= 90) return ColorScheme.red;
                                            if (pct >= 75) return ColorScheme.peach;
                                            return root.accentColor;
                                        }
                                    }
                                }
                            }

                            // Action buttons
                            Row {
                                spacing: 6

                                // Mount/Unmount button
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: DesignTokens.radiusSM
                                    color: mountBtnMa.containsMouse ? ColorScheme.glassHover : "transparent"
                                    opacity: cardItem.isBusy ? 0.4 : 1.0

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.mounted ? "\u{f2c2}" : "\u{f2c0}"
                                        font.family: DesignTokens.fontFamilyMono
                                        font.pixelSize: 12
                                        color: modelData.mounted ? root.accentColor : root.textColor
                                        opacity: 0.85
                                    }

                                    MouseArea {
                                        id: mountBtnMa
                                        anchors.fill: parent
                                        enabled: !cardItem.isBusy
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.mounted) {
                                                USBService.unmountDevice(modelData.name);
                                            } else {
                                                USBService.mountDevice(modelData.name);
                                            }
                                        }
                                    }

                                    ToolTip.visible: mountBtnMa.containsMouse
                                    ToolTip.text: modelData.mounted ? "Desmontar partição" : "Montar partição"
                                    ToolTip.delay: 300
                                }

                                // Eject / Power-off button
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: DesignTokens.radiusSM
                                    color: ejectBtnMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.red, 0.18) : "transparent"
                                    opacity: cardItem.isBusy ? 0.4 : 1.0

                                    Text {
                                        anchors.centerIn: parent
                                        text: cardItem.isBusy ? "\u{f021}" : "\u{f052}"
                                        font.family: DesignTokens.fontFamilyMono
                                        font.pixelSize: 12
                                        color: ColorScheme.red
                                    }

                                    MouseArea {
                                        id: ejectBtnMa
                                        anchors.fill: parent
                                        enabled: !cardItem.isBusy
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: USBService.ejectDevice(modelData.name)
                                    }

                                    ToolTip.visible: ejectBtnMa.containsMouse
                                    ToolTip.text: "Ejetar unidade com segurança"
                                    ToolTip.delay: 300
                                }
                            }
                        }
                    }
                }

                // ── Empty state ─────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: USBService.deviceCount === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "\u{f287}"
                            font.family: DesignTokens.fontFamilyMono
                            font.pixelSize: 28
                            color: ColorScheme.withAlpha(root.textColor, 0.25)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Nenhum dispositivo USB conectado"
                            font.pixelSize: DesignTokens.fontSizeSM
                            font.family: DesignTokens.fontFamily
                            color: root.textColor
                            opacity: 0.5
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    // ── Notifications ───────────────────────────────────────────────────────
    Connections {
        target: USBService
        enabled: root.isOpen
        function onEjectSuccess(deviceName) {
            Logger.info("USBPopup", "Device ejected successfully: " + deviceName);
        }
        function onEjectFailed(deviceName, error) {
            Logger.warn("USBPopup", "Failed to eject " + deviceName + ": " + error);
        }
    }
}
