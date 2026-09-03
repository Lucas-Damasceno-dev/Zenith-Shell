import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../services"
import "../../../shared"

Item {
    id: root

    implicitWidth: pill.implicitWidth
    implicitHeight: DesignTokens.barItemHeight

    required property color accentColor
    required property color textColor
    property string tooltipText: ""

    visible: KdeConnectService.isConnected

    PillWidget {
        id: pill
        anchors.fill: parent
        iconText: root.getIcon()
        iconColor: root.accentColor
        labelText: KdeConnectService.batteryCharge >= 0 ? (KdeConnectService.batteryCharge + "%") : ""
        labelFontSize: 12
        labelColor: ColorScheme.withAlpha(root.textColor, 0.65)
        tooltipText: KdeConnectService.deviceName + " (" + (KdeConnectService.batteryCharge >= 0 ? KdeConnectService.batteryCharge + "%" : "Bateria N/A") + ")"
        checked: false
        popupOpen: false
        anyPopupOpen: false
        onClicked: {
            // Nothing for now or toggle popup
        }
    }

    function getIcon() {
        if (!KdeConnectService.isConnected) return "\u{f3cd}";
        if (KdeConnectService.isCharging) return "\u{f0e7}"; // zap
        var b = KdeConnectService.batteryCharge;
        if (b < 0) return "\u{f3cd}"; // phone
        if (b > 80) return "\u{f240}";
        if (b > 60) return "\u{f241}";
        if (b > 40) return "\u{f242}";
        if (b > 20) return "\u{f243}";
        return "\u{f244}";
    }
}
