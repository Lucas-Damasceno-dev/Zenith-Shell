pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "../../core"
import "../../shared"
import "../../shared/IconResolver.js" as IconResolver
import "../../services"
import "../dock"
import "../dashboard"
import "LauncherData.js" as LauncherData
import "LauncherUtils.js" as LauncherUtils
import "LauncherModes.js" as LauncherModes
import "LauncherDangerousPatterns.js" as LauncherDangerousPatterns
import "LauncherConversions.js" as LauncherConversions
import "LauncherEmojis.js" as LauncherEmojis
import "LauncherMetrics.js" as LauncherMetrics
import "LauncherSearchResults.js" as LauncherSearchResults
import "LauncherParsing.js" as LauncherParsing
import "LauncherQuickActions.js" as LauncherQuickActions
import "LauncherWindowRuntime.js" as LauncherWindowRuntime
import "../../core/TextSanitizer.js" as TextSanitizer
import "../../core/ErrorStateMachine.js" as ErrorStateMachine
import "LauncherSessionState.js" as LauncherSessionState

/**
 * Launcher Elite - Glassmorphic application launcher with fuzzy search,
 * rich previews, 12+ search modes, and context actions.
 *
 * Modes:
 *   (default)  Desktop app search (fuzzy)
 *   =          Calculator + unit/currency converter
 *   nix?       NixOS package search
 *   opt?       NixOS option search (manix)
 *   g?         Google web search
 *   /          File search (fd) with rich preview
 *   >          Command execution
 *   cb?        Clipboard history search
 *   em?        Emoji & Nerd Font picker
 *   w?         Active window search (Hyprland IPC)
 *   tr?        Translation (Google Translate)
 *   vol/bri    Hardware controls (volume/brightness)
 *
 * Features:
 *   - Fuzzy search with scoring
 *   - Frecency-based favorites (most used shown first)
 *   - Rich Preview side panel for files, apps, images
 *   - Context actions via Tab key
 *   - Category filter chips
 *   - Morphing search bar with mode indicators
 *   - Cascade + glow animations
 */
AnimatedWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    showScrim: false
    scrimOpacity: 0.0
    glassRadius: 0
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0
    useAtmosphereBackdrop: false

    // ─── State ──────────────────────────────────────────────────
    property string currentMode: "apps"
    property bool previewVisible: false
    property bool previewAltHeld: false

    property int selectedIndex: 0
    property bool contextMenuOpen: false
    property bool filterBarOpen: false
    property bool cheatSheetOpen: false
    property int filterBarIndex: 0
    property int cheatSheetIndex: 0
    
    // Minimal mode: starts as a simple search bar, expands when typing
    property bool minimalMode: true
    property bool minimalExpanded: false
    readonly property bool showMenuOnlyLauncher: filterBarOpen || cheatSheetOpen
    readonly property bool showFullLauncher: !minimalMode || minimalExpanded || (searchField && searchField.text.length > 0)
    readonly property string scriptsDir: RuntimePaths.quickshellScriptsDir
    readonly property string homeDir: RuntimePaths.homeDir
    readonly property string cacheDir: RuntimePaths.cacheDir
    property string pendingDangerousCommand: ""
    property double pendingDangerousUntilMs: 0
    readonly property string launcherFileTool: RuntimePaths.scriptFile("launcher_file_tool.sh")
    readonly property string launcherSystemTool: RuntimePaths.scriptFile("launcher_system_tool.sh")
    readonly property string desktopApplicationsDir: "/run/current-system/sw/share/applications"

    property alias searchFieldObj: launcherSearchBar.searchFieldObj
    property alias resultsModelObj: resultsModel
    property alias appsListObj: resultsPane.appsListObj
    property alias contextListObj: resultsPane.contextListObj
    property alias contextModelObj: contextModel
    property alias filterBarWidget: filterBar
    property alias modeBarWidget: modeBar
    property alias searchField: launcherSearchBar.searchFieldObj
    property alias appsList: resultsPane.appsListObj
    property alias contextList: resultsPane.contextListObj
    property alias previewTitle: previewCard.previewTitleObj
    property alias previewDesc: previewCard.previewDescObj
    property alias previewContent: previewCard.previewContentObj
    property alias previewMeta: previewCard.previewMetaObj
    property alias previewImage: previewCard.previewImageObj
    property alias previewTagsFlow: previewCard.previewTagsFlowObj
    property alias actionFlow: previewCard.actionFlowObj


    property string previewPanelMode: ""
    property string previewHeroSource: ""
    property string launcherErrorText: ""
    property bool _livePreviewRefreshPending: false
    property var launcherState: ErrorStateMachine.idleState()
    property var previewInfoRows: []
    property var previewBluetoothDevices: []
    property bool bluetoothPairPromptVisible: false
    property string bluetoothPairPromptMac: ""
    property string bluetoothPairPromptLabel: ""
    property var previewRunningWindows: []
    property int pendingPreviewIndex: -1
    property int previewRequestGeneration: 0
    property bool searchHasText: false


    property var previewFileDetails: ({
        path: "",
        kind: "",
        sizeHuman: "",
        modified: "",
        permissions: "",
        mime: "",
        parent: "",
        childCount: 0,
        previewNote: ""
    })
    property var previewWindowDetails: ({
        workspaceLabel: "",
        address: "",
        pid: 0,
        ramMiB: 0,
        ramRatio: 0,
        ramText: ""
    })
    readonly property int launcherPanelRadius: DesignTokens.radiusXL
    readonly property int launcherCardRadius: DesignTokens.radiusLG
    readonly property int launcherInnerRadius: DesignTokens.radiusMD
    readonly property int launcherPanelPadding: DesignTokens.spacingXXL
    readonly property int launcherPanelInset: DesignTokens.spacingXL + DesignTokens.spacingXS
    readonly property int launcherCompactHeight: 56
    readonly property int launcherCompactMenuHeight: 116
    readonly property int launcherTopMargin: 96
    readonly property int launcherExpandedMaxHeight: 540
    readonly property int resultsPaneMaxHeight: 360
    readonly property int launcherSectionGap: DesignTokens.spacingXL
    readonly property int launcherBlockGap: DesignTokens.spacingLG
    readonly property int launcherChipGap: DesignTokens.spacingMD
    readonly property color launcherSectionLabelColor: ColorScheme.isDark ? Style.dim : ColorScheme.withAlpha(ColorScheme.text, 0.85)
    readonly property color launcherTextMuted: ColorScheme.isDark ? Style.muted : ColorScheme.withAlpha(ColorScheme.text, 0.75)
    readonly property color launcherTextSoft: ColorScheme.isDark ? ColorScheme.withAlpha(ColorScheme.text, 0.72) : ColorScheme.withAlpha(ColorScheme.text, 0.92)
    readonly property color launcherTextSubtle: ColorScheme.isDark ? ColorScheme.withAlpha(ColorScheme.text, 0.42) : ColorScheme.withAlpha(ColorScheme.text, 0.55)
    readonly property color launcherCardFill: ColorScheme.isDark ? ColorScheme.withAlpha(ColorScheme.surface, 0.28) : ColorScheme.withAlpha(ColorScheme.surface, 0.85)
    readonly property color launcherCardFillStrong: ColorScheme.isDark ? ColorScheme.withAlpha(ColorScheme.surface, 0.34) : ColorScheme.withAlpha(ColorScheme.surface, 0.95)
    readonly property color launcherCardBorder: ColorScheme.isDark ? ColorScheme.withAlpha(ColorScheme.text, 0.06) : ColorScheme.withAlpha(ColorScheme.text, 0.22)
    readonly property color launcherTrackFill: ColorScheme.isDark ? ColorScheme.withAlpha(ColorScheme.text, 0.08) : ColorScheme.withAlpha(ColorScheme.text, 0.18)
    readonly property color launcherModeGlow: ColorScheme.withAlpha(ColorScheme.accent, 0.10)
    readonly property color launcherModeTint: ColorScheme.withAlpha(ColorScheme.accent, 0.04)
    originY: 0.0
    slideY: 0
    property var _cachedAudioSinks: []
    property var normalizeCache: ({})
    readonly property int normalizeCacheMaxSize: 2000
    property bool searchLoading: false
    property string searchLoadingLabel: ""
    property string killSearchTerm: ""
    property string killPendingPid: ""
    property string killStatusText: ""
    property bool killForceAvailable: false
    property string killActionPhase: ""
    property string killSearchSnapshotText: ""
    property bool killSearchSnapshotReady: false
    property bool killSearchSnapshotLoading: false
    property int killSearchSnapshotGeneration: 0
    property var sessionMetrics: ({
        sessionStartMs: 0,
        sessionEndMs: 0,
        durationMs: 0,
        searches: 0,
        modeHits: ({}),
        previews: 0,
        launches: 0,
        kills: 0,
        contextActions: 0,
        asyncSearches: 0,
        errors: 0,
        searchCancels: 0,
        watchdogTimeouts: 0,
        stateRestores: 0,
        lastMode: "",
        lastQuery: ""
    })
    property var launcherSessionState: LauncherSessionState.defaultLauncherState()
    property bool _restoringLauncherState: false
    property bool launcherStateRestorePending: false
    property int searchGeneration: 0

    Component.onCompleted: resetSessionMetrics()

    onPreviewVisibleChanged: {
        if (previewVisible && !FeatureFlags.reducedMotion) {
            // noop, keeps bindings alive for smoother transitions
        }
    }
    Component.onDestruction: flushSessionMetrics()

    // Frecency data (persisted via Process)
    property var frecencyMap: ({})
    property bool frecencyLoaded: false
    property var favoriteAppIds: ({})
    property bool favoriteAppIdsLoaded: false
    property bool favoriteAppIdsPendingWrite: false
    property var _desktopEntriesSnapshot: []
    property string _desktopEntriesStamp: ""
    property bool _desktopEntriesRefreshPending: false
    readonly property var snippetLibrary: LauncherData.snippetLibrary(RuntimePaths)

    function iconFallbackPath(iconName) { return LauncherUtils.iconFallbackPath(iconName, IconResolver); }

    function resolveIconSource(iconName) { return LauncherUtils.resolveIconSource(iconName, IconResolver); }

    function buildIconCandidates(iconName) { return LauncherUtils.buildIconCandidates(iconName, IconResolver); }

    function resolvedModeIconSource(mode) { return LauncherUtils.resolvedModeIconSource(mode, IconResolver); }

    function isDangerousCommand(cmd) { return LauncherDangerousPatterns.isDangerousCommand(cmd); }

    function resetSessionMetrics() {
        sessionMetrics = LauncherMetrics.createSessionMetrics(Date.now());
    }

    function beginSearchLoading(label) {
        searchLoading = true;
        searchLoadingLabel = TextSanitizer.cleanSingleLineText(label);
        launcherState = ErrorStateMachine.loadingState("Busca", searchLoadingLabel, { sanitizeText: TextSanitizer.cleanSingleLineText });
        sessionMetrics.asyncSearches += 1;
    }

    function finishSearchLoading() {
        searchLoading = false;
        searchLoadingLabel = "";
        if (launcherState && launcherState.kind === "loading")
            launcherState = ErrorStateMachine.idleState();
    }

    function setPreviewFooter(parts) {
        previewMeta.text = LauncherMetrics.buildPreviewFooterText(parts);
    }

    function recordSessionSearch(mode, query) {
        LauncherMetrics.recordSearch(sessionMetrics, mode, query);
    }

    function recordSessionPreview(itemType) {
        LauncherMetrics.recordPreview(sessionMetrics, itemType);
    }

    function recordSessionLaunch(itemType) {
        LauncherMetrics.recordLaunch(sessionMetrics, itemType);
    }

    function recordSessionContextAction(action) {
        LauncherMetrics.recordContextAction(sessionMetrics, action);
    }

    function flushSessionMetrics() {
        sessionMetrics = LauncherMetrics.finalizeSessionMetrics(sessionMetrics, Date.now());
        if (!sessionMetrics || !sessionMetrics.sessionStartMs)
            return;
        Logger.info("Launcher", "session metrics", sessionMetrics);
    }

    function launcherResultKey(item) {
        if (!item)
            return "";

        return [
            String(item.type || ""),
            String(item.appId || ""),
            String(item.result || ""),
            String(item.path || ""),
            String(item.term || "")
        ].join("||");
    }

    function captureLauncherSessionState() {
        var currentItem = null;
        if (resultsModel && appsList && appsList.currentIndex >= 0 && appsList.currentIndex < resultsModel.count)
            currentItem = resultsModel.get(appsList.currentIndex);

        return LauncherSessionState.normalizeLauncherState({
            searchText: String(searchField.text || ""),
            selectedIndex: Math.max(0, Number(selectedIndex || 0)),
            selectedItemKey: launcherResultKey(currentItem),
            categoryFilter: String(categoryFilter || ""),
            filterBarIndex: Math.max(0, Number(filterBarIndex || 0)),
            filterBarOpen: filterBarOpen === true,
            cheatSheetOpen: cheatSheetOpen === true
        });
    }

    function persistLauncherSessionState() {
        if (_restoringLauncherState)
            return;
        if (!settingsStore || !settingsStore.ready || !settingsStore.set)
            return;
        persistLauncherStateDebounce.restart();
    }

    function flushLauncherSessionState() {
        if (_restoringLauncherState)
            return;
        launcherSessionState = captureLauncherSessionState();
        if (settingsStore && settingsStore.ready && settingsStore.set)
            settingsStore.set("launcherStateJson", launcherSessionState);
    }

    function loadLauncherSessionState() {
        if (_restoringLauncherState || !isOpen)
            return;

        var stored = LauncherSessionState.defaultLauncherState();
        if (settingsStore && settingsStore.ready && settingsStore.get) {
            var raw = settingsStore.get("launcherStateJson", ({}));
            if (typeof raw === "string") {
                stored = LauncherSessionState.decodeLauncherState(raw);
            } else if (raw && typeof raw === "object") {
                stored = LauncherSessionState.normalizeLauncherState(raw);
            }
        }

        launcherSessionState = stored;
        _restoringLauncherState = true;
        launcherStateRestorePending = true;
        categoryFilter = stored.categoryFilter || "";
        filterBarIndex = Math.max(0, Number(stored.filterBarIndex || 0));
        filterBarOpen = stored.filterBarOpen === true;
        cheatSheetOpen = stored.cheatSheetOpen === true;
        selectedIndex = Math.max(0, Number(stored.selectedIndex || 0));
        searchField.text = stored.searchText || "";
        _restoringLauncherState = false;

        if ((stored.searchText || stored.categoryFilter || stored.selectedItemKey || stored.selectedIndex > 0)) {
            sessionMetrics.stateRestores += 1;
        }
    }

    function applyRestoredSelection() {
        if (!launcherStateRestorePending || !launcherSessionState)
            return false;
        if (resultsModel.count <= 0)
            return false;

        var restoredIndex = -1;
        var restoredKey = String(launcherSessionState.selectedItemKey || "");
        if (restoredKey !== "") {
            for (var i = 0; i < resultsModel.count; i++) {
                if (launcherResultKey(resultsModel.get(i)) === restoredKey) {
                    restoredIndex = i;
                    break;
                }
            }
        }

        if (restoredIndex < 0)
            restoredIndex = Math.max(0, Math.min(Number(launcherSessionState.selectedIndex || 0), resultsModel.count - 1));

        selectedIndex = restoredIndex;
        if (!(currentMode === "apps" && frecencyLoaded === false))
            launcherStateRestorePending = false;
        if (appsList)
            appsList.currentIndex = restoredIndex;
        schedulePreviewUpdate(restoredIndex);
        return true;
    }

    function cancelSearchProcesses(keepLoading) {
        searchGeneration += 1;

        var processes = [
            fileSearch,
            optionsSearch,
            clipboardSearch,
            translateProc,
            recentProjectsSearch,
            recentFilesSearch,
            aiAssistProc,
            unicodeProc
        ];

        var canceled = 0;
        for (var i = 0; i < processes.length; i++) {
            var proc = processes[i];
            if (proc && proc.running === true) {
                proc.kill();
                canceled++;
            }
        }

        if (canceled > 0)
            sessionMetrics.searchCancels += canceled;

        aiLoading = false;
        if (keepLoading !== true)
            finishSearchLoading();
    }

    function isCurrentSearchRequest(proc) {
        return !!(proc && proc.requestGeneration === searchGeneration);
    }

    function reportSearchTimeout(scope, message) {
        sessionMetrics.watchdogTimeouts += 1;
        reportLauncherError(scope, message);
        if (commandRunner && commandRunner.exec) {
            commandRunner.exec([
                "notify-send",
                "-a", "Launcher",
                scope,
                TextSanitizer.cleanSingleLineText(message)
            ]);
        }
    }

    function clearLauncherError() {
        launcherErrorText = "";
        launcherState = ErrorStateMachine.idleState();
    }

    function reportLauncherError(scope, message) {
        var state = ErrorStateMachine.errorState(scope, message, { sanitizeText: TextSanitizer.cleanSingleLineText, recoverable: true });
        if (state.scope === "" && state.message === "")
            return;

        launcherState = state;
        sessionMetrics.errors += 1;
        launcherErrorText = state.summary;
        previewVisible = false;
        finishSearchLoading();
        console.warn("[Launcher] " + state.summary);
    }

    function previewItemNeedsDebounce(item) {
        if (!item)
            return false;

        var type = String(item.type || "");
        if (type === "file" || type === "folder" || type === "recentFile")
            return true;

        if (type === "clipboard" && String(item.extra || "").indexOf("[[ binary data") >= 0)
            return true;

        return false;
    }

    function togglePreviewPanel() {
        previewVisible = !previewVisible;
        if (!previewVisible)
            return;

        var nextIndex = Number(selectedIndex);
        if (!isFinite(nextIndex) || nextIndex < 0)
            nextIndex = appsList ? Number(appsList.currentIndex) : -1;
        if (!isFinite(nextIndex) || nextIndex < 0)
            nextIndex = 0;

        schedulePreviewUpdate(nextIndex);
    }

    function schedulePreviewUpdate(index) {
        previewRequestGeneration += 1;
        pendingPreviewIndex = Number(index);
        if (!isFinite(pendingPreviewIndex) || pendingPreviewIndex < 0) {
            pendingPreviewIndex = -1;
            previewUpdateDebounce.stop();
            previewVisible = false;
            previewAltHeld = false;
            return;
        }

        var item = resultsModel && pendingPreviewIndex >= 0 && pendingPreviewIndex < resultsModel.count
            ? resultsModel.get(pendingPreviewIndex)
            : null;

        if (!previewItemNeedsDebounce(item)) {
            previewUpdateDebounce.stop();
            root.updatePreview(pendingPreviewIndex);
            return;
        }

        previewVisible = false;
        previewUpdateDebounce.restart();
    }

    function refreshDesktopEntriesCache() {
        if (_desktopEntriesRefreshPending)
            return;
        _desktopEntriesRefreshPending = true;
        desktopEntriesStampProc.command = ["stat", "-c", "%Y", desktopApplicationsDir];
        desktopEntriesStampProc.running = false;
        desktopEntriesStampProc.running = true;
    }

    function confirmDangerousCommand(cmd) {
        var normalized = String(cmd || "").trim();
        if (normalized === "") return false;
        var nowMs = Date.now();
        if (pendingDangerousCommand === normalized && nowMs <= pendingDangerousUntilMs) {
            pendingDangerousCommand = "";
            pendingDangerousUntilMs = 0;
            return true;
        }
        pendingDangerousCommand = normalized;
        pendingDangerousUntilMs = nowMs + 5000;
        var safeCommand = TextSanitizer.cleanSingleLineText(normalized);
        if (safeCommand === "")
            safeCommand = normalized;
        commandRunner.exec([
            "notify-send",
            "-a", "Launcher",
            "Comando sensível bloqueado",
            "Repita Enter em até 5s para confirmar: " + safeCommand
        ]);
        return false;
    }

    function runLauncherCommand(mode, commandText, allowDangerous) {
        var args = ["bash", RuntimePaths.scriptFile("launcher_run_command.sh"), mode, commandText || ""];
        if (allowDangerous === true) args.push("--confirm-dangerous");
        commandRunner.exec(args);
    }

    function toggleCheatSheetPopup() {
        cheatSheetOpen = !cheatSheetOpen;
    }

    function openFilterMenu() {
        filterBarOpen = true;
        cheatSheetOpen = false;
        Qt.callLater(function() {
            if (filterBarWidget && filterBarWidget.listViewObj)
                filterBarWidget.listViewObj.forceActiveFocus();
        });
    }

    function openModeMenu() {
        cheatSheetOpen = true;
        filterBarOpen = false;
        Qt.callLater(function() {
            if (modeBarWidget && modeBarWidget.listViewObj)
                modeBarWidget.listViewObj.forceActiveFocus();
        });
    }

    // ─── Fuzzy Search Engine ────────────────────────────────────
    function normalizeText(text) { return LauncherUtils.normalizeText(text, normalizeCache); }

    function fuzzyScore(query, target) { return LauncherUtils.fuzzyScore(query, target, normalizeCache); }

    function htmlEscape(text) { return LauncherUtils.htmlEscape(text); }

    function cleanExecString(cmd) { return LauncherUtils.cleanExecString(cmd); }

    function normalizeAppIdKey(value) {
        return LauncherWindowRuntime.normalizeAppIdKey(value);
    }

    function getToplevelsArray() {
        return LauncherWindowRuntime.getToplevelsArray(Hyprland.toplevels);
    }

    function activeWorkspaceId() {
        return LauncherWindowRuntime.activeWorkspaceId(Hyprland.focusedWorkspace);
    }

    function activeWorkspaceLabel() {
        return LauncherWindowRuntime.activeWorkspaceLabel(Hyprland.focusedWorkspace);
    }

    function fileGlyphForPath(path, explicitExt, isFolder, iconName) {
        return LauncherUtils.fileGlyphForPath(path, explicitExt, isFolder, iconName);
    }

    function windowGlyphForAppId(appId, title) {
        return LauncherUtils.windowGlyphForAppId(appId, title, normalizeText);
    }

    function resultGlyphIcon(item) {
        if (!item) return getModeInfo("apps").icon;
        let type = String(item.type || "");
        if (type === "folder") return fileGlyphForPath(item.path || item.result || "", item.extra || "", true, item.icon || "");
        if (type === "file" || type === "recentFile") return fileGlyphForPath(item.path || item.result || "", item.extra || "", false, item.icon || "");
        if (type === "window") return windowGlyphForAppId(item.appId || "", item.name || "");
        if (type === "project") return "\u{f1d3}";
        return getModeInfo(type || "apps").icon;
    }

    function windowDataForToplevel(tl) {
        return LauncherWindowRuntime.windowDataForToplevel(tl);
    }

    function runningWindowsForApp(appOrId) {
        return LauncherWindowRuntime.runningWindowsForApp(appOrId, Hyprland.toplevels);
    }

    function safeAudioRatio(value) {
        let num = Number(value || 0);
        if (!isFinite(num) || isNaN(num)) return 0;
        return Math.max(0, Math.min(num, 1.5));
    }

    function launcherAudioSinks() {
        let sinksObj = Pipewire.sinks;
        if (!sinksObj) return [];
        let list = [];
        if (typeof sinksObj.length === "number") {
            for (let i = 0; i < sinksObj.length; i++) {
                let sink = sinksObj[i];
                if (sink && sink.audio) list.push(sink);
            }
            return list;
        }
        let vals = typeof sinksObj.values !== "undefined" ? sinksObj.values : null;
        if (vals && typeof vals.length === "number") {
            for (let j = 0; j < vals.length; j++) {
                let item = vals[j];
                if (item && item.audio) list.push(item);
            }
        }
        return list;
    }

    function launcherDefaultSink() {
        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio)
            return Pipewire.defaultAudioSink;
        let sinks = launcherAudioSinks();
        return sinks.length > 0 ? sinks[0] : null;
    }

    function launcherSinkPercent() {
        let sink = launcherDefaultSink();
        return sink && sink.audio ? Math.round(safeAudioRatio(sink.audio.volume) * 100) : 0;
    }

    function launcherSinkMuted() {
        let sink = launcherDefaultSink();
        return !!(sink && sink.audio && sink.audio.muted === true);
    }

    function launcherSetSinkRatio(value) {
        let ratio = safeAudioRatio(value);
        hwControlProc.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", String(ratio)]);
        let sink = launcherDefaultSink();
        if (sink && sink.audio) sink.audio.volume = ratio;
    }

    function launcherToggleMute() {
        hwControlProc.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        let sink = launcherDefaultSink();
        if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
    }

    function launcherMakeSinkDefault(sink) {
        if (!sink) return;
        if (sink.makeDefault) sink.makeDefault();
        else if (sink.id !== undefined && sink.id !== null) hwControlProc.exec(["wpctl", "set-default", String(sink.id)]);
    }

    function appendSystemResults(query) {
        var items = LauncherSearchResults.systemResults(query, normalizeText);
        for (var i = 0; i < items.length; i++) {
            resultsModel.append(items[i]);
        }
    }

    function parentDirectoryForPath(path) {
        let target = String(path || "").trim();
        if (target === "") return "";
        let slashIndex = target.lastIndexOf("/");
        if (slashIndex < 0) return target;
        if (slashIndex === 0) return "/";
        return target.substring(0, slashIndex);
    }

    function openPathInManager(path) {
        let target = String(path || "").trim();
        if (target === "") return;
        runLauncherCommand("open", target, false);
    }

    function revealPathInManager(path) {
        let target = String(path || "").trim();
        if (target === "") return;
        runLauncherCommand("open", target, false);
    }

    function openPathInTerminal(path) {
        let target = String(path || "").trim();
        if (target === "") return;
        runLauncherCommand("terminal-here", target, false);
    }

    function openPathInEditor(path) {
        let target = String(path || "").trim();
        if (target === "") return;
        runLauncherCommand("editor", target, false);
    }

    function resetKillState() {
        killPendingPid = "";
        killStatusText = "";
        killForceAvailable = false;
        killActionPhase = "";
        killProbeTimer.stop();
        if (killProbeProc)
            killProbeProc.requestedPid = "";
    }

    function resetKillSearchSnapshot() {
        killSearchSnapshotGeneration += 1;
        if (killSearchProc && killSearchProc.running === true)
            killSearchProc.kill();
        killSearchSnapshotText = "";
        killSearchSnapshotReady = false;
        killSearchSnapshotLoading = false;
    }

    function applyKillSearchResults(syncPreview) {
        resultsModel.clear();
        LauncherParsing.appendResults(resultsModel, LauncherSearchResults.killResults(killSearchTerm, killSearchSnapshotText, root.normalizeText));
        if (syncPreview === true)
            root.syncPreviewAfterAsyncResults();
    }

    function refreshKillProcessSnapshot() {
        if (killSearchSnapshotLoading)
            return;
        killSearchSnapshotLoading = true;
        killSearchSnapshotGeneration += 1;
        killSearchProc.requestGeneration = killSearchSnapshotGeneration;
        killSearchProc.exec(["ps", "-eo", "pid=,user=,pcpu=,pmem=,comm=,args="]);
    }

    function resetPreviewState() {
        previewRequestGeneration += 1;
        clearLauncherError();
        pendingPreviewIndex = -1;
        previewUpdateDebounce.stop();
        previewTitle.text = "Preview";
        previewDesc.text = "";
        previewContent.text = "";
        previewImage.source = "";
        previewImage.label = "";
        previewHeroSource = "";
        previewMeta.text = "";
        previewTagsFlow.tagsList = [];
        actionFlow.actionsList = [];
        previewInfoRows = [];
        previewPanelMode = "";
        previewBluetoothDevices = [];
        clearBluetoothPairPrompt();
        previewRunningWindows = [];
        resetKillState();
        previewFileDetails = ({
            path: "",
            kind: "",
            sizeHuman: "",
            modified: "",
            permissions: "",
            mime: "",
            parent: "",
            childCount: 0,
            previewNote: ""
        });
        previewWindowDetails = ({
            workspaceLabel: "",
            address: "",
            pid: 0,
            ramMiB: 0,
            ramRatio: 0,
            ramText: ""
        });
    }

    function setPreviewPlainText(text) {
        previewContent.text = htmlEscape(TextSanitizer.cleanMultilineText(text)).split("\n").join("<br>");
    }

    function refreshKillPreviewActions() {
        if (previewPanelMode !== "kill")
            return;
        if (appsList.currentIndex < 0 || appsList.currentIndex >= resultsModel.count)
            return;

        let item = resultsModel.get(appsList.currentIndex);
        if (!item || item.type !== "kill")
            return;

        let killPid = String(item.pid || item.result || "");
        let killCpu = isFinite(item.cpu) ? item.cpu.toFixed(1) + "% CPU" : "CPU";
        let killMem = isFinite(item.mem) ? item.mem.toFixed(1) + "% MEM" : "MEM";

        if (killPendingPid === "" && (killStatusText === "" || killStatusText === "Pronto para encerrar"))
            killPendingPid = killPid;
        if (killStatusText === "")
            killStatusText = "Pronto para encerrar";

        previewTagsFlow.tagsList = ["Processo", item.user || "Usuário", killCpu, killMem];
        previewDesc.text = item.user ? (item.user + " • PID " + killPid) : ("PID " + killPid);
        previewInfoRows = [
            { label: "PID", value: killPid || "—" },
            { label: "Usuário", value: item.user || "—" },
            { label: "CPU", value: isFinite(item.cpu) ? (item.cpu.toFixed(1) + "%") : "—" },
            { label: "Memória", value: isFinite(item.mem) ? (item.mem.toFixed(1) + "%") : "—" }
        ];
        setPreviewPlainText(item.command || item.name || "Processo");
        setPreviewFooter([
            { label: "Estado", value: killStatusText || "Pronto para encerrar" },
            { label: "PID", value: killPid || "—" },
            { label: "Usuário", value: item.user || "—" },
            { label: "CPU", value: isFinite(item.cpu) ? (item.cpu.toFixed(1) + "%") : "—" },
            { label: "Memória", value: isFinite(item.mem) ? (item.mem.toFixed(1) + "%") : "—" }
        ]);
        actionFlow.actionsList = LauncherQuickActions.buildKillActions({
            pid: killPid,
            command: item.command || item.name || "",
            commandRunner: commandRunner,
            runtimePaths: RuntimePaths,
            confirmDangerousCommand: confirmDangerousCommand,
            killForceAvailable: killForceAvailable,
            requestKillTerm: requestKillTermination,
            requestKillForce: requestKillForce
        });
    }

    function requestKillTermination(pid, command) {
        let killPid = String(pid || killPendingPid || "").trim();
        if (killPid === "")
            return false;
        if (killActionPhase !== "") {
            killStatusText = killActionPhase === "force"
                ? "SIGKILL já enviado. Aguardando resposta…"
                : "SIGTERM já enviado. Aguardando resposta…";
            refreshKillPreviewActions();
            return false;
        }
        if (!confirmDangerousCommand("kill -TERM " + killPid))
            return false;

        killPendingPid = killPid;
        killForceAvailable = false;
        killActionPhase = "term";
        killStatusText = "SIGTERM enviado. Verificando resposta…";
        commandRunner.exec(["kill", "-TERM", killPid]);
        recordSessionLaunch("kill");
        killProbeTimer.restart();
        refreshKillPreviewActions();
        return false;
    }

    function requestKillForce(pid, command) {
        let killPid = String(pid || killPendingPid || "").trim();
        if (killPid === "")
            return false;
        if (killActionPhase !== "") {
            killStatusText = killActionPhase === "force"
                ? "SIGKILL já enviado. Aguardando resposta…"
                : "SIGTERM ainda está em avaliação.";
            refreshKillPreviewActions();
            return false;
        }
        if (!confirmDangerousCommand("kill -KILL " + killPid))
            return false;

        killPendingPid = killPid;
        killForceAvailable = false;
        killActionPhase = "force";
        killStatusText = "SIGKILL enviado. Verificando encerramento…";
        commandRunner.exec(["kill", "-KILL", killPid]);
        recordSessionLaunch("kill");
        killProbeTimer.restart();
        refreshKillPreviewActions();
        return false;
    }

    function updateFileInfoRows() {
        if (!previewFileDetails || !previewFileDetails.path) {
            previewInfoRows = [];
            return;
        }
        let rows = [];
        rows.push({ label: previewFileDetails.kind === "directory" ? "Itens" : "Tamanho", value: previewFileDetails.sizeHuman || "—" });
        rows.push({ label: "Modificado", value: previewFileDetails.modified || "—" });
        rows.push({ label: "Permissões", value: previewFileDetails.permissions || "—" });
        rows.push({ label: "Tipo", value: previewFileDetails.mime || (previewFileDetails.kind === "directory" ? "Pasta" : "Arquivo") });
        rows.push({ label: "Caminho", value: previewFileDetails.path || "—" });
        previewInfoRows = rows;
        setPreviewFooter([
            { label: "Caminho", value: previewFileDetails.path || "—" },
            { label: "Tipo", value: previewFileDetails.kind === "directory" ? "Pasta" : "Arquivo" }
        ]);
    }

    function updateBluetoothInfoRows() {
        let connected = 0;
        for (let i = 0; i < previewBluetoothDevices.length; i++) {
            if (previewBluetoothDevices[i] && previewBluetoothDevices[i].connected === true) connected++;
        }
        previewInfoRows = [
            { label: "Estado", value: bluetoothStatusProc.statusEnabled ? "Ligado" : "Desligado" },
            { label: "Dispositivos", value: String(previewBluetoothDevices.length) },
            { label: "Conectados", value: String(connected) }
        ];
    }

    function clearBluetoothPairPrompt() {
        bluetoothPairPromptVisible = false;
        bluetoothPairPromptMac = "";
        bluetoothPairPromptLabel = "";
    }

    function requestBluetoothPairPrompt(device) {
        var mac = String(device && device.mac || "").trim();
        if (mac === "")
            return;

        bluetoothPairPromptMac = mac;
        bluetoothPairPromptLabel = String(device && device.name || mac).trim() || mac;
        bluetoothPairPromptVisible = true;
    }

    function submitBluetoothPairPrompt(pin) {
        var mac = String(bluetoothPairPromptMac || "").trim();
        var label = String(bluetoothPairPromptLabel || mac || "Dispositivo").trim() || mac || "Dispositivo";
        var pinValue = String(pin || "").trim();

        if (mac === "") {
            clearBluetoothPairPrompt();
            return;
        }

        clearBluetoothPairPrompt();
        previewActionProc.exec(["bash", launcherSystemTool, "bt-device", "pair", mac, pinValue]);
        commandRunner.exec(["notify-send", "-a", "Launcher", "Bluetooth", "Pareando " + label + (pinValue !== "" ? " com PIN" : "") + "..."]);
    }

    function handleBluetoothDeviceAction(device) {
        var mac = String(device && device.mac || "").trim();
        if (mac === "")
            return;

        if (device && device.connected === true) {
            previewActionProc.exec(["bash", launcherSystemTool, "bt-device", "disconnect", mac]);
        } else if (device && device.paired === true) {
            previewActionProc.exec(["bash", launcherSystemTool, "bt-device", "connect", mac]);
        } else {
            requestBluetoothPairPrompt(device);
        }
    }

    function updateWifiInfoRows() {
        let status = wifiStatusProc.statusEnabled ? "Ligado" : "Desligado";
        let rows = [
            { label: "Estado", value: status },
            { label: "Rede atual", value: wifiStatusProc.ssid || "Nenhuma" }
        ];
        if (wifiStatusProc.signal > 0) rows.push({ label: "Sinal", value: wifiStatusProc.signal + "%" });
        previewInfoRows = rows;
    }

    function updateWindowInfoRows() {
        if (!previewWindowDetails) return;
        let rows = [
            { label: "Workspace", value: previewWindowDetails.workspaceLabel || "—" },
            { label: "Endereço", value: previewWindowDetails.address || "—" }
        ];
        if (previewWindowDetails.pid > 0) rows.push({ label: "PID", value: String(previewWindowDetails.pid) });
        if (previewWindowDetails.ramText) rows.push({ label: "RAM", value: previewWindowDetails.ramText });
        previewInfoRows = rows;
    }





    function refreshBluetoothPreview() {
        bluetoothStatusProc.requestGeneration = previewRequestGeneration;
        bluetoothDevicesProc.requestGeneration = previewRequestGeneration;
        bluetoothStatusProc.exec(["bash", launcherSystemTool, "bt-status"]);
        bluetoothDevicesProc.exec(["bash", RuntimePaths.scriptFile("network_bt_devices.sh")]);
    }

    function refreshWifiPreview() {
        wifiStatusProc.requestGeneration = previewRequestGeneration;
        wifiStatusProc.exec(["bash", launcherSystemTool, "wifi-status"]);
    }

    function refreshWindowMemoryPreview() {
        if (previewWindowDetails && previewWindowDetails.pid > 0) {
            windowMemoryProc.requestGeneration = previewRequestGeneration;
            windowMemoryProc.requestedPid = String(previewWindowDetails.pid);
            windowMemoryProc.exec(["bash", launcherSystemTool, "window-memory", String(previewWindowDetails.pid)]);
        }
    }

    function queueLivePreviewRefresh() {
        if (!root.isOpen)
            return;
        root._livePreviewRefreshPending = true;
        livePreviewRefreshDebounce.restart();
    }

    function refreshLivePreview() {
        previewRequestGeneration += 1;

        if (previewPanelMode === "system_bluetooth") refreshBluetoothPreview();
        if (previewPanelMode === "system_wifi") refreshWifiPreview();
        if (previewPanelMode === "window") refreshWindowMemoryPreview();
    }

    // ─── Data Model ─────────────────────────────────────────────
    ListModel { id: resultsModel }

    function detectMode(query) { return LauncherModes.detectMode(query); }

    function getModeInfo(mode) { return LauncherModes.getModeInfo(mode); }

    function getModeColor(mode) {
        var colorName = LauncherModes.getModeColor(mode);
        return ColorScheme[colorName] || ColorScheme.accent;
    }

    function requestSearchUpdate(text) {
        var query = String(text || "");
        if (searchField.text !== query)
            searchField.text = query;

        if (query === "") {
            if (searchDebounce) searchDebounce.stop();
            if (searchDebounceApp) searchDebounceApp.stop();
            root.updateSearch();
            return;
        }

        if (LauncherModes.detectMode(query) === "apps") {
            if (searchDebounce) searchDebounce.stop();
            if (searchDebounceApp) searchDebounceApp.restart();
            else root.updateSearch();
            return;
        }

        if (searchDebounceApp) searchDebounceApp.stop();
        if (searchDebounce) searchDebounce.restart();
        else root.updateSearch();
    }

    // ─── Main Search Dispatcher ─────────────────────────────────
    function updateSearch() {
        let query = searchField.text;
        let mode = detectMode(query);
        cancelSearchProcesses(mode === "kill" && killSearchSnapshotLoading);
        resultsModel.clear();
        resetPreviewState();
        if ((normalizeCache.__count || 0) > normalizeCacheMaxSize)
            normalizeCache = ({});
        if (!(mode === "kill" && killSearchSnapshotLoading))
            finishSearchLoading();
        currentMode = mode;
        recordSessionSearch(mode, query);

        switch (mode) {
            case "calc":      searchCalc(query.substring(1)); break;
            case "nix":       searchNix(query.substring(4).trim()); break;
            case "options":   searchOptions(query.substring(4).trim()); break;
            case "web":       searchWeb(query.substring(2).trim()); break;
            case "files":     searchFiles(query.substring(1).trim()); break;
            case "cmd":       searchCmd(query.substring(1).trim()); break;
            case "clipboard": searchClipboard(query.substring(3).trim()); break;
            case "emoji":     searchEmoji(query.substring(3).trim()); break;
            case "windows":   searchWindows(query.substring(2).trim()); break;
            case "translate": searchTranslate(query.substring(3).trim()); break;
            case "recentProjects": searchRecentProjects(query.substring(3).trim()); break;

            case "recentFiles": searchRecentFiles(query.substring(3).trim()); break;
            case "snippets": searchSnippets(query.substring(3).trim()); break;
            case "ai": searchAiAssist(query.substring(3).trim()); break;
            case "unicode": searchUnicode(query.substring(3).trim()); break;
            case "kill": searchKill(query.substring(5).trim()); break;
            case "volume":    searchVolume(query.substring(4).trim()); break;
            case "brightness":searchBrightness(query.substring(4).trim()); break;
            default:          searchApps(query); break;
        }

        if (currentMode !== "apps")
            retryDesktopEntries.stop();

        if (resultsModel.count > 0) {
            schedulePreviewUpdate(appsList.currentIndex);
        } else {
            previewVisible = false;
        }
    }

    // ─── App Search (Fuzzy + Frecency) ──────────────────────────
    function searchApps(query) {
        appendSystemResults(query);
        let apps = getAppsArray();
        if (apps.length === 0)
            ensureDesktopEntriesRetry();
        else
            retryDesktopEntries.stop();
        let scored = LauncherSearchResults.scoreApplications(query, apps, {
            categoryFilter: categoryFilter,
            normalizeText: normalizeText,
            fuzzyScore: fuzzyScore,
            frecencyMap: frecencyMap,
            favoriteAppIds: favoriteAppIds
        });
        let limit = Math.min(scored.length, 30);
        for (let j = 0; j < limit; j++) {
            let s = scored[j];
            let categories = (s.app.categories || []).join(", ");
            resultsModel.append({
                "name": s.app.name,
                "description": s.app.genericName || s.app.comment || "",
                "icon": inferAppIcon(s.app),
                "type": "app",
                "appId": s.app.id || "",
                "appIdx": s.idx,
                "extra": categories,
                "path": "",
                "result": "",
                "term": "",
                "score": s.score,
                "favorite": s.favorite === true,
                "frecency": s.frecency || 0
            });
        }
    }

    // ─── Calculator + Unit/Currency Converter ───────────────────
    function searchCalc(expr) {
        if (expr === "") return;

        let conv = LauncherConversions.convertExpression(expr);
        if (conv) {
            resultsModel.append({
                "name": String(conv.formatted),
                "description": conv.label + ": " + conv.inputFormatted + " = " + conv.formatted,
                "icon": "accessories-calculator",
                "type": "calc",
                "result": String(conv.value),
                "appId": "",
                "appIdx": 0,
                "extra": "",
                "path": "",
                "term": "",
                "score": 1000
            });
            return;
        }

        let result = LauncherUtils.safeMathEvaluate(expr);
        if (result === null)
            return;

        resultsModel.append({
            "name": String(result),
            "description": "Resultado de " + expr,
            "icon": "accessories-calculator",
            "type": "calc",
            "result": String(result),
            "appId": "",
            "appIdx": 0,
            "extra": "",
            "path": "",
            "term": "",
            "score": 0
        });
    }

    function convertUnit(val, from, to) { return LauncherConversions.convertUnit(val, from, to); }

    // ─── NixOS Package Search ───────────────────────────────────
    function searchNix(term) {
        if (term === "") return;
        resultsModel.append({
            "name": "NixOS Packages: " + term,
            "description": "Abrir search.nixos.org",
            "icon": "nix-snowflake", "type": "web",
            "term": "https://search.nixos.org/packages?query=" + encodeURIComponent(term),
            "appId": "", "appIdx": 0, "extra": "", "path": "", "result": "", "score": 0
        });
    }

    // ─── NixOS Options Search ───────────────────────────────────
    function searchOptions(term) {
        if (term.length > 2) {
            beginSearchLoading("opções");
            optionsSearch.requestGeneration = searchGeneration;
            optionsSearch.exec(["manix", term]);
        }
    }

    // ─── Web Search ─────────────────────────────────────────────
    function searchWeb(term) {
        if (term === "") return;
        resultsModel.append({
            "name": "Google: " + term,
            "description": "Pesquisar na web",
            "icon": "", "type": "web",
            "term": "https://google.com/search?q=" + encodeURIComponent(term),
            "appId": "", "appIdx": 0, "extra": "", "path": "", "result": "", "score": 0
        });
        // Also suggest DuckDuckGo
        resultsModel.append({
            "name": "DuckDuckGo: " + term,
            "description": "Pesquisa privada",
            "icon": "", "type": "web",
            "term": "https://duckduckgo.com/?q=" + encodeURIComponent(term),
            "appId": "", "appIdx": 0, "extra": "", "path": "", "result": "", "score": 0
        });
    }

    // ─── File Search ────────────────────────────────────────────
    function searchFiles(term) {
        var home = root.homeDir || RuntimePaths.homeDir;
        if (home === "" || home === "/") home = RuntimePaths.homeDir;
        beginSearchLoading("arquivos");
        fileSearch.requestGeneration = searchGeneration;
        fileSearch.exec(["bash", launcherFileTool, "search", String(term || ""), home]);
    }

    // ─── Command Execution ──────────────────────────────────────
    function searchCmd(cmd) {
        if (cmd === "") return;
        var dangerous = isDangerousCommand(cmd);
        resultsModel.append({
            "name": "$ " + cmd,
            "description": dangerous ? "Comando sensível (exige confirmação dupla)" : "Executar comando no shell",
            "icon": "", "type": "cmd",
            "appId": "", "appIdx": 0, "extra": "", "path": "", "result": cmd, "term": "", "score": 0,
            "dangerous": dangerous
        });
        // Offer to run in terminal too
        resultsModel.append({
            "name": "Terminal: " + cmd,
            "description": dangerous ? "Comando sensível no terminal (exige confirmação dupla)" : "Executar em kitty (resultado visivel)",
            "icon": "", "type": "cmd_terminal",
            "appId": "", "appIdx": 0, "extra": "", "path": "", "result": cmd, "term": "", "score": 0,
            "dangerous": dangerous
        });
    }

    // ─── Clipboard History ──────────────────────────────────────
    function searchClipboard(term) {
        clipboardSearchTerm = term;
        beginSearchLoading("clipboard");
        clipboardSearch.requestGeneration = searchGeneration;
        clipboardSearch.exec(["cliphist", "list"]);
    }
    property string clipboardSearchTerm: ""
    property string clipboardPreviewId: ""

    // ─── Emoji & Nerd Font Picker ───────────────────────────────
    function searchEmoji(term) {
        var items = LauncherEmojis.search(term, normalizeText);
        for (var i = 0; i < items.length; i++) {
            resultsModel.append(items[i]);
        }
    }

    // ─── Unicode Character Lookup ───────────────────────────────
    function searchUnicode(term) {
        if (term.length < 1) {
            // Show help text when no search term
            resultsModel.append({
                "name": "Pesquisar caracteres Unicode",
                "description": "Ex.: uc? arrow, uc? pi, uc? heart, uc? U+2192",
                "icon": "", "type": "unicode",
                "result": "",
                "appId": "", "appIdx": 0, "extra": "", "path": "", "term": "", "score": 0
            });
            return;
        }
        beginSearchLoading("Unicode");
        unicodeProc.requestGeneration = searchGeneration;
        unicodeProc.exec(["bash", RuntimePaths.scriptFile("unicode_lookup.sh"), term]);
        // Add placeholder while searching
        resultsModel.append({
            "name": "Pesquisando: " + term,
            "description": "Buscando caracteres Unicode...",
            "icon": "", "type": "unicode",
            "result": "",
            "appId": "", "appIdx": 0, "extra": "", "path": "", "term": term, "score": 0
        });
    }

    // ─── Window Search (Hyprland IPC) ───────────────────────────
    property var _toplevelRefs: []

    function searchWindows(term) {
        let normTerm = normalizeText(term);
        _toplevelRefs = [];
        let toplevels = getToplevelsArray();
        let scored = [];

        for (let i = 0; i < toplevels.length; i++) {
            let data = windowDataForToplevel(toplevels[i]);
            let titleScore = fuzzyScore(term, data.title);
            let appScore = fuzzyScore(term, data.appId);
            let wsScore = fuzzyScore(term, data.workspaceLabel);
            let bestScore = Math.max(titleScore, appScore * 0.8, wsScore * 0.4);

            if (bestScore > 0 || term === "") {
                scored.push({
                    tl: toplevels[i],
                    data: data,
                    score: bestScore
                });
            }
        }

        scored.sort((a, b) => b.score - a.score);

        for (let j = 0; j < scored.length; j++) {
            let s = scored[j];
            _toplevelRefs.push(s.tl);
            let targetAppId = s.data.appId || "";
            let app = resolveAppFromItem(targetAppId);
            let iconName = app ? inferAppIcon(app) : targetAppId;
            if (!iconName || iconName === "") iconName = "preferences-system-windows";

            resultsModel.append({
                "name": s.data.title || targetAppId || "Untitled",
                "description": (targetAppId || "Janela") + " • " + s.data.workspaceLabel,
                "icon": iconName,
                "type": "window",
                "extra": String(_toplevelRefs.length - 1),
                "appId": targetAppId,
                "appIdx": 0,
                "path": s.data.address,
                "result": s.data.workspaceId,
                "term": String(s.data.pid || ""),
                "score": s.score
            });
        }
    }

    // ─── Translation ────────────────────────────────────────────
    function searchTranslate(term) {
        if (term.length < 2) return;
        beginSearchLoading("tradução");
        translateProc.requestGeneration = searchGeneration;
        translateProc.exec(["bash", RuntimePaths.scriptFile("launcher_translate.sh"), term]);
        // Add placeholder
        resultsModel.append({
            "name": "Traduzindo: " + term,
            "description": "Aguardando...",
            "icon": "", "type": "translate",
            "result": term,
            "appId": "", "appIdx": 0, "extra": "", "path": "", "term": "", "score": 0
        });
    }

    function searchRecentProjects(term) {
        beginSearchLoading("projetos recentes");
        recentProjectsSearch.requestGeneration = searchGeneration;
        recentProjectsSearch.exec(["bash", RuntimePaths.scriptFile("launcher_recent_projects.sh"), term || ""]);
    }

    function searchRecentFiles(term) {
        beginSearchLoading("arquivos recentes");
        recentFilesSearch.requestGeneration = searchGeneration;
        recentFilesSearch.exec(["bash", RuntimePaths.scriptFile("launcher_recent_files.sh"), term || ""]);
    }

    function searchSnippets(term) {
        var items = LauncherSearchResults.snippetResults(term, snippetLibrary, normalizeText);
        for (var i = 0; i < items.length; i++) {
            resultsModel.append(items[i]);
        }
    }

    // ─── AI State ──────────────────────────────────────────────
    property string aiTier: "default"
    property string aiPrimaryText: ""
    property string aiSecondaryText: ""
    property var aiAllTexts: []
    property bool aiLoading: false
    property string aiPromptText: ""
    property string aiLastErrorText: ""

    function trimBlankEdges(text) {
        return String(text || "").trim();
    }

    function cleanAiResponseText(text) {
        return TextSanitizer.cleanAiResponseText(text);
    }

    function aiModelLabel(key) {
        let labels = {
            "primary": "Modelo principal",
            "secondary": "Segunda opinião",
            "flash": "Gemini Flash",
            "pro": "Gemini Pro",
            "gpt41": "GPT-4.1",
            "gpt5mini": "GPT-5-mini",
            "gpt53codex": "GPT-5.3 Codex"
        };
        return labels[String(key || "")] || String(key || "Modelo");
    }

    function aiRichText(text, placeholder) {
        let value = TextSanitizer.cleanAiResponseText(text);
        if (value === "") return "<font color='" + root.launcherTextMuted + "'><i>" + htmlEscape(placeholder || "Sem resposta ainda") + "</i></font>";
        return root.htmlEscape(value).split("\n").join("<br>");
    }

    function normalizeHyprAddress(address) {
        let value = trimBlankEdges(address);
        if (value === "") return "";
        return value.startsWith("0x") ? value : ("0x" + value);
    }

    function hyprDispatch(command, argument) {
        let arg = trimBlankEdges(argument);
        let fullCmd = command + (arg !== "" ? (" " + arg) : "");
        Hyprland.dispatch(fullCmd);
    }

    function hyprFocusWindow(address, ref) {
        let normalized = normalizeHyprAddress(address);
        if (normalized !== "") commandRunner.exec(["bash", "-c", "hyprctl dispatch focuswindow address:" + normalized + " || hyprctl dispatch focuswindow " + normalized]);
        else if (ref && ref.activate) ref.activate();
    }

    function hyprGoToWindow(address, workspaceId, ref) {
        let normalized = normalizeHyprAddress(address);
        if (normalized === "") {
            if (ref && ref.activate) ref.activate();
            return;
        }
        let ws = String(workspaceId || "");
        if (ws !== "" && ws !== "?") {
            // Sequential execution with a tiny guard delay to prevent Hyprland IPC race
            commandRunner.exec(["bash", "-c", "hyprctl dispatch workspace " + ws + " && sleep 0.05 && hyprctl dispatch focuswindow address:" + normalized]);
        } else {
            commandRunner.exec(["bash", "-c", "hyprctl dispatch focuswindow address:" + normalized]);
        }
    }

    function hyprMoveWindowToWorkspace(address, workspaceId, ref) {
        let normalized = normalizeHyprAddress(address);
        if (normalized === "") {
            if (ref && ref.activate) ref.activate();
            return;
        }
        let ws = String(workspaceId || activeWorkspaceId());
        commandRunner.exec([
            "bash", "-c",
            "hyprctl dispatch movetoworkspacesilent " + ws + ",address:" + normalized + " && hyprctl dispatch workspace " + ws + " && hyprctl dispatch focuswindow address:" + normalized
        ]);
    }

    function hyprCloseWindow(address, ref) {
        let normalized = normalizeHyprAddress(address);
        if (normalized !== "") commandRunner.exec(["bash", "-c", "hyprctl dispatch closewindow address:" + normalized]);
        else if (ref && ref.close) ref.close();
    }

    function modeIconName(mode) { return LauncherUtils.modeIconName(mode); }

    function inferAppIcon(app) { return LauncherUtils.inferAppIcon(app, normalizeCache); }

    function clipboardImageTitle(clipId, content) {
        let meta = String(content || "");
        let pathMatch = meta.match(/(?:^|[\s"'=])((?:\/[^\s"']+)+\.(?:png|jpe?g|gif|webp|bmp|svg|avif))/i);
        if (pathMatch && pathMatch[1]) {
            let parts = pathMatch[1].split("/");
            return parts[parts.length - 1];
        }
        let fileNameMatch = meta.match(/([A-Za-z0-9._-]+\.(?:png|jpe?g|gif|webp|bmp|svg|avif))/i);
        if (fileNameMatch && fileNameMatch[1]) return fileNameMatch[1];
        let mimeMatch = meta.match(/image\/([a-zA-Z0-9.+-]+)/);
        let sizeMatch = meta.match(/(\d{2,5}x\d{2,5})/i);
        let sizeLabel = sizeMatch && sizeMatch[1] ? (" • " + sizeMatch[1]) : "";
        let mimeLabel = mimeMatch && mimeMatch[1] ? mimeMatch[1].toUpperCase() : "Imagem";
        return "Imagem " + mimeLabel + sizeLabel + (clipId ? (" • item " + clipId) : "");
    }

    function syncPreviewAfterAsyncResults() {
        if (applyRestoredSelection())
            return;
        if (currentMode === "ai") {
            if (resultsModel.count > 0)
                schedulePreviewUpdate(0);
            return;
        }
        if (resultsModel.count <= 0) {
            previewVisible = false;
            return;
        }
        selectedIndex = 0;
        if (appsList) appsList.currentIndex = 0;
        schedulePreviewUpdate(0);
    }

    function parseAiTier(term) {
        let trimmed = term.trim();
        if (trimmed.startsWith("fast "))  return { tier: "fast",  prompt: trimmed.substring(5).trim() };
        if (trimmed.startsWith("smart ")) return { tier: "smart", prompt: trimmed.substring(6).trim() };
        if (trimmed.startsWith("all "))   return { tier: "all",   prompt: trimmed.substring(4).trim() };
        return { tier: "default", prompt: trimmed };
    }

    function searchAiAssist(term) {
        if (term.length < 2) return;
        let parsed = parseAiTier(term);
        if (parsed.prompt.length < 2) {
            aiTier = parsed.tier;
            aiPromptText = "";
            aiPrimaryText = "";
            aiSecondaryText = "";
            aiAllTexts = [];
            aiLoading = false;
            aiLastErrorText = "";
            finishSearchLoading();
            resultsModel.clear();
            resultsModel.append({
                "name": "Descreva o pedido para a IA",
                "description": "Ex.: ai? fast explique este erro",
                "icon": "applications-science",
                "type": "ai_assist",
                "result": "",
                "appId": "", "appIdx": 0, "extra": "", "path": "", "term": parsed.tier, "score": 0
            });
            previewVisible = false;
            schedulePreviewUpdate(0);
            return;
        }
        aiTier = parsed.tier;
        aiPromptText = parsed.prompt;
        aiPrimaryText = "";
        aiSecondaryText = "";
        aiAllTexts = [];
        beginSearchLoading("IA");
        aiLoading = true;
        aiLastErrorText = "";
        previewImage.source = resolvedModeIconSource("ai");
        aiAssistProc.requestGeneration = searchGeneration;

        let tierLabels = { "default": "Equilibrado", "fast": "Rápido", "smart": "Profundo", "all": "Todos" };
        resultsModel.clear();
        resultsModel.append({
            "name": "IA " + (tierLabels[aiTier] || ""),
            "description": "Processando: " + parsed.prompt.substring(0, 60),
            "icon": "applications-science",
            "type": "ai_assist",
            "result": "",
            "appId": "", "appIdx": 0, "extra": parsed.prompt, "path": "", "term": aiTier, "score": 0
        });
        previewVisible = false;
        schedulePreviewUpdate(0);

        aiAssistProc.exec(["bash", RuntimePaths.scriptFile("launcher_ai_opencode.sh"), aiTier, parsed.prompt]);
    }

    // ─── Hardware Controls ──────────────────────────────────────
    function searchVolume(val) {
        let levels = ["0", "10", "20", "30", "40", "50", "60", "70", "80", "90", "100", "toggle"];
        let normVal = val.trim().toLowerCase();
        for (let lv of levels) {
            if (normVal === "" || lv.startsWith(normVal)) {
                resultsModel.append({
                    "name": lv === "toggle" ? "Volume: Mutar/Desmutar" : "Volume " + lv + "%",
                    "description": lv === "toggle" ? "Mute/Unmute" : "Definir volume para " + lv + "%",
                    "icon": "", "type": "hw_volume",
                    "result": lv,
                    "appId": "", "appIdx": 0, "extra": "", "path": "", "term": "", "score": 0
                });
            }
        }
    }

    function searchBrightness(val) {
        let levels = ["0", "10", "20", "30", "40", "50", "60", "70", "80", "90", "100"];
        let normVal = val.trim().toLowerCase();
        for (let lv of levels) {
            if (normVal === "" || lv.startsWith(normVal)) {
                resultsModel.append({
                    "name": "Brilho " + lv + "%",
                    "description": "Definir brilho para " + lv + "%",
                    "icon": "", "type": "hw_brightness",
                    "result": lv,
                    "appId": "", "appIdx": 0, "extra": "", "path": "", "term": "", "score": 0
                });
            }
        }
    }

    function searchKill(term) {
        killSearchTerm = term;
        if (killSearchSnapshotReady) {
            applyKillSearchResults(false);
            return;
        }

        if (!searchLoading)
            beginSearchLoading("processos");
        refreshKillProcessSnapshot();
    }

    Timer {
        id: killSnapshotRefreshTimer
        interval: 5000
        repeat: true
        running: root.isOpen && root.currentMode === "kill"
        triggeredOnStart: true
        onTriggered: root.refreshKillProcessSnapshot()
    }

    // ─── Processes ──────────────────────────────────────────────
    TimedProcess {
        id: fileSearch
        timeoutMs: 10000
        timeoutLabel: "Busca de arquivos"
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isCurrentSearchRequest(fileSearch))
                    return;
                try {
                    LauncherParsing.appendResults(resultsModel, LauncherParsing.parseFileSearchOutput(text, root.homeDir));
                    root.finishSearchLoading();
                    root.syncPreviewAfterAsyncResults();
                } catch (e) {
                    root.finishSearchLoading();
                    root.reportLauncherError("Busca de arquivos", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] fileSearch parse error:", e);
                }
            }
        }
        onTimedOut: {
            if (!root.isCurrentSearchRequest(fileSearch))
                return;
            root.reportSearchTimeout("Busca de arquivos", "A busca por arquivos demorou demais e foi interrompida.");
        }
        onFailed: function(exitCode) {
            if (!root.isCurrentSearchRequest(fileSearch))
                return;
            root.finishSearchLoading();
            root.reportLauncherError("Busca de arquivos", "Falhou com exit " + exitCode);
        }
    }

    TimedProcess {
        id: optionsSearch
        timeoutMs: 10000
        timeoutLabel: "Busca de opções"
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isCurrentSearchRequest(optionsSearch))
                    return;
                try {
                    LauncherParsing.appendResults(resultsModel, LauncherParsing.parseOptionsOutput(text));
                    root.finishSearchLoading();
                    root.syncPreviewAfterAsyncResults();
                } catch (e) {
                    root.finishSearchLoading();
                    root.reportLauncherError("Busca de opções", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] optionsSearch parse error:", e);
                }
            }
        }
        onTimedOut: {
            if (!root.isCurrentSearchRequest(optionsSearch))
                return;
            root.reportSearchTimeout("Busca de opções", "A busca de opções demorou demais e foi interrompida.");
        }
        onFailed: function(exitCode) {
            if (!root.isCurrentSearchRequest(optionsSearch))
                return;
            root.finishSearchLoading();
            root.reportLauncherError("Busca de opções", "Falhou com exit " + exitCode);
        }
    }

    TimedProcess {
        id: clipboardSearch
        timeoutMs: 10000
        timeoutLabel: "Busca do clipboard"
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isCurrentSearchRequest(clipboardSearch))
                    return;
                try {
                    LauncherParsing.appendResults(resultsModel, LauncherParsing.parseClipboardSearchOutput(text, root.clipboardSearchTerm, root.normalizeText));
                    root.finishSearchLoading();
                    root.syncPreviewAfterAsyncResults();
                } catch (e) {
                    root.finishSearchLoading();
                    root.reportLauncherError("Clipboard", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] clipboardSearch parse error:", e);
                }
            }
        }
        onTimedOut: {
            if (!root.isCurrentSearchRequest(clipboardSearch))
                return;
            root.reportSearchTimeout("Clipboard", "A busca do clipboard demorou demais e foi interrompida.");
        }
        onFailed: function(exitCode) {
            if (!root.isCurrentSearchRequest(clipboardSearch))
                return;
            root.finishSearchLoading();
            root.reportLauncherError("Clipboard", "Falhou com exit " + exitCode);
        }
    }

    TimedProcess {
        id: clipboardPreviewProc
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isOpen || clipboardPreviewProc.requestGeneration !== root.previewRequestGeneration)
                    return;
                let previewPath = text.trim();
                if (!root.clipboardPreviewId) return;

                if (previewPath) {
                    previewHeroSource = "file://" + previewPath + "?v=" + Date.now();
                    previewImage.source = previewHeroSource;
                    previewContent.text = "";
                    setPreviewFooter([
                        { label: "Clipboard ID", value: root.clipboardPreviewId },
                        { label: "Estado", value: "Prévia de imagem" }
                    ]);
                } else {
                    previewImage.source = "";
                    previewHeroSource = "";
                    setPreviewPlainText("[Imagem] Prévia indisponível");
                    setPreviewFooter([
                        { label: "Clipboard ID", value: root.clipboardPreviewId },
                        { label: "Estado", value: "Cópia binária preservada" }
                    ]);
                }
            }
        }
    }

    TimedProcess {
        id: translateProc
        timeoutMs: 12000
        timeoutLabel: "Tradução"
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isCurrentSearchRequest(translateProc))
                    return;
                try {
                    let translated = text.trim();
                    if (translated && resultsModel.count > 0) {
                        resultsModel.set(0, {
                            "name": translated,
                            "description": "Traduzido \u2022 Enter para copiar",
                            "icon": "",
                            "type": "translate", "result": translated,
                            "appId": "", "appIdx": 0, "extra": "", "path": "", "term": "", "score": 0
                        });
                    }
                    root.finishSearchLoading();
                    root.syncPreviewAfterAsyncResults();
                } catch (e) {
                    root.finishSearchLoading();
                    root.reportLauncherError("Tradução", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] translateProc parse error:", e);
                }
            }
        }
        onTimedOut: {
            if (!root.isCurrentSearchRequest(translateProc))
                return;
            root.reportSearchTimeout("Tradução", "A tradução demorou demais e foi interrompida.");
        }
        onFailed: function(exitCode) {
            if (!root.isCurrentSearchRequest(translateProc))
                return;
            root.finishSearchLoading();
            root.reportLauncherError("Tradução", "Falhou com exit " + exitCode);
        }
    }

    TimedProcess {
        id: unicodeProc
        timeoutMs: 5000
        timeoutLabel: "Unicode"
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isCurrentSearchRequest(unicodeProc))
                    return;
                try {
                    var lines = text.trim().split("\n").filter(function(l) { return l.length > 0; });
                    resultsModel.clear();
                    if (lines.length === 0) {
                        resultsModel.append({
                            "name": "Nenhum caractere encontrado",
                            "description": "Tente outro termo de busca",
                            "icon": "", "type": "unicode",
                            "result": "",
                            "appId": "", "appIdx": 0, "extra": "", "path": "", "term": "", "score": 0
                        });
                    } else {
                        for (var i = 0; i < lines.length; i++) {
                            var parts = lines[i].split("\t");
                            if (parts.length >= 3) {
                                var uchar = parts[0];
                                var codepoint = parts[1];
                                var uname = parts[2];
                                resultsModel.append({
                                    "name": uchar + "  " + uname,
                                    "description": codepoint + " \u2022 Enter para copiar",
                                    "icon": "", "type": "unicode",
                                    "result": uchar,
                                    "appId": "", "appIdx": 0, "extra": codepoint, "path": "", "term": uname, "score": 0
                                });
                            }
                        }
                    }
                    root.finishSearchLoading();
                    root.syncPreviewAfterAsyncResults();
                } catch (e) {
                    root.finishSearchLoading();
                    root.reportLauncherError("Unicode", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] unicodeProc parse error:", e);
                }
            }
        }
        onTimedOut: {
            if (!root.isCurrentSearchRequest(unicodeProc))
                return;
            root.reportSearchTimeout("Unicode", "A busca de caracteres demorou demais.");
        }
        onFailed: function(exitCode) {
            if (!root.isCurrentSearchRequest(unicodeProc))
                return;
            root.finishSearchLoading();
            root.reportLauncherError("Unicode", "Falhou com exit " + exitCode);
        }
    }

    TimedProcess {
        id: recentProjectsSearch
        timeoutMs: 8000
        timeoutLabel: "Projetos recentes"
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isCurrentSearchRequest(recentProjectsSearch))
                    return;
                try {
                    LauncherParsing.appendResults(resultsModel, LauncherParsing.parseRecentProjectsOutput(text));
                    root.finishSearchLoading();
                    root.syncPreviewAfterAsyncResults();
                } catch (e) {
                    root.finishSearchLoading();
                    root.reportLauncherError("Projetos recentes", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] recentProjectsProc parse error:", e);
                }
            }
        }
        onTimedOut: {
            if (!root.isCurrentSearchRequest(recentProjectsSearch))
                return;
            root.reportSearchTimeout("Projetos recentes", "A busca por projetos recentes demorou demais e foi interrompida.");
        }
        onFailed: function(exitCode) {
            if (!root.isCurrentSearchRequest(recentProjectsSearch))
                return;
            root.finishSearchLoading();
            root.reportLauncherError("Projetos recentes", "Falhou com exit " + exitCode);
        }
    }



    TimedProcess {
        id: recentFilesSearch
        timeoutMs: 8000
        timeoutLabel: "Arquivos recentes"
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isCurrentSearchRequest(recentFilesSearch))
                    return;
                try {
                    LauncherParsing.appendResults(resultsModel, LauncherParsing.parseRecentFilesOutput(text, root.homeDir));
                    root.finishSearchLoading();
                    root.syncPreviewAfterAsyncResults();
                } catch (e) {
                    root.finishSearchLoading();
                    root.reportLauncherError("Arquivos recentes", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] recentFilesProc parse error:", e);
                }
            }
        }
        onTimedOut: {
            if (!root.isCurrentSearchRequest(recentFilesSearch))
                return;
            root.reportSearchTimeout("Arquivos recentes", "A busca por arquivos recentes demorou demais e foi interrompida.");
        }
        onFailed: function(exitCode) {
            if (!root.isCurrentSearchRequest(recentFilesSearch))
                return;
            root.finishSearchLoading();
            root.reportLauncherError("Arquivos recentes", "Falhou com exit " + exitCode);
        }
    }

    TimedProcess {
        id: killSearchProc
        timeoutMs: 8000
        timeoutLabel: "Busca de processos"
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (killSearchProc.requestGeneration !== root.killSearchSnapshotGeneration)
                    return;
                try {
                    root.killSearchSnapshotText = text;
                    root.killSearchSnapshotReady = true;
                    root.killSearchSnapshotLoading = false;
                    if (!root.isOpen || root.currentMode !== "kill")
                        return;
                    root.applyKillSearchResults(true);
                    root.finishSearchLoading();
                } catch (e) {
                    root.killSearchSnapshotLoading = false;
                    if (root.isOpen && root.currentMode === "kill") {
                        root.finishSearchLoading();
                        root.reportLauncherError("Processos", String(e && e.message ? e.message : e));
                    }
                    console.warn("[Launcher] killSearchProc parse error:", e);
                }
            }
        }
        onTimedOut: {
            if (killSearchProc.requestGeneration !== root.killSearchSnapshotGeneration)
                return;
            root.killSearchSnapshotLoading = false;
            if (!root.isOpen || root.currentMode !== "kill")
                return;
            if (root.killSearchSnapshotReady) {
                console.warn("[Launcher] killSearchProc timed out while refreshing snapshot");
                return;
            }
            root.reportSearchTimeout("Processos", "A busca de processos demorou demais e foi interrompida.");
        }
        onFailed: function(exitCode) {
            if (killSearchProc.requestGeneration !== root.killSearchSnapshotGeneration)
                return;
            root.killSearchSnapshotLoading = false;
            if (!root.isOpen || root.currentMode !== "kill")
                return;
            if (root.killSearchSnapshotReady) {
                console.warn("[Launcher] killSearchProc failed while refreshing snapshot:", exitCode);
                return;
            }
            root.finishSearchLoading();
            root.reportLauncherError("Processos", "Falhou com exit " + exitCode);
        }
    }

    TimedProcess {
        id: aiAssistProc
        timeoutMs: 120000
        timeoutLabel: "IA"
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isCurrentSearchRequest(aiAssistProc))
                    return;
                try {
                    let sections = LauncherParsing.parseAiOutput(text, TextSanitizer.cleanAiResponseText);
                    if (root.aiTier === "all") {
                        let allArr = [];
                        let modelKeys = ["flash", "pro", "gpt41", "gpt5mini"];
                        for (let i = 0; i < modelKeys.length; i++) {
                            let key = modelKeys[i];
                            allArr.push({
                                key: key,
                                label: root.aiModelLabel(key),
                                text: TextSanitizer.cleanAiResponseText(sections[key] || "")
                            });
                        }
                        root.aiAllTexts = allArr;
                        root.aiPrimaryText = allArr[0] ? allArr[0].text : "";
                        root.aiSecondaryText = allArr[1] ? allArr[1].text : "";
                    } else {
                        root.aiPrimaryText = TextSanitizer.cleanAiResponseText(sections["primary"] || "");
                        root.aiSecondaryText = TextSanitizer.cleanAiResponseText(sections["secondary"] || "");
                    }
                    if (trimBlankEdges(root.aiPrimaryText) === "" && trimBlankEdges(root.aiSecondaryText) === "") {
                        let fallbackMessage = trimBlankEdges(root.aiLastErrorText);
                        if (fallbackMessage === "") fallbackMessage = "A IA não retornou texto útil. Verifique o OpenCode, autenticação e os modelos configurados.";
                        root.aiPrimaryText = fallbackMessage;
                    }
                    root.aiLoading = false;
                    if (resultsModel.count > 0 && resultsModel.get(0).type === "ai_assist") {
                        let preview = TextSanitizer.cleanAiResponseText(root.aiPrimaryText).substring(0, 80).split("\n").join(" ");
                        resultsModel.set(0, {
                            "name": preview + (preview.length >= 80 ? "…" : ""),
                            "description": "IA respondeu \u2022 Enter para copiar",
                            "icon": "applications-science",
                            "type": "ai_assist",
                            "result": root.aiPrimaryText,
                            "appId": "", "appIdx": 0, "extra": root.aiPromptText, "path": "", "term": root.aiTier, "score": 0
                        });
                    }
                    root.finishSearchLoading();
                    Qt.callLater(function() {
                        if (root.currentMode === "ai" && resultsModel.count > 0) root.schedulePreviewUpdate(0);
                    });
                } catch (e) {
                    root.finishSearchLoading();
                    root.reportLauncherError("IA", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] aiAssistProc parse error:", e);
                    root.aiLoading = false;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (!root.isCurrentSearchRequest(aiAssistProc))
                    return;
                let err = TextSanitizer.cleanAiResponseText(text);
                if (trimBlankEdges(err) !== "") root.aiLastErrorText = err;
            }
        }
        onExited: function(code) {
            if (!root.isCurrentSearchRequest(aiAssistProc))
                return;
            if (code === 0 || !root.aiLoading) return;
            root.finishSearchLoading();
            root.aiLoading = false;
            let message = trimBlankEdges(root.aiLastErrorText);
            if (message === "") message = "Falha ao consultar a IA (exit " + code + ").";
            root.aiPrimaryText = message;
            root.aiSecondaryText = "";
            root.aiAllTexts = [];
            if (resultsModel.count > 0 && resultsModel.get(0).type === "ai_assist") {
                resultsModel.set(0, {
                    "name": "Falha na IA",
                    "description": "Veja o painel para detalhes",
                    "icon": "applications-science",
                    "type": "ai_assist",
                    "result": root.aiPrimaryText,
                    "appId": "", "appIdx": 0, "extra": root.aiPromptText, "path": "", "term": root.aiTier, "score": 0
                });
            }
            Qt.callLater(function() {
                if (root.currentMode === "ai" && resultsModel.count > 0) root.schedulePreviewUpdate(0);
            });
        }
    }

    TimedProcess { id: commandRunner; timeoutMs: 0 }

    TimedProcess {
        id: filePreviewProc
        timeoutMs: 8000
        timeoutLabel: "Prévia do arquivo"
        property string requestedPath: ""
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isOpen || filePreviewProc.requestGeneration !== root.previewRequestGeneration)
                    return;
                if (filePreviewProc.requestedPath === "" || previewFileDetails.path !== filePreviewProc.requestedPath) return;
                setPreviewPlainText(text.substring(0, 3000));
            }
        }
        onFailed: function(exitCode) {
            if (!root.isOpen || filePreviewProc.requestGeneration !== root.previewRequestGeneration)
                return;
            if (filePreviewProc.requestedPath === "" || previewFileDetails.path !== filePreviewProc.requestedPath)
                return;
            root.reportLauncherError("Prévia do arquivo", "Falhou com exit " + exitCode);
        }
        onTimedOut: {
            if (root.isOpen && filePreviewProc.requestGeneration === root.previewRequestGeneration)
                root.reportLauncherError("Prévia do arquivo", "Timeout (arquivo pode estar inacessível)");
        }
    }

    TimedProcess {
        id: fileMetaProc
        timeoutMs: 5000
        timeoutLabel: "Metadados do arquivo"
        property string requestedPath: ""
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isOpen || fileMetaProc.requestGeneration !== root.previewRequestGeneration)
                    return;
                if (fileMetaProc.requestedPath === "" || previewFileDetails.path !== fileMetaProc.requestedPath) return;
                try {
                    let parsed = LauncherParsing.parseFileMetaOutput(text);
                    previewFileDetails = parsed;
                    updateFileInfoRows();
                    if (parsed.kind === "directory") {
                        previewDesc.text = parsed.previewNote || "Pasta";
                        setPreviewPlainText((parsed.previewNote || "Pasta") + "\n\n" + (parsed.path || ""));
                    }
                } catch (e) {
                    root.reportLauncherError("Metadados do arquivo", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] Falha ao parsear metadados de arquivo:", e);
                }
            }
        }
        onFailed: function(exitCode) {
            if (!root.isOpen || fileMetaProc.requestGeneration !== root.previewRequestGeneration)
                return;
            if (fileMetaProc.requestedPath === "" || previewFileDetails.path !== fileMetaProc.requestedPath)
                return;
            root.reportLauncherError("Metadados do arquivo", "Falhou com exit " + exitCode);
        }
        onTimedOut: {
            if (root.isOpen && fileMetaProc.requestGeneration === root.previewRequestGeneration)
                root.reportLauncherError("Metadados do arquivo", "Timeout (arquivo pode estar inacessível)");
        }
    }

    TimedProcess {
        id: fileThumbnailProc
        timeoutMs: 10000
        timeoutLabel: "Miniatura do arquivo"
        property string requestedPath: ""
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isOpen || fileThumbnailProc.requestGeneration !== root.previewRequestGeneration)
                    return;
                if (fileThumbnailProc.requestedPath === "" || previewFileDetails.path !== fileThumbnailProc.requestedPath) return;
                let thumbPath = String(text || "").trim();
                if (thumbPath === "") return;
                previewHeroSource = "file://" + thumbPath + "?v=" + Date.now();
                previewImage.source = previewHeroSource;
            }
        }
        onTimedOut: {
            if (!root.isOpen || fileThumbnailProc.requestGeneration !== root.previewRequestGeneration)
                return;
            if (fileThumbnailProc.requestedPath === "" || previewFileDetails.path !== fileThumbnailProc.requestedPath)
                return;
            previewHeroSource = "";
            previewImage.source = "";
            root.reportLauncherError("Miniatura do arquivo", "A geração da miniatura demorou demais e foi interrompida.");
        }
        onFailed: function(exitCode) {
            if (!root.isOpen || fileThumbnailProc.requestGeneration !== root.previewRequestGeneration)
                return;
            if (fileThumbnailProc.requestedPath === "" || previewFileDetails.path !== fileThumbnailProc.requestedPath)
                return;
            root.reportLauncherError("Miniatura do arquivo", "Falhou com exit " + exitCode);
        }
    }

    TimedProcess {
        id: pdfMetaProc
        property string requestedPath: ""
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isOpen || pdfMetaProc.requestGeneration !== root.previewRequestGeneration)
                    return;
                if (pdfMetaProc.requestedPath === "" || previewFileDetails.path !== pdfMetaProc.requestedPath) return;
                setPreviewPlainText(text.trim());
            }
        }
        onFailed: function(exitCode) {
            if (!root.isOpen || pdfMetaProc.requestGeneration !== root.previewRequestGeneration)
                return;
            if (pdfMetaProc.requestedPath === "" || previewFileDetails.path !== pdfMetaProc.requestedPath)
                return;
            root.reportLauncherError("PDF", "Falhou com exit " + exitCode);
        }
    }





    TimedProcess {
        id: bluetoothStatusProc
        property bool statusEnabled: false
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isOpen || bluetoothStatusProc.requestGeneration !== root.previewRequestGeneration || previewPanelMode !== "system_bluetooth")
                    return;
                try {
                    let parsed = LauncherParsing.parseBluetoothStatusOutput(text);
                    bluetoothStatusProc.statusEnabled = parsed.enabled === true;
                    updateBluetoothInfoRows();
                } catch (e) {
                    root.reportLauncherError("Bluetooth", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] Falha ao parsear status do bluetooth:", e);
                    bluetoothStatusProc.statusEnabled = false;
                    updateBluetoothInfoRows();
                }
            }
        }
        onFailed: function(exitCode) {
            if (!root.isOpen || bluetoothStatusProc.requestGeneration !== root.previewRequestGeneration || previewPanelMode !== "system_bluetooth")
                return;
            root.reportLauncherError("Bluetooth", "Falhou com exit " + exitCode);
        }
    }

    TimedProcess {
        id: bluetoothDevicesProc
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isOpen || bluetoothDevicesProc.requestGeneration !== root.previewRequestGeneration || previewPanelMode !== "system_bluetooth")
                    return;
                try {
                    previewBluetoothDevices = LauncherParsing.parseBluetoothDevicesOutput(text);
                    updateBluetoothInfoRows();
                } catch (e) {
                    root.reportLauncherError("Bluetooth", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] Falha ao parsear dispositivos bluetooth:", e);
                    previewBluetoothDevices = [];
                }
            }
        }
        onFailed: function(exitCode) {
            if (!root.isOpen || bluetoothDevicesProc.requestGeneration !== root.previewRequestGeneration || previewPanelMode !== "system_bluetooth")
                return;
            root.reportLauncherError("Bluetooth", "Falhou com exit " + exitCode);
        }
    }

    TimedProcess {
        id: wifiStatusProc
        property bool statusEnabled: false
        property string ssid: ""
        property int signal: 0
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isOpen || wifiStatusProc.requestGeneration !== root.previewRequestGeneration || previewPanelMode !== "system_wifi")
                    return;
                try {
                    let parsed = LauncherParsing.parseWifiStatusOutput(text);
                    wifiStatusProc.statusEnabled = parsed.enabled === true;
                    wifiStatusProc.ssid = String(parsed.ssid || "");
                    wifiStatusProc.signal = parseInt(parsed.signal || 0, 10) || 0;
                    updateWifiInfoRows();
                } catch (e) {
                    root.reportLauncherError("Wi-Fi", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] Falha ao parsear status do Wi-Fi:", e);
                    wifiStatusProc.statusEnabled = false;
                    wifiStatusProc.ssid = "";
                    wifiStatusProc.signal = 0;
                    updateWifiInfoRows();
                }
            }
        }
        onFailed: function(exitCode) {
            if (!root.isOpen || wifiStatusProc.requestGeneration !== root.previewRequestGeneration || previewPanelMode !== "system_wifi")
                return;
            root.reportLauncherError("Wi-Fi", "Falhou com exit " + exitCode);
        }
    }

    TimedProcess {
        id: windowMemoryProc
        property string requestedPid: ""
        property int requestGeneration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isOpen || windowMemoryProc.requestGeneration !== root.previewRequestGeneration || previewPanelMode !== "window")
                    return;
                if (!previewWindowDetails || String(previewWindowDetails.pid || "") !== windowMemoryProc.requestedPid) return;
                try {
                    let parsed = LauncherParsing.parseWindowMemoryOutput(text);
                    previewWindowDetails = {
                        workspaceLabel: previewWindowDetails.workspaceLabel,
                        address: previewWindowDetails.address,
                        pid: previewWindowDetails.pid,
                        ramMiB: parsed.rssMiB || 0,
                        ramRatio: parsed.ratio || 0,
                        ramText: parsed.ramText || ""
                    };
                    updateWindowInfoRows();
                } catch (e) {
                    root.reportLauncherError("Memória da janela", String(e && e.message ? e.message : e));
                    console.warn("[Launcher] Falha ao parsear memória da janela:", e);
                }
            }
        }
        onFailed: function(exitCode) {
            if (!root.isOpen || windowMemoryProc.requestGeneration !== root.previewRequestGeneration || previewPanelMode !== "window")
                return;
            root.reportLauncherError("Memória da janela", "Falhou com exit " + exitCode);
        }
    }

    TimedProcess {
        id: previewActionProc
        timeoutMs: 0
        stderr: StdioCollector {
            onStreamFinished: {
                let msg = String(text || "").trim();
                if (msg !== "") commandRunner.exec(["notify-send", "-a", "Launcher", "Ação falhou", msg]);
            }
        }
        onExited: {
            if (!root.isOpen) return;
            root.refreshLivePreview();
            if (previewPanelMode === "system_bluetooth" || previewPanelMode === "system_wifi")
                root.schedulePreviewUpdate(appsList.currentIndex);
        }
    }

    Timer {
        id: killProbeTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (killPendingPid === "")
                return;
            killProbeProc.requestedPid = killPendingPid;
            killProbeProc.exec(["ps", "-o", "stat=", "-p", killPendingPid]);
        }
    }

    TimedProcess {
        id: killProbeProc
        property string requestedPid: ""
        timeoutMs: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (killProbeProc.requestedPid === "" || killProbeProc.requestedPid !== killPendingPid || previewPanelMode !== "kill")
                    return;

                let phase = killActionPhase;
                killActionPhase = "";
                let stat = String(text || "").trim();
                let alive = stat !== "" && stat.charAt(0) !== "Z";

                if (alive) {
                    if (phase === "force") {
                        killForceAvailable = false;
                        killStatusText = "SIGKILL não encerrou o processo.";
                    } else {
                        killForceAvailable = true;
                        killStatusText = "SIGTERM falhou. SIGKILL disponível.";
                    }
                } else {
                    killForceAvailable = false;
                    killStatusText = "Processo encerrado.";
                    killPendingPid = "";
                }

                refreshKillPreviewActions();
            }
        }
    }

    TimedProcess {
        id: hwControlProc
    }

    // ─── Frecency ───────────────────────────────────────────────
    TimedProcess {
        id: frecencyLoader
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var trimmed = String(text || "").trim();
                    if (trimmed.startsWith("{")) {
                        root.frecencyMap = LauncherParsing.parseFrecencyJson(trimmed);
                    } else {
                        root.frecencyMap = LauncherParsing.parseFrecencyOutput(trimmed);
                    }
                    root.frecencyLoaded = true;
                    if (root.isOpen && root.currentMode === "apps") {
                        Qt.callLater(function() {
                            if (root.isOpen && root.currentMode === "apps") {
                                root.updateSearch();
                                if (root.launcherStateRestorePending)
                                    root.applyRestoredSelection();
                            }
                        });
                    }
                } catch (e) {
                    root.reportLauncherError("Frecency", String(e && e.message ? e.message : e));
                    root.frecencyMap = {};
                    root.frecencyLoaded = false;
                    root.launcherStateRestorePending = false;
                    console.warn("[Launcher] frecency parse error:", e);
                }
            }
        }
        stderr: StdioCollector {
            onRead: console.error("[Launcher:Frecency] " + data)
        }
    }

    TimedProcess { id: frecencySaver }

    TimedProcess {
        id: desktopEntriesStampProc
        timeoutMs: 5000
        stdout: StdioCollector {
            onStreamFinished: {
                var stamp = String(text || "").trim();
                if (stamp === "")
                    stamp = "0";

                var snapshot = LauncherParsing.snapshotDesktopEntries(DesktopEntries.applications);
                var stampChanged = stamp !== root._desktopEntriesStamp;

                if (snapshot.length > 0 || root._desktopEntriesSnapshot.length === 0)
                    root._desktopEntriesSnapshot = snapshot;
                root._desktopEntriesStamp = stamp;
                root._desktopEntriesRefreshPending = false;

                if (stampChanged && root.isOpen)
                    root.updateSearch();
            }
        }
        onFailed: function(exitCode) {
            root._desktopEntriesRefreshPending = false;
            if (root._desktopEntriesSnapshot.length === 0)
                root.reportLauncherError("Desktop cache", "Falha ao ler timestamp dos aplicativos (exit " + exitCode + ")");
        }
    }

    function loadFrecency() {
        if (frecencyLoaded || frecencyLoader.running)
            return frecencyLoaded === true;

        frecencyLoaded = false;
        frecencyLoader.exec([
            "bash", "-c",
            "cat \"$1\" 2>/dev/null || printf '{}'",
            "dummy",
            RuntimePaths.cacheFile("launcher-frecency.json")
        ]);
        return true;
    }

    function recordLaunch(appId) {
        if (!appId) return;
        let f = frecencyMap[appId] || 0;
        frecencyMap[appId] = f + 1;
        frecencySaver.exec(["bash", RuntimePaths.scriptFile("launcher_record_launch.sh"), appId]);
    }

    function normalizeFavoriteAppIds(raw) {
        var map = ({});
        var source = raw;
        if (source === undefined || source === null)
            return map;

        if (typeof source === "string") {
            var text = String(source || "").trim();
            if (text === "")
                return map;
            try {
                source = JSON.parse(text);
            } catch (e) {
                return map;
            }
        }

        if (source && typeof source.length === "number" && typeof source !== "string") {
            for (var i = 0; i < source.length; i++) {
                var id = String(source[i] || "").trim();
                if (id !== "")
                    map[id] = true;
            }
            return map;
        }

        if (source && typeof source === "object") {
            for (var key in source) {
                if (source[key] === true || source[key] === 1 || source[key] === "1") {
                    var normalizedKey = String(key || "").trim();
                    if (normalizedKey !== "")
                        map[normalizedKey] = true;
                }
            }
        }

        return map;
    }

    function favoriteAppIdsArray() {
        var ids = [];
        for (var key in favoriteAppIds) {
            if (favoriteAppIds[key] === true)
                ids.push(key);
        }
        ids.sort(function(a, b) { return a.localeCompare(b); });
        return ids;
    }

    function loadFavoriteAppIds() {
        if (favoriteAppIdsLoaded)
            return true;

        if (!settingsStore || !settingsStore.ready || !settingsStore.get) {
            favoriteAppIds = ({});
            favoriteAppIdsLoaded = false;
            return false;
        }

        var raw = settingsStore.get("launcherFavoritesJson", []);
        if (typeof raw === "string") {
            try {
                favoriteAppIds = normalizeFavoriteAppIds(JSON.parse(raw));
            } catch (e) {
                favoriteAppIds = ({});
            }
        } else if (Array.isArray(raw)) {
            favoriteAppIds = normalizeFavoriteAppIds(raw);
        } else {
            favoriteAppIds = ({});
        }

        favoriteAppIdsLoaded = true;
        return true;
    }

    function persistFavoriteAppIds() {
        if (!settingsStore || !settingsStore.ready || !settingsStore.set) {
            favoriteAppIdsPendingWrite = true;
            return;
        }
        favoriteAppIdsPendingWrite = false;
        settingsStore.set("launcherFavoritesJson", favoriteAppIdsArray());
    }

    function isFavoriteAppId(appId) {
        return favoriteAppIds[String(appId || "").trim()] === true;
    }

    function restoreSelectionByKey(itemKey) {
        var targetKey = String(itemKey || "");
        if (targetKey === "" || !resultsModel || resultsModel.count <= 0)
            return false;

        for (var i = 0; i < resultsModel.count; i++) {
            if (launcherResultKey(resultsModel.get(i)) === targetKey) {
                selectedIndex = i;
                schedulePreviewUpdate(i);
                return true;
            }
        }

        return false;
    }

    function refreshAppSearchAfterFavoriteChange(previousKey) {
        if (currentMode !== "apps")
            return;

        cancelSearchProcesses();
        resultsModel.clear();
        resetPreviewState();
        if ((normalizeCache.__count || 0) > normalizeCacheMaxSize)
            normalizeCache = ({});
        finishSearchLoading();
        searchApps(searchField.text);

        if (resultsModel.count <= 0) {
            previewVisible = false;
            return;
        }

        if (!restoreSelectionByKey(previousKey)) {
            var fallbackIndex = Math.max(0, Math.min(Number(selectedIndex || 0), resultsModel.count - 1));
            selectedIndex = fallbackIndex;
            schedulePreviewUpdate(fallbackIndex);
        }
    }

    function toggleFavoriteApp(appId) {
        var id = String(appId || "").trim();
        if (id === "")
            return false;

        var previousKey = "";
        if (resultsModel && appsList && appsList.currentIndex >= 0 && appsList.currentIndex < resultsModel.count)
            previousKey = launcherResultKey(resultsModel.get(appsList.currentIndex));

        if (favoriteAppIds[id] === true)
            delete favoriteAppIds[id];
        else
            favoriteAppIds[id] = true;

        persistFavoriteAppIds();

        if (isOpen && currentMode === "apps")
            refreshAppSearchAfterFavoriteChange(previousKey);

        return false;
    }

    // ─── Retry Timer ────────────────────────────────────────────
    // Helper to safely get the applications array
    function getAppsArray() {
        if (root._desktopEntriesSnapshot.length > 0)
            return root._desktopEntriesSnapshot;
        if (typeof DesktopEntries !== "undefined" && DesktopEntries && DesktopEntries.applications) {
            var snap = LauncherParsing.snapshotDesktopEntries(DesktopEntries.applications);
            if (snap && snap.length > 0) {
                root._desktopEntriesSnapshot = snap;
                return root._desktopEntriesSnapshot;
            }
        }
        return [];
    }

    function ensureDesktopEntriesRetry() {
        if (currentMode !== "apps") {
            retryDesktopEntries.stop();
            return;
        }

        if (root.getAppsArray().length > 0) {
            retryDesktopEntries.stop();
            return;
        }

        if (!retryDesktopEntries.running) {
            retryDesktopEntries.attempts = 0;
            retryDesktopEntries.start();
        }
    }

    function resolveAppFromItem(item) {
        if (!item) return null;
        let targetId = typeof item === "string" ? item : (item.appId || item.id || "");

        let heuristicCandidates = [targetId];
        if (typeof item === "object") {
            if (item.name) heuristicCandidates.push(item.name);
            if (item.title) heuristicCandidates.push(item.title);
            if (item.icon) heuristicCandidates.push(item.icon);
        }

        if (typeof DesktopEntries !== "undefined" && DesktopEntries && typeof DesktopEntries.heuristicLookup === "function") {
            for (let h = 0; h < heuristicCandidates.length; h++) {
                let candidate = String(heuristicCandidates[h] || "").trim();
                if (candidate === "")
                    continue;
                let heuristicMatch = DesktopEntries.heuristicLookup(candidate);
                if (heuristicMatch)
                    return heuristicMatch;
                let withoutDesktopSuffix = candidate.replace(/\.desktop$/i, "");
                if (withoutDesktopSuffix !== candidate) {
                    heuristicMatch = DesktopEntries.heuristicLookup(withoutDesktopSuffix);
                    if (heuristicMatch)
                        return heuristicMatch;
                }
            }
        }

        let apps = getAppsArray();
        let normalizedId = normalizeAppIdKey(targetId);
        if (normalizedId === "") return null;

        // Pass 1: Exact matches (priority)
        for (let i = 0; i < apps.length; i++) {
            let app = apps[i];
            if (!app) continue;
            let appId = normalizeAppIdKey(app.id || app.desktopId || "");
            let appName = normalizeAppIdKey(app.name || "");
            let appIcon = normalizeAppIdKey(app.icon || "");

            if (appId === normalizedId || appName === normalizedId || appIcon === normalizedId) return app;
        }

        // Pass 2: Partial matches for reverse domain names (e.g. org.gnome.Nautilus vs nautilus)
        for (let j = 0; j < apps.length; j++) {
            let app2 = apps[j];
            if (!app2) continue;
            let appId2 = normalizeAppIdKey(app2.id || app2.desktopId || "");
            let appName2 = normalizeAppIdKey(app2.name || "");

            if (appId2.indexOf(normalizedId) >= 0 || normalizedId.indexOf(appId2) >= 0 ||
                appName2.indexOf(normalizedId) >= 0 || normalizedId.indexOf(appName2) >= 0) {
                return app2;
            }
        }
        return null;
    }

    Timer {
        id: retryDesktopEntries
        interval: 500; repeat: true
        property int attempts: 0
        onTriggered: {
            if (root.getAppsArray().length > 0 || attempts >= 10) {
                retryDesktopEntries.stop();
                if (root.isOpen) updateSearch();
            }
            attempts++;
        }
    }

    // Two-phase focus acquisition:
    // 1. focusDelay fires once after 80ms, giving the compositor time to
    //    process the WlrKeyboardFocus.Exclusive change and grant keyboard
    //    interactivity to the layer surface.
    // 2. focusTimer then retries forceActiveFocus every 80ms up to 8 times
    //    in case the first attempt didn't stick (e.g. Hyprland was busy).
    Timer {
        id: focusDelay
        interval: 80
        repeat: false
        onTriggered: {
            searchField.forceActiveFocus();
            if (!searchField.activeFocus) {
                focusTimer._attempts = 0;
                focusTimer.start();
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 80
        repeat: true
        property int _attempts: 0
        onTriggered: {
            searchField.forceActiveFocus();
            _attempts++;
            if (searchField.activeFocus || _attempts >= 8)
                focusTimer.stop();
        }
    }

    Shortcut {
        sequence: "Alt"
        enabled: root.isOpen
        onActivated: root.togglePreviewPanel()
    }

    // Debounce search: fast for apps (50ms), slower for external commands (200ms)
    Timer {
        id: searchDebounce
        interval: 200
        onTriggered: root.updateSearch()
    }
    Timer {
        id: searchDebounceApp
        interval: 50
        onTriggered: root.updateSearch()
    }

    Timer {
        id: previewUpdateDebounce
        // Wait for the selection to settle before loading the preview image.
        interval: 150
        repeat: false
        onTriggered: {
            if (pendingPreviewIndex < 0)
                return;
            root.updatePreview(pendingPreviewIndex);
        }
    }

    Timer {
        id: persistLauncherStateDebounce
        interval: 350
        repeat: false
        onTriggered: root.flushLauncherSessionState()
    }

    Timer {
        id: livePreviewTimer
        interval: 5000
        repeat: true
        running: root.isOpen && (previewPanelMode === "system_bluetooth" || previewPanelMode === "system_wifi" || previewPanelMode === "window")
        triggeredOnStart: true
        onTriggered: root.refreshLivePreview()
    }

    Timer {
        id: livePreviewRefreshDebounce
        interval: FeatureFlags.lowPowerUiMode ? 120 : 60
        repeat: false
        onTriggered: {
            if (!root._livePreviewRefreshPending)
                return;
            root._livePreviewRefreshPending = false;
            root.refreshLivePreview();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.isOpen)
                return;

            var name = event && event.name ? String(event.name) : "";
            if (name === "")
                return;

            var isWindowEvent = name.indexOf("window") >= 0 && name.indexOf("title") < 0;
            var isWorkspaceEvent = name.indexOf("workspace") >= 0 || name === "activespecial" || name === "focusedmon";
            if (!isWindowEvent && !isWorkspaceEvent)
                return;

            if (previewPanelMode === "app" || previewPanelMode === "window") {
                if (appsList && appsList.currentIndex >= 0)
                    root.schedulePreviewUpdate(appsList.currentIndex);
                return;
            }

            if (previewPanelMode === "system_bluetooth" || previewPanelMode === "system_wifi") {
                root.queueLivePreviewRefresh();
                return;
            }
        }
    }



    onIsOpenChanged: {
        if (isOpen) {
            // Clear stale data from previous session, then rebuild.
            // We intentionally do NOT detach/clear models on close to avoid
            // the QQuickItemPrivate::addToDirtyList crash caused by destroying
            // delegates while dirty events are still queued in the event loop.
            resultsModel.clear();
            contextModel.clear();
            _toplevelRefs = [];
            contextMenuOpen = false;
            resetPreviewState();
            loadLauncherSessionState();
            focusDelay.restart();
            Qt.callLater(function() {
                if (!root.isOpen)
                    return;
                loadFavoriteAppIds();
                refreshDesktopEntriesCache();
                loadFrecency();
                updateSearch();
                if (resultsModel.count > 0)
                    applyRestoredSelection();
            });
        } else {
            // Do NOT touch models or delegates here.
            // AnimatedWindow will hide the window (opacity → 0, then visible = false).
            // Stale delegates remain in memory but are invisible — no crash.
            previewRequestGeneration += 1;
            retryDesktopEntries.stop();
            searchDebounce.stop();
            searchDebounceApp.stop();
            previewUpdateDebounce.stop();
            livePreviewTimer.stop();
            persistLauncherSessionState();
            cancelSearchProcesses();
            launcherStateRestorePending = false;
            previewVisible = false;
            minimalExpanded = false;  // Reset minimal mode expansion
            // Release image memory: clear sources so textures are freed
            previewImage.source = "";
            previewHeroSource = "";
            finishSearchLoading();
            resetKillState();
            resetKillSearchSnapshot();
            root.flushLauncherSessionState();
            persistLauncherStateDebounce.stop();
            // Deactivate dashboard services to stop polling
            clearBluetoothPairPrompt();
            bluetoothPairPromptVisible = false;
            bluetoothPairPromptMac = "";
            bluetoothPairPromptLabel = "";

        }
    }

    // ─── Rich Preview Logic ─────────────────────────────────────
    function updatePreview(index) {
        resetPreviewState();
        clipboardPreviewId = "";



        if (index < 0 || index >= resultsModel.count) {
            previewVisible = false;
            return;
        }

        let item = resultsModel.get(index);
        if (!item || !item.type) {
            previewVisible = false;
            return;
        }

        if (root.previewVisible) {
            recordSessionPreview(item.type);
        }

        previewTitle.text = item.name || "";
        previewDesc.text = item.description || "";

        if ((item.type === "file" || item.type === "folder" || item.type === "recentFile") && (item.path || item.result)) {
            let filePath = item.path || item.result || "";
            let ext = (item.extra || "").toLowerCase();
            let isFolder = item.type === "folder";
            previewPanelMode = isFolder ? "folder" : "file";
            previewFileDetails = {
                path: filePath,
                kind: isFolder ? "directory" : "file",
                sizeHuman: "",
                modified: "",
                permissions: "",
                mime: "",
                parent: "",
                childCount: 0,
                previewNote: ""
            };
            let fileTags = [isFolder ? "Pasta" : "Arquivo"];
            if (!isFolder && ext !== "") fileTags.push(ext.toUpperCase());
            previewTagsFlow.tagsList = fileTags;

            fileMetaProc.requestGeneration = previewRequestGeneration;
            fileMetaProc.requestedPath = filePath;
            fileMetaProc.exec(["bash", launcherFileTool, "metadata", filePath]);
            fileThumbnailProc.requestGeneration = previewRequestGeneration;
            fileThumbnailProc.requestedPath = filePath;
            fileThumbnailProc.exec(["bash", launcherFileTool, "thumbnail", filePath]);

            if (isFolder) {
                setPreviewPlainText("Resumo da pasta\n\n" + filePath);
            } else if (["png", "jpg", "jpeg", "gif", "bmp", "svg", "webp", "avif", "mp4", "mkv", "avi", "webm", "mov", "m4v"].includes(ext)) {
                previewContent.text = "";
            } else if (ext === "json") {
                filePreviewProc.requestGeneration = previewRequestGeneration;
                filePreviewProc.requestedPath = filePath;
                filePreviewProc.exec(["jq", ".", filePath]);
            } else if (ext === "pdf") {
                pdfMetaProc.requestGeneration = previewRequestGeneration;
                pdfMetaProc.requestedPath = filePath;
                pdfMetaProc.exec(["pdfinfo", filePath]);
            } else {
                filePreviewProc.requestGeneration = previewRequestGeneration;
                filePreviewProc.requestedPath = filePath;
                filePreviewProc.exec(["head", "-n", "60", filePath]);
            }
            setPreviewFooter([
                { label: "Caminho", value: filePath },
                { label: "Tipo", value: isFolder ? "Pasta" : (ext !== "" ? ext.toUpperCase() : "Arquivo") }
            ]);

            actionFlow.actionsList = LauncherQuickActions.buildFileActions({
                isFolder: isFolder,
                filePath: filePath,
                ext: ext,
                openPathInManager: openPathInManager,
                openPathInTerminal: openPathInTerminal,
                revealPathInManager: revealPathInManager,
                openPathInEditor: openPathInEditor,
                parentDirectoryForPath: parentDirectoryForPath,
                commandRunner: commandRunner,
                previewActionProc: previewActionProc,
                launcherFileTool: launcherFileTool,
                runtimePaths: RuntimePaths
            });
        } else if (item.type === "app") {
            previewPanelMode = "app";
            let app = resolveAppFromItem(item);
            if (app) {
                let execString = cleanExecString(app.execString || "");
                let infoParts = [];
                let appTags = [];
                if (item.favorite === true)
                    appTags.push("Favorito");
                if (app.categories && typeof app.categories.length === "number") {
                    for (let i = 0; i < app.categories.length; i++)
                        appTags.push(app.categories[i]);
                }
                previewTagsFlow.tagsList = appTags;
                previewRunningWindows = runningWindowsForApp(app);
                let appInfoRows = [];
                previewImage.source = "";
                if (previewRunningWindows.length > 0) {
                    appInfoRows.push({ label: "Executando", value: previewRunningWindows.length + " janela(s)" });
                    appInfoRows.push({ label: "Workspace", value: previewRunningWindows[0].workspaceLabel });
                }
                if (item.favorite === true)
                    appInfoRows.push({ label: "Favorito", value: "Sim" });
                if (app.id) appInfoRows.push({ label: "App ID", value: app.id });
                if (execString !== "") appInfoRows.push({ label: "Exec", value: execString });
                if (app.terminal) appInfoRows.push({ label: "Modo", value: "Aplicativo de terminal" });
                previewInfoRows = appInfoRows;
                if (app.comment) infoParts.push("<i>" + htmlEscape(app.comment) + "</i>");
                if (execString !== "") infoParts.push("<b>Comando de Execução</b><br><font color='" + root.launcherTextMuted + "'>" + htmlEscape(execString) + "</font>");
                if (previewRunningWindows.length > 0) infoParts.push("<b>Janela Atual</b><br>" + htmlEscape(previewRunningWindows[0].workspaceLabel));
                previewContent.text = infoParts.join("<br><br>");
                setPreviewFooter([
                    { label: "App ID", value: app.id || "—" },
                    { label: "Exec", value: execString || "—" },
                    { label: "Janela", value: previewRunningWindows.length > 0 ? previewRunningWindows[0].workspaceLabel : "Nenhuma" }
                ]);
                let previewAppIcon = item.icon || inferAppIcon(app);
                if (previewAppIcon) previewImage.loadIcon(previewAppIcon);

                actionFlow.actionsList = LauncherQuickActions.buildAppActions({
                    app: app,
                    execString: execString,
                    previewRunningWindows: previewRunningWindows,
                    index: index,
                    launchItem: launchItem,
                    runLauncherCommand: runLauncherCommand,
                    commandRunner: commandRunner,
                    runtimePaths: RuntimePaths,
                    dockService: DockService,
                    isFavorite: item.favorite === true,
                    toggleFavorite: function() { return root.toggleFavoriteApp(app.id || ""); },
                    closeLauncher: function() { root.isOpen = false; },
                    hyprGoToWindow: hyprGoToWindow,
                    hyprMoveWindowToWorkspace: hyprMoveWindowToWorkspace,
                    activeWorkspaceId: activeWorkspaceId
                });
            }
        } else if (item.type === "window") {
            previewPanelMode = "window";
            let tlIdx = parseInt(item.extra);
            let tl = (tlIdx >= 0 && tlIdx < _toplevelRefs.length) ? _toplevelRefs[tlIdx] : null;
            let windowData = tl ? windowDataForToplevel(tl) : {
                title: item.name || "",
                appId: item.appId || "",
                workspaceId: item.result || "?",
                workspaceLabel: "Workspace " + (item.result || "?"),
                address: item.path || "",
                pid: parseInt(item.term || "0") || 0,
                ref: null
            };
            previewDesc.text = (windowData.appId || "Janela") + " • " + windowData.workspaceLabel;
            previewContent.text = "<b>Workspace</b><br>" + htmlEscape(windowData.workspaceLabel);
            previewImage.loadIcon(item.icon || windowData.appId || "preferences-system-windows");
            previewWindowDetails = {
                workspaceLabel: windowData.workspaceLabel,
                address: windowData.address,
                pid: windowData.pid,
                ramMiB: 0,
                ramRatio: 0,
                ramText: ""
            };
            updateWindowInfoRows();
            refreshWindowMemoryPreview();
            actionFlow.actionsList = LauncherQuickActions.buildWindowActions({
                windowData: windowData,
                hyprGoToWindow: hyprGoToWindow,
                hyprMoveWindowToWorkspace: hyprMoveWindowToWorkspace,
                hyprCloseWindow: hyprCloseWindow,
                activeWorkspaceId: activeWorkspaceId,
                closeLauncher: function() { root.isOpen = false; }
            });
        } else if (item.type === "system_audio") {
            previewPanelMode = "system_audio";
            root._cachedAudioSinks = launcherAudioSinks();
            previewTagsFlow.tagsList = ["PipeWire", "Saídas", "Mixer"];
            previewDesc.text = launcherDefaultSink()
                ? ((launcherDefaultSink().description || launcherDefaultSink().name || "Saída padrão") + " • " + launcherSinkPercent() + "%")
                : "Sem saída padrão ativa";
            previewContent.text = "<b>Controle rápido de áudio</b><br>Use o slider para ajustar o volume, troque a saída padrão ou silencie instantaneamente.";
            actionFlow.actionsList = LauncherQuickActions.buildAudioActions({
                launcherSinkMuted: launcherSinkMuted,
                launcherToggleMute: launcherToggleMute,
                schedulePreviewUpdate: schedulePreviewUpdate,
                currentIndex: appsList.currentIndex
            });
        } else if (item.type === "system_bluetooth") {
            previewPanelMode = "system_bluetooth";
            previewTagsFlow.tagsList = ["Dispositivos", "Bateria", "Conexão"];
            previewContent.text = "<b>Bluetooth</b><br>Veja bateria, estado e conecte/desconecte dispositivos sem sair do launcher.";
            actionFlow.actionsList = LauncherQuickActions.buildBluetoothActions({
                enabled: bluetoothStatusProc.statusEnabled,
                previewActionProc: previewActionProc,
                launcherSystemTool: launcherSystemTool
            });
            refreshBluetoothPreview();
        } else if (item.type === "system_wifi") {
            previewPanelMode = "system_wifi";
            previewTagsFlow.tagsList = ["Rede", "SSID", "Toggle"];
            previewContent.text = "<b>Wi-Fi</b><br>Status da rede atual e atalhos rápidos para ligar ou desligar o rádio.";
            actionFlow.actionsList = LauncherQuickActions.buildWifiActions({
                enabled: wifiStatusProc.statusEnabled,
                previewActionProc: previewActionProc,
                launcherSystemTool: launcherSystemTool
            });
            refreshWifiPreview();
        } else if (item.type === "system_power") {
            previewPanelMode = "system_power";
            previewTagsFlow.tagsList = ["Sessão", "Energia", activeWorkspaceLabel()];
            previewContent.text = "<b>Energia & Sessão</b><br>Bloqueie, suspenda, finalize a sessão ou desligue o sistema.";
            actionFlow.actionsList = LauncherQuickActions.buildPowerActions({
                previewActionProc: previewActionProc
            });
        } else if (item.type === "system_brightness") {
            previewPanelMode = "system_brightness";
            previewTagsFlow.tagsList = ["Tela", "Slider", "Ajuste"];
            previewContent.text = "<b>Brilho</b><br>Controle rápido para a luminosidade da tela atual.";
        } else if (item.type === "clipboard") {
            previewPanelMode = "clipboard";
            let isClipboardImage = (item.extra || "").includes("[[ binary data");
            previewImage.source = resolvedModeIconSource("clipboard");
            if (isClipboardImage) {
                previewContent.text = "Gerando prévia da imagem...";
                clipboardPreviewId = item.result || "";
                clipboardPreviewProc.requestGeneration = previewRequestGeneration;
                clipboardPreviewProc.exec(["bash", RuntimePaths.scriptFile("launcher_cliphist_preview.sh"), clipboardPreviewId]);
            } else {
                setPreviewPlainText(item.extra || "");
            }
            setPreviewFooter([
                { label: "Clipboard ID", value: item.result || "—" },
                { label: "Estado", value: isClipboardImage ? "Prévia de imagem" : "Texto copiado" }
            ]);
            actionFlow.actionsList = LauncherQuickActions.buildClipboardActions({
                commandRunner: commandRunner,
                runtimePaths: RuntimePaths,
                item: item
            });
        } else if (item.type === "project") {
            previewPanelMode = "project";
            previewImage.loadIcon(item.icon || "folder-git");
            setPreviewPlainText("Projeto\n\n" + (item.path || ""));
            setPreviewFooter([
                { label: "Caminho", value: item.path || "—" },
                { label: "Tipo", value: "Projeto" }
            ]);
            actionFlow.actionsList = LauncherQuickActions.buildProjectActions({
                openPathInTerminal: openPathInTerminal,
                commandRunner: commandRunner,
                runtimePaths: RuntimePaths,
                item: item,
                homeDir: root.homeDir
            });
        } else if (item.type === "snippet") {
            previewPanelMode = "snippet";
            previewImage.loadIcon(item.icon || "text-x-script");
            setPreviewPlainText(item.result || "");
            actionFlow.actionsList = LauncherQuickActions.buildSnippetActions({
                commandRunner: commandRunner,
                runtimePaths: RuntimePaths,
                item: item,
                isDangerousCommand: isDangerousCommand,
                confirmDangerousCommand: confirmDangerousCommand,
                runLauncherCommand: runLauncherCommand
            });
        } else if (item.type === "kill") {
            previewPanelMode = "kill";
            previewImage.loadIcon(item.icon || "process-stop");
            killPendingPid = String(item.pid || item.result || "");
            killStatusText = "Pronto para encerrar";
            killForceAvailable = false;
            killProbeTimer.stop();
            refreshKillPreviewActions();
        } else if (item.type === "ai_assist") {
            previewPanelMode = "ai";
            previewImage.source = resolvedModeIconSource("ai");
            previewTitle.text = item.name || "IA";
            previewDesc.text = item.description || "IA Assistente";
            previewTagsFlow.tagsList = ["IA", aiTier.toUpperCase()];
            actionFlow.actionsList = LauncherQuickActions.buildAiAssistActions({
                commandRunner: commandRunner,
                runtimePaths: RuntimePaths,
                aiPrimaryText: aiPrimaryText,
                shellRoot: shellRoot
            });
        } else {
            previewVisible = false;
        }
    }

    // ─── Launch Action ──────────────────────────────────────────
    function launchItem(index) {
        if (index < 0 || index >= resultsModel.count) return;
        let item = resultsModel.get(index);
        if (!item) return;

        console.log("[Launcher] Launching item: " + item.name + " (type: " + item.type + ")");

        // Close first to avoid accessing items after window destruction
        let itemType = item.type;
        let itemAppIdx = item.appIdx;
        let itemAppId = item.appId;
        let itemTerm = item.term;
        let itemPath = item.path;
        let itemResult = item.result;
        let itemExtra = item.extra;
        let itemName = item.name;
        let itemDangerous = item.dangerous === true || isDangerousCommand(itemResult || "");

        if (itemType === "app") {
            let app = resolveAppFromItem(item);
            let cleanExec = "";
            let isTerminal = false;

            if (app) {
                recordLaunch(itemAppId || app.id);
                console.log("[Launcher] Executing app: " + (app.name || app.id));
                isTerminal = app.runInTerminal === true || app.terminal === true;
                if (!isTerminal && typeof app.execute === "function") {
                    try {
                        app.execute();
                        recordSessionLaunch(itemType);
                        root.isOpen = false;
                        return;
                    } catch (e) {
                        console.log("[Launcher] app.execute() failed, fallback to script:", e);
                    }
                }
                cleanExec = cleanExecString(app.execString || "");
            }
            if (cleanExec === "" && itemResult) {
                cleanExec = cleanExecString(itemResult);
            }
            if (cleanExec === "" && itemName) {
                cleanExec = cleanExecString(itemName);
            }

            if (cleanExec !== "") {
                runLauncherCommand(isTerminal ? "terminal" : "direct", cleanExec, false);
            } else if (app && typeof app.execute === "function") {
                app.execute();
            } else if (itemName) {
                runLauncherCommand("direct", itemName, false);
            }
        } else if (itemType === "web") {
            Qt.openUrlExternally(itemTerm);
        } else if (itemType === "file" || itemType === "recentFile" || itemType === "folder") {
            openPathInManager(itemPath);
        } else if (itemType === "calc" || itemType === "translate") {
            commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), itemResult || ""]);
        } else if (itemType === "cmd") {
            if (itemDangerous && !confirmDangerousCommand(itemResult)) return;
            runLauncherCommand("direct", itemResult, itemDangerous);
        } else if (itemType === "cmd_terminal") {
            if (itemDangerous && !confirmDangerousCommand(itemResult)) return;
            runLauncherCommand("terminal", itemResult, itemDangerous);
        } else if (itemType === "emoji") {
            commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), itemResult || ""]);
        } else if (itemType === "unicode") {
            if (itemResult && itemResult !== "") {
                commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), itemResult]);
            }
        } else if (itemType === "clipboard") {
            commandRunner.exec(["bash", RuntimePaths.scriptFile("launcher_cliphist_copy.sh"), itemResult || ""]);
        } else if (itemType === "project") {
            openPathInTerminal(itemPath || root.homeDir);

        } else if (itemType === "snippet") {
            commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), itemResult || ""]);
        } else if (itemType === "window") {
            let tlIdx = parseInt(itemExtra);
            let tl = (tlIdx >= 0 && tlIdx < _toplevelRefs.length) ? _toplevelRefs[tlIdx] : null;
            root.isOpen = false;
            let wsId = itemResult; // stored in resultsModel.append
            hyprGoToWindow(itemPath, wsId, tl);
            recordSessionLaunch("window");
            return;
        } else if (itemType === "hw_volume") {
            if (itemResult === "toggle")
                hwControlProc.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
            else
                hwControlProc.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (parseInt(itemResult) / 100).toFixed(2)]);
        } else if (itemType === "hw_brightness") {
            hwControlProc.exec(["brightnessctl", "s", itemResult + "%"]);
        } else if (itemType.indexOf("system_") === 0) {
            recordSessionLaunch(itemType);
            appsList.currentIndex = index;
            schedulePreviewUpdate(index);
            return;
        } else if (itemType === "kill") {
            let killPid = String(itemResult || item.pid || "");
            if (killPid === "") return;
            requestKillTermination(killPid, item.command || itemName || "");
            return;
        }
        recordSessionLaunch(itemType);
        root.isOpen = false;
    }

    // ─── Context Actions ────────────────────────────────────────
    ListModel { id: contextModel }

    function openContextMenu(index) {
        if (currentMode === "ai") {
            contextMenuOpen = false;
            return;
        }
        contextModel.clear();
        if (index < 0 || index >= resultsModel.count) return;
        let item = resultsModel.get(index);

        if (item.type === "app") {
            contextModel.append({ "action": "launch",    "label": "Abrir",               "icon": "\u{f04b}" });
            let app = resolveAppFromItem(item);
            let execString = cleanExecString(app && app.execString ? app.execString : "");
            if (execString !== "") {
                contextModel.append({ "action": "run_root", "label": "Rodar como Root", "icon": "\u{f084}" });
                contextModel.append({ "action": "run_terminal", "label": "Rodar no Terminal", "icon": "\u{f120}" });
                contextModel.append({ "action": "copy_exec", "label": "Copiar Exec", "icon": "\u{f0c5}" });
            }
            if (app && app.actions && app.actions.values) {
                let dActions = app.actions.values;
                for (let i = 0; i < dActions.length; i++) {
                    let act = dActions[i];
                    contextModel.append({
                        "action": "desktop_action",
                        "label": act.name,
                        "icon": "\u{f144}",
                        "actionIdx": i
                    });
                }
            }

            contextModel.append({ "action": "nix_search","label": "Ver no NixOS Search",  "icon": "\u{f313}" });
            contextModel.append({ "action": "copy_name", "label": "Copiar Nome",          "icon": "\u{f0c5}" });
            if (item.appId)
                contextModel.append({ "action": "copy_id","label": "Copiar ID",           "icon": "\u{f0c5}" });
            contextModel.append({
                "action": "toggle_favorite",
                "label": item.favorite === true ? "Remover dos Favoritos" : "Adicionar aos Favoritos",
                "icon": "\u{f005}"
            });
        } else if (item.type === "file" || item.type === "folder" || item.type === "recentFile") {
            contextModel.append({ "action": "open",      "label": item.type === "folder" ? "Abrir Pasta" : "Abrir", "icon": item.type === "folder" ? "\u{f07c}" : "\u{f15b}" });
            contextModel.append({ "action": "open_dir",  "label": item.type === "folder" ? "Abrir Pasta Pai" : "Abrir na Pasta", "icon": "\u{f07b}" });
            contextModel.append({ "action": "copy_path", "label": "Copiar Caminho",      "icon": "\u{f0c5}" });
            contextModel.append({ "action": "terminal",  "label": "Abrir no Terminal",   "icon": "\u{f120}" });
            contextModel.append({ "action": "delete_file", "label": "Excluir",           "icon": "\u{f1f8}" });
        } else if (item.type === "window") {
            contextModel.append({ "action": "focus",     "label": "Focar Janela",        "icon": "\u{f2d0}" });
            contextModel.append({ "action": "move_current_ws", "label": "Trazer p/ atual", "icon": "\u{f0e8}" });
            contextModel.append({ "action": "close_win", "label": "Fechar Janela",       "icon": "\u{f00d}" });
        } else if (item.type === "project") {
            contextModel.append({ "action": "open_project", "label": "Abrir no Terminal", "icon": "\u{f120}" });
            contextModel.append({ "action": "copy_path", "label": "Copiar Caminho", "icon": "\u{f0c5}" });

        } else if (item.type === "snippet") {
            contextModel.append({ "action": "copy_snippet", "label": "Copiar snippet", "icon": "\u{f0c5}" });
            contextModel.append({ "action": "run_snippet_terminal", "label": "Executar no terminal", "icon": "\u{f120}" });
        } else if (item.type === "kill") {
            contextModel.append({ "action": "kill", "label": "Encerrar (SIGTERM)", "icon": "\u{f00d}" });
            if (killForceAvailable)
                contextModel.append({ "action": "kill_force", "label": "Forçar (SIGKILL)", "icon": "\u{f071}" });
            contextModel.append({ "action": "copy_pid", "label": "Copiar PID", "icon": "\u{f0c5}" });
            contextModel.append({ "action": "copy_command", "label": "Copiar comando", "icon": "\u{f0c5}" });
        } else if (item.type === "emoji" || item.type === "calc") {
            contextModel.append({ "action": "copy",      "label": "Copiar",              "icon": "\u{f0c5}" });
        } else if (item.type === "unicode") {
            contextModel.append({ "action": "copy",      "label": "Copiar Caractere",    "icon": "\u{f0c5}" });
            if (item.extra)
                contextModel.append({ "action": "copy_extra", "label": "Copiar Codepoint",   "icon": "\u{f0c5}" });
        }

        if (contextModel.count > 0) {
            contextMenuOpen = true;
            contextList.currentIndex = 0;
            Qt.callLater(function() {
                if (contextMenuOpen && contextList)
                    contextList.forceActiveFocus();
            });
        }
    }

    function executeContextAction(actionIndex, itemIndex) {
        if (actionIndex < 0 || actionIndex >= contextModel.count) return;
        if (itemIndex < 0 || itemIndex >= resultsModel.count) return;
        let action = contextModel.get(actionIndex).action;
        let item = resultsModel.get(itemIndex);
        if (!item) return;

        // Copy values before closing (avoids accessing destroyed model items)
        let itemName = item.name || "";
        let itemAppId = item.appId || "";
        let itemPath = item.path || "";
        let itemExtra = item.extra || "";
        let itemResult = item.result || "";
        let itemType = item.type || "";

        contextMenuOpen = false;
        recordSessionContextAction(action);

        switch (action) {
            case "launch": launchItem(itemIndex); break;
            case "open":   launchItem(itemIndex); break;
            case "focus":  launchItem(itemIndex); break;
            case "copy":   launchItem(itemIndex); break;
            case "run_root": {
                let app = resolveAppFromItem(item);
                let execString = cleanExecString(app && app.execString ? app.execString : "");
                if (execString !== "") runLauncherCommand("root", execString, false);
                root.isOpen = false;
                break;
            }
            case "run_terminal": {
                let app = resolveAppFromItem(item);
                let execString = cleanExecString(app && app.execString ? app.execString : "");
                if (execString !== "") runLauncherCommand("terminal", execString, false);
                root.isOpen = false;
                break;
            }
            case "copy_exec": {
                let app = resolveAppFromItem(item);
                let execString = cleanExecString(app && app.execString ? app.execString : "");
                if (execString !== "") commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), execString]);
                root.isOpen = false;
                break;
            }
            case "nix_search":
                Qt.openUrlExternally("https://search.nixos.org/packages?query=" + encodeURIComponent(itemName));
                root.isOpen = false;
                break;
            case "copy_name":
                commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), itemName]);
                root.isOpen = false;
                break;
            case "copy_id":
                commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), itemAppId]);
                root.isOpen = false;
                break;
            case "toggle_favorite":
                toggleFavoriteApp(itemAppId || itemName);
                break;
            case "desktop_action":
                let app = resolveAppFromItem(item);
                let actionIdx = contextModel.get(actionIndex).actionIdx;
                if (app && app.actions && app.actions.values) {
                    let dActions = app.actions.values;
                    if (actionIdx >= 0 && actionIdx < dActions.length) {
                        dActions[actionIdx].execute();
                    }
                }
                root.isOpen = false;
                break;
            case "open_dir":
                if (itemType === "folder") openPathInManager(parentDirectoryForPath(itemPath));
                else revealPathInManager(itemPath);
                root.isOpen = false;
                break;
            case "copy_path":
                commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), itemPath]);
                root.isOpen = false;
                break;
            case "terminal":
                let fdir = itemType === "folder" ? itemPath : parentDirectoryForPath(itemPath);
                openPathInTerminal(fdir);
                root.isOpen = false;
                break;
            case "delete_file":
                previewActionProc.exec(["bash", launcherFileTool, "delete", itemPath]);
                root.isOpen = false;
                break;
            case "open_project":
                openPathInTerminal(itemPath || root.homeDir);
                root.isOpen = false;
                break;

            case "copy_snippet":
                commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), itemResult || ""]);
                root.isOpen = false;
                break;
            case "run_snippet_terminal":
                if (isDangerousCommand(itemResult || "") && !confirmDangerousCommand(itemResult || "")) return;
                runLauncherCommand("terminal", itemResult || "", isDangerousCommand(itemResult || ""));
                root.isOpen = false;
                break;
            case "kill":
                requestKillTermination(String(itemResult || item.pid || ""), item.command || itemName || "");
                break;
            case "kill_force": {
                if (!killForceAvailable)
                    break;
                requestKillForce(String(itemResult || item.pid || ""), item.command || itemName || "");
                break;
            }
            case "copy_pid":
                commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), String(item.pid || itemResult || "")]);
                root.isOpen = false;
                break;
            case "copy_command":
                commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), String(item.command || itemExtra || "")]);
                root.isOpen = false;
                break;
            case "copy_extra":
                commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), itemExtra || ""]);
                root.isOpen = false;
                break;
            case "move_current_ws":
                let moveIdx = parseInt(itemExtra);
                let moveTl = (moveIdx >= 0 && moveIdx < _toplevelRefs.length) ? _toplevelRefs[moveIdx] : null;
                let moveAddress = moveTl && moveTl.lastIpcObject && moveTl.lastIpcObject.address
                    ? String(moveTl.lastIpcObject.address)
                    : itemPath;
                hyprMoveWindowToWorkspace(moveAddress, activeWorkspaceId(), moveTl);
                root.isOpen = false;
                break;
            case "close_win":
                let tlIdx = parseInt(itemExtra);
                let tl = (tlIdx >= 0 && tlIdx < _toplevelRefs.length) ? _toplevelRefs[tlIdx] : null;
                hyprCloseWindow(itemPath, tl);
                root.isOpen = false;
                break;
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  VISUAL INTERFACE
    // ═══════════════════════════════════════════════════════════

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        cursorShape: Qt.ArrowCursor
        onClicked: root.isOpen = false
    }

    Item {
        id: cardContainer
        z: 1
        width: (previewVisible && showFullLauncher) ? 962 : 600
        height: showFullLauncher
            ? Math.min(launcherExpandedMaxHeight, launcherContentColumn.implicitHeight + launcherContentColumn.anchors.topMargin + launcherContentColumn.anchors.bottomMargin)
            : (showMenuOnlyLauncher ? launcherCompactMenuHeight : launcherCompactHeight)
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: launcherTopMargin

        Behavior on width {
            enabled: !FeatureFlags.reducedMotion
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: !FeatureFlags.reducedMotion
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 10

            // ─── Main Card ──────────────────────────────────────
            Rectangle {
                id: mainCard
                Layout.preferredWidth: showFullLauncher ? 600 : parent.width
                Layout.rightMargin: 0
                Layout.fillHeight: true
                radius: showFullLauncher ? launcherPanelRadius : 28
                color: Style.glassCard
                border.color: Style.outline
                border.width: 1
                clip: true

                Behavior on radius {
                    enabled: !FeatureFlags.reducedMotion
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                // Subtle mode-tinted gradient overlay
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: ColorScheme.withAlpha(getModeColor(currentMode), 0.03)
                    Behavior on color {
                        enabled: !FeatureFlags.reducedMotion
                        ColorAnimation { duration: 300 }
                    }
                }

                // Top highlight
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: 1
                    radius: launcherPanelRadius
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                // Bottom accent glow
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.6
                    height: 2; radius: 1
                    color: ColorScheme.withAlpha(getModeColor(currentMode), 0.52)
                    Behavior on color {
                        enabled: !FeatureFlags.reducedMotion
                        ColorAnimation { duration: 300 }
                    }

                    layer.enabled: false
                }

                // Lightweight shadow
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: DesignTokens.shadowLauncher.offsetY
                    radius: parent.radius
                    color: Qt.rgba(0, 0, 0, DesignTokens.shadowLauncher.alpha)
                    z: -1
                }

                ColumnLayout {
                    id: launcherContentColumn
                    anchors.fill: parent
                    anchors.leftMargin: launcherPanelInset
                    anchors.rightMargin: launcherPanelInset
                    anchors.topMargin: DesignTokens.spacingSM
                    anchors.bottomMargin: DesignTokens.spacingSM
                    spacing: DesignTokens.spacingLG

                    // ── Search Bar with Mode Indicator ──
                    LauncherSearchBar {
                        id: launcherSearchBar
                        launcher: root
                    }

                    CategoryBar {
                        id: filterBar
                        launcher: root
                        visible: filterBarOpen
                    }

                    ModeBar {
                        id: modeBar
                        launcher: root
                        visible: cheatSheetOpen
                    }

                    LauncherResultsPane {
                        id: resultsPane
                        launcher: root
                        contextModel: contextModel
                        Layout.fillWidth: true
                        visible: showFullLauncher
                    }


                }
            }

            PreviewPanel {
                id: previewCard
                launcher: root
                Layout.preferredWidth: 352
                Layout.fillHeight: true
                visible: showFullLauncher && previewVisible
            }

        }
    }

    Connections {
        target: settingsStore
        function onReadyChanged() {
            if (!settingsStore || !settingsStore.ready)
                return;

            if (isOpen && launcherStateRestorePending)
                loadLauncherSessionState();

            if (favoriteAppIdsPendingWrite)
                persistFavoriteAppIds();
            loadFavoriteAppIds();

            if (isOpen && currentMode === "apps") {
                updateSearch();
                if (launcherStateRestorePending && resultsModel.count > 0)
                    applyRestoredSelection();
            }
        }
    }

    onSelectedIndexChanged: {
        if (_restoringLauncherState)
            return;
        persistLauncherSessionState();
    }

    onCategoryFilterChanged: {
        if (_restoringLauncherState)
            return;
        launcherStateRestorePending = false;
        persistLauncherSessionState();
    }

    onFilterBarIndexChanged: {
        if (_restoringLauncherState)
            return;
        persistLauncherSessionState();
    }

    onFilterBarOpenChanged: {
        if (_restoringLauncherState)
            return;
        launcherStateRestorePending = false;
        persistLauncherSessionState();
    }

    onCheatSheetOpenChanged: {
        if (_restoringLauncherState)
            return;
        launcherStateRestorePending = false;
        persistLauncherSessionState();
    }

    // Settings Store injection
    property var settingsStore

    // Category filter state
    property string categoryFilter: ""
}
