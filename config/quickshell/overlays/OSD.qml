import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../core"
import "../services"

/**
 * OSD - Unified, Zero-Latency On-Screen Display
 *
 * Implements optimistic UI predictions + coalesced background syncing
 * for instant sub-millisecond response across volume, mic, brightness,
 * and system indicators.
 */
PanelWindow {
    id: root

    anchors {
        bottom: true
        left: true
        right: true
    }

    implicitHeight: 96
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-tooltip"

    visible: root.active || contentRect.opacity > 0.01

    // Central state
    property string osdType: "volume" // "volume" | "microphone" | "brightness" | "kbdbrightness" | "power-profile" | "capslock"
    property string currentIcon: "\u{f028}"
    property real currentValue: 0.0
    property string statusText: ""
    property string deviceSubtitle: ""
    property bool isMuted: false
    property bool active: false
    property int pulseToken: 0

    // Anti-storm coalescing flags
    property bool _fetchingVolume: false
    property bool _queuedVolumeFetch: false
    property bool _fetchingMic: false
    property bool _queuedMicFetch: false
    property bool _fetchingBrightness: false
    property bool _queuedBrightnessFetch: false
    property int maxBrightness: 255

    // Auto-hide timer
    Timer {
        id: hideTimer
        interval: 1800
        repeat: false
        onTriggered: root.active = false
    }

    function show(icon, value, textLabel, devSubtitle, muted, type) {
        currentIcon = icon || "\u{f028}";
        let v = (typeof value === "number" && !isNaN(value) && isFinite(value)) ? value : 0.0;
        currentValue = Math.min(Math.max(v, 0.0), 1.5);
        statusText = String(textLabel || "");
        deviceSubtitle = String(devSubtitle || "");
        isMuted = muted === true;
        osdType = type || "volume";
        pulseToken++;
        root.active = true;
        hideTimer.restart();
    }

    function triggerVolume(deltaPayload) {
        var delta = Number(deltaPayload);
        var curVol = (AudioStatusService.cliReady ? AudioStatusService.cliVolume : AudioStatusService.volume) / 100.0;
        if (isFinite(delta) && !isNaN(delta) && delta !== 0) {
            curVol = Math.max(0, Math.min(1.5, curVol + delta));
            AudioStatusService.cliVolume = Math.round(curVol * 100);
            AudioStatusService.cliReady = true;
        }

        var isMuted = AudioStatusService.muted;
        var ic = isMuted ? "\u{f0580}" : (curVol > 0.66 ? "\u{f028}" : (curVol > 0.33 ? "\u{f027}" : "\u{f026}"));
        var devDesc = "";
        var pwSink = (typeof Pipewire !== "undefined" && Pipewire.defaultAudioSink) ? Pipewire.defaultAudioSink : null;
        
        if (pwSink) {
            var desc = String(pwSink.description || pwSink.name || "").toLowerCase();
            var formFactor = String((pwSink.properties && pwSink.properties["device.form_factor"]) || "").toLowerCase();
            var iconName = String((pwSink.properties && pwSink.properties["device.icon_name"]) || "").toLowerCase();
            devDesc = pwSink.description || pwSink.name || "";
            
            if (iconName.indexOf("bluetooth") !== -1 || desc.indexOf("bluez") !== -1 || desc.indexOf("bluetooth") !== -1 || desc.indexOf("wh-") !== -1 || desc.indexOf("airpod") !== -1 || desc.indexOf("buds") !== -1) {
                ic = "\u{f00af}";
            } else if (formFactor === "headphone" || formFactor === "headset" || desc.indexOf("headphone") !== -1 || desc.indexOf("fone") !== -1 || desc.indexOf("headset") !== -1) {
                ic = "\u{f025}";
            } else if (desc.indexOf("hdmi") !== -1 || desc.indexOf("displayport") !== -1 || desc.indexOf("tv") !== -1) {
                ic = "\u{f026c}";
            }
        }
        if (isMuted) {
            ic = "\u{f0580}";
        }
        var label = isMuted ? "Mudo" : (Math.round(curVol * 100) + "%");

        // 1. Instantaneous 0ms render
        show(ic, curVol, label, devDesc, isMuted, "volume");

        // 2. Coalesced background exact hardware sync
        if (_fetchingVolume) {
            _queuedVolumeFetch = true;
            return;
        }
        _fetchingVolume = true;
        getCurVolume.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
    }

    TimedProcess {
        id: getCurVolume
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(text || "").split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    var m = line.match(/Volume:\s+([0-9.]+)(?:\s+\[(MUTED)\])?/);
                    if (m) {
                        var vol = Number(m[1]);
                        var isMuted = (m[2] === "MUTED");
                        AudioStatusService.cliVolume = Math.round(vol * 100);
                        AudioStatusService.cliMuted = isMuted;
                        AudioStatusService.cliReady = true;
                        
                        var ic = isMuted ? "\u{f0580}" : (vol > 0.66 ? "\u{f028}" : (vol > 0.33 ? "\u{f027}" : "\u{f026}"));
                        var devDesc = "";
                        var pwSink = (typeof Pipewire !== "undefined" && Pipewire.defaultAudioSink) ? Pipewire.defaultAudioSink : null;
                        
                        if (pwSink) {
                            var desc = String(pwSink.description || pwSink.name || "").toLowerCase();
                            var formFactor = String((pwSink.properties && pwSink.properties["device.form_factor"]) || "").toLowerCase();
                            var iconName = String((pwSink.properties && pwSink.properties["device.icon_name"]) || "").toLowerCase();
                            devDesc = pwSink.description || pwSink.name || "";
                            
                            if (iconName.indexOf("bluetooth") !== -1 || desc.indexOf("bluez") !== -1 || desc.indexOf("bluetooth") !== -1 || desc.indexOf("wh-") !== -1 || desc.indexOf("airpod") !== -1 || desc.indexOf("buds") !== -1) {
                                ic = "\u{f00af}";
                            } else if (formFactor === "headphone" || formFactor === "headset" || desc.indexOf("headphone") !== -1 || desc.indexOf("fone") !== -1 || desc.indexOf("headset") !== -1) {
                                ic = "\u{f025}";
                            } else if (desc.indexOf("hdmi") !== -1 || desc.indexOf("displayport") !== -1 || desc.indexOf("tv") !== -1) {
                                ic = "\u{f026c}";
                            }
                        }

                        if (isMuted) {
                            ic = "\u{f0580}";
                        }

                        var label = isMuted ? "Mudo" : (Math.round(vol * 100) + "%");
                        root.show(ic, vol, label, devDesc, isMuted, "volume");
                        break;
                    }
                }
            }
        }
        onExited: {
            root._fetchingVolume = false;
            if (root._queuedVolumeFetch) {
                root._queuedVolumeFetch = false;
                root.triggerVolume();
            }
        }
    }

    function triggerMicrophone(deltaPayload) {
        var delta = Number(deltaPayload);
        var curVol = (AudioStatusService.cliSourceReady ? AudioStatusService.cliSourceVolume : AudioStatusService.sourceVolume) / 100.0;
        if (isFinite(delta) && !isNaN(delta) && delta !== 0) {
            curVol = Math.max(0, Math.min(1.5, curVol + delta));
            AudioStatusService.cliSourceVolume = Math.round(curVol * 100);
            AudioStatusService.cliSourceReady = true;
        }

        var isMuted = AudioStatusService.sourceMuted;
        var ic = isMuted ? "\u{f131}" : "\u{f130}";
        var label = isMuted ? "Mic Mudo" : (Math.round(curVol * 100) + "%");
        var devDesc = "";
        var pwSource = (typeof Pipewire !== "undefined" && Pipewire.defaultAudioSource) ? Pipewire.defaultAudioSource : null;
        if (pwSource) {
            devDesc = pwSource.description || pwSource.name || "";
        }

        // 1. Instantaneous 0ms render
        show(ic, curVol, label, devDesc, isMuted, "microphone");

        // 2. Coalesced background exact hardware sync
        if (_fetchingMic) {
            _queuedMicFetch = true;
            return;
        }
        _fetchingMic = true;
        getCurMic.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]);
    }

    TimedProcess {
        id: getCurMic
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(text || "").split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    var m = line.match(/Volume:\s+([0-9.]+)(?:\s+\[(MUTED)\])?/);
                    if (m) {
                        var vol = Number(m[1]);
                        var isMuted = (m[2] === "MUTED");
                        AudioStatusService.cliSourceVolume = Math.round(vol * 100);
                        AudioStatusService.cliSourceMuted = isMuted;
                        AudioStatusService.cliSourceReady = true;

                        var ic = isMuted ? "\u{f131}" : "\u{f130}";
                        var label = isMuted ? "Mic Mudo" : (Math.round(vol * 100) + "%");
                        var devDesc = "";
                        var pwSource = (typeof Pipewire !== "undefined" && Pipewire.defaultAudioSource) ? Pipewire.defaultAudioSource : null;
                        if (pwSource) {
                            devDesc = pwSource.description || pwSource.name || "";
                        }
                        root.show(ic, vol, label, devDesc, isMuted, "microphone");
                        break;
                    }
                }
            }
        }
        onExited: {
            root._fetchingMic = false;
            if (root._queuedMicFetch) {
                root._queuedMicFetch = false;
                root.triggerMicrophone();
            }
        }
    }

    function triggerBrightness(deltaPayload) {
        var delta = Number(deltaPayload);
        if (isFinite(delta) && !isNaN(delta) && delta !== 0 && root.maxBrightness > 0) {
            var cur = (root.currentValue || 0.5) + delta;
            cur = Math.min(1.0, Math.max(0.0, cur));
            var label = Math.round(cur * 100) + "%";
            show("\u{f185}", cur, label, "Tela", false, "brightness");
        }

        if (_fetchingBrightness) {
            _queuedBrightnessFetch = true;
            return;
        }
        _fetchingBrightness = true;
        getCurBright.exec(["brightnessctl", "g"]);
    }

    TimedProcess {
        id: getMaxBright
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let val = parseInt(String(text || "").trim());
                if (!isNaN(val) && val > 0) {
                    root.maxBrightness = val;
                    root.triggerBrightness();
                }
            }
        }
    }

    Component.onCompleted: getMaxBright.exec(["brightnessctl", "m"])

    TimedProcess {
        id: getCurBright
        stdout: StdioCollector {
            onStreamFinished: {
                let val = parseInt(String(text || "").trim());
                if (isNaN(val)) val = 0;
                if (root.maxBrightness <= 0) root.maxBrightness = 255;
                let newPercent = Math.min(1.0, Math.max(0.0, val / root.maxBrightness));
                let label = Math.round(newPercent * 100) + "%";
                root.show("\u{f185}", newPercent, label, "Tela", false, "brightness");
            }
        }
        onExited: {
            root._fetchingBrightness = false;
            if (root._queuedBrightnessFetch) {
                root._queuedBrightnessFetch = false;
                root.triggerBrightness();
            }
        }
    }

    function triggerKbdBrightness() {
        getCurKbdBright.exec(["brightnessctl", "--device=*kbd*", "g"]);
    }

    TimedProcess {
        id: getCurKbdBright
        stdout: StdioCollector {
            onStreamFinished: {
                let val = parseInt(String(text || "").trim());
                if (isNaN(val)) val = 0;
                let newPercent = Math.min(1.0, Math.max(0.0, val / 3.0));
                let label = Math.round(newPercent * 100) + "%";
                root.show("\u{f11c}", newPercent, label, "Teclado", false, "kbdbrightness");
            }
        }
    }

    function triggerPowerProfile(profileKey) {
        var key = String(profileKey || BatteryStatsService.powerProfile || "balanced");
        var icon = "\u{f24e}";
        var label = "Equilibrado";
        var value = 0.66;
        if (key === "power-saver") {
            icon = "\u{f06c}";
            label = "Economia";
            value = 0.33;
        } else if (key === "performance") {
            icon = "\u{f135}";
            label = "Performance";
            value = 1.0;
        }
        show(icon, value, label, "Perfil de Energia", false, "power-profile");
    }

    function triggerCapsLock(enabled) {
        var icon = "\u{f022}";
        var label = enabled ? "ATIVADO" : "DESATIVADO";
        show(icon, enabled ? 1.0 : 0.0, label, "Caps Lock", !enabled, "capslock");
    }

    Rectangle {
        id: contentRect
        width: root.deviceSubtitle !== "" ? 310 : 270
        height: 50
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        radius: DesignTokens.radiusLG
        color: ColorScheme.withAlpha(ColorScheme.background, 0.76)
        border.color: root.isMuted
            ? ColorScheme.withAlpha(ColorScheme.red, 0.40)
            : (root.currentValue > 1.0 ? ColorScheme.withAlpha(ColorScheme.yellow, 0.40) : ColorScheme.glassBorder)
        border.width: 1

        opacity: root.active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
        }

        transform: [
            Translate {
                y: root.active ? 0 : 35
                Behavior on y {
                    SpringAnimation { spring: 8.5; damping: 0.70; epsilon: 0.1 }
                }
            },
            Scale {
                id: pillScale
                origin.x: contentRect.width / 2
                origin.y: contentRect.height / 2
                xScale: 1.0
                yScale: 1.0
            }
        ]

        // Micro-pulse animation on consecutive inputs
        SequentialAnimation {
            id: pulseAnim
            PropertyAnimation { target: pillScale; property: "xScale"; to: 1.025; duration: 25; easing.type: Easing.OutQuad }
            PropertyAnimation { target: pillScale; property: "yScale"; to: 1.025; duration: 25; easing.type: Easing.OutQuad }
            PropertyAnimation { target: pillScale; property: "xScale"; to: 1.0; duration: 60; easing.type: Easing.OutBack }
            PropertyAnimation { target: pillScale; property: "yScale"; to: 1.0; duration: 60; easing.type: Easing.OutBack }
        }

        Connections {
            target: root
            function onPulseTokenChanged() {
                if (root.active) {
                    pulseAnim.restart();
                }
            }
        }

        // Drop shadow
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.22)
            z: -1
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 16
            spacing: 10

            // Icon with circular container
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: root.isMuted
                    ? ColorScheme.withAlpha(ColorScheme.red, 0.16)
                    : (root.currentValue > 1.0 ? ColorScheme.withAlpha(ColorScheme.yellow, 0.16) : ColorScheme.withAlpha(ColorScheme.accent, 0.14))

                Text {
                    anchors.centerIn: parent
                    text: root.currentIcon
                    color: root.isMuted
                        ? ColorScheme.red
                        : (root.currentValue > 1.0 ? ColorScheme.yellow : ColorScheme.accent)
                    font.family: DesignTokens.fontFamilyMono
                    font.pixelSize: 16
                    Behavior on color { ColorAnimation { duration: 70 } }
                }
            }

            // Middle Column: Subtitle + Progress Bar
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                // Device subtitle chip (if any)
                Text {
                    visible: root.deviceSubtitle !== ""
                    text: root.deviceSubtitle
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                    font.pixelSize: 9
                    font.family: DesignTokens.fontFamilyUI
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Dual-zone progress bar (0-100% normal, 100-150% over-amplification)
                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.10)
                    clip: true

                    // Active Fill (0 to 100%)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: root.isMuted ? 0 : Math.min(parent.width, parent.width * Math.min(1.0, root.currentValue))
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: ColorScheme.accent }
                            GradientStop { position: 1.0; color: root.currentValue > 1.0 ? ColorScheme.accentAlt : ColorScheme.accent }
                        }
                        Behavior on width {
                            NumberAnimation { duration: 60; easing.type: Easing.OutCubic }
                        }
                    }

                    // Over-amplification segment (100% to 150%)
                    Rectangle {
                        visible: root.currentValue > 1.0 && !root.isMuted
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: parent.width * (1.0 / 1.5)
                        width: Math.max(0, parent.width * ((root.currentValue - 1.0) / 1.5))
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: ColorScheme.yellow }
                            GradientStop { position: 1.0; color: ColorScheme.peach }
                        }
                        Behavior on width {
                            NumberAnimation { duration: 60; easing.type: Easing.OutCubic }
                        }
                    }

                    // 100% Tick Mark indicator (visible if max volume is 1.5)
                    Rectangle {
                        visible: root.osdType === "volume" || root.osdType === "microphone"
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        x: parent.width * (1.0 / 1.5) - 1
                        width: 2
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.40)
                        z: 2
                    }
                }
            }

            // Value label / Status Text
            Text {
                text: root.statusText
                color: root.isMuted
                    ? ColorScheme.red
                    : (root.currentValue > 1.0 ? ColorScheme.yellow : ColorScheme.text)
                font.pixelSize: 12
                font.weight: Font.Bold
                font.family: DesignTokens.fontFamilyUI
                font.letterSpacing: DesignTokens.letterSpacingBadge
                Layout.preferredWidth: 64
                horizontalAlignment: Text.AlignRight
                Behavior on color { ColorAnimation { duration: 90 } }
            }
        }
    }
}
