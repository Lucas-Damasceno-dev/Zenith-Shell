import QtQuick
import QtQuick.Layouts
import "../../../core"

RowLayout {
    id: root

    property string title: ""
    property string description: ""
    property string iconGlyph: ""
    default property alias control: controlContainer.data

    Layout.fillWidth: true
    spacing: DesignTokens.spacingMD

    Text {
        visible: root.iconGlyph.length > 0
        text: root.iconGlyph
        font.family: Style.fontMono
        font.pixelSize: Style.fontSizeMD
        color: ColorScheme.withAlpha(ColorScheme.text, 0.70)
        renderType: Style.renderType
        Layout.alignment: Qt.AlignVCenter
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 2

        Text {
            text: root.title
            font.family: Style.fontUI
            font.pixelSize: Style.fontSizeMD
            font.weight: Font.Medium
            color: ColorScheme.text
            renderType: Style.renderType
        }

        Text {
            visible: root.description.length > 0
            text: root.description
            font.family: Style.fontUI
            font.pixelSize: Style.fontSizeSM
            color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            renderType: Style.renderType
        }
    }

    Item {
        id: controlContainer
        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
