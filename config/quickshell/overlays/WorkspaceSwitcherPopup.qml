import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core"

PopupWindow {
    id: root

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    showScrim: false
    glassRadius: 0
    glassBackground: "transparent"
    glassBorderWidth: 0
    slideY: 8
    originX: 0.5
    originY: 0.5
    layerNamespace: "quickshell-workspace-switcher"

    onIsOpenChanged: {
        if (!isOpen)
            return;

        root.requestActivate();
        selectedIndex = getActiveWorkspaceIndex();
        keyboardGrab.forceActiveFocus();
    }

    function getActiveWorkspaceIndex() {
        if (!Hyprland.focusedWorkspace)
            return 0;

        var activeId = Hyprland.focusedWorkspace.id;
        for (var i = 0; i < workspacesModel.length; i++) {
            if (workspacesModel[i] === activeId)
                return i;
        }

        return 0;
    }

    property var workspacesModel: {
        if (!root.isOpen)
            return [1];
        var wsIds = [];
        if (!Hyprland.workspaces || !Hyprland.workspaces.values)
            return [1, 2, 3, 4, 5];

        var vals = Hyprland.workspaces.values;
        for (var i = 0; i < vals.length; i++) {
            if (vals[i].id > 0)
                wsIds.push(vals[i].id);
        }

        wsIds.sort(function(a, b) {
            return a - b;
        });

        if (wsIds.length === 0)
            return [1];

        return wsIds;
    }

    property int selectedIndex: 0

    function confirmSelection() {
        if (workspacesModel.length > selectedIndex) {
            var wsId = workspacesModel[selectedIndex];
            Hyprland.dispatch("workspace " + wsId);
        }

        isOpen = false;
    }

    function cycleNext() {
        selectedIndex = (selectedIndex + 1) % workspacesModel.length;
    }

    function cyclePrev() {
        selectedIndex = (selectedIndex - 1 + workspacesModel.length) % workspacesModel.length;
    }

    function getIconsForWorkspace(wsId) {
        if (!root.isOpen)
            return [];
        var icons = [];
        if (!Hyprland.toplevels || !Hyprland.toplevels.values)
            return icons;

        var tpls = Hyprland.toplevels.values;
        for (var i = 0; i < tpls.length; i++) {
            var win = tpls[i];
            if (win && win.workspace && win.workspace.id === wsId) {
                var appId = String(win.appId || "").toLowerCase();
                var iconName = "image://icon/nix-snowflake";
                if (appId !== "") {
                    var entry = (DesktopEntries.byId ? (DesktopEntries.byId(appId) || DesktopEntries.byId(win.appId)) : null);
                    if (entry && entry.icon) {
                        iconName = "image://icon/" + entry.icon;
                    } else {
                        iconName = "image://icon/" + appId;
                    }
                }
                icons.push(iconName);
            }
        }
        return icons;
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        onClicked: root.isOpen = false
    }

    Item {
        id: keyboardGrab
        anchors.fill: parent
        focus: root.isOpen

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Tab) {
                if (event.modifiers & Qt.ShiftModifier)
                    cyclePrev();
                else
                    cycleNext();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                isOpen = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                confirmSelection();
                event.accepted = true;
            }
        }

        Keys.onReleased: function(event) {
            if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) {
                confirmSelection();
                event.accepted = true;
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, workspacesModel.length * 200 + 80)
        height: 320
        radius: DesignTokens.radiusXL
        color: ColorScheme.glassPopup
        border.color: ColorScheme.glassBorder
        border.width: 1

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.20)
            z: -1
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 1
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.05)
        }

        Text {
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Workspaces"
            color: ColorScheme.withAlpha(ColorScheme.foreground, 0.5)
            font.pixelSize: 11
            font.weight: Font.Medium
            font.family: "Inter"
            font.letterSpacing: DesignTokens.letterSpacingCaps
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Tab ↹ navegar  ·  Enter ↵ confirmar  ·  Esc cancelar"
            color: ColorScheme.withAlpha(ColorScheme.foreground, 0.30)
            font.pixelSize: 10
            font.family: "Inter"
        }

        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 4
            spacing: 16

            Repeater {
                model: workspacesModel

                delegate: Rectangle {
                    id: wsTile
                    width: 180
                    height: 220
                    radius: DesignTokens.radiusMD
                    color: root.selectedIndex === index
                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.12)
                        : ColorScheme.withAlpha(ColorScheme.foreground, 0.03)

                    border.color: root.selectedIndex === index
                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.6)
                        : ColorScheme.withAlpha(ColorScheme.foreground, 0.06)
                    border.width: root.selectedIndex === index ? 2 : 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on border.width { NumberAnimation { duration: 100 } }

                    scale: root.selectedIndex === index ? 1.03 : (wsTileMa.containsMouse ? 1.01 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 3
                        radius: parent.radius
                        color: Qt.rgba(0, 0, 0, root.selectedIndex === index ? 0.12 : 0.05)
                        z: -1
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData
                        color: root.selectedIndex === index
                            ? ColorScheme.accent
                            : ColorScheme.withAlpha(ColorScheme.foreground, 0.6)
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        font.family: "Inter"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    readonly property var wsIcons: root.getIconsForWorkspace(modelData)

                    Flow {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 16
                        width: parent.width - 32
                        spacing: 10

                        Repeater {
                            model: wsTile.wsIcons

                            delegate: Image {
                                width: 44
                                height: 44
                                source: modelData
                                sourceSize: Qt.size(48, 48)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true

                                onStatusChanged: {
                                    if (status === Image.Error && source !== "image://icon/nix-snowflake")
                                        source = "image://icon/nix-snowflake";
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 16
                        visible: wsTile.wsIcons.length === 0
                        text: "\u{f7d9}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 28
                        color: ColorScheme.withAlpha(ColorScheme.foreground, 0.12)
                    }

                    MouseArea {
                        id: wsTileMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = index;
                            confirmSelection();
                        }
                    }
                }
            }
        }
    }
}
