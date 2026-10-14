import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../"

RowLayout {
    id: root

    property string configKey: ""
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string unit: ""
    property int decimals: 0

    signal valueModified(real nextValue)

    spacing: DesignTokens.spacingMD
    implicitWidth: 260
    implicitHeight: 28

    Component.onCompleted: {
        if (configKey.length > 0 && SettingsConfig.ready) {
            root.value = SettingsConfig.getNumber(configKey, root.value);
        }
    }

    Connections {
        target: SettingsConfig
        function onConfigChanged(path, nextVal) {
            if (path === root.configKey) {
                root.value = Number(nextVal);
            }
        }
        function onLoaded() {
            if (root.configKey.length > 0) {
                root.value = SettingsConfig.getNumber(root.configKey, root.value);
            }
        }
    }

    Item {
        id: sliderContainer
        Layout.fillWidth: true
        Layout.preferredHeight: 20
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.90)

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, Math.min(parent.width, (parent.width * (root.value - root.from) / Math.max(0.0001, root.to - root.from))))
                radius: 3
                color: ColorScheme.accent
            }
        }

        Rectangle {
            id: thumb
            width: 16
            height: 16
            radius: 8
            color: ColorScheme.accent
            border.width: 2
            border.color: ColorScheme.surface
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * (root.value - root.from) / Math.max(0.0001, root.to - root.from)))
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            function updateFromMouse(mouseX) {
                var ratio = Math.max(0, Math.min(1, mouseX / parent.width));
                var rawVal = root.from + ratio * (root.to - root.from);
                if (root.stepSize > 0) {
                    rawVal = Math.round((rawVal - root.from) / root.stepSize) * root.stepSize + root.from;
                }
                rawVal = Math.max(root.from, Math.min(root.to, rawVal));
                root.value = rawVal;
                if (root.configKey.length > 0) {
                    SettingsConfig.set(root.configKey, rawVal);
                }
                root.valueModified(rawVal);
            }

            onPressed: mouse => updateFromMouse(mouse.x)
            onPositionChanged: mouse => {
                if (pressed) updateFromMouse(mouse.x);
            }
        }
    }

    Rectangle {
        id: valueBadge
        Layout.preferredWidth: Math.max(76, valueText.implicitWidth + DesignTokens.spacingMD * 2)
        Layout.preferredHeight: 24
        Layout.alignment: Qt.AlignVCenter
        radius: DesignTokens.radiusXS
        color: ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.50)
        border.width: 1
        border.color: ColorScheme.withAlpha(ColorScheme.outline, 0.15)

        Text {
            id: valueText
            anchors.centerIn: parent
            text: (root.decimals > 0 ? root.value.toFixed(root.decimals) : Math.round(root.value).toString()) + (root.unit.length > 0 ? " " + root.unit : "")
            font.family: Style.fontMono
            font.pixelSize: Style.fontSizeXS
            font.weight: Font.Medium
            color: ColorScheme.text
            renderType: Style.renderType
        }
    }
}
