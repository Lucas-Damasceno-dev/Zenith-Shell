import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../core"
import "widgets"
import "."

Rectangle {
    id: root

    property int currentPage: 0
    property string searchQuery: ""

    signal pageSelected(int pageIndex)
    signal searchUpdated(string query)
    signal closeRequested()

    width: 300
    Layout.fillHeight: true
    color: ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.35)
    border.width: 1
    border.color: ColorScheme.withAlpha(ColorScheme.outline, 0.12)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: DesignTokens.spacingLG
        spacing: DesignTokens.spacingMD

        // --- Brand Header ---
        RowLayout {
            Layout.fillWidth: true
            spacing: DesignTokens.spacingMD

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: ColorScheme.accent

                Text {
                    anchors.centerIn: parent
                    text: "\uf013" // cog
                    font.family: Style.fontMono
                    font.pixelSize: Style.fontSizeMD
                    color: ColorScheme.onPrimary
                    renderType: Style.renderType
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "Zenith Settings"
                    font.family: Style.fontUI
                    font.pixelSize: Style.fontSizeLG
                    font.weight: Font.Bold
                    color: ColorScheme.text
                    renderType: Style.renderType
                }

                Text {
                    text: "Shell Engine v2.0"
                    font.family: Style.fontUI
                    font.pixelSize: Style.fontSizeXS
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.50)
                    renderType: Style.renderType
                }
            }
        }

        // --- Search Input ---
        SettingsSearchBox {
            id: searchBox
            onTextChanged: {
                root.searchQuery = text;
                root.searchUpdated(text);
            }
            onSearchCleared: {
                root.searchQuery = "";
                root.searchUpdated("");
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: ColorScheme.withAlpha(ColorScheme.outline, 0.08)
        }

        // --- Categories & Pages List ---
        ScrollView {
            id: navScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                id: navCol
                width: navScroll.availableWidth
                spacing: DesignTokens.spacingLG

                Repeater {
                    model: SettingsRegistry.categories

                    delegate: ColumnLayout {
                        id: catCol
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        width: navCol.width
                        spacing: DesignTokens.spacingXS

                        // Category Label
                        Text {
                            text: modelData.label.toUpperCase()
                            font.family: Style.fontUI
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.40)
                            renderType: Style.renderType
                            Layout.leftMargin: DesignTokens.spacingSM
                            Layout.topMargin: DesignTokens.spacingXS
                        }

                        // Pages in category
                        Repeater {
                            model: catCol.modelData.pages

                            delegate: Rectangle {
                                id: navItem
                                required property int modelData // page index

                                readonly property var pageDef: SettingsRegistry.pages[modelData]
                                readonly property bool isSelected: root.currentPage === modelData && root.searchQuery.length === 0

                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                width: catCol.width
                                height: 42
                                radius: DesignTokens.radiusSM

                                color: isSelected ? ColorScheme.accent :
                                       mouseArea.containsMouse ? ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.60) :
                                       "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: DesignTokens.spacingMD
                                    anchors.rightMargin: DesignTokens.spacingMD
                                    spacing: DesignTokens.spacingMD

                                    Text {
                                        text: (navItem.pageDef && navItem.pageDef.icon) ? navItem.pageDef.icon : "\uf013"
                                        font.family: Style.fontMono
                                        font.pixelSize: Style.fontSizeMD
                                        color: navItem.isSelected ? ColorScheme.onPrimary : ColorScheme.accent
                                        renderType: Style.renderType
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: (navItem.pageDef && navItem.pageDef.name) ? navItem.pageDef.name : ""
                                            font.family: Style.fontUI
                                            font.pixelSize: Style.fontSizeSM
                                            font.weight: navItem.isSelected ? Font.Bold : Font.Medium
                                            color: navItem.isSelected ? ColorScheme.onPrimary : ColorScheme.text
                                            renderType: Style.renderType
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (navItem.pageDef && navItem.pageDef.desc) ? navItem.pageDef.desc : ""
                                            font.family: Style.fontUI
                                            font.pixelSize: 10
                                            color: navItem.isSelected ? ColorScheme.withAlpha(ColorScheme.onPrimary, 0.80) : ColorScheme.withAlpha(ColorScheme.text, 0.45)
                                            renderType: Style.renderType
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentPage = navItem.modelData;
                                        root.pageSelected(navItem.modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: ColorScheme.withAlpha(ColorScheme.outline, 0.08)
        }

        // --- Bottom Actions ---
        RowLayout {
            Layout.fillWidth: true
            spacing: DesignTokens.spacingSM

            SettingsButton {
                text: "Flush"
                iconGlyph: "\uf0c7"
                Layout.fillWidth: true
                onClicked: SettingsConfig.flush()
            }

            SettingsButton {
                text: "Close"
                iconGlyph: "\uf00d"
                Layout.fillWidth: true
                isPrimary: true
                onClicked: root.closeRequested()
            }
        }
    }
}
