import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../core"
import "../../../shared"
import "../../../services"

/**
 * BarKeyboardLayout - Shows current keyboard layout
 * Click to switch layouts or open layout picker
 */
Item {
    id: root

    required property color accentColor
    required property color textColor
    required property bool anyPopupOpen

    implicitWidth: pill.implicitWidth
    implicitHeight: DesignTokens.barItemHeight

    // Only show if multiple layouts are configured
    visible: KeyboardLayoutService.layoutCount > 1

    PillWidget {
        id: pill
        anchors.fill: parent
        iconColor: root.accentColor

        RowLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: "\u{f11c}" // keyboard icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: root.textColor
                opacity: 0.7
            }

            Text {
                text: KeyboardLayoutService.currentLayoutShort
                font.pixelSize: 11
                font.family: "Inter"
                font.bold: true
                color: root.accentColor
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                KeyboardLayoutService.nextLayout();
            } else if (mouse.button === Qt.RightButton) {
                layoutMenu.popup();
            }
        }
    }

    Menu {
        id: layoutMenu
        
        Repeater {
            model: KeyboardLayoutService.availableLayouts
            
            MenuItem {
                text: modelData.flag + "  " + modelData.name
                checkable: true
                checked: modelData.code === KeyboardLayoutService.currentLayout
                onTriggered: KeyboardLayoutService.switchToLayout(modelData.code)
            }
        }
    }

    // Visual feedback on layout change
    Connections {
        target: KeyboardLayoutService
        function onLayoutChanged(layout) {
            changeAnim.start();
        }
    }

    SequentialAnimation {
        id: changeAnim
        PropertyAnimation { target: pill; property: "scale"; to: 1.1; duration: 100 }
        PropertyAnimation { target: pill; property: "scale"; to: 1.0; duration: 100 }
    }
}
