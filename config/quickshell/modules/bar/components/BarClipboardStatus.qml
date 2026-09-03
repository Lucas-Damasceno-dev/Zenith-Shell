import QtQuick
import "../../../core"
import "../../../shared"

/**
 * BarClipboardStatus - Quick clipboard history toggle on the bar.
 * Lightweight, zero-overhead when idle, responsive pill widget.
 */
Item {
    id: root

    implicitWidth: pill.implicitWidth
    implicitHeight: DesignTokens.barItemHeight

    required property color accentColor
    required property color textColor
    required property var popupInstance
    required property bool anyPopupOpen

    function togglePopup() {
        ShellController.togglePopup(root, root.popupInstance);
    }

    PillWidget {
        id: pill
        anchors.fill: parent
        iconText: "\u{f0ea}" // Clipboard icon
        iconColor: root.accentColor
        checked: ShellController.isPopupOpen(root.popupInstance)
        popupOpen: checked
        anyPopupOpen: root.anyPopupOpen
        tooltipText: "Área de Transferência (Clipboard)\nClique ou Super+V para abrir histórico"
        onClicked: root.togglePopup()
    }
}
