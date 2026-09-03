import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

PanelWindow {
    id: tooltipWindow

    property string text: ""
    property string extraInfo: ""
    property point globalPos: Qt.point(0, 0)
    property bool showTooltip: false
    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion

    visible: showTooltip && text.length > 0
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { left: true; right: false; top: false; bottom: true }

    implicitWidth: Math.max(tooltipLabel.width, extraLabel.visible ? extraLabel.width : 0) + 16
    implicitHeight: tooltipLabel.height + (extraLabel.visible ? extraLabel.height + 4 : 0) + 10

    margins {
        left: Math.max(0, Math.min(globalPos.x - width / 2, (screen ? screen.width : 1920) - width))
        bottom: 74
    }

    // Shadow
    Rectangle {
        anchors.fill: tooltipCard
        anchors.topMargin: 2
        radius: tooltipCard.radius
        color: Qt.rgba(0, 0, 0, 0.18)
        z: -1
    }

    Rectangle {
        id: tooltipCard
        anchors.fill: parent
        radius: DesignTokens.radiusSM
        color: ColorScheme.glassPopup
        border.width: 1
        border.color: ColorScheme.glassBorder

        opacity: tooltipWindow.showTooltip ? 1.0 : 0.0
        scale: tooltipWindow.showTooltip ? 1.0 : 0.88
        Behavior on opacity {
            enabled: !tooltipWindow.reducedEffects
            NumberAnimation { duration: 120; easing.type: Easing.OutQuint }
        }
        Behavior on scale {
            enabled: !tooltipWindow.reducedEffects
            SpringAnimation { spring: DesignTokens.springBouncy; damping: DesignTokens.dampingBouncy; epsilon: 0.01 }
        }
        transformOrigin: Item.Bottom

        // Inner glow
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 1
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        Text {
            id: tooltipLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 5
            text: tooltipWindow.text
            color: ColorScheme.text
            font.pixelSize: 12
            font.family: Style.fontUI
            font.weight: Font.Medium
        }

        Text {
            id: extraLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: tooltipLabel.bottom
            anchors.topMargin: 2
            visible: tooltipWindow.extraInfo.length > 0
            text: tooltipWindow.extraInfo
            color: ColorScheme.textAlt
            font.pixelSize: 10
            font.family: Style.fontMono
        }
    }
}
