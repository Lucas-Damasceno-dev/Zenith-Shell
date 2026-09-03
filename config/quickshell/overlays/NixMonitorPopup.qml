import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../services"

/**
 * NixMonitorPopup - Detailed NixOS system information popup.
 */
PopupWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    showScrim: false
    glassRadius: 0
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0

    property color accentColor: ColorScheme.accent
    property color bgColor: ColorScheme.withAlpha(ColorScheme.background, 0.72)
    property color textColor: ColorScheme.text
    property real popupMargin: DesignTokens.spacingLG
    readonly property string diskRootValue: {
        var value = String(SystemMetricsService.diskRootUsage || "").trim();
        return value !== "" ? value : "--";
    }
    readonly property string diskHomeValue: {
        var value = String(SystemMetricsService.diskHomeUsage || "").trim();
        return value !== "" ? value : "--";
    }
    originY: 0.0
    slideX: -12
    slideY: 12

    // Refresh on open
    onIsOpenChanged: {
        if (isOpen) {
            SystemMetricsService.refreshNow();
            NixMonitorService.refresh(true);
            NixMonitorService.checkGCReclaimable();
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: (mouse) => {
            var p = mapToItem(container, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > container.width || p.y > container.height) {
                root.isOpen = false;
            }
        }
    }

    Item {
        id: container
        width: 320
        height: contentLayout.implicitHeight + 36
        anchors.top: parent.top
        anchors.topMargin: popupTopMargin
        x: Math.max(
            root.popupMargin,
            root.width - width - root.popupMargin
        )
        z: 1

        scale: root.isOpen ? 1.0 : 0.92
        opacity: root.isOpen ? 1.0 : 0.0
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.48; epsilon: 0.005 } }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        transformOrigin: Item.Top

        Rectangle {
            id: card
            anchors.fill: parent
            color: root.bgColor
            radius: 18
            border.color: ColorScheme.glassBorder
            border.width: 1

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1; radius: 18
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }

        // Shadow
        Rectangle {
            anchors.fill: card
            anchors.topMargin: 6
            radius: card.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: -1
        }

        ColumnLayout {
            id: contentLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 40; height: 40; radius: 12
                    color: ColorScheme.withAlpha(ColorScheme.blue, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f313}"  // Nix icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 20
                        color: ColorScheme.blue
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "NixOS Monitor"
                        color: root.textColor
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "Inter"
                    }

                    Text {
                        text: NixMonitorService.daemonRunning ? "Daemon running" : "Daemon offline"
                        color: NixMonitorService.daemonRunning ? ColorScheme.green : ColorScheme.red
                        font.pixelSize: 10
                        font.family: "Inter"
                    }
                }

                // Refresh button
                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: refreshMa.containsMouse ? ColorScheme.glassHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f021}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: ColorScheme.withAlpha(root.textColor, 0.6)
                        rotation: refreshAnim.running ? refreshAnim.angle : 0

                        NumberAnimation on rotation {
                            id: refreshAnim
                            running: false
                            from: 0; to: 360
                            duration: 1000
                            loops: 1
                        }
                    }

                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            refreshAnim.start();
                            NixMonitorService.refresh(true);
                            NixMonitorService.checkGCReclaimable();
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: ColorScheme.withAlpha(root.textColor, 0.08)
            }

            // Stats grid
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 12
                columnSpacing: 16

                // Store Size
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Store Size"
                        color: ColorScheme.withAlpha(root.textColor, 0.5)
                        font.pixelSize: 9
                        font.family: "Inter"
                        font.letterSpacing: 0.5
                    }
                    Text {
                        text: NixMonitorService.storeSize
                        color: root.textColor
                        font.pixelSize: 16
                        font.bold: true
                        font.family: DesignTokens.fontFamilyMono
                    }
                }

                // Store Paths
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Store Paths"
                        color: ColorScheme.withAlpha(root.textColor, 0.5)
                        font.pixelSize: 9
                        font.family: "Inter"
                        font.letterSpacing: 0.5
                    }
                    Text {
                        text: NixMonitorService.storePathCount.toLocaleString()
                        color: root.textColor
                        font.pixelSize: 16
                        font.bold: true
                        font.family: DesignTokens.fontFamilyMono
                    }
                }

                // Current Generation
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Generation"
                        color: ColorScheme.withAlpha(root.textColor, 0.5)
                        font.pixelSize: 9
                        font.family: "Inter"
                        font.letterSpacing: 0.5
                    }
                    RowLayout {
                        spacing: 6
                        Text {
                            text: "#" + NixMonitorService.currentGeneration
                            color: ColorScheme.blue
                            font.pixelSize: 16
                            font.bold: true
                            font.family: DesignTokens.fontFamilyMono
                        }
                        Text {
                            visible: NixMonitorService.currentGenerationDate !== ""
                            text: NixMonitorService.currentGenerationDate
                            color: ColorScheme.withAlpha(root.textColor, 0.4)
                            font.pixelSize: 10
                            font.family: "Inter"
                        }
                    }
                }

                // GC Reclaimable
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "GC Reclaimable"
                        color: ColorScheme.withAlpha(root.textColor, 0.5)
                        font.pixelSize: 9
                        font.family: "Inter"
                        font.letterSpacing: 0.5
                    }
                    Text {
                        text: NixMonitorService.gcReclaimable
                        color: NixMonitorService.gcReclaimable === "Clean" ? ColorScheme.green : ColorScheme.peach
                        font.pixelSize: 16
                        font.bold: true
                        font.family: DesignTokens.fontFamilyMono
                    }
                }

                // Disk /
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Disk /"
                        color: ColorScheme.withAlpha(root.textColor, 0.5)
                        font.pixelSize: 9
                        font.family: "Inter"
                        font.letterSpacing: 0.5
                    }
                    Text {
                        text: root.diskRootValue
                        color: root.textColor
                        font.pixelSize: 11
                        font.bold: true
                        font.family: DesignTokens.fontFamilyMono
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                // Disk /home
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Disk /home"
                        color: ColorScheme.withAlpha(root.textColor, 0.5)
                        font.pixelSize: 9
                        font.family: "Inter"
                        font.letterSpacing: 0.5
                    }
                    Text {
                        text: root.diskHomeValue
                        color: root.textColor
                        font.pixelSize: 11
                        font.bold: true
                        font.family: DesignTokens.fontFamilyMono
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: ColorScheme.withAlpha(root.textColor, 0.08)
            }

            // Quick Actions
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Garbage Collect button
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 10
                    color: gcBtnMa.containsMouse 
                        ? ColorScheme.withAlpha(ColorScheme.peach, 0.25) 
                        : ColorScheme.withAlpha(ColorScheme.surface, 0.3)
                    opacity: NixMonitorService.gcRunning ? 0.5 : 1.0

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: NixMonitorService.gcRunning ? "\u{f110}" : "\u{f1f8}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: ColorScheme.peach

                            RotationAnimation on rotation {
                                running: NixMonitorService.gcRunning
                                from: 0; to: 360
                                duration: 1000
                                loops: Animation.Infinite
                            }
                        }

                        Text {
                            text: NixMonitorService.gcRunning ? "Cleaning..." : "Garbage Collect"
                            color: ColorScheme.peach
                            font.pixelSize: 11
                            font.family: "Inter"
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: gcBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: NixMonitorService.gcRunning ? Qt.BusyCursor : Qt.PointingHandCursor
                        enabled: !NixMonitorService.gcRunning
                        onClicked: NixMonitorService.runGarbageCollection()
                    }
                }

                // Open store button
                Rectangle {
                    width: 36
                    height: 36
                    radius: 10
                    color: storeBtnMa.containsMouse 
                        ? ColorScheme.withAlpha(ColorScheme.blue, 0.25) 
                        : ColorScheme.withAlpha(ColorScheme.surface, 0.3)

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f07b}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: ColorScheme.blue
                    }

                    MouseArea {
                        id: storeBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            openStoreProc.exec(["xdg-open", "/nix/store"]);
                            root.isOpen = false;
                        }
                    }

                    TimedProcess { id: openStoreProc }
                }
            }

            // System info footer
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "NixOS · " + NixMonitorService.totalGenerations + " generations"
                color: ColorScheme.withAlpha(root.textColor, 0.35)
                font.pixelSize: 9
                font.family: "Inter"
            }
        }
    }
}
