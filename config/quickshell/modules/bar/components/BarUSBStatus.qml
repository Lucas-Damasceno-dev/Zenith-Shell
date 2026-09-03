import QtQuick
import "../../../core"
import "../../../shared"
import "../../../services"

/**
 * BarUSBStatus - Shows connected USB & removable storage devices
 * Provides real-time status, semantic coloring, busy indicators,
 * rich tooltip inspection and fast mouse interactions.
 */
Item {
    id: root

    required property color accentColor
    required property color textColor
    required property var popupInstance
    required property bool anyPopupOpen

    clip: true
    implicitWidth: USBService.hasDevices ? pill.implicitWidth : 0
    implicitHeight: DesignTokens.barItemHeight
    opacity: USBService.hasDevices ? 1.0 : 0.0
    visible: opacity > 0.01 || implicitWidth > 0.5

    Behavior on implicitWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }

    readonly property string displayIcon: {
        if (USBService.lastError !== "") return "\u{f071}"; // Warning icon
        if (USBService.isBusy) return "\u{f021}"; // Sync / refresh icon
        return "\u{f287}"; // USB icon
    }

    readonly property color displayColor: {
        if (USBService.lastError !== "") return ColorScheme.red;
        if (USBService.isBusy) return ColorScheme.peach;
        if (USBService.hasMountedDevices) return root.accentColor;
        return ColorScheme.withAlpha(root.textColor, 0.65);
    }

    readonly property string displayLabel: {
        if (USBService.isBusy) return "...";
        if (USBService.deviceCount === 0) return "";
        if (USBService.deviceCount === 1 && USBService.devices[0]) {
            var dev = USBService.devices[0];
            return dev.label ? dev.label : (dev.size ? dev.size : "1");
        }
        return USBService.mountedCount + "/" + USBService.deviceCount;
    }

    readonly property string richTooltip: {
        if (!USBService.hasDevices) return "Nenhum dispositivo USB conectado";
        var lines = [];
        lines.push(USBService.deviceCount + " dispositivo(s) USB (" + USBService.mountedCount + " montado(s))");
        for (var i = 0; i < USBService.devices.length; i++) {
            var d = USBService.devices[i];
            var line = "• " + (d.label || d.name) + " (" + d.size + ")";
            if (d.mounted && d.mountpoint) {
                line += " \u2192 " + d.mountpoint;
            } else {
                line += " [Desmontado]";
            }
            lines.push(line);
        }
        lines.push("");
        lines.push("Esq: Gerenciar • Dir: Abrir • Meio: Ejetar tudo");
        return lines.join("\n");
    }

    PillWidget {
        id: pill
        anchors.fill: parent
        iconText: root.displayIcon
        iconColor: root.displayColor
        labelText: root.displayLabel
        labelFontSize: 11
        labelColor: root.displayColor
        busy: USBService.isBusy
        checked: ShellController.isPopupOpen(root.popupInstance)
        popupOpen: checked
        anyPopupOpen: root.anyPopupOpen
        tooltipText: root.richTooltip
        onClicked: ShellController.togglePopup(root, root.popupInstance)
    }

    // Secondary click handlers (Middle click: Eject all, Right click: Open in file manager)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) {
                USBService.ejectAll();
            } else if (mouse.button === Qt.RightButton) {
                if (USBService.primaryMountpoint) {
                    USBService.openInFileManager(USBService.primaryMountpoint);
                } else {
                    ShellController.togglePopup(root, root.popupInstance);
                }
            }
        }
    }

    // Gentle flash animation when a new device is connected
    Connections {
        target: USBService
        function onDeviceAdded(device) {
            if (!FeatureFlags.reducedMotion) {
                flashAnim.restart();
            }
        }
    }

    SequentialAnimation {
        id: flashAnim
        loops: 2
        PropertyAnimation { target: pill; property: "scale"; to: 1.08; duration: 120; easing.type: Easing.OutQuad }
        PropertyAnimation { target: pill; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.InQuad }
    }
}
