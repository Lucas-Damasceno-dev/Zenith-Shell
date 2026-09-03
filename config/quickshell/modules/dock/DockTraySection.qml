import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../core"
import "../../core/TrayIconUtils.js" as TrayIconUtils

/**
 * DockTraySection — System tray that participates in magnification.
 */
Item {
    id: root

    property real baseSize: 48
    property bool expanded: false
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

    property var blacklistedTrayIds: ["nm-applet", "networkmanager"]
    property var blacklistedTrayTitles: ["network", "wi-fi"]

    readonly property bool hasItems: {
        var items = SystemTray.items;
        if (!items) return false;
        for (var i = 0; i < items.count; i++) {
            if (shouldShowItem(items.objectAt(i))) return true;
        }
        return false;
    }

    width: toggleBtn.width + (expanded ? expandedContent.width + 4 * magnification : 0)
    height: displaySize

    function shouldShowItem(item) {
        if (!item) return false;
        var id = String(item.id || "").toLowerCase();
        var title = String(item.title || item.tooltipTitle || "").toLowerCase();
        
        for (var i = 0; i < root.blacklistedTrayIds.length; i++) {
            if (id.indexOf(root.blacklistedTrayIds[i]) >= 0) return false;
        }
        for (var j = 0; j < root.blacklistedTrayTitles.length; j++) {
            if (title.indexOf(root.blacklistedTrayTitles[j]) >= 0) return false;
        }
        return true;
    }

    function activateItem(item) {
        if (item && typeof item.activate === "function") item.activate();
    }

    // Toggle arrow
    Item {
        id: toggleBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: displaySize * 0.55
        height: displaySize

        Rectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -root.riseOffset
            width: root.displaySize * 0.5
            height: root.displaySize * 0.7
            radius: 10 * magnification
            color: toggleMouse.containsMouse
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
            text: root.expanded ? "\u{f053}" : "\u{f054}"
            color: ColorScheme.overlay
            font.pixelSize: root.displaySize * 0.3
            font.family: Style.fontMono
            opacity: toggleMouse.containsMouse ? 1.0 : 0.6
            Behavior on opacity {
                enabled: !root.reducedEffects
                NumberAnimation { duration: 120 }
            }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    // Tray items
    Row {
        id: expandedContent
        anchors.right: toggleBtn.left
        anchors.rightMargin: 4 * magnification
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2 * magnification
        clip: true
        width: root.expanded ? implicitWidth : 0
        Behavior on width {
            enabled: !root.reducedEffects
            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayDelegate
                readonly property bool trayVisible: root.shouldShowItem(modelData)
                property string primaryIconSource: TrayIconUtils.primaryIconSource(modelData)
                property string fallbackIconSource: TrayIconUtils.fallbackSource(modelData)
                property string fallbackGlyph: TrayIconUtils.fallbackGlyph(modelData)
                property bool useFallbackIcon: false
                property bool iconLoadFailed: false

                onPrimaryIconSourceChanged: {
                    useFallbackIcon = primaryIconSource === "";
                    iconLoadFailed = false;
                }

                width: trayVisible && root.expanded ? root.displaySize * 0.75 : 0
                height: root.displaySize * 0.75
                visible: trayVisible && root.expanded
                transformOrigin: Item.Center

                Component.onCompleted: useFallbackIcon = primaryIconSource === ""

                QsMenuAnchor {
                    id: trayContextMenu
                    menu: modelData && modelData.hasMenu ? modelData.menu : null
                    anchor.item: parent
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.verticalCenterOffset: -root.riseOffset
                    radius: 10 * magnification
                    color: trayMouse.containsMouse
                        ? ColorScheme.withAlpha(ColorScheme.surface, 0.35)
                        : "transparent"
                    Behavior on color {
                        enabled: !root.reducedEffects
                        ColorAnimation { duration: 120 }
                    }
                }

                Image {
                    id: trayIcon
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -root.riseOffset
                    width: parent.width * 0.62
                    height: parent.height * 0.62
                    source: trayDelegate.useFallbackIcon ? trayDelegate.fallbackIconSource : trayDelegate.primaryIconSource
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: Math.max(24, width * 2)
                    sourceSize.height: Math.max(24, height * 2)
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    visible: status === Image.Ready
                    opacity: trayMouse.containsMouse ? 1.0 : 0.84
                    Behavior on opacity {
                        enabled: !root.reducedEffects
                        NumberAnimation { duration: 150 }
                    }

                    onStatusChanged: {
                        if (status === Image.Ready) {
                            trayDelegate.iconLoadFailed = false;
                            return;
                        }

                        if (status === Image.Error) {
                            if (!trayDelegate.useFallbackIcon
                                    && trayDelegate.fallbackIconSource !== ""
                                    && trayDelegate.fallbackIconSource !== trayDelegate.primaryIconSource) {
                                trayDelegate.useFallbackIcon = true;
                                trayDelegate.iconLoadFailed = false;
                            } else {
                                trayDelegate.iconLoadFailed = true;
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -root.riseOffset
                    visible: trayDelegate.iconLoadFailed
                    text: trayDelegate.fallbackGlyph
                    color: ColorScheme.overlay
                    font.family: DesignTokens.fontFamilyMono
                    font.pixelSize: Math.max(10, parent.height * 0.44)
                    renderType: Text.NativeRendering
                    opacity: trayMouse.containsMouse ? 1.0 : 0.84
                    Behavior on opacity {
                        enabled: !root.reducedEffects
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }

                scale: trayMouse.pressed ? DesignTokens.pressedScale : 1.0
                Behavior on scale {
                    enabled: !root.reducedEffects
                    SpringAnimation { spring: DesignTokens.springSnappy; damping: DesignTokens.dampingSnappy; epsilon: 0.01 }
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: function(mouse) {
                        if (!modelData) return;
                        if (mouse.button === Qt.RightButton) {
                            if (modelData.hasMenu) trayContextMenu.open();
                            else modelData.secondaryActivate();
                        } else {
                            root.activateItem(modelData);
                        }
                    }
                }
            }
        }
    }
}
