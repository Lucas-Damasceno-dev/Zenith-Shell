import QtQuick

Item {
    id: root
    visible: false

    property alias command: proc.command
    property alias running: proc.running
    property alias stdout: proc.stdout
    property alias stderr: proc.stderr
    property alias processId: proc.processId
    property alias timeoutMs: proc.timeoutMs
    property alias timeoutLabel: proc.timeoutLabel
    property alias terminateSignal: proc.terminateSignal
    property alias forceSignal: proc.forceSignal
    property alias forceDelayMs: proc.forceDelayMs
    property alias backoffBaseDelayMs: proc.backoffBaseDelayMs
    property alias backoffMaxDelayMs: proc.backoffMaxDelayMs
    property alias backoffFailureThreshold: proc.backoffFailureThreshold
    property alias failureCount: proc.failureCount
    property alias lastExitCode: proc.lastExitCode
    property alias lastError: proc.lastError
    property alias timeoutTriggered: proc.timeoutTriggered
    property alias cancelRequested: proc.cancelRequested

    readonly property bool timeoutEnabled: proc.timeoutEnabled

    signal succeeded(string label)
    signal failed(int exitCode, string label)
    signal timedOut(string label)
    signal started()
    signal exited(int exitCode)

    function run(args, label) {
        proc.run(args, label);
    }

    function exec(args) {
        proc.exec(args);
    }

    function kill() {
        proc.kill();
    }

    function cancel() {
        proc.cancel();
    }

    Connections {
        target: proc

        function onSucceeded(label) {
            root.succeeded(label);
        }

        function onFailed(exitCode, label) {
            root.failed(exitCode, label);
        }

        function onTimedOut(label) {
            root.timedOut(label);
        }

        function onStarted() {
            root.started();
        }

        function onExited(exitCode) {
            root.exited(exitCode);
        }
    }

    TimedProcess {
        id: proc
    }
}
