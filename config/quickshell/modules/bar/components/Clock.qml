import QtQuick
import "../../../core"
import "../../../shared"

PillWidget {
    id: root

    required property var calendarInstance
    required property color textColor
    property color accentColor: ColorScheme.accent
    required property bool compact

    readonly property int minuteStamp: MinuteTicker.minuteStamp

    function formattedTime(_stamp) {
        return Qt.formatTime(new Date(), "h:mm ap");
    }

    function formattedDate(_stamp) {
        return Qt.formatDateTime(new Date(), "ddd, dd/MM");
    }

    function toggleCalendar() {
        if (!calendarInstance) return;
        ShellController.togglePopup(root, calendarInstance);
    }

    iconText: root.formattedTime(root.minuteStamp)
    iconFontFamily: "Inter"
    iconFontSize: 12
    iconColor: root.accentColor
    labelText: root.compact ? "" : root.formattedDate(root.minuteStamp)
    labelColor: ColorScheme.withAlpha(root.textColor, 0.65)
    activeLabelColor: root.accentColor
    checked: ShellController.isPopupOpen(root.calendarInstance)
    popupOpen: checked
    tooltipText: root.formattedDate(root.minuteStamp) + " · " + root.formattedTime(root.minuteStamp)

    mouseArea.acceptedButtons: Qt.LeftButton | Qt.RightButton
    mouseArea.onClicked: root.toggleCalendar()
}
