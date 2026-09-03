import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../shared"
import "../../../services"

/**
 * BarQuickNotes - Quick notes widget for the bar
 * Shows note count and opens popup for note management
 */
Item {
    id: root

    required property color accentColor
    required property color textColor
    required property var popupInstance
    required property bool anyPopupOpen
    property int openTabIndex: 4

    implicitWidth: pill.implicitWidth
    implicitHeight: DesignTokens.barItemHeight

    PillWidget {
        id: pill
        anchors.fill: parent
        iconColor: root.accentColor
        checked: ShellController.isPopupOpen(root.popupInstance)
        popupOpen: checked
        anyPopupOpen: root.anyPopupOpen

        RowLayout {
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: "\u{f249}" // sticky note icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: root.accentColor
                opacity: 0.9
            }

            Text {
                text: QuickNotesService.noteCount > 0 ? QuickNotesService.noteCount.toString() : ""
                font.pixelSize: 11
                font.family: "Inter"
                font.bold: true
                color: root.accentColor
                visible: QuickNotesService.noteCount > 0
            }
        }

        onClicked: {
            var isOpen = ShellController.isPopupOpen(root.popupInstance);
            if (!isOpen && root.popupInstance && root.openTabIndex >= 0 && root.popupInstance.pendingOpenOptions !== undefined)
                root.popupInstance.pendingOpenOptions = { activeTab: root.openTabIndex };

            if (isOpen && root.popupInstance && root.popupInstance.item && root.popupInstance.item.activeTab !== undefined && root.popupInstance.item.activeTab !== root.openTabIndex) {
                root.popupInstance.item.activeTab = root.openTabIndex;
                return;
            }

            ShellController.togglePopup(root, root.popupInstance);
        }
    }
}
