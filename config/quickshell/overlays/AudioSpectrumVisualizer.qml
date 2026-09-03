import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../core"
import "../services/MprisUtils.js" as MprisUtils

PanelWindow {
    id: root

    property var player: shellRoot.activeMprisPlayer
    readonly property bool isPlaying: !!(player && player.playbackState === MprisPlaybackState.Playing)

    visible: isPlaying
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-audio-spectrum"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false

    anchors {
        left: true; right: true; bottom: true; top: false
    }
    
    implicitHeight: 80

    // Prevent blocking input
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 80
        spacing: 3

        // Single shared timer drives all bars
        Timer {
            id: spectrumTimer
            interval: 220
            running: root.isPlaying && root.visible
            repeat: true
            onTriggered: {
                var centerIndex = (spectrumRepeater.count - 1) / 2.0;
                for (var i = 0; i < spectrumRepeater.count; i++) {
                    var bar = spectrumRepeater.itemAt(i);
                    if (!bar) continue;
                    var centerDist = centerIndex > 0 ? Math.abs(i - centerIndex) / centerIndex : 0;
                    var multiplier = 1.0 - (centerDist * 0.45);
                    bar.targetHeight = Math.max(3, Math.random() * 65 * multiplier);
                }
            }
        }

        Connections {
            target: root
            function onIsPlayingChanged() {
                if (root.isPlaying)
                    return;
                for (var i = 0; i < spectrumRepeater.count; i++) {
                    var bar = spectrumRepeater.itemAt(i);
                    if (bar)
                        bar.targetHeight = 3;
                }
            }
        }

        Repeater {
            id: spectrumRepeater
            model: 28

            delegate: Rectangle {
                width: 5
                radius: 2.5
                property real targetHeight: 3
                height: targetHeight
                anchors.bottom: parent.bottom

                // Gradient color from accent to accentAlt across bars
                color: {
                    var t = spectrumRepeater.count > 1 ? index / (spectrumRepeater.count - 1) : 0;
                    var r = ColorScheme.accent.r * (1 - t) + ColorScheme.accentAlt.r * t;
                    var g = ColorScheme.accent.g * (1 - t) + ColorScheme.accentAlt.g * t;
                    var b = ColorScheme.accent.b * (1 - t) + ColorScheme.accentAlt.b * t;
                    // Intensity-based opacity: taller bars = brighter
                    var intensity = Math.min(1.0, targetHeight / 50.0);
                    return Qt.rgba(r, g, b, 0.35 + intensity * 0.40);
                }

                Behavior on height {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
            }
        }
    }
}
