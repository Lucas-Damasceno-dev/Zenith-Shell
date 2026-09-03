import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../core"
import "../../../shared"
import "../../../services"

Item {
    id: root

    implicitWidth: pill.implicitWidth
    implicitHeight: DesignTokens.barItemHeight

    required property color accentColor
    required property color textColor
    required property var popupInstance
    required property bool anyPopupOpen
    property string tooltipText: ""

    function togglePopup() {
        ShellController.togglePopup(root, popupInstance);
    }

    readonly property bool wifiConnected: NetworkStatusService.wifiConnected
    readonly property string wifiSSID: NetworkStatusService.wifiSSID
    readonly property int wifiSignal: NetworkStatusService.wifiSignal
    readonly property bool wifiEnabled: NetworkStatusService.wifiEnabled
    readonly property bool ethernetConnected: NetworkStatusService.ethernetConnected
    readonly property string ethernetName: NetworkStatusService.ethernetName
    readonly property bool vpnActive: NetworkStatusService.vpnActive
    readonly property string vpnName: NetworkStatusService.vpnName
    readonly property bool bluetoothPowered: NetworkStatusService.bluetoothPowered
    readonly property int btConnectedCount: NetworkStatusService.btConnectedCount
    readonly property string localIP: NetworkStatusService.localIP
    readonly property bool networkConnected: NetworkStatusService.networkConnected

    // ── Contextual Adaptive Icon ──────────────────────────────────
    readonly property string netIcon: {
        if (root.ethernetConnected)
            return "\u{f0200}"; // Ethernet LAN icon (Nerd Font md-ethernet)
        if (root.wifiConnected)
            return "\u{f1eb}"; // Wi-Fi icon
        if (root.vpnActive)
            return "\u{f023}"; // VPN Lock/Shield icon
        if (root.bluetoothPowered && root.btConnectedCount > 0)
            return "\u{f293}"; // Bluetooth connected icon
        if (root.bluetoothPowered)
            return "\u{f294}"; // Bluetooth powered icon
        return "\u{f0ac}";     // Offline / Globe icon
    }

    // ── Contextual Adaptive Color ─────────────────────────────────
    readonly property color netColor: {
        if (root.ethernetConnected)
            return ColorScheme.green;
        if (root.wifiConnected) {
            if (root.wifiSignal > 0 && root.wifiSignal < 30)
                return ColorScheme.red;
            if (root.wifiSignal >= 30 && root.wifiSignal < 55)
                return ColorScheme.yellow;
            return root.accentColor;
        }
        if (root.vpnActive)
            return ColorScheme.teal;
        if (root.bluetoothPowered && root.btConnectedCount > 0)
            return ColorScheme.blue;
        if (root.bluetoothPowered)
            return ColorScheme.withAlpha(ColorScheme.blue, 0.75);
        return ColorScheme.withAlpha(root.textColor, 0.35);
    }

    // ── Rich Multi-line Tooltip ───────────────────────────────────
    readonly property string computedTooltip: {
        if (root.tooltipText !== "")
            return root.tooltipText;

        var lines = [];
        if (root.ethernetConnected) {
            var ethDesc = root.ethernetName !== "" ? (" (" + root.ethernetName + ")") : "";
            lines.push("󰈀 Ethernet: Conectado" + ethDesc);
        }

        if (root.wifiConnected) {
            var ssidDesc = root.wifiSSID !== "" ? root.wifiSSID : "Conectado";
            var sigDesc = root.wifiSignal > 0 ? (" (" + root.wifiSignal + "%)") : "";
            lines.push(" Wi-Fi: " + ssidDesc + sigDesc);
        } else if (root.wifiEnabled) {
            lines.push(" Wi-Fi: Ligado (Sem conexão)");
        } else {
            lines.push(" Wi-Fi: Desligado");
        }

        if (root.vpnActive) {
            var vpnDesc = root.vpnName !== "" ? (" (" + root.vpnName + ")") : "";
            lines.push("󰌆 VPN: Ativa" + vpnDesc);
        }

        if (root.bluetoothPowered) {
            if (root.btConnectedCount > 0) {
                lines.push(" Bluetooth: " + root.btConnectedCount + " conectado(s)");
            } else {
                lines.push(" Bluetooth: Ligado");
            }
        } else {
            lines.push(" Bluetooth: Desligado");
        }

        if (root.localIP !== "") {
            lines.push("🌐 IP Local: " + root.localIP);
        }

        lines.push("🖱️ Esq: Menu · Dir: Wi-Fi On/Off · Meio: BT On/Off");
        return lines.join("\n");
    }

    function toggleWifiQuick() {
        actionProc.exec(["bash", RuntimePaths.scriptFile("launcher_system_tool.sh"), "wifi-toggle"]);
        feedbackProc.exec([
            "notify-send",
            "-a", "Network Status",
            "Wi-Fi",
            root.wifiEnabled ? "Desligando Wi-Fi..." : "Ligando Wi-Fi..."
        ]);
        Qt.callLater(NetworkStatusService.refreshNow);
    }

    function toggleBluetoothQuick() {
        actionProc.exec(["bash", RuntimePaths.scriptFile("launcher_system_tool.sh"), "bt-toggle"]);
        feedbackProc.exec([
            "notify-send",
            "-a", "Bluetooth Status",
            "Bluetooth",
            root.bluetoothPowered ? "Desligando Bluetooth..." : "Ligando Bluetooth..."
        ]);
        Qt.callLater(NetworkStatusService.refreshNow);
    }

    PillWidget {
        id: pill
        anchors.fill: parent
        iconText: root.netIcon
        iconColor: root.netColor
        labelText: ""
        labelVisible: false
        tooltipText: root.computedTooltip
        checked: ShellController.isPopupOpen(root.popupInstance)
        popupOpen: checked
        anyPopupOpen: root.anyPopupOpen
        onClicked: root.togglePopup()

        // ── VPN Active Badge Dot (Top-Right) ──────────────────────
        Rectangle {
            id: vpnBadge
            visible: root.vpnActive && (root.wifiConnected || root.ethernetConnected)
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            width: 6
            height: 6
            radius: 3
            color: ColorScheme.teal

            SequentialAnimation on opacity {
                running: vpnBadge.visible
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.4; duration: 1200; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.4; to: 1.0; duration: 1200; easing.type: Easing.InOutQuad }
            }
        }

        // ── Bluetooth Connected Badge Dot (Bottom-Right) ──────────
        Rectangle {
            id: btBadge
            visible: root.bluetoothPowered && root.btConnectedCount > 0 && (root.wifiConnected || root.ethernetConnected)
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 4
            width: 5
            height: 5
            radius: 2.5
            color: ColorScheme.blue
        }
    }

    // ── Mouse Area for Secondary & Middle Click Quick Actions ─────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.MiddleButton | Qt.RightButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                root.toggleWifiQuick();
            } else if (mouse.button === Qt.MiddleButton) {
                root.toggleBluetoothQuick();
            }
        }
    }

    TimedProcess {
        id: actionProc
        timeoutMs: 4000
        onExited: NetworkStatusService.refreshNow()
    }

    TimedProcess {
        id: feedbackProc
        timeoutMs: 3000
    }
}
