pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"

Rectangle {
    id: modeBar

    required property var launcher
    property alias listViewObj: modeBarList

    Layout.fillWidth: true
    Layout.preferredHeight: launcher.cheatSheetOpen ? 44 : 0
    visible: launcher.cheatSheetOpen
    clip: true
    radius: launcher.launcherInnerRadius
    color: launcher.launcherCardFill
    border.color: launcher.launcherCardBorder
    border.width: 1
    opacity: launcher.cheatSheetOpen ? 1 : 0

    Behavior on Layout.preferredHeight {
        enabled: !FeatureFlags.reducedMotion
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        enabled: !FeatureFlags.reducedMotion
        NumberAnimation { duration: 150 }
    }

    ListView {
        id: modeBarList
        anchors.fill: parent
        anchors.margins: 6
        orientation: ListView.Horizontal
        spacing: DesignTokens.spacingSM
        currentIndex: launcher.cheatSheetIndex
        clip: true
        reuseItems: true
        model: ListModel {
            id: modeModel
            ListElement { prefix: ""; label: "Apps"; icon: "\u{f002}"; shortcut: "0" }
            ListElement { prefix: "="; label: "Calc"; icon: "\u{f1ec}"; shortcut: "1" }
            ListElement { prefix: "g?"; label: "Web"; icon: "\u{f0ac}"; shortcut: "2" }
            ListElement { prefix: "/"; label: "Arquivos"; icon: "\u{f07b}"; shortcut: "3" }
            ListElement { prefix: ">"; label: "Cmd"; icon: "\u{f120}"; shortcut: "4" }
            ListElement { prefix: "w?"; label: "Janelas"; icon: "\u{f2d0}"; shortcut: "5" }
            ListElement { prefix: "cb?"; label: "Clipboard"; icon: "\u{f0ea}"; shortcut: "6" }
            ListElement { prefix: "em?"; label: "Emoji"; icon: "\u{f118}"; shortcut: "7" }
            ListElement { prefix: "nix?"; label: "NixPkgs"; icon: "\u{f313}"; shortcut: "8" }
            ListElement { prefix: "opt?"; label: "NixOpts"; icon: "\u{f013}"; shortcut: "9" }
            ListElement { prefix: "tr?"; label: "Tradução"; icon: "\u{f1ab}"; shortcut: "" }
            ListElement { prefix: "rp?"; label: "Projetos"; icon: "\u{f07c}"; shortcut: "" }
            ListElement { prefix: "rf?"; label: "Recentes"; icon: "\u{f016}"; shortcut: "" }
            ListElement { prefix: "sn?"; label: "Snippets"; icon: "\u{f121}"; shortcut: "" }
            ListElement { prefix: "ai?"; label: "IA"; icon: "\u{f135}"; shortcut: "" }
            ListElement { prefix: "kill?"; label: "Kill"; icon: "\u{f00d}"; shortcut: "" }
            ListElement { prefix: "vol "; label: "Volume"; icon: "\u{f028}"; shortcut: "" }
            ListElement { prefix: "bri "; label: "Brilho"; icon: "\u{f185}"; shortcut: "" }
        }

        delegate: Rectangle {
            required property var model
            required property int index
            property bool _hovered: false
            readonly property bool _selected: model.prefix === ""
                ? !launcher.searchHasText
                : launcher.searchFieldObj.text.startsWith(model.prefix)
            readonly property bool _focused: modeBarList.currentIndex === index
            width: modeChipRow.implicitWidth + 18
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
                id: modeChipRow
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
                    launcher.cheatSheetIndex = index;
                    if (model.prefix === "") {
                        launcher.searchFieldObj.text = "";
                    } else {
                        launcher.searchFieldObj.text = model.prefix;
                    }
                    launcher.cheatSheetOpen = false;
                    launcher.searchFieldObj.forceActiveFocus();
                }
            }

            ListView.onReused: _hovered = false
            ListView.onPooled: _hovered = false
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Left) {
                launcher.cheatSheetIndex = Math.max(0, launcher.cheatSheetIndex - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                launcher.cheatSheetIndex = Math.min(modeModel.count - 1, launcher.cheatSheetIndex + 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_K) {
                launcher.cheatSheetIndex = Math.max(0, launcher.cheatSheetIndex - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_L || event.key === Qt.Key_J) {
                launcher.cheatSheetIndex = Math.min(modeModel.count - 1, launcher.cheatSheetIndex + 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                let item = modeModel.get(launcher.cheatSheetIndex);
                if (item) {
                    if (item.prefix === "") {
                        launcher.searchFieldObj.text = "";
                    } else {
                        launcher.searchFieldObj.text = item.prefix;
                    }
                }
                launcher.cheatSheetOpen = false;
                launcher.searchFieldObj.forceActiveFocus();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                launcher.cheatSheetOpen = false;
                launcher.searchFieldObj.forceActiveFocus();
                event.accepted = true;
            } else {
                // Number shortcuts 0-9
                let numStr = event.text;
                if (numStr >= "0" && numStr <= "9") {
                    for (let i = 0; i < modeModel.count; i++) {
                        if (modeModel.get(i).shortcut === numStr) {
                            let item = modeModel.get(i);
                            if (item.prefix === "") {
                                launcher.searchFieldObj.text = "";
                            } else {
                                launcher.searchFieldObj.text = item.prefix;
                            }
                            launcher.cheatSheetIndex = i;
                            launcher.cheatSheetOpen = false;
                            launcher.searchFieldObj.forceActiveFocus();
                            event.accepted = true;
                            return;
                        }
                    }
                }

                // Prefix matching
                let ch = event.text.toLowerCase();
                if (ch.length === 1) {
                    for (let i = 0; i < modeModel.count; i++) {
                        let item = modeModel.get(i);
                        let lbl = item.label.toLowerCase();
                        if (lbl.startsWith(ch)) {
                            if (item.prefix === "") {
                                launcher.searchFieldObj.text = "";
                            } else {
                                launcher.searchFieldObj.text = item.prefix;
                            }
                            launcher.cheatSheetIndex = i;
                            launcher.cheatSheetOpen = false;
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
