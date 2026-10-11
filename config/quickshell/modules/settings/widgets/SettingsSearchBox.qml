import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../core"

Rectangle {
    id: root

    property alias text: searchInput.text
    signal searchCleared()

    Layout.fillWidth: true
    Layout.preferredHeight: 36
    radius: DesignTokens.radiusSM
    color: ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.45)
    border.width: searchInput.activeFocus ? 1.5 : 1
    border.color: searchInput.activeFocus ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.outline, 0.20)

    Behavior on border.color { ColorAnimation { duration: 120 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: DesignTokens.spacingMD
        anchors.rightMargin: DesignTokens.spacingSM
        spacing: DesignTokens.spacingSM

        Text {
            text: "\uf002" // search
            font.family: Style.fontMono
            font.pixelSize: Style.fontSizeSM
            color: ColorScheme.withAlpha(ColorScheme.text, 0.50)
            renderType: Style.renderType
            Layout.alignment: Qt.AlignVCenter
        }

        TextField {
            id: searchInput
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: "Search settings..."
            placeholderTextColor: ColorScheme.withAlpha(ColorScheme.text, 0.40)
            font.family: Style.fontUI
            font.pixelSize: Style.fontSizeSM
            color: ColorScheme.text
            renderType: Style.renderType
            verticalAlignment: TextInput.AlignVCenter
            background: Item {}
            selectByMouse: true
        }

        Item {
            visible: searchInput.text.length > 0
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
                    searchInput.text = "";
                    root.searchCleared();
                }
            }
        }
    }
}
