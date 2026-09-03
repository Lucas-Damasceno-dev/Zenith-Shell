import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../core"
import "../services"

ColumnLayout {
    id: root
    spacing: DesignTokens.spacingMD

    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.text
    readonly property color secondaryTextColor: Style.muted
    readonly property color subtleTextColor: ColorScheme.withAlpha(textColor, 0.42)
    readonly property color cardFill: ColorScheme.withAlpha(ColorScheme.surface, 0.24)
    readonly property color cardBorder: ColorScheme.withAlpha(ColorScheme.text, 0.06)
    property var settingsStore
    property var presets: ({})
    property var recentlySavedMap: ({})

    function streamDetailsFor(stream) {
        if (!stream) return { appName: "Aplicativo", mediaTitle: "", subtitle: "Áudio" };
        var app = "";
        var binary = "";
        var mediaTitle = "";
        var mediaArtist = "";

        if (stream.properties) {
            app = String(stream.properties["application.name"] || "").trim();
            binary = String(stream.properties["application.process.binary"] || "").trim();
            mediaTitle = String(stream.properties["media.title"] || stream.properties["media.name"] || "").trim();
            mediaArtist = String(stream.properties["media.artist"] || "").trim();
        }

        if (!app) {
            app = binary || String(stream.description || stream.name || "Aplicativo").trim();
        }

        // Cross-reference with MPRIS for rich track/video title info (YouTube, Spotify, etc.)
        var mprisTrack = "";
        var mprisArtist = "";
        var resolvedPlayer = null;
        if (typeof Mpris !== "undefined" && Mpris.players) {
            var players = Mpris.players.values || [];
            var appLower = app.toLowerCase();
            var binLower = binary.toLowerCase();
            for (var i = 0; i < players.length; i++) {
                var p = players[i];
                if (!p) continue;
                var pId = String(p.identity || "").toLowerCase();
                var pDesk = String(p.desktopEntry || "").toLowerCase();
                var pDbus = String(p.dbusName || "").toLowerCase();

                if (pId.includes(appLower) || pDesk.includes(binLower) || pDbus.includes(binLower) || appLower.includes(pId)) {
                    var t = String(p.trackTitle || "").trim();
                    var a = String(p.trackArtist || "").trim();
                    resolvedPlayer = p;
                    if (t && t !== "Playback") {
                        mprisTrack = t;
                        mprisArtist = a;
                        break;
                    }
                }
            }
        }

        var resolvedTitle = mprisTrack || mediaTitle;
        if (resolvedTitle === "Playback" || resolvedTitle === "ALSA Playback" || resolvedTitle === "AudioStream") {
            resolvedTitle = "";
        }

        var resolvedArtist = mprisArtist || mediaArtist;
        var sub = "";
        if (resolvedTitle && resolvedArtist) {
            sub = resolvedArtist;
        } else if (resolvedTitle) {
            sub = app;
        } else {
            sub = "Reprodução de áudio";
        }

        return {
            appName: app,
            mediaTitle: resolvedTitle,
            subtitle: sub,
            fullDisplay: resolvedTitle ? (app + " • " + resolvedTitle) : app,
            mprisPlayer: resolvedPlayer
        };
    }

    function appNameFor(stream) {
        return streamDetailsFor(stream).appName;
    }

    function loadPresets() {
        if (!settingsStore || !settingsStore.ready) return;
        var raw = settingsStore.get("audioAppMixerPresetsJson", ({}));
        if (typeof raw === "string") {
            try { presets = JSON.parse(raw); } catch (e) { presets = ({}); }
        } else if (raw && typeof raw === "object") {
            presets = raw;
        } else {
            presets = ({});
        }
    }

    function persistPresets() {
        if (!settingsStore || !settingsStore.ready) return;
        settingsStore.set("audioAppMixerPresetsJson", presets);
    }

    readonly property var audioStreams: {
        if (!Pipewire.nodes) return [];
        var allNodes = Pipewire.nodes.values || [];
        var filtered = [];
        for (var i = 0; i < allNodes.length; i++) {
            var node = allNodes[i];
            if (!node || !node.audio) continue;
            if (node.isStream === true) {
                filtered.push(node);
            } else if (!node.isSink) {
                var mc = String((node.properties && node.properties["media.class"]) || "");
                var app = String((node.properties && node.properties["application.name"]) || "");
                if (mc.indexOf("Stream/") === 0 || (app !== "" && !AudioPopupUtils.isMonitorSource(node))) {
                    filtered.push(node);
                }
            }
        }
        return filtered;
    }

    function applyPreset(stream) {
        if (!stream || !stream.audio) return;
        var key = appNameFor(stream);
        if (key === "" || !presets[key]) return;
        var item = presets[key];
        
        if (item.volume !== undefined) {
            var v = Number(item.volume);
            if (!isNaN(v) && Math.abs((stream.audio.volume || 0) - v) > 0.001) {
                setAppVolume(stream, Math.max(0, Math.min(1.5, v)));
            }
        }
        
        if (item.muted !== undefined) {
            var m = item.muted === true;
            if (stream.audio.muted !== m) {
                setAppMute(stream, m);
            }
        }
    }

    property var streamMuteMap: ({})

    function isStreamMuted(stream) {
        if (!stream || stream.id === undefined) return false;
        if (streamMuteMap[stream.id] !== undefined) {
            return streamMuteMap[stream.id] === true;
        }
        if (stream.audio && typeof stream.audio.muted === "boolean") {
            return stream.audio.muted === true;
        }
        return false;
    }

    TimedProcess {
        id: cliAppMuteProc
        timeoutMs: 2000
    }

    TimedProcess {
        id: cliAppVolProc
        timeoutMs: 2000
    }

    property var streamVolumeMap: ({})

    function getAppVolume(stream) {
        if (!stream || stream.id === undefined) return 1.0;
        if (streamVolumeMap[stream.id] !== undefined) {
            return Number(streamVolumeMap[stream.id]);
        }
        if (stream.audio && typeof stream.audio.volume === "number" && stream.audio.volume > 0.001) {
            return Number(stream.audio.volume);
        }
        return 1.0;
    }

    function setAppVolume(stream, value) {
        if (!stream || stream.id === undefined) return;
        var ratio = Math.max(0, Math.min(1.5, Number(value !== undefined ? value : 1.0)));

        var vMap = Object.assign({}, streamVolumeMap);
        vMap[stream.id] = ratio;
        streamVolumeMap = vMap;

        if (stream.audio) {
            stream.audio.volume = ratio;
        }

        cliAppVolProc.exec(["wpctl", "set-volume", "-l", "1.5", String(stream.id), ratio.toFixed(2)]);

        // Auto-unmute when moving volume slider above 0
        if (ratio > 0 && isStreamMuted(stream)) {
            setAppMute(stream, false);
        }
    }

    function setAppMute(stream, muted) {
        if (!stream || stream.id === undefined) return;
        var map = Object.assign({}, streamMuteMap);
        map[stream.id] = muted;
        streamMuteMap = map;

        if (stream.audio) {
            stream.audio.muted = muted;
            if (!muted && stream.audio.volume <= 0.01) {
                stream.audio.volume = 0.50;
                cliAppVolProc.exec(["wpctl", "set-volume", "-l", "1.5", String(stream.id), "0.50"]);
            }
        }
        cliAppMuteProc.exec(["wpctl", "set-mute", String(stream.id), muted ? "1" : "0"]);
    }

    function unmuteStream(stream) {
        setAppMute(stream, false);
    }

    function unmuteAllApps() {
        var streams = root.audioStreams;
        for (var i = 0; i < streams.length; i++) {
            var s = streams[i];
            setAppMute(s, false);
        }
    }

    function toggleAppMute(stream) {
        if (!stream || stream.id === undefined) return;
        var current = isStreamMuted(stream);
        setAppMute(stream, !current);
    }

    function savePreset(stream) {
        if (!stream || !stream.audio) return;
        var key = appNameFor(stream);
        if (key === "") return;
        presets[key] = {
            volume: Number(stream.audio.volume || 0),
            muted: stream.audio.muted === true
        };
        persistPresets();

        var updatedMap = Object.assign({}, root.recentlySavedMap);
        updatedMap[key] = true;
        root.recentlySavedMap = updatedMap;
        savedTimer.restart();
    }

    Timer {
        id: savedTimer
        interval: 2000
        repeat: false
        onTriggered: root.recentlySavedMap = ({})
    }

    Component.onCompleted: loadPresets()
    onSettingsStoreChanged: loadPresets()

    RowLayout {
        Layout.fillWidth: true
        visible: root.audioStreams.length > 0
        spacing: 8

        Text {
            text: "\u{f0550} Mixer de aplicativos"
            color: textColor
            font.bold: true
            font.pixelSize: DesignTokens.fontSizeMD
            font.family: Style.fontUI
            Layout.fillWidth: true
        }

        Rectangle {
            height: 24
            width: unmuteAllText.implicitWidth + 16
            radius: 12
            color: unmuteAllMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.25) : ColorScheme.withAlpha(ColorScheme.accent, 0.12)
            border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.30)
            border.width: 1

            RowLayout {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: "\u{f028}"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    color: ColorScheme.accent
                }
                Text {
                    id: unmuteAllText
                    text: "Desmutar todos"
                    font.pixelSize: 10
                    font.family: Style.fontUI
                    color: ColorScheme.accent
                    font.bold: true
                }
            }

            MouseArea {
                id: unmuteAllMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.unmuteAllApps()
            }
        }
    }

    Column {
        Layout.fillWidth: true
        Layout.topMargin: 20
        Layout.bottomMargin: 20
        spacing: 8
        visible: root.audioStreams.length === 0
        opacity: 0.55

        DynamicIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            iconSource: "file://" + RuntimePaths.quickshellDir + "/shared/icons/audio-output.svg"
            iconColor: ColorScheme.text
            size: 28
            fallbackGlyph: "\u{f0550}"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nenhum aplicativo reproduzindo áudio"
            color: ColorScheme.text
            font.pixelSize: 12
            font.family: "Inter"
        }
    }

    Repeater {
        id: appRepeater
        model: root.audioStreams

        delegate: Rectangle {
            id: appCard
            Layout.fillWidth: true
            implicitHeight: cardInnerCol.implicitHeight + DesignTokens.spacingLG * 2
            radius: DesignTokens.radiusMD
            color: root.cardFill
            border.color: isMuted ? ColorScheme.withAlpha(ColorScheme.red, 0.45) : root.cardBorder
            border.width: isMuted ? 1.5 : 1

            readonly property var details: root.streamDetailsFor(modelData)
            readonly property bool isInput: String((modelData && modelData.properties) ? modelData.properties["media.class"] : "").indexOf("Stream/Input") === 0
            readonly property bool isMuted: root.isStreamMuted(modelData)
            readonly property real currentVol: root.getAppVolume(modelData)
            readonly property bool isSaved: !!root.recentlySavedMap[details.appName]

            ColumnLayout {
                id: cardInnerCol
                anchors.fill: parent
                anchors.margins: DesignTokens.spacingLG
                spacing: 8

                // ─── Prominent Unmute Banner (when muted) ──────
                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: DesignTokens.radiusSM
                    color: ColorScheme.withAlpha(ColorScheme.red, 0.18)
                    border.color: ColorScheme.withAlpha(ColorScheme.red, 0.35)
                    border.width: 1
                    visible: isMuted

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "\u{f026}"
                            font.family: "JetBrainsMono Nerd Font"
                            color: ColorScheme.red
                            font.pixelSize: 11
                        }
                        Text {
                            text: "Aplicativo mutado — clique aqui para desmutar"
                            color: ColorScheme.red
                            font.pixelSize: 10
                            font.family: Style.fontUI
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.setAppMute(modelData, false)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: DesignTokens.spacingMD

                // ─── App Icon ─────────────────────────────────
                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    Layout.alignment: Qt.AlignTop
                    radius: DesignTokens.radiusMD
                    color: isMuted ? ColorScheme.withAlpha(ColorScheme.red, 0.14) : ColorScheme.withAlpha(accentColor, 0.14)
                    border.color: isMuted ? ColorScheme.withAlpha(ColorScheme.red, 0.25) : ColorScheme.withAlpha(accentColor, 0.18)
                    border.width: 1

                    DynamicIcon {
                        anchors.centerIn: parent
                        iconSource: {
                            var iconProp = (modelData.properties && modelData.properties["application.icon_name"]) || (modelData.properties && modelData.properties["application.icon.name"]);
                            if (iconProp) return "image://icon/" + iconProp;
                            var bin = String((modelData.properties && modelData.properties["application.process.binary"]) || "").toLowerCase();
                            if (bin === "brave") return "image://icon/brave-browser";
                            if (bin === "spotify") return "image://icon/spotify";
                            if (bin === "mpv") return "image://icon/mpv";
                            return isInput ? "file://" + RuntimePaths.quickshellDir + "/shared/icons/audio-input.svg" : "file://" + RuntimePaths.quickshellDir + "/shared/icons/audio-output.svg";
                        }
                        iconColor: isMuted ? ColorScheme.red : accentColor
                        fallbackGlyph: isInput ? "\u{f130}" : "\u{f028}"
                        size: 20
                    }
                }

                // ─── Content Details & Sliders ────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // App Name & Track/Video Title
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: DesignTokens.spacingSM

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: details.mediaTitle ? (details.appName + " — " + details.mediaTitle) : (details.appName + (isInput ? " (Gravação)" : ""))
                                    color: textColor
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: Style.fontUI
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                // Animated Soundwave Bars
                                Row {
                                    spacing: 2
                                    visible: details.mprisPlayer && details.mprisPlayer.playbackState === 1 && !isMuted
                                    Rectangle {
                                        width: 2; height: 10; radius: 1; color: accentColor
                                        SequentialAnimation on height {
                                            running: details.mprisPlayer && details.mprisPlayer.playbackState === 1 && !isMuted
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 4; duration: 280 }
                                            NumberAnimation { to: 12; duration: 280 }
                                        }
                                    }
                                    Rectangle {
                                        width: 2; height: 6; radius: 1; color: accentColor
                                        SequentialAnimation on height {
                                            running: details.mprisPlayer && details.mprisPlayer.playbackState === 1 && !isMuted
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 14; duration: 340 }
                                            NumberAnimation { to: 5; duration: 340 }
                                        }
                                    }
                                    Rectangle {
                                        width: 2; height: 8; radius: 1; color: accentColor
                                        SequentialAnimation on height {
                                            running: details.mprisPlayer && details.mprisPlayer.playbackState === 1 && !isMuted
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 3; duration: 300 }
                                            NumberAnimation { to: 10; duration: 300 }
                                        }
                                    }
                                }
                            }

                            Text {
                                text: details.subtitle
                                color: root.secondaryTextColor
                                font.pixelSize: 10
                                font.family: Style.fontUI
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: details.subtitle !== ""
                            }
                        }

                        Text {
                            text: isMuted ? "Mudo" : (Math.round(currentVol * 100) + "%")
                            color: isMuted ? ColorScheme.red : (currentVol > 1.0 ? ColorScheme.yellow : textColor)
                            font.pixelSize: 11
                            font.family: "Inter"
                            font.bold: true
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // Volume Slider with - / + step buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Step Minus Button
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: stepMinusMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.text, 0.15) : ColorScheme.withAlpha(ColorScheme.text, 0.08)
                            Text {
                                anchors.centerIn: parent
                                text: "-"
                                color: ColorScheme.text
                                font.pixelSize: 13
                                font.bold: true
                            }
                            MouseArea {
                                id: stepMinusMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setAppVolume(modelData, Math.max(0, currentVol - 0.05))
                            }
                        }

                        Slider {
                            id: volSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 1.5
                            stepSize: 0.01
                            value: currentVol
                            onMoved: root.setAppVolume(modelData, value)

                            background: Rectangle {
                                implicitHeight: 6
                                width: volSlider.availableWidth
                                height: implicitHeight
                                radius: 3
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.1)

                                Rectangle {
                                    width: volSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 3
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: isMuted ? ColorScheme.red : (volSlider.value > 1.0 ? ColorScheme.warningGradientStart : ColorScheme.accent) }
                                        GradientStop { position: 1.0; color: isMuted ? ColorScheme.red : (volSlider.value > 1.0 ? ColorScheme.warningGradientEnd : ColorScheme.accentAlt) }
                                    }
                                }
                            }

                            handle: Rectangle {
                                x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                                y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                implicitWidth: 14
                                implicitHeight: 14
                                radius: 7
                                color: isMuted ? ColorScheme.red : accentColor
                                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.15)
                                border.width: 1
                            }
                        }

                        // Step Plus Button
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: stepPlusMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.text, 0.15) : ColorScheme.withAlpha(ColorScheme.text, 0.08)
                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                color: ColorScheme.text
                                font.pixelSize: 13
                                font.bold: true
                            }
                            MouseArea {
                                id: stepPlusMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var nextVol = Math.min(1.5, currentVol + 0.05);
                                    root.setAppVolume(modelData, nextVol);
                                    if (nextVol > 0 && root.isStreamMuted(modelData)) {
                                        root.setAppMute(modelData, false);
                                    }
                                }
                            }
                        }
                    }

                    // Action Buttons (Mute, Save Preset, Preset Status)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: DesignTokens.spacingSM

                        // Play/Pause MPRIS Quick Control
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            visible: details.mprisPlayer !== null && details.mprisPlayer !== undefined
                            color: mprisMa.containsMouse ? ColorScheme.withAlpha(accentColor, 0.24) : ColorScheme.withAlpha(accentColor, 0.12)
                            border.color: ColorScheme.withAlpha(accentColor, 0.25)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: (details.mprisPlayer && details.mprisPlayer.playbackState === 1) ? "\u{f04c}" : "\u{f04b}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: accentColor
                            }

                            MouseArea {
                                id: mprisMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (details.mprisPlayer && typeof details.mprisPlayer.togglePlaying === "function") {
                                        details.mprisPlayer.togglePlaying();
                                    }
                                }
                            }
                        }

                        // Mute Toggle Button
                        Rectangle {
                            width: muteText.implicitWidth + 16
                            height: 24
                            radius: 12
                            color: muteMa.containsMouse
                                ? ColorScheme.withAlpha(isMuted ? ColorScheme.red : accentColor, 0.24)
                                : ColorScheme.withAlpha(isMuted ? ColorScheme.red : accentColor, 0.14)
                            border.color: ColorScheme.withAlpha(isMuted ? ColorScheme.red : accentColor, muteMa.containsMouse ? 0.40 : 0.22)
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: isMuted ? "\u{f026}" : "\u{f028}"
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: isMuted ? ColorScheme.red : accentColor
                                    font.pixelSize: 10
                                }
                                Text {
                                    id: muteText
                                    text: isMuted ? "Desmutar" : "Mutar"
                                    color: isMuted ? ColorScheme.red : accentColor
                                    font.pixelSize: DesignTokens.fontSizeXS
                                    font.family: Style.fontUI
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: muteMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleAppMute(modelData)
                            }
                        }

                        // Save Preset Button
                        Rectangle {
                            width: savePresetText.implicitWidth + (isSaved ? 20 : 16)
                            height: 24
                            radius: 12
                            color: isSaved
                                ? ColorScheme.withAlpha(ColorScheme.green, 0.24)
                                : (savePresetMa.containsMouse ? ColorScheme.withAlpha(accentColor, 0.24) : ColorScheme.withAlpha(accentColor, 0.12))
                            border.color: isSaved
                                ? ColorScheme.green
                                : ColorScheme.withAlpha(accentColor, savePresetMa.containsMouse ? 0.35 : 0.18)
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: isSaved ? "\u{f00c}" : "\u{f0c7}"
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: isSaved ? ColorScheme.green : accentColor
                                    font.pixelSize: 10
                                }
                                Text {
                                    id: savePresetText
                                    text: isSaved ? "Salvo!" : "Salvar preset"
                                    color: isSaved ? ColorScheme.green : accentColor
                                    font.pixelSize: DesignTokens.fontSizeXS
                                    font.family: Style.fontUI
                                    font.bold: isSaved
                                }
                            }

                            MouseArea {
                                id: savePresetMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.savePreset(modelData)
                            }
                        }

                        // Preset Badge if preset exists
                        Rectangle {
                            width: presetHint.implicitWidth + 14
                            height: 24
                            radius: 12
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.22)
                            border.color: root.cardBorder
                            border.width: 1
                            visible: !!root.presets[details.appName] && !isSaved

                            Text {
                                id: presetHint
                                anchors.centerIn: parent
                                text: root.presets[details.appName] && root.presets[details.appName].muted
                                    ? "Preset: mudo"
                                    : "Preset: " + Math.round((root.presets[details.appName] ? root.presets[details.appName].volume : 1) * 100) + "%"
                                color: root.secondaryTextColor
                                font.pixelSize: DesignTokens.fontSizeXS
                                font.family: Style.fontUI
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

            Component.onCompleted: root.applyPreset(modelData)
        }
    }
}
