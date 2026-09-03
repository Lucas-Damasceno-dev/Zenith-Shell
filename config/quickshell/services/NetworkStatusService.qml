pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Item {
    id: root

    visible: false

    property bool wifiEnabled: false
    property bool wifiConnected: false
    property string wifiSSID: ""
    property int wifiSignal: 0
    property bool ethernetConnected: false
    property string ethernetName: ""
    property string localIP: ""
    property bool vpnActive: false
    property string vpnName: ""
    property bool bluetoothPowered: false
    property int btConnectedCount: 0
    readonly property bool connectivityReady: ConnectivityService.available

    readonly property bool networkConnected: root.ethernetConnected || root.wifiConnected || root.vpnActive
    readonly property string primaryType: {
        if (root.ethernetConnected) return "ethernet";
        if (root.wifiConnected) return "wifi";
        if (root.vpnActive) return "vpn";
        return "offline";
    }

    function isActiveFlag(flag) {
        var token = String(flag || "").trim().toLowerCase();
        return token === "yes" || token === "sim" || token === "true" || token === "active" || token === "*";
    }

    function syncFromConnectivity() {
        if (!root.connectivityReady) return;
        root.wifiEnabled = ConnectivityService.wifiEnabled;
        root.wifiConnected = ConnectivityService.wifiConnected;
        root.wifiSSID = ConnectivityService.wifiSSID;
        root.wifiSignal = ConnectivityService.wifiSignal;
        root.ethernetConnected = ConnectivityService.ethernetConnected;
        root.ethernetName = ConnectivityService.ethernetName;
        root.localIP = ConnectivityService.localIP;
        root.vpnActive = ConnectivityService.vpnActive;
        root.vpnName = ConnectivityService.vpnName;
        root.bluetoothPowered = ConnectivityService.btEnabled;
        root.btConnectedCount = ConnectivityService.btConnectedCount;
    }

    function refreshWifiStatus() {
        if (root.connectivityReady) return;
        wifiCheck.exec(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"]);
    }

    function refreshBluetoothStatus() {
        if (root.connectivityReady) return;
        // Direct execution without bash/sed subshell pipeline
        btCheck.exec(["bluetoothctl", "show"]);
    }

    function refreshNow() {
        if (root.connectivityReady) {
            syncFromConnectivity();
            return;
        }
        refreshWifiStatus();
        refreshBluetoothStatus();
    }

    TimedProcess {
        id: wifiCheck
        timeoutMs: 5000

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(text || "").trim().split(/\r?\n/);
                var foundWifi = false;
                var foundWifiSSID = "";
                var foundEth = false;
                var foundEthName = "";

                for (var i = 0; i < lines.length; i++) {
                    var line = String(lines[i] || "").trim();
                    if (line === "") continue;
                    var parts = line.split(":");
                    if (parts.length < 2) continue;
                    var type = parts[0].toLowerCase();
                    var state = parts[1].toLowerCase();
                    var conn = parts.length > 2 ? parts.slice(2).join(":") : "";

                    var isConnected = state === "connected" || state === "conectado" || state.indexOf("connected") >= 0;

                    if (type === "wifi" || type === "802-11-wireless") {
                        if (isConnected) {
                            foundWifi = true;
                            foundWifiSSID = conn;
                        }
                    } else if (type === "ethernet" || type === "802-3-ethernet") {
                        if (isConnected) {
                            foundEth = true;
                            foundEthName = conn;
                        }
                    }
                }

                root.wifiConnected = foundWifi;
                root.wifiSSID = foundWifiSSID;
                root.ethernetConnected = foundEth;
                root.ethernetName = foundEthName;
            }
        }
    }

    Timer {
        id: wifiDebounce
        interval: 300
        repeat: false
        onTriggered: root.refreshWifiStatus()
    }

    TimedProcess {
        id: nmMonitor
        command: ["nmcli", "monitor"]
        running: false // Fallback only; primary is D-Bus context-daemon
        timeoutMs: 0

        stdout: StdioCollector {
            onRead: wifiDebounce.restart()
        }

        onExited: {
            if (!root.connectivityReady && nmMonitor.running)
                nmFallback.restart();
        }
    }

    Timer {
        id: nmFallback
        interval: 5000
        repeat: false
        onTriggered: {
            if (!root.connectivityReady)
                nmMonitor.exec(["nmcli", "monitor"]);
        }
    }

    TimedProcess {
        id: btCheck
        timeoutMs: 5000

        stdout: StdioCollector {
            onStreamFinished: {
                var textContent = String(text || "");
                var match = textContent.match(/Powered:\s*(yes|no|sim|true|false)/i);
                if (match) {
                    root.bluetoothPowered = root.isActiveFlag(match[1]);
                } else {
                    root.bluetoothPowered = false;
                }
            }
        }
    }

    Timer {
        id: btDebounce
        interval: 300
        repeat: false
        onTriggered: root.refreshBluetoothStatus()
    }

    TimedProcess {
        id: btMonitor
        command: ["bluetoothctl", "--monitor"]
        running: false // Fallback only; primary is D-Bus context-daemon
        timeoutMs: 0

        stdout: StdioCollector {
            onRead: btDebounce.restart()
        }

        stderr: StdioCollector {
            onRead: {
                if (!root.connectivityReady && btMonitor.running)
                    btMonitorRestart.restart();
            }
        }

        onExited: {
            if (!root.connectivityReady && btMonitor.running)
                btMonitorRestart.restart();
        }
    }

    Timer {
        id: btMonitorRestart
        interval: 5000
        repeat: false
        onTriggered: {
            if (!root.connectivityReady)
                btMonitor.exec(["bluetoothctl", "--monitor"]);
        }
    }

    onConnectivityReadyChanged: {
        if (root.connectivityReady) {
            syncFromConnectivity();
            if (nmMonitor.running)
                nmMonitor.kill();
            if (btMonitor.running)
                btMonitor.kill();
            nmFallback.stop();
            btMonitorRestart.stop();
            return;
        }
        root.refreshNow();
        nmMonitor.running = true;
        btMonitor.running = true;
    }

    Connections {
        target: ConnectivityService

        function onWifiConnectedChanged() { if (root.connectivityReady) root.wifiConnected = ConnectivityService.wifiConnected; }
        function onWifiSSIDChanged() { if (root.connectivityReady) root.wifiSSID = ConnectivityService.wifiSSID; }
        function onWifiSignalChanged() { if (root.connectivityReady) root.wifiSignal = ConnectivityService.wifiSignal; }
        function onWifiEnabledChanged() { if (root.connectivityReady) root.wifiEnabled = ConnectivityService.wifiEnabled; }
        function onEthernetConnectedChanged() { if (root.connectivityReady) root.ethernetConnected = ConnectivityService.ethernetConnected; }
        function onEthernetNameChanged() { if (root.connectivityReady) root.ethernetName = ConnectivityService.ethernetName; }
        function onLocalIPChanged() { if (root.connectivityReady) root.localIP = ConnectivityService.localIP; }
        function onVpnActiveChanged() { if (root.connectivityReady) root.vpnActive = ConnectivityService.vpnActive; }
        function onVpnNameChanged() { if (root.connectivityReady) root.vpnName = ConnectivityService.vpnName; }
        function onBtEnabledChanged() { if (root.connectivityReady) root.bluetoothPowered = ConnectivityService.btEnabled; }
        function onBtDevicesChanged() { if (root.connectivityReady) root.btConnectedCount = ConnectivityService.btConnectedCount; }
    }

    Component.onCompleted: {
        if (root.connectivityReady) {
            syncFromConnectivity();
            return;
        }
        root.refreshNow();
    }
}
