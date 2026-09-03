import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "../core"
import "../services"
import "../shared"
import "./NetworkPopupParsers.js" as NetworkPopupParsers

PopupWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    
        
    showScrim: false
    glassRadius: 0
    glassBackground: "transparent"
        slideY: 12
    originY: 0.0
    originX: 1.0

    property real anchorX: -1
    property real popupMargin: DesignTokens.spacingLG
    property bool outsideCloseEnabled: false
    property var settingsStore
    readonly property string scriptsDir: RuntimePaths.quickshellScriptsDir

    property bool wifiEnabled: true
    property string wifiSSID: ""
    property int wifiSignal: 0
    property bool ethernetConnected: NetworkStatusService.ethernetConnected
    property string ethernetName: NetworkStatusService.ethernetName
    property string localIP: ""
    property string publicIP: ""
    property string gateway: ""
    property string dnsText: ""
    property string linkSpeed: ""
    property bool vpnActive: false
    property string vpnName: ""
    property bool revealNetworkAddresses: false
    property var wifiNetworks: []
    property var savedWifiNetworks: []
    property string connectPromptSsid: ""
    property string connectPromptSecurity: ""
    property string connectPromptPassword: ""
    property bool showWifiPassword: false
    property bool wifiConnecting: false

    property bool btEnabled: false
    property bool btScanning: false
    property var btDevices: []
    property bool btDevicesRefreshQueued: false
    property bool btToggleGraceActive: false
    property bool btTogglePending: false
    property string btPendingPowerState: ""
    property bool btPairable: false
    property bool btDiscoverable: false
    property bool btPairPromptVisible: false
    property string btPairPromptMac: ""
    property string btPairPromptLabel: ""

    property string activeView: "wifi"
    readonly property string launcherSystemTool: RuntimePaths.scriptFile("launcher_system_tool.sh")
    readonly property bool connectivityReady: ConnectivityService.available

    property real lastRxBytes: 0
    property real lastTxBytes: 0
    property string netUploadSpeed: "0.0 KB/s"
    property string netDownloadSpeed: "0.0 KB/s"

    TimedProcess {
        id: netSpeedProc
        stdout: StdioCollector {
            onStreamFinished: {
                var output = String(text || "").trim();
                var lines = output.split(/\r?\n/);
                var parsed = false;
                if (lines.length >= 2) {
                    var rx = parseFloat(lines[0]);
                    var tx = parseFloat(lines[1]);
                    if (!isNaN(rx) && !isNaN(tx)) {
                        parsed = true;
                        if (root.lastRxBytes > 0 && root.lastTxBytes > 0) {
                            var diffRx = rx - root.lastRxBytes;
                            var diffTx = tx - root.lastTxBytes;
                            var rxSpeed = Math.max(0, diffRx / 2.0);
                            var txSpeed = Math.max(0, diffTx / 2.0);
                            
                            var fmt = function(b) {
                                if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s";
                                return (b / 1024).toFixed(1) + " KB/s";
                            }
                            root.netDownloadSpeed = fmt(rxSpeed);
                            root.netUploadSpeed = fmt(txSpeed);
                        }
                        root.lastRxBytes = rx;
                        root.lastTxBytes = tx;
                    }
                }
                if (!parsed) {
                    root.netDownloadSpeed = "0.0 KB/s";
                    root.netUploadSpeed = "0.0 KB/s";
                }
            }
        }
        stderr: StdioCollector { onRead: console.error("[NetworkPopup] Error: " + data) }
    }

    Timer {
        id: netSpeedTimer
        interval: FeatureFlags.lowPowerUiMode ? 5000 : 3000
        repeat: true
        running: root.isOpen && root.activeView === "wifi"
        triggeredOnStart: true
        onTriggered: {
            netSpeedProc.exec(["sh", RuntimePaths.scriptFile("net_speed.sh")]);
        }
    }

    function displayAddress(value) {
        var addr = String(value || "").trim();
        if (addr === "") return "";
        if (root.revealNetworkAddresses) return addr;
        return addr.replace(/[0-9a-fA-F]/g, "•");
    }

    function resetSpeedMetrics() {
        root.lastRxBytes = 0;
        root.lastTxBytes = 0;
        root.netDownloadSpeed = "0.0 KB/s";
        root.netUploadSpeed = "0.0 KB/s";
    }

    function applyConnectivityWifiSnapshot() {
        root.wifiEnabled = ConnectivityService.wifiEnabled;
        root.wifiSSID = ConnectivityService.wifiSSID;
        root.wifiSignal = ConnectivityService.wifiSignal;
        root.wifiNetworks = ConnectivityService.wifiNetworks;
        root.ethernetConnected = ConnectivityService.ethernetConnected;
        root.ethernetName = ConnectivityService.ethernetName;
        root.localIP = ConnectivityService.localIP;
        root.gateway = ConnectivityService.gateway;
        root.dnsText = ConnectivityService.dnsText;
        root.linkSpeed = ConnectivityService.linkSpeed;
        root.vpnActive = ConnectivityService.vpnActive;
        root.vpnName = ConnectivityService.vpnName;
    }

    function applyConnectivityBtSnapshot() {
        root.btEnabled = ConnectivityService.btEnabled;
        root.btPairable = ConnectivityService.btPairable;
        root.btDiscoverable = ConnectivityService.btDiscoverable;
        root.btScanning = ConnectivityService.btScanning;
        root.btDevices = ConnectivityService.btDevices;
    }

    onActiveViewChanged: {
        if (settingsStore && settingsStore.set)
            settingsStore.set("networkActiveView", activeView);
        if (activeView !== "bt")
            clearBtPairPrompt();
        if (isOpen && activeView === "wifi") {
            resetSpeedMetrics();
            refreshWifi({
                includeDetails: true,
                includeSaved: false,
                includeVpn: true
            });
        } else if (isOpen && activeView === "bt") {
            refreshBt({ includeDevices: true });
        }
    }

    function refreshVpnInfo() {
        if (root.connectivityReady)
            return;
        vpnInfoProc.exec([
            "bash", "-lc",
            "vpn_name=$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | awk -F: '$1==\"wireguard\" || $1==\"vpn\" {print $2; exit}'); if [ -n \"$vpn_name\" ]; then echo \"VPN:1:$vpn_name\"; else echo \"VPN:0:\"; fi"
        ]);
    }

    function notifyFeedback(summary, body) {
        feedbackProc.exec([
            "notify-send",
            "-a", "Connectivity Nexus",
            summary,
            body
        ]);
    }

    function clearBtPairPrompt() {
        root.btPairPromptVisible = false;
        root.btPairPromptMac = "";
        root.btPairPromptLabel = "";
    }

    function requestBtPairPrompt(device) {
        var mac = String(device && device.mac || "").trim();
        if (mac === "")
            return;

        root.btPairPromptMac = mac;
        root.btPairPromptLabel = String(device && device.name || mac).trim() || mac;
        root.btPairPromptVisible = true;
    }

    function submitBtPairPrompt(pin) {
        var mac = String(root.btPairPromptMac || "").trim();
        var label = String(root.btPairPromptLabel || mac || "Dispositivo").trim() || mac || "Dispositivo";
        var pinValue = String(pin || "").trim();

        if (mac === "") {
            clearBtPairPrompt();
            return;
        }

        clearBtPairPrompt();
        netActionProc.exec(["bash", root.launcherSystemTool, "bt-device", "pair", mac, pinValue]);
        root.notifyFeedback("Bluetooth", "Pareando " + label + (pinValue !== "" ? " com PIN" : "") + "...");

        Qt.callLater(function() {
            if (root.isOpen)
                root.refreshBt({ includeDevices: true });
        });
    }

    onIsOpenChanged: {
        if (isOpen) { outsideCloseEnabled = false; closeEnableTimer.restart(); } else { outsideCloseEnabled = false; }
        if (isOpen) {
            Qt.callLater(function() {
                if (!root.isOpen)
                    return;
                resetSpeedMetrics();
                // First pass: fast – wifi list + details (no rescan, no saved connections)
                refreshWifi({
                    includeDetails: true,
                    includeSaved: false,
                    includeVpn: false,
                    rescan: true
                });
                refreshBt({ includeDevices: activeView === "bt" || btScanning });
                startEventMonitors();
                // Second pass deferred: saved connections + VPN (heavier queries)
                Qt.callLater(function() {
                    if (!root.isOpen) return;
                    savedWifiProc.exec(["nmcli", "-t", "-f", "NAME,AUTOCONNECT-PRIORITY,TYPE", "connection", "show"]);
                    refreshVpnInfo();
                });
            });
        } else {
            resetSpeedMetrics();
            stopEventMonitors();
            root.btTogglePending = false;
            root.btPendingPowerState = "";
            root.btToggleGraceActive = false;
            clearBtPairPrompt();
            btToggleGraceTimer.stop();
        }
    }

    Component.onCompleted: {
        activeView = ConfigFacade.networkActiveView();
    }

    Component.onDestruction: {
        // ── Graceful cleanup of all monitors and timers ──────────────
        // Stop event monitors first (they spawn external processes)
        stopEventMonitors();

        // Stop all repeating/pending timers
        netSpeedTimer.stop();
        fallbackRefreshTimer.stop();
        vpnRefreshTimer.stop();
        wifiEventDebounce.stop();
        btEventDebounce.stop();
        btScanRefreshTimer.stop();
        btTogglePollTimer.stop();
        btToggleGraceTimer.stop();
    }

    function refreshWifi(options) {
        var opts = options || {};
        var includeDetails = opts.includeDetails === true;
        var includeSaved = opts.includeSaved === true;
        var includeVpn = opts.includeVpn === true;
        var rescan = opts.rescan !== false;

        if (root.connectivityReady) {
            root.applyConnectivityWifiSnapshot();
            if (includeSaved)
                savedWifiProc.exec(["nmcli", "-t", "-f", "NAME,AUTOCONNECT-PRIORITY,TYPE", "connection", "show"]);
            return;
        }

        wifiStatusProc.exec(["nmcli", "-t", "-f", "WIFI", "general"]);
        wifiSsidProc.exec(["nmcli", "-t", "-f", "active,ssid,signal,security", "dev", "wifi", "list", "--rescan", rescan ? "yes" : "no"]);

        if (includeDetails) {
            // Batch IP + gateway/DNS into single nmcli call
            netDetailsProc.exec(["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "dev", "show"]);
        }

        if (includeSaved)
            savedWifiProc.exec(["nmcli", "-t", "-f", "NAME,AUTOCONNECT-PRIORITY,TYPE", "connection", "show"]);

        if (includeVpn)
            refreshVpnInfo();
    }

    function refreshBt(options) {
        var opts = options || {};
        var includeDevices = opts.includeDevices !== false;

        if (root.connectivityReady) {
            root.applyConnectivityBtSnapshot();
            return;
        }

        btStatusProc.exec(["bash", root.launcherSystemTool, "bt-status"]);

        if (includeDevices) {
            var scriptPath = RuntimePaths.scriptFile("network_bt_devices.sh");
            if (btDevicesProc.running) {
                root.btDevicesRefreshQueued = true;
                return;
            }
            root.btDevicesRefreshQueued = false;
            btDevicesProc.exec([
                "bash",
                scriptPath,
                "list"
            ]);
        }
    }

    function submitWifiConnection() {
        root.wifiConnecting = true;
        var cmd = ["nmcli", "device", "wifi", "connect", root.connectPromptSsid];
        if (root.connectPromptPassword.trim() !== "") {
            cmd.push("password");
            cmd.push(root.connectPromptPassword);
        }
        netActionProc.exec(cmd);
        root.notifyFeedback("Wi-Fi", "Conectando a " + root.connectPromptSsid + "...");
        root.connectPromptSsid = "";
        root.connectPromptSecurity = "";
        root.connectPromptPassword = "";
        root.showWifiPassword = false;
        root.refreshWifi();
    }

    function handleBtDeviceAction(action, device) {
        var mac = String(device && device.mac || "").trim();
        var name = String(device && device.name || mac).trim();
        var label = name !== "" ? name : mac;

        if (mac === "")
            return;

        if (action === "pair") {
            requestBtPairPrompt(device);
            return;
        }

        netActionProc.exec(["bash", root.launcherSystemTool, "bt-device", action, mac]);
        if (action === "disconnect") {
            root.notifyFeedback("Bluetooth", "Desconectando " + label);
        } else if (action === "connect") {
            root.notifyFeedback("Bluetooth", "Conectando " + label + "...");
        } else {
            root.notifyFeedback("Bluetooth", "Pareando " + label + "... confirme no dispositivo");
        }

        Qt.callLater(function() {
            if (root.isOpen)
                root.refreshBt({ includeDevices: true });
        });
    }

    function openBluemanManager() {
        netActionProc.exec(["bash", root.launcherSystemTool, "bt-open-manager"]);
        root.notifyFeedback("Bluetooth", "Abrindo Blueman Manager");
    }

    function startEventMonitors() {
        // Background event monitoring is centralized in NetworkStatusService singleton
    }

    function stopEventMonitors() {
        // Background event monitoring is centralized in NetworkStatusService singleton
    }

    TimedProcess {
        id: wifiStatusProc
        stdout: StdioCollector {
            onRead: root.wifiEnabled = NetworkPopupParsers.isEnabledToken(data)
            onStreamFinished: root.wifiEnabled = NetworkPopupParsers.isEnabledToken(text)
        }
    }

    TimedProcess {
        id: wifiSsidProc
        stdout: StdioCollector {
            onStreamFinished: {
                var parsed = NetworkPopupParsers.parseWifiRows(text);
                root.wifiSSID = parsed.wifiSSID;
                root.wifiSignal = parsed.wifiSignal;
                root.wifiNetworks = parsed.wifiNetworks;
            }
        }
    }

    TimedProcess {
        id: netDetailsProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.localIP = NetworkPopupParsers.parsePrimaryIp(text);
                var details = NetworkPopupParsers.parseNetDetails(text);
                root.gateway = details.gateway;
                root.dnsText = details.dnsText;
                root.linkSpeed = details.linkSpeed;
            }
        }
    }

    TimedProcess {
        id: vpnInfoProc
        stdout: StdioCollector {
            onStreamFinished: {
                var parsed = NetworkPopupParsers.parseVpnAndPublic(text);
                root.vpnActive = parsed.vpnActive;
                root.vpnName = parsed.vpnName;
                root.publicIP = parsed.publicIP;
            }
        }
    }

    TimedProcess {
        id: savedWifiProc
        stdout: StdioCollector {
            onStreamFinished: root.savedWifiNetworks = NetworkPopupParsers.parseSavedWifiRows(text)
        }
    }

    TimedProcess {
        id: btStatusProc
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(text || "").trim();
                var powered = false;
                var pairable = false;
                var discoverable = false;
                var discovering = false;

                if (raw !== "") {
                    try {
                        var parsed = JSON.parse(raw);
                        powered = parsed.enabled === true;
                        pairable = parsed.pairable === true;
                        discoverable = parsed.discoverable === true;
                        discovering = parsed.discovering === true;
                    } catch (e) {
                        powered = false;
                        pairable = false;
                        discoverable = false;
                        discovering = false;
                    }
                }

                if (root.btToggleGraceActive && root.btPendingPowerState === "on")
                    powered = true;

                root.btEnabled = powered;
                root.btPairable = powered && pairable;
                root.btDiscoverable = powered && discoverable;

                if (!root.btEnabled) {
                    root.btScanning = false;
                } else if (!root.btTogglePending) {
                    root.btScanning = discovering;
                }

                if (root.btTogglePending) {
                    if ((root.btPendingPowerState === "on" && root.btEnabled) || (root.btPendingPowerState === "off" && !root.btEnabled)) {
                        root.btTogglePending = false;
                        root.btPendingPowerState = "";
                        root.btToggleGraceActive = false;
                        btToggleGraceTimer.stop();
                    }
                }
            }
        }
        onFailed: {
            root.btTogglePending = false;
            root.btPendingPowerState = "";
            root.btToggleGraceActive = false;
            btToggleGraceTimer.stop();
        }
    }

    TimedProcess {
        id: btDevicesProc
        stdout: StdioCollector {
            onStreamFinished: root.btDevices = NetworkPopupParsers.parseBtRows(text)
        }
        onExited: {
            if (root.btDevicesRefreshQueued && root.isOpen) {
                root.btDevicesRefreshQueued = false;
                Qt.callLater(function() {
                    if (root.isOpen)
                        root.refreshBt({ includeDevices: true });
                });
            }
        }
    }

    TimedProcess {
        id: netActionProc
        stdout: StdioCollector {
            onRead: {
                var out = String(data || "").trim();
                if (out !== "" && (out.toLowerCase().indexOf("error") >= 0 || out.toLowerCase().indexOf("falha") >= 0)) {
                    root.notifyFeedback("Connectivity action", out);
                }
            }
        }
        stderr: StdioCollector {
            onRead: {
                var err = String(data || "").trim();
                if (err !== "") root.notifyFeedback("Connectivity action", err);
            }
        }
        onExited: {
            root.wifiConnecting = false;
            if (root.isOpen) {
                if (root.activeView === "wifi") wifiEventDebounce.restart();
                else btEventDebounce.restart();
            }
        }
        onFailed: {
            root.wifiConnecting = false;
        }
    }
    TimedProcess { id: feedbackProc }

    Timer {
        id: fallbackRefreshTimer
        interval: FeatureFlags.lowPowerUiMode ? 60000 : 30000
        repeat: true
        running: root.isOpen && !root.connectivityReady && (root.activeView === "wifi" || root.activeView === "bt")
        triggeredOnStart: true
        onTriggered: {
            if (root.connectivityReady)
                return;
            if (root.activeView === "wifi") {
                root.refreshWifi({
                        includeDetails: false,
                        includeSaved: false,
                        includeVpn: false,
                    rescan: true
                });
            } else {
                root.refreshBt({ includeDevices: true });
            }
        }
    }

    Timer {
        id: vpnRefreshTimer
        interval: FeatureFlags.lowPowerUiMode ? 180000 : 90000
        repeat: true
        running: root.isOpen && root.activeView === "wifi" && !root.connectivityReady
        triggeredOnStart: true
        onTriggered: root.refreshVpnInfo()
    }

    Timer {
        id: closeEnableTimer
        interval: 120
        repeat: false
        running: false
        onTriggered: root.outsideCloseEnabled = true
    }

    Timer {
        id: wifiEventDebounce
        interval: 250
        repeat: false
        onTriggered: root.refreshWifi({
            includeDetails: false,
            includeSaved: false,
            includeVpn: false,
            rescan: true
        })
    }

    Timer {
        id: btEventDebounce
        interval: 250
        repeat: false
        onTriggered: root.refreshBt({ includeDevices: root.activeView === "bt" || root.btScanning })
    }

    Timer {
        id: btScanRefreshTimer
        interval: 2500  // Less aggressive polling while scanning
        repeat: true
        running: root.isOpen && root.activeView === "bt" && root.btScanning
        onTriggered: root.refreshBt({ includeDevices: true })
    }

    Timer {
        id: btToggleGraceTimer
        interval: 8000
        repeat: false
        onTriggered: {
            root.btToggleGraceActive = false;
            root.btTogglePending = false;
            root.btPendingPowerState = "";
            root.refreshBt({ includeDevices: root.activeView === "bt" || root.btScanning });
        }
    }

    Timer {
        id: btTogglePollTimer
        interval: 500
        repeat: true
        running: root.isOpen && root.btTogglePending
        onTriggered: root.refreshBt({ includeDevices: root.activeView === "bt" || root.btScanning })
    }

    onConnectivityReadyChanged: {
        if (root.connectivityReady) {
            root.applyConnectivityWifiSnapshot();
            root.applyConnectivityBtSnapshot();
            vpnRefreshTimer.stop();
            return;
        }
    }

    Connections {
        target: ConnectivityService

        function onLastUpdateMsChanged() {
            if (!root.connectivityReady)
                return;
            root.applyConnectivityWifiSnapshot();
            root.applyConnectivityBtSnapshot();
        }
    }

    Connections {
        target: NetworkStatusService

        function onWifiConnectedChanged() {
            if (!root.connectivityReady && root.isOpen)
                wifiEventDebounce.restart();
        }

        function onBluetoothPoweredChanged() {
            if (!root.connectivityReady && root.isOpen)
                btEventDebounce.restart();
        }
    }


    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        onClicked: (mouse) => {
            var p = mapToItem(popupCard, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > popupCard.width || p.y > popupCard.height) {
                root.isOpen = false;
            }
        }
    }

    Item {
        id: popupCard
        width: 350
        height: 500
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: popupTopMargin
        anchors.rightMargin: root.popupMargin
        z: 1

        Rectangle {
            id: popupBg
            anchors.fill: parent
            radius: 16
            color: ColorScheme.glassPopup
            border.color: ColorScheme.outlineVariant
            border.width: 1
        }

    Flickable {
        anchors.fill: parent
        anchors.margins: 16
        contentHeight: mainCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol
            width: parent.width
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { key: "wifi", label: "\u{f1eb}  Wi-Fi" },
                        { key: "bt", label: "\u{f294}  Bluetooth" }
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: 10
                        color: root.activeView === modelData.key
                            ? ColorScheme.withAlpha(ColorScheme.accent, 0.18)
                            : "transparent"

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.5
                            height: 2
                            radius: 1
                            color: ColorScheme.accent
                            visible: root.activeView === modelData.key
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.activeView === modelData.key
                                ? ColorScheme.accent
                                : ColorScheme.withAlpha(ColorScheme.text, 0.50)
                            font.pixelSize: 12
                            font.weight: root.activeView === modelData.key ? Font.Bold : Font.Normal
                            font.family: "Inter"
                            font.letterSpacing: DesignTokens.letterSpacingLabel
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeView = modelData.key
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.activeView === "wifi"

                // ── Ethernet Active Card ──────────────────────────────────────
                Rectangle {
                    visible: root.ethernetConnected
                    Layout.fillWidth: true
                    implicitHeight: ethRow.implicitHeight + 14
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.green, 0.12)
                    border.color: ColorScheme.withAlpha(ColorScheme.green, 0.35)
                    border.width: 1

                    RowLayout {
                        id: ethRow
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            text: "\u{f0200}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: ColorScheme.green
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: root.ethernetName !== "" ? root.ethernetName : "Rede Cabeada"
                                color: ColorScheme.text
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.family: "Inter"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "Ethernet Conectada" + (root.localIP !== "" ? (" • " + root.displayAddress(root.localIP)) : "")
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.60)
                                font.pixelSize: 9
                                font.family: "Inter"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            width: 52
                            height: 20
                            radius: 10
                            color: ColorScheme.withAlpha(ColorScheme.green, 0.22)
                            Text {
                                anchors.centerIn: parent
                                text: "Ativo"
                                color: ColorScheme.green
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.family: "Inter"
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: root.wifiEnabled ? ("\u{f1eb}  " + (root.wifiSSID || "Wi-Fi ligado")) : "\u{f1eb}  Wi-Fi desligado"
                        color: ColorScheme.text
                        font.pixelSize: 11
                        font.family: "Inter"
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 44
                        height: 24
                        radius: 12
                        color: root.wifiEnabled
                            ? ColorScheme.withAlpha(ColorScheme.accent, 0.5)
                            : ColorScheme.withAlpha(ColorScheme.text, 0.12)
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: ColorScheme.text
                            x: root.wifiEnabled ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 180 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var next = !root.wifiEnabled;
                                root.wifiEnabled = next;
                                ConnectivityService.wifiEnabled = next;
                                netActionProc.exec(["nmcli", "radio", "wifi", next ? "on" : "off"]);
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: netMetaCol.implicitHeight + 12
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.18)
                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                    border.width: 1
                    
                    ColumnLayout {
                        id: netMetaCol
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "VPN"
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.70)
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                font.family: "Inter"
                                font.letterSpacing: DesignTokens.letterSpacingLabel
                            }
                            Text {
                                text: "●"
                                color: root.vpnActive ? ColorScheme.green : ColorScheme.red
                                font.pixelSize: 9
                                font.family: "Inter"
                            }
                            Text {
                                text: root.vpnActive ? ("Ativa" + (root.vpnName !== "" ? (" (" + root.vpnName + ")") : "")) : "Inativa"
                                color: root.vpnActive ? ColorScheme.green : ColorScheme.red
                                font.pixelSize: 9
                                font.family: "Inter"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                                Text {
                                    anchors.centerIn: parent
                                    text: root.revealNetworkAddresses ? "\u{f070}" : "\u{f06e}"
                                    color: ColorScheme.withAlpha(ColorScheme.text, 0.82)
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.revealNetworkAddresses = !root.revealNetworkAddresses
                                }
                            }
                        }

                        Text {
                            visible: root.localIP !== ""
                            text: "IP Local: " + root.displayAddress(root.localIP)
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.58)
                            font.pixelSize: 9
                            font.family: "Inter"
                        }
                        Text {
                            visible: root.publicIP !== ""
                            text: "IP Público: " + root.displayAddress(root.publicIP)
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.58)
                            font.pixelSize: 9
                            font.family: "Inter"
                        }
                        Text {
                            visible: root.gateway !== ""
                            text: "Gateway: " + root.gateway
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.50)
                            font.pixelSize: 9
                            font.family: "Inter"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: root.dnsText !== ""
                            text: "DNS: " + root.dnsText
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.50)
                            font.pixelSize: 9
                            font.family: "Inter"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text { text: "▼ " + root.netDownloadSpeed; color: ColorScheme.green; font.pixelSize: 10; font.bold: true; font.family: "Inter" }
                    Text { text: "▲ " + root.netUploadSpeed; color: ColorScheme.blue; font.pixelSize: 10; font.bold: true; font.family: "Inter" }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: ColorScheme.withAlpha(ColorScheme.text, 0.06) }

                ColumnLayout {
                    visible: root.wifiNetworks.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.bottomMargin: 8
                    spacing: 6
                    Layout.alignment: Qt.AlignHCenter

                    Text {
                        text: "\u{f1eb}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 28
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.18)
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: "Nenhuma rede Wi-Fi encontrada"
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.42)
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.family: "Inter"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: "Verifique se o Wi-Fi está ligado e ao alcance"
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.28)
                        font.pixelSize: 9
                        font.family: "Inter"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                Repeater {
                    model: root.wifiNetworks
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: 10
                        color: modelData.active
                            ? ColorScheme.withAlpha(ColorScheme.accent, 0.18)
                            : ColorScheme.withAlpha(ColorScheme.text, 0.04)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: parent.height - 12
                            radius: 1.5
                            color: ColorScheme.accent
                            visible: modelData.active
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            anchors.leftMargin: modelData.active ? 14 : 8
                            spacing: 8
                            Text {
                                text: "\u{f1eb}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                color: modelData.active ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.5)
                            }
                            Text {
                                text: modelData.ssid
                                color: ColorScheme.text
                                font.pixelSize: 11
                                font.weight: modelData.active ? Font.DemiBold : Font.Normal
                                font.family: "Inter"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                visible: !!modelData.band
                                width: bandText.implicitWidth + 8
                                height: 16
                                radius: 4
                                color: modelData.band === "5G" || modelData.band === "5 GHz"
                                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.20)
                                    : (modelData.band === "6G" || modelData.band === "6 GHz"
                                        ? ColorScheme.withAlpha(ColorScheme.teal, 0.20)
                                        : ColorScheme.withAlpha(ColorScheme.text, 0.08))
                                Text {
                                    id: bandText
                                    anchors.centerIn: parent
                                    text: modelData.band || ""
                                    font.pixelSize: 8
                                    font.bold: true
                                    font.family: "Inter"
                                    color: modelData.band === "5G" || modelData.band === "5 GHz"
                                        ? ColorScheme.accent
                                        : (modelData.band === "6G" || modelData.band === "6 GHz"
                                            ? ColorScheme.teal
                                            : ColorScheme.withAlpha(ColorScheme.text, 0.60))
                                }
                            }

                            Text {
                                text: modelData.security && modelData.security !== "" && modelData.security !== "--" ? "\u{f023}" : "\u{f09c}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                            }
                            Rectangle {
                                width: signalBadgeRow.implicitWidth + 10
                                height: 16
                                radius: 8
                                color: modelData.signal >= 70
                                    ? ColorScheme.withAlpha(ColorScheme.green, 0.16)
                                    : (modelData.signal >= 40
                                        ? ColorScheme.withAlpha(ColorScheme.yellow, 0.16)
                                        : ColorScheme.withAlpha(ColorScheme.red, 0.16))

                                RowLayout {
                                    id: signalBadgeRow
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text {
                                        text: modelData.signal >= 70 ? "\u{f012}" : (modelData.signal >= 40 ? "\u{f012}" : "\u{f012}")
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 7
                                        opacity: modelData.signal >= 70 ? 1.0 : (modelData.signal >= 40 ? 0.7 : 0.5)
                                        color: modelData.signal >= 70
                                            ? ColorScheme.green
                                            : (modelData.signal >= 40 ? ColorScheme.yellow : ColorScheme.red)
                                    }
                                    Text {
                                        text: modelData.signal + "%"
                                        font.pixelSize: 9
                                        font.family: "Inter"
                                        color: modelData.signal >= 70
                                            ? ColorScheme.green
                                            : (modelData.signal >= 40 ? ColorScheme.yellow : ColorScheme.red)
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.active) return;
                                root.connectPromptSsid = modelData.ssid;
                                root.connectPromptSecurity = modelData.security || "";
                                root.connectPromptPassword = "";
                                root.showWifiPassword = false;
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: root.connectPromptSsid !== ""
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.26)
                    border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.22)
                    border.width: 1
                    implicitHeight: connectPromptCol.implicitHeight + 16
                    Layout.preferredHeight: implicitHeight
                    clip: true
                    
                    ColumnLayout {
                        id: connectPromptCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Text {
                            text: "Conectar: " + root.connectPromptSsid
                            color: ColorScheme.text
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Inter"
                        }

                        Text {
                            text: root.connectPromptSecurity !== "" ? "Digite a senha da rede abaixo." : "Rede aberta: senha opcional."
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.6)
                            font.pixelSize: 10
                            font.family: "Inter"
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            TextField {
                                id: wifiPasswordField
                                Layout.fillWidth: true
                                placeholderText: root.connectPromptSecurity !== "" ? "Senha do Wi-Fi" : "Senha (opcional)"
                                placeholderTextColor: ColorScheme.withAlpha(ColorScheme.text, 0.35)
                                text: root.connectPromptPassword
                                echoMode: root.showWifiPassword ? TextInput.Normal : TextInput.Password
                                font.pixelSize: 10
                                font.family: "Inter"
                                leftPadding: 10
                                rightPadding: 10
                                topPadding: 6
                                bottomPadding: 6
                                background: Rectangle {
                                    radius: 8
                                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.20)
                                    border.width: 1
                                    border.color: wifiPasswordField.activeFocus
                                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.35)
                                        : ColorScheme.withAlpha(ColorScheme.text, 0.10)
                                }
                                onTextChanged: root.connectPromptPassword = text
                                onAccepted: root.submitWifiConnection()
                            }

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 8
                                color: root.showWifiPassword
                                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.25)
                                    : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                                border.width: 1
                                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.10)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.showWifiPassword ? "\u{f070}" : "\u{f06e}"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: root.showWifiPassword ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.75)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showWifiPassword = !root.showWifiPassword
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                id: connectButton
                                Layout.fillWidth: true
                                height: 24
                                radius: 12
                                color: ColorScheme.withAlpha(ColorScheme.accent, 0.20)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        visible: root.wifiConnecting
                                        text: "\u{f110}"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: ColorScheme.accent
                                        RotationAnimation on rotation {
                                            from: 0; to: 360; duration: 900
                                            loops: Animation.Infinite
                                            running: root.wifiConnecting
                                        }
                                    }

                                    Text {
                                        text: root.wifiConnecting ? "Conectando..." : "Conectar"
                                        color: ColorScheme.accent
                                        font.pixelSize: 9
                                        font.bold: true
                                        font.family: "Inter"
                                    }
                                }

                                MouseArea {
                                    id: connectButtonMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.wifiConnecting
                                    onClicked: root.submitWifiConnection()
                                }
                            }

                            Rectangle {
                                width: 74
                                height: 24
                                radius: 12
                                color: ColorScheme.withAlpha(ColorScheme.red, 0.18)
                                Text { anchors.centerIn: parent; text: "Cancelar"; color: ColorScheme.red; font.pixelSize: 9; font.family: "Inter" }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.connectPromptSsid = "";
                                        root.connectPromptSecurity = "";
                                        root.connectPromptPassword = "";
                                        root.showWifiPassword = false;
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.savedWifiNetworks.length > 0
                    text: "Redes salvas"
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.58)
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.family: "Inter"
                    font.letterSpacing: DesignTokens.letterSpacingLabel
                }

                Repeater {
                    model: root.savedWifiNetworks
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        radius: 8
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.18)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Text {
                                text: modelData.name
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.78)
                                font.pixelSize: 9
                                font.family: "Inter"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "P" + modelData.priority
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.45)
                                font.pixelSize: 8
                                font.family: "Inter"
                            }

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: ColorScheme.withAlpha(ColorScheme.accent, 0.20)
                                Text { anchors.centerIn: parent; text: "+"; color: ColorScheme.accent; font.pixelSize: 10; font.bold: true; font.family: "Inter" }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        netActionProc.exec(["nmcli", "connection", "modify", modelData.name, "connection.autoconnect-priority", String(modelData.priority + 1)]);
                                        root.refreshWifi();
                                    }
                                }
                            }
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                                Text { anchors.centerIn: parent; text: "-"; color: ColorScheme.withAlpha(ColorScheme.text, 0.8); font.pixelSize: 10; font.bold: true; font.family: "Inter" }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        netActionProc.exec(["nmcli", "connection", "modify", modelData.name, "connection.autoconnect-priority", String(modelData.priority - 1)]);
                                        root.refreshWifi();
                                    }
                                }
                            }
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: ColorScheme.withAlpha(ColorScheme.red, 0.20)
                                Text { anchors.centerIn: parent; text: "\u{f00d}"; color: ColorScheme.red; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8 }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        netActionProc.exec(["nmcli", "connection", "delete", modelData.name]);
                                        root.notifyFeedback("Wi-Fi", "Rede esquecida: " + modelData.name);
                                        root.refreshWifi();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.activeView === "bt"

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: root.btEnabled ? "\u{f294}  Bluetooth ligado" : "\u{f294}  Bluetooth desligado"
                        color: ColorScheme.text
                        font.pixelSize: 11
                        font.family: "Inter"
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 44
                        height: 24
                        radius: 12
                        color: root.btEnabled
                            ? ColorScheme.withAlpha(ColorScheme.blue, 0.5)
                            : ColorScheme.withAlpha(ColorScheme.text, 0.12)
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: ColorScheme.text
                            x: root.btEnabled ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 180 } }
                        }
                        MouseArea {
                            id: btToggleMa
                            anchors.fill: parent
                            z: 2
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            onPressed: function(mouse) { mouse.accepted = true; }
                            onClicked: {
                                if (root.btTogglePending)
                                    return;

                                var nextState = root.btEnabled ? "off" : "on";
                                root.btEnabled = nextState === "on";
                                root.btToggleGraceActive = nextState === "on";

                                root.btTogglePending = true;
                                root.btPendingPowerState = nextState;
                                btToggleGraceTimer.restart();
                                btTogglePollTimer.restart();

                                netActionProc.exec(["bash", root.launcherSystemTool, "bt-toggle", nextState]);
                                if (nextState === "on") {
                                    root.btScanning = true;
                                    btScanRefreshTimer.restart();
                                    root.refreshBt({ includeDevices: true });
                                } else {
                                    root.btPairable = false;
                                    root.btDiscoverable = false;
                                    root.btScanning = false;
                                    btScanRefreshTimer.stop();
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 104
                        height: 24
                        radius: 12
                        color: root.btEnabled && root.btPairable
                            ? ColorScheme.withAlpha(ColorScheme.accent, 0.25)
                            : ColorScheme.withAlpha(ColorScheme.surface, 0.28)

                        Text {
                            anchors.centerIn: parent
                            text: "Pareável"
                            color: root.btEnabled && root.btPairable
                                ? ColorScheme.accent
                                : ColorScheme.withAlpha(ColorScheme.text, 0.8)
                            font.pixelSize: 9
                            font.family: "Inter"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.btEnabled
                            onClicked: {
                                var nextPairable = root.btPairable ? "off" : "on";
                                root.btPairable = nextPairable === "on";
                                netActionProc.exec(["bash", root.launcherSystemTool, "bt-pairable", nextPairable]);
                                btEventDebounce.restart();
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 110
                        height: 24
                        radius: 12
                        color: root.btEnabled && root.btDiscoverable
                            ? ColorScheme.withAlpha(ColorScheme.green, 0.24)
                            : ColorScheme.withAlpha(ColorScheme.surface, 0.28)

                        Text {
                            anchors.centerIn: parent
                            text: "Descobrível"
                            color: root.btEnabled && root.btDiscoverable
                                ? ColorScheme.green
                                : ColorScheme.withAlpha(ColorScheme.text, 0.8)
                            font.pixelSize: 9
                            font.family: "Inter"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.btEnabled
                            onClicked: {
                                var nextDiscoverable = root.btDiscoverable ? "off" : "on";
                                root.btDiscoverable = nextDiscoverable === "on";
                                netActionProc.exec(["bash", root.launcherSystemTool, "bt-discoverable", nextDiscoverable]);
                                btEventDebounce.restart();
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        Layout.preferredWidth: 88
                        height: 24
                        radius: 12
                        color: root.btScanning
                            ? ColorScheme.withAlpha(ColorScheme.blue, 0.25)
                            : ColorScheme.withAlpha(ColorScheme.surface, 0.28)
                        Text {
                            anchors.centerIn: parent
                            text: root.btScanning ? "Parar busca" : "Buscar"
                            color: root.btScanning ? ColorScheme.blue : ColorScheme.withAlpha(ColorScheme.text, 0.8)
                            font.pixelSize: 9
                            font.family: "Inter"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            acceptedButtons: Qt.LeftButton
                            onPressed: function(mouse) { mouse.accepted = true; }
                            onClicked: {
                                var nextScanState = root.btScanning ? "off" : "on";
                                netActionProc.exec(["bash", root.launcherSystemTool, "bt-scan", nextScanState]);
                                root.btScanning = nextScanState === "on";
                                if (root.btScanning) {
                                    btScanRefreshTimer.restart();
                                    root.refreshBt({ includeDevices: true });
                                } else {
                                    btScanRefreshTimer.stop();
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 86
                        height: 24
                        radius: 12
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.28)

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                id: btRefreshIcon
                                text: "\u{f021}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.8)

                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: 800
                                    loops: Animation.Infinite
                                    running: root.btScanning
                                }
                            }
                            Text {
                                text: "Atualizar"
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.8)
                                font.pixelSize: 9
                                font.family: "Inter"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refreshBt()
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 110
                        height: 24
                        radius: 12
                        color: ColorScheme.withAlpha(ColorScheme.accent, 0.22)

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\u{f293}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: ColorScheme.accent
                            }
                            Text {
                                text: "Blueman"
                                color: ColorScheme.accent
                                font.pixelSize: 9
                                font.family: "Inter"
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openBluemanManager()
                        }
                    }
                    Item { Layout.fillWidth: true }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: ColorScheme.withAlpha(ColorScheme.text, 0.06) }

                BluetoothPairPrompt {
                    Layout.fillWidth: true
                    promptVisible: root.btPairPromptVisible
                    deviceLabel: root.btPairPromptLabel
                    onConfirmed: root.submitBtPairPrompt(value)
                    onCancelled: root.clearBtPairPrompt()
                }

                ColumnLayout {
                    visible: root.btDevices.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.bottomMargin: 8
                    spacing: 6
                    Layout.alignment: Qt.AlignHCenter

                    Text {
                        text: "\u{f294}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 28
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.18)
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: "Nenhum dispositivo Bluetooth"
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.42)
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.family: "Inter"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: root.btScanning ? "Buscando dispositivos próximos…" : "Inicie uma busca para descobrir dispositivos"
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.28)
                        font.pixelSize: 9
                        font.family: "Inter"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                Repeater {
                    model: root.btDevices
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: 10
                        color: modelData.connected
                            ? ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                            : ColorScheme.withAlpha(ColorScheme.blue, 0.08)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Text {
                                text: {
                                    var ic = String(modelData.icon || "").toLowerCase();
                                    if (ic.indexOf("head") >= 0 || ic.indexOf("audio") >= 0) return "\u{f025c}";
                                    if (ic.indexOf("mouse") >= 0 || ic.indexOf("pointer") >= 0) return "\u{f8be}";
                                    if (ic.indexOf("keyboard") >= 0) return "\u{f11c}";
                                    if (ic.indexOf("phone") >= 0 || ic.indexOf("cellular") >= 0) return "\u{f10b}";
                                    if (ic.indexOf("game") >= 0 || ic.indexOf("joystick") >= 0) return "\u{f11b}";
                                    return "\u{f293}";
                                }
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                                color: modelData.connected ? ColorScheme.accent : ColorScheme.blue
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: modelData.name !== "" ? modelData.name : modelData.mac
                                    color: ColorScheme.text
                                    font.pixelSize: 11
                                    font.weight: modelData.connected ? Font.DemiBold : Font.Normal
                                    font.family: "Inter"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: modelData.connected ? "Conectado" : (modelData.paired ? "Pareado" : "Disponível")
                                        color: modelData.connected ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.50)
                                        font.pixelSize: 9
                                        font.family: "Inter"
                                    }

                                    Rectangle {
                                        visible: !!modelData.battery
                                        width: batRow.implicitWidth + 8
                                        height: 14
                                        radius: 4
                                        color: ColorScheme.withAlpha(
                                            parseInt(modelData.battery) <= 20 ? ColorScheme.red : (parseInt(modelData.battery) <= 45 ? ColorScheme.yellow : ColorScheme.green),
                                            0.18
                                        )

                                        RowLayout {
                                            id: batRow
                                            anchors.centerIn: parent
                                            spacing: 3
                                            Text {
                                                text: "\u{f240}"
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 8
                                                color: parseInt(modelData.battery) <= 20 ? ColorScheme.red : (parseInt(modelData.battery) <= 45 ? ColorScheme.yellow : ColorScheme.green)
                                            }
                                            Text {
                                                text: modelData.battery || ""
                                                font.pixelSize: 8
                                                font.bold: true
                                                font.family: "Inter"
                                                color: parseInt(modelData.battery) <= 20 ? ColorScheme.red : (parseInt(modelData.battery) <= 45 ? ColorScheme.yellow : ColorScheme.green)
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 82
                                height: 22
                                radius: 11
                                color: modelData.connected
                                    ? ColorScheme.withAlpha(ColorScheme.red, 0.20)
                                    : ColorScheme.withAlpha(ColorScheme.blue, 0.20)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.connected ? "Desconectar" : (modelData.paired ? "Conectar" : "Parear")
                                    color: modelData.connected ? ColorScheme.red : ColorScheme.blue
                                    font.pixelSize: 8
                                    font.family: "Inter"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var action = modelData.connected ? "disconnect" : (modelData.paired ? "connect" : "pair");
                                        root.handleBtDeviceAction(action, modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    }
}
