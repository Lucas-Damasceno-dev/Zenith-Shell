pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Io
import QtCore
import "../core/BatteryProfileParser.js" as BatteryProfileParser
import "../core"
Item {
    id: root
    visible: false

    readonly property string scriptsDir: RuntimePaths.quickshellScriptsDir
    readonly property string caffeinePidFile: RuntimePaths.runtimeFile("quickshell-caffeine.pid")
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.isPresent
    readonly property real batteryPercentRaw: hasBattery ? Number(battery.percentage) : -1
    readonly property int batteryPercentRawInt: hasBattery
        ? Math.round(Math.max(0, Math.min(100, batteryPercentRaw <= 1 ? batteryPercentRaw * 100 : batteryPercentRaw)))
        : -1
    readonly property int smartChargeThreshold: 80

    readonly property int batteryPercent: {
        if (batteryPercentRawInt === -1) return -1;
        // Aesthetic correction for the 80% health limit:
        // If limit is on and we are at 79%, show 80%
        if (limitActive && batteryPercentRawInt === 79) return 80;
        return batteryPercentRawInt;
    }

    property int cycleCount: -1
    property string wearText: "N/A"
    property int healthPct: -1
    property string modelName: "N/A"
    property string systemUptime: "N/A"
    property bool caffeineActive: false
    property bool limitActive: false
    property string powerProfile: ConfigFacade.batteryPowerProfile()
    property bool _waitingForLimit: false
    property bool _hardwareLimitActive: false

    function refreshUptime() {
        uptimeProc.exec([
            "bash",
            RuntimePaths.scriptFile("battery_info.sh"),
            "uptime"
        ]);
    }

    function refreshDetails() {
        refreshUptime();
        // We don't reset to N/A anymore to prevent flickering; values will update once process finished
        detailsProc.exec([
            "bash",
            RuntimePaths.scriptFile("battery_info.sh"),
            "details"
        ]);
        limitStatusProc.exec([
            "bash",
            RuntimePaths.scriptFile("battery_info.sh"),
            "limit-status"
        ]);
    }

    function refreshCaffeine() {
        caffeineStatusProc.exec([
            "bash",
            RuntimePaths.scriptFile("battery_info.sh"),
            "caffeine-status",
            caffeinePidFile
        ]);
    }

    function refreshPowerProfile() {
        profileStatusProc.exec([
            "powerprofilesctl",
            "get"
        ]);
    }

    function setPowerProfile(profileKey) {
        var next = String(profileKey || "").trim().toLowerCase();
        if (next !== "power-saver" && next !== "balanced" && next !== "performance")
            return;

        root.powerProfile = next;
        ConfigFacade.set("batteryPowerProfile", next);
        profileSetProc.exec([
            "powerprofilesctl",
            "set",
            next
        ]);
    }

    function cyclePowerProfile(stepUp) {
        var profiles = ["power-saver", "balanced", "performance"];
        var currentIdx = profiles.indexOf(String(root.powerProfile || "").toLowerCase());
        if (currentIdx < 0) currentIdx = 1;
        var nextIdx = (stepUp === undefined || stepUp === true)
            ? (currentIdx + 1) % profiles.length
            : (currentIdx - 1 + profiles.length) % profiles.length;
        var nextProfile = profiles[nextIdx];
        setPowerProfile(nextProfile);
        if (typeof shellRoot !== "undefined" && shellRoot && shellRoot.triggerPowerProfileOsd) {
            shellRoot.triggerPowerProfileOsd(nextProfile);
        }
    }

    function startCaffeine() {
        caffeineActionProc.exec([
            "bash",
            RuntimePaths.scriptFile("battery_info.sh"),
            "caffeine-start",
            caffeinePidFile
        ]);
    }

    function stopCaffeine() {
        caffeineActionProc.exec([
            "bash",
            RuntimePaths.scriptFile("battery_info.sh"),
            "caffeine-stop",
            caffeinePidFile
        ]);
    }

    function setCaffeineActive(enabled) {
        var next = enabled === true;
        if (root.caffeineActive === next) return;
        if (next) startCaffeine();
        else stopCaffeine();
    }

    function setLimitActive(enabled) {
        let nextIntent = enabled === true;
        if (root.limitActive === nextIntent && !_waitingForLimit) {
            if ((nextIntent && root._hardwareLimitActive === true) || (!nextIntent && root._hardwareLimitActive === false))
                return;
        }
        root.limitActive = nextIntent;

        if (nextIntent) {
            // User wants a limit: if below 80, don't lock hardware yet
            if (root.batteryPercentRawInt < smartChargeThreshold) {
                _waitingForLimit = true;
                limitActionProc.exec(["bash", RuntimePaths.scriptFile("battery_info.sh"), "limit-disable"]);
            } else {
                _waitingForLimit = false;
                limitActionProc.exec(["bash", RuntimePaths.scriptFile("battery_info.sh"), "limit-enable"]);
            }
        } else {
            // User disabled: stop waiting and disable hardware lock
            _waitingForLimit = false;
            limitActionProc.exec(["bash", RuntimePaths.scriptFile("battery_info.sh"), "limit-disable"]);
        }
    }

    function toggleLimit() {
        setLimitActive(!root.limitActive);
    }

    onBatteryPercentRawIntChanged: {
        root.batteryStateChanged(root.batteryPercent, root.battery && root.battery.state === 2);
        if (limitActive && _waitingForLimit && batteryPercentRawInt >= smartChargeThreshold) {
            _waitingForLimit = false;
            limitActionProc.exec(["bash", RuntimePaths.scriptFile("battery_info.sh"), "limit-enable"]);
        }
    }

    TimedProcess {
        id: limitStatusProc
        timeoutLabel: "battery limit status"
        stdout: StdioCollector {
            onStreamFinished: {
                let hwValue = text.trim() === "1";
                root._hardwareLimitActive = hwValue;
                // Only sync the UI (limitActive) with hardware if NOT in Smart Charge mode
                if (!root._waitingForLimit) {
                    root.limitActive = hwValue;
                }
            }
        }
    }

    TimedProcess {
        id: limitActionProc
        timeoutLabel: "battery limit action"
        onExited: root.refreshDetails()
    }

    TimedProcess {
        id: detailsProc
        timeoutLabel: "battery details"

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split(/\r?\n/);
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (line.indexOf("cycles=") === 0) {
                        var c = parseInt(line.substring(7).trim());
                        root.cycleCount = isNaN(c) ? -1 : c;
                    } else if (line.indexOf("health=") === 0) {
                        var healthText = line.substring(7).trim();
                        var hp = parseFloat(healthText);
                        root.healthPct = isNaN(hp) ? -1 : Math.round(hp);
                        if (healthText && healthText !== "N/A") {
                            root.wearText = healthText;
                        }
                    } else if (line.indexOf("wear=") === 0) {
                        var wearValue = line.substring(5).trim();
                        if (wearValue && wearValue !== "N/A") {
                            root.wearText = wearValue;
                        }
                    } else if (line.indexOf("model=") === 0) {
                        root.modelName = line.substring(6).trim() || "N/A";
                    }
                }
            }
        }
    }

    TimedProcess {
        id: uptimeProc
        timeoutLabel: "battery uptime"
        stdout: StdioCollector {
            onStreamFinished: {
                var clean = text.trim();
                if (clean.length > 0) root.systemUptime = clean;
            }
        }
    }

    TimedProcess {
        id: caffeineStatusProc
        timeoutLabel: "battery caffeine status"
        stdout: StdioCollector {
            onStreamFinished: root.caffeineActive = text.trim() === "1"
        }
    }

    TimedProcess {
        id: caffeineActionProc
        timeoutLabel: "battery caffeine action"
        onExited: root.refreshCaffeine()
    }

    TimedProcess {
        id: profileStatusProc
        timeoutLabel: "battery power profile"
        stdout: StdioCollector {
            onStreamFinished: {
                root.powerProfile = BatteryProfileParser.parsePowerProfile(text);
            }
        }
    }

    TimedProcess {
        id: profileSetProc
        timeoutLabel: "battery set power profile"
        onFailed: root.refreshPowerProfile()
    }

    property bool detailsActive: false

    onDetailsActiveChanged: {
        if (root.detailsActive) {
            root.refreshDetails();
            root.refreshCaffeine();
        }
    }

    // ─── Signals for external consumers ──────────────────────
    signal batteryStateChanged(int newPercent, bool isCharging)
    signal caffeineChanged(bool active)

    onCaffeineActiveChanged: root.caffeineChanged(caffeineActive)

    Connections {
        target: MinuteTicker
        function onMinuteStampChanged() {
            root.refreshUptime();
        }
    }

    Connections {
        target: root.hasBattery && root.battery ? root.battery : null
        function onStateChanged() {
            root.batteryStateChanged(root.batteryPercent, root.battery.state === 2); // 2 = Charging
            root.refreshPowerProfile();
            if (root.detailsActive) {
                root.refreshDetails();
                root.refreshCaffeine();
            }
        }
    }

    Component.onCompleted: {
        refreshDetails();
        refreshCaffeine();
        refreshPowerProfile();
    }
}
