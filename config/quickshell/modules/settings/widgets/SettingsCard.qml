import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../core"

Rectangle {
    id: root

    property string title: ""
    property string description: ""
    property string iconGlyph: ""
    default property alias content: contentLayout.data

    Layout.fillWidth: true
    implicitHeight: mainCol.implicitHeight + DesignTokens.spacingXL * 2

    radius: DesignTokens.radiusMD
    color: ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.40)
    border.width: 1
    border.color: ColorScheme.withAlpha(ColorScheme.outline, 0.12)

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        anchors.margins: DesignTokens.spacingXL
        spacing: DesignTokens.spacingMD

        RowLayout {
            id: headerRow
            visible: root.title.length > 0
            Layout.fillWidth: true
            spacing: DesignTokens.spacingMD

            Text {
                visible: root.iconGlyph.length > 0
                text: root.iconGlyph
                font.family: Style.fontMono
                font.pixelSize: Style.fontSizeLG
                color: ColorScheme.accent
                renderType: Style.renderType
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.title
                    font.family: Style.fontUI
                    font.pixelSize: Style.fontSizeMD
                    font.weight: Font.DemiBold
                    color: ColorScheme.text
                    renderType: Style.renderType
                }

                Text {
                    visible: root.description.length > 0
                    text: root.description
                    font.family: Style.fontUI
                    font.pixelSize: Style.fontSizeSM
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.60)
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    renderType: Style.renderType
                }
            }
        }

        Rectangle {
            visible: root.title.length > 0 && contentLayout.children.length > 0
            Layout.fillWidth: true
            height: 1
            color: ColorScheme.withAlpha(ColorScheme.outline, 0.08)
        }

        ColumnLayout {
            id: contentLayout
            Layout.fillWidth: true
            spacing: DesignTokens.spacingMD
        }
    }
}
