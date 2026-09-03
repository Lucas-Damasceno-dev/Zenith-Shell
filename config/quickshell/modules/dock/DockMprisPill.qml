import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../../core"
import "../../services/MprisUtils.js" as MprisUtils

/**
 * DockMprisPill — Media player integration that participates in magnification.
 */
Item {
    id: root

    readonly property var activePlayer: MprisUtils.selectPlayerWithPreference(Mpris.players, MprisPlaybackState.Playing, "")
    readonly property string currentTitle: MprisUtils.titleForPlayer(activePlayer)
    readonly property string currentArtist: MprisUtils.artistForPlayer(activePlayer)
    readonly property string currentArtUrl: MprisUtils.artUrlForPlayer(activePlayer)

    property bool hasMedia: activePlayer !== null && currentTitle.length > 0
    property real baseSize: 48
    property real magnification: 1.0
    property real riseOffset: 0
    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion
    
    readonly property real displaySize: baseSize * magnification

    Behavior on magnification {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 72; easing.type: Easing.OutCubic }
    }
    Behavior on riseOffset {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 72; easing.type: Easing.OutCubic }
    }

    visible: hasMedia
    width: hasMedia ? pillBg.width : 0
    height: displaySize

    Behavior on width {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: pillBg
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenterOffset: -root.riseOffset
        width: pillRow.width + 14
        height: 40 * magnification
        radius: DesignTokens.radiusMD
        color: ColorScheme.withAlpha(ColorScheme.surface, 0.6)
        border.width: 1
        border.color: ColorScheme.withAlpha(ColorScheme.base03, 0.3)
        clip: true

        // Track progress indicator (thin accent line at bottom)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            height: 2 * magnification
            radius: 1
            color: ColorScheme.withAlpha(ColorScheme.accent, 0.5)
            width: {
                if (!root.activePlayer) return 0;
                var pos = root.activePlayer.position || 0;
                var len = root.activePlayer.length || 0;
                if (len <= 0) return 0;
                return parent.width * (pos / len);
            }
            Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
        }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6 * magnification
            scale: magnification

            // Album art
            Rectangle {
                width: 32; height: 32
                radius: DesignTokens.radiusSM
                color: ColorScheme.base03
                clip: true
                visible: root.hasMedia

                Image {
                    anchors.fill: parent
                    source: root.currentArtUrl
                    sourceSize.width: 64
                    sourceSize.height: 64
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u{f001}"
                    color: ColorScheme.textAlt
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    visible: !root.currentArtUrl || root.currentArtUrl === ""
                }
            }

            // Track info
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(trackTitle.implicitWidth, 120)

                Text {
                    id: trackTitle
                    text: root.currentTitle
                    color: ColorScheme.text
                    font.pixelSize: 11
                    font.family: Style.fontUI
                    font.bold: true
                    elide: Text.ElideRight
                    width: 120
                }
                Text {
                    text: root.currentArtist
                    color: ColorScheme.textAlt
                    font.pixelSize: 10
                    font.family: Style.fontUI
                    elide: Text.ElideRight
                    width: 120
                }
            }

            // Controls
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: [
                        { icon: "⏮", action: "previous", canDo: root.activePlayer ? root.activePlayer.canGoPrevious : false },
                        { icon: root.activePlayer && root.activePlayer.isPlaying ? "⏸" : "▶", action: "toggle", canDo: root.activePlayer ? root.activePlayer.canTogglePlaying : false },
                        { icon: "⏭", action: "next", canDo: root.activePlayer ? root.activePlayer.canGoNext : false }
                    ]

                    delegate: Rectangle {
                        width: 24; height: 24; radius: 12
                        color: ctrlMouse.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.18) : "transparent"
                        visible: modelData.canDo
                        Behavior on color {
                            enabled: !root.reducedEffects
                            ColorAnimation { duration: DesignTokens.durationFast }
                        }

                        scale: ctrlMouse.pressed ? DesignTokens.pressedScale : 1.0
                        Behavior on scale {
                            enabled: !root.reducedEffects
                            SpringAnimation { spring: DesignTokens.springSnappy; damping: DesignTokens.dampingSnappy; epsilon: 0.01 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.pixelSize: 11
                            color: ctrlMouse.containsMouse ? ColorScheme.accent : ColorScheme.text
                            Behavior on color {
                                enabled: !root.reducedEffects
                                ColorAnimation { duration: DesignTokens.durationFast }
                            }
                        }
                        MouseArea {
                            id: ctrlMouse; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (!root.activePlayer) return;
                                if (modelData.action === "previous") root.activePlayer.previous();
                                else if (modelData.action === "next") root.activePlayer.next();
                                else root.activePlayer.togglePlaying();
                            }
                        }
                    }
                }
            }
        }
    }
}
