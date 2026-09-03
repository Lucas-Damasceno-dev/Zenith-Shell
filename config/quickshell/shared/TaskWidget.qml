import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../core"
import "../services"

/**
 * TaskWidget - Live process list gated by visibility.
 */
ColumnLayout {
    id: root
    spacing: 8

    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.text
    property bool pollActive: visible
    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion

    Text {
        text: "  Top Processes"
        color: root.accentColor
        font.bold: true
        font.pixelSize: 12
        font.family: "Inter"
    }

    ListModel { id: procModel }

    TimedProcess {
        id: procLoader
        stdout: StdioCollector {
            onStreamFinished: {
                procModel.clear();
                var lines = String(text || "").trim().split(/\r?\n/);
                lines.slice(1, 8).forEach(function(line) {
                    var parts = line.trim().split(/\s+/);
                    if (parts.length >= 3) {
                        var cpuVal = parseFloat(parts[2]) || 0;
                        procModel.append({ pid: parts[0], name: parts[1], cpu: cpuVal });
                    }
                });
            }
        }
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            if (root.pollActive)
                refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer
        interval: FeatureFlags.lowPowerUiMode ? 240 : 120
        repeat: false
        onTriggered: {
            if (root.pollActive)
                procLoader.exec(["ps", "-eo", "pid,comm,pcpu", "--sort=-pcpu"]);
        }
    }

    Timer {
        id: pollTimer
        interval: FeatureFlags.lowPowerUiMode ? 8000 : 5000
        repeat: true
        running: root.pollActive
        triggeredOnStart: true
        onTriggered: procLoader.exec(["ps", "-eo", "pid,comm,pcpu", "--sort=-pcpu"])
    }

    TimedProcess { id: taskKiller }

    ListView {
        id: procList
        Layout.fillWidth: true
        Layout.preferredHeight: 200
        model: procModel
        spacing: 4
        clip: true
        interactive: false

        displaced: Transition {
            enabled: !root.reducedEffects
            NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
        }
        add: Transition {
            enabled: !root.reducedEffects
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
        }

        delegate: Rectangle {
            width: procList.width
            height: 28
            radius: 6
            color: ColorScheme.glassCard
            border.color: ColorScheme.glassBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: Math.max(4, Math.min(40, model.cpu * 0.6))
                    Layout.preferredHeight: 4
                    radius: 2
                    color: model.cpu > 80 ? ColorScheme.red
                         : model.cpu > 40 ? ColorScheme.peach
                         : root.accentColor
                    Behavior on width {
                        enabled: !root.reducedEffects
                        NumberAnimation { duration: 300 }
                    }
                }

                Text {
                    text: model.name
                    color: root.textColor
                    font.pixelSize: 11
                    font.family: "Inter"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: model.cpu.toFixed(1) + "%"
                    color: model.cpu > 80 ? ColorScheme.red : root.accentColor
                    font.bold: true
                    font.pixelSize: 10
                    font.family: "Inter"
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                    Behavior on color {
                        enabled: !root.reducedEffects
                        ColorAnimation { duration: 200 }
                    }
                }

                Item {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: killMa.containsMouse
                            ? ColorScheme.withAlpha(ColorScheme.red, 0.25)
                            : "transparent"
                        Behavior on color {
                            enabled: !root.reducedEffects
                            ColorAnimation { duration: 100 }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: killMa.containsMouse ? ColorScheme.red : ColorScheme.withAlpha(root.textColor, 0.4)
                        font.pixelSize: 8
                        Behavior on color {
                            enabled: !root.reducedEffects
                            ColorAnimation { duration: 100 }
                        }
                    }
                    MouseArea {
                        id: killMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var pid = parseInt(model.pid);
                            if (pid > 0) taskKiller.exec(["kill", "-15", String(pid)]);
                        }
                    }
                }
            }
        }
    }
}
