import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../core"
import "../services"

import "../services/ScreenshotService.js" as ScreenshotService
import "../services/HealthService.js" as HealthService

PopupWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    showScrim: false
    glassRadius: 0
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0
    originY: 0.0
    originX: 0.5
    slideY: 10

    property real anchorX: -1
    property real popupMargin: DesignTokens.spacingLG
    property bool outsideCloseEnabled: false

    property string activeGroup: ""
    readonly property bool expanded: activeGroup !== ""

    // Bindings to UtilityService singleton
    readonly property bool isRecording: UtilityService.isRecording
    readonly property bool isPaused: UtilityService.isPaused
    readonly property bool presentationMode: UtilityService.presentationMode
    readonly property string recordingMode: UtilityService.recordingMode
    readonly property string recordingFile: UtilityService.recordingFile
    readonly property bool micEnabled: UtilityService.micEnabled
    readonly property bool systemEnabled: UtilityService.systemEnabled
    readonly property string lastColorHex: UtilityService.lastColorHex
    readonly property bool hasColor: UtilityService.hasColor
    property var binaryStatus: UtilityService.binaryStatus
    property bool healthChecked: UtilityService.healthChecked
    property var settingsStore
    readonly property bool anonymizeCapture: UtilityService.anonymizeCapture
    property bool lensConfirmArmed: false
    readonly property string screenshotFormat: UtilityService.screenshotFormat
    readonly property string screenshotMode: UtilityService.screenshotMode
    readonly property int screenshotDelaySec: UtilityService.screenshotDelaySec
    readonly property string videoContainer: UtilityService.videoContainer
    readonly property string videoCodec: UtilityService.videoCodec
    readonly property int videoFps: UtilityService.videoFps
    readonly property int videoQuality: UtilityService.videoQuality
    readonly property string screenshotDestination: UtilityService.screenshotDestination
    readonly property string videoDestination: UtilityService.videoDestination
    readonly property string fileTemplate: UtilityService.fileTemplate
    readonly property bool copyPathThumb: UtilityService.copyPathThumb
    readonly property string lensProvider: UtilityService.lensProvider
    readonly property string ocrLanguage: UtilityService.ocrLanguage
    readonly property string homeDir: RuntimePaths.homeDir
    readonly property int recordingDurationSec: UtilityService.recordingDurationSec
    readonly property string recordingDurationLabel: UtilityService.recordingDurationLabel
    property string lastErrorMessage: UtilityService.lastError
    readonly property var recentCaptures: UtilityService.recentCaptures
    readonly property var colorHistory: UtilityService.colorHistory
    readonly property string activeDisplayProfile: UtilityService.activeDisplayProfile
    readonly property string activeDisplayResolution: UtilityService.activeDisplayResolution
    readonly property var availableResolutions: UtilityService.availableResolutions
    readonly property int connectedMonitorsCount: UtilityService.connectedMonitorsCount
    readonly property string internalMonitorName: UtilityService.internalMonitorName
    readonly property string externalMonitorName: UtilityService.externalMonitorName
    readonly property var monitorList: UtilityService.monitorList

    readonly property string scriptsDir: RuntimePaths.quickshellScriptsDir
    readonly property var mainGroups: [
        { key: "camera", icon: "\u{f030}", tooltip: "Capturas de Tela" },
        { key: "video", icon: "\u{f03d}", tooltip: "Gravação de Vídeo" },
        { key: "display", icon: "\u{f108}", tooltip: "Monitores & Projeção" },
        { key: "tools", icon: "\u{f0ad}", tooltip: "Ferramentas & Cores" }
    ]
    readonly property var groupActions: root.submenuFor(root.activeGroup)
    readonly property bool utilityAvailable: UtilityService.utilityAvailable

    onIsOpenChanged: {
        if (isOpen) {
            outsideCloseEnabled = false;
            closeEnableTimer.restart();
            if (!activeGroup) activeGroup = (isRecording ? "video" : "camera");
            UtilityService.loadPreferences();
            UtilityService.refreshHistory();
            UtilityService.refreshRecordingStatus();
            UtilityService.refreshDisplayProfile();
            UtilityService.refreshColorHistory();
            UtilityService.refreshStatus();
            ScreenFilterService.refresh();
            lensConfirmArmed = false;
            lastErrorMessage = "";
        } else {
            outsideCloseEnabled = false;
            lensConfirmArmed = false;
        }
    }

    function submenuFor(groupKey) {
        if (groupKey === "camera") {
            return [
                { key: "shot-active-mode", icon: "\u{f030}", tooltip: "Capturar Agora (" + (screenshotMode === "screen" ? "Tela/Monitor" : (screenshotMode === "region" ? "Região" : (screenshotMode === "window" ? "Janela" : "Todas as Telas"))) + ")" },
                { key: "shot-screen", icon: "\u{f108}", tooltip: "Capturar Tela / Monitor (Clique na tela desejada)" },
                { key: "shot-all", icon: "\u{f065}", tooltip: "Todas as Telas (Combinadas)" },
                { key: "shot-region", icon: "\u{f125}", tooltip: "Recorte de Região (Arrastar seleção)" },
                { key: "shot-window", icon: "\u{f2d0}", tooltip: "Janela Ativa" },
                { key: "shot-annotate", icon: "\u{f044}", tooltip: "Capturar e Anotar (Swappy)" },
                { key: "cycle-shot-mode", icon: "\u{f0db}", tooltip: "Modo Padrão: " + screenshotMode.toUpperCase() },
                { key: "cycle-shot-format", icon: "\u{f1c5}", tooltip: "Formato: " + screenshotFormat.toUpperCase() },
                { key: "cycle-shot-delay", icon: "\u{f017}", tooltip: "Temporizador: " + (screenshotDelaySec > 0 ? (screenshotDelaySec + "s") : "Instantâneo") },
                { key: "cycle-shot-destination", icon: "\u{f07c}", tooltip: "Destino: " + (screenshotDestination.indexOf("Screenshots") >= 0 ? "Screenshots" : (screenshotDestination.indexOf("Captures") >= 0 ? "Captures" : "Downloads")) },
                { key: "cycle-template", icon: "\u{f15b}", tooltip: "Template de Nome: " + fileTemplate },
                { key: "toggle-copy-path-thumb", icon: "\u{f0c5}", tooltip: copyPathThumb ? "Clipboard: Apenas Copiar (Sem salvar)" : "Clipboard: Salvar Arquivo + Copiar" }
            ];
        }
        if (groupKey === "video") {
            return [
                { key: "rec-full", icon: "\u{f03d}", tooltip: isRecording ? "Parar gravação" : "Gravar tela cheia" },
                { key: "rec-region", icon: "\u{f124}", tooltip: isRecording ? "Parar gravação" : "Gravar região" },
                { key: "rec-gif", icon: "\u{f1c8}", tooltip: isRecording ? "Parar gravação" : "Gravar GIF" },
                { key: "toggle-pause", icon: isPaused ? "\u{f04b}" : "\u{f04c}", tooltip: isPaused ? "Retomar gravação" : "Pausar gravação" },
                { key: "toggle-mic", icon: "\u{f130}", tooltip: micEnabled ? "Mic ligado" : "Mic desligado" },
                { key: "toggle-system", icon: "\u{f028}", tooltip: systemEnabled ? "Áudio sistema ligado" : "Áudio sistema desligado" },
                { key: "cycle-video-container", icon: "\u{f03d}", tooltip: "Container: " + videoContainer.toUpperCase() },
                { key: "cycle-video-codec", icon: "\u{f2db}", tooltip: "Codec: " + videoCodec },
                { key: "cycle-video-destination", icon: "\u{f07c}", tooltip: "Destino vídeo" },
                { key: "cycle-video-fps", icon: "\u{f017}", tooltip: "FPS: " + videoFps },
                { key: "cycle-video-quality", icon: "\u{f201}", tooltip: "Qualidade: CRF " + videoQuality }
            ];
        }
        if (groupKey === "tools") {
            return [
                { key: "color", icon: "\u{f1fb}", tooltip: "Color Picker (Hyprpicker)" },
                { key: "ocr", icon: "\u{f15c}", tooltip: (anonymizeCapture ? "Snip OCR (Anonimizado)" : "Snip OCR") + " [" + ocrLanguage + "]" },
                { key: "lens", icon: "\u{f030}", tooltip: lensConfirmArmed ? "Clique novamente para confirmar upload" : "Visual Lens (" + lensProvider + ")" },
                { key: "toggle-presentation", icon: "\u{f26c}", tooltip: presentationMode ? "Modo Apresentação ON" : "Modo Apresentação" },
                { key: "toggle-anonymize", icon: "\u{f5fd}", tooltip: anonymizeCapture ? "Anonimização ON" : "Anonimização OFF" },
                { key: "cycle-lens-provider", icon: "\u{f0ac}", tooltip: "Provider: " + lensProvider },
                { key: "cycle-ocr-lang", icon: "\u{f1ab}", tooltip: "Idioma OCR: " + ocrLanguage },
                { key: "copy-color-rgb", icon: "\u{f53f}", tooltip: "Copiar RGB da última cor" },
                { key: "copy-color-hsl", icon: "\u{f53f}", tooltip: "Copiar HSL da última cor" }
            ];
        }
        if (groupKey === "display") {
            return [
                { key: "display-extend-right", icon: "\u{f065}", tooltip: "Estender (Direita)" },
                { key: "display-extend-left", icon: "\u{f060}", tooltip: "Estender (Esquerda)" },
                { key: "display-extend-above", icon: "\u{f062}", tooltip: "Estender (Acima)" },
                { key: "display-mirror", icon: "\u{f0c5}", tooltip: "Espelhar telas (Mirror)" },
                { key: "display-internal", icon: "\u{f109}", tooltip: "Apenas Laptop" },
                { key: "display-external", icon: "\u{f26c}", tooltip: "Apenas TV / Monitor Externo" },
                { key: "display-identify", icon: "\u{f06e}", tooltip: "Identificar Telas (OSD)" },
                { key: "cycle-display-res", icon: "\u{f021}", tooltip: "Alternar Resolução (" + (root.activeDisplayResolution || "Auto") + ")" },
                { key: "display-night-light", icon: "\u{f186}", tooltip: ScreenFilterService.nightLightActive ? ("Luz Noturna ON (" + ScreenFilterService.nightLightValue + "%)") : "Luz Noturna (Filtro Azul)" },
                { key: "display-grayscale", icon: "\u{f042}", tooltip: ScreenFilterService.grayscaleActive ? ("Modo Leitura ON (" + ScreenFilterService.grayscaleValue + "%)") : "Modo Leitura (Monocromático)" }
            ];
        }
        return [];
    }

    function iconColorForAction(actionKey) {
        if (!actionAvailable(actionKey)) {
            return ColorScheme.withAlpha(ColorScheme.text, 0.32);
        }
        if (actionKey === "toggle-mic") {
            return micEnabled ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.72);
        }
        if (actionKey === "toggle-system") {
            return systemEnabled ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.72);
        }
        if (actionKey === "toggle-anonymize") {
            return anonymizeCapture ? ColorScheme.blue : ColorScheme.withAlpha(ColorScheme.text, 0.72);
        }
        if (actionKey === "toggle-presentation") {
            return presentationMode ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.72);
        }
        if (actionKey === "toggle-copy-path-thumb") {
            return copyPathThumb ? ColorScheme.teal : ColorScheme.withAlpha(ColorScheme.text, 0.72);
        }
        if (actionKey === "toggle-pause") {
            return isPaused ? ColorScheme.yellow : ColorScheme.accent;
        }
        if ((actionKey.indexOf("rec-") === 0) && isRecording) {
            return ColorScheme.red;
        }
        if (actionKey === "color" && hasColor) {
            return lastColorHex;
        }
        if (actionKey === "display-night-light") {
            return ScreenFilterService.nightLightActive ? ColorScheme.yellow : ColorScheme.withAlpha(ColorScheme.text, 0.72);
        }
        if (actionKey === "display-grayscale") {
            return ScreenFilterService.grayscaleActive ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.72);
        }
        if ((actionKey === "display-extend" || actionKey === "display-extend-right") && (UtilityService.activeDisplayProfile === "dock" || UtilityService.activeDisplayProfile === "extend" || UtilityService.activeDisplayProfile === "extend-right")) {
            return ColorScheme.accent;
        }
        if (actionKey === "display-extend-left" && UtilityService.activeDisplayProfile === "extend-left") {
            return ColorScheme.accent;
        }
        if (actionKey === "display-extend-above" && UtilityService.activeDisplayProfile === "extend-above") {
            return ColorScheme.accent;
        }
        if (actionKey === "display-mirror" && UtilityService.activeDisplayProfile === "mirror") {
            return ColorScheme.accent;
        }
        if (actionKey === "display-internal" && (UtilityService.activeDisplayProfile === "undock" || UtilityService.activeDisplayProfile === "internal-only")) {
            return ColorScheme.accent;
        }
        if (actionKey === "display-external" && UtilityService.activeDisplayProfile === "external-only") {
            return ColorScheme.accent;
        }
        if (actionKey === "display-identify") {
            return ColorScheme.teal;
        }
        return ColorScheme.withAlpha(ColorScheme.text, 0.95);
    }

    function actionAvailable(actionKey) {
        if (!root.healthChecked) return true;
        var deps = HealthService.dependenciesForAction(actionKey);
        return HealthService.missingDependencies(root.binaryStatus, deps).length === 0;
    }

    function groupAvailable(groupKey) {
        return true;
    }

    function toggleGroup(groupKey) {
        if (root.activeGroup === groupKey) {
            root.activeGroup = "";
        } else {
            root.activeGroup = groupKey;
        }
    }

    function notifyMissing(actionKey) {
        if (!root.healthChecked) return;
        var deps = HealthService.dependenciesForAction(actionKey);
        var missing = HealthService.missingDependencies(root.binaryStatus, deps);
        if (missing.length === 0) return;

        notifyProc.exec([
            "notify-send",
            "-a", "Utility Hub",
            "Dependência ausente",
            "Instale: " + missing.join(", ")
        ]);
    }

    function handleAction(actionKey) {
        if (!actionAvailable(actionKey)) {
            notifyMissing(actionKey);
            return;
        }
        if (actionKey === "toggle-presentation") {
            UtilityService.togglePresentationMode();
            return;
        }
        if (actionKey === "shot-active-mode") {
            root.isOpen = false;
            UtilityService.takeScreenshot(UtilityService.screenshotMode, { annotate: false });
            return;
        }
        if (actionKey === "shot-screen") {
            root.isOpen = false;
            UtilityService.takeScreenshot("screen", { annotate: false });
            return;
        }
        if (actionKey === "shot-all") {
            root.isOpen = false;
            UtilityService.takeScreenshot("all", { annotate: false });
            return;
        }
        if (actionKey === "shot-region") {
            root.isOpen = false;
            UtilityService.takeScreenshot("region", { annotate: false });
            return;
        }
        if (actionKey === "shot-window") {
            root.isOpen = false;
            UtilityService.takeScreenshot("window", { annotate: false });
            return;
        }
        if (actionKey === "shot-annotate") {
            root.isOpen = false;
            UtilityService.takeScreenshot("region", { annotate: true });
            return;
        }
        if (actionKey === "cycle-shot-format") {
            UtilityService.cycleScreenshotFormat();
            return;
        }
        if (actionKey === "cycle-shot-mode") {
            UtilityService.cycleScreenshotMode();
            return;
        }
        if (actionKey === "cycle-shot-delay") {
            UtilityService.cycleScreenshotDelay();
            return;
        }
        if (actionKey === "cycle-shot-destination") {
            UtilityService.cycleScreenshotDestination();
            return;
        }
        if (actionKey === "cycle-template") {
            UtilityService.cycleFileTemplate();
            return;
        }
        if (actionKey === "toggle-copy-path-thumb") {
            UtilityService.toggleCopyPathThumb();
            return;
        }
        if (actionKey === "rec-full") {
            root.isOpen = false;
            UtilityService.toggleRecording("full");
            return;
        }
        if (actionKey === "rec-region") {
            root.isOpen = false;
            UtilityService.toggleRecording("region");
            return;
        }
        if (actionKey === "rec-gif") {
            root.isOpen = false;
            UtilityService.toggleRecording("gif");
            return;
        }
        if (actionKey === "toggle-pause") {
            UtilityService.togglePauseRecording();
            return;
        }
        if (actionKey === "toggle-mic") {
            UtilityService.toggleMic();
            return;
        }
        if (actionKey === "toggle-system") {
            UtilityService.toggleSystemAudio();
            return;
        }
        if (actionKey === "cycle-video-container") {
            UtilityService.cycleVideoContainer();
            return;
        }
        if (actionKey === "cycle-video-codec") {
            UtilityService.cycleVideoCodec();
            return;
        }
        if (actionKey === "cycle-video-destination") {
            UtilityService.cycleVideoDestination();
            return;
        }
        if (actionKey === "cycle-video-fps") {
            UtilityService.cycleVideoFps();
            return;
        }
        if (actionKey === "cycle-video-quality") {
            UtilityService.cycleVideoQuality();
            return;
        }
        if (actionKey === "display-extend" || actionKey === "display-extend-right") {
            UtilityService.applyDisplayProfile("extend-right");
            return;
        }
        if (actionKey === "display-extend-left") {
            UtilityService.applyDisplayProfile("extend-left");
            return;
        }
        if (actionKey === "display-extend-above") {
            UtilityService.applyDisplayProfile("extend-above");
            return;
        }
        if (actionKey === "display-mirror") {
            UtilityService.applyDisplayProfile("mirror");
            return;
        }
        if (actionKey === "display-internal") {
            UtilityService.applyDisplayProfile("internal-only");
            return;
        }
        if (actionKey === "display-external") {
            UtilityService.applyDisplayProfile("external-only");
            return;
        }
        if (actionKey === "display-identify") {
            UtilityService.identifyMonitors();
            return;
        }
        if (actionKey === "display-night-light") {
            ScreenFilterService.toggleNightLight();
            return;
        }
        if (actionKey === "display-grayscale") {
            ScreenFilterService.toggleGrayscale();
            return;
        }
        if (actionKey === "cycle-display-res") {
            UtilityService.cycleDisplayResolution();
            return;
        }
        if (actionKey === "color") {
            root.isOpen = false;
            UtilityService.pickColor();
            return;
        }
        if (actionKey === "copy-color-rgb") {
            UtilityService.copyColor("rgb");
            return;
        }
        if (actionKey === "copy-color-hsl") {
            UtilityService.copyColor("hsl");
            return;
        }
        if (actionKey === "toggle-anonymize") {
            UtilityService.toggleAnonymize();
            return;
        }
        if (actionKey === "cycle-lens-provider") {
            UtilityService.cycleLensProvider();
            return;
        }
        if (actionKey === "cycle-ocr-lang") {
            UtilityService.cycleOcrLanguage();
            return;
        }
        if (actionKey === "ocr") {
            root.isOpen = false;
            UtilityService.runOcr();
            return;
        }
        if (actionKey === "lens") {
            if (!root.lensConfirmArmed) {
                root.lensConfirmArmed = true;
                lensConfirmTimer.restart();
                UtilityService.notifyInfo("Visual Lens", "Clique novamente para confirmar envio");
                return;
            }
            root.lensConfirmArmed = false;
            root.isOpen = false;
            UtilityService.runLens();
            return;
        }
    }

    Timer {
        id: closeEnableTimer
        interval: 120
        repeat: false
        running: false
        onTriggered: root.outsideCloseEnabled = true
    }

    Timer {
        id: lensConfirmTimer
        interval: 5000
        repeat: false
        onTriggered: root.lensConfirmArmed = false
    }

    TimedProcess { id: notifyProc }

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        onClicked: (mouse) => {
            var pBar = mapToItem(actionBar, mouse.x, mouse.y);
            var inBar = pBar.x >= 0 && pBar.y >= 0 && pBar.x <= actionBar.width && pBar.y <= actionBar.height;
            var inGallery = false;
            if (galleryCard.visible) {
                var pGal = mapToItem(galleryCard, mouse.x, mouse.y);
                inGallery = pGal.x >= 0 && pGal.y >= 0 && pGal.x <= galleryCard.width && pGal.y <= galleryCard.height;
            }
            var inVideo = false;
            if (videoCard.visible) {
                var pVid = mapToItem(videoCard, mouse.x, mouse.y);
                inVideo = pVid.x >= 0 && pVid.y >= 0 && pVid.x <= videoCard.width && pVid.y <= videoCard.height;
            }
            var inDisplay = false;
            if (displayCard.visible) {
                var pDisp = mapToItem(displayCard, mouse.x, mouse.y);
                inDisplay = pDisp.x >= 0 && pDisp.y >= 0 && pDisp.x <= displayCard.width && pDisp.y <= displayCard.height;
            }
            var inTools = false;
            if (toolsCard.visible) {
                var pTools = mapToItem(toolsCard, mouse.x, mouse.y);
                inTools = pTools.x >= 0 && pTools.y >= 0 && pTools.x <= toolsCard.width && pTools.y <= toolsCard.height;
            }

            if (!inBar && !inGallery && !inVideo && !inDisplay && !inTools) {
                if (root.expanded) root.activeGroup = "";
                else root.isOpen = false;
            }
        }
    }

    Item {
        id: actionBar
        height: 52
        width: Math.min(root.width - 64, rowContent.implicitWidth + 32)
        anchors.top: parent.top
        anchors.topMargin: 58
        anchors.horizontalCenter: parent.horizontalCenter
        z: 2
        opacity: root.utilityAvailable ? 1.0 : 0.78

        Behavior on width {
            SpringAnimation { spring: 4.8; damping: 0.65; epsilon: 1.0 }
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: height / 2
            color: ColorScheme.withAlpha(ColorScheme.background, 0.88)
            border.color: root.isRecording
                ? ColorScheme.withAlpha(ColorScheme.red, 0.65)
                : ColorScheme.glassBorder
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 180 } }
        }

        Rectangle {
            anchors.fill: bg
            anchors.topMargin: 6
            radius: bg.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: -1
        }

        RowLayout {
            id: rowContent
            anchors.centerIn: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 12

            Repeater {
                model: root.mainGroups

                delegate: Item {
                    id: mainDelegate
                    required property var modelData
                    readonly property bool groupEnabled: root.groupAvailable(modelData.key)

                    width: 36
                    height: 36
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        id: mainBtnBg
                        anchors.fill: parent
                        radius: 18
                        color: {
                            if (root.activeGroup === modelData.key) return ColorScheme.withAlpha(ColorScheme.accent, 0.35);
                            if (mainMa.containsMouse) return ColorScheme.withAlpha(ColorScheme.text, 0.12);
                            return "transparent";
                        }
                        scale: (mainMa.containsMouse && groupEnabled) ? 1.1 : 1.0
                        opacity: groupEnabled ? 1.0 : DesignTokens.disabledOpacity
                        border.color: root.isRecording && modelData.key === "video"
                            ? ColorScheme.withAlpha(ColorScheme.red, 0.65)
                            : (root.activeGroup === modelData.key ? ColorScheme.accent : "transparent")
                        border.width: 1

                        Behavior on scale { SpringAnimation { spring: 5; damping: 0.52; epsilon: 0.02 } }
                        Behavior on color { ColorAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: root.isRecording && modelData.key === "video"
                                ? ColorScheme.red
                                : (groupEnabled
                                    ? (root.activeGroup === modelData.key ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.85))
                                    : ColorScheme.withAlpha(ColorScheme.text, 0.32))

                            SequentialAnimation on opacity {
                                running: root.isRecording && modelData.key === "video"
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 550; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 550; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    MouseArea {
                        id: mainMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: groupEnabled
                        cursorShape: groupEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (groupEnabled) root.toggleGroup(modelData.key)
                    }
                }
            }

            Rectangle {
                visible: root.expanded
                Layout.preferredWidth: 1
                Layout.preferredHeight: 24
                color: ColorScheme.withAlpha(ColorScheme.text, 0.12)
                Layout.leftMargin: 2
                Layout.rightMargin: 2
            }

            Repeater {
                model: root.groupActions

                delegate: Item {
                    id: actionDelegate
                    required property var modelData
                    readonly property bool actionEnabled: root.actionAvailable(modelData.key)

                    visible: root.expanded
                    width: visible ? 36 : 0
                    height: 36
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        id: actionBtnBg
                        anchors.fill: parent
                        radius: 18
                        color: actionMa.containsMouse
                            ? ColorScheme.withAlpha(ColorScheme.text, 0.12)
                            : "transparent"
                        scale: (actionMa.containsMouse && actionEnabled) ? 1.1 : 1.0
                        opacity: actionEnabled ? 1.0 : DesignTokens.disabledOpacity

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 15
                            color: root.iconColorForAction(modelData.key)
                        }
                    }

                    MouseArea {
                        id: actionMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: actionEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: root.handleAction(modelData.key)
                    }
                }
            }

            Item {
                visible: root.expanded
                width: 36
                height: 36
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 4

                Rectangle {
                    id: collapseBg
                    anchors.fill: parent
                    radius: 18
                    color: collapseMa.containsMouse
                        ? ColorScheme.withAlpha(ColorScheme.red, 0.20)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f00d}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: collapseMa.containsMouse ? ColorScheme.red : ColorScheme.withAlpha(ColorScheme.text, 0.8)
                    }
                }

                MouseArea {
                    id: collapseMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeGroup = ""
                }
            }
        }
    }

    // ─── Recent Screenshots Mini-Gallery Dropdown Card ───────────────────────
    Item {
        id: galleryCard
        visible: root.activeGroup === "camera" && root.isOpen
        anchors.top: actionBar.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width - 64, 460)
        height: 148
        z: 1

        opacity: (root.activeGroup === "camera" && root.isOpen) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

        Rectangle {
            anchors.fill: parent
            radius: DesignTokens.radiusLG
            color: ColorScheme.withAlpha(ColorScheme.background, 0.88)
            border.color: ColorScheme.glassBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Header Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "\u{f03e} Capturas Recentes"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.9)
                    }

                    Rectangle {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: fmtText.implicitWidth + 12
                        radius: 9
                        color: ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                        border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.3)
                        border.width: 1

                        Text {
                            id: fmtText
                            anchors.centerIn: parent
                            text: root.screenshotFormat.toUpperCase() + (root.screenshotDelaySec > 0 ? (" • " + root.screenshotDelaySec + "s") : "")
                            font.pixelSize: 9
                            font.bold: true
                            color: ColorScheme.accent
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Open Screenshots Folder Button
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: folderMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.25) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\u{f07c}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: folderMa.containsMouse ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.6)
                        }

                        MouseArea {
                            id: folderMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.openFolder(root.screenshotDestination)
                        }
                    }
                }

                // Gallery Thumbnail List
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: galleryView
                        visible: UtilityService.recentCaptures.length > 0
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        boundsBehavior: Flickable.StopAtBounds
                        spacing: 8
                        clip: true
                        model: UtilityService.recentCaptures

                        WheelHandler {
                            orientation: Qt.Vertical
                            onWheel: (event) => {
                                galleryView.contentX = Math.max(0, Math.min(galleryView.contentWidth - galleryView.width, galleryView.contentX - event.angleDelta.y));
                            }
                        }

                        delegate: Item {
                            id: thumbDelegate
                            required property var modelData
                            width: 100
                            height: 84

                            Rectangle {
                                anchors.fill: parent
                                radius: DesignTokens.radiusMD
                                color: ColorScheme.withAlpha(ColorScheme.surface, 0.6)
                                border.color: thumbMa.containsMouse ? ColorScheme.accent : ColorScheme.glassBorder
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: "file://" + modelData.path
                                    sourceSize.width: 160
                                    sourceSize.height: 120
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                }

                                // Dark gradient scrim for readability & hover buttons
                                Rectangle {
                                    anchors.fill: parent
                                    color: thumbMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.background, 0.75) : Qt.rgba(0, 0, 0, 0.25)
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                // Quick action buttons visible on hover
                                RowLayout {
                                    visible: thumbMa.containsMouse
                                    anchors.centerIn: parent
                                    spacing: 4

                                    // View / Open
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: ColorScheme.withAlpha(ColorScheme.text, 0.2)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\u{f06e}"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            color: ColorScheme.text
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: UtilityService.openCapture(modelData.path)
                                        }
                                    }

                                    // Copy
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: ColorScheme.withAlpha(ColorScheme.text, 0.2)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\u{f0c5}"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            color: ColorScheme.text
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: UtilityService.copyCapture(modelData.path)
                                        }
                                    }

                                    // Edit / Swappy
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: ColorScheme.withAlpha(ColorScheme.text, 0.2)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\u{f044}"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            color: ColorScheme.text
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: UtilityService.annotateCapture(modelData.path)
                                        }
                                    }

                                    // Delete
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: ColorScheme.withAlpha(ColorScheme.red, 0.25)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\u{f1f8}"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            color: ColorScheme.red
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: UtilityService.deleteCapture(modelData.path)
                                        }
                                    }
                                }

                                // Bottom filename label
                                Text {
                                    visible: !thumbMa.containsMouse
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 4
                                    text: modelData.label
                                    font.pixelSize: 8
                                    elide: Text.ElideMiddle
                                    color: ColorScheme.withAlpha(ColorScheme.text, 0.85)
                                }
                            }

                            MouseArea {
                                id: thumbMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: UtilityService.openCapture(modelData.path)
                            }
                        }
                    }

                    // Empty State
                    RowLayout {
                        visible: UtilityService.recentCaptures.length === 0
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "\u{f15c}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.3)
                        }

                        Text {
                            text: "Nenhuma captura recente"
                            font.pixelSize: 11
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.45)
                        }
                    }
                }
            }
        }
    }

    // ─── Video Recording Controls & Status Dropdown Card (Wave 2) ─────────────
    Item {
        id: videoCard
        visible: root.activeGroup === "video" && root.isOpen
        anchors.top: actionBar.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width - 64, 460)
        height: 136
        z: 1

        opacity: (root.activeGroup === "video" && root.isOpen) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

        Rectangle {
            anchors.fill: parent
            radius: DesignTokens.radiusLG
            color: ColorScheme.withAlpha(ColorScheme.background, 0.88)
            border.color: root.isRecording ? ColorScheme.withAlpha(ColorScheme.red, 0.5) : ColorScheme.glassBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Header Bar with status & duration
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: root.isRecording ? ColorScheme.red : ColorScheme.accent

                        SequentialAnimation on opacity {
                            running: root.isRecording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }
                    }

                    Text {
                        text: root.isRecording
                            ? (root.isPaused ? "Gravação Pausada (" + root.recordingDurationLabel + ")" : "Gravando: " + root.recordingDurationLabel)
                            : "Gravação de Tela"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true
                        color: root.isRecording ? ColorScheme.red : ColorScheme.withAlpha(ColorScheme.text, 0.9)
                    }

                    Rectangle {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: vidBadgeText.implicitWidth + 12
                        radius: 9
                        color: ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                        border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.3)
                        border.width: 1

                        Text {
                            id: vidBadgeText
                            anchors.centerIn: parent
                            text: root.videoContainer.toUpperCase() + " • " + root.videoFps + " FPS"
                            font.pixelSize: 9
                            font.bold: true
                            color: ColorScheme.accent
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Open Videos Folder Button
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: vfolderMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.25) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\u{f07c}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: vfolderMa.containsMouse ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.6)
                        }

                        MouseArea {
                            id: vfolderMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.openFolder(root.videoDestination)
                        }
                    }
                }

                // Middle Info Row: Audio status & Hardware Acceleration
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Mic status badge
                    Rectangle {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: micTxt.implicitWidth + 16
                        radius: 11
                        color: root.micEnabled ? ColorScheme.withAlpha(ColorScheme.accent, 0.25) : ColorScheme.withAlpha(ColorScheme.text, 0.08)
                        border.color: root.micEnabled ? ColorScheme.accent : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\u{f130}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: root.micEnabled ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.5)
                            }
                            Text {
                                id: micTxt
                                text: root.micEnabled ? "Mic ON" : "Mic OFF"
                                font.pixelSize: 9
                                font.bold: root.micEnabled
                                color: root.micEnabled ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.6)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.toggleMic()
                        }
                    }

                    // System audio status badge
                    Rectangle {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: sysTxt.implicitWidth + 16
                        radius: 11
                        color: root.systemEnabled ? ColorScheme.withAlpha(ColorScheme.accent, 0.25) : ColorScheme.withAlpha(ColorScheme.text, 0.08)
                        border.color: root.systemEnabled ? ColorScheme.accent : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\u{f028}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: root.systemEnabled ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.5)
                            }
                            Text {
                                id: sysTxt
                                text: root.systemEnabled ? "Áudio Sistema ON" : "Áudio Sistema OFF"
                                font.pixelSize: 9
                                font.bold: root.systemEnabled
                                color: root.systemEnabled ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.6)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.toggleSystemAudio()
                        }
                    }

                    // GPU VAAPI Hardware Accel Tag
                    Rectangle {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: vaapiTxt.implicitWidth + 14
                        radius: 11
                        color: ColorScheme.withAlpha(ColorScheme.teal, 0.15)
                        border.color: ColorScheme.withAlpha(ColorScheme.teal, 0.3)
                        border.width: 1

                        Text {
                            id: vaapiTxt
                            anchors.centerIn: parent
                            text: "\u{f2db} VAAPI (GPU)"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 9
                            font.bold: true
                            color: ColorScheme.teal
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Bottom Action Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Primary Action Button: Stop Recording or Quick Full/Region/GIF
                    Rectangle {
                        visible: root.isRecording
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: DesignTokens.radiusMD
                        color: ColorScheme.withAlpha(ColorScheme.red, 0.25)
                        border.color: ColorScheme.red
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\u{f04d}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: ColorScheme.red
                            }
                            Text {
                                text: "Parar e Salvar Gravação"
                                font.pixelSize: 11
                                font.bold: true
                                color: ColorScheme.red
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.stopRecording()
                        }
                    }

                    // Pause / Resume Button
                    Rectangle {
                        visible: root.isRecording
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 32
                        radius: DesignTokens.radiusMD
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.1)
                        border.color: ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: root.isPaused ? "\u{f04b}" : "\u{f04c}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: root.isPaused ? ColorScheme.yellow : ColorScheme.text
                            }
                            Text {
                                text: root.isPaused ? "Retomar" : "Pausar"
                                font.pixelSize: 10
                                color: root.isPaused ? ColorScheme.yellow : ColorScheme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.togglePauseRecording()
                        }
                    }

                    // Idle Quick Buttons: Full, Region, GIF
                    Rectangle {
                        visible: !root.isRecording
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: DesignTokens.radiusMD
                        color: ColorScheme.withAlpha(ColorScheme.accent, 0.2)
                        border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.4)
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\u{f03d}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ColorScheme.accent
                            }
                            Text {
                                text: "Gravar Tela Cheia"
                                font.pixelSize: 11
                                font.bold: true
                                color: ColorScheme.accent
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isOpen = false;
                                UtilityService.startRecording("full");
                            }
                        }
                    }

                    Rectangle {
                        visible: !root.isRecording
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: DesignTokens.radiusMD
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                        border.color: ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\u{f124}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ColorScheme.text
                            }
                            Text {
                                text: "Gravar Região"
                                font.pixelSize: 11
                                color: ColorScheme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isOpen = false;
                                UtilityService.startRecording("region");
                            }
                        }
                    }

                    Rectangle {
                        visible: !root.isRecording
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: DesignTokens.radiusMD
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                        border.color: ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\u{f1c8}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ColorScheme.text
                            }
                            Text {
                                text: "Gravar GIF"
                                font.pixelSize: 11
                                color: ColorScheme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isOpen = false;
                                UtilityService.startRecording("gif");
                            }
                        }
                    }
                }
            }
        }
    }

    // ─── Display & Screen Manager Dropdown Card (Wave 3) ─────────────────────
    Item {
        id: displayCard
        visible: root.activeGroup === "display" && root.isOpen
        anchors.top: actionBar.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width - 48, 520)
        height: displayCol.implicitHeight + 24
        z: 1

        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        opacity: (root.activeGroup === "display" && root.isOpen) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

        Rectangle {
            anchors.fill: parent
            radius: DesignTokens.radiusLG
            color: ColorScheme.withAlpha(ColorScheme.background, 0.92)
            border.color: ColorScheme.glassBorder
            border.width: 1

            ColumnLayout {
                id: displayCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Header Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "\u{f108} Gerenciador de Telas"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.9)
                    }

                    Rectangle {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: dispBadgeText.implicitWidth + 12
                        radius: 9
                        color: ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                        border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.3)
                        border.width: 1

                        Text {
                            id: dispBadgeText
                            anchors.centerIn: parent
                            text: root.activeDisplayProfile.toUpperCase() + " • " + (root.connectedMonitorsCount > 1 ? (root.connectedMonitorsCount + " TELAS") : "1 TELA")
                            font.pixelSize: 9
                            font.bold: true
                            color: ColorScheme.accent
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Identify Displays Button
                    Rectangle {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: identTxt.implicitWidth + 14
                        radius: 11
                        color: identMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.teal, 0.3) : ColorScheme.withAlpha(ColorScheme.teal, 0.12)
                        border.color: ColorScheme.withAlpha(ColorScheme.teal, 0.4)
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\u{f06e}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                color: ColorScheme.teal
                            }
                            Text {
                                id: identTxt
                                text: "Identificar"
                                font.pixelSize: 9
                                font.bold: true
                                color: ColorScheme.teal
                            }
                        }

                        MouseArea {
                            id: identMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.identifyMonitors()
                        }
                    }

                    // Refresh Button
                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: refMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.25) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\u{f021}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: refMa.containsMouse ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.6)
                        }

                        MouseArea {
                            id: refMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.refreshDisplayProfile()
                        }
                    }
                }

                // ── Interactive 2D Spatial Canvas Preview ──
                Rectangle {
                    id: visualCanvas
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    radius: DesignTokens.radiusMD
                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.45)
                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                    border.width: 1
                    clip: true

                    // Ambient grid pattern
                    Item {
                        anchors.fill: parent
                        opacity: 0.25

                        Repeater {
                            model: 6
                            Rectangle {
                                x: (parent.width / 6) * index
                                y: 0
                                width: 1
                                height: parent.height
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                            }
                        }
                    }

                    // Canvas viewport centering container
                    Item {
                        id: canvasScene
                        anchors.centerIn: parent
                        width: parent.width - 24
                        height: parent.height - 16

                        // Laptop Visual Box (eDP-1)
                        Rectangle {
                            id: laptopVisualBox
                            readonly property bool isMirror: root.activeDisplayProfile === "mirror"
                            readonly property bool isLeft: root.activeDisplayProfile === "extend-left"
                            readonly property bool isRight: root.activeDisplayProfile === "dock" || root.activeDisplayProfile === "extend" || root.activeDisplayProfile === "extend-right"
                            readonly property bool isDisabled: root.activeDisplayProfile === "external-only"
                            readonly property bool isFocused: {
                                for (var i = 0; i < root.monitorList.length; i++) {
                                    if (root.monitorList[i].isInternal && root.monitorList[i].focused) return true;
                                }
                                return false;
                            }

                            width: 116
                            height: 72
                            radius: DesignTokens.radiusSM
                            color: isDisabled ? ColorScheme.withAlpha(ColorScheme.surface, 0.2) : ColorScheme.withAlpha(ColorScheme.background, 0.9)
                            border.color: isFocused ? ColorScheme.accent : (isDisabled ? ColorScheme.withAlpha(ColorScheme.text, 0.1) : ColorScheme.glassBorder)
                            border.width: isFocused ? 2 : 1
                            opacity: isDisabled ? 0.35 : 1.0

                            anchors.verticalCenter: parent.verticalCenter
                            x: {
                                if (isMirror) return (parent.width - width) / 2 - 18;
                                if (root.connectedMonitorsCount <= 1 || root.activeDisplayProfile === "internal-only" || root.activeDisplayProfile === "undock") return (parent.width - width) / 2;
                                if (isLeft) return parent.width / 2 + 10;
                                return parent.width / 2 - width - 10;
                            }

                            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text {
                                        text: "\u{f109}"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: laptopVisualBox.isFocused ? ColorScheme.accent : ColorScheme.text
                                    }
                                    Text {
                                        text: root.internalMonitorName || "eDP-1"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: ColorScheme.text
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Rectangle {
                                        visible: laptopVisualBox.isFocused
                                        width: 6; height: 6; radius: 3
                                        color: ColorScheme.accent
                                    }
                                }

                                Text {
                                    text: "1366x768 (60Hz)"
                                    font.pixelSize: 9
                                    color: ColorScheme.withAlpha(ColorScheme.text, 0.6)
                                }

                                Item { Layout.fillHeight: true }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 16
                                    radius: 3
                                    color: ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Workspaces 1 - 5"
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: ColorScheme.accent
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch("focusmonitor " + (root.internalMonitorName || "eDP-1"))
                            }
                        }

                        // External TV / Monitor Visual Box (HDMI-A-1)
                        Rectangle {
                            id: tvVisualBox
                            readonly property bool isPresent: root.connectedMonitorsCount > 1
                            readonly property bool isMirror: root.activeDisplayProfile === "mirror"
                            readonly property bool isLeft: root.activeDisplayProfile === "extend-left"
                            readonly property bool isRight: root.activeDisplayProfile === "dock" || root.activeDisplayProfile === "extend" || root.activeDisplayProfile === "extend-right"
                            readonly property bool isDisabled: !isPresent || root.activeDisplayProfile === "internal-only" || root.activeDisplayProfile === "undock"
                            readonly property bool isFocused: {
                                for (var i = 0; i < root.monitorList.length; i++) {
                                    if (!root.monitorList[i].isInternal && root.monitorList[i].focused) return true;
                                }
                                return false;
                            }

                            width: 140
                            height: 84
                            radius: DesignTokens.radiusSM
                            color: isDisabled ? ColorScheme.withAlpha(ColorScheme.surface, 0.15) : ColorScheme.withAlpha(ColorScheme.background, 0.9)
                            border.color: isFocused ? ColorScheme.accent : (isDisabled ? ColorScheme.withAlpha(ColorScheme.text, 0.1) : ColorScheme.glassBorder)
                            border.width: isFocused ? 2 : 1
                            opacity: isDisabled ? 0.35 : 1.0

                            anchors.verticalCenter: parent.verticalCenter
                            x: {
                                if (isMirror) return (parent.width - width) / 2 + 18;
                                if (!isPresent || root.activeDisplayProfile === "internal-only" || root.activeDisplayProfile === "undock") return parent.width - width - 10;
                                if (isLeft) return parent.width / 2 - width - 10;
                                return parent.width / 2 + 10;
                            }

                            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text {
                                        text: "\u{f26c}"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        color: tvVisualBox.isFocused ? ColorScheme.accent : (tvVisualBox.isDisabled ? ColorScheme.withAlpha(ColorScheme.text, 0.4) : ColorScheme.text)
                                    }
                                    Text {
                                        text: root.externalMonitorName || "HDMI-A-1 (TV)"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: tvVisualBox.isDisabled ? ColorScheme.withAlpha(ColorScheme.text, 0.4) : ColorScheme.text
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Rectangle {
                                        visible: tvVisualBox.isFocused
                                        width: 6; height: 6; radius: 3
                                        color: ColorScheme.accent
                                    }
                                }

                                Text {
                                    text: tvVisualBox.isDisabled ? "Desativada" : (root.activeDisplayResolution.indexOf("1920") >= 0 ? "1920x1080 (Full HD)" : root.activeDisplayResolution + " (Nativa)")
                                    font.pixelSize: 9
                                    color: tvVisualBox.isDisabled ? ColorScheme.withAlpha(ColorScheme.text, 0.35) : ColorScheme.withAlpha(ColorScheme.text, 0.6)
                                }

                                Item { Layout.fillHeight: true }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 16
                                    radius: 3
                                    color: tvVisualBox.isDisabled
                                        ? ColorScheme.withAlpha(ColorScheme.text, 0.06)
                                        : (isMirror ? ColorScheme.withAlpha(ColorScheme.teal, 0.18) : ColorScheme.withAlpha(ColorScheme.blue, 0.18))
                                    Text {
                                        anchors.centerIn: parent
                                        text: tvVisualBox.isDisabled ? "Desconectada" : (isMirror ? "Espelhado (Clone)" : "Workspaces 6 - 10 (TV)")
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: tvVisualBox.isDisabled
                                            ? ColorScheme.withAlpha(ColorScheme.text, 0.4)
                                            : (isMirror ? ColorScheme.teal : ColorScheme.blue)
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !tvVisualBox.isDisabled
                                cursorShape: tvVisualBox.isDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    Hyprland.dispatch("focusmonitor " + (root.externalMonitorName || "HDMI-A-1"));
                                }
                            }
                        }

                        // Spatial Connection Indicator between screens
                        Rectangle {
                            visible: root.connectedMonitorsCount > 1 && root.activeDisplayProfile !== "internal-only" && root.activeDisplayProfile !== "external-only"
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            radius: 11
                            color: ColorScheme.withAlpha(ColorScheme.background, 0.95)
                            border.color: ColorScheme.accent
                            border.width: 1
                            z: 5

                            Text {
                                anchors.centerIn: parent
                                text: root.activeDisplayProfile === "mirror" ? "\u{f0c5}" : (root.activeDisplayProfile === "extend-left" ? "\u{f060}" : "\u{f061}")
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: ColorScheme.accent
                            }
                        }
                    }
                }

                // Middle Row: 5 Projection Profile Presets
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    // Extend Right
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: DesignTokens.radiusMD
                        readonly property bool isActive: root.activeDisplayProfile === "dock" || root.activeDisplayProfile === "extend" || root.activeDisplayProfile === "extend-right"
                        color: isActive ? ColorScheme.withAlpha(ColorScheme.accent, 0.25) : ColorScheme.withAlpha(ColorScheme.text, 0.06)
                        border.color: isActive ? ColorScheme.accent : ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\u{f065}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: parent.parent.isActive ? ColorScheme.accent : ColorScheme.text
                            }
                            Text {
                                text: "Estender (Dir)"
                                font.pixelSize: 9
                                font.bold: parent.parent.isActive
                                color: parent.parent.isActive ? ColorScheme.accent : ColorScheme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.applyDisplayProfile("extend-right")
                        }
                    }

                    // Extend Left
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: DesignTokens.radiusMD
                        readonly property bool isActive: root.activeDisplayProfile === "extend-left"
                        color: isActive ? ColorScheme.withAlpha(ColorScheme.accent, 0.25) : ColorScheme.withAlpha(ColorScheme.text, 0.06)
                        border.color: isActive ? ColorScheme.accent : ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\u{f060}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: parent.parent.isActive ? ColorScheme.accent : ColorScheme.text
                            }
                            Text {
                                text: "Estender (Esq)"
                                font.pixelSize: 9
                                font.bold: parent.parent.isActive
                                color: parent.parent.isActive ? ColorScheme.accent : ColorScheme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.applyDisplayProfile("extend-left")
                        }
                    }

                    // Mirror
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: DesignTokens.radiusMD
                        readonly property bool isActive: root.activeDisplayProfile === "mirror"
                        color: isActive ? ColorScheme.withAlpha(ColorScheme.accent, 0.25) : ColorScheme.withAlpha(ColorScheme.text, 0.06)
                        border.color: isActive ? ColorScheme.accent : ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\u{f0c5}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: parent.parent.isActive ? ColorScheme.accent : ColorScheme.text
                            }
                            Text {
                                text: "Espelhar"
                                font.pixelSize: 9
                                font.bold: parent.parent.isActive
                                color: parent.parent.isActive ? ColorScheme.accent : ColorScheme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.applyDisplayProfile("mirror")
                        }
                    }

                    // Laptop Only
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: DesignTokens.radiusMD
                        readonly property bool isActive: root.activeDisplayProfile === "undock" || root.activeDisplayProfile === "internal-only"
                        color: isActive ? ColorScheme.withAlpha(ColorScheme.accent, 0.25) : ColorScheme.withAlpha(ColorScheme.text, 0.06)
                        border.color: isActive ? ColorScheme.accent : ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\u{f109}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: parent.parent.isActive ? ColorScheme.accent : ColorScheme.text
                            }
                            Text {
                                text: "Laptop"
                                font.pixelSize: 9
                                font.bold: parent.parent.isActive
                                color: parent.parent.isActive ? ColorScheme.accent : ColorScheme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.applyDisplayProfile("internal-only")
                        }
                    }

                    // External Only
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: DesignTokens.radiusMD
                        readonly property bool isActive: root.activeDisplayProfile === "external-only"
                        color: isActive ? ColorScheme.withAlpha(ColorScheme.accent, 0.25) : ColorScheme.withAlpha(ColorScheme.text, 0.06)
                        border.color: isActive ? ColorScheme.accent : ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\u{f26c}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: parent.parent.isActive ? ColorScheme.accent : ColorScheme.text
                            }
                            Text {
                                text: "TV/Ext"
                                font.pixelSize: 9
                                font.bold: parent.parent.isActive
                                color: parent.parent.isActive ? ColorScheme.accent : ColorScheme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.applyDisplayProfile("external-only")
                        }
                    }
                }

                // Dynamic Physical Displays List
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.monitorList.length > 0 ? root.monitorList : [
                            {
                                name: root.internalMonitorName || "eDP-1",
                                model: "Tela Integrada",
                                width: 1366,
                                height: 768,
                                refreshRate: 60,
                                scale: 1,
                                transform: 0,
                                focused: true,
                                isInternal: true
                            }
                        ]

                        delegate: Rectangle {
                            id: monCardDelegate
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: DesignTokens.radiusMD
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.6)
                            border.color: modelData.focused ? ColorScheme.accent : ColorScheme.glassBorder
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                // Monitor Type Icon
                                Text {
                                    text: modelData.isInternal ? "\u{f109}" : "\u{f26c}"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
                                    color: modelData.focused ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.7)
                                }

                                // Monitor Name & Make
                                ColumnLayout {
                                    spacing: 1
                                    Layout.preferredWidth: 130

                                    RowLayout {
                                        spacing: 4
                                        Text {
                                            text: modelData.name
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: ColorScheme.text
                                        }
                                        Rectangle {
                                            visible: modelData.focused
                                            Layout.preferredHeight: 12
                                            Layout.preferredWidth: 44
                                            radius: 6
                                            color: ColorScheme.withAlpha(ColorScheme.accent, 0.2)
                                            Text {
                                                anchors.centerIn: parent
                                                text: "FOCADO"
                                                font.pixelSize: 7
                                                font.bold: true
                                                color: ColorScheme.accent
                                            }
                                        }
                                    }
                                    Text {
                                        text: String(modelData.model || modelData.description || "Display").substring(0, 18)
                                        font.pixelSize: 9
                                        color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                                        elide: Text.ElideRight
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Resolution & Refresh Rate Button (Cycles supported hardware modes)
                                Rectangle {
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: resTxt.implicitWidth + 12
                                    radius: DesignTokens.radiusSM
                                    color: resMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.2) : ColorScheme.withAlpha(ColorScheme.text, 0.07)
                                    border.color: resMa.containsMouse ? ColorScheme.accent : ColorScheme.glassBorder
                                    border.width: 1

                                    Text {
                                        id: resTxt
                                        anchors.centerIn: parent
                                        text: modelData.width + "x" + modelData.height + "@" + (modelData.refreshRate || 60) + "Hz"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: ColorScheme.withAlpha(ColorScheme.text, 0.9)
                                    }

                                    MouseArea {
                                        id: resMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: UtilityService.cycleDisplayResolution(modelData.name)
                                    }
                                }

                                // Scale Adjuster Button (Cycles 1.0x -> 1.25x -> 1.5x -> 2.0x -> 1.0x)
                                Rectangle {
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: 42
                                    radius: DesignTokens.radiusSM
                                    color: scaleMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.2) : ColorScheme.withAlpha(ColorScheme.text, 0.07)
                                    border.color: scaleMa.containsMouse ? ColorScheme.accent : ColorScheme.glassBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: (modelData.scale || 1) + "x"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: ColorScheme.withAlpha(ColorScheme.text, 0.9)
                                    }

                                    MouseArea {
                                        id: scaleMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var currentScale = modelData.scale || 1;
                                            var nextScale = 1;
                                            if (currentScale < 1.2) nextScale = 1.25;
                                            else if (currentScale < 1.4) nextScale = 1.5;
                                            else if (currentScale < 1.8) nextScale = 2.0;
                                            else nextScale = 1.0;
                                            UtilityService.setMonitorScale(modelData.name, nextScale);
                                        }
                                    }
                                }

                                // Rotation Adjuster Button (Cycles 0° -> 90° -> 180° -> 270° -> 0°)
                                Rectangle {
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: 32
                                    radius: DesignTokens.radiusSM
                                    color: rotMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.2) : ColorScheme.withAlpha(ColorScheme.text, 0.07)
                                    border.color: rotMa.containsMouse ? ColorScheme.accent : ColorScheme.glassBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: (modelData.transform === 1 ? "90°" : (modelData.transform === 2 ? "180°" : (modelData.transform === 3 ? "270°" : "0°")))
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: ColorScheme.withAlpha(ColorScheme.text, 0.9)
                                    }

                                    MouseArea {
                                        id: rotMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var curTrans = modelData.transform || 0;
                                            var nextTrans = (curTrans + 1) % 4;
                                            UtilityService.setMonitorTransform(modelData.name, nextTrans);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Bottom Row: Eye Care & Screen Filters
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Night Light / Blue Light Filter Toggle
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: DesignTokens.radiusMD
                        color: ScreenFilterService.nightLightActive
                            ? ColorScheme.withAlpha(ColorScheme.yellow, 0.2)
                            : ColorScheme.withAlpha(ColorScheme.text, 0.08)
                        border.color: ScreenFilterService.nightLightActive ? ColorScheme.yellow : ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\u{f186}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ScreenFilterService.nightLightActive ? ColorScheme.yellow : ColorScheme.text
                            }
                            Text {
                                text: ScreenFilterService.nightLightActive
                                    ? ("Luz Noturna: " + ScreenFilterService.nightLightValue + "%")
                                    : "Luz Noturna (OFF)"
                                font.pixelSize: 10
                                font.bold: ScreenFilterService.nightLightActive
                                color: ScreenFilterService.nightLightActive ? ColorScheme.yellow : ColorScheme.text
                            }
                        }

                        WheelHandler {
                            onWheel: (event) => ScreenFilterService.stepNightLight(event.angleDelta.y > 0 ? 10 : -10)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ScreenFilterService.toggleNightLight()
                        }
                    }

                    // Grayscale / Reading Mode Toggle
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: DesignTokens.radiusMD
                        color: ScreenFilterService.grayscaleActive
                            ? ColorScheme.withAlpha(ColorScheme.accent, 0.2)
                            : ColorScheme.withAlpha(ColorScheme.text, 0.08)
                        border.color: ScreenFilterService.grayscaleActive ? ColorScheme.accent : ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\u{f06e}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ScreenFilterService.grayscaleActive ? ColorScheme.accent : ColorScheme.text
                            }
                            Text {
                                text: ScreenFilterService.grayscaleActive
                                    ? ("Monocromático: " + ScreenFilterService.grayscaleValue + "%")
                                    : "Modo Leitura (OFF)"
                                font.pixelSize: 10
                                font.bold: ScreenFilterService.grayscaleActive
                                color: ScreenFilterService.grayscaleActive ? ColorScheme.accent : ColorScheme.text
                            }
                        }

                        WheelHandler {
                            onWheel: (event) => ScreenFilterService.stepGrayscale(event.angleDelta.y > 0 ? 10 : -10)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ScreenFilterService.toggleGrayscale()
                        }
                    }
                }
            }
        }
    }

    // ─── Tools, Color Swatches & Productivity Dropdown Card (Wave 4) ───────────
    Item {
        id: toolsCard
        visible: root.activeGroup === "tools" && root.isOpen
        anchors.top: actionBar.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width - 64, 460)
        height: 148
        z: 1

        opacity: (root.activeGroup === "tools" && root.isOpen) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

        Rectangle {
            anchors.fill: parent
            radius: DesignTokens.radiusLG
            color: ColorScheme.withAlpha(ColorScheme.background, 0.88)
            border.color: ColorScheme.glassBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Header Bar with Tools status tags
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "\u{f0ad} Ferramentas & Cores"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.9)
                    }

                    Rectangle {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: toolsTagText.implicitWidth + 12
                        radius: 9
                        color: ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                        border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.3)
                        border.width: 1

                        Text {
                            id: toolsTagText
                            anchors.centerIn: parent
                            text: "OCR: " + root.ocrLanguage.toUpperCase() + " • LENS: " + root.lensProvider.toUpperCase()
                            font.pixelSize: 9
                            font.bold: true
                            color: ColorScheme.accent
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Middle Row: Color Picker & Swatches History
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Color Picker Button with current active color preview
                    Rectangle {
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: 34
                        radius: DesignTokens.radiusMD
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                        border.color: root.hasColor ? root.lastColorHex : ColorScheme.glassBorder
                        border.width: 1.5

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                color: root.hasColor ? root.lastColorHex : ColorScheme.accent
                                border.color: ColorScheme.withAlpha(ColorScheme.background, 0.8)
                                border.width: 1
                            }

                            Text {
                                text: root.hasColor ? root.lastColorHex : "Capturar Cor"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.bold: true
                                color: ColorScheme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isOpen = false;
                                UtilityService.pickColor();
                            }
                        }
                    }

                    // Recent Color Swatches Dots
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: UtilityService.colorHistory.slice(0, 6)

                            delegate: Item {
                                id: swatchItem
                                required property var modelData
                                width: 22
                                height: 22

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 11
                                    color: modelData.hex || "#FFFFFF"
                                    border.color: swatchMa.containsMouse ? ColorScheme.text : ColorScheme.withAlpha(ColorScheme.background, 0.8)
                                    border.width: 1.5
                                    scale: swatchMa.containsMouse ? 1.2 : 1.0
                                    Behavior on scale { SpringAnimation { spring: 5; damping: 0.5 } }
                                }

                                MouseArea {
                                    id: swatchMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: UtilityService.copyColor("hex", modelData.hex)
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Bottom Row: OCR, Visual Lens & Presentation Mode Quick Actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Snip OCR
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: DesignTokens.radiusMD
                        color: ColorScheme.withAlpha(ColorScheme.accent, 0.2)
                        border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.4)
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\u{f15c}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ColorScheme.accent
                            }
                            Text {
                                text: "Snip OCR"
                                font.pixelSize: 11
                                font.bold: true
                                color: ColorScheme.accent
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isOpen = false;
                                UtilityService.runOcr();
                            }
                        }
                    }

                    // Visual Lens Search
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: DesignTokens.radiusMD
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                        border.color: ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\u{f030}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ColorScheme.text
                            }
                            Text {
                                text: "Visual Lens"
                                font.pixelSize: 11
                                color: ColorScheme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isOpen = false;
                                UtilityService.runLens();
                            }
                        }
                    }

                    // Presentation Mode Toggle
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: DesignTokens.radiusMD
                        color: root.presentationMode
                            ? ColorScheme.withAlpha(ColorScheme.teal, 0.25)
                            : ColorScheme.withAlpha(ColorScheme.text, 0.08)
                        border.color: root.presentationMode ? ColorScheme.teal : ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\u{f26c}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: root.presentationMode ? ColorScheme.teal : ColorScheme.text
                            }
                            Text {
                                text: root.presentationMode ? "Apresentação ON" : "Apresentação"
                                font.pixelSize: 10
                                font.bold: root.presentationMode
                                color: root.presentationMode ? ColorScheme.teal : ColorScheme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UtilityService.togglePresentationMode()
                        }
                    }
                }
            }
        }
    }
}
