//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Hyprland._GlobalShortcuts
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtCore
import "core"
import "shared"
import "services"
import "modules/bar"
import "modules/bar/components"
import "modules/notifications"
import "modules/launcher"
import "modules/dashboard"
import "modules/dock"
import "modules/hotcorners"
import "overlays"

import Quickshell.Services.Mpris
import "services/HealthService.js" as HealthService
import "services/SanityService.js" as SanityService
import "services/MprisUtils.js" as MprisUtils
import "services/ShellIpcActions.js" as ShellIpcActions
import "core/TextSanitizer.js" as TextSanitizer
import "core/ErrorStateMachine.js" as ErrorStateMachine
import "core/LatencyProbe.js" as LatencyProbe

Scope {
    id: shellRoot

    // Global active MPRIS player for efficiency and stability.
    // We use a debounced property update to avoid C++ segfaults (MprisPlayer::onMetadataChanged)
    // when multiple DBus players or metadata updates arrive rapidly in batch.
    property var activeMprisPlayer: null

    Connections {
        target: Mpris.players
        function onValuesChanged() { mprisDebounce.restart(); }
    }

    Timer {
        id: mprisDebounce
        interval: 100; repeat: false; running: true; triggeredOnStart: true
        onTriggered: {
            try {
                shellRoot.activeMprisPlayer = MprisUtils.selectPlayer(Mpris.players, MprisPlaybackState.Playing);
            } catch (e) {
                shellRoot.activeMprisPlayer = null;
            }
        }
    }

    // Property aliases for Loaders to allow qualified access in delegates (fix qmllint warnings)
    property alias calendarLoader: calendarLoader
    property alias mediaPopupLoader: mediaPopupLoader
    property alias weatherPopupLoader: weatherPopupLoader
    property alias utilityMenuLoader: utilityMenuLoader
    property alias audioLoader: audioLoader
    property alias networkLoader: networkLoader
    property alias batteryLoader: batteryLoader
    property alias sessionLoader: sessionLoader
    property alias systemMonitorLoader: systemMonitorLoader
    property alias errorLogLoader: errorLogLoader
    property alias contextPopupLoader: contextPopupLoader
    property alias launcherLoader: launcherLoader
    property alias overviewLoader: overviewLoader
    property alias overviewCurrentLoader: overviewCurrentLoader
    property alias exposeLoader: exposeLoader
    property alias settingsStore: settingsStore
    property alias notificationPopupWindow: notificationPopupWindow
    property alias nixMonitorLoader: nixMonitorLoader
    property alias quickNotesLoader: quickNotesLoader
    property alias usbLoader: usbLoader
    property alias volumeMixerLoader: volumeMixerLoader
    property alias clipboardLoader: clipboardLoader

    property bool healthChecked: false
    property var binaryHealth: HealthService.defaultStatus()
    property var sanityIssues: []
    property var recoveryState: ErrorStateMachine.idleState()
    property bool lowPowerApplied: false
    property int lowPowerThreshold: 20
    property string activeContextProfile: "work"
    property int daemonRetry: 0
    property var contextData: ShellController.defaultContextData()
    property var popupLatencySamples: ({})
    property string pendingOsdAction: ""
    property string pendingOsdPayload: ""
    readonly property bool mediaSpectrumEnabled: ConfigFacade.mediaSpectrumEnabled()

    // Shell state machine: "initializing" → "ready" → "degraded"
    // Degraded shown when context_daemon or critical services fail
    property string shellState: "initializing"
    readonly property bool shellDegraded: shellState === "degraded"

    readonly property string hyprScriptsDir: RuntimePaths.hyprScriptsDir
    function defaultContextData() { return ShellController.defaultContextData(); }
    function normalizeContextData(data) { return ShellController.normalizeContextData(data); }
    function runHealthCheck() { ShellController.runHealthCheck(shellRoot, healthCheckProc); }
    function openPopup(triggerItem, popup) { ShellController.openPopup(triggerItem, popup); }
    function closePopup(triggerItem, popup) { ShellController.closePopup(triggerItem, popup); }
    function togglePopup(triggerItem, popup) { ShellController.togglePopup(triggerItem, popup); }
    function openLazyItem(item, label) { ShellController.openLazyItem(item, label); }
    function _wireLoaderTeardown(item, loader) { ShellController.wireLoaderTeardown(item, loader); }
    function toggleLazyItem(item, label) { ShellController.toggleLazyItem(item, label); }
    function toggleLazyWindow(loader) { ShellController.toggleLazyWindow(loader); }
    function flushPendingOsdAction() {
        if (!osdLoader.item || shellRoot.pendingOsdAction === "")
            return;
        var action = shellRoot.pendingOsdAction;
        var payload = shellRoot.pendingOsdPayload;
        shellRoot.pendingOsdAction = "";
        shellRoot.pendingOsdPayload = "";
        if (action === "volume" && typeof osdLoader.item.triggerVolume === "function") {
            osdLoader.item.triggerVolume(payload);
        } else if (action === "brightness" && typeof osdLoader.item.triggerBrightness === "function") {
            osdLoader.item.triggerBrightness(payload);
        } else if (action === "microphone" && typeof osdLoader.item.triggerMicrophone === "function") {
            osdLoader.item.triggerMicrophone(payload);
        } else if (action === "power-profile" && typeof osdLoader.item.triggerPowerProfile === "function") {
            osdLoader.item.triggerPowerProfile(payload);
        } else if (action === "capslock" && typeof osdLoader.item.triggerCapsLock === "function") {
            osdLoader.item.triggerCapsLock(payload === "true" || payload === true);
        } else if (action === "kbdbrightness" && typeof osdLoader.item.triggerKbdBrightness === "function") {
            osdLoader.item.triggerKbdBrightness();
        }
    }
    function triggerVolumeOsd(delta) {
        shellRoot.pendingOsdPayload = (typeof delta !== "undefined") ? String(delta) : "";
        ShellIpcActions.triggerOsd(shellRoot, osdLoader, PopupUtils, "volume");
    }
    function triggerBrightnessOsd(delta) {
        shellRoot.pendingOsdPayload = (typeof delta !== "undefined") ? String(delta) : "";
        ShellIpcActions.triggerOsd(shellRoot, osdLoader, PopupUtils, "brightness");
    }
    function triggerMicrophoneOsd(delta) {
        shellRoot.pendingOsdPayload = (typeof delta !== "undefined") ? String(delta) : "";
        ShellIpcActions.triggerOsd(shellRoot, osdLoader, PopupUtils, "microphone");
    }
    function triggerCapsLockOsd(enabled) {
        shellRoot.pendingOsdPayload = String(enabled);
        ShellIpcActions.triggerOsd(shellRoot, osdLoader, PopupUtils, "capslock");
    }
    function triggerKbdBrightnessOsd() {
        ShellIpcActions.triggerOsd(shellRoot, osdLoader, PopupUtils, "kbdbrightness");
    }
    function triggerPowerProfileOsd(profileKey) {
        if (profileKey) {
            BatteryStatsService.setPowerProfile(String(profileKey));
        }
        shellRoot.pendingOsdPayload = String(profileKey || "");
        ShellIpcActions.triggerOsd(shellRoot, osdLoader, PopupUtils, "power-profile");
    }
    function toggleCheatSheet() { shellRoot.toggleLazyWindow(cheatSheetLoader); }
    function toggleProductivity() {
        if (shellRoot.calendarLoader.active && shellRoot.calendarLoader.item && shellRoot.calendarLoader.item.activeTab !== undefined && shellRoot.calendarLoader.item.activeTab !== 0) {
            shellRoot.calendarLoader.item.activeTab = 0;
            return;
        }

        if (!shellRoot.calendarLoader.active)
            shellRoot.calendarLoader.pendingOpenOptions = { activeTab: 0 };

        shellRoot.togglePopup(null, shellRoot.calendarLoader);
    }
    function collectPopupIssues() { return ShellController.collectPopupIssues(shellRoot); }
    function runSanityCheck() { ShellController.runSanityCheck(shellRoot, sanityCheckProc); }
    function finishSanityCheck(parsed) { ShellController.finishSanityCheck(shellRoot, parsed, sanityNotifyProc); }
    function loadUiPreferences() {
        ShellController.bindSettingsStore(settingsStore);
        ShellController.loadUiPreferences();
    }
    function restoreBatteryPreferences() {
        ShellController.bindSettingsStore(settingsStore);
        ShellController.restoreBatteryPreferences(batteryPowerProfileProc, batteryNightLightProc, batteryGrayscaleProc);
    }
    function setDndState(enabled) { ShellController.setDndState(notificationPopupWindow, enabled); }
    function applyLowPowerMode(enabled) { ShellController.applyLowPowerMode(shellRoot, enabled, lowPowerProc, sanityNotifyProc); }
    function parseBatteryPercent(rawText) { ShellController.parseBatteryPercent(shellRoot, rawText, lowPowerProc, sanityNotifyProc); }
    function markPopupLoadStart(label) {
        popupLatencySamples[label] = LatencyProbe.begin(label, Date.now());
    }
    function markPopupLoadReady(label) {
        var sample = popupLatencySamples[label];
        if (!sample)
            return;

        delete popupLatencySamples[label];
        var finished = LatencyProbe.finish(sample, Date.now());
        Logger.info("Latency", LatencyProbe.format(finished), {
            popup: label,
            elapsedMs: finished.elapsedMs
        });
        if (LatencyProbe.isSlow(finished, FeatureFlags.lowPowerUiMode ? 900 : 600)) {
            Logger.warn("Latency", "Popup load exceeded baseline", {
                popup: label,
                elapsedMs: finished.elapsedMs
            });
        }
    }
    function updateRecoveryState(kind, scope, message, options) {
        recoveryState = ErrorStateMachine.makeState(kind, scope, message, options || { sanitizeText: TextSanitizer.cleanSingleLineText });
    }
    function beginBootstrap() {
        updateRecoveryState("loading", "Bootstrap", "Inicializando shell", { sanitizeText: TextSanitizer.cleanSingleLineText });
        bootstrapTimer.restart();
    }
    function performBootstrap() {
        ensurePathsProc.exec([
            "bash",
            RuntimePaths.scriptFile("ensure_runtime_dirs.sh")
        ]);
        loadUiPreferences();
        if (settingsStore && settingsStore.ready)
            restoreBatteryPreferences();
        runHealthCheck();
        sanityStartupTimer.restart();
        masterTimer.restart();
        timeRulesProc.exec([
            "bash",
            RuntimePaths.hyprScriptFile("time_rules.sh")
        ]);
        parseBatteryPercent(String(BatteryStatsService.batteryPercent));
        updateRecoveryState("ready", "Bootstrap", "Shell pronto", { sanitizeText: TextSanitizer.cleanSingleLineText, recoverable: true });
        shellState = "ready";

        // Fire morning briefing notification
        var h = new Date().getHours();
        if (h >= 5 && h < 12) {
            dailyBriefingNotifyProc.exec(["bash", RuntimePaths.scriptFile("daily_briefing.sh"), "--notify"]);
        }
    }

    Connections {
        target: Pipewire
        function onReadyChanged() {
            Logger.info("Shell", "Pipewire ready state changed", { ready: Pipewire.ready });
        }
    }

    // ─── Event-driven focus metrics (fires on window focus change, not poll) ──
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            focusMetricsDebounce.restart();
        }
    }

    Timer {
        id: focusMetricsDebounce
        interval: FeatureFlags.lowPowerUiMode ? 2000 : 800
        repeat: false
        running: false
        onTriggered: {
            focusMetricsProc.exec([
                "bash",
                RuntimePaths.scriptFile("focus_metrics_tick.sh")
            ]);
        }
    }

    Component.onCompleted: {
        Logger.info("Shell", "Initial Pipewire ready state", { ready: Pipewire.ready });
        beginBootstrap();
    }

    Component.onDestruction: {
        // ── Graceful shutdown sequence ──────────────────────────────
        // 1. Stop all daemons first (they may have external resources)
        contextDaemon.kill();
        usbEjectDaemon.kill();

        // 2. Stop all repeating timers to prevent callbacks during teardown
        masterTimer.stop();
        mprisDebounce.stop();
        focusMetricsDebounce.stop();
        daemonRestartTimer.stop();
        daemonHealthTimer.stop();
        bootstrapTimer.stop();
        sanityStartupTimer.stop();
        audioOsdArmTimer.stop();

        // 3. Flush logs synchronously (last action)
        Logger.flush();
    }

    Timer {
        id: bootstrapTimer
        interval: 0
        repeat: false
        running: false
        onTriggered: shellRoot.performBootstrap()
    }

    Timer {
        id: sanityStartupTimer
        interval: 2600
        repeat: false
        running: false
        onTriggered: shellRoot.runSanityCheck()
    }

    Timer {
        id: masterTimer
        // Base interval: 60s (perf budget + time rules only; focus now event-driven)
        interval: FeatureFlags.lowPowerUiMode ? 120000 : 60000
        repeat: true
        running: true
        triggeredOnStart: true
        
        property int ticks: 0
        
        onTriggered: {
            ticks++;
            
            // Focus metrics now event-driven only (via focusMetricsDebounce)
            
            // Every 8 ticks (~8 min): Perf Budget
            if (ticks % 8 === 0) {
                perfBudgetProc.exec([
                    "bash",
                    RuntimePaths.scriptFile("perf_budget_snapshot.sh")
                ]);
            }
            
            // Every 40 ticks (~10 min): Time Rules
            if (ticks % 40 === 0) {
                timeRulesProc.exec([
                    "bash",
                    RuntimePaths.hyprScriptFile("time_rules.sh")
                ]);
            }
        }
    }

    TimedProcess {
        id: healthCheckProc
        stdout: StdioCollector {
            onStreamFinished: {
                var output = String(text || "");
                var start = output.indexOf("__HEALTH_BEGIN__");
                var end = output.indexOf("__HEALTH_END__");
                if (start < 0 || end <= start) return;

                var payload = output.substring(start + "__HEALTH_BEGIN__".length, end);
                ShellController.applyHealthStatus(shellRoot, payload);
            }
        }
    }

    TimedProcess {
        id: sanityCheckProc
        stdout: StdioCollector {
            onStreamFinished: {
                var output = String(text || "");
                if (output.indexOf("__SANITY_END__") < 0) return;
                var parsed = SanityService.parse(output);
                shellRoot.finishSanityCheck(parsed);
            }
        }
    }

    TimedProcess { id: sanityNotifyProc }
    TimedProcess { id: daemonNotifyProc }
    TimedProcess { id: lowPowerProc }
    TimedProcess { id: ensurePathsProc }
    TimedProcess { id: focusMetricsProc }
    TimedProcess { id: timeRulesProc }
    TimedProcess { id: dailyBriefingNotifyProc }

    // Exponential backoff timers for context daemon restart
    Timer {
        id: daemonRestartTimer
        interval: 5000
        repeat: false
        running: false
        onTriggered: {
            contextDaemon.running = true;
            daemonHealthTimer.restart();
        }
    }

    // Reset retry counter after 30s of successful operation
    Timer {
        id: daemonHealthTimer
        interval: 30000
        repeat: false
        running: false
        onTriggered: {
            shellRoot.daemonRetry = 0;
            ShellController.onContextDaemonRecovered(shellRoot);
        }
    }

    TimedProcess {
        id: contextDaemon
        command: ["python3", RuntimePaths.scriptFile("context_daemon_v2.py")]
        running: false // Managed by systemd user service context-daemon.service
        timeoutMs: 0 // Disable timeout (long running)
        timeoutLabel: "context-daemon"
        onExited: {
            ShellController.onContextDaemonExited(shellRoot, daemonRestartTimer, daemonHealthTimer, contextDaemon);
        }
    }

    Connections {
        target: EventBus.process
        function onFailed(payload) {
            ShellController.notifyContextDaemonFailure(shellRoot, daemonNotifyProc, payload);
        }
    }

    TimedProcess {
        id: perfBudgetProc
        stdout: StdioCollector {
            onRead: {
                try {
                    var parsed = JSON.parse(String(data || "{}"));
                    if (parsed.ok === false) {
                        EventBus.performance.publishBudgetMeasured(parsed);
                    }
                } catch (e) {}
            }
        }
    }

    SettingsStore {
        id: settingsStore
    }

    TimedProcess { id: batteryNightLightProc }
    TimedProcess { id: batteryGrayscaleProc }
    TimedProcess { id: batteryPowerProfileProc }

    Connections {
        target: BatteryStatsService
        function onBatteryPercentChanged() {
            shellRoot.parseBatteryPercent(String(BatteryStatsService.batteryPercent));
        }
    }

    property bool _audioOsdArmed: false
    Timer {
        id: audioOsdArmTimer
        interval: 3500
        running: true
        repeat: false
        onTriggered: shellRoot._audioOsdArmed = true
    }

    Connections {
        target: AudioStatusService
        function onVolumeChanged() {
            if (!shellRoot._audioOsdArmed) return;
            shellRoot.triggerVolumeOsd();
        }
        function onMutedChanged() {
            if (!shellRoot._audioOsdArmed) return;
            shellRoot.triggerVolumeOsd();
        }
        function onSourceVolumeChanged() {
            if (!shellRoot._audioOsdArmed) return;
            shellRoot.triggerMicrophoneOsd();
        }
        function onSourceMutedChanged() {
            if (!shellRoot._audioOsdArmed) return;
            shellRoot.triggerMicrophoneOsd();
        }
    }

    Connections {
        target: settingsStore
        function onReadyChanged() {
            if (!settingsStore || !settingsStore.ready) return;
            shellRoot.loadUiPreferences();
            shellRoot.restoreBatteryPreferences();
        }
    }

    TimedProcess {
        id: usbEjectDaemon
        command: ["bash", RuntimePaths.scriptFile("usb_eject_daemon.sh")]
        running: false // Handled natively by USBService.qml
        timeoutMs: 0
    }

    CommandRunner {
        id: commandSender
        command: ["bash", RuntimePaths.scriptFile("send_command.sh"), "{}"]
    }

    // --- IPC Handler for External Commands ---
    IpcHandler {
        id: ipcHandler
        target: "ipcHandler"  // IPC target name for external calls
        
        // Send command to Python Daemon
        function sendCommand(action: string, target: string) {
            ShellIpcActions.sendCommand(commandSender, RuntimePaths, action, target);
        }
        
        // Toggle launcher
        function toggleLauncher() {
            shellRoot.togglePopup(null, launcherLoader);
        }

        function toggleWorkspaceSwitcher() {
            shellRoot.toggleLazyWindow(workspaceSwitcherLoader);
        }

        function openWorkspaceSwitcher() {
            ShellIpcActions.openWorkspaceSwitcher(workspaceSwitcherLoader);
        }

        // Open launcher
        function openLauncher() {
            shellRoot.openPopup(null, launcherLoader);
        }

        // Toggle utility hub
        function toggleUtilityHub() {
            shellRoot.toggleLazyWindow(utilityMenuLoader);
        }

        function toggleAudioPopup() {
            shellRoot.toggleLazyWindow(audioLoader);
        }

        function toggleMediaPopup() {
            shellRoot.toggleLazyWindow(mediaPopupLoader);
        }

        function toggleSessionPopup() {
            shellRoot.toggleLazyWindow(sessionLoader);
        }

        // Toggle dashboard
        function toggleDashboard() {
            shellRoot.toggleLazyWindow(dashboardLoader);
        }

        // Toggle power menu
        function togglePowerMenu() {
            shellRoot.toggleLazyWindow(powerMenuLoader);
        }

        // Toggle CheatSheet
        function toggleCheatSheet() {
            shellRoot.toggleLazyWindow(cheatSheetLoader);
        }

        // Toggle Productivity
        function toggleProductivity() {
            shellRoot.toggleProductivity();
        }

        // Reload daily briefing
        function reloadDailyBriefing() {
            ShellIpcActions.reloadDailyBriefing(shellRoot.dailyBriefingNotifyProc, RuntimePaths);
        }

        function triggerVolumeOsd() { shellRoot.triggerVolumeOsd(); }
        function triggerVolumeUp() { shellRoot.triggerVolumeOsd(0.05); }
        function triggerVolumeDown() { shellRoot.triggerVolumeOsd(-0.05); }
        function triggerVolumeToggleMute() {
            AudioStatusService.cliMuted = !AudioStatusService.cliMuted;
            shellRoot.triggerVolumeOsd();
        }

        function triggerBrightnessOsd() { shellRoot.triggerBrightnessOsd(); }
        function triggerBrightnessUp() { shellRoot.triggerBrightnessOsd(0.05); }
        function triggerBrightnessDown() { shellRoot.triggerBrightnessOsd(-0.05); }

        function triggerMicrophoneOsd() { shellRoot.triggerMicrophoneOsd(); }
        function triggerMicUp() { shellRoot.triggerMicrophoneOsd(0.05); }
        function triggerMicDown() { shellRoot.triggerMicrophoneOsd(-0.05); }
        function triggerMicToggleMute() {
            AudioStatusService.cliSourceMuted = !AudioStatusService.cliSourceMuted;
            shellRoot.triggerMicrophoneOsd();
        }

        function triggerCapsLockOsd(enabled: bool) { shellRoot.triggerCapsLockOsd(enabled); }
        function triggerKbdBrightnessOsd() { shellRoot.triggerKbdBrightnessOsd(); }
        function triggerPowerProfileOsd(profileKey: string) { shellRoot.triggerPowerProfileOsd(profileKey); }

        function setDndOn() {
            shellRoot.setDndState(true);
        }

        function setDndOff() {
            shellRoot.setDndState(false);
        }

        // Trigger color scheme reload
        function reloadColors() {
            ColorScheme.reload();
        }

        // Receive context update from Python daemon
        function updateContext(payload: string) {
            ShellIpcActions.updateContext(shellRoot, payload, ShellController, Logger);
        }

        // Receive connectivity updates from context daemon (DBus -> IPC -> QML)
        function updateConnectivity(payload: string) {
            ShellIpcActions.updateConnectivity(payload, ConnectivityService, Logger);
        }

        // Receive monitor hotplug and layout changes from Hyprland
        function onMonitorsChanged() {
            UtilityService.refreshDisplayProfile();
        }
    }

    // --- Hyprland Global Shortcuts ---
    // Note: Launcher is now triggered via IPC, not GlobalShortcut
    // This allows us to use Hyprland's bindr for SUPER solo detection
    
    GlobalShortcut {
        name: "overview"
        description: "Toggle workspace overview"
        onPressed: shellRoot.toggleLazyWindow(overviewLoader)
    }

    // --- Global Singletons (Windows that exist once) ---
    // Launcher and Overview are Loader-based to avoid mapping full-screen
    // Wayland surfaces at all times (saves ~50% GPU on idle).
    Loader {
        id: launcherLoader; objectName: "Launcher"; active: false; asynchronous: true
        property bool openOnLoad: false
        sourceComponent: Launcher {
            settingsStore: shellRoot.settingsStore
        }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: {
            shellRoot.markPopupLoadReady(objectName);
            if (openOnLoad === true) {
                shellRoot.openLazyItem(item, objectName);
                openOnLoad = false;
            }
        }
    }

    Timer {
        id: launcherWarmupTimer
        interval: 2800
        repeat: false
        running: true
        onTriggered: {
            if (!launcherLoader.active) {
                launcherLoader.openOnLoad = false;
                launcherLoader.active = true;
            }
        }
    }
    Loader {
        id: overviewLoader; objectName: "Overview"; active: false; asynchronous: true
        property var pendingOpenOptions: null
        sourceComponent: Overview {}
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: {
            shellRoot.markPopupLoadReady(objectName);
            if (pendingOpenOptions && typeof pendingOpenOptions === "object") {
                for (var key in pendingOpenOptions) {
                    if (pendingOpenOptions.hasOwnProperty(key) && item[key] !== undefined)
                        item[key] = pendingOpenOptions[key];
                }
                pendingOpenOptions = null;
            }
            shellRoot.openLazyItem(item, objectName);
            shellRoot._wireLoaderTeardown(item, shellRoot.overviewLoader)
        }
    }
    Loader {
        id: overviewCurrentLoader; objectName: "OverviewCurrent"; active: false; asynchronous: true
        sourceComponent: Overview { currentWorkspaceOnly: true }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: {
            shellRoot.markPopupLoadReady(objectName);
            shellRoot.openLazyItem(item, objectName);
            shellRoot._wireLoaderTeardown(item, shellRoot.overviewCurrentLoader)
        }
    }
    Loader {
        id: exposeLoader; objectName: "ExposePopup"; active: false; asynchronous: true
        sourceComponent: ExposePopup { }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: {
            shellRoot.markPopupLoadReady(objectName);
            shellRoot.openLazyItem(item, objectName);
            shellRoot._wireLoaderTeardown(item, shellRoot.exposeLoader)
        }
    }
    Loader {
        id: powerMenuLoader; objectName: "PowerMenu"; active: false; asynchronous: true
        sourceComponent: PowerMenu {}
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.powerMenuLoader) }
    }
    Loader {
        id: dashboardLoader
        objectName: "Dashboard"; active: false; asynchronous: true
        sourceComponent: Dashboard {
            contextData: shellRoot.contextData
            binaryStatus: shellRoot.binaryHealth
            healthChecked: shellRoot.healthChecked
            recoveryState: shellRoot.recoveryState
            sanityIssues: shellRoot.sanityIssues
        }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: {
            shellRoot.markPopupLoadReady(objectName);
            shellRoot.openLazyItem(item, objectName);
            shellRoot._wireLoaderTeardown(item, shellRoot.dashboardLoader);
        }
    }

    Loader {
        id: calendarLoader; objectName: "CalendarPopup"; active: false; asynchronous: true
        property var pendingOpenOptions: null
        sourceComponent: CalendarPopup {
            quickNotesPopup: shellRoot.quickNotesLoader
        }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: {
            shellRoot.markPopupLoadReady(objectName);
            if (pendingOpenOptions && typeof pendingOpenOptions === "object") {
                for (var key in pendingOpenOptions) {
                    if (pendingOpenOptions.hasOwnProperty(key) && item[key] !== undefined)
                        item[key] = pendingOpenOptions[key];
                }
                pendingOpenOptions = null;
            }
            shellRoot.openLazyItem(item, objectName);
            shellRoot._wireLoaderTeardown(item, shellRoot.calendarLoader)
        }
    }
    Loader {
        id: mediaPopupLoader; objectName: "BarMediaPopup"; active: false; asynchronous: true
        sourceComponent: BarMediaPopup { settingsStore: shellRoot.settingsStore }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.mediaPopupLoader) }
    }
    Loader {
        id: weatherPopupLoader; objectName: "BarWeatherPopup"; active: false; asynchronous: true
        sourceComponent: BarWeatherPopup { }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.weatherPopupLoader) }
    }
    Loader {
        id: utilityMenuLoader; objectName: "UtilityMenu"; active: false; asynchronous: true
        sourceComponent: UtilityMenu {
            binaryStatus: shellRoot.binaryHealth
            healthChecked: shellRoot.healthChecked
            settingsStore: shellRoot.settingsStore
        }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: {
            shellRoot.markPopupLoadReady(objectName);
            shellRoot.openLazyItem(item, objectName);
            shellRoot._wireLoaderTeardown(item, shellRoot.utilityMenuLoader);
        }
    }
    Loader {
        id: osdLoader
        objectName: "OSD"
        active: true
        asynchronous: false
        sourceComponent: OSD { }
        onLoaded: shellRoot.flushPendingOsdAction()
    }
    Loader {
        id: audioSpectrumLoader
        objectName: "AudioSpectrumVisualizer"
        active: shellRoot.mediaSpectrumEnabled
            && !FeatureFlags.lowPowerUiMode
            && !FeatureFlags.reducedMotion
            && !!(shellRoot.activeMprisPlayer && shellRoot.activeMprisPlayer.playbackState === MprisPlaybackState.Playing)
        asynchronous: true
        sourceComponent: AudioSpectrumVisualizer {
            player: shellRoot.activeMprisPlayer
        }
    }
    BarNotificationsPopup {
        id: notificationPopupWindow
        settingsStore: shellRoot.settingsStore
        focusMode: FeatureFlags.focusMode
    }
    NotificationToastWindow { id: notificationToastWindow; notificationCenter: shellRoot.notificationPopupWindow }

    Loader { id: workspaceSwitcherLoader; objectName: "WorkspaceSwitcherPopup"; active: false; asynchronous: true
        sourceComponent: WorkspaceSwitcherPopup {}
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.workspaceSwitcherLoader) }
    }

    Loader { id: cheatSheetLoader; objectName: "CheatSheet"; active: false; asynchronous: true
        sourceComponent: CheatSheet {}
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.cheatSheetLoader) }
    }

    Loader {
        id: audioLoader; objectName: "AudioPopup"; active: false; asynchronous: true
        sourceComponent: AudioPopup { settingsStore: shellRoot.settingsStore }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.audioLoader) }
    }
    Loader {
        id: networkLoader; objectName: "NetworkPopup"; active: false; asynchronous: true
        sourceComponent: NetworkPopup { settingsStore: shellRoot.settingsStore }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.networkLoader) }
    }
    Loader {
        id: batteryLoader; objectName: "BatteryPopup"; active: false; asynchronous: true
        sourceComponent: BatteryPopup { settingsStore: shellRoot.settingsStore }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.batteryLoader) }
    }
    Loader {
        id: sessionLoader; objectName: "SessionPopup"; active: false; asynchronous: true
        sourceComponent: SessionPopup { }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.sessionLoader) }
    }
    Loader {
        id: systemMonitorLoader; objectName: "SystemMonitorPopup"; active: false; asynchronous: true
        sourceComponent: SystemMonitorPopup { settingsStore: shellRoot.settingsStore }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.systemMonitorLoader) }
    }
    Loader {
        id: errorLogLoader; objectName: "ErrorLogPopup"; active: false; asynchronous: true
        sourceComponent: ErrorLogPopup {
            sanityIssues: shellRoot.sanityIssues
            recoveryState: shellRoot.recoveryState
        }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.errorLogLoader) }
    }
    Loader {
        id: contextPopupLoader; objectName: "ContextPopup"; active: false; asynchronous: true
        sourceComponent: ContextPopup {
            contextData: shellRoot.contextData
        }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.contextPopupLoader) }
    }
    Loader {
        id: nixMonitorLoader; objectName: "NixMonitorPopup"; active: false; asynchronous: true
        sourceComponent: NixMonitorPopup { }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.nixMonitorLoader) }
    }
    Loader {
        id: quickNotesLoader; objectName: "QuickNotesPopup"; active: false; asynchronous: true
        sourceComponent: QuickNotesPopup { }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.quickNotesLoader) }
    }
    Loader {
        id: usbLoader; objectName: "USBPopup"; active: false; asynchronous: true
        sourceComponent: USBPopup { }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.usbLoader) }
    }
    Loader {
        id: volumeMixerLoader; objectName: "VolumeMixerPopup"; active: false; asynchronous: true
        sourceComponent: VolumeMixerPopup { }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.volumeMixerLoader) }
    }
    Loader {
        id: clipboardLoader; objectName: "ClipboardPopup"; active: false; asynchronous: true
        sourceComponent: ClipboardPopup { }
        onActiveChanged: if (active) shellRoot.markPopupLoadStart(objectName)
        onLoaded: { shellRoot.markPopupLoadReady(objectName); shellRoot.openLazyItem(item, objectName); shellRoot._wireLoaderTeardown(item, shellRoot.clipboardLoader) }
    }

    // --- Per-Screen Components (Bar) ---
    // Variants creates an instance of the delegate for every item in the model (screens)
    Scope {
        Variants {
            model: Quickshell.screens
            
            delegate: Bar {
                // Connect the per-screen bar to the global windows
                launcherInstance: shellRoot.launcherLoader
                overviewInstance: shellRoot.overviewLoader
                exposeInstance: shellRoot.exposeLoader
                calendarInstance: shellRoot.calendarLoader
                settingsStore: shellRoot.settingsStore
                notificationCenter: shellRoot.notificationPopupWindow
                mediaPopup: shellRoot.mediaPopupLoader
                weatherPopup: shellRoot.weatherPopupLoader
                utilityHub: shellRoot.utilityMenuLoader
                audioPopup: shellRoot.audioLoader
                networkPopup: shellRoot.networkLoader
                batteryPopup: shellRoot.batteryLoader
                sessionPopup: shellRoot.sessionLoader
                systemMonitorPopup: shellRoot.systemMonitorLoader
                errorPopup: shellRoot.errorLogLoader
                contextPopup: shellRoot.contextPopupLoader
                nixMonitorPopup: shellRoot.nixMonitorLoader
                quickNotesPopup: shellRoot.quickNotesLoader
                usbPopup: shellRoot.usbLoader
                volumeMixerPopup: shellRoot.volumeMixerLoader
                clipboardPopup: shellRoot.clipboardLoader
                productivityPopup: shellRoot.calendarLoader
                contextData: shellRoot.contextData
                binaryStatus: shellRoot.binaryHealth
                healthChecked: shellRoot.healthChecked
                shellDegraded: shellRoot.shellDegraded
            }
        }
    }

    // --- Per-Screen Components (Dock) ---
    Scope {
        Variants {
            model: FeatureFlags.dockEnabled ? Quickshell.screens : []
            delegate: Dock {}
        }
    }

    // --- Per-Screen Components (Hot Corners) ---
    Scope {
        Variants {
            model: FeatureFlags.enableHotCorners ? Quickshell.screens : []
            delegate: HotCorners {
                launcherLoader: shellRoot.launcherLoader
                overviewLoader: shellRoot.overviewLoader
                overviewCurrentLoader: shellRoot.overviewCurrentLoader
                exposeLoader: shellRoot.exposeLoader
            }
        }
    }

    IconWarmup {
        enabled: false // Disabled: real UI components resolve & cache their icons on-demand
    }
}
