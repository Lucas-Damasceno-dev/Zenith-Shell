pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"

Rectangle {
    id: filterBar

    required property var launcher
    property alias listViewObj: filterBarList

    Layout.fillWidth: true
    Layout.preferredHeight: launcher.filterBarOpen ? 44 : 0
    visible: launcher.filterBarOpen
    clip: true
    radius: launcher.launcherInnerRadius
    color: launcher.launcherCardFill
    border.color: launcher.launcherCardBorder
    border.width: 1
    opacity: launcher.filterBarOpen ? 1 : 0

    Behavior on Layout.preferredHeight {
        enabled: !FeatureFlags.reducedMotion
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        enabled: !FeatureFlags.reducedMotion
        NumberAnimation { duration: 150 }
    }

    ListView {
        id: filterBarList
        anchors.fill: parent
        anchors.margins: 6
        orientation: ListView.Horizontal
        spacing: DesignTokens.spacingSM
        currentIndex: launcher.filterBarIndex
        clip: true
        reuseItems: true
        model: ListModel {
            id: filterCategoryModel
            ListElement { key: ""; label: "Todos"; icon: "\u{f00a}"; shortcut: "0" }
            ListElement { key: "Network"; label: "Internet"; icon: "\u{f0ac}"; shortcut: "1" }
            ListElement { key: "Development"; label: "Dev"; icon: "\u{f121}"; shortcut: "2" }
            ListElement { key: "Game"; label: "Jogos"; icon: "\u{f11b}"; shortcut: "3" }
            ListElement { key: "AudioVideo"; label: "Media"; icon: "\u{f001}"; shortcut: "4" }
            ListElement { key: "Graphics"; label: "Gráficos"; icon: "\u{f1fc}"; shortcut: "5" }
            ListElement { key: "Office"; label: "Office"; icon: "\u{f15c}"; shortcut: "6" }
            ListElement { key: "Utility"; label: "Utilit."; icon: "\u{f0ad}"; shortcut: "7" }
            ListElement { key: "System"; label: "Sistema"; icon: "\u{f085}"; shortcut: "8" }
            ListElement { key: "Chat"; label: "Chat"; icon: "\u{f075}"; shortcut: "9" }
            ListElement { key: "Science"; label: "Ciência"; icon: "\u{f0c3}"; shortcut: "" }
            ListElement { key: "Education"; label: "Educação"; icon: "\u{f19d}"; shortcut: "" }
        }

        delegate: Rectangle {
            required property var model
            required property int index
            property bool _hovered: false
            readonly property bool _selected: launcher.categoryFilter === model.key
            readonly property bool _focused: filterBarList.currentIndex === index
            width: filterChipRow.implicitWidth + 18
            height: 32
            radius: 8
            color: _selected
                ? ColorScheme.stateSelected
                : (_hovered || _focused ? ColorScheme.stateHover : "transparent")
            border.color: _selected
                ? ColorScheme.withAlpha(ColorScheme.accent, 0.4)
                : (_hovered || _focused
                    ? ColorScheme.withAlpha(ColorScheme.foreground, DesignTokens.hoverBorderOpacity)
                    : "transparent")
            border.width: 1

            Behavior on color {
                enabled: !FeatureFlags.reducedMotion
                ColorAnimation { duration: DesignTokens.durationFast }
            }
            Behavior on border.color {
                enabled: !FeatureFlags.reducedMotion
                ColorAnimation { duration: DesignTokens.durationFast }
            }

            Row {
                id: filterChipRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: model.icon
                    font.family: Style.fontMono
                    font.pixelSize: DesignTokens.iconSizeXS
                    color: _selected
                        ? ColorScheme.accent
                        : (_hovered || _focused
                            ? launcher.launcherTextMuted
                            : launcher.launcherTextSubtle)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: model.label
                    font.pixelSize: DesignTokens.fontSizeXS
                    font.family: Style.fontUI
                    font.weight: _selected ? Font.DemiBold : Font.Normal
                    color: _selected
                        ? ColorScheme.accent
                        : (_hovered || _focused
                            ? launcher.launcherTextMuted
                            : launcher.launcherTextSubtle)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: _hovered = true
                onExited: _hovered = false
                onClicked: {
                    launcher.categoryFilter = model.key;
                    launcher.filterBarIndex = index;
                    launcher.updateSearch();
                    launcher.searchFieldObj.forceActiveFocus();
                }
            }

            ListView.onReused: _hovered = false
            ListView.onPooled: _hovered = false
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Left) {
                launcher.filterBarIndex = Math.max(0, launcher.filterBarIndex - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                launcher.filterBarIndex = Math.min(filterCategoryModel.count - 1, launcher.filterBarIndex + 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_K) {
                launcher.filterBarIndex = Math.max(0, launcher.filterBarIndex - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_L || event.key === Qt.Key_J) {
                launcher.filterBarIndex = Math.min(filterCategoryModel.count - 1, launcher.filterBarIndex + 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                let item = filterCategoryModel.get(launcher.filterBarIndex);
                if (item) {
                    launcher.categoryFilter = item.key;
                    launcher.updateSearch();
                }
                launcher.filterBarOpen = false;
                launcher.searchFieldObj.forceActiveFocus();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                launcher.filterBarOpen = false;
                launcher.searchFieldObj.forceActiveFocus();
                event.accepted = true;
            } else {
                // Number shortcuts 0-9
                let numStr = event.text;
                if (numStr >= "0" && numStr <= "9") {
                    for (let i = 0; i < filterCategoryModel.count; i++) {
                        if (filterCategoryModel.get(i).shortcut === numStr) {
                            launcher.categoryFilter = filterCategoryModel.get(i).key;
                            launcher.filterBarIndex = i;
                            launcher.filterBarOpen = false;
                            launcher.updateSearch();
                            launcher.searchFieldObj.forceActiveFocus();
                            event.accepted = true;
                            return;
                        }
                    }
                }

                // Prefix or label character matching
                let ch = event.text.toLowerCase();
                if (ch.length === 1) {
                    for (let i = 0; i < filterCategoryModel.count; i++) {
                        let item = filterCategoryModel.get(i);
                        let lbl = item.label.toLowerCase();
                        if (lbl.startsWith(ch)) {
                            launcher.categoryFilter = item.key;
                            launcher.filterBarIndex = i;
                            launcher.filterBarOpen = false;
                            launcher.updateSearch();
                            launcher.searchFieldObj.forceActiveFocus();
                            event.accepted = true;
                            return;
                        }
                    }
                }
            }
        }
    }
}
