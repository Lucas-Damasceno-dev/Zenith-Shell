import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../core"
import "../../services"

/**
 * Dock — Floating glassmorphic bottom dock (end4/Caelestia style).
 *
 * Mirrors the Bar's visual language: layered glass, inner glow, drop shadow,
 * reveal strip and intelligent auto-hide driven by Hyprland toplevel events.
 * Magnification uses a smooth Gaussian curve + parabolic rise for macOS-like hover zoom.
 */
PanelWindow {
    id: dock
    screen: dock.screenData

    required property var modelData
    property var screenData: modelData

    // ── Dimensions ───────────────────────────────────────────
    readonly property int dockHeight: 60
    readonly property int dockItemSize: 46
    readonly property int dockPadH: DesignTokens.spacingLG
    readonly property int dockHiddenThickness: 1
    property int dockMarginBottom: _hyprGapsOut > 0 ? _hyprGapsOut : DesignTokens.spacingSM

    // ── Dynamic gap sync with Hyprland ───────────────────────
    property int _hyprGapsOut: 0

    Process {
        id: _gapSyncProc
        command: ["hyprctl", "-j", "getoption", "general:gaps_out"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(text || "{}");
                    var val = (obj && obj.int !== undefined) ? parseInt(obj.int) : NaN;
                    if (!isNaN(val) && val >= 0) dock._hyprGapsOut = val;
                } catch (e) {}
            }
        }
    }



    // Extra dockHeight above glass provides space for icons to rise during magnification
    implicitHeight: dockHiddenThickness + dockMarginBottom + (dockHeight * dockRevealOpacity)
    Behavior on implicitHeight {
        enabled: !dock.reducedEffects
        NumberAnimation { duration: DesignTokens.barDockSyncDurationMs; easing.type: Easing.InOutCubic }
    }

    // ── Layer Shell Config ────────────────────────────────────
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-dock"
    WlrLayershell.keyboardFocus: _keyboardNavActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: dock.shouldAutoHide ? 0 : (dockHeight + dockMarginBottom)

    // ── Keyboard Navigation ─────────────────────────────────
    property bool _keyboardNavActive: false
    property int _keyboardNavIndex: 0

    // Listen for Super+Alt+D via Hyprland dispatcher bind
    Connections {
        target: DockService
        function onKeyboardNavRequested() {
            dock._keyboardNavActive = true;
            dock._keyboardNavIndex = 0;
        }
    }

    anchors { left: true; right: true; bottom: true; top: false }
    color: "transparent"
    aboveWindows: true

    property var dockItems: DockService.mergedItems

    // ── Auto-hide Logic (mirrors Bar) ────────────────────────
    readonly property bool autoHideEnabled: FeatureFlags.barAutoHide
    property int hyprEventTick: 0
    property bool _refreshWorkspacesPending: false
    readonly property int hyprRefreshIntervalMs: FeatureFlags.lowPowerUiMode ? 150 : 96

    function requestVisibilityRefresh(refreshWorkspaces) {
        if (refreshWorkspaces === true)
            _refreshWorkspacesPending = true;

        hyprRefreshTimer.restart();
    }

    // ── Peek mode ──────────────────────────────────────────────
    property string _peekAppId: ""
    property bool _peekActive: false
    property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion || dock._fullscreenActive || dock.shouldAutoHide

    function _activatePeek(appId) {
        if (!appId || _peekActive) return;
        _peekActive = true;
        _peekAppId = appId;
        var toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        var batch = [];
        for (var i = 0; i < toplevels.length; i++) {
            var tl = toplevels[i];
            if (!tl || !tl.lastIpcObject || !tl.lastIpcObject.address) continue;
            var cls = String(tl.appId || "").toLowerCase();
            var op = (cls === appId.toLowerCase()) ? "1.0" : "0.3";
            batch.push("dispatch setopacity address:" + tl.lastIpcObject.address + " " + op);
        }
        if (batch.length > 0) {
            Hyprland.dispatch("batch " + batch.join(" ; "));
        }
    }

    function _deactivatePeek() {
        if (!_peekActive) return;
        _peekActive = false;
        _peekAppId = "";
        var toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        var batch = [];
        for (var i = 0; i < toplevels.length; i++) {
            var tl = toplevels[i];
            if (tl && tl.lastIpcObject && tl.lastIpcObject.address) {
                batch.push("dispatch setopacity address:" + tl.lastIpcObject.address + " 1.0");
            }
        }
        if (batch.length > 0) {
            Hyprland.dispatch("batch " + batch.join(" ; "));
        }
    }

    // ── Submap tracking (mirrors FocusedApp) ─────────────────
    property string activeSubmap: "default"
    readonly property bool inSubmap: activeSubmap !== "" && activeSubmap !== "default"

    property bool _itemHoverActive: false

    Timer {
        id: itemHoverResetTimer
        interval: 96
        repeat: false
        onTriggered: dock._itemHoverActive = false
    }

    function setItemHover(active) {
        if (active) {
            _itemHoverActive = true;
            itemHoverResetTimer.stop();
        } else {
            itemHoverResetTimer.restart();
        }
    }

    readonly property bool isHovered: (dockRevealZone && dockRevealZone.containsMouse) ||
                                      (dockHoverTracker && dockHoverTracker.hovered) ||
                                      mouseInDock ||
                                      _itemHoverActive ||
                                      (tooltipWindow && tooltipWindow.showTooltip) ||
                                      (contextMenu && contextMenu.showMenu) ||
                                      (previewWindow && previewWindow.showPreview)


    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            dock.requestVisibilityRefresh(false);
        }
        function onRawEvent(event) {
            var n = event && event.name ? String(event.name) : "";
            var isWindowEvent = n.indexOf("window") >= 0 && n.indexOf("title") < 0;
            
            if (n === "openwindow" || n === "activewindowv2" || n === "activewindow") {
                // Force clear stuck hovers when windows open or change focus
                dock._itemHoverActive = false;
            }

            var isWorkspaceEvent = n.indexOf("workspace") >= 0 || n === "activespecial";
            var isFloatingOrFullscreen = n.indexOf("floating") >= 0 || n.indexOf("fullscreen") >= 0;
            if (isWindowEvent || isWorkspaceEvent || isFloatingOrFullscreen) {
                dock.requestVisibilityRefresh(isWorkspaceEvent);
            }
            if (n === "focusedworkspace") {
                dock.requestVisibilityRefresh(true);
            }
            // Submap tracking
            if (n === "submap") {
                var raw = String(event.data || "").trim();
                dock.activeSubmap = raw === "" ? "default" : raw;
            }
            // Re-sync gaps_out immediately when Hyprland config is reloaded
            if (n === "configreloaded") {
                _gapSyncProc.running = true;
            }
        }
    }

    Timer {
        id: hyprRefreshTimer
        interval: dock.hyprRefreshIntervalMs
        repeat: false
        onTriggered: {
            try {
                if (dock._refreshWorkspacesPending)
                    Hyprland.refreshWorkspaces();
                Hyprland.refreshToplevels();
            } catch (e) {}

            dock._refreshWorkspacesPending = false;
            dock.hyprEventTick++;
        }
    }

    readonly property bool hiddenByWindow: {
        var _tick = dock.hyprEventTick;
        dock._fullscreenActive = false;
        if (!autoHideEnabled || isHovered)
            return false;

        var focusedWs = Hyprland.focusedWorkspace;
        if (!focusedWs) return false;

        var expectedDockH = dock.dockHeight + dock.dockMarginBottom + 20; // Extra buffer
        var toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        var monName = dock.screenData ? dock.screenData.name : "";
        var hidden = false;
        var fullscreenFound = false;

        for (var i = 0; i < toplevels.length; i++) {
            var win = toplevels[i];
            if (!win || !win.workspace || String(win.workspace.id) !== String(focusedWs.id)) continue;

            var wMon = win.workspace.monitor;
            if (!wMon || wMon.name !== monName) continue;

            var isMin = win.lastIpcObject && win.lastIpcObject.minimized;
            if (isMin) continue;

            var isFullscreen = win.fullscreen || (win.lastIpcObject && win.lastIpcObject.fullscreen);
            if (isFullscreen)
                fullscreenFound = true;

            var winX = -1, winY = -1, winW = 0, winH = 0;
            if (win.at) { winX = win.at.x; winY = win.at.y; }
            else if (win.lastIpcObject && win.lastIpcObject.at) { winX = win.lastIpcObject.at[0]; winY = win.lastIpcObject.at[1]; }
            if (win.size) { winW = win.size.width; winH = win.size.height; }
            else if (win.lastIpcObject && win.lastIpcObject.size) { winW = win.lastIpcObject.size[0]; winH = win.lastIpcObject.size[1]; }

            if (winX !== -1 && winY !== -1) {
                var monY = wMon.y !== undefined ? wMon.y : 0;
                var monHeight = wMon.height !== undefined ? wMon.height : 1080;
                var dockTop = monY + monHeight - expectedDockH;
                if (isFullscreen || !((win.lastIpcObject && win.lastIpcObject.floating === true) || win.floating === true)) {
                    hidden = true;
                } else if (winY + winH >= dockTop) {
                    hidden = true;
                }
            } else if (isFullscreen || !((win.lastIpcObject && win.lastIpcObject.floating === true) || win.floating === true)) {
                hidden = true;
            }
        }

        dock._fullscreenActive = fullscreenFound;
        return hidden;
    }

    // Track whether dock is hidden specifically due to fullscreen (for GPU throttle)
    property bool _fullscreenActive: false

    readonly property bool shouldAutoHide: {
        if (!autoHideEnabled) return false;
        if (isHovered) return false;
        return _autoHideConfirmed;
    }

    property real dockRevealOpacity: shouldAutoHide ? 0.0 : 1.0
    Behavior on dockRevealOpacity {
        enabled: !dock.reducedEffects
        NumberAnimation { duration: DesignTokens.barDockSyncDurationMs; easing.type: Easing.InOutCubic }
    }

    // Grace period: only hide after hiddenByWindow stays true for a debounce
    property bool _autoHideConfirmed: false
    Timer {
        id: autoHideDebounce
        interval: 64; repeat: false
        onTriggered: dock._autoHideConfirmed = dock.hiddenByWindow
    }
    onHiddenByWindowChanged: {
        if (hiddenByWindow) autoHideDebounce.restart();
        else { autoHideDebounce.stop(); _autoHideConfirmed = false; }
    }

    onShouldAutoHideChanged: {
        if (!shouldAutoHide) {
            dock._oledDimmed = false;
            dock._oledOpacity = 1.0;
        }
    }

    Timer {
        id: startupTimer
        interval: 1000; repeat: true; running: false
        property int cnt: 0
        onTriggered: {
            dock.requestVisibilityRefresh(false);
            cnt++;
            if (cnt > 2) { stop(); cnt = 0; }
        }
    }

    Component.onCompleted: {
        _gapSyncProc.running = true;
        dock.requestVisibilityRefresh(true);
        startupTimer.restart();
    }

    // ── Magnification Logic ──────────────────────────────────
    property real mouseXInRow: -1000
    property bool mouseInDock: dockHoverTracker.hovered

    // Gaussian magnification curve with static slot spacing to eliminate layout feedback loops
    function calculateStaticZoom(mouseX, slotIndex) {
        if (mouseX < -500) return 1.0;
        var itemCenter = slotIndex * (dock.dockItemSize + DesignTokens.spacingXS) + dock.dockItemSize / 2;
        var dist = Math.abs(itemCenter - mouseX);
        var sigma = 80;
        var maxScale = 1.65;
        return 1.0 + (maxScale - 1.0) * Math.exp(-(dist * dist) / (2 * sigma * sigma));
    }

    function calculateZoom(mouseX, itemX, itemWidth) {
        if (mouseX < -500) return 1.0;
        var itemCenter = itemX + itemWidth / 2;
        var dist = Math.abs(itemCenter - mouseX);
        var sigma = 80; 
        var maxScale = 1.65; 
        return 1.0 + (maxScale - 1.0) * Math.exp(-(dist * dist) / (2 * sigma * sigma));
    }

    function calculateRise(zoom) {
        return (zoom - 1.0) * 24;
    }

    function shouldShowPinnedSeparator(itemIndex) {
        if (!dock.dockItems || itemIndex < 0 || itemIndex >= dock.dockItems.length)
            return false;
        var current = dock.dockItems[itemIndex];
        if (!current || current.pinned !== true)
            return false;
        for (var i = itemIndex + 1; i < dock.dockItems.length; i++) {
            var next = dock.dockItems[i];
            if (!next)
                continue;
            return next.pinned !== true;
        }
        return false;
    }

    function requestPinReorder(appId, dropGlobalX) {
        if (!appId) return;
        var pinned = DockService.pinnedAppIds || [];
        var isCurrentlyPinned = pinned.indexOf(appId) >= 0;
        var fromIndex = pinned.indexOf(appId);

        var targetIndex = 0;
        var lastPinnedX = -1;
        for (var i = 0; i < appRepeater.count; i++) {
            var dockItem = dock.dockItems[i];
            if (!dockItem) continue;
            var delegate = appRepeater.itemAt(i);
            if (!delegate || !delegate.mapToGlobal) continue;
            
            if (dockItem.pinned) {
                lastPinnedX = delegate.mapToGlobal(delegate.width, 0).x;
                if (dockItem.appId !== appId) {
                    var center = delegate.mapToGlobal(delegate.width / 2, delegate.height / 2);
                    if (dropGlobalX > center.x) targetIndex++;
                }
            }
        }

        if (!isCurrentlyPinned) {
            if (dropGlobalX <= lastPinnedX + 40 || pinned.length === 0) {
                DockService.pinApp(appId);
                var newPinned = DockService.pinnedAppIds || [];
                var newIndex = newPinned.indexOf(appId);
                if (newIndex >= 0 && targetIndex !== newIndex) {
                    DockService.reorderPins(newIndex, targetIndex);
                }
            }
        } else {
            if (targetIndex !== fromIndex) {
                DockService.reorderPins(fromIndex, targetIndex);
            }
        }
    }

    // ── Interaction Areas ──────────────────────────────────────
    // Reveal zone — always at bottom edge for hover reveal
    MouseArea {
        id: dockRevealZone
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.95 // Large horizontal hit area
        height: shouldAutoHide ? Math.max(dockHeight + dockMarginBottom, 24) : (dockHeight + dockMarginBottom)
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: autoHideEnabled
        z: 100
    }

    // ── Reveal Strip (accent pill with subtle glow, visible when auto-hidden) ─
    Rectangle {
        id: revealStrip
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.18
        height: 2
        radius: 1
        color: ColorScheme.withAlpha(ColorScheme.accent, DesignTokens.revealStripOpacity)
        visible: dock.shouldAutoHide
        opacity: dock.shouldAutoHide ? 0.7 : 0.0
        Behavior on opacity {
            enabled: !dock.reducedEffects
            NumberAnimation { duration: DesignTokens.revealDurationMs }
        }
        z: 50

        // Subtle breathing glow (only when strip is visible on screen)
        SequentialAnimation on opacity {
            running: dock.shouldAutoHide && revealStrip.visible && !dock.reducedEffects
            loops: Animation.Infinite
            NumberAnimation { to: 0.9; duration: 2000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.5; duration: 2000; easing.type: Easing.InOutSine }
        }
    }

    // ── Dock Container (anchored top — slides out when hidden) ─
    Item {
        id: dockContainer
        anchors.left: parent.left
        anchors.right: parent.right
        height: dockHeight + dockMarginBottom
        anchors.bottom: parent.bottom  // icons overflow upward into transparent area
        focus: dock._keyboardNavActive
            opacity: dock.dockRevealOpacity * dock._oledOpacity
            scale: 0.985 + (0.015 * dock.dockRevealOpacity)
            transformOrigin: Item.Bottom

        Behavior on opacity {
            enabled: !dock.reducedEffects
            NumberAnimation { duration: DesignTokens.barDockSyncDurationMs; easing.type: Easing.InOutCubic }
        }

        Behavior on scale {
            enabled: !dock.reducedEffects
            NumberAnimation { duration: DesignTokens.barDockSyncDurationMs; easing.type: Easing.InOutCubic }
        }

            Keys.onPressed: function(event) {
            if (!dock._keyboardNavActive) return;
            if (event.key === Qt.Key_Left) {
                dock._keyboardNavIndex = Math.max(0, dock._keyboardNavIndex - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                dock._keyboardNavIndex = Math.min(dock.dockItems.length - 1, dock._keyboardNavIndex + 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (dock.dockItems[dock._keyboardNavIndex])
                    DockService.launchOrFocus(dock.dockItems[dock._keyboardNavIndex]);
                dock._keyboardNavActive = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                dock._keyboardNavActive = false;
                event.accepted = true;
            }
        }

        Item {
            id: dockHoverLayer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: dockHiddenThickness + dockMarginBottom + (dockHeight * dock.dockRevealOpacity)
            z: 11

            HoverHandler {
                id: dockHoverTracker

                onPointChanged: {
                    if (hovered) {
                        var dockContentPos = dockContent.mapToItem(null, 0, 0);
                        dock.mouseXInRow = point.position.x - dockContentPos.x;
                    } else {
                        dock.mouseXInRow = -1000;
                    }
                }

                onHoveredChanged: {
                    if (!hovered)
                        dock.mouseXInRow = -1000;
                }
            }
        }

        // ── Drop Shadow (below glass) ────────────────────────
        Rectangle {
            anchors.fill: glassPanel
            anchors.topMargin: 3
            radius: glassPanel.radius
            color: Qt.rgba(0, 0, 0, 0.20)
            z: -1
            opacity: 0.16 * dock.dockRevealOpacity
        }

        // ── Glass Panel (main background) ────────────────────
        Rectangle {
            id: glassPanel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: dockMarginBottom

            width: Math.min(dockContent.width + dockPadH * 2, dock.width * 0.92)
            property bool _overflowing: dockContent.width + dockPadH * 2 > dock.width * 0.92
            clip: _overflowing
            height: dock.dockHeight
            radius: DesignTokens.radiusXL
            color: ColorScheme.glassDock
            border.width: dock.inSubmap ? 2 : DesignTokens.borderDefault
            border.color: dock.inSubmap
                ? ColorScheme.withAlpha(ColorScheme.peach, 0.7)
                : ColorScheme.withAlpha(ColorScheme.glassBorder, 0.5)

            Behavior on border.color {
                enabled: !dock.reducedEffects
                ColorAnimation { duration: 200 }
            }
            Behavior on border.width {
                enabled: !dock.reducedEffects
                NumberAnimation { duration: 150 }
            }

            // Blur behind (Hyprland will handle this via namespace blur if configured)
            // But we can also add a subtle inner shadow/glow
            
            scale: 0.92 + (0.08 * dock.dockRevealOpacity)
            transformOrigin: Item.Bottom
            Behavior on scale {
                enabled: !dock.reducedEffects
                NumberAnimation { duration: DesignTokens.revealDurationMs + 90; easing.type: Easing.InOutCubic }
            }

            layer.enabled: !dock.shouldAutoHide && !dock._fullscreenActive && !dock.reducedEffects
            layer.smooth: false

            // Inner glow — 1px highlight at top (matching Bar)
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1
                radius: parent.radius
                color: Qt.rgba(1, 1, 1, 0.05)
            }

            // Frosted glass noise overlay (cached static texture)
            Image {
                id: noiseOverlay
                anchors.fill: parent
                opacity: 0.035
                z: 1
                visible: !dock.reducedEffects
                source: RuntimePaths.quickshellDir + "/shared/icons/dock-grain.svg"
                fillMode: Image.Tile
                asynchronous: true
                cache: true
                smooth: false
                sourceSize.width: 64
                sourceSize.height: 64
            }

            // ── Fade edges on overflow ──────────────────────────
            Rectangle {
                visible: glassPanel._overflowing
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 24
                z: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: ColorScheme.glassDock }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle {
                visible: glassPanel._overflowing
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 24
                z: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: ColorScheme.glassDock }
                }
            }

            // ── Content Row ──────────────────────────────────
            Row {
                id: dockContent
                anchors.centerIn: parent
                spacing: DesignTokens.spacingXS

                // ── 1. Utilities (if enabled) ─────────────────
                DockUtilities {
                    id: dockUtilities
                    visible: FeatureFlags.dockShowUtilities
                    baseSize: dock.dockItemSize
                    magnification: dock.calculateStaticZoom(dock.mouseXInRow, 0)
                    riseOffset: dock.calculateRise(magnification)
                    onHovered: function(isHov) { dock.setItemHover(isHov); }
                }

                DockSeparator {
                    visible: FeatureFlags.dockShowUtilities && dock.dockItems.length > 0
                    separatorHeight: dock.dockItemSize * 0.45
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ── 2. App icons (Pinned & Running) ───────────
                Repeater {
                    id: appRepeater
                    model: dock.dockItems

                    delegate: Item {
                        id: itemDelegate
                        property int idx: index
                        property var itemInfo: dock.dockItems[idx]
                        
                        readonly property real mag: dock.calculateStaticZoom(dock.mouseXInRow, idx + (FeatureFlags.dockShowUtilities ? 1 : 0))

                        property bool showSeparatorAfter: dock.shouldShowPinnedSeparator(index)

                        // Dynamic width with smooth animation
                        width: (dock.dockItemSize * mag) + (showSeparatorAfter ? DesignTokens.spacingLG : DesignTokens.spacingSM)
                        Behavior on width {
                            enabled: !dock.reducedEffects
                            NumberAnimation { duration: 72; easing.type: Easing.OutCubic }
                        }
                        
                        height: dock.dockHeight
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                        DockItem {
                            id: dockItemComp
                            itemData: itemDelegate.itemInfo
                            itemIndex: itemDelegate.idx
                            baseSize: dock.dockItemSize
                            reducedEffects: dock.reducedEffects
                            
                            magnification: itemDelegate.mag
                            riseOffset: dock.calculateRise(magnification)
                            anchors.bottom: parent ? parent.bottom : undefined

                            onClicked: {
                                tooltipWindow.showTooltip = false;
                                DockService.launchOrFocus(itemDelegate.itemInfo);
                            }
                            onMiddleClicked: {
                                tooltipWindow.showTooltip = false;
                                DockService.launchNewInstance(itemDelegate.itemInfo);
                            }
                            onRightClicked: function(mx, my, shiftHeld) {
                                contextMenu.itemData = itemDelegate.itemInfo;
                                contextMenu.shiftHeld = shiftHeld;
                                var mapped = dockItemComp.mapToItem(null, mx, my);
                                contextMenu.globalPos = Qt.point(mapped.x, 0);
                                contextMenu.showMenu = true;
                            }
                            onHovered: function(isHov) {
                                dock.setItemHover(isHov);
                                if (isHov) {
                                    tooltipWindow.text = itemDelegate.itemInfo ? (itemDelegate.itemInfo.name || itemDelegate.itemInfo.appId) : "";
                                    tooltipWindow.extraInfo = "";
                                    var mapped = dockItemComp.mapToItem(null, dockItemComp.width / 2, 0);
                                    tooltipWindow.globalPos = Qt.point(mapped.x, 0);
                                    tooltipWindow.showTooltip = true;

                                    // Prepare preview and stat fetch with debounce
                                    if (itemDelegate.itemInfo && itemDelegate.itemInfo.running && itemDelegate.itemInfo.toplevels.length > 0) {
                                        _previewHoverItem = itemDelegate.itemInfo;
                                        _previewHoverPos = Qt.point(mapped.x, 0);
                                        previewDelayTimer.restart();
                                    }
                                } else {
                                    tooltipWindow.showTooltip = false;
                                    previewDelayTimer.stop();
                                    _previewHoverItem = null;
                                }
                            }
                            onWheelScrolled: function(delta) {
                                if (itemDelegate.itemInfo) {
                                    // Volume scroll for audio-active apps
                                    if (itemDelegate.itemInfo.audioActive) {
                                        DockService.adjustAppVolumes(itemDelegate.itemInfo.appId, delta < 0 ? "5%+" : "5%-");
                                    } else {
                                        DockService.focusNextInstance(itemDelegate.itemInfo.appId, delta);
                                    }
                                }
                            }
                            onPeekRequested: function(appId, active) {
                                if (active)
                                    dock._activatePeek(appId);
                                else
                                    dock._deactivatePeek();
                            }
                            onReorderRequested: function(globalX, appId) {
                                dock.requestPinReorder(appId, globalX);
                            }
                        }

                        DockSeparator {
                            visible: itemDelegate.showSeparatorAfter
                            anchors.right: parent.right
                            anchors.rightMargin: 1
                            anchors.verticalCenter: parent.verticalCenter
                            separatorHeight: dock.dockItemSize * 0.45
                        }
                    }
                }

                // ── 3. Separator before Accessories ──────────
                DockSeparator {
                    visible: (dockScratchpad.visible || dockRecentFiles.visible || dockMprisPill.visible || dockTrash.visible) && dock.dockItems.length > 0
                    separatorHeight: dock.dockItemSize * 0.45
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ── 4. Scratchpad badge ───────────────────────
                DockScratchpad {
                    id: dockScratchpad
                    visible: FeatureFlags.dockShowScratchpad && DockService.scratchpadCount > 0
                    baseSize: dock.dockItemSize
                    magnification: dock.calculateStaticZoom(dock.mouseXInRow, dock.dockItems.length + 1)
                    riseOffset: dock.calculateRise(magnification)
                    onHovered: function(isHov) { dock.setItemHover(isHov); }
                }

                // ── 5. Recent Files ───────────────────────────
                DockRecentFiles {
                    id: dockRecentFiles
                    visible: FeatureFlags.dockShowRecentFiles
                    baseSize: dock.dockItemSize
                    magnification: dock.calculateStaticZoom(dock.mouseXInRow, dock.dockItems.length + 2)
                    riseOffset: dock.calculateRise(magnification)
                    onHovered: function(isHov) { dock.setItemHover(isHov); }
                }

                // ── 6. MPRIS Pill ─────────────────────────────
                DockMprisPill {
                    id: dockMprisPill
                    visible: FeatureFlags.dockShowMpris && hasMedia
                    baseSize: dock.dockItemSize
                    magnification: 1.0
                }

                // ── 7. Trash ──────────────────────────────────
                DockTrash {
                    id: dockTrash
                    visible: FeatureFlags.dockShowTrash
                    baseSize: dock.dockItemSize
                    magnification: dock.calculateStaticZoom(dock.mouseXInRow, dock.dockItems.length + 3)
                    riseOffset: dock.calculateRise(magnification)
                    onHovered: function(isHov) { dock.setItemHover(isHov); }
                }

            } // End dockContent

        } // End glassPanel
    } // End dockContainer

    // ── CPU/RAM stat process ─────────────────────────────────
    TimedProcess {
        id: _statProc
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = (text || "").trim().split(/\s+/);
                if (parts.length >= 2) {
                    tooltipWindow.extraInfo = "CPU: " + parts[0] + "%  RAM: " + parts[1] + "%";
                }
            }
        }
    }

    // ── Peek mode process ────────────────────────────────────
    Process { id: _peekProc }

    // ── Preview Hover Delay ─────────────────────────────────
    property var _previewHoverItem: null
    property point _previewHoverPos: Qt.point(0, 0)

    Timer {
        id: previewDelayTimer
        interval: DesignTokens.tooltipDelayMs
        repeat: false
        onTriggered: {
            if (dock._previewHoverItem && dock._previewHoverItem.running) {
                if (dock._previewHoverItem.toplevels && dock._previewHoverItem.toplevels.length > 0) {
                    var tl = dock._previewHoverItem.toplevels[0];
                    var pid = tl && tl.lastIpcObject ? tl.lastIpcObject.pid : 0;
                    if (pid > 0) {
                        _statProc.exec(["ps", "-p", String(pid), "-o", "%cpu,%mem", "--no-headers"]);
                    }
                }
                previewWindow.itemData = dock._previewHoverItem;
                previewWindow.globalPos = dock._previewHoverPos;
                previewWindow.showPreview = true;
                tooltipWindow.showTooltip = false;
            }
        }
    }

    // ── Child Windows ────────────────────────────────────────
    DockTooltip { id: tooltipWindow }
    DockContextMenu { id: contextMenu }
    DockPreview { id: previewWindow }

    // ── OLED Dimming (auto-dim after 3min idle) ──────────────
    property real _oledOpacity: 1.0
    property bool _oledDimmed: false

    Timer {
        id: oledDimTimer
        interval: 180000; repeat: false
        running: !dock.shouldAutoHide && !dock.isHovered
        onTriggered: {
            dock._oledDimmed = true;
            dock._oledOpacity = 0.20;
        }
    }

    // Wake on any hover
    onIsHoveredChanged: {
        if (isHovered) {
            _oledDimmed = false;
            _oledOpacity = 1.0;
            dock.requestVisibilityRefresh(false);
        }
        if (isHovered) oledDimTimer.restart();
    }

    Behavior on _oledOpacity {
        enabled: !dock.reducedEffects
        NumberAnimation { duration: 800; easing.type: Easing.InOutSine }
    }

    // ── Ambient Backlight (diffuse glow under glass) ─────────
    Rectangle {
        id: ambientBacklight
        anchors.horizontalCenter: dockContainer.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dockMarginBottom - 4
        width: glassPanel.width * 0.6
        height: 8
        radius: 4
        color: ColorScheme.withAlpha(ColorScheme.accent, 0.12)
        visible: true
        opacity: dock.dockRevealOpacity * 0.8
        z: -2
        Behavior on opacity {
            enabled: !dock.reducedEffects
            NumberAnimation { duration: DesignTokens.revealDurationMs + 40; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            enabled: !dock.reducedEffects
            ColorAnimation { duration: 500 }
        }
    }

    Connections {
        target: EventBus.dock
        function onToggleWorkspaceIsolation(payload) {
            DockService.workspaceIsolation = !DockService.workspaceIsolation;
            DockService.refresh();
        }
    }
}
