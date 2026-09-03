import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"
import "../../shared"
import "../../services"
import "components"
import "./BarAutoHideUtils.js" as BarAutoHideUtils
/**
 * Bar - Floating glassmorphic top bar (end4/Caelestia style).
 */
PanelWindow {
    id: bar
    screen: bar.screenData

    anchors.top: true
    anchors.left: true
    anchors.right: true
    // Extra spacingSM above glass gives the "floating" look (same as dock's bottom margin)
    implicitHeight: bar.shouldAutoHide ? 2 : ((bar.compactMode ? DesignTokens.barCompactHeight : DesignTokens.barExpandedHeight) + DesignTokens.spacingSM)
    Behavior on implicitHeight {
        enabled: !bar.reducedEffects
        NumberAnimation { duration: bar.compactMode ? 140 : DesignTokens.barDockSyncDurationMs; easing.type: Easing.InOutCubic }
    }

    color: "transparent"
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-bar"
    
    // Exclusive zone: reserva o espaço total da barra quando visível, libera quando escondida
    // Usamos valores fixos aqui para evitar que as janelas do sistema "pulem" durante a animação da altura.
    WlrLayershell.exclusiveZone: bar.shouldAutoHide ? 0 : (bar.compactMode ? DesignTokens.barCompactHeight : DesignTokens.barExpandedHeight)

    // ─── Variants model injection ───────────────────────────────
    required property var modelData
    property var screenData: modelData

    // ─── Processes ────────────────────────────────────────────
    CommandRunner { id: barCommandRunner }

    // ─── Connected overlays ─────────────────────────────────────
    required property var launcherInstance
    required property var overviewInstance
    property var exposeInstance: null
    required property var calendarInstance
    required property var settingsStore
    required property var notificationCenter
    required property var mediaPopup
    required property var weatherPopup
    required property var utilityHub
    required property var audioPopup
    required property var networkPopup
    required property var batteryPopup
    required property var sessionPopup
    required property var systemMonitorPopup
    required property var errorPopup
    required property var contextPopup
    required property var nixMonitorPopup
    required property var quickNotesPopup
    required property var usbPopup
    required property var volumeMixerPopup
    required property var clipboardPopup
    required property var productivityPopup
    required property var contextData
    required property var binaryStatus
    required property bool healthChecked
    required property bool shellDegraded

    // ─── State ──────────────────────────────────────────────────
    readonly property bool autoHideEnabled: FeatureFlags.barAutoHide
    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion
    readonly property color bgSurface: ColorScheme.panelBg
    readonly property color accent:    ColorScheme.accent
    readonly property color fgMain:    ColorScheme.foreground
    readonly property bool compactMode: FeatureFlags.barCompactMode
    readonly property bool dndVisualActive: FeatureFlags.barDndVisualMode
        && !!(bar.notificationCenter && bar.notificationCenter.muted === true)

    readonly property bool launcherPopupOpen: ShellController.isPopupOpen(bar.launcherInstance)
    readonly property bool overviewPopupOpen: ShellController.isPopupOpen(bar.overviewInstance)
    readonly property bool anyOtherPopupOpen: ShellController.anyBarPopupOpen(bar)

    // ─── Intelligent Auto-Hide Logic (Snippet Style) ──────────
    
    property bool isHovered: barRevealZone.containsMouse || barHoverArea.containsMouse
    property bool overviewHover: false

    onOverviewPopupOpenChanged: if (!overviewPopupOpen) overviewHover = false

    property real barExclusiveZone: (bar.compactMode ? DesignTokens.barCompactHeight : DesignTokens.barExpandedHeight) * barRevealOpacity
    Behavior on barExclusiveZone {
        enabled: !bar.reducedEffects
        NumberAnimation { duration: DesignTokens.barDockSyncDurationMs; easing.type: Easing.InOutCubic }
    }

    // Small tick counter — used to force re-evaluation of the reactive binding
    // whenever Hyprland emits focus/workspace/toplevel events. Some Hyprland
    // objects are updated in-place (same JS object) which doesn't always
    // trigger deep bindings, so we increment this counter from Connections.
    property int hyprEventTick: 0
    // Enable/disable verbose auto-hide debugging logs at runtime
    property bool autoHideDebug: false
    property bool _refreshWorkspacesPending: false

    function requestVisibilityRefresh(refreshWorkspaces) {
        if (refreshWorkspaces === true)
            _refreshWorkspacesPending = true;

        visibilityRefreshTimer.restart();
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            bar.requestVisibilityRefresh(false);
        }
        function onRawEvent(event) {
            var n = event && event.name ? String(event.name) : "";
            var isWindowEvent = n.indexOf("window") >= 0 && n.indexOf("title") < 0;
            var isWorkspaceEvent = n.indexOf("workspace") >= 0 || n === "activespecial";
            var isFloatingOrFullscreen = n.indexOf("floating") >= 0 || n.indexOf("fullscreen") >= 0;
        if (isWindowEvent || isWorkspaceEvent || isFloatingOrFullscreen) {
            bar.requestVisibilityRefresh(isWorkspaceEvent);
        }
        if (n === "focusedworkspace") {
            bar.requestVisibilityRefresh(true);
        }
        }
    }

    Timer {
        id: hyprRefreshTimer
        interval: 48
        repeat: false
        onTriggered: {
            try {
                if (bar._refreshWorkspacesPending)
                    Hyprland.refreshWorkspaces();
                Hyprland.refreshToplevels();
            } catch (e) {}

            bar._refreshWorkspacesPending = false;
            bar.hyprEventTick++;
            bar.updateAutoHideTimer();
        }
    }

    Timer {
        id: hyprSettleTimer
        interval: 80
        repeat: false
        onTriggered: {
            bar.hyprEventTick++;
            bar.updateAutoHideTimer();
        }
    }

    Timer {
        id: visibilityRefreshTimer
        interval: FeatureFlags.lowPowerUiMode ? 180 : 120
        repeat: false
        onTriggered: {
            hyprRefreshTimer.restart();
            hyprSettleTimer.restart();
        }
    }

    readonly property bool hiddenByWindow: {
        // O _tick força o QML a reavaliar sempre que o Hyprland emitir um evento
        var _tick = bar.hyprEventTick;
        if (!bar.autoHideEnabled || bar.isHovered || bar.anyOtherPopupOpen)
            return false;
        var focusedWs = Hyprland.focusedWorkspace;
        var expectedBarHeight = bar.compactMode ? DesignTokens.barCompactHeight : DesignTokens.barExpandedHeight;
        var toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        var monName = bar.screenData ? bar.screenData.name : "";
        return BarAutoHideUtils.shouldHideByWindow(focusedWs, toplevels, monName, expectedBarHeight);
    }

    property bool _autoHideConfirmed: false

    Timer {
        id: autoHideTimer
        interval: DesignTokens.autohideDelayMs
        repeat: false
        onTriggered: bar._autoHideConfirmed = true
    }

    function updateAutoHideTimer() {
        if (!bar.autoHideEnabled || bar.isHovered || bar.anyOtherPopupOpen) {
            autoHideTimer.stop();
            bar._autoHideConfirmed = false;
            return;
        }

        // Se houver uma janela colidindo, escondemos imediatamente ao sair do hover (agilidade)
        if (bar.hiddenByWindow) {
            bar._autoHideConfirmed = true;
            autoHideTimer.stop();
        } else {
            // Se NÃO houver janela colidindo, a barra deve ficar visível
            autoHideTimer.stop();
            bar._autoHideConfirmed = false;
        }
    }

    Component.onCompleted: {
        updateAutoHideTimer();
        bar.requestVisibilityRefresh(true);
    }

    onHiddenByWindowChanged: {
        updateAutoHideTimer();
    }

    onIsHoveredChanged: {
        updateAutoHideTimer();
        if (bar.autoHideDebug) console.log("[Bar][hover] isHovered=", bar.isHovered);
    }

    onAnyOtherPopupOpenChanged: {
        updateAutoHideTimer();
    }

    onAutoHideEnabledChanged: {
        updateAutoHideTimer();
    }

    // keep this; it drives the reveal animation

    readonly property bool shouldAutoHide: {
        if (!autoHideEnabled) return false;
        if (isHovered || anyOtherPopupOpen) return false;
        return hiddenByWindow || _autoHideConfirmed;
    }

    // ─── Animations ─────────────────────────────────────────────
    property real barRevealOpacity: shouldAutoHide ? 0.0 : 1.0
    Behavior on barRevealOpacity {
        enabled: !bar.reducedEffects
        NumberAnimation { duration: DesignTokens.barDockSyncDurationMs; easing.type: Easing.InOutCubic }
    }

    onShouldAutoHideChanged: {
        if (bar.autoHideDebug) {
            console.log("[Bar][shouldAutoHideChanged] ->", bar.shouldAutoHide);
            dumpAutoHideState("[Bar][onShouldAutoHideChanged]");
        }
    }

    onCompactModeChanged: {
        if (bar.autoHideDebug) dumpAutoHideState("[Bar][compactModeChanged]");
    }

    function _toggleLoaderPopup(loader) {
        ShellController.togglePopup(bar, loader);
    }

    function toggleCompactMode() {
        var next = !FeatureFlags.barCompactMode;
        FeatureFlags.barCompactMode = next;
        if (bar.settingsStore && bar.settingsStore.set) {
            try { bar.settingsStore.set("barCompactMode", next); } catch (e) {}
        }
    }

    // Toggle auto-hide at runtime (called by middle-click on menu button)
    function toggleAutoHideMode() {
        var next = !FeatureFlags.barAutoHide;
        FeatureFlags.barAutoHide = next;
        if (bar.settingsStore && bar.settingsStore.set) {
            try { bar.settingsStore.set("barAutoHide", next); } catch (e) {}
        }
        if (bar.autoHideDebug) console.log("[Bar] toggleAutoHideMode ->", next);
    }

    // Dump current auto-hide state (verbose) to logs for debugging
    function dumpAutoHideState(prefix) {
        if (!bar.autoHideDebug) return;
        prefix = prefix || "[Bar][state]";
        var a = Hyprland.activeToplevel || null;
        var addr = "<none>";
        var aFloating = "n/a";
        var aFullscreen = "n/a";
        var aAt = "n/a";
        var aWs = "n/a";
        var aMon = "n/a";
        if (a && a.workspace) {
            addr = (a.lastIpcObject && a.lastIpcObject.address) || a.address || "<unk>";
            aFloating = !!a.floating;
            aFullscreen = !!a.fullscreen;
            aAt = a.at ? (String(a.at.x) + "," + String(a.at.y)) : "n/a";
            aWs = a.workspace ? String(a.workspace.id) : "n/a";
            aMon = a.workspace && a.workspace.monitor ? String(a.workspace.monitor.name) : "n/a";
        }
        var vals = Hyprland.toplevels ? Hyprland.toplevels.values : null;
        var toplevelCount = vals ? vals.length : 0;
        console.log(prefix,
            "autoHideEnabled=", bar.autoHideEnabled,
            "FeatureFlags.barAutoHide=", FeatureFlags.barAutoHide,
            "hiddenByWindow=", bar.hiddenByWindow,
            "isHovered=", bar.isHovered,
            "anyOtherPopupOpen=", bar.anyOtherPopupOpen,
            "shouldAutoHide=", bar.shouldAutoHide,
            "hyprEventTick=", bar.hyprEventTick,
            "activeToplevel=", addr,
            "floating=", aFloating,
            "fullscreen=", aFullscreen,
            "at=", aAt,
            "ws=", aWs,
            "monitor=", aMon,
            "toplevelCount=", toplevelCount,
            "bar.implicitHeight=", bar.implicitHeight,
            "bar.height=", bar.height
        );
    }

    // Also log when the hypr tick updates (Hyprland events)
    onHyprEventTickChanged: {
        dumpAutoHideState("[Bar][hyprTick]");
    }

    // ─── Interaction Areas ──────────────────────────────────────
    // Zona de reveal: fica SEMPRE ancorada no topo do PanelWindow.
    // Quando a barra some (topMargin negativo no barContainer), esta área
    // ainda existe no topo e captura o hover para revelar a barra.
    MouseArea {
        id: barRevealZone
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        // Reduzido para 2px quando escondida para exigir precisão no topo da tela.
        height: bar.shouldAutoHide ? 2 : (DesignTokens.barRevealStripHeight + 4)
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        // Sempre habilitada quando autoHide está ativo
        enabled: bar.autoHideEnabled
        z: 100
    }

    // ─── Floating Glass Background ──────────────────────────────
    // Reveal strip (visible when bar is auto-hidden)
    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.25
        height: 2
        radius: 1
        color: ColorScheme.withAlpha(ColorScheme.accent, DesignTokens.revealStripOpacity)
        visible: bar.shouldAutoHide
        opacity: bar.shouldAutoHide ? 0.6 : 0.0
        Behavior on opacity {
            enabled: !bar.reducedEffects
            NumberAnimation { duration: 200 }
        }
        z: 50
    }

    Item {
        id: barContainer
        anchors.left: parent.left
        anchors.right: parent.right
        height: (bar.compactMode ? DesignTokens.barCompactHeight : DesignTokens.barExpandedHeight)

        // Ancorado na base: conforme a implicitHeight da janela cresce, a barra "desce"
        anchors.bottom: parent.bottom
        
        anchors.leftMargin: bar.compactMode ? DesignTokens.radiusMD : DesignTokens.radiusLG
        anchors.rightMargin: bar.compactMode ? DesignTokens.radiusMD : DesignTokens.radiusLG

        opacity: bar.barRevealOpacity
        scale: bar.shouldAutoHide ? 0.985 : 1.0
        transformOrigin: Item.Top
        Behavior on scale {
            enabled: !bar.reducedEffects
            NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
        }

        MouseArea {
            id: barHoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled: bar.autoHideEnabled
            z: 10
        }

        // Glass panel
        Rectangle {
            id: glassPanel
            anchors.fill: parent
            radius: DesignTokens.radiusLG
            color: bar.dndVisualActive
                ? ColorScheme.blend(bar.bgSurface, ColorScheme.red, 0.06)
                : bar.bgSurface
            border.color: bar.dndVisualActive
                ? ColorScheme.withAlpha(ColorScheme.red, 0.20)
                : ColorScheme.outlineVariant
            border.width: 1
            layer.enabled: !bar.shouldAutoHide && !bar.reducedEffects
            layer.smooth: false

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }

        // Shadow
        Rectangle {
            anchors.fill: glassPanel
            anchors.topMargin: 2
            radius: glassPanel.radius

            color: Qt.rgba(0, 0, 0, 0.18)
            z: -1
        }

        // ─── Center Cluster (Fixed in horizontal center of screen) ──
        RowLayout {
            id: centerCluster
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: bar.compactMode ? DesignTokens.spacingSM : DesignTokens.barCenterSpacing
            z: 2

            BarMediaStatus {
                id: barMediaStatusWidget
                visible: FeatureFlags.showCenterMedia && !bar.compactMode && !FeatureFlags.focusMode && hasMedia && (isPlaying || isOpen || retainOnPause)
                Layout.preferredWidth: implicitWidth
                Layout.maximumWidth: 200
                Layout.alignment: Qt.AlignVCenter
                accentColor: bar.accent
                textColor: bar.fgMain
                popupInstance: bar.mediaPopup
                anyPopupOpen: bar.anyOtherPopupOpen
            }

            BarNotificationStatus {
                visible: FeatureFlags.showCenterNotifications
                Layout.alignment: Qt.AlignVCenter
                accentColor: bar.accent
                textColor: bar.fgMain
                popupInstance: bar.notificationCenter
                anyPopupOpen: bar.anyOtherPopupOpen
            }

            Clock {
                id: barClock
                Layout.alignment: Qt.AlignVCenter
                visible: FeatureFlags.showCenterClock
                calendarInstance: bar.calendarInstance
                accentColor: bar.accent
                textColor: bar.fgMain
                compact: bar.compactMode

                WheelHandler {
                    onWheel: (event) => {
                        let dir = event.angleDelta.y > 0 ? "+5%" : "5%-";
                        barCommandRunner.exec(["brightnessctl", "s", dir]);
                    }
                }
            }

            BarWeatherStatus {
                visible: FeatureFlags.showCenterWeather && !FeatureFlags.focusMode
                Layout.alignment: Qt.AlignVCenter
                accentColor: bar.accent
                textColor: bar.fgMain
                popupInstance: bar.weatherPopup
                anyPopupOpen: bar.anyOtherPopupOpen
            }

            UtilityHubStatus {
                visible: FeatureFlags.showCenterUtilityHub && !FeatureFlags.focusMode
                Layout.alignment: Qt.AlignVCenter
                accentColor: bar.accent
                textColor: bar.fgMain
                popupInstance: bar.utilityHub
                anyPopupOpen: bar.anyOtherPopupOpen
            }
        }

        // ─── Left Section (Constrained between screen left and centerCluster) ──
        Item {
            id: leftContainer
            anchors.left: parent.left
            anchors.right: centerCluster.left
            anchors.leftMargin: bar.compactMode ? DesignTokens.radiusMD : DesignTokens.radiusLG
            anchors.rightMargin: DesignTokens.spacingMD
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            clip: true

            RowLayout {
                anchors.fill: parent
                spacing: bar.compactMode ? DesignTokens.spacingMD : DesignTokens.barLeftSpacing

                PillWidget {
                    id: launcherButton
                    Layout.alignment: Qt.AlignVCenter

                    readonly property bool launcherOpen: ShellController.isPopupOpen(bar.launcherInstance)

                    iconText: "\u{f313}"
                    iconFontFamily: "JetBrainsMono Nerd Font"
                    iconFontSize: bar.compactMode ? 16 : 18
                    iconColor: bar.accent
                    checked: launcherOpen
                    popupOpen: launcherOpen
                    anyPopupOpen: bar.anyOtherPopupOpen

                    mouseArea.acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    mouseArea.onClicked: (mouse) => {
                        _realHover = false;
                        if (mouse.button === Qt.RightButton) {
                            bar.toggleCompactMode();
                            return;
                        }
                        if (mouse.button === Qt.MiddleButton) {
                            bar.toggleAutoHideMode();
                            return;
                        }
                        bar._toggleLoaderPopup(launcherInstance);
                    }
                }


                WorkspaceIndicator {
                    Layout.alignment: Qt.AlignVCenter
                    screenData: bar.screenData
                    overviewInstance: bar.overviewInstance
                    accentColor: bar.accent
                    occupiedColor: ColorScheme.withAlpha(bar.fgMain, 0.45)
                    inactiveColor: ColorScheme.withAlpha(bar.fgMain, 0.15)
                }

                BarOverviewButton {
                    Layout.alignment: Qt.AlignVCenter
                    overviewInstance: bar.overviewInstance
                    exposeInstance: bar.exposeInstance
                    accentColor: bar.accent
                    textColor: bar.fgMain
                    compact: bar.compactMode
                    anyPopupOpen: bar.anyOtherPopupOpen
                }

                BarTaskbar {
                    id: barTaskbarWidget
                    visible: FeatureFlags.dockInBar
                    screenData: bar.screenData
                    compact: bar.compactMode
                    accentColor: bar.accent
                    textColor: bar.fgMain
                    Layout.alignment: Qt.AlignVCenter
                }

                FocusedApp {
                    id: focusedAppWidget
                    screenData: bar.screenData
                    visible: true
                    compact: bar.compactMode
                    mediaActive: barMediaStatusWidget.visible
                    Layout.preferredWidth: implicitWidth
                    Layout.maximumWidth: DesignTokens.barFocusedAppMaxWidth
                    Layout.alignment: Qt.AlignVCenter
                    accentColor: bar.accent
                    textColor: bar.fgMain
                }

                Item { Layout.fillWidth: true }
            }
        }

        // ─── Right Section (Constrained between centerCluster and screen right) ──
        Item {
            id: rightContainer
            anchors.right: parent.right
            anchors.left: centerCluster.right
            anchors.rightMargin: bar.compactMode ? DesignTokens.radiusMD : DesignTokens.radiusLG
            anchors.leftMargin: DesignTokens.spacingMD
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            clip: true

            RightBarModules {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                height: parent.height
                visible: FeatureFlags.showRightBarModules
                accentColor: bar.accent
                textColor: bar.fgMain
                anyPopupOpen: bar.anyOtherPopupOpen
                systemMonitorPopup: bar.systemMonitorPopup
                networkPopup: bar.networkPopup
                audioPopup: bar.audioPopup
                batteryPopup: bar.batteryPopup
                sessionPopup: bar.sessionPopup
                errorPopup: bar.errorPopup
                contextPopup: bar.contextPopup
                clipboardPopup: bar.clipboardPopup
                nixMonitorPopup: bar.nixMonitorPopup
                usbPopup: bar.usbPopup
                contextData: bar.contextData
                binaryStatus: bar.binaryStatus
                healthChecked: bar.healthChecked
                shellDegraded: bar.shellDegraded
            }
        }
    }

}
