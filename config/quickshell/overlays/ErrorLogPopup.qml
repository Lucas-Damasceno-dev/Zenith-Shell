import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "../core"
import "../services"

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

    property int issueCount: 0
    property string latestSnapshot: ""
    property var sanityIssues: []
    property var recoveryState: ({ kind: "idle", scope: "", message: "", summary: "" })
    property real popupMargin: DesignTokens.spacingLG
    readonly property string scriptsDir: RuntimePaths.quickshellScriptsDir

    ListModel { id: logModel }

    function refreshLogs() {
        logLoader.exec([
            "bash",
            RuntimePaths.scriptFile("error_log_snapshot.sh")
        ]);
    }

    function appendIssueLine(text) {
        logModel.insert(0, {
            line: text,
            issue: true
        });
        root.issueCount += 1;
        if (logModel.count > 260) logModel.remove(logModel.count - 1);
    }

    function isIssueLine(lineText) {
        var l = String(lineText || "").toLowerCase();
        if (l.indexOf("debug qml: [colorscheme] error:") >= 0) return false;
        if (l.indexOf("could not load icon") >= 0) return false;
        if (l.indexOf("utility_screenshot.sh: line") >= 0 && l.indexOf("grim: command not found") >= 0) return false;
        if (l.indexOf("capture inválida (wayland/seleção)") >= 0) return false;
        if (l.indexOf("failed with result 'exit-code'") >= 0) return false;
        return l.indexOf("warn") >= 0
            || l.indexOf("error") >= 0
            || l.indexOf("failed") >= 0
            || l.indexOf("falha") >= 0
            || l.indexOf("cannot") >= 0
            || l.indexOf("traceback") >= 0
            || l.indexOf("exception") >= 0;
    }

    function parseLogs(rawText) {
        logModel.clear();
        issueCount = 0;
        latestSnapshot = "";

        if (root.recoveryState && root.recoveryState.kind && root.recoveryState.kind !== "idle" && root.recoveryState.kind !== "ready") {
            var recoverySummary = root.recoveryState.summary || root.recoveryState.message || root.recoveryState.scope || "unknown";
            logModel.append({
                line: "[RECOVERY][" + root.recoveryState.kind + "] " + recoverySummary,
                issue: root.recoveryState.kind !== "loading"
            });
            if (root.recoveryState.kind !== "loading")
                issueCount += 1;
        }

        // Insert sanity issues at the top
        if (root.sanityIssues && root.sanityIssues.length > 0) {
            for (var s = 0; s < root.sanityIssues.length; s++) {
                logModel.append({
                    line: "[CRITICAL SANITY FAILURE] " + root.sanityIssues[s],
                    issue: true
                });
                issueCount++;
            }
        }

        var text = String(rawText || "");
        var start = text.indexOf("__LOG_BEGIN__");
        var end = text.indexOf("__LOG_END__");
        if (start < 0 || end <= start) return;

        var payload = text.substring(start + "__LOG_BEGIN__".length, end);
        latestSnapshot = payload;
        var lines = payload.split(/\r?\n/);
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (!line || line.trim() === "") continue;
            var issue = isIssueLine(line);
            if (issue) issueCount += 1;
            logModel.append({ line: line, issue: issue });
        }
    }

    onIsOpenChanged: if (isOpen) refreshLogs()
    onRecoveryStateChanged: if (root.isOpen) refreshLogs()

    function copyLogs() {
        if (latestSnapshot.trim() === "") {
            refreshLogs();
            return;
        }
        copyProc.exec([
            "bash",
            RuntimePaths.scriptFile("utility_copy_text.sh"),
            latestSnapshot
        ]);
        notifyProc.exec([
            "notify-send",
            "-a", "Error Panel",
            "Logs copiados",
            "Snapshot atual copiado para o clipboard."
        ]);
    }

    function explainIssue() {
        if (latestSnapshot.trim() === "") return;
        aiProc.exec([
            "bash",
            RuntimePaths.scriptFile("launcher_ai_assist.sh"),
            "explain_error",
            latestSnapshot
        ]);
        notifyProc.exec([
            "notify-send",
            "-a", "Quickshell AI",
            "Analisando erro...",
            "Aguarde a resposta do assistente."
        ]);
    }

    Connections {
        target: EventBus.process
        function onTimeout(payload) {
            var label = payload && payload.label ? String(payload.label) : "process";
            appendIssueLine("[TimedProcess timeout] " + label);
        }
    }

    Connections {
        target: EventBus.component
        function onLoadFailure(payload) {
            var comp = payload && payload.label ? String(payload.label) : "component";
            appendIssueLine("[Component load failure] " + comp);
        }
    }

    Connections {
        target: EventBus.performance
        function onBudgetMeasured(payload) {
            var cpu = payload && payload.cpu !== undefined ? payload.cpu : "?";
            var mem = payload && payload.mem !== undefined ? payload.mem : "?";
            appendIssueLine("[Performance budget] cpu=" + cpu + "% mem=" + mem + "%");
        }
    }

    Connections {
        target: EventBus.weather
        function onError(payload) {
            var provider = payload && payload.provider ? String(payload.provider) : "weather";
            var attempt = payload && payload.attempt !== undefined ? String(payload.attempt) : "?";
            var message = payload && payload.message ? String(payload.message) : "unknown error";
            appendIssueLine("[Weather error][" + provider + "][attempt " + attempt + "] " + message);
        }
    }

    TimedProcess {
        id: logLoader
        stdout: StdioCollector { onStreamFinished: root.parseLogs(text) }
    }
    TimedProcess { id: copyProc }
    TimedProcess { id: notifyProc }
    TimedProcess { id: aiProc }

    Timer {
        interval: 20000
        repeat: true
        running: root.isOpen
        triggeredOnStart: true
        onTriggered: root.refreshLogs()
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
        width: 500
        height: 460
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "\u{f188}  Error Panel"
                color: ColorScheme.text
                font.pixelSize: 15
                font.bold: true
                font.family: "Inter"
            }

            Rectangle {
                radius: 10
                color: root.issueCount > 0
                    ? ColorScheme.withAlpha(ColorScheme.red, 0.22)
                    : ColorScheme.withAlpha(ColorScheme.accent, 0.16)
                border.color: root.issueCount > 0
                    ? ColorScheme.withAlpha(ColorScheme.red, 0.45)
                    : ColorScheme.withAlpha(ColorScheme.accent, 0.35)
                border.width: 1
                height: 22
                width: issueBadgeText.implicitWidth + 14

                Text {
                    id: issueBadgeText
                    anchors.centerIn: parent
                    text: root.issueCount > 0 ? (root.issueCount + " issue(s)") : "clean"
                    color: root.issueCount > 0 ? ColorScheme.red : ColorScheme.accent
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "Inter"
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: explainText.implicitWidth + 20
                height: 28
                radius: 14
                visible: root.issueCount > 0
                color: explainMa.containsMouse
                    ? ColorScheme.withAlpha(ColorScheme.mauve, 0.24)
                    : ColorScheme.withAlpha(ColorScheme.surface, 0.35)
                Behavior on color { ColorAnimation { duration: 120 } }
                border.color: ColorScheme.withAlpha(ColorScheme.mauve, 0.3)
                border.width: 1

                Text {
                    id: explainText
                    anchors.centerIn: parent
                    text: "✨ AI Explain"
                    color: ColorScheme.mauve
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "Inter"
                }

                MouseArea {
                    id: explainMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.explainIssue()
                }
            }

            Rectangle {
                width: copyText.implicitWidth + 20
                height: 28
                radius: 14
                color: copyMa.containsMouse
                    ? ColorScheme.withAlpha(ColorScheme.blue, 0.24)
                    : ColorScheme.withAlpha(ColorScheme.surface, 0.35)
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: copyText
                    anchors.centerIn: parent
                    text: "Copy logs"
                    color: ColorScheme.blue
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "Inter"
                }

                MouseArea {
                    id: copyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyLogs()
                }
            }

            Rectangle {
                width: refreshText.implicitWidth + 20
                height: 28
                radius: 14
                color: refreshMa.containsMouse
                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.24)
                    : ColorScheme.withAlpha(ColorScheme.surface, 0.35)
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: refreshText
                    anchors.centerIn: parent
                    text: "Refresh"
                    color: ColorScheme.accent
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "Inter"
                }

                MouseArea {
                    id: refreshMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refreshLogs()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: ColorScheme.withAlpha(ColorScheme.surface, 0.20)
            border.color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
            border.width: 1

            ListView {
                anchors.fill: parent
                anchors.margins: 10
                model: logModel
                spacing: 4
                clip: true

                delegate: Rectangle {
                    width: ListView.view.width
                    height: lineText.implicitHeight + 8
                    radius: 6
                    color: issue
                        ? ColorScheme.withAlpha(ColorScheme.red, 0.14)
                        : ColorScheme.withAlpha(ColorScheme.surface, 0.16)
                    border.color: issue
                        ? ColorScheme.withAlpha(ColorScheme.red, 0.35)
                        : "transparent"
                    border.width: issue ? 1 : 0

                    Text {
                        id: lineText
                        anchors.fill: parent
                        anchors.margins: 6
                        text: line
                        wrapMode: Text.WrapAnywhere
                        color: issue ? ColorScheme.red : ColorScheme.withAlpha(ColorScheme.text, 0.82)
                        font.pixelSize: 10
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }
        }
    }
    }
}
