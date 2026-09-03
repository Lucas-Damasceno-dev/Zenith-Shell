import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../core"
import "../../../shared"
import "../../../services"

/**
 * HardwareMonitors - Row of circular gauges for CPU/RAM/GPU/Temp.
 *
 * Features:
 * - Native vector rendering at configurable gaugeSize (no fractional scale blur).
 * - Left-click toggles system monitor popup; Right-click launches btop directly.
 * - Reactive degraded badge with click-to-retry.
 */
Row {
    id: root
    spacing: 5

    property real gaugeSize: 22
    property color accentColor: ColorScheme.accent

    signal clicked(int mouseButton, int gaugeIndex)

    // ─── Shared btop launcher ──────────────────────────────────
    TimedProcess {
        id: launchBtop
        command: ["kitty", "--title", "System Monitor", "btop"]
    }

    // ─── Gauge definitions ─────────────────────────────────────
    readonly property var gauges: [
        {
            icon: "cpu",
            glyph: "\u{f2db}",
            label: "CPU",
            usage: SystemMetricsService.cpuUsage
        },
        {
            icon: "memory",
            glyph: "\u{f538}",
            label: "RAM",
            usage: SystemMetricsService.ramUsage
        },
        {
            icon: "gpu",
            glyph: "\u{f108}",
            label: "GPU",
            usage: SystemMetricsService.gpuUsage
        },
        {
            icon: "temp",
            glyph: "\u{f2c9}",
            label: "Temp",
            usage: Math.min(1.0, Math.max(0.0, (SystemMetricsService.temperatureC - 30) / 60))
        }
    ]

    Repeater {
        model: root.gauges

        delegate: Item {
            id: gaugeItem
            required property var modelData
            required property int index

            width: root.gaugeSize
            height: root.gaugeSize
            opacity: SystemMetricsService.healthState === "degraded" ? 0.72 : 1.0

            CircularGauge {
                anchors.fill: parent
                size: root.gaugeSize
                iconName: modelData.icon
                iconGlyph: modelData.glyph
                activeColor: root.accentColor
                usage: modelData.usage
            }

            // Hover and press scale
            scale: gaugeMa.pressed ? DesignTokens.pressedScale : (gaugeMa.containsMouse ? 1.15 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }

            MouseArea {
                id: gaugeMa
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: function(mouse) {
                    root.clicked(mouse.button, index);
                    if (mouse.button === Qt.RightButton) {
                        launchBtop.running = false;
                        launchBtop.running = true;
                    }
                }
            }
        }
    }

    Item {
        visible: SystemMetricsService.healthState === "degraded"
        width: visible ? Math.round(root.gaugeSize * 0.65) : 0
        height: visible ? Math.round(root.gaugeSize * 0.65) : 0
        anchors.verticalCenter: parent.verticalCenter
        opacity: 0.9

        Text {
            anchors.centerIn: parent
            text: "\u{f071}"
            color: ColorScheme.red
            font.family: DesignTokens.fontFamilyMono
            font.pixelSize: Math.max(10, Math.round(root.gaugeSize * 0.55))
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: healthBadgeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: SystemMetricsService.refreshNow()
        }
    }
}
