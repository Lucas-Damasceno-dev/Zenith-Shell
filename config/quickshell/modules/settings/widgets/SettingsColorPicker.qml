import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../"

RowLayout {
    id: root

    property string configKey: ""
    property string selectedColor: "#7aa2f7"
    readonly property var presetColors: [
        "#7aa2f7", "#bb9af7", "#7dcfff", "#9ece6a", "#f7768e", "#ff9e64", "#e0af68", "#c0caf5"
    ]

    signal colorChosen(string hexColor)

    spacing: DesignTokens.spacingSM
    implicitHeight: 32

    Component.onCompleted: {
        if (configKey.length > 0 && SettingsConfig.ready) {
            root.selectedColor = SettingsConfig.getString(configKey, root.selectedColor);
        }
    }

    Connections {
        target: SettingsConfig
        function onConfigChanged(path, nextVal) {
            if (path === root.configKey) {
                root.selectedColor = String(nextVal || "#7aa2f7");
            }
        }
        function onLoaded() {
            if (root.configKey.length > 0) {
                root.selectedColor = SettingsConfig.getString(root.configKey, root.selectedColor);
            }
        }
    }

    // Active color preview
    Rectangle {
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        Layout.alignment: Qt.AlignVCenter
        radius: 13
        color: root.selectedColor
        border.width: 2
        border.color: ColorScheme.surfaceVariant
    }

    // Swatches
    Repeater {
        model: root.presetColors

        delegate: Rectangle {
            id: swatch
            required property var modelData

            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            radius: 11
            color: modelData
            border.width: root.selectedColor.toLowerCase() === modelData.toLowerCase() ? 2 : 1
            border.color: root.selectedColor.toLowerCase() === modelData.toLowerCase() ? ColorScheme.text : ColorScheme.withAlpha(ColorScheme.outline, 0.20)

            scale: root.selectedColor.toLowerCase() === modelData.toLowerCase() ? 1.15 : 1.0
            Behavior on scale { NumberAnimation { duration: 120 } }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedColor = swatch.modelData;
                    if (root.configKey.length > 0) {
                        SettingsConfig.set(root.configKey, swatch.modelData);
                    }
                    root.colorChosen(swatch.modelData);
                }
            }
        }
    }

    // Hex input
    SettingsTextField {
        preferredWidth: 90
        text: root.selectedColor
        onEditingFinished: newHex => {
            if (newHex.indexOf("#") === 0 && (newHex.length === 7 || newHex.length === 9)) {
                root.selectedColor = newHex;
                if (root.configKey.length > 0) {
                    SettingsConfig.set(root.configKey, newHex);
                }
                root.colorChosen(newHex);
            }
        }
    }
}
