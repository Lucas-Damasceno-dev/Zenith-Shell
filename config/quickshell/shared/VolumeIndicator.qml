import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../services"

Item {
    id: root
    width: row.implicitWidth
    height: 32
    
    property color accentColor: ColorScheme.accent

    // Safe volume reader: returns 0-100 integer, never NaN
    function safeVolume() {
        return AudioStatusService.volume;
    }

    function isMuted() {
        return AudioStatusService.muted;
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 5

        DynamicIcon {
            iconSource: root.isMuted()
                        ? "file://" + RuntimePaths.quickshellDir + "/shared/icons/mute.svg"
                        : "file://" + RuntimePaths.quickshellDir + "/shared/icons/audio-output.svg"
            iconColor: root.isMuted() ? ColorScheme.red : root.accentColor
            fallbackGlyph: root.isMuted() ? "\u{f0580}" : "\u{f028}"
            size: 16
        }

        Text {
            text: root.isMuted() ? "Mudo" : root.safeVolume() + "%"
            color: root.isMuted() ? ColorScheme.red : ColorScheme.withAlpha(ColorScheme.text, 0.65)
            font.pixelSize: 12
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            AudioStatusService.toggleSinkMute();
            Qt.callLater(AudioStatusService.refreshCliStatus);
        }
        onWheel: (wheel) => {
            if (wheel.angleDelta.y === 0) return;
            let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            AudioStatusService.setSinkVolumeRatio((AudioStatusService.volume / 100.0) + delta);
            Qt.callLater(AudioStatusService.refreshCliStatus);
        }
    }
}
