import QtQuick
import QtQuick.Layouts
import "../../../core"

RowLayout {
    id: root

    property var tabs: [] // Array of { id: "audio", label: "Audio", icon: "\uf028" }
    property string activeTab: ""

    signal tabSelected(string tabId)

    spacing: DesignTokens.spacingSM
    Layout.fillWidth: true
    implicitHeight: 36

    Repeater {
        model: root.tabs

        delegate: Rectangle {
            id: tabItem
            required property var modelData
            required property int index

            readonly property bool isSelected: root.activeTab === modelData.id

            Layout.preferredHeight: 32
            implicitWidth: tabRow.implicitWidth + DesignTokens.spacingLG * 2
            radius: DesignTokens.radiusSM

            color: isSelected ? ColorScheme.accent : 
                   mouseArea.containsMouse ? ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.60) :
                   ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.25)
            border.width: 1
            border.color: isSelected ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.outline, 0.12)

            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                id: tabRow
                anchors.centerIn: parent
                spacing: DesignTokens.spacingSM

                Text {
                    visible: !!(modelData.icon && modelData.icon.length > 0)
                    text: modelData.icon || ""
                    font.family: Style.fontMono
                    font.pixelSize: Style.fontSizeSM
                    color: tabItem.isSelected ? ColorScheme.onPrimary : ColorScheme.text
                    renderType: Style.renderType
                }

                Text {
                    text: modelData.label || ""
                    font.family: Style.fontUI
                    font.pixelSize: Style.fontSizeSM
                    font.weight: tabItem.isSelected ? Font.Bold : Font.Normal
                    color: tabItem.isSelected ? ColorScheme.onPrimary : ColorScheme.text
                    renderType: Style.renderType
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.activeTab = tabItem.modelData.id;
                    root.tabSelected(tabItem.modelData.id);
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
    }
}
