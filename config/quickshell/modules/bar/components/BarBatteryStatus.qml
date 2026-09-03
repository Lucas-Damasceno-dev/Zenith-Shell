import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../../../core"
import "../../../shared"
import "../../../services"

Item {
    id: root
    implicitWidth:  pill.implicitWidth
    implicitHeight: DesignTokens.barItemHeight

    required property color accentColor
    required property color textColor
    required property var popupInstance
    required property bool anyPopupOpen
    property string tooltipText: ""

    function togglePopup() { ShellController.togglePopup(root, popupInstance); }

    property int _pendingBrightnessDelta: 0

    Timer {
        id: brightnessTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (root._pendingBrightnessDelta === 0) return;
            var delta = root._pendingBrightnessDelta;
            root._pendingBrightnessDelta = 0;
            var stepStr = delta < 0 ? (Math.abs(delta) + "%-") : ("+" + delta + "%");
            brightnessCtl.exec(["brightnessctl", "s", stepStr]);
        }
    }

    function adjustBrightness(stepUp) {
        _pendingBrightnessDelta += (stepUp ? 5 : -5);
        brightnessTimer.restart();
    }

    function cyclePowerProfile(stepUp) {
        BatteryStatsService.cyclePowerProfile(stepUp);
    }

    readonly property var  bat:         UPower.displayDevice
    readonly property bool hasBat:      bat && bat.isPresent
    readonly property int  pct:         BatteryStatsService.batteryPercent >= 0 ? BatteryStatsService.batteryPercent : (hasBat ? Math.round(bat.percentage <= 1 ? bat.percentage * 100 : bat.percentage) : -1)
    readonly property bool charging:    hasBat && bat.state === UPowerDeviceState.Charging
    readonly property bool discharging: hasBat && bat.state === UPowerDeviceState.Discharging

    // Dynamic contextual glyph with integrated charging bolt (Nerd Font Material Icons)
    readonly property string batIcon: {
        if (!hasBat) {
            if (BatteryStatsService.powerProfile === "power-saver") return "\u{f06c}";
            if (BatteryStatsService.powerProfile === "performance") return "\u{f135}";
            return "\u{f24e}";
        }
        if (charging) {
            if (pct >= 95) return "\u{f0085}"; // battery_charging_100
            if (pct >= 85) return "\u{f008b}"; // battery_charging_90
            if (pct >= 75) return "\u{f008a}"; // battery_charging_80
            if (pct >= 65) return "\u{f0089}"; // battery_charging_70
            if (pct >= 55) return "\u{f0088}"; // battery_charging_60
            if (pct >= 45) return "\u{f0087}"; // battery_charging_50
            if (pct >= 35) return "\u{f0086}"; // battery_charging_40
            if (pct >= 25) return "\u{f089d}"; // battery_charging_30
            if (pct >= 15) return "\u{f089c}"; // battery_charging_20
            return "\u{f089f}";                // battery_charging_outline
        }
        if (pct >= 95) return "\u{f0079}";     // battery_100
        if (pct >= 85) return "\u{f0082}";     // battery_90
        if (pct >= 75) return "\u{f0081}";     // battery_80
        if (pct >= 65) return "\u{f0080}";     // battery_70
        if (pct >= 55) return "\u{f007f}";     // battery_60
        if (pct >= 45) return "\u{f007e}";     // battery_50
        if (pct >= 35) return "\u{f007d}";     // battery_40
        if (pct >= 25) return "\u{f007c}";     // battery_30
        if (pct >= 15) return "\u{f007b}";     // battery_20
        return "\u{f007a}";                    // battery_10 / alert
    }

    // Dynamic semantic color coding
    readonly property color batColor: {
        if (!hasBat) return accentColor;
        if (charging) return ColorScheme.teal;
        if (pct <= 15) return ColorScheme.red;
        if (pct <= 25) return ColorScheme.peach;
        return accentColor;
    }

    // Legacy function aliases
    function batteryIcon()  { return batIcon; }
    function batteryColor() { return batColor; }

    PillWidget {
        id: pill
        anchors.fill: parent
        iconText:   root.batIcon
        iconColor:  root.batColor
        labelText:  root.hasBat ? (root.pct + "%") : "AC"
        labelFontSize: 12
        labelColor: ColorScheme.withAlpha(root.textColor, 0.75)
        badgeText: {
            if (BatteryStatsService.caffeineActive) return "\u{f0f4}";
            if (BatteryStatsService.powerProfile === "power-saver") return "\u{f06c}";
            if (BatteryStatsService.powerProfile === "performance") return "\u{f0e7}";
            return "";
        }
        badgeColor: {
            if (BatteryStatsService.caffeineActive) return ColorScheme.peach;
            if (BatteryStatsService.powerProfile === "power-saver") return ColorScheme.teal;
            return ColorScheme.accent;
        }

        tooltipText: {
            if (root.tooltipText !== "") return root.tooltipText;
            if (!root.hasBat) return "Alimentação AC · Perfil: " + BatteryStatsService.powerProfile;
            var info = root.pct + "% " + (root.charging ? "carregando" : "bateria");
            if (root.bat) {
                var sec = root.charging ? root.bat.timeToFull : root.bat.timeToEmpty;
                if (sec > 0) {
                    var h = Math.floor(sec / 3600);
                    var m = Math.floor((sec % 3600) / 60);
                    info += " · " + (h > 0 ? (h + "h " + m + "m") : (m + "m")) + (root.charging ? " até 100%" : " restante");
                }
                if (root.bat.changeRate > 0) {
                    info += " (" + Math.abs(root.bat.changeRate).toFixed(1) + " W)";
                }
            }
            info += " · Perfil: " + BatteryStatsService.powerProfile;
            info += "\n[Scroll: Brilho | Clique-Dir: Perfil | Clique-Meio: Caffeine]";
            return info;
        }

        checked:      ShellController.isPopupOpen(root.popupInstance)
        popupOpen:    checked
        anyPopupOpen: root.anyPopupOpen
        onClicked:    root.togglePopup()
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                root.cyclePowerProfile(true);
            } else if (mouse.button === Qt.MiddleButton) {
                BatteryStatsService.setCaffeineActive(!BatteryStatsService.caffeineActive);
            }
        }
        onWheel: function(wheel) {
            if (wheel.angleDelta.y === 0) return;
            root.adjustBrightness(wheel.angleDelta.y > 0);
        }
    }

    TimedProcess {
        id: brightnessCtl
        timeoutMs: 2500
        onExited: {
            if (typeof shellRoot !== "undefined" && shellRoot && shellRoot.triggerBrightnessOsd) {
                shellRoot.triggerBrightnessOsd();
            }
        }
    }
}
