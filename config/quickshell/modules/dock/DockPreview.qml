import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../core"
import "../../core/TrayIconUtils.js" as TrayIconUtils

PanelWindow {
    id: previewWindow

    property var itemData: null
    property point globalPos: Qt.point(0, 0)
    property bool showPreview: false
    property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion
    readonly property bool previewContentReady: showPreview && itemData !== null && itemData.running

    visible: showPreview && itemData !== null && itemData.running
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { left: false; right: false; top: false; bottom: false }

    implicitWidth: previewContentLoader.item ? previewContentLoader.item.implicitWidth : 16
    implicitHeight: previewContentLoader.item ? previewContentLoader.item.implicitHeight : 16

    margins {
        left: Math.max(0, Math.min(globalPos.x - width / 2, (screen ? screen.width : 1920) - width))
        bottom: 76
    }
    // Hide when mouse leaves
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onContainsMouseChanged: {
            if (!containsMouse) {
                hidePreviewTimer.restart();
            } else {
                hidePreviewTimer.stop();
            }
        }
    }

    Timer {
        id: hidePreviewTimer
        interval: 300
        onTriggered: previewWindow.showPreview = false
    }

    Loader {
        id: previewContentLoader
        active: previewWindow.previewContentReady
        asynchronous: false
        sourceComponent: Item {
            id: previewBody
            width: implicitWidth
            height: implicitHeight
            implicitWidth: previewContent.width + 16
            implicitHeight: previewContent.height + 16

            // Shadow behind card
            Rectangle {
                anchors.fill: previewCard
                anchors.topMargin: 4
                radius: previewCard.radius
                color: Qt.rgba(0, 0, 0, 0.18)
                z: -1
            }

            Rectangle {
                id: previewCard
                anchors.fill: parent
                radius: DesignTokens.radiusMD
                color: ColorScheme.glassPopup
                border.width: 1
                border.color: ColorScheme.glassBorder

                opacity: previewWindow.showPreview ? 1.0 : 0.0
                scale: previewWindow.showPreview ? 1.0 : 0.90
                Behavior on opacity {
                    enabled: !previewWindow.reducedEffects
                    NumberAnimation { duration: 160; easing.type: Easing.OutQuint }
                }
                Behavior on scale {
                    enabled: !previewWindow.reducedEffects
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
                transformOrigin: Item.Bottom

                // Top highlight
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: 1
                    radius: parent.radius
                    color: Qt.rgba(1, 1, 1, 0.05)
                }

                Column {
                    id: previewContent
                    anchors.centerIn: parent
                    spacing: 6
                    width: 240

                    // App name header
                    Text {
                        width: parent.width
                        text: {
                            if (!previewWindow.itemData) return "";
                            return previewWindow.itemData.name || previewWindow.itemData.appId || "";
                        }
                        color: ColorScheme.text
                        font.pixelSize: 12
                        font.family: Style.fontUI
                        font.weight: Font.DemiBold
                        font.letterSpacing: DesignTokens.letterSpacingLabel
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Preview for each toplevel window
                    Flow {
                        width: 240
                        spacing: 8
                        Repeater {
                            model: previewWindow.itemData ? (previewWindow.itemData.toplevels || []) : []

                            delegate: Rectangle {
                                readonly property bool isWindowFocused: {
                                    var active = Hyprland.activeToplevel;
                                    return active && active.lastIpcObject && modelData.lastIpcObject && active.lastIpcObject.address === modelData.lastIpcObject.address;
                                }
                                readonly property bool isMinimized: modelData.workspace && modelData.workspace.id < 0

                                width: 240
                                height: 100
                                radius: DesignTokens.radiusSM
                                color: previewMouseArea.containsMouse
                                    ? ColorScheme.stateHover
                                    : isWindowFocused ? ColorScheme.withAlpha(ColorScheme.accent, 0.12) : ColorScheme.withAlpha(ColorScheme.foreground, 0.04)
                                border.width: isWindowFocused ? 1 : 0
                                border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.3)
                                clip: true

                                Behavior on color { ColorAnimation { duration: DesignTokens.durationNormal } }

                                scale: previewMouseArea.containsMouse ? 1.02 : 1.0
                                Behavior on scale {
                                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                }

                                // Icon and Title centered (placeholder for future wlr-screencopy thumbnails)
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    visible: !_thumbnailLoader.active || _thumbnailLoader.status !== Image.Ready

                                    property var iconHints: ({
                                        icon: previewWindow.itemData ? (previewWindow.itemData.icon || previewWindow.itemData.appId || "") : "",
                                        id: previewWindow.itemData ? (previewWindow.itemData.appId || "") : "",
                                        title: modelData ? (modelData.title || "") : ""
                                    })

                                        Image {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 42; height: 42
                                            property string primaryIconSource: TrayIconUtils.primaryIconSource(parent.iconHints)
                                            property string fallbackIconSource: TrayIconUtils.fallbackSource(parent.iconHints)
                                            source: primaryIconSource !== "" ? primaryIconSource : fallbackIconSource
                                            sourceSize: Qt.size(64, 64)
                                            fillMode: Image.PreserveAspectFit
                                            opacity: isMinimized ? 0.5 : 0.9
                                            onStatusChanged: {
                                                if (status === Image.Error && source !== fallbackIconSource)
                                                    source = fallbackIconSource;
                                            }
                                        }

                                    Text {
                                        text: modelData ? (modelData.title || "Window") : "Window"
                                        color: ColorScheme.text
                                        font.pixelSize: 10
                                        font.family: Style.fontUI
                                        font.weight: Font.Medium
                                        width: 220
                                        elide: Text.ElideMiddle
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                // Lazy thumbnail loader — future wlr-screencopy integration
                                Image {
                                    id: _thumbnailLoader
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    sourceSize.width: Math.max(64, width * 2)
                                    sourceSize.height: Math.max(64, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: false
                                    visible: active && status === Image.Ready
                                    property bool active: false
                                }

                                // Close button
                                Rectangle {
                                    id: closeBtn
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    width: 22; height: 22; radius: 11
                                    color: closeBtnMouse.containsMouse ? ColorScheme.withAlpha(ColorScheme.red, 0.8) : ColorScheme.withAlpha(ColorScheme.surface, 0.4)
                                    border.width: 1
                                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.1)
                            
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u{f00d}"
                                        font.family: Style.fontMono
                                        font.pixelSize: 10
                                        color: ColorScheme.text
                                    }

                                    MouseArea {
                                        id: closeBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (modelData && modelData.lastIpcObject) {
                                                Hyprland.dispatch("closewindow address:" + modelData.lastIpcObject.address);
                                            }
                                        }
                                    }
                                }

                                // Click to focus this window
                                MouseArea {
                                    id: previewMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    z: -1
                                    onClicked: {
                                        if (modelData && modelData.lastIpcObject) {
                                            var addr = modelData.lastIpcObject.address;
                                            var wsId = modelData.workspace ? modelData.workspace.id : 0;
                                            if (wsId < 0) {
                                                var currentWs = Hyprland.focusedWorkspace;
                                                var targetWs = currentWs ? String(currentWs.id) : "1";
                                                Hyprland.dispatch("movetoworkspacesilent " + targetWs + ",address:" + addr);
                                            }
                                            Hyprland.dispatch("focuswindow address:" + addr);
                                            previewWindow.showPreview = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

    }
}
