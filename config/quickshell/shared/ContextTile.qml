import QtQuick
import Quickshell
import "../core"
Item {
    id: root
    width: 30
    height: 30

    required property var popupInstance
    required property color accentColor
    required property bool anyPopupOpen
    required property var contextData
    
    property bool _hover: false

    function _arrayOrEmpty(value) {
        if (!value || value.length === undefined) return [];
        return value;
    }

    function _serviceHasIssue() {
        var rows = _arrayOrEmpty(contextData.services);
        for (var i = 0; i < rows.length; i++) {
            var state = String(rows[i].state || "").toLowerCase();
            if (state !== "" && state !== "active" && state !== "running") return true;
        }
        return false;
    }

    readonly property bool hasIssues: _arrayOrEmpty(contextData.issues).length > 0 || _serviceHasIssue()
    readonly property string currentIcon: {
        var icon = String(contextData.icon || "").trim();
        return icon !== "" ? icon : "\uf120";
    }

    Rectangle {
        anchors.fill: parent
        radius: DesignTokens.radiusSM
        readonly property bool isOpen: ShellController.isPopupOpen(root.popupInstance)
        color: (isOpen || (root._hover && !root.anyPopupOpen))
            ? ColorScheme.withAlpha(root.hasIssues ? ColorScheme.red : root.accentColor, 0.20)
            : "transparent"
        border.width: 1
        border.color: isOpen
            ? ColorScheme.withAlpha(root.hasIssues ? ColorScheme.red : root.accentColor, DesignTokens.activeBorderOpacity)
            : (root._hover
                ? ColorScheme.withAlpha(ColorScheme.foreground, DesignTokens.hoverBorderOpacity)
                : ColorScheme.glassBorder)
        
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Text {
            id: ctxIcon
            anchors.centerIn: parent
            text: root.currentIcon
            color: root.hasIssues
                ? ColorScheme.red
                : root.accentColor
            font.family: DesignTokens.fontFamilyMono
            font.pixelSize: DesignTokens.iconSizeSM
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Error indicator dot
        Rectangle {
            visible: root.hasIssues
            width: 6
            height: 6
            radius: 3
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 3
            anchors.rightMargin: 3
            color: ColorScheme.red
        }
    }

    scale: root._hover ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root._hover = true
        onExited:  root._hover = false
        onClicked: {
            root._hover = false;
            if (root.popupInstance) {
                ShellController.togglePopup(root, root.popupInstance);
            }
        }
    }
}
