import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../core"
import "../"

Rectangle {
    id: root

    property string configKey: ""
    property alias text: textInput.text
    property alias placeholderText: textInput.placeholderText
    property int preferredWidth: 260

    signal editingFinished(string newText)

    implicitWidth: preferredWidth
    implicitHeight: 32
    radius: DesignTokens.radiusSM
    color: ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.40)
    border.width: textInput.activeFocus ? 1.5 : 1
    border.color: textInput.activeFocus ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.outline, 0.20)

    Behavior on border.color { ColorAnimation { duration: 120 } }

    Component.onCompleted: {
        if (configKey.length > 0 && SettingsConfig.ready) {
            root.text = SettingsConfig.getString(configKey, root.text);
        }
    }

    Connections {
        target: SettingsConfig
        function onConfigChanged(path, nextVal) {
            if (path === root.configKey && textInput.text !== String(nextVal || "")) {
                textInput.text = String(nextVal || "");
            }
        }
        function onLoaded() {
            if (root.configKey.length > 0) {
                root.text = SettingsConfig.getString(root.configKey, root.text);
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: DesignTokens.spacingMD
        anchors.rightMargin: DesignTokens.spacingSM
        spacing: DesignTokens.spacingSM

        TextField {
            id: textInput
            Layout.fillWidth: true
            Layout.fillHeight: true
            font.family: Style.fontUI
            font.pixelSize: Style.fontSizeSM
            color: ColorScheme.text
            renderType: Style.renderType
            verticalAlignment: TextInput.AlignVCenter
            background: Item {}
            selectByMouse: true

            onEditingFinished: {
                if (root.configKey.length > 0) {
                    SettingsConfig.set(root.configKey, textInput.text);
                }
                root.editingFinished(textInput.text);
            }
        }

        Item {
            visible: textInput.text.length > 0
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: "\uf00d" // times
                font.family: Style.fontMono
                font.pixelSize: Style.fontSizeXS
                color: ColorScheme.withAlpha(ColorScheme.text, 0.50)
                renderType: Style.renderType
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    textInput.text = "";
                    if (root.configKey.length > 0) {
                        SettingsConfig.set(root.configKey, "");
                    }
                    root.editingFinished("");
                }
            }
        }
    }
}
