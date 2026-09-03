pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../core"
import "../../../shared"
import "../../dock"

/**
 * BarTaskbar - Compact integrated taskbar / dock for the top bar.
 *
 * Provides a lightweight, high-performance embedded taskbar showing
 * pinned and running applications with instance indicators, audio badges,
 * focus states, and drag-and-drop file opening.
 */
Item {
    id: root

    property var screenData: null
    property bool compact: false
    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.foreground

    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion
    readonly property real itemSize: compact ? 26 : 30
    readonly property var items: DockService.mergedItems

    implicitWidth: taskbarRow.width
    implicitHeight: itemSize

    Row {
        id: taskbarRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: DesignTokens.spacingXS

        Repeater {
            model: root.items

            delegate: Item {
                id: barItemDelegate
                property var itemData: modelData
                property bool isFocused: itemData ? !!itemData.focused : false
                property bool isRunning: itemData ? !!itemData.running : false
                property bool isUrgent: itemData && itemData.appId ? DockService.getUrgent(itemData.appId) : false
                property bool isAudio: itemData ? !!itemData.audioActive : false
                property int instances: itemData ? (itemData.instanceCount || 0) : 0
                property bool dropTarget: false

                width: root.itemSize
                height: root.itemSize

                Rectangle {
                    id: itemBg
                    anchors.fill: parent
                    radius: DesignTokens.radiusSM
                    color: barItemDelegate.dropTarget
                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.25)
                        : (barItemDelegate.isFocused
                            ? ColorScheme.withAlpha(ColorScheme.accent, 0.18)
                            : (barItemMouse.containsMouse
                                ? ColorScheme.stateHover
                                : (barItemDelegate.isRunning ? ColorScheme.withAlpha(ColorScheme.surface, 0.35) : "transparent")))
                    border.width: barItemDelegate.dropTarget ? 1.5 : (barItemDelegate.isUrgent ? 1.5 : (barItemDelegate.isFocused ? 1 : 0))
                    border.color: barItemDelegate.dropTarget ? ColorScheme.accent : (barItemDelegate.isUrgent ? ColorScheme.red : ColorScheme.withAlpha(ColorScheme.accent, 0.4))

                    Behavior on color {
                        enabled: !root.reducedEffects
                        ColorAnimation { duration: DesignTokens.durationFast }
                    }
                    Behavior on border.color {
                        enabled: !root.reducedEffects
                        ColorAnimation { duration: DesignTokens.durationFast }
                    }

                    // App icon
                    SmartIcon {
                        id: appIcon
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: barItemDelegate.isRunning ? -1 : 0
                        size: root.itemSize * 0.68
                        source: barItemDelegate.itemData ? (barItemDelegate.itemData.icon || barItemDelegate.itemData.appId || "") : ""
                        label: barItemDelegate.itemData ? (barItemDelegate.itemData.name || "") : ""
                        opacity: (barItemDelegate.itemData && barItemDelegate.itemData.minimizedAll) ? 0.45 : 1.0
                    }

                    // Audio indicator
                    Rectangle {
                        visible: barItemDelegate.isAudio && !barItemDelegate.isUrgent
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 1
                        anchors.rightMargin: 1
                        width: 8; height: 8; radius: 4
                        color: ColorScheme.base00
                        border.width: 1; border.color: ColorScheme.accent

                        Text {
                            anchors.centerIn: parent
                            text: "\u{f028}"
                            font.family: Style.fontMono
                            font.pixelSize: 5
                            color: ColorScheme.accent
                        }
                    }

                    // Urgent badge
                    Rectangle {
                        visible: barItemDelegate.isUrgent
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 1
                        anchors.rightMargin: 1
                        width: 8; height: 8; radius: 4
                        color: ColorScheme.red
                    }

                    // Running dot / pill indicator
                    Rectangle {
                        visible: barItemDelegate.isRunning
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        width: barItemDelegate.isFocused ? 10 : (barItemDelegate.instances > 1 ? 5 : 3)
                        height: 2
                        radius: 1
                        color: barItemDelegate.isFocused
                            ? ColorScheme.accent
                            : (barItemDelegate.isUrgent
                                ? ColorScheme.red
                                : ColorScheme.withAlpha(ColorScheme.text, 0.60))

                        Behavior on width {
                            enabled: !root.reducedEffects
                            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                        }
                    }
                }

                DropArea {
                    anchors.fill: parent
                    onEntered: function(drag) {
                        barItemDelegate.dropTarget = true;
                        drag.accepted = true;
                    }
                    onExited: {
                        barItemDelegate.dropTarget = false;
                    }
                    onDropped: function(drop) {
                        barItemDelegate.dropTarget = false;
                        if (drop.hasUrls) {
                            var urls = [];
                            for (var i = 0; i < drop.urls.length; i++) {
                                urls.push(drop.urls[i].toString().replace(/^file:\/\//, ""));
                            }
                            if (urls.length > 0) {
                                DockService.launchWithFiles(barItemDelegate.itemData, urls);
                            }
                            drop.acceptProposedAction();
                        }
                    }
                }

                MouseArea {
                    id: barItemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: function(mouse) {
                        if (!barItemDelegate.itemData) return;
                        if (mouse.button === Qt.LeftButton) {
                            DockService.launchOrFocus(barItemDelegate.itemData);
                        } else if (mouse.button === Qt.MiddleButton) {
                            DockService.launchNewInstance(barItemDelegate.itemData);
                        }
                    }

                    onWheel: function(wheel) {
                        if (!barItemDelegate.itemData) return;
                        if (barItemDelegate.isAudio) {
                            DockService.adjustAppVolumes(barItemDelegate.itemData.appId, wheel.angleDelta.y > 0 ? "5%+" : "5%-");
                        } else {
                            DockService.focusNextInstance(barItemDelegate.itemData.appId, wheel.angleDelta.y > 0 ? -1 : 1);
                        }
                    }
                }
            }
        }
    }
}
