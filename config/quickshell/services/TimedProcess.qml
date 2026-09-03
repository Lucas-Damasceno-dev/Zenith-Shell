import QtQuick
import Quickshell.Io
import "../core"

Item {
    id: root
    visible: false

    property int timeoutMs: 20000
    property int terminateSignal: 15
    property int forceSignal: 9
    property int forceDelayMs: 1200
    property string timeoutLabel: ""
    property int backoffBaseDelayMs: 5000
    property int backoffMaxDelayMs: 60000
    property int backoffFailureThreshold: 3
    property int failureCount: 0
    property int lastExitCode: 0
    property string lastError: ""
    property bool timeoutTriggered: false
    property bool cancelRequested: false

    property alias command: proc.command
    property alias running: proc.running
    property alias stdout: proc.stdout
    property alias stderr: proc.stderr
    property alias processId: proc.processId

    readonly property bool timeoutEnabled: timeoutMs > 0

    signal succeeded(string label)
    signal failed(int exitCode, string label)
    signal timedOut(string label)
    signal started()
    signal exited(int exitCode)

    function timeoutName() {
        if (timeoutLabel !== "")
            return timeoutLabel;
        if (command && command.length > 0)
            return String(command[0]);
        return "process";
    }

    function backoffDelayMs(failures) {
        var count = Number(failures || 0);
        if (!isFinite(count) || count <= 0)
            return backoffBaseDelayMs;

        // Exponential backoff: base * 2^(n-1)
        // e.g., 5s → 10s → 20s → 40s → 60s (capped)
        var exponent = Math.min(count - 1, 5); // Cap exponent to prevent overflow
        var exponential = backoffBaseDelayMs * Math.pow(2, exponent);
        var capped = Math.min(backoffMaxDelayMs, exponential);

        // Add ±20% jitter to prevent thundering herd when multiple
        // daemons/services fail and restart simultaneously
        var jitter = (Math.random() - 0.5) * 0.4 * capped; // ±20%
        return Math.max(backoffBaseDelayMs, Math.round(capped + jitter));
    }

    function run(args, label) {
        if (label !== undefined && label !== null && String(label) !== "")
            timeoutLabel = String(label);
        exec(args);
    }

    function exec(args) {
        if (proc.running) {
            cancelRequested = true;
        }
        if (args !== undefined && args !== null) {
            proc.command = args;
        }
        proc.running = false;
        proc.running = true;
    }

    function kill() {
        cancelRequested = true;
        timeoutTimer.stop();
        forceTimer.stop();
        if (proc && proc.kill) {
            proc.kill();
        } else if (proc && proc.signal) {
            proc.signal(root.terminateSignal);
        }
    }

    function cancel() {
        kill();
    }

    Connections {
        target: proc

        function onStarted() {
            root.timeoutTriggered = false;
            root.cancelRequested = false;
            root.lastError = "";
            root.lastExitCode = 0;
            if (root.timeoutEnabled)
                timeoutTimer.restart();
            root.started();
        }

        function onExited(code) {
            timeoutTimer.stop();
            forceTimer.stop();

            var exitCode = Number(code);
            if (!isFinite(exitCode))
                exitCode = 0;

            root.lastExitCode = exitCode;

            if (root.cancelRequested || exitCode === root.terminateSignal || exitCode === root.forceSignal) {
                root.cancelRequested = false;
                root.lastError = "cancelled";
                root.exited(exitCode);
                return;
            }

            if (root.timeoutTriggered) {
                root.timeoutTriggered = false;
                root.exited(exitCode);
                return;
            }

            if (exitCode === 0) {
                if (root.failureCount > 0) {
                    Logger.info("TimedProcess", "recovered", {
                        label: root.timeoutName(),
                        failures: root.failureCount
                    });
                }
                root.failureCount = 0;
                root.lastError = "";
                root.succeeded(root.timeoutName());
                EventBus.process.publishSucceeded({
                    label: root.timeoutName(),
                    exitCode: exitCode,
                    pid: root.processId
                });
                root.exited(exitCode);
                return;
            }

            root.failureCount += 1;
            root.lastError = "exit-code";
            Logger.warn("TimedProcess", "process failed", {
                label: root.timeoutName(),
                exitCode: exitCode,
                failures: root.failureCount,
                pid: root.processId
            });
            root.failed(exitCode, root.timeoutName());
            EventBus.process.publishFailed({
                label: root.timeoutName(),
                exitCode: exitCode,
                failures: root.failureCount,
                pid: root.processId
            });
            root.exited(exitCode);
        }
    }

    Timer {
        id: timeoutTimer
        interval: root.timeoutMs
        repeat: false
        running: false
        onTriggered: {
            if (!root.running)
                return;

            root.timeoutTriggered = true;
            root.failureCount += 1;
            root.lastExitCode = -1;
            root.lastError = "timeout";
            Logger.warn("TimedProcess", "process timed out", {
                label: root.timeoutName(),
                timeoutMs: root.timeoutMs,
                failures: root.failureCount,
                pid: root.processId
            });
            root.timedOut(root.timeoutName());
            EventBus.process.publishTimeout({
                label: root.timeoutName(),
                timeoutMs: root.timeoutMs,
                pid: root.processId
            });
            proc.signal(root.terminateSignal);
            forceTimer.restart();
        }
    }

    Timer {
        id: forceTimer
        interval: root.forceDelayMs
        repeat: false
        running: false
        onTriggered: {
            if (!root.running)
                return;
            Logger.warn("TimedProcess", "force signal sent", {
                label: root.timeoutName(),
                signal: root.forceSignal,
                pid: root.processId
            });
            proc.signal(root.forceSignal);
        }
    }

    Process {
        id: proc
    }
}
