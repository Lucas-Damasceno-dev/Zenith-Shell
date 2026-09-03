pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../core"

Item {
    id: root

    visible: false

    property int cliVolume: 0
    property bool cliMuted: false
    property bool cliReady: false
    property int cliSourceVolume: 0
    property bool cliSourceMuted: false
    property bool cliSourceReady: false
    readonly property int fallbackPollIntervalMs: FeatureFlags.lowPowerUiMode ? 5000 : 2000

    readonly property bool pwSinkReady: {
        if (!(Pipewire.ready && Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio))
            return false;
        var raw = Pipewire.defaultAudioSink.audio.volume;
        return typeof raw === "number" && isFinite(raw) && !isNaN(raw) && raw >= 0;
    }

    readonly property real pwVolume: {
        if (!pwSinkReady)
            return -1;
        var v = Number(Pipewire.defaultAudioSink.audio.volume || 0);
        if (!isFinite(v) || isNaN(v))
            return -1;
        return v;
    }

    readonly property bool pwSourceReady: {
        if (!(Pipewire.ready && Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio))
            return false;
        var raw = Pipewire.defaultAudioSource.audio.volume;
        return typeof raw === "number" && isFinite(raw) && !isNaN(raw) && raw >= 0;
    }

    readonly property real pwSourceVolume: {
        if (!pwSourceReady)
            return -1;
        var v = Number(Pipewire.defaultAudioSource.audio.volume || 0);
        if (!isFinite(v) || isNaN(v))
            return -1;
        return v;
    }

    readonly property bool pwMuted: {
        if (!(Pipewire.ready && Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio))
            return false;
        return Pipewire.defaultAudioSink.audio.muted === true;
    }

    readonly property bool pwSourceMuted: {
        if (!(Pipewire.ready && Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio))
            return false;
        return Pipewire.defaultAudioSource.audio.muted === true;
    }

    readonly property bool hasSinkReady: cliReady || pwSinkReady || (Pipewire.ready && !!Pipewire.defaultAudioSink)
    readonly property bool hasSourceReady: cliSourceReady || pwSourceReady || (Pipewire.ready && !!Pipewire.defaultAudioSource)

    readonly property int volume: {
        if (cliReady)
            return cliVolume;
        if (pwSinkReady && pwVolume >= 0)
            return Math.round(Math.max(0, Math.min(pwVolume, 1.5)) * 100);
        return 0;
    }

    readonly property bool muted: {
        if (cliReady)
            return cliMuted;
        if (pwSinkReady)
            return pwMuted;
        return false;
    }

    readonly property int sourceVolume: {
        if (cliSourceReady)
            return cliSourceVolume;
        if (pwSourceReady && pwSourceVolume >= 0)
            return Math.round(Math.max(0, Math.min(pwSourceVolume, 1.5)) * 100);
        return 0;
    }

    readonly property bool sourceMuted: {
        if (cliSourceReady)
            return cliSourceMuted;
        if (pwSourceReady)
            return pwSourceMuted;
        return false;
    }

    function syncFromPipewire() {
        if (!pwSinkReady)
            return false;
        cliVolume = Math.round(Math.max(0, Math.min(pwVolume, 1.5)) * 100);
        cliMuted = pwMuted;
        cliReady = true;
        return true;
    }

    function syncSourceFromPipewire() {
        if (!pwSourceReady)
            return false;
        cliSourceVolume = Math.round(Math.max(0, Math.min(pwSourceVolume, 1.5)) * 100);
        cliSourceMuted = pwSourceMuted;
        cliSourceReady = true;
        return true;
    }

    function refreshCliStatus() {
        cliStatusProc.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
        cliSourceStatusProc.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]);
    }

    function setSinkVolumeRatio(value) {
        var ratio = Math.max(0, Math.min(Number(value || 0), 1.5));
        cliVolume = Math.round(ratio * 100);
        cliReady = true;
        cliActionProc.exec(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", ratio.toFixed(2)]);
    }

    function toggleSinkMute() {
        cliMuted = !cliMuted;
        cliReady = true;
        cliActionProc.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }

    function setSourceVolumeRatio(value) {
        var ratio = Math.max(0, Math.min(Number(value || 0), 1.5));
        cliSourceVolume = Math.round(ratio * 100);
        cliSourceReady = true;
        cliActionProc.exec(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SOURCE@", ratio.toFixed(2)]);
    }

    function toggleSourceMute() {
        cliSourceMuted = !cliSourceMuted;
        cliSourceReady = true;
        cliActionProc.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
    }

    TimedProcess {
        id: cliStatusProc
        timeoutMs: 3000

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    var m = line.match(/Volume:\s+([0-9.]+)(?:\s+\[(MUTED)\])?/);
                    if (!m)
                        continue;

                    root.cliVolume = Math.round(Number(m[1]) * 100);
                    root.cliMuted = (m[2] === "MUTED");
                    root.cliReady = true;
                    break;
                }
            }
        }
    }

    TimedProcess {
        id: cliSourceStatusProc
        timeoutMs: 3000

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    var m = line.match(/Volume:\s+([0-9.]+)(?:\s+\[(MUTED)\])?/);
                    if (!m)
                        continue;

                    root.cliSourceVolume = Math.round(Number(m[1]) * 100);
                    root.cliSourceMuted = (m[2] === "MUTED");
                    root.cliSourceReady = true;
                    break;
                }
            }
        }
    }

    TimedProcess {
        id: cliActionProc
        timeoutMs: 3000
        onExited: root.refreshCliStatus()
    }

    Timer {
        id: cliRefreshTimer
        interval: root.fallbackPollIntervalMs
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshCliStatus()
    }

    Component.onCompleted: root.refreshCliStatus()

    Connections {
        target: Pipewire

        function onReadyChanged() {
            root.refreshCliStatus();
        }

        function onDefaultAudioSinkChanged() {
            root.refreshCliStatus();
        }

        function onDefaultAudioSourceChanged() {
            root.refreshCliStatus();
        }
    }

    Connections {
        target: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio : null

        function onVolumeChanged() {
            root.syncFromPipewire();
        }

        function onMutedChanged() {
            root.syncFromPipewire();
        }
    }

    Connections {
        target: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio : null

        function onVolumeChanged() {
            root.syncSourceFromPipewire();
        }

        function onMutedChanged() {
            root.syncSourceFromPipewire();
        }
    }
}
