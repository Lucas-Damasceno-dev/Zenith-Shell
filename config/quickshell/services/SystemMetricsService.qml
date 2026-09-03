pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Item {
    id: root
    visible: false

    // Consumers set active=true when they need data (e.g. HardwareMonitors visible).
    // When no consumer needs metrics, polling stops entirely → zero bash spawns.
    property bool active: false

    property real cpuUsage: 0
    property real ramUsage: 0
    property real ramUsedMB: 0
    property real ramTotalMB: 0
    property string ramFormatted: ""
    property real gpuUsage: 0
    property int temperatureC: 0
    property string diskRootUsage: "--"
    property string diskHomeUsage: "--"

    // Rolling history arrays for sparklines (max 40 points)
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistory: []
    readonly property int historyMaxLen: 40

    // In-memory CPU delta tracker (zero disk I/O)
    property real prevCpuTotal: 0
    property real prevCpuIdle: 0

    property int consecutiveFailures: 0
    property bool refreshInFlight: false
    property bool refreshQueued: false
    property bool lastParseOk: false
    property string healthState: "idle"
    property string healthMessage: ""
    property real nextRefreshAtMs: 0

    readonly property string scriptsDir: RuntimePaths.quickshellScriptsDir
    readonly property int basePollIntervalMs: FeatureFlags.lowPowerUiMode ? 10000 : 5000
    readonly property int pollIntervalMs: consecutiveFailures <= 0
        ? basePollIntervalMs
        : metricsProc.backoffDelayMs(consecutiveFailures)
    readonly property int refreshDebounceMs: FeatureFlags.lowPowerUiMode ? 250 : 120

    function nowMs() {
        return new Date().getTime();
    }

    function scheduleNextRefresh() {
        root.nextRefreshAtMs = root.nowMs() + root.pollIntervalMs;
    }

    function syncTickerActive() {
        MetricsTicker.active = root.active || ExtendedMetricsService.active;
    }

    function appendHistory(arr, val) {
        var copy = arr.slice();
        copy.push(val);
        if (copy.length > historyMaxLen) copy.splice(0, copy.length - historyMaxLen);
        return copy;
    }

    function parseMetrics(rawText) {
        var lines = String(rawText || "").split(/\r?\n/);
        var sawMetric = false;
        var curCpuTotal = 0;
        var curCpuIdle = 0;
        var ramUsed = 0;
        var ramTotal = 0;
        var directCpu = -1;

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            var idx = line.indexOf("=");
            if (idx <= 0) continue;
            var key = line.substring(0, idx).trim();
            var val = Number(line.substring(idx + 1).trim());
            if (!isFinite(val)) continue;

            if (key === "cpu_total") {
                curCpuTotal = val;
            } else if (key === "cpu_idle") {
                curCpuIdle = val;
            } else if (key === "cpu") {
                directCpu = val;
            } else if (key === "ram") {
                root.ramUsage = Math.max(0, Math.min(1, val / 100));
                root.ramHistory = root.appendHistory(root.ramHistory, root.ramUsage);
                sawMetric = true;
            } else if (key === "ram_used_mb") {
                ramUsed = val;
            } else if (key === "ram_total_mb") {
                ramTotal = val;
            } else if (key === "gpu") {
                root.gpuUsage = Math.max(0, Math.min(1, val / 100));
                root.gpuHistory = root.appendHistory(root.gpuHistory, root.gpuUsage);
                sawMetric = true;
            } else if (key === "temp") {
                root.temperatureC = Math.max(0, Math.round(val));
                sawMetric = true;
            }
        }

        // Process in-memory CPU delta if total and idle ticks are available
        if (curCpuTotal > 0 && curCpuIdle > 0) {
            if (root.prevCpuTotal > 0 && curCpuTotal > root.prevCpuTotal) {
                var diffTotal = curCpuTotal - root.prevCpuTotal;
                var diffIdle = curCpuIdle - root.prevCpuIdle;
                if (diffTotal > 0) {
                    var calculatedUsage = Math.max(0, Math.min(1, (diffTotal - diffIdle) / diffTotal));
                    root.cpuUsage = calculatedUsage;
                    root.cpuHistory = root.appendHistory(root.cpuHistory, root.cpuUsage);
                }
            } else if (directCpu >= 0) {
                root.cpuUsage = Math.max(0, Math.min(1, directCpu / 100));
                root.cpuHistory = root.appendHistory(root.cpuHistory, root.cpuUsage);
            }
            root.prevCpuTotal = curCpuTotal;
            root.prevCpuIdle = curCpuIdle;
            sawMetric = true;
        } else if (directCpu >= 0) {
            root.cpuUsage = Math.max(0, Math.min(1, directCpu / 100));
            root.cpuHistory = root.appendHistory(root.cpuHistory, root.cpuUsage);
            sawMetric = true;
        }

        // Format RAM string
        if (ramUsed > 0 && ramTotal > 0) {
            root.ramUsedMB = ramUsed;
            root.ramTotalMB = ramTotal;
            var usedGB = (ramUsed / 1024).toFixed(1);
            var totalGB = (ramTotal / 1024).toFixed(1);
            root.ramFormatted = usedGB + " / " + totalGB + " GB";
        }

        return sawMetric;
    }

    function parseDiskUsage(rawText) {
        var lines = String(rawText || "").split(/\r?\n/);
        var nextRoot = "--";
        var nextHome = "--";

        for (var i = 0; i < lines.length; i++) {
            var line = String(lines[i] || "").trim();
            if (line.indexOf("root=") === 0) {
                var rootValue = String(line.substring(5) || "").trim();
                if (rootValue !== "")
                    nextRoot = rootValue;
            } else if (line.indexOf("home=") === 0) {
                var homeValue = String(line.substring(5) || "").trim();
                if (homeValue !== "")
                    nextHome = homeValue;
            }
        }

        root.diskRootUsage = nextRoot;
        root.diskHomeUsage = nextHome;
    }

    function markHealthy() {
        root.healthState = "ok";
        root.healthMessage = "";
    }

    function markDegraded(message) {
        var nextMessage = String(message || "metrics refresh failed");
        if (root.healthState !== "degraded" || root.healthMessage !== nextMessage) {
            Logger.warn("SystemMetricsService", "metrics degraded", {
                reason: nextMessage,
                failures: root.consecutiveFailures,
                retryInMs: root.pollIntervalMs
            });
        }
        root.healthState = "degraded";
        root.healthMessage = nextMessage;
    }

    function finishRefresh(success, message) {
        root.refreshInFlight = false;
        if (!root.active) {
            root.refreshQueued = false;
            return;
        }
        if (success) {
            if (root.consecutiveFailures > 0) {
                Logger.info("SystemMetricsService", "metrics recovered", {
                    failures: root.consecutiveFailures
                });
            }
            root.consecutiveFailures = 0;
            root.markHealthy();
        } else {
            root.consecutiveFailures += 1;
            root.markDegraded(message);
        }

        root.scheduleNextRefresh();

        if (root.refreshQueued) {
            root.refreshQueued = false;
            refreshDebounce.restart();
        }
    }

    function requestRefresh() {
        if (!root.active) return;
        if (root.refreshInFlight) {
            root.refreshQueued = true;
            return;
        }
        refreshDebounce.restart();
    }

    function refreshNow() {
        requestRefresh();
    }

    property int diskRefreshTick: 0

    function performRefresh() {
        if (!root.active) return;
        if (root.refreshInFlight) {
            root.refreshQueued = true;
            return;
        }
        root.refreshQueued = false;
        root.refreshInFlight = true;
        root.lastParseOk = false;
        metricsProc.run([
            "bash",
            RuntimePaths.scriptFile("system_metrics_snapshot.sh")
        ], "system metrics snapshot");

        root.diskRefreshTick++;
        if (root.diskRefreshTick % 12 === 1 || root.diskRootUsage === "--") {
            diskProc.exec([
                "bash",
                RuntimePaths.scriptFile("disk_usage.sh")
            ]);
        }
    }

    onActiveChanged: {
        if (root.active) {
            root.healthState = "starting";
            root.healthMessage = "";
            root.consecutiveFailures = 0;
            root.nextRefreshAtMs = 0;
            root.requestRefresh();
        } else {
            root.healthState = "idle";
            root.healthMessage = "";
            root.refreshInFlight = false;
            root.refreshQueued = false;
            refreshDebounce.stop();
            root.nextRefreshAtMs = 0;
        }
        root.syncTickerActive();
    }

    TimedProcess {
        id: metricsProc
        timeoutMs: 12000
        timeoutLabel: "system metrics snapshot"

        stdout: StdioCollector {
            onStreamFinished: root.lastParseOk = root.parseMetrics(text)
        }

        onSucceeded: {
            root.finishRefresh(root.lastParseOk, root.lastParseOk ? "" : "invalid metrics payload")
        }
        onFailed: function(exitCode) {
            root.finishRefresh(false, "exit code " + exitCode)
        }
        onTimedOut: {
            root.finishRefresh(false, "timeout")
        }
    }

    TimedProcess {
        id: diskProc
        timeoutMs: 8000
        timeoutLabel: "disk usage snapshot"

        stdout: StdioCollector {
            onStreamFinished: root.parseDiskUsage(text)
        }
    }

    Connections {
        target: MetricsTicker
        function onTickStampChanged() {
            if (!root.active) return;
            if (root.nextRefreshAtMs <= 0 || root.nowMs() >= root.nextRefreshAtMs)
                root.requestRefresh();
        }
    }

    Timer {
        id: refreshDebounce
        interval: root.refreshDebounceMs
        repeat: false
        onTriggered: root.performRefresh()
    }

    Component.onCompleted: root.syncTickerActive()
}
