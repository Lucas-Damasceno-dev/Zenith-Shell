import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"
import "."

PopupWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    showScrim: true
    scrimOpacity: 0.70
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0
    layerNamespace: "quickshell-settings"

    property int activePage: 0
    property string activeSearch: ""

    // Close on Escape key
    Keys.onEscapePressed: root.isOpen = false

    // Center Modal Box
    Rectangle {
        id: modalFrame
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 1100)
        height: Math.min(parent.height - 64, 760)
        radius: DesignTokens.radiusLG
        color: ColorScheme.panelBg
        border.width: 1
        border.color: ColorScheme.withAlpha(ColorScheme.outline, 0.20)
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Left Navigation Sidebar
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
                onCloseRequested: root.isOpen = false
            }

            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: ColorScheme.withAlpha(ColorScheme.outline, 0.12)
            }

            // Right Main Content Area
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

    // Dismiss when clicking the scrim background outside the modal
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.isOpen = false
    }
}
