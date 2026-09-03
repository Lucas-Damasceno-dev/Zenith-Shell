pragma Singleton

import QtQuick

Item {
    id: root

    visible: false

    property bool available: false
    property bool wifiEnabled: false
    property bool wifiConnected: false
    property string wifiSSID: ""
    property int wifiSignal: 0
    property bool ethernetConnected: false
    property string ethernetName: ""
    property string localIP: ""
    property string gateway: ""
    property string dnsText: ""
    property string linkSpeed: ""
    property bool vpnActive: false
    property string vpnName: ""
    property bool btEnabled: false
    property bool btPairable: false
    property bool btDiscoverable: false
    property bool btScanning: false

    property var wifiNetworks: []
    property var btDevices: []
    readonly property int btConnectedCount: {
        var count = 0;
        var devs = root.btDevices || [];
        for (var i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].connected)
                count++;
        }
        return count;
    }
    property int lastUpdateMs: 0
    property int staleTimeoutMs: 70000

    function asBool(value) {
        if (value === true || value === false)
            return value;
        var token = String(value || "").trim().toLowerCase();
        return token === "1" || token === "true" || token === "yes" || token === "on" || token === "sim" || token === "active" || token === "enabled";
    }

    function asInt(value, fallback) {
        var num = Number(value);
        if (!isFinite(num) || isNaN(num))
            return fallback;
        return Math.round(num);
    }

    function clampPercent(value) {
        return Math.max(0, Math.min(100, asInt(value, 0)));
    }

    function normalizeWifiNetwork(raw) {
        var item = raw && typeof raw === "object" ? raw : {};
        var ssid = String(item.ssid || "").trim();
        if (ssid === "")
            return null;

        return {
            ssid: ssid,
            signal: clampPercent(item.signal),
            active: asBool(item.active),
            security: String(item.security || "--")
        };
    }

    function normalizeBtDevice(raw) {
        var item = raw && typeof raw === "object" ? raw : {};
        var mac = String(item.mac || "").trim();
        if (mac === "")
            return null;

        var name = String(item.name || mac).trim();
        if (name === "")
            name = mac;

        return {
            mac: mac,
            name: name,
            paired: asBool(item.paired),
            connected: asBool(item.connected),
            icon: String(item.icon || "").trim(),
            battery: String(item.battery || "").trim()
        };
    }

    function normalizeWifiList(rawList) {
        var src = Array.isArray(rawList) ? rawList : [];
        var out = [];
        for (var i = 0; i < src.length; i++) {
            var item = normalizeWifiNetwork(src[i]);
            if (item)
                out.push(item);
        }
        out.sort(function(a, b) {
            if (a.active !== b.active)
                return a.active ? -1 : 1;
            if (a.signal !== b.signal)
                return b.signal - a.signal;
            return String(a.ssid).localeCompare(String(b.ssid));
        });
        return out;
    }

    function normalizeBtList(rawList) {
        var src = Array.isArray(rawList) ? rawList : [];
        var out = [];
        for (var i = 0; i < src.length; i++) {
            var item = normalizeBtDevice(src[i]);
            if (item)
                out.push(item);
        }
        out.sort(function(a, b) {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            return String(a.name).localeCompare(String(b.name));
        });
        return out;
    }

    function applyWifiState(wifi, vpn) {
        var wifiObj = wifi && typeof wifi === "object" ? wifi : {};
        var vpnObj = vpn && typeof vpn === "object" ? vpn : {};
        var networks = normalizeWifiList(wifiObj.networks);

        root.wifiNetworks = networks;
        root.wifiEnabled = asBool(wifiObj.enabled);
        root.wifiConnected = asBool(wifiObj.connected);
        root.wifiSSID = String(wifiObj.ssid || "").trim();
        root.wifiSignal = clampPercent(wifiObj.signal);
        root.ethernetConnected = asBool(wifiObj.ethernet_connected);
        root.ethernetName = String(wifiObj.ethernet_name || "").trim();
        root.localIP = String(wifiObj.local_ip || "").trim();
        root.gateway = String(wifiObj.gateway || "").trim();
        root.dnsText = String(wifiObj.dns_text || "").trim();
        root.linkSpeed = String(wifiObj.link_speed || "").trim();

        root.vpnActive = asBool(vpnObj.active);
        root.vpnName = String(vpnObj.name || "").trim();

        if (root.wifiSSID === "") {
            for (var i = 0; i < networks.length; i++) {
                if (networks[i].active) {
                    root.wifiSSID = networks[i].ssid;
                    root.wifiSignal = networks[i].signal;
                    root.wifiConnected = true;
                    break;
                }
            }
        }
    }

    function applyBluetoothState(bluetooth) {
        var btObj = bluetooth && typeof bluetooth === "object" ? bluetooth : {};
        root.btEnabled = asBool(btObj.enabled);
        root.btPairable = asBool(btObj.pairable);
        root.btDiscoverable = asBool(btObj.discoverable);
        root.btScanning = asBool(btObj.scanning);
        root.btDevices = normalizeBtList(btObj.devices);
    }

    function applyPayload(payloadObj) {
        var payload = payloadObj && typeof payloadObj === "object" ? payloadObj : {};
        var pType = String(payload.type || "").trim().toLowerCase();
        if (pType !== "network_update")
            return false;

        applyWifiState(payload.wifi, payload.vpn);
        applyBluetoothState(payload.bluetooth);
        root.available = true;
        root.lastUpdateMs = asInt(payload.timestamp, Date.now());
        return true;
    }

    function handleIpcPayload(payloadText) {
        try {
            var parsed = JSON.parse(String(payloadText || "{}"));
            return applyPayload(parsed);
        } catch (_e) {
            return false;
        }
    }

    function reset() {
        root.available = false;
        root.wifiEnabled = false;
        root.wifiConnected = false;
        root.wifiSSID = "";
        root.wifiSignal = 0;
        root.ethernetConnected = false;
        root.ethernetName = "";
        root.localIP = "";
        root.gateway = "";
        root.dnsText = "";
        root.linkSpeed = "";
        root.vpnActive = false;
        root.vpnName = "";
        root.btEnabled = false;
        root.btPairable = false;
        root.btDiscoverable = false;
        root.btScanning = false;
        root.wifiNetworks = [];
        root.btDevices = [];
        root.lastUpdateMs = 0;
    }

    Timer {
        id: staleGuard
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.available || root.lastUpdateMs <= 0)
                return;
            if ((Date.now() - root.lastUpdateMs) > root.staleTimeoutMs)
                root.reset();
        }
    }
}
