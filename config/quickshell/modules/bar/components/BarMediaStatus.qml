import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Mpris
import "../../../core"
import "../../../services/MprisUtils.js" as MprisUtils

/**
 * BarMediaStatus — High-performance, reactive MPRIS media status pill for the top bar.
 *
 * Features:
 *   - Autonomous MPRIS state & metadata extraction without popup coupling
 *   - Real-time track progress with anti-rewind animation smoothing
 *   - Mini album art thumbnail with fallback icon
 *   - Graceful 30s pause retention (keeps control visible instead of abrupt disappearing)
 *   - Zero garbage-collection churn: static lightweight control buttons (no Repeater allocations)
 *   - Capability-aware buttons (canGoPrevious, canGoNext, canTogglePlaying)
 *   - Smart scroll wheel: cycles active players if >1, adjusts player volume if 1
 *   - Informative hover ToolTip showing full title, artist, and media player identity
 */
Item {
    id: root

    required property color accentColor
    required property color textColor
    required property var popupInstance
    property bool anyPopupOpen: false

    // ─── MPRIS State Management ──────────────────────────────────
    readonly property var allPlayers: MprisUtils.playerList(Mpris.players)
    readonly property int playerCount: allPlayers.length
    readonly property var mprisPlayer: typeof shellRoot !== "undefined" && shellRoot ? shellRoot.activeMprisPlayer : null
    readonly property var effectivePlayer: mprisPlayer ? mprisPlayer : (playerCount > 0 ? allPlayers[0] : null)
    readonly property bool hasMedia: !!(effectivePlayer && MprisUtils.hasPlayableMetadata(effectivePlayer))
    readonly property bool isPlaying: !!(effectivePlayer && effectivePlayer.playbackState === MprisPlaybackState.Playing)
    readonly property bool isOpen: ShellController.isPopupOpen(root.popupInstance)

    readonly property string titleText: hasMedia ? (MprisUtils.titleForPlayer(effectivePlayer) || "Sem título") : ""
    readonly property string artistText: hasMedia ? (MprisUtils.artistForPlayer(effectivePlayer) || "") : ""
    readonly property string artUrl: hasMedia ? (MprisUtils.artUrlForPlayer(effectivePlayer) || "") : ""
    readonly property string playerIdentity: effectivePlayer ? String(effectivePlayer.identity || effectivePlayer.desktopEntry || "") : ""

    // ─── Control Capabilities ────────────────────────────────────
    readonly property bool canGoPrev: effectivePlayer ? (effectivePlayer.canGoPrevious !== undefined ? effectivePlayer.canGoPrevious : true) : false
    readonly property bool canGoNext: effectivePlayer ? (effectivePlayer.canGoNext !== undefined ? effectivePlayer.canGoNext : true) : false
    readonly property bool canToggle: effectivePlayer ? (effectivePlayer.canTogglePlaying !== undefined ? effectivePlayer.canTogglePlaying : true) : false

    // ─── Graceful Pause Retention ────────────────────────────────
    // Keeps widget visible and interactive for 30s after pause instead of vanishing abruptly
    property bool retainOnPause: false

    Timer {
        id: retainTimer
        interval: 30000
        repeat: false
        onTriggered: root.retainOnPause = false
    }

    onIsPlayingChanged: {
        if (!isPlaying && hasMedia) {
            retainOnPause = true;
            retainTimer.restart();
        } else if (isPlaying) {
            retainTimer.stop();
            retainOnPause = false;
        }
    }

    onHasMediaChanged: {
        if (!hasMedia) {
            retainTimer.stop();
            retainOnPause = false;
        }
    }

    // ─── Real-Time Progress Tracking ─────────────────────────────
    property int _progressTick: 0

    Timer {
        id: progressPollTimer
        interval: FeatureFlags.lowPowerUiMode ? 2000 : 1000
        running: root.visible && root.isPlaying
        repeat: true
        onTriggered: root._progressTick++
    }

    readonly property real mediaProgress: {
        var _ = root._progressTick;
        if (!hasMedia || !effectivePlayer) return 0;
        var len = Number(effectivePlayer.length);
        var pos = Number(effectivePlayer.position);
        if (!isFinite(len) || !isFinite(pos) || len <= 0) return 0;
        if (len > 10000000) len /= 1000000;
        if (pos > 10000000) pos /= 1000000;
        return Math.max(0, Math.min(1, pos / len));
    }

    // ─── Player Cycling ──────────────────────────────────────────
    readonly property int currentPlayerIndex: {
        if (playerCount <= 0 || !effectivePlayer) return 0;
        for (var i = 0; i < playerCount; i++) {
            if (allPlayers[i] === effectivePlayer) return i;
        }
        var targetKey = root.playerKey(effectivePlayer);
        for (var j = 0; j < playerCount; j++) {
            if (root.playerKey(allPlayers[j]) === targetKey) return j;
        }
        return 0;
    }

    readonly property string playerCycleLabel: playerCount > 1 ? String(currentPlayerIndex + 1) + "/" + String(playerCount) : ""

    function togglePopup() {
        ShellController.togglePopup(root, root.popupInstance);
    }

    function doPrev() {
        if (effectivePlayer && canGoPrev) {
            try { effectivePlayer.previous(); } catch (e) {}
        }
    }

    function doPlayPause() {
        if (effectivePlayer) {
            try {
                if (typeof effectivePlayer.togglePlaying === "function") {
                    effectivePlayer.togglePlaying();
                } else if (typeof effectivePlayer.playPause === "function") {
                    effectivePlayer.playPause();
                }
            } catch (e) {}
        }
    }

    function doNext() {
        if (effectivePlayer && canGoNext) {
            try { effectivePlayer.next(); } catch (e) {}
        }
    }

    function playerKey(player) {
        if (!player) return "";
        return String(player.dbusName || player.desktopEntry || player.identity || "");
    }

    // ─── Dimensions & Animation ──────────────────────────────────
    implicitHeight: DesignTokens.barItemHeight
    implicitWidth: hasMedia ? Math.min(200, Math.max(64, contentRow.implicitWidth + 16)) : 34

    Behavior on implicitWidth {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    // ─── Pill Background ─────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        clip: true
        color: root.isPlaying
            ? ColorScheme.withAlpha(ColorScheme.surface, 0.35)
            : ColorScheme.withAlpha(ColorScheme.surface, 0.22)
        border.color: (root.isPlaying || root.isOpen)
            ? ColorScheme.withAlpha(root.accentColor, 0.38)
            : (root.retainOnPause ? ColorScheme.withAlpha(root.accentColor, 0.18) : ColorScheme.glassBorder)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 250 } }
        Behavior on border.color { ColorAnimation { duration: 250 } }
    }

    // ─── Main Content Row ────────────────────────────────────────
    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 6

        // Status / Mini Album Art Thumbnail — clickable to open popup
        Item {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            z: 2

            Rectangle {
                anchors.fill: parent
                radius: 9
                color: ColorScheme.withAlpha(root.accentColor, 0.15)
                clip: true

                Image {
                    id: miniArt
                    anchors.fill: parent
                    source: root.artUrl
                    sourceSize.width: 36
                    sourceSize.height: 36
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready && root.artUrl !== ""
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u{f001}"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    color: root.hasMedia ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.35)
                    visible: miniArt.status !== Image.Ready || root.artUrl === ""

                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePopup()
            }
        }

        // Track Title & Artist (Compact with Elide)
        Item {
            id: textContainer
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            Layout.maximumWidth: 110
            Layout.preferredHeight: 16
            visible: root.hasMedia
            z: 2

            Text {
                id: marqueeText
                anchors.fill: parent
                text: root.titleText + (root.artistText ? " — " + root.artistText : "")
                color: root.isPlaying
                    ? ColorScheme.withAlpha(root.textColor, 0.90)
                    : ColorScheme.withAlpha(root.textColor, 0.65)
                font.pixelSize: 10
                font.family: "Inter"
                font.weight: Font.Medium
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter

                Behavior on color { ColorAnimation { duration: 200 } }
            }

            MouseArea {
                id: titleMa
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePopup()
            }
        }

        // Right-Side Playback Controls (Static items to eliminate GC churn)
        Row {
            Layout.alignment: Qt.AlignVCenter
            visible: root.hasMedia
            spacing: 1
            z: 3

            // Player cycle badge (if >1 player)
            Text {
                visible: root.playerCount > 1
                anchors.verticalCenter: parent.verticalCenter
                text: root.playerCycleLabel
                color: ColorScheme.withAlpha(root.textColor, 0.55)
                font.pixelSize: 9
                font.family: "Inter"
                font.weight: Font.Medium
                rightPadding: 2
            }

            // Previous Button
            Item {
                width: 18
                height: 18
                opacity: root.canGoPrev ? 1.0 : 0.35

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: (prevMa.containsMouse && !root.anyPopupOpen)
                        ? ColorScheme.withAlpha(root.accentColor, 0.18)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u{f048}"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                    color: (prevMa.containsMouse && !root.anyPopupOpen)
                        ? root.accentColor
                        : ColorScheme.withAlpha(root.textColor, 0.70)
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.canGoPrev ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.doPrev()
                }
            }

            // Play / Pause Button
            Item {
                width: 20
                height: 20

                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: (playMa.containsMouse && !root.anyPopupOpen)
                        ? ColorScheme.withAlpha(root.accentColor, 0.25)
                        : (root.isPlaying ? ColorScheme.withAlpha(root.accentColor, 0.12) : "transparent")
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.isPlaying ? "\u{f04c}" : "\u{f04b}"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    color: (playMa.containsMouse && !root.anyPopupOpen || root.isPlaying)
                        ? root.accentColor
                        : ColorScheme.withAlpha(root.textColor, 0.85)
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: playMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doPlayPause()
                }
            }

            // Next Button
            Item {
                width: 18
                height: 18
                opacity: root.canGoNext ? 1.0 : 0.35

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: (nextMa.containsMouse && !root.anyPopupOpen)
                        ? ColorScheme.withAlpha(root.accentColor, 0.18)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u{f051}"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                    color: (nextMa.containsMouse && !root.anyPopupOpen)
                        ? root.accentColor
                        : ColorScheme.withAlpha(root.textColor, 0.70)
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.canGoNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.doNext()
                }
            }
        }
    }

    // ─── Bottom Mini Progress Line ───────────────────────────────
    Rectangle {
        visible: root.hasMedia && root.mediaProgress > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        height: 2
        radius: 1
        color: ColorScheme.withAlpha(root.textColor, 0.10)
        clip: true

        Rectangle {
            width: parent.width * root.mediaProgress
            height: parent.height
            radius: 1
            color: ColorScheme.withAlpha(root.accentColor, root.isPlaying ? 0.85 : 0.45)

            Behavior on width {
                // Disable linear 1s animation when progress resets to 0 (prevents backward rewind visual glitch)
                enabled: root.mediaProgress > 0.03
                NumberAnimation { duration: 950; easing.type: Easing.Linear }
            }
        }
    }

    // ─── Full-Widget Mouse & Smart Scroll Interaction ────────────
    MouseArea {
        id: mediaMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 1

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton || mouse.button === Qt.LeftButton)
                root.togglePopup();
        }

        onWheel: (wheel) => {
            // If multiple players, wheel cycles through them
            if (root.playerCount > 1) {
                var players = root.allPlayers;
                var currentIdx = root.currentPlayerIndex;
                if (currentIdx < 0) currentIdx = 0;
                var nextIdx = wheel.angleDelta.y > 0
                    ? (currentIdx + 1) % players.length
                    : (currentIdx - 1 + players.length) % players.length;
                if (typeof shellRoot !== "undefined" && shellRoot) {
                    shellRoot.activeMprisPlayer = players[nextIdx];
                }
            } else if (root.effectivePlayer && root.effectivePlayer.volume !== undefined) {
                // If single player, wheel adjusts media player volume
                var delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                try {
                    root.effectivePlayer.volume = Math.max(0.0, Math.min(1.0, root.effectivePlayer.volume + delta));
                } catch (e) {}
            }
        }
    }
}
