import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../core"

ColumnLayout {
    id: root
    spacing: 6

    property string icon: ""
    property string title: ""
    property int value: 0
    property int minValue: 0
    property int maxValue: 100
    property int step: 5
    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.text
    property string suffix: "%"
    property bool showButtons: true

    signal valueChangedByUser(int newValue)
    signal resetRequested()

    function clampValue(val) {
        return Math.max(minValue, Math.min(maxValue, Math.round(Number(val) || 0)));
    }

    function applyDelta(delta) {
        var next = clampValue(root.value + delta);
        if (next !== root.value) {
            root.valueChangedByUser(next);
        }
    }

    // ─── Header ──────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Item {
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            visible: root.icon !== ""

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: root.value > 0 ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.70)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onDoubleClicked: root.resetRequested()
            }
        }

        Text {
            text: root.title
            color: root.textColor
            font.pixelSize: 11
            font.family: "Inter"
            font.weight: Font.Medium
            Layout.fillWidth: true
            elide: Text.ElideRight

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onDoubleClicked: root.resetRequested()
            }
        }

        Text {
            text: root.value + root.suffix
            color: root.value > 0 ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.65)
            font.pixelSize: 11
            font.family: "Inter"
            font.bold: true
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    // ─── Slider Track & Controls ─────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // -5% Button
        Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 24
            radius: 12
            visible: root.showButtons
            color: minusMa.pressed
                ? ColorScheme.withAlpha(ColorScheme.surface, 0.40)
                : (minusMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.surface, 0.32) : ColorScheme.withAlpha(ColorScheme.surface, 0.20))
            border.color: ColorScheme.withAlpha(root.textColor, minusMa.containsMouse ? 0.12 : 0.06)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "-" + root.step + root.suffix
                color: root.textColor
                font.pixelSize: 10
                font.family: "Inter"
            }

            MouseArea {
                id: minusMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.applyDelta(-root.step)
            }
        }

        // Track Area
        Item {
            id: trackContainer
            Layout.fillWidth: true
            height: 24

            function updatePosition(mouseX) {
                var ratio = Math.max(0, Math.min(1.0, mouseX / trackContainer.width));
                var val = clampValue(root.minValue + ratio * (root.maxValue - root.minValue));
                root.valueChangedByUser(val);
            }

            // Track Background
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 12
                radius: 6
                color: ColorScheme.withAlpha(root.textColor, 0.08)

                // Fill Progress
                Rectangle {
                    width: Math.max(0, Math.min(parent.width, parent.width * ((root.value - root.minValue) / Math.max(1, (root.maxValue - root.minValue)))))
                    height: parent.height
                    radius: 6
                    color: root.accentColor
                    Behavior on width {
                        enabled: !trackMa.pressed
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }
                }
            }

            // Slider Knob / Thumb
            Rectangle {
                id: thumb
                width: 20
                height: 20
                radius: 10
                x: Math.max(0, Math.min(trackContainer.width - width, (trackContainer.width * ((root.value - root.minValue) / Math.max(1, (root.maxValue - root.minValue)))) - (width / 2)))
                anchors.verticalCenter: parent.verticalCenter
                color: trackMa.pressed ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.95)
                border.width: 2
                border.color: trackMa.pressed ? root.accentColor : ColorScheme.withAlpha(ColorScheme.foreground, 0.20)
                scale: trackMa.pressed ? 1.18 : (trackMa.containsMouse ? 1.08 : 1.0)

                Behavior on x {
                    enabled: !trackMa.pressed
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            // Interactive MouseArea (Drag + Click + Wheel Scroll)
            MouseArea {
                id: trackMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                onPressed: (mouse) => trackContainer.updatePosition(mouse.x)
                onPositionChanged: (mouse) => {
                    if (pressed) trackContainer.updatePosition(mouse.x);
                }
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y === 0) return;
                    root.applyDelta(wheel.angleDelta.y > 0 ? root.step : -root.step);
                }
                onDoubleClicked: root.resetRequested()
            }
        }

        // +5% Button
        Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 24
            radius: 12
            visible: root.showButtons
            color: plusMa.pressed
                ? ColorScheme.withAlpha(root.accentColor, 0.35)
                : (plusMa.containsMouse ? ColorScheme.withAlpha(root.accentColor, 0.26) : ColorScheme.withAlpha(root.accentColor, 0.16))
            border.color: ColorScheme.withAlpha(root.accentColor, plusMa.containsMouse ? 0.35 : 0.20)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "+" + root.step + root.suffix
                color: root.accentColor
                font.pixelSize: 10
                font.family: "Inter"
                font.bold: true
            }

            MouseArea {
                id: plusMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.applyDelta(root.step)
            }
        }
    }
}
