pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * USBService - Event-driven removable storage service
 * Monitors USB & removable block devices with zero-polling wakeups,
 * multi-partition support, async state tracking and safe power-off ejection.
 */
Singleton {
    id: root

    // ── Public State ────────────────────────────────────────────────────────
    readonly property var devices: _devices
    readonly property int deviceCount: _devices.length
    readonly property bool hasDevices: _devices.length > 0
    readonly property int mountedCount: {
        var count = 0;
        for (var i = 0; i < _devices.length; i++) {
            if (_devices[i].mounted) count++;
        }
        return count;
    }
    readonly property bool hasMountedDevices: mountedCount > 0
    readonly property bool isBusy: _refreshing || _mounting || _unmounting || _ejecting || Object.keys(_busyMap).length > 0
    readonly property string primaryMountpoint: {
        for (var i = 0; i < _devices.length; i++) {
            if (_devices[i].mounted && _devices[i].mountpoint) {
                return _devices[i].mountpoint;
            }
        }
        return "";
    }
    readonly property int pollIntervalMs: root.hasDevices
        ? (FeatureFlags.lowPowerUiMode ? 120000 : 60000)
        : (FeatureFlags.lowPowerUiMode ? 300000 : 180000)

    property string lastError: ""

    // ── Private State ───────────────────────────────────────────────────────
    property var _devices: []
    property var _busyMap: ({})
    property bool _refreshing: false
    property bool _mounting: false
    property bool _unmounting: false
    property bool _ejecting: false

    // ── Signals ─────────────────────────────────────────────────────────────
    signal deviceAdded(var device)
    signal deviceRemoved(string devicePath)
    signal ejectSuccess(string deviceName)
    signal ejectFailed(string deviceName, string error)
    signal mountSuccess(string deviceName)
    signal mountFailed(string deviceName, string error)
    signal unmountSuccess(string deviceName)
    signal unmountFailed(string deviceName, string error)

    // ── Public Helpers ──────────────────────────────────────────────────────
    function isDeviceBusy(deviceName) {
        if (!deviceName) return false;
        return !!_busyMap[deviceName];
    }

    function _setDeviceBusy(deviceName, busy) {
        var map = Object.assign({}, _busyMap);
        if (busy) {
            map[deviceName] = true;
        } else {
            delete map[deviceName];
        }
        _busyMap = map;
    }

    function refresh() {
        if (_refreshing) return;
        _refreshing = true;
        refreshProc.exec(["bash", RuntimePaths.scriptFile("usb_devices.sh"), "--json"]);
    }

    function mountDevice(deviceName) {
        if (!deviceName || isDeviceBusy(deviceName)) return;
        Logger.info("USBService", "Mounting device: " + deviceName);
        _setDeviceBusy(deviceName, true);
        _mounting = true;
        mountProc.targetDevice = deviceName;
        mountProc.exec(["bash", RuntimePaths.scriptFile("usb_devices.sh"), "--mount", deviceName]);
    }

    function unmountDevice(deviceName) {
        if (!deviceName || isDeviceBusy(deviceName)) return;
        Logger.info("USBService", "Unmounting device: " + deviceName);
        _setDeviceBusy(deviceName, true);
        _unmounting = true;
        unmountProc.targetDevice = deviceName;
        unmountProc.exec(["bash", RuntimePaths.scriptFile("usb_devices.sh"), "--unmount", deviceName]);
    }

    function ejectDevice(deviceName) {
        if (!deviceName || isDeviceBusy(deviceName)) return;
        Logger.info("USBService", "Ejecting device: " + deviceName);
        
        // Find parent disk and mark all related partitions as busy
        var parentDisk = deviceName;
        for (var i = 0; i < _devices.length; i++) {
            if (_devices[i].name === deviceName && _devices[i].parentDisk) {
                parentDisk = _devices[i].parentDisk;
                break;
            }
        }

        _setDeviceBusy(deviceName, true);
        if (parentDisk !== deviceName) {
            _setDeviceBusy(parentDisk, true);
        }
        
        // Also mark any siblings under same parentDisk
        for (var j = 0; j < _devices.length; j++) {
            if (_devices[j].parentDisk === parentDisk) {
                _setDeviceBusy(_devices[j].name, true);
            }
        }

        _ejecting = true;
        ejectProc.targetDevice = deviceName;
        ejectProc.parentDisk = parentDisk;
        ejectProc.exec(["bash", RuntimePaths.scriptFile("usb_devices.sh"), "--eject", deviceName]);
    }

    function ejectAll() {
        if (_devices.length === 0 || root.isBusy) return;
        for (var i = 0; i < _devices.length; i++) {
            root.ejectDevice(_devices[i].name);
        }
    }

    function openInFileManager(mountpoint) {
        if (mountpoint) {
            Qt.openUrlExternally("file://" + mountpoint);
        }
    }

    // ── Live Event Stream (Zero-Polling UDev Monitor) ───────────────────────
    Timer {
        id: udevDebounceTimer
        interval: 350
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: udevWatcher
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block"]
        running: true
        stdout: StdioCollector {
            onRead: function(data) {
                if (data && (data.indexOf("add") !== -1 || data.indexOf("remove") !== -1 || data.indexOf("change") !== -1)) {
                    udevDebounceTimer.restart();
                }
            }
        }
    }

    // ── Lazy Safety Fallback Timer ──────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: root.pollIntervalMs
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // ── Processes ───────────────────────────────────────────────────────────
    TimedProcess {
        id: refreshProc
        timeoutMs: 8000
        timeoutLabel: "USBRefresh"
        stdout: StdioCollector {
            onStreamFinished: {
                root._refreshing = false;
                try {
                    var cleanText = text ? text.trim() : "";
                    var match = cleanText.match(/\[[\s\S]*\]/);
                    if (match) cleanText = match[0];

                    if (cleanText === "" || cleanText === "[]") {
                        if (root._devices.length > 0) {
                            root._devices.forEach(function(dev) {
                                root.deviceRemoved(dev.name);
                            });
                        }
                        root._devices = [];
                        root.lastError = "";
                        return;
                    }

                    var parsed = JSON.parse(cleanText);
                    if (Array.isArray(parsed)) {
                        var oldNames = root._devices.map(function(d) { return d.name; });
                        var newNames = parsed.map(function(d) { return d.name; });

                        parsed.forEach(function(dev) {
                            if (oldNames.indexOf(dev.name) === -1) {
                                root.deviceAdded(dev);
                            }
                        });

                        root._devices.forEach(function(dev) {
                            if (newNames.indexOf(dev.name) === -1) {
                                root.deviceRemoved(dev.name);
                            }
                        });

                        root._devices = parsed;
                        root.lastError = "";
                    }
                } catch (e) {
                    Logger.warn("USBService", "Failed to parse USB devices: " + e);
                }
            }
        }
        onExited: function(code) {
            root._refreshing = false;
        }
    }

    TimedProcess {
        id: ejectProc
        timeoutMs: 15000
        timeoutLabel: "USBEject"
        property string targetDevice: ""
        property string parentDisk: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root._ejecting = false;
                var dev = ejectProc.targetDevice;
                var parent = ejectProc.parentDisk;
                root._setDeviceBusy(dev, false);
                if (parent) root._setDeviceBusy(parent, false);

                var out = text ? text.trim() : "";
                if (out.indexOf("EJECT_FAILED") !== -1) {
                    root.lastError = "Falha ao ejetar " + dev;
                    root.ejectFailed(dev, out);
                } else {
                    root.lastError = "";
                    root.ejectSuccess(dev);
                }
                root.refresh();
            }
        }
        onExited: function(code) {
            root._ejecting = false;
            root._setDeviceBusy(ejectProc.targetDevice, false);
            if (ejectProc.parentDisk) root._setDeviceBusy(ejectProc.parentDisk, false);
            root.refresh();
        }
    }

    TimedProcess {
        id: mountProc
        timeoutMs: 10000
        timeoutLabel: "USBMount"
        property string targetDevice: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root._mounting = false;
                root._setDeviceBusy(mountProc.targetDevice, false);
                root.mountSuccess(mountProc.targetDevice);
                root.refresh();
            }
        }
        onExited: function(code) {
            root._mounting = false;
            root._setDeviceBusy(mountProc.targetDevice, false);
            if (code !== 0) {
                root.mountFailed(mountProc.targetDevice, "Exit code " + code);
            }
            root.refresh();
        }
    }

    TimedProcess {
        id: unmountProc
        timeoutMs: 10000
        timeoutLabel: "USBUnmount"
        property string targetDevice: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root._unmounting = false;
                root._setDeviceBusy(unmountProc.targetDevice, false);
                root.unmountSuccess(unmountProc.targetDevice);
                root.refresh();
            }
        }
        onExited: function(code) {
            root._unmounting = false;
            root._setDeviceBusy(unmountProc.targetDevice, false);
            if (code !== 0) {
                root.unmountFailed(unmountProc.targetDevice, "Exit code " + code);
            }
            root.refresh();
        }
    }

    Component.onCompleted: Qt.callLater(root.refresh)
}
