pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Item {
    id: root
    visible: false

    property bool active: false
    property var metrics: ({ "sclk": "0", "mclk": "0", "temp": 0, "power": 0, "load": 0 })
    // Smoothed scalars for binding (avoids binding to object keys directly)
    property real gpuLoad: 0.0
    property real gpuTemp: 0.0
    property real gpuPower: 0.0

    property bool refreshInFlight: false
    property bool refreshQueued: false
    property bool lastParseOk: false
    property int consecutiveFailures: 0
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
        MetricsTicker.active = root.active || SystemMetricsService.active;
    }

    Behavior on gpuLoad { enabled: root.active; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on gpuTemp { enabled: root.active; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    function parseMetrics(rawText) {
        var raw = String(rawText || "").trim();
        if (raw === "") return false;
        try {
            var parsed = JSON.parse(raw);
            if (!parsed || typeof parsed !== "object") return false;
            root.metrics = parsed;
            if (typeof parsed.load === "number") root.gpuLoad = parsed.load / 100.0;
            if (typeof parsed.temp === "number") root.gpuTemp = parsed.temp;
            if (typeof parsed.power === "number") root.gpuPower = parsed.power;
            return true;
        } catch (e) {
            return false;
        }
    }

    function markHealthy() {
        root.healthState = "ok";
        root.healthMessage = "";
    }

    function markDegraded(message) {
        var nextMessage = String(message || "metrics refresh failed");
        if (root.healthState !== "degraded" || root.healthMessage !== nextMessage) {
            Logger.warn("ExtendedMetricsService", "metrics degraded", {
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
                Logger.info("ExtendedMetricsService", "metrics recovered", {
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

    function refresh() {
        requestRefresh();
    }

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
            RuntimePaths.scriptFile("extended_metrics.sh")
        ], "extended metrics snapshot");
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
        timeoutLabel: "extended metrics snapshot"

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
