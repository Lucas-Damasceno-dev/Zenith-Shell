import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"
import "."

/**
 * SettingsWindow - Embeddable settings view for Zenith-Shell.
 */
Rectangle {
    id: root

    property int activePage: 0
    property string activeSearch: ""

    signal closeRequested()

    color: ColorScheme.panelBg
    radius: DesignTokens.radiusLG
    border.width: 1
    border.color: ColorScheme.withAlpha(ColorScheme.outline, 0.20)
    clip: true

    RowLayout {
        anchors.fill: parent
        spacing: 0

        SettingsNav {
            id: navSidebar
            currentPage: root.activePage
            searchQuery: root.activeSearch
            onPageSelected: index => {
                root.activePage = index;
                contentView.currentPage = index;
            }
            onSearchUpdated: query => {
                root.activeSearch = query;
                contentView.searchQuery = query;
            }
            onCloseRequested: root.closeRequested()
        }

        Rectangle {
            Layout.fillHeight: true
            width: 1
            color: ColorScheme.withAlpha(ColorScheme.outline, 0.12)
        }

        SettingsContent {
            id: contentView
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentPage: root.activePage
            searchQuery: root.activeSearch
            onNavigateToPage: pageIndex => {
                root.activePage = pageIndex;
                contentView.currentPage = pageIndex;
                navSidebar.currentPage = pageIndex;
                root.activeSearch = "";
                navSidebar.searchQuery = "";
                contentView.searchQuery = "";
            }
        }
    }
}
