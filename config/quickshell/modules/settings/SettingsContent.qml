import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../core"
import "widgets"
import "."

Item {
    id: root

    property int currentPage: 0
    property string searchQuery: ""
    property var searchResults: []

    signal navigateToPage(int pageIndex)

    onSearchQueryChanged: {
        if (searchQuery.trim().length > 0) {
            root.searchResults = SettingsRegistry.search(searchQuery.trim());
        } else {
            root.searchResults = [];
        }
    }

    readonly property var activePageDef: SettingsRegistry.pages[currentPage]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: DesignTokens.spacingXXL
        spacing: DesignTokens.spacingLG

        // --- Page Header ---
        RowLayout {
            Layout.fillWidth: true
            spacing: DesignTokens.spacingLG

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: DesignTokens.radiusSM
                color: ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                border.width: 1
                border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.30)

                Text {
                    anchors.centerIn: parent
                    text: root.searchQuery.length > 0 ? "\uf002" : (root.activePageDef.icon || "\uf013")
                    font.family: Style.fontMono
                    font.pixelSize: Style.fontSizeHeading
                    color: ColorScheme.accent
                    renderType: Style.renderType
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.searchQuery.length > 0 ? ("Search Results for \"" + root.searchQuery + "\" (" + root.searchResults.length + ")") : (root.activePageDef.name || "")
                    font.family: Style.fontUI
                    font.pixelSize: Style.fontSizeHeading
                    font.weight: Font.Bold
                    color: ColorScheme.text
                    renderType: Style.renderType
                }

                Text {
                    text: root.searchQuery.length > 0 ? "Click any search result to jump directly to that setting page." : (root.activePageDef.desc || "")
                    font.family: Style.fontUI
                    font.pixelSize: Style.fontSizeSM
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.60)
                    renderType: Style.renderType
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: ColorScheme.withAlpha(ColorScheme.outline, 0.10)
        }

        // --- Main Content: Search Results OR Active Page Loader ---
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width - DesignTokens.spacingLG
                spacing: DesignTokens.spacingLG

                // --- SEARCH RESULTS LIST ---
                ColumnLayout {
                    visible: root.searchQuery.length > 0
                    Layout.fillWidth: true
                    spacing: DesignTokens.spacingMD

                    Text {
                        visible: root.searchResults.length === 0
                        text: "No settings found matching your query."
                        font.family: Style.fontUI
                        font.pixelSize: Style.fontSizeMD
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.50)
                        renderType: Style.renderType
                        Layout.topMargin: DesignTokens.spacingXXL
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Repeater {
                        model: root.searchResults

                        delegate: Rectangle {
                            id: searchItem
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: DesignTokens.radiusMD
                            color: itemMouse.containsMouse ? ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.70) : ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.35)
                            border.width: 1
                            border.color: ColorScheme.withAlpha(ColorScheme.outline, 0.15)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: DesignTokens.spacingLG
                                spacing: DesignTokens.spacingLG

                                Text {
                                    text: modelData.pageIcon || "\uf013"
                                    font.family: Style.fontMono
                                    font.pixelSize: Style.fontSizeMD
                                    color: ColorScheme.accent
                                    renderType: Style.renderType
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: modelData.label
                                        font.family: Style.fontUI
                                        font.pixelSize: Style.fontSizeMD
                                        font.weight: Font.SemiBold
                                        color: ColorScheme.text
                                        renderType: Style.renderType
                                    }

                                    Text {
                                        text: modelData.pageName + " › " + modelData.section
                                        font.family: Style.fontUI
                                        font.pixelSize: Style.fontSizeXS
                                        color: ColorScheme.withAlpha(ColorScheme.text, 0.50)
                                        renderType: Style.renderType
                                    }
                                }

                                Text {
                                    text: "\uf054" // chevron-right
                                    font.family: Style.fontMono
                                    font.pixelSize: Style.fontSizeSM
                                    color: ColorScheme.withAlpha(ColorScheme.text, 0.40)
                                    renderType: Style.renderType
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.navigateToPage(searchItem.modelData.pageIndex);
                                }
                            }
                        }
                    }
                }

                // --- ACTIVE PAGE COMPONENT LOADER ---
                Loader {
                    id: pageLoader
                    visible: root.searchQuery.length === 0
                    Layout.fillWidth: true
                    asynchronous: true
                    source: (root.searchQuery.length === 0 && root.activePageDef && root.activePageDef.component) ? root.activePageDef.component : ""
                }
            }
        }
    }
}
