pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"

RowLayout {
    required property var launcher
    property alias searchFieldObj: searchField
    readonly property bool compactState: !launcher.showFullLauncher

    Layout.fillWidth: true
    Layout.fillHeight: false
    Layout.alignment: Qt.AlignTop
    spacing: launcher.launcherChipGap

    TextField {
        id: searchField
        Keys.priority: Keys.BeforeItem
        Layout.preferredWidth: -1
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        horizontalAlignment: compactState ? TextInput.AlignHCenter : TextInput.AlignLeft
        placeholderText: "Pesquisar apps, arquivos, emojis..."
        placeholderTextColor: launcher.launcherTextSubtle
        font.pixelSize: DesignTokens.fontSizeLG
        font.family: launcher.currentMode === "cmd" ? Style.fontMono : Style.fontUI
        color: ColorScheme.text
        leftPadding: 40
        rightPadding: 44

        background: Rectangle {
            radius: launcher.showFullLauncher ? launcher.launcherCardRadius : 22
            color: launcher.showFullLauncher
                ? (ColorScheme.isDark ? ColorScheme.withAlpha(ColorScheme.surfaceHigh, 0.54) : ColorScheme.withAlpha(ColorScheme.surface, 0.92))
                : "transparent"
            border.color: searchField.activeFocus
                ? ColorScheme.withAlpha(launcher.getModeColor(launcher.currentMode), 0.8)
                : (launcher.showFullLauncher ? launcher.launcherCardBorder : "transparent")
            border.width: launcher.showFullLauncher ? 1 : 0

            Behavior on radius {
                enabled: !FeatureFlags.reducedMotion
                NumberAnimation { duration: 200 }
            }
            Behavior on border.color {
                enabled: !FeatureFlags.reducedMotion
                ColorAnimation { duration: 200 }
            }

            Text {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                text: launcher.currentMode === "apps" ? "\u{f002}" : launcher.getModeInfo(launcher.currentMode).icon
                font.family: Style.fontMono
                font.pixelSize: 14
                color: ColorScheme.isDark ? ColorScheme.withAlpha(launcher.getModeColor(launcher.currentMode), 0.6) : launcher.getModeColor(launcher.currentMode)
                Behavior on color {
                    enabled: !FeatureFlags.reducedMotion
                    ColorAnimation { duration: 200 }
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: launcher.launcherCardRadius + 3
                color: "transparent"
                border.color: ColorScheme.withAlpha(launcher.getModeColor(launcher.currentMode), searchField.activeFocus ? 0.35 : 0)
                border.width: 2
                Behavior on border.color {
                    enabled: !FeatureFlags.reducedMotion
                    ColorAnimation { duration: 300 }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                radius: 6
                color: launcher.filterBarOpen || launcher.categoryFilter !== ""
                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.18)
                    : (funnelMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.text, 0.08) : "transparent")
                Behavior on color {
                    enabled: !FeatureFlags.reducedMotion
                    ColorAnimation { duration: 150 }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        text: "\u{f0b0}"
                        font.family: Style.fontMono
                        font.pixelSize: 12
                        color: launcher.categoryFilter !== ""
                            ? ColorScheme.accent
                            : ColorScheme.withAlpha(ColorScheme.text, 0.45)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: launcher.categoryFilter !== ""
                        text: {
                            var filterIcons = {
                                "Network": "\u{f0ac}", "Development": "\u{f121}", "Game": "\u{f11b}",
                                "AudioVideo": "\u{f001}", "Graphics": "\u{f1fc}", "Office": "\u{f15c}",
                                "Utility": "\u{f0ad}", "System": "\u{f085}", "Chat": "\u{f075}",
                                "Science": "\u{f0c3}", "Education": "\u{f19d}"
                            };
                            return filterIcons[launcher.categoryFilter] || "\u{f02b}";
                        }
                        font.family: Style.fontMono
                        font.pixelSize: 10
                        color: ColorScheme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: funnelMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (launcher.filterBarOpen) {
                            launcher.filterBarOpen = false;
                            searchField.forceActiveFocus();
                        } else {
                            launcher.openFilterMenu();
                        }
                    }
                }
            }
        }

        onTextChanged: {
            var hasText = searchField.text.trim().length > 0;
            if (launcher.searchHasText !== hasText)
                launcher.searchHasText = hasText;
            if (launcher._restoringLauncherState)
                return;
            launcher.launcherStateRestorePending = false;
            launcher.persistLauncherSessionState();
            launcher.requestSearchUpdate(searchField.text);
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Alt) {
                launcher.togglePreviewPanel();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Down) {
                if (launcher.contextMenuOpen) {
                    launcher.contextList.currentIndex = Math.min(launcher.contextList.currentIndex + 1, launcher.contextModel.count - 1);
                } else if (launcher.appsList.count > 0) {
                    if (launcher.minimalMode && !launcher.minimalExpanded && searchField.text.length > 0) {
                        launcher.minimalExpanded = true;
                        launcher.previewVisible = true;
                    }
                    launcher.selectedIndex = Math.max(launcher.selectedIndex, 0);
                    launcher.appsList.forceActiveFocus();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                if (launcher.contextMenuOpen) {
                    launcher.contextList.currentIndex = Math.max(launcher.contextList.currentIndex - 1, 0);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (launcher.contextMenuOpen) { launcher.contextMenuOpen = false; }
                else { launcher.isOpen = false; }
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                if (launcher.cheatSheetOpen) {
                    launcher.cheatSheetOpen = false;
                    searchField.forceActiveFocus();
                } else {
                    launcher.openModeMenu();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                if (launcher.filterBarOpen) {
                    launcher.filterBarOpen = false;
                    searchField.forceActiveFocus();
                } else {
                    launcher.openFilterMenu();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (launcher.contextMenuOpen) {
                    launcher.executeContextAction(launcher.contextList.currentIndex, launcher.selectedIndex);
                } else {
                    launcher.launchItem(launcher.selectedIndex);
                }
                event.accepted = true;
            }
        }

        Keys.onReleased: (event) => {
            // Replaced Alt key behaviour
        }
    }
}
