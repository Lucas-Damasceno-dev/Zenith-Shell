import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../core"
import "../../../shared"
import "../../../services"

Item {
    id: root

    implicitWidth: pill.implicitWidth
    implicitHeight: DesignTokens.barItemHeight

    required property color accentColor
    required property color textColor
    required property var popupInstance
    required property bool anyPopupOpen
    property string tooltipText: ""

    function togglePopup() { ShellController.togglePopup(root, popupInstance); }

    readonly property bool hasSinkReady: AudioStatusService.hasSinkReady
    readonly property int volumeProp: AudioStatusService.volume
    readonly property bool isMutedProp: AudioStatusService.muted

    readonly property bool hasSourceReady: AudioStatusService.hasSourceReady
    readonly property int sourceVolumeProp: AudioStatusService.sourceVolume
    readonly property bool isSourceMutedProp: AudioStatusService.sourceMuted

    readonly property string volIconProp: {
        if (isMutedProp) return "\u{f0580}";
        if (volumeProp > 66) return "\u{f028}";
        if (volumeProp > 33) return "\u{f027}";
        if (volumeProp > 0) return "\u{f026}";
        return "\u{f0580}";
    }

    readonly property string volLabelText: isMutedProp ? "Mudo" : (root.volumeProp + "%")

    readonly property color volColorProp: isMutedProp ? ColorScheme.red : accentColor

    property int _pendingSourceDelta: 0
    property int _pendingSinkDelta: 0

    Timer {
        id: sourceVolumeTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (root._pendingSourceDelta === 0) return;
            var delta = root._pendingSourceDelta;
            root._pendingSourceDelta = 0;
            if (AudioStatusService.pwSourceReady) {
                var newRatio = (AudioStatusService.sourceVolume + delta) / 100.0;
                AudioStatusService.setSourceVolumeRatio(newRatio);
            } else {
                var stepStr = delta < 0 ? (Math.abs(delta) + "%-") : (delta + "%+");
                sourceStepProc.exec(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SOURCE@", stepStr]);
            }
        }
    }

    Timer {
        id: sinkVolumeTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (!root.hasSinkReady || root._pendingSinkDelta === 0) return;
            var delta = root._pendingSinkDelta;
            root._pendingSinkDelta = 0;
            if (AudioStatusService.pwSinkReady) {
                var newRatio = (AudioStatusService.volume + delta) / 100.0;
                AudioStatusService.setSinkVolumeRatio(newRatio);
            } else {
                var stepStr = delta < 0 ? (Math.abs(delta) + "%-") : (delta + "%+");
                sinkStepProc.exec(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", stepStr]);
            }
        }
    }

    function safeVolume() { return volumeProp; }
    function isMuted() { return isMutedProp; }
    function volumeIcon() { return volIconProp; }
    function stepSourceVolume(stepUp) {
        _pendingSourceDelta += (stepUp ? 5 : -5);
        sourceVolumeTimer.restart();
    }
    function stepSinkVolume(stepUp) {
        if (!root.hasSinkReady)
            return;
        _pendingSinkDelta += (stepUp ? 5 : -5);
        sinkVolumeTimer.restart();
    }

    PillWidget {
        id: pill
        anchors.fill: parent
        iconText: root.volIconProp
        iconColor: root.volColorProp
        labelText: root.volLabelText
        labelFontSize: 12
        labelColor: isMutedProp ? ColorScheme.red : ColorScheme.withAlpha(root.textColor, 0.65)
        tooltipText: {
            if (root.tooltipText !== "") return root.tooltipText;
            if (!root.hasSinkReady) return "Áudio indisponível";
            var outText = root.isMutedProp ? "Saída: Mudo" : "Saída: " + root.volumeProp + "%";
            var inText = root.hasSourceReady ? (root.isSourceMutedProp ? "Mic: Mudo" : "Mic: " + root.sourceVolumeProp + "%") : "";
            return inText !== "" ? (outText + " | " + inText) : outText;
        }
        checked: ShellController.isPopupOpen(root.popupInstance)
        popupOpen: checked
        anyPopupOpen: root.anyPopupOpen
        onClicked: root.togglePopup()
        onPressAndHold: {
            if (!root.hasSinkReady) return;
            AudioStatusService.toggleSinkMute();
            Qt.callLater(AudioStatusService.refreshCliStatus);
        }

        // Live mic status badge (dot / icon)
        Rectangle {
            id: micDot
            visible: root.hasSourceReady && (root.isSourceMutedProp || PrivacyService.micActive)
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            width: 6
            height: 6
            radius: 3
            color: root.isSourceMutedProp ? ColorScheme.red : ColorScheme.accent

            SequentialAnimation on opacity {
                running: PrivacyService.micActive && !root.isSourceMutedProp
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.3; duration: 800; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.3; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.MiddleButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) {
                if (root.hasSourceReady) {
                    AudioStatusService.toggleSourceMute();
                    Qt.callLater(AudioStatusService.refreshCliStatus);
                }
            } else if (mouse.button === Qt.RightButton) {
                if (root.hasSinkReady) {
                    AudioStatusService.toggleSinkMute();
                    Qt.callLater(AudioStatusService.refreshCliStatus);
                }
            }
        }
        onWheel: function(wheel) {
            if (wheel.angleDelta.y === 0) return;
            var isShift = (wheel.modifiers & Qt.ShiftModifier);
            if (isShift) {
                root.stepSourceVolume(wheel.angleDelta.y > 0);
            } else {
                root.stepSinkVolume(wheel.angleDelta.y > 0);
            }
        }
    }

    TimedProcess {
        id: sinkStepProc
        timeoutMs: 2500
        onExited: AudioStatusService.refreshCliStatus()
    }

    TimedProcess {
        id: sourceStepProc
        timeoutMs: 2500
        onExited: AudioStatusService.refreshCliStatus()
    }
}
