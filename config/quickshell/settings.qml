pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "core"
import "modules/settings"

PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Dark scrim backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.65)

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }
    }

    // Modal Box in Center (adapts to 768p and larger screens)
    Rectangle {
        id: modalFrame
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 1060)
        height: Math.min(parent.height - 48, 670)
        radius: DesignTokens.radiusLG
        color: ColorScheme.panelBg
        border.width: 1
        border.color: ColorScheme.withAlpha(ColorScheme.outline, 0.22)
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            SettingsNav {
                id: navSidebar
                currentPage: 0
                onPageSelected: index => {
                    contentView.currentPage = index;
                }
                onSearchUpdated: query => {
                    contentView.searchQuery = query;
                }
                onCloseRequested: Qt.quit()
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
                currentPage: 0
                onNavigateToPage: pageIndex => {
                    contentView.currentPage = pageIndex;
                    navSidebar.currentPage = pageIndex;
                    navSidebar.searchQuery = "";
                    contentView.searchQuery = "";
                }
            }
        }
    }

    // Escape key closes
    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }
}
