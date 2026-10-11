import QtQuick
import QtQuick.Layouts
import "../../../core"

Rectangle {
    id: root

    property string text: ""
    property string iconGlyph: ""
    property bool isPrimary: false
    property bool isDanger: false
    property bool enabled: true

    signal clicked()

    Layout.preferredHeight: 32
    implicitWidth: btnRow.implicitWidth + DesignTokens.spacingLG * 2
    radius: DesignTokens.radiusSM

    color: !root.enabled ? ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.20) :
           mouseArea.pressed ? (root.isDanger ? ColorScheme.withAlpha(ColorScheme.red, 0.70) : (root.isPrimary ? ColorScheme.withAlpha(ColorScheme.accent, 0.70) : ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.80))) :
           mouseArea.containsMouse ? (root.isDanger ? ColorScheme.withAlpha(ColorScheme.red, 0.90) : (root.isPrimary ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.60))) :
           (root.isDanger ? ColorScheme.red : (root.isPrimary ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.35)))

    border.width: 1
    border.color: root.isDanger ? ColorScheme.red : (root.isPrimary ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.outline, 0.20))

    Behavior on color { ColorAnimation { duration: 120 } }

    RowLayout {
        id: btnRow
        anchors.centerIn: parent
        spacing: DesignTokens.spacingSM

        Text {
            visible: root.iconGlyph.length > 0
            text: root.iconGlyph
            font.family: Style.fontMono
            font.pixelSize: Style.fontSizeSM
            color: (root.isPrimary || root.isDanger) ? ColorScheme.onPrimary : ColorScheme.text
            renderType: Style.renderType
        }

        Text {
            visible: root.text.length > 0
            text: root.text
            font.family: Style.fontUI
            font.pixelSize: Style.fontSizeSM
            font.weight: root.isPrimary ? Font.DemiBold : Font.Normal
            color: (root.isPrimary || root.isDanger) ? ColorScheme.onPrimary : ColorScheme.text
            renderType: Style.renderType
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
