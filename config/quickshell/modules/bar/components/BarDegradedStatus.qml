import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../shared"

Item {
    id: root

    required property bool shellDegraded
    required property bool focusMode
    required property var errorPopup

    visible: root.shellDegraded && !root.focusMode
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: degradedIcon.width + DesignTokens.spacingXS * 2
    implicitHeight: degradedIcon.height + DesignTokens.spacingXS
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: DesignTokens.radiusSM
        color: ColorScheme.withAlpha(ColorScheme.warning || "#f59e0b", 0.15)
    }

    SmartIcon {
        id: degradedIcon
        anchors.centerIn: parent
        source: "dialog-warning-symbolic"
        fallbackIcon: "⚠"
        size: 16
        color: ColorScheme.warning || "#f59e0b"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellController.togglePopup(root, root.errorPopup)
    }
}
