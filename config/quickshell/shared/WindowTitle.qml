pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../core"
import "../shared"

/**
 * WindowTitle - Focused window indicator with icon, title, and workspace badge.
 *
 * Shows the currently focused window's app icon (via SmartIcon), truncated title,
 * and a small workspace number badge. Smooth morph animations on transitions.
 */
Item {
    id: root

    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.foreground

    implicitWidth: 400
    implicitHeight: parent.height

    readonly property var focusedClient: Hyprland.activeToplevel
    readonly property string clientClass: {
        if (!focusedClient) return "";
        if (focusedClient.waylandSurface && focusedClient.waylandSurface.appId)
            return String(focusedClient.waylandSurface.appId || "");
        if (focusedClient.lastIpcObject && focusedClient.lastIpcObject["class"])
            return String(focusedClient.lastIpcObject["class"] || "");
        return "";
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 8
        opacity: root.focusedClient ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // ── Workspace badge ──
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 20; height: 16
            radius: 5
            color: ColorScheme.withAlpha(root.accentColor, 0.15)
            visible: !!(root.focusedClient && root.focusedClient.workspace)

            Text {
                anchors.centerIn: parent
                text: (root.focusedClient && root.focusedClient.workspace)
                    ? root.focusedClient.workspace.id : ""
                color: root.accentColor
                font.pixelSize: 9
                font.bold: true
                font.family: "Inter"
            }
        }

        // ── App Icon (SmartIcon) ──
        SmartIcon {
            Layout.alignment: Qt.AlignVCenter
            size: 16
            sourceSize: 32
            source: root.clientClass
            label: root.clientClass
            color: root.accentColor
        }

        // ── Separator dot ──
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 3; height: 3; radius: 1.5
            color: ColorScheme.withAlpha(root.textColor, 0.25)
        }

        // ── Window Title ──
        Text {
            id: titleText
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 280

            text: root.focusedClient ? (root.focusedClient.title || "") : ""
            color: ColorScheme.withAlpha(root.textColor, 0.7)
            font.pixelSize: 12
            font.family: "Inter"
            elide: Text.ElideRight

            onTextChanged: titleFadeAnim.restart()

            NumberAnimation {
                id: titleFadeAnim
                target: titleText
                property: "opacity"
                from: 0.35
                to: 1.0
                duration: 120
                easing.type: Easing.OutQuad
            }
        }
    }
}
