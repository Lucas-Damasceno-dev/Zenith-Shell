pragma Singleton
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../core"
import "../../services"
import "DockServiceUtils.js" as DockServiceUtils

/**
 * DockService - Singleton provider for running apps, pinning and task management.
 * 
 * Uses FileView + JsonAdapter for persistent pins.
 */
Item {
    id: root
    visible: false
    width: 0; height: 0

    // ── Keyboard navigation signal ──────────────────────────────
    signal keyboardNavRequested()

    readonly property string scriptsDir: RuntimePaths.quickshellScriptsDir

    // ── Default pinned apps ──────────────────────────────────────
    readonly property var _defaultPins: [
        "thunar", "brave", "kitty", "code", "steam", "mpv"
    ]

    property string _pinsFile: RuntimePaths.stateDir + "/dock-pins.json"

    // ── Persistence via FileView ────────────────────────────────
    FileView {
        id: pinsFileView
        path: root._pinsFile
        preload: true
        printErrors: false

        onLoadFailed: function(error) {
            // If file doesn't exist, use default pins
            if (error === FileViewError.FileNotFound) {
                pinsAdapter.pins = root._defaultPins;
                pinsFileView.writeAdapter();
            }
        }

        JsonAdapter {
            id: pinsAdapter
            property var pins: []
            
            onPinsChanged: {
                root.refresh();
            }
        }
    }

    property alias pinnedAppIds: pinsAdapter.pins

    // ── Cache for performance ────────────────────────────────────
    property var _desktopEntryCache: ({})
    property var _entryResultCache: ({})  // appId → resolved desktop entry (null = not found)
    property bool _cacheBuilt: false

    function _buildAppCache() {
        if (_cacheBuilt) return;
        var allApps = DesktopEntries.applications;
        if (!allApps) return;
        root._desktopEntryCache = DockServiceUtils.buildDesktopEntryCache(allApps);
        root._entryResultCache = {};
        _cacheBuilt = true;
    }

    Component.onCompleted: {
        // Build the app cache after first paint so dock startup stays responsive.
        Qt.callLater(function() {
            _buildAppCache();
            root.refresh();
            _retryTimer.restart();
        });
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined" && DesktopEntries) ? DesktopEntries : null
        function onApplicationsChanged() {
            root._cacheBuilt = false;
            root._desktopEntryCache = {};
            root._entryResultCache = {};
            root._buildAppCache();
            root.refresh();
        }
    }

    function _savePins() {
        pinsFileView.writeAdapter();
    }

    // ── Running apps ─────────────────────────────────────────────
    property var _runningGroups: ({})
    property var _mergedItems: []
    property int _tick: 0
    property bool _refreshPending: false
    property bool _titleRefreshPending: false
    property real _refreshDeadlineMs: 0
    readonly property int refreshDebounceMs: FeatureFlags.lowPowerUiMode ? 90 : 50
    readonly property int titleRefreshDebounceMs: FeatureFlags.lowPowerUiMode ? 180 : 150
    property bool workspaceIsolation: false

    // ── MRU focus tracking — address → timestamp of last focus ───
    property var _focusTimestamps: ({})

    // ── Urgent / notification tracking ───────────────────────────
    property var _urgentApps: ({})

    // ── Badge count tracking (Unity Launcher API) ────────────────
    property var _badgeCounts: ({})

    // ── Audio tracking (apps emitting sound) ─────────────────────
    property var _audioApps: ({})
    property var _audioSinkInputsByApp: ({})

    // ── Scratchpad (special:minimize) window count ───────────────
    property int scratchpadCount: 0
    property var scratchpadWindows: []

    // ── Terminal icon overrides based on window title ─────────────
    readonly property var _terminalApps: ["kitty", "alacritty", "foot", "wezterm", "gnome-terminal", "konsole", "xterm"]
    readonly property var _titleIconMap: {
        "nvim": "neovim", "vim": "vim", "btop": "btop", "htop": "htop",
        "ranger": "ranger", "lazygit": "lazygit", "docker": "docker",
        "python": "python", "node": "nodejs", "cargo": "rust",
        "make": "cmake", "ssh": "terminal"
    }

    function _setMapValue(mapName, key, value) {
        var map = root[mapName] || {};
        if (map[key] === value)
            return false;
        map[key] = value;
        return true;
    }

    function _deleteMapValue(mapName, key) {
        var map = root[mapName] || {};
        if (!(key in map))
            return false;
        delete map[key];
        return true;
    }

    function _resolveTerminalIcon(appId, toplevels) {
        if (!toplevels || toplevels.length === 0) return "";
        var lowerId = (appId || "").toLowerCase();
        var isTerminal = false;
        for (var t = 0; t < _terminalApps.length; t++) {
            if (lowerId.indexOf(_terminalApps[t]) >= 0) { isTerminal = true; break; }
        }
        if (!isTerminal) return "";
        
        // Prefer the focused toplevel for accurate title detection (e.g. two Kitty windows)
        var tl = toplevels[0];
        var activeTl = Hyprland.activeToplevel;
        if (activeTl) {
            for (var f = 0; f < toplevels.length; f++) {
                if (toplevels[f] === activeTl) { tl = toplevels[f]; break; }
            }
        }
        var title = "";
        if (tl.title) title = tl.title.toLowerCase();
        else if (tl.lastIpcObject && tl.lastIpcObject.title) title = tl.lastIpcObject.title.toLowerCase();
        if (!title) return "";
        
        for (var key in _titleIconMap) {
            if (title.indexOf(key) >= 0) return _titleIconMap[key];
        }
        return "";
    }
    readonly property var mergedItems: {
        var _t = root._tick;
        return root._mergedItems;
    }

    function refresh() {
        var toplevels = [];
        if (Hyprland.toplevels) {
            var vals = Hyprland.toplevels.values;
            if (vals) {
                for (var i = 0; i < vals.length; i++) toplevels.push(vals[i]);
            }
        }

        var groups = {};
        var spCount = 0;
        var spWindows = [];
        var focusedWs = Hyprland.focusedWorkspace;
        var active = Hyprland.activeToplevel; // Cache once — avoids N IPC reads in the loop
        for (var j = 0; j < toplevels.length; j++) {
            var tl = toplevels[j];
            if (!tl) continue;
            var appId = (tl.appId || "").toLowerCase();
            if (!appId) continue;

            var wsId = tl.workspace ? tl.workspace.id : 0;
            var wsName = tl.lastIpcObject && tl.lastIpcObject.workspace ? tl.lastIpcObject.workspace.name : "";

            if (root.workspaceIsolation && focusedWs && tl.workspace) {
                if (String(wsId) !== String(focusedWs.id)) continue;
            }

            if (!groups[appId]) {
                groups[appId] = { appId: appId, toplevels: [], focused: false, focusedIdx: 0, minimizedAll: true, floating: false, hasPip: false };
            }
            groups[appId].toplevels.push(tl);

            if (active && active === tl) {
                groups[appId].focused = true;
                groups[appId].focusedIdx = groups[appId].toplevels.length - 1;
            }

            // Track scratchpad (merged to avoid second pass over toplevels)
            if (wsId < 0 || wsName === "special:minimize") {
                spCount++;
                spWindows.push({
                    address: tl.lastIpcObject ? tl.lastIpcObject.address : "",
                    title: tl.title || (tl.lastIpcObject ? tl.lastIpcObject.title : "") || "Window",
                    appId: appId,
                    icon: (tl.appId || "")
                });
            }

            // In Hyprland, a window is minimized if it's in a special workspace or has minimized flag
            var isMin = (tl.lastIpcObject ? !!tl.lastIpcObject.minimized : false) || wsId < 0;
            if (!isMin) groups[appId].minimizedAll = false;

            // Track floating state
            var isFloat = (tl.floating === true) || (tl.lastIpcObject && tl.lastIpcObject.floating === true);
            if (isFloat) groups[appId].floating = true;

            // Detect PiP windows (floating + small dimensions)
            if (isFloat && tl.lastIpcObject && tl.lastIpcObject.size) {
                var w = tl.lastIpcObject.size[0] || 0;
                var h = tl.lastIpcObject.size[1] || 0;
                if (w > 0 && h > 0 && w < 640 && h < 480) {
                    groups[appId].hasPip = true;
                }
            }
        }
        root._runningGroups = groups;
        root.scratchpadCount = spCount;
        root.scratchpadWindows = spWindows;

        var items = [];
        var seen = {};
        var currentPins = pinsAdapter.pins || [];

        // 1. Process Pinned Items
        for (var p = 0; p < currentPins.length; p++) {
            var pid = String(currentPins[p] || "").trim().toLowerCase();
            if (pid === "")
                continue;
            var entry = _lookupDesktopEntry(pid);
            
            // Try to find a group that matches this pin
            var group = groups[pid.toLowerCase()] || null;
            if (!group && entry) {
                // Try matching group by startupWMClass
                if (entry.startupWMClass && groups[entry.startupWMClass.toLowerCase()]) {
                    group = groups[entry.startupWMClass.toLowerCase()];
                }
            }
            
            if (group) seen[group.appId] = true;

            var termIcon = group ? _resolveTerminalIcon(pid, group.toplevels) : "";
            var baseIcon = entry ? entry.icon : pid;
            
            items.push({
                appId: pid,
                pinned: true,
                running: !!group,
                instanceCount: group ? group.toplevels.length : 0,
                focused: group ? group.focused : false,
                focusedIdx: group ? group.focusedIdx : 0,
                minimizedAll: group ? group.minimizedAll : false,
                floating: group ? group.floating : false,
                desktopEntry: entry,
                toplevels: group ? group.toplevels : [],
                icon: termIcon || baseIcon,
                name: entry ? entry.name : pid,
                launching: isLaunching(pid),
                urgent: !!(root._urgentApps[pid]) || (group ? !!(root._urgentApps[group.appId]) : false),
                badgeCount: root._badgeCounts[pid] || 0,
                audioActive: !!(root._audioApps[pid]) || (group ? !!(root._audioApps[group.appId]) : false),
                xwayland: group ? _checkXWayland(group.toplevels) : false,
                hasSpecial: group ? _checkSpecialWorkspace(group.toplevels) : false,
                hasPip: group ? group.hasPip : false
            });
        }

        // 2. Process Unpinned Running Items
        var sortedRunningKeys = Object.keys(groups).sort();
        for (var k = 0; k < sortedRunningKeys.length; k++) {
            var rk = sortedRunningKeys[k];
            if (seen[rk]) continue;
            
            var rGroup = groups[rk];
            var rEntry = _lookupDesktopEntry(rk);
            var rTermIcon = _resolveTerminalIcon(rk, rGroup.toplevels);
            var rBaseIcon = rEntry ? rEntry.icon : rk;
            
            items.push({
                appId: rk,
                pinned: false,
                running: true,
                instanceCount: rGroup.toplevels.length,
                focused: rGroup.focused,
                focusedIdx: rGroup.focusedIdx,
                minimizedAll: rGroup.minimizedAll,
                floating: rGroup.floating,
                desktopEntry: rEntry,
                toplevels: rGroup.toplevels,
                icon: rTermIcon || rBaseIcon,
                name: rEntry ? rEntry.name : rk,
                launching: isLaunching(rk),
                urgent: !!(root._urgentApps[rk]),
                badgeCount: Number(root._badgeCounts[rk] || 0),
                audioActive: !!(root._audioApps[rk]),
                xwayland: _checkXWayland(rGroup.toplevels),
                hasSpecial: _checkSpecialWorkspace(rGroup.toplevels),
                hasPip: rGroup.hasPip
            });
        }

        root._mergedItems = items;
        root._tick++;
    }

    function queueRefresh(titleDriven) {
        var now = new Date().getTime();
        if (titleDriven === true)
            root._titleRefreshPending = true;
        else
            root._refreshPending = true;

        var delayMs = root._titleRefreshPending ? root.titleRefreshDebounceMs : root.refreshDebounceMs;
        var nextDeadline = now + delayMs;
        if (root._refreshDeadlineMs <= 0 || root._refreshDeadlineMs < now)
            root._refreshDeadlineMs = nextDeadline;
        else
            root._refreshDeadlineMs = Math.max(root._refreshDeadlineMs, nextDeadline);

        eventRefreshTimer.interval = Math.max(1, Math.round(root._refreshDeadlineMs - now));
        eventRefreshTimer.restart();
    }

    function flushQueuedRefresh() {
        root._refreshPending = false;
        root._titleRefreshPending = false;
        root._refreshDeadlineMs = 0;
        root.refresh();
    }

    function _lookupDesktopEntry(appId) {
        if (!appId) return null;
        if (!_cacheBuilt) _buildAppCache();
        var lowerId = appId.toLowerCase();

        // Fast path: return cached result (null means already searched, not found)
        if (lowerId in root._entryResultCache) return root._entryResultCache[lowerId];

        var result = DockServiceUtils.lookupDesktopEntry(lowerId, root._desktopEntryCache);
        if (!result && typeof DesktopEntries !== "undefined" && DesktopEntries) {
            if (typeof DesktopEntries.byId === "function")
                result = DesktopEntries.byId(appId) || DesktopEntries.byId(lowerId) || DesktopEntries.byId(lowerId + ".desktop");
            if (!result && typeof DesktopEntries.heuristicLookup === "function")
                result = DesktopEntries.heuristicLookup(appId) || DesktopEntries.heuristicLookup(lowerId);
        }

        root._entryResultCache[lowerId] = result;
        return result;
    }

    // ── Launch or Focus (standard: click focuses, click-again minimizes) ─
    function launchOrFocus(item) {
        if (!item) return;

        if (item.running && item.toplevels && item.toplevels.length > 0) {
            _clearUrgent(item.appId);

            if (item.focused) {
                // Already focused → minimize via Hyprland native minimize (special workspace)
                for (var i = 0; i < item.toplevels.length; i++) {
                    var tl = item.toplevels[i];
                    if (tl && tl.lastIpcObject && tl.lastIpcObject.address) {
                        // Use special:minimize as a "minimized" state in Hyprland
                        Hyprland.dispatch("movetoworkspacesilent special:minimize,address:" + tl.lastIpcObject.address);
                    }
                }
            } else {
                // Not focused → bring back from special if needed
                var firstTl = item.toplevels[0];
                if (firstTl && firstTl.lastIpcObject && firstTl.lastIpcObject.address) {
                    var addr = firstTl.lastIpcObject.address;
                    
                    // Check if it's in a special workspace (usually negative IDs)
                    var isSpecial = false;
                    if (firstTl.workspace && firstTl.workspace.id < 0) isSpecial = true;
                    else if (firstTl.lastIpcObject && firstTl.lastIpcObject.workspace && firstTl.lastIpcObject.workspace.id < 0) isSpecial = true;

                    if (isSpecial) {
                        var currentWs = Hyprland.focusedWorkspace;
                        var targetWs = currentWs ? String(currentWs.id) : "1";
                        // Only restore windows that are actually in special/minimized workspaces
                        for (var j = 0; j < item.toplevels.length; j++) {
                            var tlj = item.toplevels[j];
                            if (tlj && tlj.lastIpcObject) {
                                var wId = tlj.workspace ? tlj.workspace.id :
                                          (tlj.lastIpcObject.workspace ? tlj.lastIpcObject.workspace.id : 0);
                                if (wId < 0) {
                                    Hyprland.dispatch("movetoworkspacesilent " + targetWs + ",address:" + tlj.lastIpcObject.address);
                                }
                            }
                        }
                    }
                    Hyprland.dispatch("focuswindow address:" + addr);
                }
            }
        } else {
            _launchApp(item);
            _markLaunching(item.appId);
        }
    }

    // ── Launch New Instance (middle click) ────────────────────────
    function launchNewInstance(item) {
        if (!item) return;
        _launchApp(item);
        _markLaunching(item.appId);
    }

    // ── Launch with Files (drag and drop) ────────────────────────
    function launchWithFiles(item, filePaths) {
        if (!item || !filePaths || filePaths.length === 0) return;
        
        var filesStr = filePaths.map(function(p) { return "'" + p + "'"; }).join(" ");
        console.log("[DockService] Launching with files:", item.appId, filesStr);
        
        if (item.desktopEntry && item.desktopEntry.execString) {
            var cmd = item.desktopEntry.execString;
            // Replace %f, %u etc with the actual files
            if (cmd.indexOf("%") >= 0) {
                cmd = cmd.replace(/%[fFuUn]/g, filesStr).replace(/%[iickv]/g, "").trim();
            } else {
                cmd = cmd.trim() + " " + filesStr;
            }
            
            try {
                launchProc.exec(["bash", RuntimePaths.scriptFile("launcher_run_command.sh"), "direct", cmd]);
            } catch (e) {
                Hyprland.dispatch("exec " + cmd);
            }
        } else {
            var appId = item.appId || "";
            Hyprland.dispatch("exec " + appId + " " + filesStr);
        }
        _markLaunching(item.appId);
    }

    function buildLaunchCommand(item, extraArgs) {
        return DockServiceUtils.buildLaunchCommand(item, extraArgs);
    }

    function runCommand(mode, commandText, confirmDangerous) {
        var cmd = String(commandText || "").trim();
        if (cmd === "") return;

        var args = ["bash", RuntimePaths.scriptFile("launcher_run_command.sh"), mode || "direct", cmd];
        if (confirmDangerous === true)
            args.push("--confirm-dangerous");
        launchProc.exec(args);
    }

    function _launchApp(item) {
        if (!item) return;
        console.log("[DockService] Attempting to launch:", item.appId);
        var entry = item.desktopEntry || _lookupDesktopEntry(item.appId);
        if (entry && typeof entry.execute === "function") {
            try {
                console.log("[DockService] Executing via desktopEntry.execute():", entry.id || entry.name);
                entry.execute();
                return;
            } catch (e) {
                console.log("[DockService] desktopEntry.execute failed, fallback to script:", e);
            }
        }
        var cmd = buildLaunchCommand(item, []);
        if (cmd) {
            console.log("[DockService] Executing desktop command via hypr fallback script:", cmd);
            try {
                runCommand("direct", cmd);
            } catch (e) {
                console.log("[DockService] Fallback exec failed, attempting Hyprland.dispatch:", e);
                Hyprland.dispatch("exec " + cmd);
            }
        }
    }

    function focusNextInstance(appId, delta) {
        var group = root._runningGroups[appId];
        if (!group || group.toplevels.length <= 1) return;

        // Sort toplevels by last-focus timestamp descending (MRU order: most recent first)
        var sorted = group.toplevels.slice().sort(function(a, b) {
            var ta = (a.lastIpcObject && root._focusTimestamps[a.lastIpcObject.address]) || 0;
            var tb = (b.lastIpcObject && root._focusTimestamps[b.lastIpcObject.address]) || 0;
            return tb - ta; // descending: most recently focused first
        });

        // Find where the currently focused window sits in MRU order
        var active = Hyprland.activeToplevel;
        var currentIdx = -1;
        for (var i = 0; i < sorted.length; i++) {
            if (sorted[i] === active) { currentIdx = i; break; }
        }

        // Cycle in the requested direction through the MRU list
        var nextIdx = (currentIdx + delta + sorted.length) % sorted.length;
        var nextTl = sorted[nextIdx];
        if (nextTl && nextTl.lastIpcObject) {
            Hyprland.dispatch("focuswindow address:" + nextTl.lastIpcObject.address);
        }
    }

    // ── Launch tracking ──────────────────────────────────────────
    property var _launchingApps: ({})

    function _markLaunching(appId) {
        if (_setMapValue("_launchingApps", appId, Date.now()))
            root._tick++;
        if (!_launchTimer.running) _launchTimer.running = true;
    }

    function isLaunching(appId) {
        var _t = root._tick;
        var ts = root._launchingApps[appId];
        if (!ts) return false;
        
        // If app has appeared as running, clear launching state immediately
        if (root._runningGroups[appId]) {
            _clearLaunching(appId);
            return false;
        }
        
        // Timeout after 15 seconds
        return (Date.now() - ts) < 15000;
    }

    function _clearLaunching(appId) {
        if (_deleteMapValue("_launchingApps", appId))
            root._tick++;
    }

    // Checks every second and clears only entries that have timed out (>15s).
    // Stops itself when no more launching apps remain.
    Timer {
        id: _launchTimer
        interval: 1000; repeat: true; running: false
        onTriggered: {
            var now = Date.now();
            var changed = false;
            var hasAny = false;
            for (var id in root._launchingApps) {
                if (now - root._launchingApps[id] >= 15000) {
                    delete root._launchingApps[id];
                    changed = true;
                } else {
                    hasAny = true;
                }
            }
            if (changed) {
                root._tick++;
                root.refresh();
            }
            if (!hasAny) running = false;
        }
    }

    // ── Pin / Unpin / Reorder ────────────────────────────────────
    function pinApp(appId) {
        var list = pinsAdapter.pins.slice();
        if (list.indexOf(appId) < 0) {
            list.push(appId);
            pinsAdapter.pins = list;
            _savePins();
            root.refresh();
        }
    }

    function unpinApp(appId) {
        pinsAdapter.pins = pinsAdapter.pins.filter(function(id) { return id !== appId; });
        _savePins();
        root.refresh();
    }

    function togglePin(appId) {
        if (pinsAdapter.pins.indexOf(appId) >= 0) unpinApp(appId); else pinApp(appId);
    }

    function reorderPins(fromIndex, toIndex) {
        var list = pinsAdapter.pins.slice();
        if (fromIndex < 0 || fromIndex >= list.length) return;
        if (toIndex < 0) return;
        if (toIndex > list.length) toIndex = list.length;
        if (fromIndex === toIndex) return;
        var item = list.splice(fromIndex, 1)[0];
        list.splice(toIndex, 0, item);
        pinsAdapter.pins = list;
        _savePins();
        root.refresh();
    }

    function reorderPinsByAppId(fromAppId, toAppId) {
        var list = pinsAdapter.pins.slice();
        var fromIndex = list.indexOf(fromAppId);
        var toIndex = list.indexOf(toAppId);
        if (fromIndex < 0 || toIndex < 0) return;
        reorderPins(fromIndex, toIndex);
    }

    function restoreItem(item) {
        if (!item || !item.toplevels || item.toplevels.length === 0) return;
        var currentWs = Hyprland.focusedWorkspace;
        var targetWs = currentWs ? String(currentWs.id) : "1";
        for (var i = 0; i < item.toplevels.length; i++) {
            var tl = item.toplevels[i];
            if (!tl || !tl.lastIpcObject || !tl.lastIpcObject.address) continue;
            var wsId = tl.workspace ? tl.workspace.id : (tl.lastIpcObject.workspace ? tl.lastIpcObject.workspace.id : 0);
            if (wsId < 0 || item.minimizedAll) {
                Hyprland.dispatch("movetoworkspacesilent " + targetWs + ",address:" + tl.lastIpcObject.address);
            }
        }
        if (item.toplevels[0] && item.toplevels[0].lastIpcObject)
            Hyprland.dispatch("focuswindow address:" + item.toplevels[0].lastIpcObject.address);
    }

    // ── Urgent / Badge tracking ──────────────────────────────────
    function _clearUrgent(appId) {
        if (_deleteMapValue("_urgentApps", appId))
            root._tick++;
    }

    function getUrgent(appId) {
        var _t = root._tick;
        return !!(root._urgentApps[appId]);
    }

    // ── XWayland detection ───────────────────────────────────────
    function _checkXWayland(toplevels) {
        if (!toplevels) return false;
        for (var i = 0; i < toplevels.length; i++) {
            var tl = toplevels[i];
            if (tl && tl.lastIpcObject && tl.lastIpcObject.xwayland === true) return true;
        }
        return false;
    }

    function _checkSpecialWorkspace(toplevels) {
        if (!toplevels) return false;
        for (var i = 0; i < toplevels.length; i++) {
            var tl = toplevels[i];
            if (!tl) continue;
            var wsObj = tl.workspace
                ? tl.workspace
                : (tl.lastIpcObject && tl.lastIpcObject.workspace ? tl.lastIpcObject.workspace : null);
            var wsId = wsObj && wsObj.id !== undefined ? Number(wsObj.id) : 0;
            var wsName = wsObj && wsObj.name !== undefined ? String(wsObj.name) : "";
            if (isFinite(wsId) && wsId < 0) return true;
            if (wsName !== "" && wsName.indexOf("special") >= 0) return true;
        }
        return false;
    }

    // ── Audio monitoring (poll wpctl status) ─────────────────────
    Timer {
        id: _audioPollTimer
        interval: 30000; running: !FeatureFlags.lowPowerUiMode; repeat: true; triggeredOnStart: true
        onTriggered: _audioProc.running = true
    }

    Process {
        id: _audioProc
        // Parse application.process.binary from verbose pactl output.
        // "short" format uses field $4 = numeric client-id, not app name — always wrong.
        // Emit "<sink-input-id>|<binary>" and also "<id>|<stripped>" for Brave-style binaries.
        command: ["bash", "-c", "pactl list sink-inputs 2>/dev/null | awk '\nfunction emit() {\n    if (id == \"\" || bin == \"\") return\n    short = bin; gsub(/-browser$|-bin$|-stable$|-nightly$|-beta$/, \"\", short)\n    print id \"|\" short\n    if (short != bin) print id \"|\" bin\n    if (aname != \"\" && aname != short && aname != bin) print id \"|\" aname\n}\n/^Sink Input #/ { emit(); id = substr($3, 2); bin = \"\"; aname = \"\" }\n/application\\.process\\.binary/ { split($0, a, \"\\\"\"); bin = tolower(a[2]); gsub(/.*\\//, \"\", bin) }\n/application\\.name = / { split($0, a, \"\\\"\"); if (a[2] != \"\") aname = tolower(a[2]) }\nEND { emit() }\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (text || "").trim().split("\n");
                var audioMap = {};
                var sinkInputMap = {};
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    var parts = line.split("|");
                    if (parts.length < 2) continue;
                    var sinkId = String(parts[0] || "").trim();
                    var app = String(parts[1] || "").trim().toLowerCase();
                    if (!app) continue;
                    audioMap[app] = true;
                    if (!sinkInputMap[app]) sinkInputMap[app] = [];
                    if (sinkId && sinkInputMap[app].indexOf(sinkId) < 0)
                        sinkInputMap[app].push(sinkId);
                }
                root._audioApps = audioMap;
                root._audioSinkInputsByApp = sinkInputMap;
                root._tick++;
            }
        }
    }

    function adjustAppVolumes(appId, delta) {
        var key = String(appId || "").toLowerCase();
        var inputs = root._audioSinkInputsByApp[key] || [];
        if (!inputs || inputs.length === 0)
            return;

        var quotedIds = [];
        for (var i = 0; i < inputs.length; i++) {
            var sinkId = String(inputs[i] || "").trim();
            if (sinkId !== "")
                quotedIds.push("'" + sinkId.replace(/'/g, "'\\''") + "'");
        }

        if (quotedIds.length === 0)
            return;

        volumeAdjustProc.exec([
            "bash",
            "-c",
            "for id in " + quotedIds.join(" ") + "; do pactl set-sink-input-volume \"$id\" " + delta + "; done"
        ]);
    }

    // ── Scratchpad restore ───────────────────────────────────────
    function restoreFromScratchpad(address) {
        if (!address) return;
        var currentWs = Hyprland.focusedWorkspace;
        var targetWs = currentWs ? String(currentWs.id) : "1";
        Hyprland.dispatch("movetoworkspacesilent " + targetWs + ",address:" + address);
        Hyprland.dispatch("focuswindow address:" + address);
    }

    function restoreAllFromScratchpad() {
        var wins = root.scratchpadWindows;
        var currentWs = Hyprland.focusedWorkspace;
        var targetWs = currentWs ? String(currentWs.id) : "1";
        for (var i = 0; i < wins.length; i++) {
            if (wins[i].address) {
                Hyprland.dispatch("movetoworkspacesilent " + targetWs + ",address:" + wins[i].address);
            }
        }
    }

    // ── Mic/Camera privacy indicator (delegated to PrivacyService) ─────────
    readonly property bool _micActive: PrivacyService.micActive
    readonly property bool _cameraActive: PrivacyService.cameraActive

    // ── Auto-refresh ─────────────────────────────────────────────
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event.name;
            if (n === "openwindow" || n === "closewindow" ||
                n === "movewindow" || n === "activewindow" ||
                n === "activewindowv2" || n === "changefloatingmode" ||
                n === "minimize" || n === "fullscreen" ||
                n === "workspace" || n === "focusedmon") {

                // On openwindow, check if we can clear any launching state
                if (n === "openwindow") {
                    var args = event.data.split(",");
                    if (args.length >= 3) {
                        var appId = args[2];
                        if (root._launchingApps[appId]) {
                            _clearLaunching(appId);
                        }
                    }
                }

                // MRU: record focus timestamp for the newly active window
                if ((n === "activewindow" || n === "activewindowv2") && Hyprland.activeToplevel) {
                    var active = Hyprland.activeToplevel;
                    if (active && active.lastIpcObject && active.lastIpcObject.address) {
                        _setMapValue("_focusTimestamps", active.lastIpcObject.address, Date.now());
                    }
                }

                root.queueRefresh(false);
            }

            // windowtitle fires every ~1s when htop/nvim is running — use a longer debounce
            if (n === "windowtitle") {
                root.queueRefresh(true);
            }

            // Track urgent windows for badges
            if (n === "urgent") {
                var addr = event.data;
                for (var appId in root._runningGroups) {
                    var group = root._runningGroups[appId];
                    for (var i = 0; i < group.toplevels.length; i++) {
                        var tl = group.toplevels[i];
                        if (tl && tl.lastIpcObject && tl.lastIpcObject.address === addr) {
                            if (_setMapValue("_urgentApps", appId, true))
                                root._tick++;
                            break;
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: eventRefreshTimer
        interval: root.refreshDebounceMs
        repeat: false
        onTriggered: root.flushQueuedRefresh()
    }

    // Process helper used to run launcher helper script when Hyprland.exec via
    // dispatch may not be available due to limited PATH or runtime environment.
    TimedProcess {
        id: launchProc
        timeoutMs: 0
        onExited: function(exitCode) {
            console.log("[DockService] launchProc exited with code:", exitCode);
            // trigger a refresh so launching state updates
            root._tick++;
            root.queueRefresh(false);
        }
    }

    TimedProcess { id: volumeAdjustProc }

    // ── Layout Time-Machine ────────────────────────────────────
    property string _layoutFile: RuntimePaths.stateDir + "/dock-layout-snapshot.json"

    function saveLayout() {
        _saveLayoutProc.command = ["bash", "-c",
            "hyprctl clients -j | jq '[.[] | {class, title, at, size, workspace: .workspace.id, floating}]' > " + _layoutFile
        ];
        _saveLayoutProc.running = true;
        console.log("[DockService] Saving layout snapshot to", _layoutFile);
    }

    function restoreLayout() {
        _restoreLayoutProc.command = ["bash", "-c",
            "cat " + _layoutFile + " 2>/dev/null"
        ];
        _restoreLayoutProc.running = true;
    }

    Process { id: _saveLayoutProc }

    Process {
        id: _restoreLayoutProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var layout = JSON.parse(text || "[]");
                    for (var i = 0; i < layout.length; i++) {
                        var entry = layout[i];
                        // Find matching client by class
                        var clients = Hyprland.clients;
                        for (var j = 0; j < clients.length; j++) {
                            var c = clients[j];
                            if (c.lastIpcObject && c.lastIpcObject.class === entry.class) {
                                var addr = c.lastIpcObject.address;
                                if (entry.workspace)
                                    Hyprland.dispatch("movetoworkspacesilent " + entry.workspace + ",address:" + addr);
                                if (entry.at && entry.size)
                                    Hyprland.dispatch("movewindowpixel exact " + entry.at[0] + " " + entry.at[1] + ",address:" + addr);
                                if (entry.size)
                                    Hyprland.dispatch("resizewindowpixel exact " + entry.size[0] + " " + entry.size[1] + ",address:" + addr);
                                if (entry.floating)
                                    Hyprland.dispatch("setfloating address:" + addr);
                                break;
                            }
                        }
                    }
                    console.log("[DockService] Layout restored:", layout.length, "windows");
                } catch (e) {
                    console.log("[DockService] Failed to restore layout:", e);
                }
            }
        }
    }

    Timer {
        id: _retryTimer
        interval: 500; repeat: true
        property int attempts: 0
        onTriggered: {
            root.refresh();
            attempts++;
            var hasEntries = false;
            for (var i = 0; i < root._mergedItems.length; i++) {
                if (root._mergedItems[i].desktopEntry) { hasEntries = true; break; }
            }
            if (hasEntries || attempts >= 12) { _retryTimer.stop(); attempts = 0; }
        }
    }
}
