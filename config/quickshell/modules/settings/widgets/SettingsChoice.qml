import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../"

RowLayout {
    id: root

    property string configKey: ""
    property var options: []
    property var currentValue: ""

    signal choiceSelected(var value)

    spacing: 4
    implicitHeight: 32

    Component.onCompleted: {
        if (configKey.length > 0 && SettingsConfig.ready) {
            root.currentValue = SettingsConfig.get(configKey, root.currentValue);
        }
    }

    Connections {
        target: SettingsConfig
        function onConfigChanged(path, nextVal) {
            if (path === root.configKey) {
                root.currentValue = nextVal;
            }
        }
        function onLoaded() {
            if (root.configKey.length > 0) {
                root.currentValue = SettingsConfig.get(root.configKey, root.currentValue);
            }
        }
    }

    Repeater {
        model: root.options

        delegate: Rectangle {
            id: chip
            required property var modelData
            required property int index

            readonly property var optVal: (typeof modelData === "object" && modelData !== null && modelData.value !== undefined) ? modelData.value : modelData
            readonly property string optLabel: (typeof modelData === "object" && modelData !== null && modelData.label !== undefined) ? modelData.label : String(modelData)
            readonly property bool isSelected: String(root.currentValue) === String(optVal)

            Layout.preferredHeight: 28
            implicitWidth: chipText.implicitWidth + DesignTokens.spacingMD * 2
            radius: DesignTokens.radiusSM
            color: isSelected ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.40)
            border.width: 1
            border.color: isSelected ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.outline, 0.15)

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                id: chipText
                anchors.centerIn: parent
                text: chip.optLabel
                font.family: Style.fontUI
                font.pixelSize: Style.fontSizeXS
                font.weight: chip.isSelected ? Font.Bold : Font.Normal
                color: chip.isSelected ? ColorScheme.onPrimary : ColorScheme.text
                renderType: Style.renderType
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.currentValue = chip.optVal;
                    if (root.configKey.length > 0) {
                        SettingsConfig.set(root.configKey, chip.optVal);
                    }
                    root.choiceSelected(chip.optVal);
                }
            }
        }
    }
}
