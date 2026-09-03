import QtQuick
import "../../../core"
import "../../../shared"
import "../../../services"

PillWidget {
    id: root

    required property color accentColor
    required property color textColor
    required property var popupInstance
    property string tooltipOverride: ""

    readonly property string weatherIcon: {
        var ic = WeatherStatusService.cacheIcon;
        if (ic === "" || ic === "⛅" || ic === "⛅\uFE0E") return "\u{f0c2}";
        if (ic === "☀") return "\u{f185}";
        if (ic === "☁") return "\u{f0c2}";
        if (ic === "🌧" || ic === "⛈") return "\u{f0e7}";
        if (ic === "❄") return "\u{f2dc}";
        if (ic === "🌫") return "\u{f75f}";
        return "\u{f0c2}";
    }
    readonly property string weatherTemp: WeatherStatusService.cacheTemp !== "" ? WeatherStatusService.cacheTemp : "--°"
    readonly property bool isOffline: String(WeatherStatusService.cacheStateText || "") === "Cached"
    readonly property bool hasError: isOffline || weatherTemp === "--°"

    function togglePopup() {
        ShellController.togglePopup(root, root.popupInstance);
    }

    iconText: root.weatherIcon
    iconFontFamily: "JetBrainsMono Nerd Font"
    iconFontSize: 13
    iconYOffset: 0
    iconColor: root.accentColor
    checked: ShellController.isPopupOpen(root.popupInstance)
    popupOpen: checked
    labelText: root.weatherTemp
    labelFontSize: 11
    labelColor: ColorScheme.withAlpha(root.textColor, 0.75)
    activeLabelColor: ColorScheme.withAlpha(root.textColor, 0.85)
    tooltipText: root.tooltipOverride !== ""
        ? root.tooltipOverride
        : (root.isOffline ? "Weather cache offline" : (root.weatherTemp + " · " + root.weatherIcon))

    onClicked: root.togglePopup()
}
