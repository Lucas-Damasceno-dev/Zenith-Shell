import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../core"
import "../services"
import "../services/MprisUtils.js" as MprisUtils

PopupWindow {
    id: root
    property var settingsStore
    
    property bool showLyrics: false

            
    Behavior on implicitHeight { 
        NumberAnimation { duration: 400; easing.type: Easing.OutBack } 
    }

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    showScrim: false
    glassRadius: 0
    glassBackground: "transparent"
    glassBorderWidth: 0
    slideY: 15
    originY: 0.0
    originX: 0.5

    // ─── MPRIS Logic ───
    readonly property var allPlayers: MprisUtils.playerList(Mpris.players)
    readonly property var mprisPlayer: typeof shellRoot !== "undefined" && shellRoot ? shellRoot.activeMprisPlayer : null
    readonly property var effectivePlayer: mprisPlayer ? mprisPlayer : (allPlayers.length > 0 ? allPlayers[0] : null)
    readonly property bool hasMedia: !!(effectivePlayer && MprisUtils.hasPlayableMetadata(effectivePlayer))
    readonly property bool isPlaying: !!(effectivePlayer && effectivePlayer.playbackState === MprisPlaybackState.Playing)
    
    readonly property string trackTitle: hasMedia ? MprisUtils.titleForPlayer(effectivePlayer) : "Pausado"
    readonly property string trackArtist: hasMedia ? MprisUtils.artistForPlayer(effectivePlayer) : "Nenhuma música..."
    readonly property string trackArtUrl: hasMedia ? MprisUtils.artUrlForPlayer(effectivePlayer) : ""
    
    readonly property real durationMs: {
        if (!hasMedia || !effectivePlayer || effectivePlayer.length === undefined) return 0;
        let l = effectivePlayer.length;
        if (l > 10000000) return l / 1000;
        return l * 1000;
    }

    readonly property real mediaProgress: (durationMs > 0) ? Math.max(0, Math.min(1, syncedPosMs / durationMs)) : 0
    
    // Position Tracker
    property real syncedPosMs: 0
    Timer {
        id: posUpdateTimer
        interval: 500
        running: root.isOpen && root.isPlaying
        repeat: true
        onTriggered: {
            let rawPos = effectivePlayer ? effectivePlayer.position : 0;
            let realPosMs = (rawPos > 10000000) ? rawPos / 1000 : rawPos * 1000;
            let diff = Math.abs(realPosMs - syncedPosMs);
            if (diff > 2500) {
                syncedPosMs = realPosMs;
            } else {
                syncedPosMs += 500;
            }
        }
    }

    onIsPlayingChanged: {
        if (!effectivePlayer) return;
        let rawPos = effectivePlayer.position;
        syncedPosMs = (rawPos > 10000000) ? rawPos / 1000 : rawPos * 1000;
    }
    onTrackTitleChanged: { syncedPosMs = 0; currentLineIndex = -1; if(showLyrics) updateLyrics(); }
    onShowLyricsChanged: if(showLyrics) updateLyrics()
    onIsOpenChanged: if(isOpen && showLyrics) updateLyrics()

    // ─── Lyrics State ───
    property string lastFetchedTrack: ""
    property bool isFetchingLyrics: false
    property var lyricsModel: []
    property int currentLineIndex: -1

    function parseLRC(lrcText) {
        var lines = lrcText.split("\n");
        var model = [];
        var timeRegex = /\[(\d+):(\d+[\.:]\d+)\]/;
        for (var i = 0; i < lines.length; i++) {
            var match = lines[i].match(timeRegex);
            if (match) {
                var minutes = parseInt(match[1]);
                var secondsStr = match[2].replace(":", ".");
                var seconds = parseFloat(secondsStr);
                var timeMs = (minutes * 60 + seconds) * 1000;
                var text = lines[i].replace(timeRegex, "").trim();
                if (text !== "") model.push({ time: timeMs, text: text });
            } else {
                var plainText = lines[i].trim();
                if (plainText !== "" && plainText.indexOf("[") !== 0) model.push({ time: -1, text: plainText });
            }
        }
        model.sort((a, b) => a.time - b.time);
        return model;
    }

    function updateLyrics() {
        if (!hasMedia || !isOpen || !showLyrics) return;
        var trackId = trackArtist + " - " + trackTitle;
        if (trackId === lastFetchedTrack && lyricsModel.length > 1) return;
        lastFetchedTrack = trackId;
        isFetchingLyrics = true;
        lyricsModel = [{ time: 0, text: "Buscando letras..." }];
        lyricsProc.exec(["bash", RuntimePaths.scriptFile("fetch_lyrics.sh"), trackArtist, trackTitle]);
    }

    function syncLyrics() {
        if (lyricsModel.length <= 1) return;
        var bestIndex = -1;
        for (var i = 0; i < lyricsModel.length; i++) {
            if (lyricsModel[i].time === -1) continue;
            if (syncedPosMs >= lyricsModel[i].time) bestIndex = i;
            else break;
        }
        if (bestIndex !== currentLineIndex && bestIndex !== -1) {
            currentLineIndex = bestIndex;
            lyricsList.positionViewAtIndex(currentLineIndex, ListView.Center);
        }
    }

    onSyncedPosMsChanged: syncLyrics()

    TimedProcess {
        id: lyricsProc
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim();
                if (l === "LETRA_NAO_ENCONTRADA" || l === "LETRA_NAO_DISPONIVEL" || l === "" || l === "null") {
                    root.lyricsModel = [{ time: -1, text: "Letra não encontrada." }];
                } else {
                    root.lyricsModel = parseLRC(l);
                }
                root.isFetchingLyrics = false;
                syncLyrics();
            }
        }
    }


    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        onClicked: (mouse) => {
            var p = mapToItem(popupCard, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > popupCard.width || p.y > popupCard.height) {
                root.isOpen = false;
            }
        }
    }

    Item {
        id: popupCard
        width: 420
        height: showLyrics ? 640 : 210
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: popupTopMargin
        z: 1

        Rectangle {
            id: popupBg
            anchors.fill: parent
            radius: 28
            color: ColorScheme.withAlpha(ColorScheme.surfaceContainer, 0.85)
            border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.2)
            border.width: 1
        }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 24

            Rectangle {
                width: 130
                height: 130
                radius: 24
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.3)
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.trackArtUrl
                    sourceSize.width: Math.max(130, Math.min(192, parent.width * 2))
                    sourceSize.height: Math.max(130, Math.min(192, parent.height * 2))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 24
                    color: "transparent"
                    border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.2)
                    border.width: 1
                }
                Text {
                    anchors.centerIn: parent
                    text: "\u{f001}"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 48
                    color: ColorScheme.accent
                    visible: root.trackArtUrl === ""
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: root.trackTitle
                    color: ColorScheme.text
                    font.family: "Inter"
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: root.trackArtist
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.5)
                    font.family: "Inter"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Item { Layout.preferredHeight: 12 }

                RowLayout {
                    spacing: 14
                    RowLayout {
                        spacing: 14
                        Text {
                            text: "\u{f048}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            color: ColorScheme.text
                            MouseArea {
                                anchors.fill: parent
                                onClicked: if(root.effectivePlayer) root.effectivePlayer.previous()
                            }
                        }
                        Rectangle {
                            width: 44
                            height: 44
                            radius: 22
                            color: ColorScheme.accent
                            Text {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: root.isPlaying ? 0 : 2
                                text: root.isPlaying ? "\u{f04c}" : "\u{f04b}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                color: ColorScheme.background
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: if(root.effectivePlayer) root.effectivePlayer.togglePlaying()
                            }
                        }
                        Text {
                            text: "\u{f051}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            color: ColorScheme.text
                            MouseArea {
                                anchors.fill: parent
                                onClicked: if(root.effectivePlayer) root.effectivePlayer.next()
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 16
                        color: root.showLyrics ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.1)
                        Text {
                            anchors.centerIn: parent
                            text: root.showLyrics ? "Close" : "Lyrics"
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.showLyrics ? ColorScheme.background : ColorScheme.text
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showLyrics = !root.showLyrics
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
            Rectangle {
                width: parent.width * root.mediaProgress
                height: parent.height
                radius: 2
                color: ColorScheme.accent
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.Linear } }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 20
            color: ColorScheme.withAlpha(ColorScheme.background, 0.3)
            clip: true
            visible: root.showLyrics
            opacity: root.showLyrics ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 250 } }
            ListView {
                id: lyricsList
                anchors.fill: parent
                anchors.margins: 16
                model: root.lyricsModel
                spacing: 12
                interactive: true
                clip: true
                delegate: Text {
                    width: ListView.view.width
                    text: modelData.text
                    font.family: "Inter"
                    font.pixelSize: 16
                    font.bold: index === root.currentLineIndex
                    color: index === root.currentLineIndex ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, index < root.currentLineIndex ? 0.3 : 0.6)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: parent.height / 3
                preferredHighlightEnd: parent.height * 2/3
            }
        }
    }
    }
}
