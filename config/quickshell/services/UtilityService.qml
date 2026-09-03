pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "ScreenshotService.js" as ScreenshotService
import "HealthService.js" as HealthService

/**
 * UtilityService - Central reactive state & orchestration for the Utility Hub.
 * Manages Screenshots, Screen Recordings, Displays, and Productivity tools.
 */
Singleton {
    id: root

    // ─── Public State: Screenshots & Captures ─────────────────────────────────
    property string screenshotFormat: "png"
    property string screenshotMode: "full"
    property int screenshotDelaySec: 0
    property string screenshotDestination: RuntimePaths.joinPath(RuntimePaths.picturesDir, "Screenshots")
    property string fileTemplate: "{type}_{timestamp}"
    property bool copyPathThumb: false

    property var recentCaptures: []
    property string lastCapturePath: ""
    property string lastCaptureThumb: ""
    property bool isTakingScreenshot: false
    property int countdownRemaining: 0
    readonly property bool isCountingDown: countdownRemaining > 0

    // ─── Public State: Recordings (Wave 2) ────────────────────────────────────
    property bool isRecording: false
    property bool isPaused: false
    property string recordingMode: ""
    property string recordingFile: ""
    property int recordingDurationSec: 0
    property string recordingDurationLabel: "00:00"
    property bool micEnabled: false
    property bool systemEnabled: false
    property string videoContainer: "mkv"
    property string videoCodec: "auto"
    property int videoFps: 30
    property int videoQuality: 23
    property string videoDestination: RuntimePaths.joinPath(RuntimePaths.moviesDir, "ScreenRecords")

    // ─── Public State: Displays & Monitors (Wave 3) ──────────────────────────
    property string activeDisplayProfile: "internal-only"
    property string activeDisplayResolution: "1366x768"
    property var availableResolutions: ["1366x768", "1920x1080", "1280x720", "preferred"]
    property string externalMonitorName: ""
    property string internalMonitorName: ""
    property int connectedMonitorsCount: 1
    property var monitorList: []

    // ─── Public State: Tools & Colors (Bridged for Wave 4) ─────────────────────
    property bool presentationMode: false
    property string lastColorHex: "#FFFFFF"
    property bool hasColor: false
    property var colorHistory: []
    property bool anonymizeCapture: false
    property string lensProvider: "google"
    property string ocrLanguage: "eng"

    // ─── System Health & Availability ─────────────────────────────────────────
    property var binaryStatus: ({})
    property bool healthChecked: false
    readonly property bool utilityAvailable: !healthChecked || HealthService.utilityHubAvailable(binaryStatus)

    // ─── Errors & Diagnostics ─────────────────────────────────────────────────
    property string lastError: ""

    // ─── Paths ────────────────────────────────────────────────────────────────
    readonly property string scriptsDir: RuntimePaths.quickshellScriptsDir
    readonly property string uiScriptsDir: RuntimePaths.joinPath(RuntimePaths.quickshellScriptsDir, "ui")

    // ─── Signals ──────────────────────────────────────────────────────────────
    signal captureCreated(string path, string kind)
    signal captureDeleted(string path)
    signal recordingStarted(string mode, string filePath)
    signal recordingStopped(string filePath)
    signal recordingPaused(bool paused)
    signal countdownTick(int remainingSec)
    signal actionCompleted(string actionName)

    // ─── Initialization & Persistence ─────────────────────────────────────────
    Component.onCompleted: {
        loadPreferences();
        refreshHistory();
        refreshStatus();
        refreshRecordingStatus();
        refreshDisplayProfile();
        refreshColorHistory();
    }

    function loadPreferences() {
        if (!ConfigFacade) return;
        screenshotFormat = ConfigFacade.utilityScreenshotFormat();
        screenshotMode = ConfigFacade.utilityScreenshotMode();
        screenshotDelaySec = ConfigFacade.utilityScreenshotDelaySec();
        var dest = ConfigFacade.utilityScreenshotDir();
        if (dest && dest !== "") screenshotDestination = dest;
        fileTemplate = ConfigFacade.utilityFileTemplate();
        copyPathThumb = ConfigFacade.utilityCopyPathThumb();

        micEnabled = ConfigFacade.utilityMicEnabled();
        systemEnabled = ConfigFacade.utilitySystemEnabled();
        videoContainer = ConfigFacade.utilityVideoContainer();
        videoCodec = ConfigFacade.utilityVideoCodec();
        videoFps = ConfigFacade.utilityVideoFps();
        videoQuality = ConfigFacade.utilityVideoQuality();
        var vdest = ConfigFacade.utilityVideoDir();
        if (vdest && vdest !== "") videoDestination = vdest;

        anonymizeCapture = ConfigFacade.utilityAnonymizeCapture();
        lensProvider = ConfigFacade.utilityLensProvider();
        ocrLanguage = ConfigFacade.utilityOcrLang();
    }

    function formatDuration(seconds) {
        var sec = Math.max(0, Number(seconds) || 0);
        var mm = Math.floor(sec / 60);
        var ss = sec % 60;
        return (mm < 10 ? "0" : "") + mm + ":" + (ss < 10 ? "0" : "") + ss;
    }

    // ─── Screenshot Operations ────────────────────────────────────────────────
    function takeScreenshot(mode, customOptions) {
        var opt = customOptions || {};
        var chosenMode = mode || screenshotMode || "screen";
        var delay = (opt.delaySec !== undefined && opt.delaySec !== null) ? Number(opt.delaySec) : screenshotDelaySec;

        if (delay > 0) {
            startCountdown(delay, function() {
                _executeScreenshot(chosenMode, opt, 0);
            });
            return;
        }

        // Interactive modes (region, annotate, screen) wait for user click/drag so they don't need delay
        if (chosenMode === "region" || chosenMode === "annotate" || chosenMode === "screen") {
            _executeScreenshot(chosenMode, opt, 0);
            return;
        }

        // Small 80ms settle delay for instant window/all capture to allow popup unmap
        settleTimer.callback = function() {
            _executeScreenshot(chosenMode, opt, 0);
        };
        settleTimer.restart();
    }

    Timer {
        id: settleTimer
        interval: 80
        repeat: false
        property var callback: null
        onTriggered: {
            if (callback) {
                var cb = callback;
                callback = null;
                cb();
            }
        }
    }

    function _executeScreenshot(mode, opt, delaySec) {
        isTakingScreenshot = true;
        lastError = "";

        var args = ScreenshotService.screenshotArgs(scriptsDir, mode, {
            format: opt.format || screenshotFormat,
            destination: opt.destination || screenshotDestination,
            template: opt.template || fileTemplate,
            copyPathThumb: opt.copyPathThumb !== undefined ? opt.copyPathThumb : copyPathThumb,
            annotate: opt.annotate === true,
            delaySec: delaySec
        });

        shotProc.exec(args);
    }

    function startCountdown(seconds, onComplete) {
        countdownRemaining = Math.max(1, Math.round(seconds));
        _pendingCountdownAction = onComplete;
        countdownTimer.restart();
        countdownTick(countdownRemaining);
        notifyInfo("Temporizador (" + countdownRemaining + "s)", "Captura em andamento...");
    }

    property var _pendingCountdownAction: null

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            root.countdownRemaining--;
            root.countdownTick(root.countdownRemaining);
            if (root.countdownRemaining > 0) {
                root.notifyInfo("Temporizador", "Capturando em " + root.countdownRemaining + "s...");
            } else {
                countdownTimer.stop();
                if (root._pendingCountdownAction) {
                    var action = root._pendingCountdownAction;
                    root._pendingCountdownAction = null;
                    action();
                }
            }
        }
    }

    // ─── Screen Recording Operations (Wave 2) ─────────────────────────────────
    function startRecording(mode, customOptions) {
        if (isRecording) return;
        var opt = customOptions || {};
        var chosenMode = mode || "full";

        var args = ScreenshotService.recordToggleArgs(scriptsDir, chosenMode, micEnabled, systemEnabled, false, {
            container: opt.container || videoContainer,
            codec: opt.codec || videoCodec,
            fps: opt.fps || videoFps,
            quality: opt.quality || videoQuality,
            destination: opt.destination || videoDestination,
            template: opt.template || fileTemplate
        });

        recordActionProc.exec(args);
    }

    function stopRecording() {
        if (!isRecording) return;
        recordActionProc.exec(ScreenshotService.recordStopArgs(scriptsDir));
    }

    function toggleRecording(mode, customOptions) {
        if (isRecording) stopRecording();
        else startRecording(mode, customOptions);
    }

    function togglePauseRecording() {
        if (!isRecording) return;
        recordActionProc.exec(ScreenshotService.recordPauseArgs(scriptsDir));
    }

    function toggleMic() {
        micEnabled = !micEnabled;
        ConfigFacade.set("utilityMicEnabled", micEnabled);
        notifyInfo("Microfone na Gravação", micEnabled ? "Ativado" : "Desativado");
        return micEnabled;
    }

    function toggleSystemAudio() {
        systemEnabled = !systemEnabled;
        ConfigFacade.set("utilitySystemEnabled", systemEnabled);
        notifyInfo("Áudio do Sistema", systemEnabled ? "Ativado" : "Desativado");
        return systemEnabled;
    }

    function cycleVideoContainer() {
        var containers = ["mkv", "mp4", "gif", "webm"];
        var idx = containers.indexOf(videoContainer);
        videoContainer = containers[(idx + 1) % containers.length];
        ConfigFacade.set("utilityVideoContainer", videoContainer);
        notifyInfo("Formato de Vídeo", videoContainer.toUpperCase());
        return videoContainer;
    }

    function cycleVideoCodec() {
        var codecs = ["auto", "h264_vaapi", "hevc_vaapi", "libx264", "libvpx-vp9"];
        var idx = codecs.indexOf(videoCodec);
        videoCodec = codecs[(idx + 1) % codecs.length];
        ConfigFacade.set("utilityVideoCodec", videoCodec);
        notifyInfo("Codec de Gravação", videoCodec);
        return videoCodec;
    }

    function cycleVideoFps() {
        var fpsList = [30, 60, 120];
        var idx = fpsList.indexOf(videoFps);
        videoFps = fpsList[(idx + 1) % fpsList.length];
        ConfigFacade.set("utilityVideoFps", videoFps);
        notifyInfo("Taxa de Quadros (FPS)", videoFps + " FPS");
        return videoFps;
    }

    function cycleVideoQuality() {
        var qualityList = [18, 21, 23, 26, 30];
        var idx = qualityList.indexOf(videoQuality);
        videoQuality = qualityList[(idx + 1) % qualityList.length];
        ConfigFacade.set("utilityVideoQuality", videoQuality);
        notifyInfo("Qualidade de Gravação", "CRF " + videoQuality);
        return videoQuality;
    }

    function cycleVideoDestination() {
        var destinations = [
            RuntimePaths.joinPath(RuntimePaths.moviesDir, "ScreenRecords"),
            RuntimePaths.moviesDir,
            RuntimePaths.downloadsDir
        ];
        var idx = destinations.indexOf(videoDestination);
        videoDestination = destinations[(idx + 1) % destinations.length];
        ConfigFacade.set("utilityVideoDir", videoDestination);
        notifyInfo("Destino de Gravações", videoDestination);
        return videoDestination;
    }

    // ─── Smooth 1-Second Recording Timer ─────────────────────────────────────
    Timer {
        id: recordingClockTimer
        interval: 1000
        repeat: true
        running: root.isRecording && !root.isPaused
        onTriggered: {
            root.recordingDurationSec++;
            root.recordingDurationLabel = root.formatDuration(root.recordingDurationSec);
        }
    }

    // Background sync check every 10s or on demand
    Timer {
        id: recordSyncTimer
        interval: 10000
        repeat: true
        running: root.isRecording
        onTriggered: root.refreshRecordingStatus()
    }

    function refreshRecordingStatus() {
        recordStatusProc.exec(ScreenshotService.recordStatusArgs(scriptsDir));
    }

    function applyRecordStatus(rawText) {
        var parsed = ScreenshotService.parseRecordStatus(rawText);
        var wasRecording = root.isRecording;
        root.isRecording = parsed.running;
        root.recordingMode = parsed.mode || "";
        root.recordingFile = parsed.file || "";
        root.isPaused = parsed.paused === true;

        if (parsed.running) {
            root.micEnabled = parsed.mic;
            root.systemEnabled = parsed.system;
            if (parsed.duration > 0 && Math.abs(root.recordingDurationSec - parsed.duration) > 2) {
                root.recordingDurationSec = parsed.duration;
            }
            root.recordingDurationLabel = root.formatDuration(root.recordingDurationSec);
            if (!wasRecording) {
                root.recordingStarted(root.recordingMode, root.recordingFile);
            }
        } else {
            root.recordingDurationSec = 0;
            root.recordingDurationLabel = "00:00";
            if (wasRecording) {
                root.recordingStopped(root.recordingFile);
                root.refreshHistory();
            }
        }
    }

    // ─── History & File Actions ───────────────────────────────────────────────
    function refreshHistory() {
        historyProc.exec(ScreenshotService.captureHistoryArgs(scriptsDir));
    }

    function openCapture(filePath) {
        if (!filePath) return;
        fileActionProc.exec(["xdg-open", filePath]);
    }

    function openFolder(folderPath) {
        var target = folderPath || screenshotDestination;
        fileActionProc.exec(["xdg-open", target]);
    }

    function copyCapture(filePath) {
        if (!filePath) return;
        fileActionProc.exec(["bash", "-c", "mime=$(file -b --mime-type " + JSON.stringify(filePath) + " 2>/dev/null || echo image/png); wl-copy -t \"$mime\" < " + JSON.stringify(filePath) + " && notify-send -a 'Utility Hub' 'Copiado para Clipboard' " + JSON.stringify(filePath)]);
    }

    function annotateCapture(filePath) {
        if (!filePath) return;
        fileActionProc.exec(["swappy", "-f", filePath]);
    }

    function deleteCapture(filePath) {
        if (!filePath) return;
        fileActionProc.exec(["bash", "-c", "rm -f " + JSON.stringify(filePath) + " && notify-send -a 'Utility Hub' 'Arquivo Removido' " + JSON.stringify(filePath)]);
        refreshHistory();
        captureDeleted(filePath);
    }

    // ─── Preference Cyclers: Screenshots ──────────────────────────────────────
    function cycleScreenshotFormat() {
        var formats = ["png", "jpg", "webp"];
        var idx = formats.indexOf(screenshotFormat);
        screenshotFormat = formats[(idx + 1) % formats.length];
        ConfigFacade.set("utilityScreenshotFormat", screenshotFormat);
        notifyInfo("Formato de Imagem", screenshotFormat.toUpperCase());
        return screenshotFormat;
    }

    function cycleScreenshotMode() {
        var modes = ["screen", "region", "window", "all"];
        var idx = modes.indexOf(screenshotMode);
        if (idx < 0) idx = 0;
        screenshotMode = modes[(idx + 1) % modes.length];
        ConfigFacade.set("utilityScreenshotMode", screenshotMode);
        var label = "TELA / MONITOR";
        if (screenshotMode === "region") label = "REGIÃO";
        else if (screenshotMode === "window") label = "JANELA";
        else if (screenshotMode === "all") label = "TODAS AS TELAS";
        notifyInfo("Modo Padrão", label);
        return screenshotMode;
    }

    function cycleScreenshotDelay() {
        var delays = [0, 3, 5, 10];
        var idx = delays.indexOf(screenshotDelaySec);
        screenshotDelaySec = delays[(idx + 1) % delays.length];
        ConfigFacade.set("utilityScreenshotDelaySec", screenshotDelaySec);
        notifyInfo("Temporizador", screenshotDelaySec > 0 ? (screenshotDelaySec + "s") : "Desativado (Instantâneo)");
        return screenshotDelaySec;
    }

    function cycleScreenshotDestination() {
        var destinations = [
            RuntimePaths.joinPath(RuntimePaths.picturesDir, "Screenshots"),
            RuntimePaths.joinPath(RuntimePaths.picturesDir, "Captures"),
            RuntimePaths.downloadsDir
        ];
        var idx = destinations.indexOf(screenshotDestination);
        screenshotDestination = destinations[(idx + 1) % destinations.length];
        ConfigFacade.set("utilityScreenshotDir", screenshotDestination);
        notifyInfo("Destino de Screenshots", screenshotDestination);
        return screenshotDestination;
    }

    function cycleFileTemplate() {
        var templates = [
            "{type}_{timestamp}",
            "{timestamp}_{mode}",
            "capture_{type}_{mode}_{timestamp}"
        ];
        var idx = templates.indexOf(fileTemplate);
        fileTemplate = templates[(idx + 1) % templates.length];
        ConfigFacade.set("utilityFileTemplate", fileTemplate);
        notifyInfo("Template de Arquivo", fileTemplate);
        return fileTemplate;
    }

    function toggleCopyPathThumb() {
        copyPathThumb = !copyPathThumb;
        ConfigFacade.set("utilityCopyPathThumb", copyPathThumb);
        notifyInfo("Modo Clipboard", copyPathThumb ? "Caminho + Thumbnail" : "Imagem Direta");
        return copyPathThumb;
    }

    // ─── Status Refreshing ────────────────────────────────────────────────────
    function refreshStatus() {
        colorStatusProc.exec(ScreenshotService.colorStatusArgs(scriptsDir));
    }

    function notifyInfo(title, body) {
        notifyProc.exec(["notify-send", "-a", "Utility Hub", title, body]);
    }

    // ─── Process Runners ──────────────────────────────────────────────────────
    TimedProcess {
        id: shotProc
        stdout: StdioCollector {
            onRead: (data) => {
                var text = String(data || "").trim();
                if (text.indexOf("ERROR:") === 0) {
                    root.lastError = text.substring(6).trim();
                } else if (text !== "") {
                    root.lastCapturePath = text;
                    root.captureCreated(text, "screenshot");
                    root.refreshHistory();
                }
            }
        }
        stderr: StdioCollector {
            onRead: (data) => {
                var text = String(data || "").trim();
                if (text.indexOf("ERROR:") === 0) {
                    root.lastError = text.substring(6).trim();
                }
            }
        }
        onExited: {
            root.isTakingScreenshot = false;
            root.refreshHistory();
        }
    }

    TimedProcess {
        id: recordActionProc
        stdout: StdioCollector {
            onRead: (data) => {
                root.applyRecordStatus(data);
            }
        }
        stderr: StdioCollector {
            onRead: (data) => {
                var text = String(data || "").trim();
                if (text.indexOf("ERROR:") === 0) {
                    root.lastError = text.substring(6).trim();
                }
            }
        }
        onExited: {
            root.refreshRecordingStatus();
        }
    }

    TimedProcess {
        id: recordStatusProc
        stdout: StdioCollector {
            onRead: (data) => {
                root.applyRecordStatus(data);
            }
        }
    }

    TimedProcess {
        id: historyProc
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(text || "").trim();
                if (raw === "") {
                    root.recentCaptures = [];
                    return;
                }
                var entries = [];
                var lines = raw.split(/\r?\n/);
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line === "") continue;
                    var parts = line.split("\t");
                    if (parts.length < 3) continue;
                    var path = parts[1];
                    if (path.charAt(0) !== "/") continue;
                    entries.push({
                        timestamp: parts[0],
                        path: path,
                        kind: parts[2],
                        label: path.substring(path.lastIndexOf("/") + 1)
                    });
                }
                entries.reverse();
                root.recentCaptures = entries;
            }
        }
    }

    TimedProcess {
        id: colorStatusProc
        stdout: StdioCollector {
            onRead: (data) => {
                var color = ScreenshotService.normalizeHexColor(data);
                root.hasColor = color !== "";
                if (root.hasColor) root.lastColorHex = color;
            }
        }
    }

    // ─── Display Profile Operations (Wave 3) ──────────────────────────────────
    function applyDisplayProfile(profile) {
        if (!profile) return;
        var flag = profile.indexOf("--") === 0 ? profile : ("--" + profile);
        displayActionProc.exec(["bash", RuntimePaths.hyprScriptFile("monitor_profile.sh"), flag]);
        activeDisplayProfile = profile.replace(/^--/, "");
    }

    function setDisplayResolution(res) {
        if (!res) return;
        displayActionProc.exec(["bash", RuntimePaths.hyprScriptFile("monitor_profile.sh"), "--set-res", res]);
        activeDisplayResolution = res;
    }

    function cycleDisplayResolution(monitorName) {
        var args = ["bash", RuntimePaths.hyprScriptFile("monitor_profile.sh"), "--cycle-res"];
        if (monitorName) args.push(monitorName);
        displayActionProc.exec(args);
    }

    function setMonitorScale(name, scale) {
        if (!name) return;
        displayActionProc.exec(["bash", RuntimePaths.hyprScriptFile("monitor_profile.sh"), "--set-scale", name, String(scale)]);
    }

    function setMonitorTransform(name, transform) {
        if (!name) return;
        displayActionProc.exec(["bash", RuntimePaths.hyprScriptFile("monitor_profile.sh"), "--set-transform", name, String(transform)]);
    }

    function setMonitorMode(name, mode) {
        if (!name) return;
        displayActionProc.exec(["bash", RuntimePaths.hyprScriptFile("monitor_profile.sh"), "--set-monitor-mode", name, mode]);
    }

    function parseDisplayStatus(rawText) {
        if (!rawText) return;
        var lines = String(rawText).split(/\r?\n/);
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.indexOf("profile=") === 0) {
                root.activeDisplayProfile = line.substring(8).trim();
            } else if (line.indexOf("resolution=") === 0) {
                root.activeDisplayResolution = line.substring(11).trim();
            } else if (line.indexOf("monitors_count=") === 0) {
                var c = parseInt(line.substring(15).trim());
                if (!isNaN(c)) root.connectedMonitorsCount = c;
            } else if (line.indexOf("external_name=") === 0) {
                root.externalMonitorName = line.substring(14).trim();
            } else if (line.indexOf("internal_name=") === 0) {
                root.internalMonitorName = line.substring(14).trim();
            } else if (line.indexOf("available_resolutions=") === 0) {
                var arr = line.substring(22).trim().split(",");
                if (arr.length > 0) root.availableResolutions = arr;
            } else if (line.indexOf("monitors_json=") === 0) {
                try {
                    var rawJson = line.substring(14).trim();
                    var parsed = JSON.parse(rawJson);
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        root.monitorList = parsed;
                    }
                } catch (e) {
                    Logger.warn("UtilityService", "Failed to parse monitors_json", { error: e.message });
                }
            }
        }
        Logger.info("UtilityService", "display status parsed", { count: root.connectedMonitorsCount, ext: root.externalMonitorName, int: root.internalMonitorName, profile: root.activeDisplayProfile, monitors: root.monitorList.length });
    }

    function identifyMonitors() {
        displayActionProc.exec(["bash", RuntimePaths.hyprScriptFile("monitor_profile.sh"), "--identify"]);
    }

    function refreshDisplayProfile() {
        displayStatusProc.exec(["bash", RuntimePaths.hyprScriptFile("monitor_profile.sh"), "status"]);
    }

    TimedProcess {
        id: displayActionProc
        onExited: (exitCode) => {
            root.refreshDisplayProfile();
        }
    }

    TimedProcess {
        id: displayStatusProc
        stdout: StdioCollector {
            id: displayStatusCollector
            onStreamFinished: {
                root.parseDisplayStatus(String(displayStatusCollector.text || ""));
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "")
                    console.warn("[UtilityService displayStatusProc stderr]:", text.trim());
            }
        }
    }

    // ─── Tools & Productivity Operations (Wave 4) ────────────────────────────
    function pickColor() {
        colorPickProc.exec(["bash", RuntimePaths.joinPath(uiScriptsDir, "utility_color_pick.sh"), "pick"]);
    }

    function copyColor(format, hexValue) {
        var fmt = format || "hex";
        if (hexValue) {
            var valToCopy = hexValue;
            for (var i = 0; i < root.colorHistory.length; i++) {
                if (root.colorHistory[i].hex === hexValue) {
                    if (fmt === "rgb" && root.colorHistory[i].rgb) valToCopy = root.colorHistory[i].rgb;
                    else if (fmt === "hsl" && root.colorHistory[i].hsl) valToCopy = root.colorHistory[i].hsl;
                    break;
                }
            }
            fileActionProc.exec(["bash", "-c", "printf '%s' " + JSON.stringify(valToCopy) + " | wl-copy && notify-send -a 'Utility Hub' 'Cor copiada' " + JSON.stringify(valToCopy)]);
        } else {
            colorPickProc.exec(["bash", RuntimePaths.joinPath(uiScriptsDir, "utility_color_pick.sh"), "copy-" + fmt]);
        }
    }

    function refreshColorHistory() {
        colorHistProc.exec(["bash", RuntimePaths.joinPath(uiScriptsDir, "utility_color_pick.sh"), "history"]);
    }

    function togglePresentationMode() {
        presentationMode = !presentationMode;
        presentationProc.exec(["bash", RuntimePaths.joinPath(uiScriptsDir, "presentation_mode.sh"), presentationMode ? "on" : "off"]);
        return presentationMode;
    }

    function toggleAnonymize() {
        anonymizeCapture = !anonymizeCapture;
        ConfigFacade.set("utilityAnonymizeCapture", anonymizeCapture);
        notifyInfo("Anonimização", anonymizeCapture ? "Ativada (dados sensíveis mascarados)" : "Desativada");
        return anonymizeCapture;
    }

    function cycleLensProvider() {
        var providers = ["google", "bing", "yandex"];
        var idx = providers.indexOf(lensProvider);
        lensProvider = providers[(idx + 1) % providers.length];
        ConfigFacade.set("utilityLensProvider", lensProvider);
        notifyInfo("Visual Lens", lensProvider.toUpperCase());
        return lensProvider;
    }

    function cycleOcrLanguage() {
        var langs = ["eng+por", "por", "eng", "spa", "deu"];
        var idx = langs.indexOf(ocrLanguage);
        ocrLanguage = langs[(idx + 1) % langs.length];
        ConfigFacade.set("utilityOcrLang", ocrLanguage);
        notifyInfo("Idioma OCR", ocrLanguage.toUpperCase());
        return ocrLanguage;
    }

    function runOcr() {
        var args = ["bash", RuntimePaths.joinPath(uiScriptsDir, "utility_ocr.sh"), "--lang", ocrLanguage];
        if (anonymizeCapture) args.push("--anonymize");
        ocrProc.exec(args);
    }

    function runLens() {
        var args = ["bash", RuntimePaths.joinPath(uiScriptsDir, "utility_lens_search.sh"), "--confirm", "--provider", lensProvider];
        if (anonymizeCapture) args.push("--anonymize");
        lensProc.exec(args);
    }

    TimedProcess {
        id: colorPickProc
        stdout: StdioCollector {
            onRead: (data) => {
                var color = ScreenshotService.normalizeHexColor(data);
                if (color !== "") {
                    root.hasColor = true;
                    root.lastColorHex = color;
                    root.refreshColorHistory();
                }
            }
        }
    }

    TimedProcess {
        id: colorHistProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(String(text || "[]"));
                    if (Array.isArray(parsed)) {
                        root.colorHistory = parsed.reverse();
                        return;
                    }
                } catch (e) {}
                root.colorHistory = [];
            }
        }
    }

    TimedProcess { id: presentationProc }
    TimedProcess { id: ocrProc }
    TimedProcess { id: lensProc }

    TimedProcess { id: fileActionProc }
    TimedProcess { id: notifyProc }
}
