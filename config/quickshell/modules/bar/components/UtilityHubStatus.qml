import QtQuick
import "../../../core"
import "../../../shared"
import "../../../services"
import "../../../services/HealthService.js" as HealthService

PillWidget {
    id: root

    required property color accentColor
    required property color textColor
    required property var popupInstance
    property string tooltipOverride: ""

    // Bindings directly to UtilityService singleton for persistent state
    readonly property bool isRecording: UtilityService.isRecording
    readonly property bool hasColor: UtilityService.hasColor
    readonly property string recordingDurationLabel: UtilityService.recordingDurationLabel
    readonly property color lastColor: UtilityService.lastColorHex
    readonly property bool isCountingDown: UtilityService.isCountingDown
    readonly property int countdownRemaining: UtilityService.countdownRemaining
    readonly property bool utilityAvailable: UtilityService.utilityAvailable

    function togglePopup() {
        ShellController.togglePopup(root, root.popupInstance);
    }

    opacity: root.utilityAvailable ? 1.0 : 0.45

    iconText: (root.isRecording || root.isCountingDown) ? "" : "\u{f030}"
    iconColor: root.isCountingDown ? ColorScheme.accent : root.accentColor
    checked: ShellController.isPopupOpen(root.popupInstance)
    popupOpen: checked
    labelText: root.isCountingDown
        ? (root.countdownRemaining + "s")
        : (root.isRecording ? root.recordingDurationLabel : "")
    labelColor: root.isCountingDown
        ? ColorScheme.accent
        : ColorScheme.withAlpha(ColorScheme.text, 0.92)
    activeLabelColor: root.isRecording
        ? ColorScheme.red
        : (root.isCountingDown ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.92))
    tooltipText: root.tooltipOverride !== ""
        ? root.tooltipOverride
        : (root.isCountingDown
            ? "Capturando em " + root.countdownRemaining + "s..."
            : (root.isRecording
                ? "Gravando " + root.recordingDurationLabel
                : (root.hasColor ? "Cor capturada: " + root.lastColor : "Central de Utilidades (Screenshots / Gravação)")))

    onClicked: root.togglePopup()
    onPressAndHold: {
        if (UtilityService.isRecording) {
            UtilityService.stopRecording();
        }
    }

    // Recording pulsing indicator
    Rectangle {
        visible: root.isRecording && !root.isCountingDown
        x: (DesignTokens.barIconButtonSize - width) / 2
        y: (DesignTokens.barItemHeight - height) / 2
        width: 10
        height: 10
        radius: 5
        color: ColorScheme.red

        SequentialAnimation on opacity {
            running: root.isRecording && !(FeatureFlags.reducedMotion || FeatureFlags.lowPowerUiMode)
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 550; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 550; easing.type: Easing.InOutSine }
        }
    }

    // Countdown active indicator
    Rectangle {
        visible: root.isCountingDown
        x: (DesignTokens.barIconButtonSize - width) / 2
        y: (DesignTokens.barItemHeight - height) / 2
        width: 12
        height: 12
        radius: 6
        color: ColorScheme.withAlpha(ColorScheme.accent, 0.25)
        border.color: ColorScheme.accent
        border.width: 1.5

        SequentialAnimation on scale {
            running: root.isCountingDown
            loops: Animation.Infinite
            NumberAnimation { to: 1.25; duration: 500; easing.type: Easing.OutQuad }
            NumberAnimation { to: 0.95; duration: 500; easing.type: Easing.InQuad }
        }
    }

    // Color Swatch Badge
    Rectangle {
        visible: root.hasColor && !root.isRecording && !root.isCountingDown
        x: DesignTokens.barIconButtonSize - width - 2
        y: DesignTokens.barItemHeight - height - 2
        width: 11
        height: 11
        radius: 6
        color: root.lastColor
        border.color: ColorScheme.withAlpha(ColorScheme.background, 0.9)
        border.width: 1.3
    }
}
