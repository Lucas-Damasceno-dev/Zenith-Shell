pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * PrivacyService - Monitor reativo de alta eficiência para dispositivos de privacidade (Mic, Câmera, Screencast).
 * Integra-se aos nós do PipeWire e processos de gravação via privacy_snapshot.sh.
 */
Singleton {
    id: root

    readonly property bool micActive: _micActive
    readonly property bool cameraActive: _cameraActive
    readonly property bool screenShareActive: _screenShareActive
    readonly property bool anyActive: _micActive || _cameraActive || _screenShareActive
    readonly property int activeCount: (_micActive ? 1 : 0) + (_cameraActive ? 1 : 0) + (_screenShareActive ? 1 : 0)

    readonly property var micApps: _micApps
    readonly property var cameraApps: _cameraApps
    readonly property var screenApps: _screenApps

    readonly property string micAppsText: _micApps.length > 0 ? _micApps.join(", ") : ""
    readonly property string cameraAppsText: _cameraApps.length > 0 ? _cameraApps.join(", ") : ""
    readonly property string screenAppsText: _screenApps.length > 0 ? _screenApps.join(", ") : ""

    readonly property int activePollIntervalMs: FeatureFlags.lowPowerUiMode ? 5000 : 3000
    readonly property int idlePollIntervalMs: FeatureFlags.lowPowerUiMode ? 16000 : 10000
    readonly property int pollIntervalMs: root.anyActive ? root.activePollIntervalMs : root.idlePollIntervalMs

    readonly property string activeDevices: {
        var devices = [];
        if (_micActive) devices.push("Microphone" + (_micApps.length > 0 ? " (" + root.micAppsText + ")" : ""));
        if (_cameraActive) devices.push("Camera" + (_cameraApps.length > 0 ? " (" + root.cameraAppsText + ")" : ""));
        if (_screenShareActive) devices.push("Screen Share" + (_screenApps.length > 0 ? " (" + root.screenAppsText + ")" : ""));
        return devices.join(" | ");
    }

    readonly property string summaryTooltip: {
        if (!root.anyActive) return "Privacidade protegida: nenhum dispositivo em uso";
        var parts = [];
        if (_micActive) {
            parts.push("🎤 Microfone ativo: " + (_micApps.length > 0 ? root.micAppsText : "Em uso"));
        }
        if (_cameraActive) {
            parts.push("📷 Câmera ativa: " + (_cameraApps.length > 0 ? root.cameraAppsText : "Em uso"));
        }
        if (_screenShareActive) {
            parts.push("🖥️ Gravação/Tela ativa: " + (_screenApps.length > 0 ? root.screenAppsText : "Em uso"));
        }
        return parts.join("\n") + "\n\n• Botão Direito: alternar mudo do microfone";
    }

    readonly property string icon: {
        if (_screenShareActive) return "\u{f03d}";
        if (_cameraActive) return "\u{f030}";
        if (_micActive) return "\u{f130}";
        return "";
    }

    property bool _micActive: false
    property bool _cameraActive: false
    property bool _screenShareActive: false
    property var _micApps: []
    property var _cameraApps: []
    property var _screenApps: []
    property bool _checking: false

    function refresh() {
        if (_checking) return;
        _checking = true;
        privacyCheckProc.exec([
            "bash",
            RuntimePaths.scriptFile("privacy_snapshot.sh")
        ]);
    }

    function toggleMicMute() {
        actionProc.exec([
            "wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"
        ]);
        Qt.callLater(root.refresh);
    }

    function stopRecordings() {
        actionProc.exec([
            "killall", "-INT", "wf-recorder", "gpu-screen-recorder", "wl-screenrec", "kooha"
        ]);
        Qt.callLater(root.refresh);
    }

    function applyState(rawText) {
        if (!rawText || String(rawText).trim() === "") return;
        try {
            var data = JSON.parse(String(rawText).trim());
            root._micActive = !!(data.mic && data.mic.active);
            root._micApps = (data.mic && Array.isArray(data.mic.apps)) ? data.mic.apps : [];

            root._cameraActive = !!(data.camera && data.camera.active);
            root._cameraApps = (data.camera && Array.isArray(data.camera.apps)) ? data.camera.apps : [];

            root._screenShareActive = !!(data.screen && data.screen.active);
            root._screenApps = (data.screen && Array.isArray(data.screen.apps)) ? data.screen.apps : [];
        } catch (e) {
            Logger.warn("PrivacyService", "Falha ao analisar JSON de privacidade: " + e);
        }
    }

    Timer {
        id: pollTimer
        interval: root.pollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    TimedProcess {
        id: privacyCheckProc
        timeoutMs: 2500
        stdout: StdioCollector {
            onStreamFinished: {
                root._checking = false;
                root.applyState(text);
            }
        }
        onFailed: function(code) {
            root._checking = false;
            Logger.warn("PrivacyService", "Check failed with code: " + code);
        }
        onTimedOut: {
            root._checking = false;
        }
        onExited: {
            root._checking = false;
        }
    }

    TimedProcess {
        id: actionProc
        timeoutMs: 1500
    }

    Component.onCompleted: Qt.callLater(root.refresh)
}
