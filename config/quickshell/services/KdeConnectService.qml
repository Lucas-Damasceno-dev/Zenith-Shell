pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Item {
    id: root

    property string deviceName: ""
    property int batteryCharge: -1
    property bool isCharging: false
    property bool isConnected: false
    readonly property string bashBin: "bash"
    readonly property string kdeconnectCliBin: "kdeconnect-cli"
    readonly property string busctlBin: "busctl"

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: proc.running = true
    }

    Component.onCompleted: proc.running = true

    TimedProcess {
        id: proc
        command: [
            root.bashBin, "-c",
            "DEV=$(" + root.kdeconnectCliBin + " -a --id-only 2>/dev/null | head -n1); " +
            "if [ -n \"$DEV\" ]; then " +
            "NAME=$(" + root.kdeconnectCliBin + " -a --name-only 2>/dev/null | head -n1); " +
            "BATT=$(" + root.busctlBin + " --user get-property org.kde.kdeconnect /modules/kdeconnect/devices/$DEV org.kde.kdeconnect.device.battery charge 2>/dev/null | awk '{print $2}'); " +
            "CHARGING=$(" + root.busctlBin + " --user get-property org.kde.kdeconnect /modules/kdeconnect/devices/$DEV org.kde.kdeconnect.device.battery isCharging 2>/dev/null | awk '{print $2}'); " +
            "echo \"$NAME|$BATT|$CHARGING\"; " +
            "else echo \"\"; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = (text || "").trim();
                if (out === "") {
                    root.isConnected = false;
                    root.deviceName = "";
                    root.batteryCharge = -1;
                    root.isCharging = false;
                } else {
                    var parts = out.split("|");
                    root.isConnected = true;
                    root.deviceName = parts[0] || "Dispositivo";
                    var parsedBattery = Number(parts[1]);
                    root.batteryCharge = isFinite(parsedBattery) && !isNaN(parsedBattery) ? parsedBattery : -1;
                    var chargingText = String(parts[2] || "").trim().toLowerCase();
                    root.isCharging = chargingText === "true" || chargingText === "1";
                }
            }
        }
    }
}
