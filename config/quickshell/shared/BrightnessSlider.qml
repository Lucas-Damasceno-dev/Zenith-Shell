import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"
import "../services"

ColumnLayout {
    id: root
    spacing: DesignTokens.spacingMD

    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.text
    readonly property color secondaryTextColor: Style.muted
    readonly property color cardFill: ColorScheme.withAlpha(ColorScheme.surface, 0.24)
    readonly property color cardBorder: ColorScheme.withAlpha(ColorScheme.text, 0.06)

    // Max/current brightness storage
    property int maxBrightness: 255
    property int currentBrightness: 0

    function parseBrightnessValue(rawText) {
        var text = String(rawText || "").trim();
        if (text === "") return -1;
        var match = text.match(/([0-9]+)(?!.*[0-9])/);
        if (!match || match.length < 2) return -1;
        var value = parseInt(match[1]);
        return isNaN(value) ? -1 : value;
    }

    // Get Max Brightness
    TimedProcess {
        id: getMaxBright
        stdout: StdioCollector {
            onStreamFinished: {
                let max = root.parseBrightnessValue(text);
                if (max > 0) {
                    root.maxBrightness = max;
                    getCurBright.exec(["brightnessctl", "g"]);
                }
            }
        }
    }

    // Get Current Brightness
    TimedProcess {
        id: getCurBright
        stdout: StdioCollector {
            onStreamFinished: {
                let cur = root.parseBrightnessValue(text);
                if (cur >= 0) {
                    root.currentBrightness = cur;
                    slider.value = Math.max(0, Math.min(root.maxBrightness, cur));
                }
            }
        }
    }
    
    // Set Brightness
    TimedProcess {
        id: setBright
        onExited: getCurBright.exec(["brightnessctl", "g"])
    }

    Component.onCompleted: getMaxBright.exec(["brightnessctl", "m"])

    property bool pollActive: visible

    Timer {
        interval: FeatureFlags.lowPowerUiMode ? 15000 : 10000
        running: root.pollActive
        repeat: true
        triggeredOnStart: true
        onTriggered: getCurBright.exec(["brightnessctl", "g"])
    }

    // Debounce slider moves to avoid subprocess spam
    Timer {
        id: brightnessDebounce
        interval: 300
        repeat: false
        property int pendingPct: 0
        onTriggered: setBright.exec(["brightnessctl", "s", String(Math.max(1, Math.min(100, pendingPct))) + "%"])
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "\u{f00df} Brilho"
            color: textColor
            font.bold: true
            font.pixelSize: DesignTokens.fontSizeSM
            font.family: Style.fontUI
        }
        Item { Layout.fillWidth: true }
        Text {
            text: root.maxBrightness > 0
                ? Math.round((slider.value / root.maxBrightness) * 100) + "%"
                : "0%"
            color: secondaryTextColor
            font.pixelSize: DesignTokens.fontSizeXS + 1
            font.family: Style.fontUI
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 28
        radius: DesignTokens.radiusMD
        color: cardFill
        border.color: cardBorder
        border.width: 1

        Rectangle {
            width: root.maxBrightness > 0 ? (parent.width * (slider.value / root.maxBrightness)) : 0
            height: parent.height
            color: accentColor
            radius: parent.radius
        }

        Slider {
            id: slider
            anchors.fill: parent
            from: 0
            to: root.maxBrightness
            opacity: 0

            onMoved: {
                var pct = root.maxBrightness > 0
                    ? Math.round((value / root.maxBrightness) * 100)
                    : 0;
                brightnessDebounce.pendingPct = pct;
                brightnessDebounce.restart();
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: DesignTokens.spacingSM
        Rectangle {
            Layout.preferredWidth: 58
            height: 24
            radius: DesignTokens.radiusMD
            color: minusMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.surface, 0.36) : cardFill
            border.color: cardBorder
            border.width: 1
            Behavior on color { ColorAnimation { duration: DesignTokens.durationSlow } }
            Text {
                anchors.centerIn: parent
                text: "-5%"
                color: textColor
                font.pixelSize: DesignTokens.fontSizeXS
                font.family: Style.fontUI
            }
            MouseArea {
                id: minusMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: setBright.exec(["brightnessctl", "s", "5%-"])
            }
        }
        Rectangle {
            Layout.preferredWidth: 58
            height: 24
            radius: DesignTokens.radiusMD
            color: plusMa.containsMouse ? ColorScheme.withAlpha(accentColor, 0.26) : ColorScheme.withAlpha(accentColor, 0.20)
            border.color: ColorScheme.withAlpha(accentColor, plusMa.containsMouse ? 0.30 : 0.18)
            border.width: 1
            Behavior on color { ColorAnimation { duration: DesignTokens.durationSlow } }
            Text {
                anchors.centerIn: parent
                text: "+5%"
                color: accentColor
                font.pixelSize: DesignTokens.fontSizeXS
                font.family: Style.fontUI
            }
            MouseArea {
                id: plusMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: setBright.exec(["brightnessctl", "s", "5%+"])
            }
        }
        Item { Layout.fillWidth: true }
    }
}
