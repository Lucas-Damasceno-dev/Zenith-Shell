import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "../../core"
import "../../core/ConfirmationGate.js" as ConfirmationGate
import "../../core/HealthSummary.js" as HealthSummary
import "../../services"

AnimatedWindow {
    id: root

    anchors.top: true
    anchors.right: true

    implicitWidth: 400
    implicitHeight: 500

    glassRadius: 16
    glassBackground: ColorScheme.glassPopup
    glassBorderColor: ColorScheme.outlineVariant
    slideY: 12
    originY: 0.0
    originX: 1.0

    property var contextData: ({})
    readonly property string scriptsDir: RuntimePaths.quickshellScriptsDir
    property string dashboardError: ""
    property var binaryStatus: ({})
    property bool healthChecked: false
    property var recoveryState: ({ kind: "idle", scope: "", message: "", summary: "" })
    property var sanityIssues: []
    property var lastProcessFailure: ({})
    property string confirmingQuickFix: ""
    readonly property var healthSummary: HealthSummary.summarize({
        healthChecked: root.healthChecked,
        binaryStatus: root.binaryStatus,
        recoveryState: root.recoveryState,
        sanityIssues: root.sanityIssues,
        lastFailure: root.lastProcessFailure
    })

    property bool pomodoroRunning: false
    property int pomodoroPresetMinutes: 25
    property int pomodoroSecondsRemaining: pomodoroPresetMinutes * 60
    property int pomodoroCycleCount: 0

    function formatDuration(totalSec) {
        var sec = Math.max(0, Number(totalSec) || 0);
        var mm = Math.floor(sec / 60);
        var ss = sec % 60;
        return (mm < 10 ? "0" : "") + mm + ":" + (ss < 10 ? "0" : "") + ss;
    }

    function resetPomodoro(mins) {
        var value = Number(mins);
        if (!isFinite(value) || value <= 0) value = 25;
        pomodoroPresetMinutes = value;
        pomodoroSecondsRemaining = value * 60;
        pomodoroRunning = false;
    }

    function isSensitiveQuickFix(target) {
        return target === "network" || target === "portal" || target === "quickshell" || target === "hyprland";
    }

    function requestQuickFixConfirmation(target) {
        var result = ConfirmationGate.nextState(root.confirmingQuickFix, target);
        root.confirmingQuickFix = result.confirmingAction;
        if (!result.confirmed) {
            quickFixConfirmTimer.restart();
            return false;
        }
        quickFixConfirmTimer.stop();
        return true;
    }

    function runServiceAction(args, label) {
        dashboardError = "";
        lastProcessFailure = ({});
        dashboardActionProc.run(args, label || "dashboard action");
    }

    function nextAgendaHint() {
        if (agendaModel.count <= 0) return "Sem próximos eventos";
        var item = agendaModel.get(0);
        return (item.title || "Evento") + (item.when ? (" • " + item.when) : "");
    }

    function refreshDashboardData() {
        // serviceStatusProc is no longer needed (handled by contextDaemon)
        agendaProc.exec(["bash", RuntimePaths.scriptFile("dashboard_agenda.sh")]);
        metricsProc.exec(["bash", RuntimePaths.scriptFile("read_focus_metrics.sh")]);
    }

    onIsOpenChanged: if (!isOpen) confirmingQuickFix = ""

    ListModel { id: agendaModel }
    ListModel { id: metricsModel }

    // Removed serviceStatusProc and serviceModel - data comes from contextData

    TimedProcess {
        id: agendaProc
        stdout: StdioCollector {
            onStreamFinished: {
                agendaModel.clear();
                var lines = String(text || "").split(/\r?\n/);
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line === "") continue;
                    var parts = line.split("\t");
                    if (parts.length < 3) continue;
                    agendaModel.append({
                        source: parts[0],
                        title: parts[1],
                        when: parts[2]
                    });
                }
            }
        }
    }

    TimedProcess {
        id: metricsProc
        stdout: StdioCollector {
            onStreamFinished: {
                metricsModel.clear();
                try {
                    var parsed = JSON.parse(String(text || "{}"));
                    var topApps = parsed.topApps || [];
                    for (var i = 0; i < topApps.length && i < 5; i++) {
                        metricsModel.append({
                            app: topApps[i].app || "unknown",
                            minutes: Number(topApps[i].minutes || 0),
                            interruptions: Number(topApps[i].interruptions || 0)
                        });
                    }
                } catch (e) {}
            }
        }
    }

    CommandRunner {
        id: dashboardActionProc
        stdout: StdioCollector {
            onRead: {
                if (String(data || "").indexOf("ERROR:") >= 0)
                    root.dashboardError = String(data).trim();
            }
        }
        stderr: StdioCollector {
            onRead: {
                var msg = String(data || "").trim();
                if (msg !== "") root.dashboardError = msg;
            }
        }
        onSucceeded: function(label) {
            root.lastProcessFailure = ({});
            statusRefreshDelay.restart();
        }
        onFailed: function(exitCode, label) {
            var failureMessage = "Falha ao executar " + label + " (exit " + exitCode + ")";
            root.lastProcessFailure = {
                label: label,
                exitCode: exitCode,
                message: failureMessage
            };
            root.dashboardError = failureMessage;
            statusRefreshDelay.restart();
        }
        onTimedOut: function(label) {
            var timeoutMessage = "Tempo esgotado: " + label;
            root.lastProcessFailure = {
                label: label,
                timeout: true,
                message: timeoutMessage
            };
            root.dashboardError = timeoutMessage;
            statusRefreshDelay.restart();
        }
    }

    TimedProcess { id: pomodoroNotifyProc }

    Timer {
        interval: FeatureFlags.lowPowerUiMode ? (DesignTokens.pollSlowMs * 2) : DesignTokens.pollSlowMs
        repeat: true
        running: root.isOpen
        triggeredOnStart: true
        onTriggered: root.refreshDashboardData()
    }

    Timer {
        id: statusRefreshDelay
        interval: 1200
        repeat: false
        onTriggered: {
            if (root.isOpen)
                root.refreshDashboardData();
        }
    }

    Timer {
        id: quickFixConfirmTimer
        interval: 3000
        repeat: false
        onTriggered: root.confirmingQuickFix = ""
    }

    Timer {
        interval: 1000
        running: root.pomodoroRunning
        repeat: true
        onTriggered: {
            if (root.pomodoroSecondsRemaining > 0) {
                root.pomodoroSecondsRemaining -= 1;
                return;
            }
            root.pomodoroRunning = false;
            root.pomodoroCycleCount += 1;
            pomodoroNotifyProc.exec([
                "notify-send",
                "-a", "Pomodoro",
                "Sessão concluída",
                "Hora de pausar por 5 minutos."
            ]);
            root.resetPomodoro(5);
        }
    }

    Component.onCompleted: refreshDashboardData()

    Item {
        anchors.fill: parent
        anchors.topMargin: 52
        anchors.rightMargin: 12
        anchors.leftMargin: 12
        anchors.bottomMargin: 12

        Rectangle {
            id: dashCard
            anchors.fill: parent
            radius: root.glassRadius
            color: root.glassBackground
            border.color: root.glassBorderColor
            border.width: 1
        }

        Rectangle {
            anchors.fill: dashCard
            anchors.topMargin: 5
            radius: dashCard.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: -1
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 6
            clip: true
            contentHeight: mainLayout.implicitHeight + 24
            boundsMovement: Flickable.StopAtBounds

            ColumnLayout {
                id: mainLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 14
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                Text {
                    text: "Productivity Dashboard"
                    color: ColorScheme.text
                    font.bold: true
                    font.pixelSize: 16
                    font.family: "Inter"
                }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: Qt.formatDateTime(new Date(), "ddd, dd MMM  hh:mm")
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.5)
                    font.pixelSize: 10
                    font.family: "Inter"
                }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: healthRow.implicitHeight + 18
                    radius: 12
                    color: root.healthSummary.level === "degraded"
                        ? ColorScheme.withAlpha(ColorScheme.red, 0.10)
                        : (root.healthSummary.level === "ok"
                            ? ColorScheme.withAlpha(ColorScheme.green, 0.10)
                            : (root.healthSummary.level === "loading"
                                ? ColorScheme.withAlpha(ColorScheme.yellow, 0.10)
                                : ColorScheme.withAlpha(ColorScheme.text, 0.05)))
                    border.color: root.healthSummary.level === "degraded"
                        ? ColorScheme.withAlpha(ColorScheme.red, 0.24)
                        : (root.healthSummary.level === "loading"
                            ? ColorScheme.withAlpha(ColorScheme.yellow, 0.24)
                            : ColorScheme.withAlpha(ColorScheme.text, 0.12))
                    border.width: 1

                    RowLayout {
                        id: healthRow
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            color: root.healthSummary.level === "degraded"
                                ? ColorScheme.withAlpha(ColorScheme.red, 0.20)
                                : (root.healthSummary.level === "ok"
                                    ? ColorScheme.withAlpha(ColorScheme.green, 0.20)
                                    : (root.healthSummary.level === "loading"
                                        ? ColorScheme.withAlpha(ColorScheme.yellow, 0.20)
                                        : ColorScheme.withAlpha(ColorScheme.text, 0.12)))

                            Text {
                                anchors.centerIn: parent
                                text: root.healthSummary.level === "degraded"
                                    ? "\u{f071}"
                                    : (root.healthSummary.level === "ok"
                                        ? "\u{f058}"
                                        : (root.healthSummary.level === "loading" ? "\u{f110}" : "\u{f059}"))
                                color: root.healthSummary.level === "degraded"
                                    ? ColorScheme.red
                                    : (root.healthSummary.level === "ok"
                                        ? ColorScheme.green
                                        : (root.healthSummary.level === "loading" ? ColorScheme.yellow : ColorScheme.text))
                                font.pixelSize: 13
                                font.family: DesignTokens.fontFamilyMono
                                renderType: Text.NativeRendering
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: root.healthSummary.headline
                                color: ColorScheme.text
                                font.pixelSize: 12
                                font.bold: true
                                font.family: "Inter"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: root.healthSummary.detail !== ""
                                text: root.healthSummary.detail
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.65)
                                font.pixelSize: 9
                                font.family: "Inter"
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        ColumnLayout {
                            visible: root.healthSummary.missing.length > 0 || !root.healthSummary.healthChecked
                            spacing: 2
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: root.healthSummary.missing.length > 0
                                    ? root.healthSummary.missing.length + " ausentes"
                                    : (root.healthSummary.healthChecked ? "Verificado" : "Aguardando")
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.72)
                                font.pixelSize: 10
                                font.family: "Inter"
                                font.weight: Font.DemiBold
                            }

                            Text {
                                visible: root.lastProcessFailure && root.lastProcessFailure.label
                                text: "Falha recente"
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                                font.pixelSize: 8
                                font.family: "Inter"
                            }
                        }
                    }
                }

                // --- Project Context Notes ---
                ColumnLayout {
                    visible: root.contextData && root.contextData.notes && root.contextData.notes !== ""
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: ColorScheme.glassBorder
                        opacity: 0.5
                    }

                    RowLayout {
                        spacing: 6
                        Text {
                            text: (root.contextData.icon || "") + "  Project Notes"
                            color: ColorScheme.accent
                            font.pixelSize: 11
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Text {
                            text: root.contextData.path ? "(" + root.contextData.path.split("/").pop() + ")" : ""
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.5)
                            font.pixelSize: 10
                            font.family: "Inter"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: notesText.implicitHeight + 16
                        radius: 8
                        color: ColorScheme.withAlpha(ColorScheme.yellow, 0.12)
                        border.color: ColorScheme.withAlpha(ColorScheme.yellow, 0.25)
                        border.width: 1

                        Text {
                            id: notesText
                            anchors.fill: parent
                            anchors.margins: 8
                            text: root.contextData.notes || ""
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.9)
                            font.pixelSize: 10
                            font.family: "Inter"
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Text {
                    visible: root.dashboardError !== ""
                    text: root.dashboardError
                    color: ColorScheme.peach
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: ColorScheme.glassBorder
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Quick fixes"
                        color: ColorScheme.text
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "Inter"
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 8
                        rowSpacing: 8

                    Repeater {
                        model: [
                            { label: "Rede", target: "network" },
                            { label: "Áudio", target: "audio" },
                            { label: "Portal", target: "portal" },
                            { label: "Quickshell", target: "quickshell" },
                            { label: "Hyprland", target: "hyprland" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool requiresConfirm: root.isSensitiveQuickFix(modelData.target)
                            readonly property bool confirmArmed: root.confirmingQuickFix === modelData.target
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 9
                            color: confirmArmed || quickFixMa.containsMouse
                                ? ColorScheme.withAlpha(ColorScheme.accent, 0.22)
                                : ColorScheme.glassCard
                            border.color: confirmArmed
                                ? ColorScheme.accent
                                : ColorScheme.withAlpha(ColorScheme.accent, 0.16)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: confirmArmed ? "Confirmar?" : modelData.label
                                color: confirmArmed
                                    ? ColorScheme.accent
                                    : ColorScheme.withAlpha(ColorScheme.text, 0.92)
                                font.pixelSize: 10
                                font.family: "Inter"
                                font.weight: Font.Medium
                            }

                                MouseArea {
                                    id: quickFixMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (requiresConfirm && !root.requestQuickFixConfirmation(modelData.target))
                                            return;
                                        var payload = JSON.stringify({ action: "quick_fix", target: modelData.target });
                                        root.runServiceAction([
                                            "bash",
                                            RuntimePaths.scriptFile("send_command.sh"),
                                            payload
                                        ], modelData.label);
                                        if (modelData.target === "quickshell")
                                            root.isOpen = false;
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: ColorScheme.glassBorder
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Critical user services"
                        color: ColorScheme.text
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "Inter"
                    }

                    Repeater {
                        model: root.contextData.services || []
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 9
                            color: ColorScheme.glassCard
                            border.color: ColorScheme.withAlpha(ColorScheme.text, 0.12)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8

                                Text {
                                    text: modelData.label || "Service"
                                    color: ColorScheme.withAlpha(ColorScheme.text, 0.95)
                                    font.pixelSize: 10
                                    font.family: "Inter"
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.state || "unknown"
                                    color: (modelData.state === "active")
                                        ? ColorScheme.green
                                        : (modelData.state === "activating" ? ColorScheme.yellow : ColorScheme.red)
                                    font.pixelSize: 9
                                    font.family: "Inter"
                                }
                                Rectangle {
                                    width: 46
                                    height: 20
                                    radius: 8
                                    color: restartMa.containsMouse
                                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.24)
                                        : ColorScheme.glassCard
                                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.12)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Restart"
                                        color: ColorScheme.withAlpha(ColorScheme.text, 0.88)
                                        font.pixelSize: 8
                                        font.family: "Inter"
                                    }

                                    MouseArea {
                                        id: restartMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            // Call global IPC handler
                                            // The Dashboard is loaded dynamically, so we need to access ipcHandler from root context or pass it down
                                            // Assuming ipcHandler is available globally or we use Quickshell.ipc
                                            // Simpler: use the TimedProcess directly here or rely on the shellRoot function if accessible
                                            // Actually, we can use the same mechanism:
                                            
                                            // Send JSON directly to the socket helper
                                            var payload = JSON.stringify({ action: "restart_service", target: modelData.service });
                                            dashboardActionProc.exec([
                                                "bash",
                                                RuntimePaths.scriptFile("send_command.sh"),
                                                payload
                                            ]);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: ColorScheme.glassBorder
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Agenda / tasks (ICS + JSON)"
                        color: ColorScheme.text
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "Inter"
                    }

                    Text {
                        visible: agendaModel.count === 0
                        text: "Nenhum item em ~/.config/quickshell/agenda.json ou agenda.ics"
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.45)
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: agendaModel
                        delegate: Rectangle {
                            required property string source
                            required property string title
                            required property string when
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 9
                            color: ColorScheme.glassCard
                            border.color: ColorScheme.withAlpha(ColorScheme.text, 0.12)
                            border.width: 1

                            Column {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 5
                                spacing: 1

                                Text {
                                    text: title
                                    color: ColorScheme.withAlpha(ColorScheme.text, 0.95)
                                    font.pixelSize: 10
                                    font.family: "Inter"
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    text: (source === "ics" ? "ICS • " : "JSON • ") + (when || "sem data")
                                    color: ColorScheme.withAlpha(ColorScheme.text, 0.5)
                                    font.pixelSize: 9
                                    font.family: "Inter"
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: ColorScheme.glassBorder
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Focus sessions (Pomodoro)"
                        color: ColorScheme.text
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "Inter"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.formatDuration(root.pomodoroSecondsRemaining)
                            color: root.pomodoroRunning ? ColorScheme.accent : ColorScheme.text
                            font.pixelSize: 22
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Ciclos: " + root.pomodoroCycleCount
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.5)
                            font.pixelSize: 10
                            font.family: "Inter"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { label: root.pomodoroRunning ? "Pause" : "Start", action: "toggle" },
                                { label: "25m", action: "25" },
                                { label: "15m", action: "15" },
                                { label: "5m", action: "5" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                radius: 8
                                color: pomoMa.containsMouse
                                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.22)
                                    : ColorScheme.glassCard
                                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.12)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: ColorScheme.withAlpha(ColorScheme.text, 0.9)
                                    font.pixelSize: 10
                                    font.family: "Inter"
                                }

                                MouseArea {
                                    id: pomoMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.action === "toggle") {
                                            root.pomodoroRunning = !root.pomodoroRunning;
                                            if (root.pomodoroRunning) {
                                                dashboardActionProc.exec([
                                                    "notify-send",
                                                    "-a", "Pomodoro",
                                                    "Foco iniciado",
                                                    root.nextAgendaHint()
                                                ]);
                                            }
                                        } else {
                                            root.resetPomodoro(parseInt(modelData.action));
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "Próximo evento: " + root.nextAgendaHint()
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                        font.pixelSize: 9
                        font.family: "Inter"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: ColorScheme.glassBorder
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Personal metrics (focus tracker)"
                        color: ColorScheme.text
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "Inter"
                    }

                    Text {
                        visible: metricsModel.count === 0
                        text: "Sem métricas ainda (aguardando tracker)."
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.45)
                        font.pixelSize: 10
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: metricsModel
                        delegate: Rectangle {
                            required property string app
                            required property real minutes
                            required property int interruptions
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 8
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                            border.color: ColorScheme.withAlpha(ColorScheme.text, 0.12)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                Text {
                                    text: app
                                    color: ColorScheme.withAlpha(ColorScheme.text, 0.92)
                                    font.pixelSize: 10
                                    font.family: "Inter"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: Math.round(minutes) + "m • " + interruptions + " int."
                                    color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                                    font.pixelSize: 9
                                    font.family: "Inter"
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
