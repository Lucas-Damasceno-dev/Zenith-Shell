pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"
import "../../shared"

Item {
    id: paneRoot
    required property var launcher
    required property var contextModel
    property alias appsListObj: appsList
    property alias contextListObj: contextList

    readonly property int contentHeight: appsList.count > 0
        ? Math.min(appsList.contentHeight, launcher.resultsPaneMaxHeight)
        : (emptyStateColumn.implicitHeight + DesignTokens.spacingXL * 2)

    Layout.fillWidth: true
    Layout.fillHeight: false
    Layout.preferredHeight: launcher.showFullLauncher ? contentHeight : 0
    implicitHeight: launcher.showFullLauncher ? contentHeight : 0

    ListView {
        id: appsList
        Keys.priority: Keys.BeforeItem
        anchors.fill: parent
        clip: true
        visible: launcher.currentMode !== "ai" && launcher.showFullLauncher
        opacity: visible ? 1 : 0
        Behavior on opacity {
            enabled: !FeatureFlags.reducedMotion
            NumberAnimation { duration: 200 }
        }
        model: launcher ? launcher.resultsModelObj : null
        currentIndex: -1
        spacing: 2
        cacheBuffer: FeatureFlags.lowPowerUiMode ? 96 : 192
        reuseItems: true

        function syncCurrentIndexFromLauncher() {
            if (!launcher)
                return;

            var modelObj = launcher.resultsModelObj;
            var count = modelObj ? modelObj.count : 0;
            var desiredIndex = count > 0
                ? Math.max(0, Math.min(launcher.selectedIndex, count - 1))
                : -1;

            if (launcher.selectedIndex !== desiredIndex)
                launcher.selectedIndex = desiredIndex;
            if (appsList.currentIndex !== desiredIndex)
                appsList.currentIndex = desiredIndex;
        }

        Component.onCompleted: syncCurrentIndexFromLauncher()
        onModelChanged: syncCurrentIndexFromLauncher()

        highlight: Rectangle {
            color: ColorScheme.stateSelected
            radius: launcher.launcherInnerRadius
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: parent.height * 0.5
                radius: 1.5
                color: launcher.getModeColor(launcher.currentMode)
                Behavior on color {
                    enabled: !FeatureFlags.reducedMotion
                    ColorAnimation { duration: 200 }
                }
            }
        }
        highlightMoveDuration: FeatureFlags.reducedMotion ? 0 : 80

        onCurrentIndexChanged: {
            if (launcher.selectedIndex !== currentIndex)
                launcher.selectedIndex = currentIndex;
            launcher.schedulePreviewUpdate(currentIndex);
        }

        delegate: LauncherResultItem {
            launcher: paneRoot.launcher
            index: index
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Alt) {
                launcher.togglePreviewPanel();
                event.accepted = true;
                return;
            }

            if (launcher.contextMenuOpen && contextList.activeFocus) {
                if (event.key === Qt.Key_Escape) {
                    launcher.contextMenuOpen = false;
                    launcher.searchField.forceActiveFocus();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    contextList.currentIndex = Math.max(0, contextList.currentIndex - 1);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    contextList.currentIndex = Math.min(contextModel.count - 1, contextList.currentIndex + 1);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    launcher.executeContextAction(contextList.currentIndex, launcher.appsList.currentIndex);
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_Up && currentIndex === 0) {
                launcher.searchField.forceActiveFocus();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (launcher.currentMode === "ai") {
                    launcher.commandRunner.exec(["bash", RuntimePaths.scriptFile("utility_copy_text.sh"), launcher.aiPrimaryText || ""]);
                } else if (launcher.contextMenuOpen) {
                    launcher.executeContextAction(launcher.contextList.currentIndex, currentIndex);
                } else {
                    launcher.launchItem(currentIndex);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                if (launcher.cheatSheetOpen)
                    launcher.cheatSheetOpen = false;
                else
                    launcher.openModeMenu();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                if (launcher.filterBarOpen)
                    launcher.filterBarOpen = false;
                else
                    launcher.openFilterMenu();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (launcher.contextMenuOpen)
                    launcher.contextMenuOpen = false;
                else
                    launcher.searchField.forceActiveFocus();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backspace) {
                launcher.searchField.forceActiveFocus();
                if (launcher.searchField.text.length > 0)
                    launcher.searchField.text = launcher.searchField.text.substring(0, launcher.searchField.text.length - 1);
                event.accepted = true;
            } else if (event.text && event.text.length === 1 && !event.modifiers) {
                launcher.searchField.forceActiveFocus();
                launcher.searchField.text += event.text;
                event.accepted = true;
            }
        }
    }

    Connections {
        target: launcher
        function onSelectedIndexChanged() {
            appsList.syncCurrentIndexFromLauncher();
        }
    }

    Connections {
        target: launcher ? launcher.resultsModelObj : null
        function onCountChanged() {
            appsList.syncCurrentIndexFromLauncher();
        }
    }

    Item {
        anchors.fill: parent
        visible: launcher.currentMode !== "ai" && appsList.count === 0

        ColumnLayout {
            id: emptyStateColumn
            anchors.centerIn: parent
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: launcher.getModeInfo(launcher.currentMode).icon
                font.family: DesignTokens.fontFamilyMono
                font.pixelSize: DesignTokens.fontSizeXXL + 4
                color: ColorScheme.withAlpha(ColorScheme.text, 0.15)
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: {
                    if (!launcher.searchHasText) {
                        let hints = {
                            "apps": "Digite para buscar apps",
                            "calc": "Digite uma expressão (ex: 2+2)",
                            "cmd": "Digite um comando para executar",
                            "files": "Digite um nome, ~/caminho ou //raiz",
                            "emoji": "Digite para buscar emojis",
                            "clipboard": "Digite para buscar no clipboard",
                            "web": "Digite para buscar na web",
                            "nix": "Digite para buscar pacotes Nix",
                            "options": "Digite para buscar opções NixOS",
                            "windows": "Digite para buscar janelas",
                            "translate": "Digite texto para traduzir",
                            "snippets": "Digite para buscar snippets",
                            "recentProjects": "Buscando em ~/Projects e repositórios locais",
                            "ai": "Use ai? fast, ai? smart ou ai? all para alternar os tiers"
                        };
                        return hints[launcher.currentMode] || "Digite para buscar…";
                    }
                    return "Nenhum resultado para \"" + launcher.searchField.text.substring(0, 30) + "\"";
                }
                font.pixelSize: DesignTokens.fontSizeSM
                font.family: Style.fontUI
                color: launcher.launcherTextSubtle
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        Layout.fillWidth: true
        Layout.preferredHeight: launcher.contextMenuOpen ? Math.min(contextModel.count * 32 + 16, 160) : 0
        radius: launcher.launcherInnerRadius
        color: ColorScheme.withAlpha(Style.glassPopup, 0.92)
        border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.2)
        border.width: 1
        clip: true
        visible: launcher.contextMenuOpen

        Behavior on Layout.preferredHeight {
            enabled: !FeatureFlags.reducedMotion
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Text {
                text: "Ações  (Tab)"
                color: launcher.launcherSectionLabelColor
                font.pixelSize: DesignTokens.fontSizeXS
                font.family: Style.fontUI
            }

            ListView {
                id: contextList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: contextModel
                currentIndex: 0
                spacing: 1
                clip: true
                reuseItems: true

                delegate: Rectangle {
                    width: contextList.width
                    height: 28
                    radius: 6
                    color: ListView.isCurrentItem
                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                        : (ctxMa.containsMouse ? ColorScheme.glassHover : "transparent")
                    Behavior on color {
                        enabled: !FeatureFlags.reducedMotion
                        ColorAnimation { duration: 80 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: model.icon
                            font.family: Style.fontMono
                            font.pixelSize: 11
                            color: ColorScheme.accent
                        }
                        Text {
                            text: model.label
                            font.pixelSize: DesignTokens.fontSizeSM
                            font.family: Style.fontUI
                            color: ColorScheme.text
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: ctxMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: launcher.executeContextAction(index, launcher.appsList.currentIndex)
                    }
                }
            }
        }
    }
}
