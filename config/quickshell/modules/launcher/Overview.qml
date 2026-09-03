pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import "../../core"
import "../../shared"
import "./OverviewUtils.js" as OverviewUtils

/**
 * Overview - Modern fullscreen workspace overview (Mission Control / Exposé)
 *
 * Features:
 *   - Shows all 10 Standard Workspaces by default (with auto 16:9 adaptive grid)
 *   - Dedicated Hyprland Special Workspaces / Scratchpads drawer (Magic, Notes, Chat, OpenCode, SP1..10)
 *   - Seamless Drag-and-Drop between Normal Workspaces AND Special Workspaces (in both directions)
 *   - Quick "Enviar para Scratchpad" (right-click or mini magic wand button)
 *   - Quick "Trazer para Workspace Normal" buttons and drag-out support
 *   - Live window miniatures with actual positions, focus highlights and app icons
 *   - Integrated window search with keyboard navigation (Up/Down + Enter)
 *   - Quick layout arrangement switcher (Grid, Stack, Columns, Master, Float)
 *   - Full keyboard navigation (1-9, Escape, Arrow keys, Tab)
 *   - Zero background GPU/IPC overhead when closed
 */
AnimatedWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    showScrim: true
    scrimOpacity: 0.68
    glassRadius: 0
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0

    originY: 0.0
    originX: 0.5
    slideY: -30

    // ─── Mode & Filter Properties ───────────────────────────────
    property bool currentWorkspaceOnly: false
    property bool activeOnlyFilter: false
    property string searchFilter: ""
    property var searchMatches: []
    property int searchMatchIndex: 0
    property string activeSpecialInspector: "" // Inspected special workspace name (e.g. "special:magic")
    readonly property bool isCompactScreen: root.height < 800

    // ─── Reactivity Counter & Events ────────────────────────────
    property int _tick: 0

    Connections {
        target: Hyprland
        enabled: root.isOpen
        function onRawEvent(event) {
            var n = String(event.name || "");
            if (n === "workspace" || n === "createworkspace" || n === "destroyworkspace" ||
                n === "openwindow" || n === "closewindow" || n === "movewindow" ||
                n === "activewindow" || n === "focusedworkspace" || n.indexOf("special") >= 0) {
                root._tick++;
            }
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
            root._tick++;
            root.searchFilter = "";
            root.searchMatches = [];
            root.searchMatchIndex = 0;
            root.activeSpecialInspector = "";
            overviewSearchField.text = "";
            overviewSearchField.forceActiveFocus();
        }
    }

    // ─── Workspaces Tracking (All 10 by default) ────────────────
    readonly property var workspaceIds: {
        var _t = root._tick;
        if (!root.isOpen) return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        var toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        var active = Hyprland.activeWorkspace;
        var activeId = active && active.id > 0 ? active.id : 1;
        return OverviewUtils.getWorkspaceIds(toplevels, activeId, root.currentWorkspaceOnly, root.activeOnlyFilter);
    }

    // Special Workspaces (Scratchpads) list
    readonly property var specialWorkspaces: {
        var _t = root._tick;
        if (!root.isOpen) return [];
        var toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        return OverviewUtils.getSpecialWorkspaces(toplevels);
    }

    // Windows inside currently inspected special workspace
    readonly property var inspectedSpecialClients: {
        var _t = root._tick;
        if (!root.isOpen || root.activeSpecialInspector === "") return [];
        var toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        return OverviewUtils.getClientsForSpecialWorkspace(toplevels, root.activeSpecialInspector);
    }

    // ─── Layout Info (Computed dynamically for zero-overflow) ───
    readonly property var gridLayoutInfo: {
        var _t = root._tick;
        var count = workspaceIds.length;
        var availW = gridArea.width > 0 ? gridArea.width : (root.width - 40);
        var reservedH = (root.activeSpecialInspector !== "" ? 120 : 0) + (root.isCompactScreen ? 180 : 250);
        var availH = Math.max(160, (gridArea.height > 0 ? gridArea.height : root.height) - reservedH);
        return OverviewUtils.calcGridDimensions(count, availW, availH);
    }

    // ─── Workspace Metadata ─────────────────────────────────────
    readonly property var wsIcons: [
        "\u{f120}", "\u{f0ac}", "\u{f07b}", "\u{db84}\u{de1e}", "\u{f15c}",
        "\u{f086}", "\u{f001}", "\u{f008}", "\u{f11b}", "\u{f013}",
        "\u{f0e0}", "\u{f02d}", "\u{f1c0}", "\u{f188}", "\u{f0ad}",
        "\u{f135}", "\u{f24e}", "\u{f0f3}", "\u{f0c0}", "\u{f233}"
    ]
    readonly property var wsLabels: [
        "Terminal", "Browser", "Files", "Code", "Office",
        "Chat", "Music", "Media", "Games", "System",
        "Email", "Docs", "Data", "Debug", "Tools",
        "Server", "Notes", "Alerts", "Social", "Virtual"
    ]

    readonly property var categoryColors: [
        ColorScheme.green, ColorScheme.blue, ColorScheme.yellow,
        ColorScheme.mauve, ColorScheme.peach, ColorScheme.teal,
        ColorScheme.accent, ColorScheme.red, ColorScheme.blue,
        ColorScheme.text, ColorScheme.pink, ColorScheme.sapphire,
        ColorScheme.lavender, ColorScheme.maroon, ColorScheme.rosewater,
        ColorScheme.flamingo, ColorScheme.sky, ColorScheme.green,
        ColorScheme.mauve, ColorScheme.peach
    ]

    function categoryColor(wsId) {
        return OverviewUtils.categoryColor(wsId, categoryColors, ColorScheme.accent);
    }

    function findWorkspace(id) {
        return OverviewUtils.findWorkspace(Hyprland.workspaces ? Hyprland.workspaces.values : [], id);
    }

    function getClientsForWorkspace(wsId) {
        return OverviewUtils.getClientsForWorkspace(Hyprland.toplevels ? Hyprland.toplevels.values : [], wsId);
    }

    function getIconForClient(cls) {
        return OverviewUtils.getIconForClient(cls);
    }

    function normalizeAddress(address) {
        return OverviewUtils.normalizeAddress(address);
    }

    // ─── Drag-and-Drop State (Normal & Special Workspaces) ───────
    property string _dragAddress: ""
    property string _dragClass: ""
    property var _dragSourceWs: null
    property bool _dragging: false
    property real _dragGlobalX: 0
    property real _dragGlobalY: 0

    function _findTileAtPos(globalX, globalY) {
        // 1. Check normal workspace tiles (1..10)
        var repeater = wsRepeater;
        if (repeater) {
            for (var i = 0; i < repeater.count; i++) {
                var tile = repeater.itemAt(i);
                if (!tile) continue;
                var tilePos = tile.mapToItem(overviewContent, 0, 0);
                if (globalX >= tilePos.x && globalX <= tilePos.x + tile.width &&
                    globalY >= tilePos.y && globalY <= tilePos.y + tile.height) {
                    return { type: "normal", wsId: tile.wsId, item: tile };
                }
            }
        }

        // 2. Check special workspace chips
        var spRep = spRepeater;
        if (spRep) {
            for (var s = 0; s < spRep.count; s++) {
                var spChip = spRep.itemAt(s);
                if (!spChip) continue;
                var spPos = spChip.mapToItem(overviewContent, 0, 0);
                if (globalX >= spPos.x && globalX <= spPos.x + spChip.width &&
                    globalY >= spPos.y && globalY <= spPos.y + spChip.height) {
                    return { type: "special", spName: spChip.spName, item: spChip };
                }
            }
        }

        return null;
    }

    function _isOverTile(tile) {
        if (!_dragging || !tile) return false;
        var tilePos = tile.mapToItem(overviewContent, 0, 0);
        return _dragGlobalX >= tilePos.x && _dragGlobalX <= tilePos.x + tile.width &&
               _dragGlobalY >= tilePos.y && _dragGlobalY <= tilePos.y + tile.height;
    }

    function _finishDrag(globalX, globalY) {
        if (!_dragging || !_dragAddress) {
            _dragging = false;
            return;
        }
        var target = _findTileAtPos(globalX, globalY);
        var dragAddr = normalizeAddress(_dragAddress);

        if (target && dragAddr !== "") {
            if (target.type === "normal" && _dragSourceWs !== target.wsId) {
                Hyprland.dispatch("movetoworkspace " + target.wsId + ",address:" + dragAddr);
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
                root._tick++;
                refreshTimer.startRefresh();
            } else if (target.type === "special" && _dragSourceWs !== target.spName) {
                Hyprland.dispatch("movetoworkspace " + target.spName + ",address:" + dragAddr);
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
                root._tick++;
                refreshTimer.startRefresh();
            }
        }
        _dragging = false;
        _dragAddress = "";
        _dragClass = "";
        _dragSourceWs = null;
    }

    Timer {
        id: refreshTimer
        interval: 200
        repeat: true
        running: false
        property int ticksRemaining: 0
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
            root._tick++;
            ticksRemaining--;
            if (ticksRemaining <= 0) stop();
        }
        function startRefresh() {
            ticksRemaining = 4;
            start();
        }
    }

    // ─── Search & Navigation Logic ──────────────────────────────
    function buildSearchMatches(query) {
        var filter = String(query || "").trim().toLowerCase();
        var windows = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        var out = [];
        for (var i = 0; i < windows.length; i++) {
            var c = windows[i];
            if (!c) continue;
            var ipc = c.lastIpcObject || {};
            var title = String(c.title || ipc.title || "");
            var cls = String(ipc["class"] || c.appId || "");
            var titleLower = title.toLowerCase();
            var clsLower = cls.toLowerCase();
            if (filter !== "" && titleLower.indexOf(filter) < 0 && clsLower.indexOf(filter) < 0)
                continue;
            var wsObj = c.workspace ? c.workspace : (ipc.workspace ? ipc.workspace : null);
            var wsId = wsObj && wsObj.id !== undefined ? Number(wsObj.id) : 0;
            var wsName = String((wsObj && wsObj.name) || (ipc.workspace && ipc.workspace.name) || "");
            var addr = normalizeAddress(c.address || ipc.address);
            if (addr === "") continue;

            out.push({
                title: title !== "" ? title : cls,
                className: cls,
                workspaceId: wsId,
                workspaceName: wsName,
                isSpecial: wsName.indexOf("special") === 0 || wsId < 0,
                address: addr
            });
        }
        return out;
    }

    function activateSearchResult(index) {
        if (!searchMatches || searchMatches.length <= 0)
            return;
        var idx = Math.max(0, Math.min(Number(index || 0), searchMatches.length - 1));
        var target = searchMatches[idx];
        if (!target) return;

        if (target.isSpecial) {
            var spName = target.workspaceName.replace("special:", "");
            Hyprland.dispatch("togglespecialworkspace " + spName);
        } else {
            Hyprland.dispatch("workspace " + target.workspaceId);
        }

        var addr = normalizeAddress(target.address);
        if (addr !== "")
            Hyprland.dispatch("focuswindow address:" + addr);
        root.isOpen = false;
    }

    function moveWindowToActiveWorkspace(addr) {
        var cleanAddr = normalizeAddress(addr);
        if (!cleanAddr) return;
        var active = Hyprland.activeWorkspace;
        var activeId = active && active.id > 0 ? active.id : 1;
        Hyprland.dispatch("movetoworkspace " + activeId + ",address:" + cleanAddr);
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        root._tick++;
        refreshTimer.startRefresh();
    }

    // ─── Native Hyprland Layout Manager ────────────────────────
    property string activeHyprLayout: "dwindle"

    readonly property var layoutPresets: [
        {
            id: "dwindle",
            icon: "\u{f009}", // Grid / Dwindle
            label: "Dwindle",
            desc: "Modo Tiling Automático (Dwindle / Espiral)",
            isMode: true,
            action: function() {
                Hyprland.dispatch("exec hyprctl keyword general:layout dwindle");
                root.activeHyprLayout = "dwindle";
                root.tileAllWindowsOnActiveWorkspace();
            }
        },
        {
            id: "master",
            icon: "\u{f24d}", // Master
            label: "Master",
            desc: "Modo Master (Janela Principal + Coluna Lateral)",
            isMode: true,
            action: function() {
                Hyprland.dispatch("exec hyprctl keyword general:layout master");
                root.activeHyprLayout = "master";
                root.tileAllWindowsOnActiveWorkspace();
            }
        },
        {
            id: "split",
            icon: "\u{f021}", // Rotate / Swap
            label: "Girar Corte",
            desc: "Alternar corte Horizontal/Vertical das janelas (Dwindle)",
            isMode: false,
            action: function() {
                Hyprland.dispatch("layoutmsg togglesplit");
                root._tick++;
                root.refreshTimer.startRefresh();
            }
        },
        {
            id: "tile_all",
            icon: "\u{f0db}", // Columns / Tiles
            label: "Encaixar Todas",
            desc: "Remover flutuantes e encaixar todas no Tiling",
            isMode: false,
            action: function() {
                root.tileAllWindowsOnActiveWorkspace();
            }
        },
        {
            id: "float_cascade",
            icon: "\u{f2d0}", // Float
            label: "Cascata Flutuante",
            desc: "Organizar janelas em Cascata Flutuante limpa",
            isMode: false,
            action: function() {
                root.cascadeAllWindowsOnActiveWorkspace();
            }
        }
    ]

    function tileAllWindowsOnActiveWorkspace() {
        var active = Hyprland.activeWorkspace;
        var activeId = active && active.id > 0 ? active.id : 1;
        var clients = getClientsForWorkspace(activeId);
        for (var i = 0; i < clients.length; i++) {
            var addr = normalizeAddress(clients[i] && clients[i].address ? clients[i].address : "");
            if (addr) {
                Hyprland.dispatch("settiled address:" + addr);
            }
        }
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        root._tick++;
        refreshTimer.startRefresh();
    }

    function cascadeAllWindowsOnActiveWorkspace() {
        var active = Hyprland.activeWorkspace;
        var activeId = active && active.id > 0 ? active.id : 1;
        var clients = getClientsForWorkspace(activeId);
        if (clients.length === 0) return;

        var mon = workspaceMonitorGeometry(clients);
        var winW = Math.round(mon.width * 0.60);
        var winH = Math.round(mon.height * 0.60);
        var baseX = Math.round(mon.x + (mon.width - winW) / 2 - Math.min(4, clients.length - 1) * 16);
        var baseY = Math.round(mon.y + 42);
        var offsetX = 32;
        var offsetY = 28;

        for (var i = 0; i < clients.length; i++) {
            var addr = normalizeAddress(clients[i] && clients[i].address ? clients[i].address : "");
            if (!addr) continue;
            var cx = Math.max(mon.x + 12, baseX + (i % 5) * offsetX);
            var cy = Math.max(mon.y + 36, baseY + (i % 5) * offsetY);
            Hyprland.dispatch("setfloating address:" + addr);
            Hyprland.dispatch("resizewindowpixel exact " + winW + " " + winH + ",address:" + addr);
            Hyprland.dispatch("movewindowpixel exact " + cx + " " + cy + ",address:" + addr);
        }
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        root._tick++;
        refreshTimer.startRefresh();
    }

    function workspaceMonitorGeometry(clients) {
        var fallback = { x: 0, y: 0, width: 1366, height: 768 };
        var mon = null;
        if (clients && clients.length > 0 && clients[0].workspace && clients[0].workspace.monitor)
            mon = clients[0].workspace.monitor;
        if (!mon && Hyprland.focusedMonitor)
            mon = Hyprland.focusedMonitor;
        if (!mon) return fallback;

        var x = Number(mon.x);
        var y = Number(mon.y);
        var w = Number(mon.width);
        var h = Number(mon.height);
        return {
            x: isFinite(x) ? x : fallback.x,
            y: isFinite(y) ? y : fallback.y,
            width: isFinite(w) && w > 0 ? w : fallback.width,
            height: isFinite(h) && h > 0 ? h : fallback.height
        };
    }

    // ─── Main Content ───────────────────────────────────────────
    Item {
        id: overviewContent
        anchors.fill: parent

        // ── Top Toolbar (Search + Layout Switcher + Modes) ────────
        RowLayout {
            id: topToolbar
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: root.isCompactScreen ? 10 : 16
            spacing: DesignTokens.spacingMD
            z: 100

            // Search Bar
            TextField {
                id: overviewSearchField
                placeholderText: "Pesquisar janelas (normais e scratchpads)..."
                font.pixelSize: DesignTokens.fontSizeSM
                font.family: Style.fontUI
                color: ColorScheme.text
                Layout.preferredWidth: root.isCompactScreen ? 250 : 300
                Layout.preferredHeight: root.isCompactScreen ? 36 : 42
                leftPadding: 16
                rightPadding: 16
                background: Rectangle {
                    radius: parent.height / 2
                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.78)
                    border.color: overviewSearchField.activeFocus ? ColorScheme.accent : ColorScheme.glassBorder
                    border.width: 1
                }
                onTextChanged: {
                    root.searchFilter = text;
                    root.searchMatches = root.buildSearchMatches(text);
                    root.searchMatchIndex = 0;
                }
                onAccepted: {
                    root.activateSearchResult(root.searchMatchIndex);
                }
                Keys.onPressed: function(event) {
                    if (!root.searchMatches || root.searchMatches.length <= 0)
                        return;
                    if (event.key === Qt.Key_Down) {
                        root.searchMatchIndex = (root.searchMatchIndex + 1) % root.searchMatches.length;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.searchMatchIndex = (root.searchMatchIndex - 1 + root.searchMatches.length) % root.searchMatches.length;
                        event.accepted = true;
                    }
                }
            }

            // Mode Toggle (Todos 1..10 vs Apenas Ativos)
            Rectangle {
                Layout.preferredHeight: root.isCompactScreen ? 36 : 42
                Layout.preferredWidth: modeRow.width + 20
                radius: height / 2
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.78)
                border.color: ColorScheme.glassBorder
                border.width: 1

                RowLayout {
                    id: modeRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: root.activeOnlyFilter ? "\u{f06e} Apenas Ativos" : "\u{f009} Todos (1-10)"
                        font.family: Style.fontUI
                        font.pixelSize: DesignTokens.fontSizeXS
                        font.weight: Font.DemiBold
                        color: modeMa.containsMouse ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.85)
                    }
                }

                MouseArea {
                    id: modeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.activeOnlyFilter = !root.activeOnlyFilter;
                        root._tick++;
                    }
                }
                ToolTip.visible: modeMa.containsMouse
                ToolTip.text: "Alternar entre exibir todos os 10 workspaces ou apenas os que têm janelas"
                ToolTip.delay: 300
            }

            // Layout Presets Toolbar (Native Hyprland Controls)
            Rectangle {
                id: layoutToolbar
                Layout.preferredHeight: root.isCompactScreen ? 36 : 42
                Layout.preferredWidth: layoutRow.width + 16
                radius: height / 2
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.78)
                border.color: ColorScheme.glassBorder
                border.width: 1

                RowLayout {
                    id: layoutRow
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: root.layoutPresets
                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            readonly property bool isSelectedMode: modelData.isMode && root.activeHyprLayout === modelData.id

                            width: root.isCompactScreen ? 28 : 32
                            height: width
                            radius: width / 2
                            color: isSelectedMode
                                ? ColorScheme.withAlpha(ColorScheme.accent, 0.40)
                                : (layoutMa.containsMouse
                                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.22)
                                    : ColorScheme.withAlpha(ColorScheme.surface, 0.2))
                            border.color: isSelectedMode
                                ? ColorScheme.accent
                                : (layoutMa.containsMouse
                                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.5)
                                    : "transparent")
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: root.isCompactScreen ? 11 : 12
                                color: isSelectedMode || layoutMa.containsMouse
                                    ? ColorScheme.accent
                                    : ColorScheme.withAlpha(ColorScheme.text, 0.75)
                            }

                            MouseArea {
                                id: layoutMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.action()
                            }

                            ToolTip.visible: layoutMa.containsMouse
                            ToolTip.text: modelData.label + "\n• " + modelData.desc
                            ToolTip.delay: 250
                        }
                    }
                }
            }

            // Close Button
            Rectangle {
                Layout.preferredHeight: root.isCompactScreen ? 36 : 42
                Layout.preferredWidth: height
                radius: height / 2
                color: closeMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.red, 0.25) : ColorScheme.withAlpha(ColorScheme.surface, 0.78)
                border.color: closeMa.containsMouse ? ColorScheme.red : ColorScheme.glassBorder
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "\u{f00d}"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: closeMa.containsMouse ? ColorScheme.red : ColorScheme.withAlpha(ColorScheme.text, 0.7)
                }

                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.isOpen = false
                }
                ToolTip.visible: closeMa.containsMouse
                ToolTip.text: "Fechar (Esc)"
                ToolTip.delay: 300
            }
        }

        // ── Search Matches Dropdown ──────────────────────────────
        Rectangle {
            anchors.top: topToolbar.bottom
            anchors.topMargin: DesignTokens.spacingSM
            anchors.horizontalCenter: topToolbar.horizontalCenter
            width: Math.min(parent.width * 0.78, 680)
            height: Math.min(5, root.searchMatches.length) * 40 + DesignTokens.spacingSM * 2
            visible: root.searchFilter.trim() !== "" && root.searchMatches.length > 0
            radius: DesignTokens.radiusMD
            color: ColorScheme.withAlpha(ColorScheme.surface, 0.94)
            border.color: ColorScheme.glassBorder
            border.width: 1
            z: 110

            ListView {
                id: searchMatchList
                anchors.fill: parent
                anchors.margins: DesignTokens.spacingSM
                clip: true
                model: root.searchMatches
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: searchMatchList.width
                    height: 36
                    radius: DesignTokens.radiusSM
                    color: index === root.searchMatchIndex
                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.22)
                        : (searchMatchMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.text, 0.08) : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: DesignTokens.spacingMD
                        anchors.rightMargin: DesignTokens.spacingMD
                        spacing: DesignTokens.spacingSM

                        Text {
                            text: root.getIconForClient(modelData.className)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: ColorScheme.accent
                        }

                        Text {
                            text: modelData.title || modelData.className || "Janela"
                            color: ColorScheme.text
                            font.pixelSize: DesignTokens.fontSizeSM
                            font.family: Style.fontUI
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Bring back to active workspace button (for special windows)
                        Rectangle {
                            visible: modelData.isSpecial
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: bringBackText.implicitWidth + 12
                            radius: 11
                            color: ColorScheme.withAlpha(ColorScheme.mauve, 0.35)

                            Text {
                                id: bringBackText
                                anchors.centerIn: parent
                                text: "󰁞 Trazer p/ WS"
                                color: ColorScheme.mauve
                                font.pixelSize: 9
                                font.family: Style.fontUI
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.moveWindowToActiveWorkspace(modelData.address);
                                    root.isOpen = false;
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: badgeText.implicitWidth + 12
                            radius: 10
                            color: modelData.isSpecial ? ColorScheme.withAlpha(ColorScheme.mauve, 0.3) : ColorScheme.withAlpha(ColorScheme.accent, 0.2)

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: modelData.isSpecial ? modelData.workspaceName : ("WS " + modelData.workspaceId)
                                color: modelData.isSpecial ? ColorScheme.mauve : ColorScheme.accent
                                font.pixelSize: DesignTokens.fontSizeXS
                                font.family: Style.fontUI
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    MouseArea {
                        id: searchMatchMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateSearchResult(index)
                    }
                }
            }
        }

        // ── Workspace Grid Area (All 10 Workspaces with 16:9 aspect) ───
        Item {
            id: gridArea
            anchors.top: topToolbar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: (root.activeSpecialInspector !== "" ? inspectedDrawer.top : specialBar.top)
            anchors.topMargin: root.isCompactScreen ? 6 : 12
            anchors.bottomMargin: root.isCompactScreen ? 6 : 10

            // Centered layout container sized exactly to fit all 10 tiles without overflow
            Item {
                id: gridContainer
                anchors.centerIn: parent
                width: root.gridLayoutInfo.gridWidth
                height: root.gridLayoutInfo.gridHeight

                Repeater {
                    id: wsRepeater
                    model: root.workspaceIds

                    delegate: Rectangle {
                        id: wsTile
                        required property int modelData
                        required property int index

                        readonly property int wsId: modelData
                        readonly property int col: index % root.gridLayoutInfo.columns
                        readonly property int row: Math.floor(index / root.gridLayoutInfo.columns)

                        x: col * (root.gridLayoutInfo.tileWidth + root.gridLayoutInfo.gap)
                        y: row * (root.gridLayoutInfo.tileHeight + root.gridLayoutInfo.gap)
                        width: root.gridLayoutInfo.tileWidth
                        height: root.gridLayoutInfo.tileHeight

                        readonly property var wsObj: {
                            var _t = root._tick;
                            return root.findWorkspace(wsId);
                        }
                        readonly property bool isFocused: {
                            var _t = root._tick;
                            var fw = Hyprland.focusedWorkspace;
                            return fw && fw.id === wsId;
                        }
                        readonly property var wsClients: {
                            var _t = root._tick;
                            return root.getClientsForWorkspace(wsId);
                        }
                        readonly property bool hasWindows: wsClients.length > 0

                        radius: DesignTokens.radiusMD
                        color: {
                            var dragOver = root._dragging && root._isOverTile(wsTile);
                            if (dragOver) return ColorScheme.withAlpha(ColorScheme.accent, 0.32);
                            if (isFocused) return ColorScheme.withAlpha(ColorScheme.accent, 0.16);
                            if (tileHover.containsMouse) return ColorScheme.withAlpha(ColorScheme.text, 0.08);
                            return ColorScheme.withAlpha(ColorScheme.surface, 0.55);
                        }
                        border.color: {
                            var dragOver = root._dragging && root._isOverTile(wsTile);
                            if (dragOver) return ColorScheme.accent;
                            if (isFocused) return ColorScheme.withAlpha(ColorScheme.accent, 0.70);
                            return ColorScheme.withAlpha(ColorScheme.text, 0.12);
                        }
                        border.width: isFocused ? 2 : 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        // Large subtle Workspace Number in background
                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.rightMargin: 10
                            anchors.topMargin: 2
                            text: String(wsTile.wsId)
                            color: ColorScheme.withAlpha(root.categoryColor(wsTile.wsId), 0.12)
                            font.pixelSize: Math.min(54, wsTile.height * 0.45)
                            font.weight: Font.Bold
                            font.family: Style.fontUI
                        }

                        // Top workspace badge
                        RowLayout {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 6
                            spacing: 5
                            z: 20

                            Rectangle {
                                width: 16; height: 16
                                radius: 8
                                color: root.categoryColor(wsTile.wsId)

                                Text {
                                    anchors.centerIn: parent
                                    text: String(wsTile.wsId)
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: ColorScheme.surface
                                }
                            }

                            Text {
                                text: root.wsLabels[wsTile.wsId - 1] || ("WS " + wsTile.wsId)
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                font.family: Style.fontUI
                                color: wsTile.isFocused ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.8)
                            }
                        }

                        // ── Window miniatures inside tile ─────────────────
                        Item {
                            id: windowArea
                            anchors.fill: parent
                            anchors.topMargin: 24
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            anchors.bottomMargin: 6
                            clip: true

                            Repeater {
                                model: wsTile.wsClients

                                delegate: Rectangle {
                                    id: winRect
                                    required property var modelData
                                    required property int index

                                    readonly property var ipcObj: modelData.lastIpcObject || {}
                                    readonly property string clientClass: String(ipcObj["class"] || modelData.appId || "")
                                    readonly property string clientTitle: String(modelData.title || ipcObj.title || "")
                                    readonly property string clientAddress: String(modelData.address || ipcObj.address || "")

                                    readonly property var monitorGeo: {
                                        var m = Hyprland.focusedMonitor;
                                        return { w: m ? Number(m.width) : 1366, h: m ? Number(m.height) : 768 };
                                    }

                                    readonly property var clientAtArray: ipcObj["at"] || [0, 0]
                                    readonly property var clientSizeArray: ipcObj["size"] || [400, 300]
                                    readonly property real clientX: Number(clientAtArray[0] || 0)
                                    readonly property real clientY: Number(clientAtArray[1] || 0)
                                    readonly property real clientW: Number(clientSizeArray[0] || 400)
                                    readonly property real clientH: Number(clientSizeArray[1] || 300)

                                    readonly property real scaleFactor: Math.min(
                                        windowArea.width / monitorGeo.w,
                                        windowArea.height / monitorGeo.h
                                    )

                                    x: Math.max(0, Math.min(windowArea.width - width, clientX * scaleFactor))
                                    y: Math.max(0, Math.min(windowArea.height - height, clientY * scaleFactor))
                                    width: Math.max(26, clientW * scaleFactor)
                                    height: Math.max(18, clientH * scaleFactor)
                                    radius: DesignTokens.radiusSM

                                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.90)
                                    border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.55)
                                    border.width: 1

                                    // Window Drag & Click Handler (Primary Mouse Area)
                                    MouseArea {
                                        id: winMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        property real pressX: 0
                                        property real pressY: 0
                                        property bool isDragging: false
                                        z: 1

                                        onPressed: (mouse) => {
                                            pressX = mouse.x;
                                            pressY = mouse.y;
                                            isDragging = false;
                                        }
                                        onPositionChanged: (mouse) => {
                                            var dx = mouse.x - pressX;
                                            var dy = mouse.y - pressY;
                                            if (!isDragging && Math.sqrt(dx*dx + dy*dy) > 8) {
                                                isDragging = true;
                                                root._dragging = true;
                                                root._dragAddress = winRect.clientAddress;
                                                root._dragClass = winRect.clientClass;
                                                root._dragSourceWs = wsTile.wsId;
                                            }
                                            if (isDragging) {
                                                var globalPos = mapToItem(overviewContent, mouse.x, mouse.y);
                                                root._dragGlobalX = globalPos.x;
                                                root._dragGlobalY = globalPos.y;
                                            }
                                        }
                                        onReleased: (mouse) => {
                                            if (isDragging) {
                                                var globalPos = mapToItem(overviewContent, mouse.x, mouse.y);
                                                root._finishDrag(globalPos.x, globalPos.y);
                                            } else {
                                                if (mouse.button === Qt.RightButton) {
                                                    // Quick Right-click to send to Scratchpad (special:magic)
                                                    var addr = root.normalizeAddress(winRect.clientAddress);
                                                    if (addr) {
                                                        Hyprland.dispatch("movetoworkspace special:magic,address:" + addr);
                                                        Hyprland.refreshToplevels();
                                                        root._tick++;
                                                        root.refreshTimer.startRefresh();
                                                    }
                                                } else {
                                                    Hyprland.dispatch("workspace " + wsTile.wsId);
                                                    var cleanAddr = root.normalizeAddress(winRect.clientAddress);
                                                    if (cleanAddr) Hyprland.dispatch("focuswindow address:" + cleanAddr);
                                                    root.isOpen = false;
                                                }
                                            }
                                            isDragging = false;
                                            root._dragging = false;
                                        }
                                    }

                                    // App Icon
                                    Image {
                                        id: winIconImg
                                        anchors.centerIn: parent
                                        source: winRect.clientClass !== "" ? ("image://icon/" + winRect.clientClass.toLowerCase()) : ""
                                        sourceSize.width: 48
                                        sourceSize.height: 48
                                        width: Math.min(parent.width * 0.55, 28)
                                        height: width
                                        fillMode: Image.PreserveAspectFit
                                        visible: status === Image.Ready && parent.width >= 28 && parent.height >= 20
                                        opacity: 0.90
                                        z: 2
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.getIconForClient(winRect.clientClass)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Math.min(16, Math.min(parent.width, parent.height) * 0.45)
                                        color: ColorScheme.accent
                                        visible: winIconImg.status !== Image.Ready && parent.width >= 24 && parent.height >= 18
                                        z: 2
                                    }

                                    // Quick "Send to Scratchpad" mini button (placed ON TOP with high z-index)
                                    Rectangle {
                                        id: miniBtn
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 1
                                        width: 16; height: 16
                                        radius: 8
                                        color: miniBtnMa.containsMouse ? ColorScheme.mauve : ColorScheme.withAlpha(ColorScheme.mauve, 0.90)
                                        visible: winMouseArea.containsMouse || miniBtnMa.containsMouse
                                        z: 10

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\u{f0d0}"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            color: ColorScheme.surface
                                        }

                                        MouseArea {
                                            id: miniBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var addr = root.normalizeAddress(winRect.clientAddress);
                                                if (addr) {
                                                    Hyprland.dispatch("movetoworkspace special:magic,address:" + addr);
                                                    Hyprland.refreshToplevels();
                                                    root._tick++;
                                                    root.refreshTimer.startRefresh();
                                                }
                                            }
                                        }
                                        ToolTip.visible: miniBtnMa.containsMouse
                                        ToolTip.text: "Mover para Scratchpad (special:magic)"
                                        ToolTip.delay: 200
                                    }

                                    ToolTip.visible: winMouseArea.containsMouse && !miniBtnMa.containsMouse
                                    ToolTip.text: (winRect.clientTitle || winRect.clientClass) + "\n• Clique: Focar Janela\n• Botão Direito: Mover p/ Scratchpad"
                                    ToolTip.delay: 200
                                }
                            }

                            // Empty state
                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                visible: !wsTile.hasWindows
                                opacity: 0.35

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.wsIcons[wsTile.wsId - 1] || "\u{f2d0}"
                                    color: root.categoryColor(wsTile.wsId)
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: wsTile.height < 110 ? 16 : 22
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Vazio"
                                    color: ColorScheme.text
                                    font.pixelSize: 9
                                    font.family: Style.fontUI
                                }
                            }
                        }

                        // Tile Click Handler
                        MouseArea {
                            id: tileHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: -1
                            onClicked: {
                                Hyprland.dispatch("workspace " + wsTile.wsId);
                                root.isOpen = false;
                            }
                        }
                    }
                }
            }
        }

        // ── Inspected Special Workspace Window Tray (Drawer to restore/drag out) ──
        Rectangle {
            id: inspectedDrawer
            anchors.bottom: specialBar.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 6
            width: Math.min(parent.width - 40, Math.max(480, inspectedRow.width + 32))
            height: root.activeSpecialInspector !== "" ? (root.isCompactScreen ? 88 : 96) : 0
            visible: root.activeSpecialInspector !== ""
            radius: DesignTokens.radiusMD
            color: ColorScheme.withAlpha(ColorScheme.surface, 0.94)
            border.color: ColorScheme.mauve
            border.width: 1
            clip: true
            z: 60

            Behavior on height {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Drawer Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "\u{f0d0} Janelas no Scratchpad: " + root.activeSpecialInspector
                        font.family: Style.fontUI
                        font.pixelSize: DesignTokens.fontSizeXS
                        font.weight: Font.Bold
                        color: ColorScheme.mauve
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Arraste para um workspace (1-10) ou clique em 'Trazer'"
                        font.family: Style.fontUI
                        font.pixelSize: 9
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.6)
                    }

                    Rectangle {
                        width: 18; height: 18
                        radius: 9
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.1)
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: ColorScheme.text }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeSpecialInspector = ""
                        }
                    }
                }

                // Window Cards inside the Scratchpad
                RowLayout {
                    id: inspectedRow
                    spacing: DesignTokens.spacingSM

                    Repeater {
                        model: root.inspectedSpecialClients

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            readonly property var ipcObj: modelData.lastIpcObject || {}
                            readonly property string clientClass: String(ipcObj["class"] || modelData.appId || "")
                            readonly property string clientTitle: String(modelData.title || ipcObj.title || "")
                            readonly property string clientAddress: String(modelData.address || ipcObj.address || "")

                            width: Math.min(220, Math.max(140, itemContentRow.width + 16))
                            height: root.isCompactScreen ? 48 : 54
                            radius: DesignTokens.radiusSM
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.8)
                            border.color: ColorScheme.withAlpha(ColorScheme.mauve, 0.6)
                            border.width: 1

                            RowLayout {
                                id: itemContentRow
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6

                                Text {
                                    text: root.getIconForClient(clientClass)
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: ColorScheme.mauve
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: clientTitle || clientClass || "Janela"
                                        color: ColorScheme.text
                                        font.pixelSize: 10
                                        font.family: Style.fontUI
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Restore Button: Move to Active Workspace
                                    Rectangle {
                                        Layout.preferredHeight: 18
                                        Layout.preferredWidth: restoreBtnText.implicitWidth + 10
                                        radius: 9
                                        color: restoreMa.containsMouse ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.accent, 0.25)

                                        Text {
                                            id: restoreBtnText
                                            anchors.centerIn: parent
                                            text: "󰁞 Trazer p/ WS Atual"
                                            color: restoreMa.containsMouse ? ColorScheme.surface : ColorScheme.accent
                                            font.pixelSize: 8
                                            font.family: Style.fontUI
                                            font.weight: Font.Bold
                                        }

                                        MouseArea {
                                            id: restoreMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.moveWindowToActiveWorkspace(clientAddress);
                                            }
                                        }
                                    }
                                }
                            }

                            // Window Drag Handler (Drag from Scratchpad to any of the 10 Workspaces)
                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                cursorShape: Qt.OpenHandCursor
                                property real pressX: 0
                                property real pressY: 0
                                property bool isDragging: false

                                onPressed: (mouse) => {
                                    pressX = mouse.x;
                                    pressY = mouse.y;
                                    isDragging = false;
                                }
                                onPositionChanged: (mouse) => {
                                    var dx = mouse.x - pressX;
                                    var dy = mouse.y - pressY;
                                    if (!isDragging && Math.sqrt(dx*dx + dy*dy) > 6) {
                                        isDragging = true;
                                        root._dragging = true;
                                        root._dragAddress = clientAddress;
                                        root._dragClass = clientClass;
                                        root._dragSourceWs = root.activeSpecialInspector;
                                    }
                                    if (isDragging) {
                                        var globalPos = mapToItem(overviewContent, mouse.x, mouse.y);
                                        root._dragGlobalX = globalPos.x;
                                        root._dragGlobalY = globalPos.y;
                                    }
                                }
                                onReleased: (mouse) => {
                                    if (isDragging) {
                                        var globalPos = mapToItem(overviewContent, mouse.x, mouse.y);
                                        root._finishDrag(globalPos.x, globalPos.y);
                                    }
                                    isDragging = false;
                                    root._dragging = false;
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.inspectedSpecialClients.length === 0
                        text: "Nenhuma janela neste scratchpad."
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.5)
                        font.pixelSize: 10
                        font.family: Style.fontUI
                    }
                }
            }
        }

        // ── Special Workspaces / Scratchpads Drawer ──────────────
        Rectangle {
            id: specialBar
            anchors.bottom: clockArea.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: root.isCompactScreen ? 4 : 8
            width: Math.min(parent.width - 40, spContentRow.width + 24)
            height: root.isCompactScreen ? 38 : 44
            radius: height / 2
            color: ColorScheme.withAlpha(ColorScheme.surface, 0.82)
            border.color: ColorScheme.withAlpha(ColorScheme.mauve, 0.40)
            border.width: 1
            z: 50

            RowLayout {
                id: spContentRow
                anchors.centerIn: parent
                spacing: DesignTokens.spacingSM

                // Scratchpad Drawer Title
                RowLayout {
                    spacing: 6
                    Text {
                        text: "\u{f0d0}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: ColorScheme.mauve
                    }
                    Text {
                        text: "Scratchpads:"
                        font.family: Style.fontUI
                        font.pixelSize: DesignTokens.fontSizeXS
                        font.weight: Font.Bold
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.85)
                    }
                }

                // Special Workspace Chips (Magic, SP1, Notes, Chat, OpenCode, etc.)
                Repeater {
                    id: spRepeater
                    model: root.specialWorkspaces

                    delegate: Rectangle {
                        id: spChip
                        required property var modelData
                        required property int index

                        readonly property string spName: modelData.name
                        readonly property string spLabel: modelData.label
                        readonly property string spIcon: modelData.icon
                        readonly property int winCount: modelData.clientCount
                        readonly property bool hasWins: winCount > 0
                        readonly property bool isInspected: root.activeSpecialInspector === spName

                        width: spChipRow.width + 16
                        height: root.isCompactScreen ? 28 : 32
                        radius: height / 2
                        color: {
                            var dragOver = root._dragging && root._isOverTile(spChip);
                            if (dragOver) return ColorScheme.withAlpha(ColorScheme.mauve, 0.50);
                            if (isInspected) return ColorScheme.withAlpha(ColorScheme.mauve, 0.35);
                            if (spChipMa.containsMouse) return ColorScheme.withAlpha(ColorScheme.mauve, 0.25);
                            return hasWins ? ColorScheme.withAlpha(ColorScheme.mauve, 0.15) : ColorScheme.withAlpha(ColorScheme.surface, 0.35);
                        }
                        border.color: {
                            var dragOver = root._dragging && root._isOverTile(spChip);
                            if (dragOver) return ColorScheme.mauve;
                            if (isInspected) return ColorScheme.mauve;
                            return hasWins ? ColorScheme.withAlpha(ColorScheme.mauve, 0.60) : ColorScheme.withAlpha(ColorScheme.text, 0.12);
                        }
                        border.width: isInspected ? 2 : 1

                        RowLayout {
                            id: spChipRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: spChip.spIcon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ColorScheme.mauve
                            }
                            Text {
                                text: spChip.spLabel
                                font.family: Style.fontUI
                                font.pixelSize: DesignTokens.fontSizeXS
                                font.weight: Font.DemiBold
                                color: ColorScheme.text
                            }

                            // Window Count Badge (if > 0)
                            Rectangle {
                                visible: spChip.hasWins
                                width: 14; height: 14
                                radius: 7
                                color: ColorScheme.mauve

                                Text {
                                    anchors.centerIn: parent
                                    text: String(spChip.winCount)
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                    color: ColorScheme.surface
                                }
                            }
                        }

                        MouseArea {
                            id: spChipMa
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    // Right click toggles the special workspace directly on Hyprland desktop
                                    var rawName = spChip.spName.replace("special:", "");
                                    Hyprland.dispatch("togglespecialworkspace " + rawName);
                                    root.isOpen = false;
                                } else {
                                    // Left click inspects the windows inside this scratchpad in Overview drawer
                                    if (root.activeSpecialInspector === spChip.spName) {
                                        root.activeSpecialInspector = "";
                                    } else {
                                        root.activeSpecialInspector = spChip.spName;
                                    }
                                }
                            }
                        }

                        ToolTip.visible: spChipMa.containsMouse
                        ToolTip.text: "Scratchpad " + spChip.spName + "\n• Clique: Ver janelas / Trazer de volta\n• Botão Direito: Alternar no Hyprland\n• Arraste janelas aqui para mover p/ cá"
                        ToolTip.delay: 200
                    }
                }
            }
        }

        // ── Clock Area (bottom center, compact & elegant) ─────────
        Item {
            id: clockArea
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            height: root.isCompactScreen ? 46 : 70

            Column {
                anchors.centerIn: parent
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(new Date(), "HH:mm")
                    color: ColorScheme.text
                    font.pixelSize: root.isCompactScreen ? 28 : 40
                    font.weight: Font.Light
                    font.family: Style.fontUI
                    font.letterSpacing: -1
                    opacity: 0.92
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(new Date(), "dddd, dd 'de' MMMM")
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.60)
                    font.pixelSize: root.isCompactScreen ? 9 : DesignTokens.fontSizeXS
                    font.family: Style.fontUI
                }
            }

            Timer {
                interval: 1000
                running: root.isOpen
                repeat: true
                onTriggered: root._tick++
            }
        }

        // ── Keyboard Shortcuts ───────────────────────────────────
        Shortcut { sequence: "1"; enabled: root.isOpen; onActivated: { Hyprland.dispatch("workspace 1"); root.isOpen = false; } }
        Shortcut { sequence: "2"; enabled: root.isOpen; onActivated: { Hyprland.dispatch("workspace 2"); root.isOpen = false; } }
        Shortcut { sequence: "3"; enabled: root.isOpen; onActivated: { Hyprland.dispatch("workspace 3"); root.isOpen = false; } }
        Shortcut { sequence: "4"; enabled: root.isOpen; onActivated: { Hyprland.dispatch("workspace 4"); root.isOpen = false; } }
        Shortcut { sequence: "5"; enabled: root.isOpen; onActivated: { Hyprland.dispatch("workspace 5"); root.isOpen = false; } }
        Shortcut { sequence: "6"; enabled: root.isOpen; onActivated: { Hyprland.dispatch("workspace 6"); root.isOpen = false; } }
        Shortcut { sequence: "7"; enabled: root.isOpen; onActivated: { Hyprland.dispatch("workspace 7"); root.isOpen = false; } }
        Shortcut { sequence: "8"; enabled: root.isOpen; onActivated: { Hyprland.dispatch("workspace 8"); root.isOpen = false; } }
        Shortcut { sequence: "9"; enabled: root.isOpen; onActivated: { Hyprland.dispatch("workspace 9"); root.isOpen = false; } }
        Shortcut { sequence: "0"; enabled: root.isOpen; onActivated: { Hyprland.dispatch("workspace 10"); root.isOpen = false; } }
        Shortcut { sequence: "Escape"; enabled: root.isOpen; onActivated: root.isOpen = false }
    }
}
