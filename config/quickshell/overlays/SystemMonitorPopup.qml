import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "../core"
import "../services"
import "./SystemMonitorUtils.js" as SystemMonitorUtils

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
    property string activeTab: "processes" // processes | services
    property string sortMode: "cpu" // cpu | mem
    property string filterText: ""
    property string appliedFilterText: ""
    property string pendingKillPid: ""
    readonly property int processCount: procModel.count
    readonly property int serviceCount: serviceModel.count
    readonly property string diskRoot: {
        var val = String(SystemMetricsService.diskRootUsage || "").trim();
        return val !== "" ? val : "--";
    }
    readonly property string diskHome: {
        var val = String(SystemMetricsService.diskHomeUsage || "").trim();
        return val !== "" ? val : "--";
    }

    ListModel { id: procModel }
    ListModel { id: serviceModel }

    onIsOpenChanged: {
        if (isOpen) { outsideCloseEnabled = false; closeEnableTimer.restart(); } else { outsideCloseEnabled = false; }
        ExtendedMetricsService.active = isOpen;
    }

    Component.onCompleted: {
        sortMode = ConfigFacade.systemMonitorSortMode();
        filterText = ConfigFacade.systemMonitorFilter();
        activeTab = ConfigFacade.systemMonitorActiveTab();
        appliedFilterText = filterText.trim();
    }

    function cleanPath(p) {
        return SystemMonitorUtils.cleanPath(p);
    }

    function refreshProcesses() {
        procLoader.exec(SystemMonitorUtils.buildProcessCommand(
            RuntimePaths.scriptFile("system_monitor_processes.sh"),
            sortMode,
            appliedFilterText
        ));
    }

    function refreshServices() {
        serviceLoader.exec(SystemMonitorUtils.buildServiceCommand(
            RuntimePaths.scriptFile("system_monitor_services.sh")
        ));
    }

    function parseProcessRows(rawText) {
        procModel.clear();
        var rows = SystemMonitorUtils.parseProcessRows(rawText);
        for (var i = 0; i < rows.length; i++)
            procModel.append(rows[i]);
    }

    function parseServiceRows(rawText) {
        serviceModel.clear();
        var rows = SystemMonitorUtils.parseServiceRows(rawText);
        for (var i = 0; i < rows.length; i++)
            serviceModel.append(rows[i]);
    }

    function runSignal(pid, signalName) {
        if (!pid) return;
        taskKiller.exec(["kill", signalName, String(pid)]);
        pendingKillPid = "";
    }

    TimedProcess {
        id: procLoader
        stdout: StdioCollector {
            onRead: root.parseProcessRows(data)
            onStreamFinished: root.parseProcessRows(text)
        }
        stderr: StdioCollector {
            onRead: function(data) {
                Logger.warn("SystemMonitor", "Process stderr", String(data || "").trim());
            }
        }
    }

    TimedProcess {
        id: serviceLoader
        stdout: StdioCollector {
            onRead: root.parseServiceRows(data)
            onStreamFinished: root.parseServiceRows(text)
        }
        stderr: StdioCollector {
            onRead: function(data) {
                Logger.warn("SystemMonitor", "Service stderr", String(data || "").trim());
            }
        }
    }

    TimedProcess {
        id: taskKiller
        onExited: if (root.isOpen && root.activeTab === "processes") refreshProcesses()
    }
    TimedProcess {
        id: serviceAction
        onExited: if (root.isOpen && root.activeTab === "services") refreshServices()
    }
    TimedProcess { id: launchBtop; timeoutMs: 0 }

    Timer {
        id: closeEnableTimer
        interval: 400
        repeat: false
        onTriggered: root.outsideCloseEnabled = true
    }

    Timer {
        id: refreshTimer
        interval: FeatureFlags.lowPowerUiMode ? 9000 : 5000
        repeat: true
        running: root.isOpen
        triggeredOnStart: true
        onTriggered: {
            if (root.activeTab === "services") root.refreshServices();
            else root.refreshProcesses();
        }
    }

    Timer {
        id: killConfirmTimer
        interval: 3000
        repeat: false
        onTriggered: root.pendingKillPid = ""
    }

    Timer {
        id: filterDebounce
        interval: FeatureFlags.lowPowerUiMode ? 450 : 250
        repeat: false
        onTriggered: {
            var nextFilter = root.filterText.trim();
            if (root.appliedFilterText === nextFilter)
                return;
            root.appliedFilterText = nextFilter;
            if (root.isOpen && root.activeTab === "processes")
                root.refreshProcesses();
        }
    }

    onActiveTabChanged: {
        if (settingsStore && settingsStore.set)
            settingsStore.set("systemMonitorActiveTab", activeTab);
        if (!isOpen) return;
        if (activeTab === "services") refreshServices();
        else refreshProcesses();
    }

    onSortModeChanged: {
        if (settingsStore && settingsStore.set)
            settingsStore.set("systemMonitorSortMode", sortMode);
        if (root.isOpen && root.activeTab === "processes") refreshProcesses();
    }
    onFilterTextChanged: {
        if (settingsStore && settingsStore.set)
            settingsStore.set("systemMonitorFilter", filterText);
        filterDebounce.restart();
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
        width: 480
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "\u{f108}  System Monitor"
                color: ColorScheme.text
                font.pixelSize: 15
                font.bold: true
                font.family: DesignTokens.fontFamilyUI
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: quickRefreshMa.containsMouse
                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.24)
                    : ColorScheme.glassCard
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "\u{f2f1}"
                    color: ColorScheme.accent
                    font.pixelSize: 11
                    font.family: DesignTokens.fontFamilyMono
                    renderType: Text.NativeRendering
                }
                MouseArea {
                    id: quickRefreshMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.activeTab === "services") root.refreshServices();
                        else root.refreshProcesses();
                    }
                }
            }
            Rectangle {
                width: btopText.implicitWidth + 18
                height: 28
                radius: 14
                color: btopMa.containsMouse
                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.24)
                    : ColorScheme.glassCard
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    id: btopText
                    anchors.centerIn: parent
                    text: "Open btop"
                    color: ColorScheme.accent
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "Inter"
                }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: launchBtop.exec(["kitty", "--title", "System Monitor", "btop"])
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: SystemMetricsService.healthState === "degraded"
                || ExtendedMetricsService.healthState === "degraded"
            radius: 9
            implicitHeight: 30
            color: ColorScheme.withAlpha(ColorScheme.red, 0.10)
            border.width: 1
            border.color: ColorScheme.withAlpha(ColorScheme.red, 0.24)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: "\u{f071}"
                    color: ColorScheme.red
                    font.pixelSize: 12
                    font.family: DesignTokens.fontFamilyMono
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    text: SystemMetricsService.healthState === "degraded" && SystemMetricsService.healthMessage !== ""
                        ? SystemMetricsService.healthMessage
                        : (ExtendedMetricsService.healthState === "degraded" && ExtendedMetricsService.healthMessage !== ""
                            ? ExtendedMetricsService.healthMessage
                            : "System metrics degraded")
                    color: ColorScheme.text
                    font.pixelSize: 11
                    font.family: DesignTokens.fontFamilyUI
                    elide: Text.ElideRight
                }
            }
        }

        // ── Sparkline tiles: CPU / RAM / GPU / TEMP ─────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // CPU sparkline tile
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 9
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.24)
                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                border.width: 1
                clip: true

                Canvas {
                    id: cpuCanvas
                    anchors.fill: parent
                    property var history: SystemMetricsService.cpuHistory
                    property color accentColor: ColorScheme.accent
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var hist = history || [];
                        if (hist.length < 2) return;
                        var w = width, h = height;
                        var step = w / 39;
                        var grad = ctx.createLinearGradient(0, 0, 0, h);
                        grad.addColorStop(0, ColorScheme.withAlpha(accentColor, 0.3));
                        grad.addColorStop(1, "transparent");
                        ctx.beginPath(); ctx.moveTo(0, h);
                        for (var i = 0; i < hist.length; i++) ctx.lineTo(i * step, h - (hist[i] * h * 0.5));
                        ctx.lineTo((hist.length - 1) * step, h); ctx.closePath();
                        ctx.fillStyle = grad; ctx.fill();
                        ctx.beginPath(); ctx.lineWidth = 1.5; ctx.strokeStyle = accentColor; ctx.lineJoin = "round";
                        ctx.moveTo(0, h - (hist[0] * h * 0.5));
                        for (var j = 1; j < hist.length; j++) ctx.lineTo(j * step, h - (hist[j] * h * 0.5));
                        ctx.stroke();
                    }
                    Connections {
                        target: SystemMetricsService
                        enabled: root.isOpen
                        function onCpuHistoryChanged() { cpuCanvas.requestPaint(); }
                    }
                }
                
                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 8
                    anchors.topMargin: 6
                    text: "CPU"
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.65)
                    font.pixelSize: 10; font.family: "Inter"
                }
                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 8
                    anchors.topMargin: 6
                    text: Math.round(SystemMetricsService.cpuUsage * 100) + "%"
                    color: ColorScheme.accent
                    font.pixelSize: 13; font.bold: true; font.family: "Inter"
                }
            }

            // RAM sparkline tile
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 9
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.24)
                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                border.width: 1
                clip: true

                Canvas {
                    id: ramCanvas
                    anchors.fill: parent
                    property var history: SystemMetricsService.ramHistory
                    property color accentColor: ColorScheme.mauve
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var hist = history || [];
                        if (hist.length < 2) return;
                        var w = width, h = height;
                        var step = w / 39;
                        var grad = ctx.createLinearGradient(0, 0, 0, h);
                        grad.addColorStop(0, ColorScheme.withAlpha(accentColor, 0.3));
                        grad.addColorStop(1, "transparent");
                        ctx.beginPath(); ctx.moveTo(0, h);
                        for (var i = 0; i < hist.length; i++) ctx.lineTo(i * step, h - (hist[i] * h * 0.5));
                        ctx.lineTo((hist.length - 1) * step, h); ctx.closePath();
                        ctx.fillStyle = grad; ctx.fill();
                        ctx.beginPath(); ctx.lineWidth = 1.5; ctx.strokeStyle = accentColor; ctx.lineJoin = "round";
                        ctx.moveTo(0, h - (hist[0] * h * 0.5));
                        for (var j = 1; j < hist.length; j++) ctx.lineTo(j * step, h - (hist[j] * h * 0.5));
                        ctx.stroke();
                    }
                    Connections {
                        target: SystemMetricsService
                        enabled: root.isOpen
                        function onRamHistoryChanged() { ramCanvas.requestPaint(); }
                    }
                }
                
                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 8
                    anchors.topMargin: 6
                    text: "RAM"
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.65)
                    font.pixelSize: 10; font.family: "Inter"
                }
                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 8
                    anchors.topMargin: 6
                    text: Math.round(SystemMetricsService.ramUsage * 100) + "%"
                    color: ColorScheme.mauve
                    font.pixelSize: 13; font.bold: true; font.family: "Inter"
                }
            }

            // GPU sparkline tile
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 9
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.24)
                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                border.width: 1
                clip: true

                Canvas {
                    id: gpuCanvas
                    anchors.fill: parent
                    property var history: SystemMetricsService.gpuHistory
                    property color accentColor: ColorScheme.green
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var hist = history || [];
                        if (hist.length < 2) return;
                        var w = width, h = height;
                        var step = w / 39;
                        var grad = ctx.createLinearGradient(0, 0, 0, h);
                        grad.addColorStop(0, ColorScheme.withAlpha(accentColor, 0.3));
                        grad.addColorStop(1, "transparent");
                        ctx.beginPath(); ctx.moveTo(0, h);
                        for (var i = 0; i < hist.length; i++) ctx.lineTo(i * step, h - (hist[i] * h * 0.5));
                        ctx.lineTo((hist.length - 1) * step, h); ctx.closePath();
                        ctx.fillStyle = grad; ctx.fill();
                        ctx.beginPath(); ctx.lineWidth = 1.5; ctx.strokeStyle = accentColor; ctx.lineJoin = "round";
                        ctx.moveTo(0, h - (hist[0] * h * 0.5));
                        for (var j = 1; j < hist.length; j++) ctx.lineTo(j * step, h - (hist[j] * h * 0.5));
                        ctx.stroke();
                    }
                    Connections {
                        target: SystemMetricsService
                        enabled: root.isOpen
                        function onGpuHistoryChanged() { gpuCanvas.requestPaint(); }
                    }
                }
                
                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 8
                    anchors.topMargin: 6
                    text: "GPU"
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.65)
                    font.pixelSize: 10; font.family: "Inter"
                }
                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 8
                    anchors.topMargin: 6
                    text: Math.round(SystemMetricsService.gpuUsage * 100) + "%"
                    color: ColorScheme.green
                    font.pixelSize: 13; font.bold: true; font.family: "Inter"
                }
            }

            // TEMP tile (no sparkline — scalar only)
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 9
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.24)
                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                border.width: 1

                readonly property color tempColor: {
                    var t = SystemMetricsService.temperatureC;
                    if (t >= 80) return ColorScheme.red;
                    if (t >= 65) return ColorScheme.yellow;
                    return ColorScheme.teal;
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "TEMP"
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                        font.pixelSize: 9; font.family: "Inter"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: SystemMetricsService.temperatureC + "°C"
                        color: parent.parent.tempColor
                        font.pixelSize: 13; font.bold: true; font.family: "Inter"
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { label: "GPU CLK", value: ExtendedMetricsService.metrics.sclk + " MHz" },
                    { label: "GPU PWR", value: ExtendedMetricsService.metrics.power + " W" },
                    { label: "GPU TEMP", value: ExtendedMetricsService.metrics.temp + "°C" },
                    { label: "GPU LOAD", value: ExtendedMetricsService.metrics.load + "%" }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 28
                    radius: 9
                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.24)
                    border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                    border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4
                        Text {
                            text: modelData.label
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                            font.pixelSize: 9
                            font.family: "Inter"
                        }
                        Text {
                            text: modelData.value
                            color: ColorScheme.text
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Inter"
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { label: "DISK / (Use/Free)", value: root.diskRoot },
                    { label: "DISK /home (Used)", value: root.diskHome }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 28
                    radius: 9
                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.24)
                    border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                    border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4
                        Text {
                            text: modelData.label
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                            font.pixelSize: 9
                            font.family: "Inter"
                        }
                        Text {
                            text: modelData.value
                            color: ColorScheme.text
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Inter"
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { key: "processes", label: "Processes" },
                    { key: "services", label: "Services" }
                ]
                delegate: Rectangle {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 28
                    radius: 14
                    color: root.activeTab === modelData.key
                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.24)
                        : ColorScheme.withAlpha(ColorScheme.surface, 0.26)
                    border.color: root.activeTab === modelData.key ? ColorScheme.accent : "transparent"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: root.activeTab === modelData.key ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.75)
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Inter"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = modelData.key
                    }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.activeTab === "services"
                    ? (root.serviceCount + " services")
                    : (root.processCount + " processes")
                color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                font.pixelSize: 9
                font.family: "Inter"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.activeTab === "processes"
            spacing: 6

            TextField {
                Layout.fillWidth: true
                text: root.filterText
                placeholderText: "Filter process by name"
                onTextChanged: root.filterText = text
                color: ColorScheme.text
                font.pixelSize: 10
                font.family: "Inter"
                placeholderTextColor: ColorScheme.withAlpha(ColorScheme.text, 0.35)
                background: Rectangle {
                    radius: 8
                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.36)
                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.15)
                }
            }

            Rectangle {
                width: 88
                height: 30
                radius: 8
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.36)
                Text {
                    anchors.centerIn: parent
                    text: root.sortMode === "cpu" ? "Sort: CPU" : "Sort: MEM"
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.75)
                    font.pixelSize: 9
                    font.family: "Inter"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sortMode = root.sortMode === "cpu" ? "mem" : "cpu"
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: ColorScheme.withAlpha(ColorScheme.surface, 0.22)
            border.color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
            border.width: 1

            Loader {
                anchors.fill: parent
                anchors.margins: 10
                active: true
                asynchronous: true
                sourceComponent: root.activeTab === "services" ? serviceView : processView
            }
        }
    }

    Component {
        id: processView
        ListView {
            model: procModel
            spacing: 6
            clip: true
            cacheBuffer: FeatureFlags.lowPowerUiMode ? 96 : 192
            reuseItems: true
            delegate: Rectangle {
                width: ListView.view.width
                height: root.pendingKillPid === pid ? 56 : 34
                radius: 8
                color: procMa.containsMouse
                    ? ColorScheme.withAlpha(ColorScheme.surface, 0.38)
                    : ColorScheme.withAlpha(ColorScheme.surface, 0.26)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: pid; color: ColorScheme.withAlpha(ColorScheme.text, 0.72); font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; Layout.preferredWidth: 56; elide: Text.ElideRight }
                        Text { text: name; color: ColorScheme.text; font.pixelSize: 10; font.family: "Inter"; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: cpu + "%"; color: ColorScheme.accent; font.pixelSize: 10; font.bold: true; font.family: "Inter"; Layout.preferredWidth: 54; horizontalAlignment: Text.AlignRight }
                        Text { text: mem + "%"; color: ColorScheme.withAlpha(ColorScheme.text, 0.72); font.pixelSize: 10; font.family: "Inter"; Layout.preferredWidth: 54; horizontalAlignment: Text.AlignRight }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: ColorScheme.withAlpha(ColorScheme.red, 0.20)
                            Text {
                                anchors.centerIn: parent
                                text: "\u{f00d}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                color: ColorScheme.red
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.pendingKillPid = pid;
                                    killConfirmTimer.restart();
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.pendingKillPid === pid
                        spacing: 6
                        Text {
                            text: "Confirm:"
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.70)
                            font.pixelSize: 9
                            font.family: "Inter"
                        }
                        Rectangle {
                            width: 62; height: 20; radius: 10
                            color: ColorScheme.withAlpha(ColorScheme.yellow, 0.20)
                            Text { anchors.centerIn: parent; text: "SIGTERM"; color: ColorScheme.yellow; font.pixelSize: 8; font.family: "Inter" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runSignal(pid, "-TERM") }
                        }
                        Rectangle {
                            width: 62; height: 20; radius: 10
                            color: ColorScheme.withAlpha(ColorScheme.red, 0.20)
                            Text { anchors.centerIn: parent; text: "SIGKILL"; color: ColorScheme.red; font.pixelSize: 8; font.family: "Inter" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runSignal(pid, "-KILL") }
                        }
                        Rectangle {
                            width: 56; height: 20; radius: 10
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                            Text { anchors.centerIn: parent; text: "Cancel"; color: ColorScheme.withAlpha(ColorScheme.text, 0.75); font.pixelSize: 8; font.family: "Inter" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pendingKillPid = "" }
                        }
                    }
                }

                MouseArea {
                    id: procMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
            Text {
                anchors.centerIn: parent
                visible: procModel.count === 0
                text: "No processes found"
                color: ColorScheme.withAlpha(ColorScheme.text, 0.45)
                font.pixelSize: 10
                font.family: "Inter"
            }
        }
    }

    Component {
        id: serviceView
        ListView {
            model: serviceModel
            spacing: 6
            clip: true
            cacheBuffer: FeatureFlags.lowPowerUiMode ? 96 : 192
            reuseItems: true
            delegate: Rectangle {
                width: ListView.view.width
                height: 44
                radius: 8
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.24)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { text: unit; color: ColorScheme.text; font.pixelSize: 10; font.family: "Inter"; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text {
                            text: active + " / " + sub + " • " + description
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.52)
                            font.pixelSize: 8
                            font.family: "Inter"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        width: 20; height: 20; radius: 10
                        color: ColorScheme.withAlpha(ColorScheme.green, 0.20)
                        Text { anchors.centerIn: parent; text: "\u{f04b}"; color: ColorScheme.green; font.pixelSize: 8; font.family: DesignTokens.fontFamilyMono; renderType: Text.NativeRendering }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: serviceAction.exec(["systemctl", "--user", "start", unit]) }
                    }
                    Rectangle {
                        width: 20; height: 20; radius: 10
                        color: ColorScheme.withAlpha(ColorScheme.yellow, 0.20)
                        Text { anchors.centerIn: parent; text: "\u{f2f1}"; color: ColorScheme.yellow; font.pixelSize: 8; font.family: DesignTokens.fontFamilyMono; renderType: Text.NativeRendering }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: serviceAction.exec(["systemctl", "--user", "restart", unit]) }
                    }
                    Rectangle {
                        width: 20; height: 20; radius: 10
                        color: ColorScheme.withAlpha(ColorScheme.red, 0.20)
                        Text { anchors.centerIn: parent; text: "\u{f04d}"; color: ColorScheme.red; font.pixelSize: 8; font.family: DesignTokens.fontFamilyMono; renderType: Text.NativeRendering }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: serviceAction.exec(["systemctl", "--user", "stop", unit]) }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: serviceModel.count === 0
                text: "No services available"
                color: ColorScheme.withAlpha(ColorScheme.text, 0.45)
                font.pixelSize: 10
                font.family: "Inter"
            }
        }
    }
    }
}
