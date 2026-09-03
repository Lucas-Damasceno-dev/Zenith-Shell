pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"
import "../../shared"
import "../../services"
import "./PreviewPanelUtils.js" as PreviewPanelUtils

Rectangle {
    id: root

    required property var launcher

    readonly property var resultsModel: launcher.resultsModelObj
    readonly property var appsList: launcher.appsListObj
    readonly property string currentMode: launcher.currentMode
    readonly property bool previewVisible: launcher.previewVisible
    readonly property string previewPanelMode: launcher.previewPanelMode
    readonly property string previewHeroSource: launcher.previewHeroSource
    readonly property string launcherTextMuted: launcher.launcherTextMuted
    readonly property string launcherSectionLabelColor: launcher.launcherSectionLabelColor
    readonly property color launcherCardFill: launcher.launcherCardFill
    readonly property color launcherCardFillStrong: launcher.launcherCardFillStrong
    readonly property color launcherCardBorder: launcher.launcherCardBorder
    readonly property int launcherPanelRadius: launcher.launcherPanelRadius
    readonly property int launcherCardRadius: launcher.launcherCardRadius
    readonly property int launcherInnerRadius: launcher.launcherInnerRadius
    readonly property int launcherPanelPadding: launcher.launcherPanelPadding
    readonly property int launcherSectionGap: launcher.launcherSectionGap
    readonly property int launcherBlockGap: launcher.launcherBlockGap
    readonly property int launcherChipGap: launcher.launcherChipGap
    readonly property var previewInfoRows: launcher.previewInfoRows
    readonly property var previewBluetoothDevices: launcher.previewBluetoothDevices
    readonly property var previewRunningWindows: launcher.previewRunningWindows
    readonly property var previewFileDetails: launcher.previewFileDetails
    readonly property var previewWindowDetails: launcher.previewWindowDetails
    readonly property bool bluetoothPairPromptVisible: launcher.bluetoothPairPromptVisible
    readonly property string bluetoothPairPromptMac: launcher.bluetoothPairPromptMac
    readonly property string bluetoothPairPromptLabel: launcher.bluetoothPairPromptLabel
    property alias previewTitleObj: previewTitle
    property alias previewDescObj: previewDesc
    property alias previewContentObj: previewContent
    property alias previewMetaObj: previewMeta
    property alias previewImageObj: previewImage
    property alias previewTagsFlowObj: previewTagsFlow
    property alias actionFlowObj: actionFlow
    readonly property string aiTier: launcher.aiTier
    readonly property bool aiLoading: launcher.aiLoading
    readonly property string aiPrimaryText: launcher.aiPrimaryText
    readonly property string aiSecondaryText: launcher.aiSecondaryText
    readonly property var aiAllTexts: launcher.aiAllTexts
    readonly property string aiPromptText: launcher.aiPromptText
    readonly property string aiLastErrorText: launcher.aiLastErrorText
    readonly property bool searchLoading: launcher.searchLoading
    readonly property string searchLoadingLabel: launcher.searchLoadingLabel
    readonly property color launcherTextSoft: launcher.launcherTextSoft
    readonly property color launcherTextSubtle: launcher.launcherTextSubtle
    readonly property color launcherTrackFill: launcher.launcherTrackFill
    readonly property var _cachedAudioSinks: launcher._cachedAudioSinks
    readonly property var settingsStore: launcher.settingsStore
    readonly property var previewActionProc: launcher.previewActionProc
    readonly property string launcherSystemTool: launcher.launcherSystemTool
    readonly property bool previewActive: previewVisible || searchLoading

    function closeLauncher() {
        launcher.isOpen = false;
    }

    function getModeInfo(mode) { return launcher.getModeInfo(mode); }
    function resultGlyphIcon(item) { return launcher.resultGlyphIcon(item); }
    function aiRichText(text, placeholder) { return launcher.aiRichText(text, placeholder); }
    function htmlEscape(text) { return launcher.htmlEscape(text); }
    function activeWorkspaceLabel() { return launcher.activeWorkspaceLabel(); }
    function activeWorkspaceId() { return launcher.activeWorkspaceId(); }
    function runningWindowsForApp(appOrId) { return launcher.runningWindowsForApp(appOrId); }
    function resolveAppFromItem(item) { return launcher.resolveAppFromItem(item); }
    function launcherDefaultSink() { return launcher.launcherDefaultSink(); }
    function launcherSinkPercent() { return launcher.launcherSinkPercent(); }
    function launcherSinkMuted() { return launcher.launcherSinkMuted(); }
    function launcherSetSinkRatio(value) { return launcher.launcherSetSinkRatio(value); }
    function launcherMakeSinkDefault(sink) { return launcher.launcherMakeSinkDefault(sink); }
    function launcherAudioSinks() { return launcher.launcherAudioSinks(); }
    function updateFileInfoRows() { return launcher.updateFileInfoRows(); }
    function updateBluetoothInfoRows() { return launcher.updateBluetoothInfoRows(); }
    function updateWifiInfoRows() { return launcher.updateWifiInfoRows(); }
    function updateWindowInfoRows() { return launcher.updateWindowInfoRows(); }
    function refreshBluetoothPreview() { return launcher.refreshBluetoothPreview(); }
    function refreshWifiPreview() { return launcher.refreshWifiPreview(); }
    function refreshWindowMemoryPreview() { return launcher.refreshWindowMemoryPreview(); }
    function refreshLivePreview() { return launcher.refreshLivePreview(); }
    function clearBluetoothPairPrompt() { return launcher.clearBluetoothPairPrompt(); }
    function requestBluetoothPairPrompt(device) { return launcher.requestBluetoothPairPrompt(device); }
    function submitBluetoothPairPrompt(pin) { return launcher.submitBluetoothPairPrompt(pin); }
    function handleBluetoothDeviceAction(device) { return launcher.handleBluetoothDeviceAction(device); }
    function launchItem(index) { return launcher.launchItem(index); }
                Layout.preferredWidth: 352
                Layout.fillHeight: true
                radius: launcherPanelRadius
                visible: previewActive
                color: Style.glassPopup
                border.color: launcherCardBorder
                border.width: 1
                clip: true
                transformOrigin: Item.TopRight
                scale: previewActive ? 1.0 : 0.985
                z: DesignTokens.elevationRaised

                Behavior on scale {
                    enabled: !FeatureFlags.reducedMotion
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: DesignTokens.shadowLauncher.offsetY
                    radius: parent.radius
                    color: Qt.rgba(0, 0, 0, DesignTokens.shadowLauncher.alpha)
                    z: -1
                }

                // Gradiente sutil de fundo para profundidade
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    opacity: 0.72
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: ColorScheme.withAlpha(ColorScheme.accent, 0.10) }
                        GradientStop { position: 0.45; color: ColorScheme.withAlpha(ColorScheme.surfaceHigh, 0.08) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // ── AI Secondary Response Overlay ──
                Rectangle {
                    id: aiSecondaryOverlay
                    anchors.fill: parent
                    radius: parent.radius
                    color: Style.glassPopup
                    visible: currentMode === "ai"
                    z: 10
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: launcherPanelPadding
                        spacing: DesignTokens.spacingMD

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: DesignTokens.spacingMD

                            Text {
                                text: aiTier === "all" ? "\u{f24d}" : "\u{f5dc}"
                                font.family: Style.fontMono
                                font.pixelSize: 14
                                color: ColorScheme.withAlpha(ColorScheme.accent, 0.7)
                            }

                            Text {
                                text: aiTier === "all" ? "GEMINI PRO" : "SEGUNDA OPINIÃO"
                                color: root.launcherSectionLabelColor
                                font.pixelSize: DesignTokens.fontSizeXS
                                font.weight: DesignTokens.fontWeightSemiBold
                                font.family: Style.fontUI
                                font.letterSpacing: DesignTokens.letterSpacingCaps
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: aiLoading && aiSecondaryText === ""
                                width: 8
                                height: 8
                                radius: 4
                                color: ColorScheme.withAlpha(ColorScheme.accent, 0.74)
                                opacity: 0.35

                                SequentialAnimation on opacity {
                                    running: aiLoading && aiSecondaryText === "" && !FeatureFlags.reducedMotion
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1.0; duration: 650; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutQuad }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            visible: launcherErrorText !== ""
                            radius: launcherInnerRadius
                            color: ColorScheme.withAlpha(ColorScheme.red, 0.14)
                            border.color: ColorScheme.withAlpha(ColorScheme.red, 0.28)
                            border.width: 1
                            implicitHeight: aiErrorText.implicitHeight + DesignTokens.spacingMD * 2

                            Text {
                                id: aiErrorText
                                anchors.fill: parent
                                anchors.margins: DesignTokens.spacingMD
                                text: launcherErrorText
                                color: ColorScheme.text
                                font.pixelSize: DesignTokens.fontSizeXS + 1
                                font.family: Style.fontUI
                                wrapMode: Text.Wrap
                            }
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: width
                            contentHeight: aiSecondaryContent.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Text {
                                id: aiSecondaryContent
                                width: parent.width
                                text: {
                                    if (aiLoading && aiSecondaryText === "") return root.aiRichText("", aiTier === "all" ? "Consultando Gemini Pro…" : "Aguardando segunda opinião…");
                                    if (aiSecondaryText === "") return root.aiRichText("", "Aguardando resposta…");
                                    return root.aiRichText(aiSecondaryText, "Sem resposta");
                                }
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.85)
                                font.pixelSize: DesignTokens.fontSizeSM
                                font.family: Style.fontUI
                                lineHeight: Style.lineHeightNormal
                                wrapMode: Text.Wrap
                                textFormat: Text.RichText
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: launcherPanelPadding
                    spacing: launcherSectionGap

                    // ─── Header: App Identity ───
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: DesignTokens.spacingXL + DesignTokens.spacingXS

                        Rectangle {
                            id: previewIconBg
                            width: 72
                            height: 72
                            radius: launcherPanelRadius
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.56)
                            border.color: launcherCardBorder
                            border.width: 1
                            visible: root.visible

                             SmartIcon {
                                 id: previewImage
                                 anchors.fill: parent
                                 anchors.margins: 14
                                 size: 44
                                  function loadIcon(name) {
                                      source = name;
                                      label = previewTitle.text;
                                  }
                                  useThemeProvider: false
                                  fallbackIcon: {
                                      let item = launcher.selectedResultItem ? launcher.selectedResultItem() : null;
                                      return PreviewPanelUtils.fallbackIconForItem(
                                          currentMode,
                                          item,
                                          getModeInfo,
                                          root.resultGlyphIcon
                                      );
                                  }
                                  visible: PreviewPanelUtils.showSmartIcon(previewPanelMode)
                              }

                             // Ultimate Fallback for non-image modes
                             Text {
                                 anchors.centerIn: parent
                                 visible: !previewImage.visible
                                 text: previewImage.fallbackIcon
                                 font.family: Style.fontMono + ", Symbols Nerd Font Mono, monospace"
                                 font.pixelSize: 32
                                 color: ColorScheme.withAlpha(ColorScheme.text, 0.25)
                             }


                            // Reflexo no ícone
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: "white"; opacity: 0.03
                                anchors.margins: 1
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: DesignTokens.spacingXS

                            Text {
                                id: previewTitle
                                text: "Preview"
                                color: ColorScheme.text
                                font.bold: true
                                font.pixelSize: Style.fontSizeHeading
                                font.family: Style.fontUI
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }

                            Text {
                                id: previewDesc
                                text: ""
                                color: root.launcherTextMuted
                                font.pixelSize: DesignTokens.fontSizeSM
                                font.family: Style.fontUI
                                Layout.fillWidth: true; elide: Text.ElideRight; visible: text !== ""
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                visible: launcherErrorText !== ""
                                radius: launcherInnerRadius
                                color: ColorScheme.withAlpha(ColorScheme.red, 0.14)
                                border.color: ColorScheme.withAlpha(ColorScheme.red, 0.28)
                                border.width: 1
                                implicitHeight: errorText.implicitHeight + DesignTokens.spacingMD * 2

                                Text {
                                    id: errorText
                                    anchors.fill: parent
                                    anchors.margins: DesignTokens.spacingMD
                                    text: launcherErrorText
                                    color: ColorScheme.text
                                    font.pixelSize: DesignTokens.fontSizeXS + 1
                                    font.family: Style.fontUI
                                    wrapMode: Text.Wrap
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                visible: searchLoading
                                radius: launcherInnerRadius
                                color: launcherCardFill
                                border.color: launcherCardBorder
                                border.width: 1
                                implicitHeight: loadingRow.implicitHeight + DesignTokens.spacingMD * 2

                                RowLayout {
                                    id: loadingRow
                                    anchors.fill: parent
                                    anchors.margins: DesignTokens.spacingMD
                                    spacing: launcherChipGap

                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: ColorScheme.withAlpha(ColorScheme.accent, 0.74)
                                        opacity: 0.35

                                        SequentialAnimation on opacity {
                                            running: searchLoading && !FeatureFlags.reducedMotion
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 1.0; duration: 650; easing.type: Easing.InOutQuad }
                                            NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutQuad }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: searchLoadingLabel !== ""
                                                ? ("Carregando " + searchLoadingLabel + "…")
                                                : "Carregando resultados…"
                                            color: ColorScheme.text
                                            font.pixelSize: DesignTokens.fontSizeXS + 1
                                            font.family: Style.fontUI
                                            font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: "A busca pesada roda fora da thread de UI para manter a navegação responsiva."
                                            color: root.launcherTextMuted
                                            font.pixelSize: DesignTokens.fontSizeXS
                                            font.family: Style.fontUI
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }

                            Item { Layout.preferredHeight: 4 }

                            Flow {
                                id: previewTagsFlow
                                Layout.fillWidth: true
                                spacing: DesignTokens.spacingSM
                                visible: tagsList.length > 0
                                property var tagsList: []

                                 Repeater {
                                     model: previewTagsFlow.tagsList
                                     Rectangle {
                                         required property var modelData
                                         color: ColorScheme.withAlpha(ColorScheme.accent, 0.14)

                                        radius: launcherInnerRadius
                                        border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.16)
                                        border.width: 1
                                        width: tagText.implicitWidth + 16
                                        height: 24
                                        Text {
                                            id: tagText
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: ColorScheme.accent
                                            font.pixelSize: DesignTokens.fontSizeXS
                                            font.bold: true
                                            font.family: Style.fontUI
                                            font.letterSpacing: DesignTokens.letterSpacingBadge
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ─── Main Scrollable Area ───
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: scrollCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: scrollCol
                            width: parent.width
                            spacing: launcherSectionGap

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 186
                                radius: launcherPanelRadius
                                visible: previewHeroSource !== ""
                                color: launcherCardFillStrong
                                border.color: launcherCardBorder
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: previewHeroSource
                                    sourceSize.width: Math.max(1, parent.width)
                                    sourceSize.height: Math.max(1, parent.height)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 1.0; color: ColorScheme.withAlpha(ColorScheme.background, 0.60) }
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: DesignTokens.spacingLG
                                    text: previewFileDetails.mime || previewDesc.text || previewTitle.text
                                    color: ColorScheme.text
                                    font.pixelSize: DesignTokens.fontSizeSM
                                    font.family: Style.fontUI
                                    elide: Text.ElideRight
                                }
                            }







                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: launcherBlockGap
                                visible: previewContent.text !== ""

                        Text {
                            text: "AÇÕES RÁPIDAS"
                            font.pixelSize: 10; font.weight: Font.Bold; font.family: Style.fontUI
                            font.letterSpacing: 1.2
                            color: root.launcherSectionLabelColor
                        }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: previewContent.implicitHeight + 24
                                    radius: launcherInnerRadius
                                    color: launcherCardFillStrong
                                    border.color: launcherCardBorder
                                    border.width: 1

                                    Text {
                                        id: previewContent
                                        anchors.fill: parent
                                        anchors.margins: DesignTokens.spacingLG
                                        color: ColorScheme.withAlpha(ColorScheme.text, 0.85)
                                        font.pixelSize: DesignTokens.fontSizeSM
                                        font.family: Style.fontUI
                                        lineHeight: Style.lineHeightNormal
                                        wrapMode: Text.Wrap; textFormat: Text.RichText
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: launcherBlockGap
                                visible: previewInfoRows.length > 0

                                Text {
                                    text: "INFORMAÇÕES"
                                    color: root.launcherSectionLabelColor
                                    font.pixelSize: DesignTokens.fontSizeXS
                                    font.weight: DesignTokens.fontWeightSemiBold
                                    font.family: Style.fontUI
                                    font.letterSpacing: DesignTokens.letterSpacingCaps
                                }

                                GridLayout {
                                    id: previewInfoGrid
                                    Layout.fillWidth: true
                                    columns: previewInfoRows.length > 1 && width >= 260 ? 2 : 1
                                    columnSpacing: DesignTokens.spacingMD
                                    rowSpacing: DesignTokens.spacingMD

                                    Repeater {
                                        model: previewInfoRows

                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            implicitHeight: infoCol.implicitHeight + 18
                                            radius: launcherInnerRadius
                                            color: launcherCardFill
                                            border.color: launcherCardBorder
                                            border.width: 1

                                            ColumnLayout {
                                                id: infoCol
                                                anchors.fill: parent
                                                anchors.margins: DesignTokens.spacingLG
                                                spacing: DesignTokens.spacingXS

                                                Text {
                                                    text: modelData.label || "Info"
                                                    color: root.launcherTextSubtle
                                                    font.pixelSize: DesignTokens.fontSizeXS - 1
                                                    font.weight: DesignTokens.fontWeightSemiBold
                                                    font.family: Style.fontUI
                                                    font.letterSpacing: DesignTokens.letterSpacingBadge
                                                }

                                                Text {
                                                    text: modelData.value || "—"
                                                    color: ColorScheme.text
                                                    font.pixelSize: DesignTokens.fontSizeXS + 1
                                                    font.family: modelData.label === "Caminho" || modelData.label === "Exec" || modelData.label === "Endereço"
                                                        ? Style.fontMono
                                                        : Style.fontUI
                                                    wrapMode: Text.WrapAnywhere
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                id: actionsSection
                                Layout.fillWidth: true
                                spacing: launcherBlockGap
                                visible: actionFlow.actionsList.length > 0

                                Text {
                                    text: "AÇÕES RÁPIDAS"
                                    color: root.launcherSectionLabelColor
                                    font.pixelSize: DesignTokens.fontSizeXS
                                    font.weight: DesignTokens.fontWeightSemiBold
                                    font.family: Style.fontUI
                                    font.letterSpacing: DesignTokens.letterSpacingCaps
                                }

                                GridLayout {
                                    id: actionFlow
                                    Layout.fillWidth: true
                                    columns: actionFlow.actionsList.length > 1 && width >= 260 ? 2 : 1
                                    columnSpacing: DesignTokens.spacingMD
                                    rowSpacing: DesignTokens.spacingMD
                                    property var actionsList: []

                                    Repeater {
                                        model: actionFlow.actionsList
                                        Rectangle {
                                            required property var modelData
                                            id: actionBtn
                                            Layout.fillWidth: true
                                            implicitHeight: 46
                                            radius: launcherInnerRadius
                                            color: actionBtnMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.15) : launcherCardFill
                                            border.color: actionBtnMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.3) : launcherCardBorder
                                            border.width: 1

                                            Behavior on color {
                                                enabled: !FeatureFlags.reducedMotion
                                                ColorAnimation { duration: 150 }
                                            }
                                            Behavior on border.color {
                                                enabled: !FeatureFlags.reducedMotion
                                                ColorAnimation { duration: 150 }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: DesignTokens.spacingLG
                                                anchors.rightMargin: DesignTokens.spacingLG
                                                spacing: launcherChipGap

                                                Text {
                                                    text: modelData.icon || "\u{f144}"
                                                    font.family: Style.fontMono
                                                    font.pixelSize: 14
                                                    color: actionBtnMa.containsMouse ? ColorScheme.accent : ColorScheme.text
                                                }
                                                Text {
                                                    text: modelData.name || "Ação"
                                                    color: ColorScheme.text
                                                    font.pixelSize: DesignTokens.fontSizeSM
                                                    font.weight: DesignTokens.fontWeightMedium
                                                    font.family: Style.fontUI
                                                    Layout.fillWidth: true; elide: Text.ElideRight
                                                }
                                            }

                                            MouseArea {
                                                id: actionBtnMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (!modelData.callback) return;
                                                    let shouldClose = modelData.callback();
                                                    if (shouldClose !== false) closeLauncher();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: launcherBlockGap
                                visible: previewPanelMode === "app" && previewRunningWindows.length > 0

                                Text {
                                    text: "JANELAS ABERTAS"
                                    color: root.launcherSectionLabelColor
                                    font.pixelSize: DesignTokens.fontSizeXS
                                    font.weight: DesignTokens.fontWeightSemiBold
                                    font.family: Style.fontUI
                                    font.letterSpacing: DesignTokens.letterSpacingCaps
                                }

                                Repeater {
                                    model: previewRunningWindows.slice(0, 3)

                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 62
                                        radius: launcherInnerRadius
                                        color: launcherCardFill
                                        border.color: launcherCardBorder
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: DesignTokens.spacingLG
                                            spacing: launcherChipGap

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text { text: modelData.title || "Janela"; color: ColorScheme.text; font.pixelSize: DesignTokens.fontSizeXS + 1; font.bold: true; font.family: Style.fontUI; elide: Text.ElideRight; Layout.fillWidth: true }
                                                Text { text: modelData.workspaceLabel || "Workspace ?"; color: root.launcherTextMuted; font.pixelSize: DesignTokens.fontSizeXS; font.family: Style.fontUI; elide: Text.ElideRight; Layout.fillWidth: true }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 78
                                                height: 30
                                                radius: launcherInnerRadius
                                                color: appWindowMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.24) : ColorScheme.withAlpha(ColorScheme.accent, 0.14)
                                                border.color: ColorScheme.withAlpha(ColorScheme.accent, appWindowMa.containsMouse ? 0.30 : 0.18)
                                                border.width: 1
                                                Text { anchors.centerIn: parent; text: "Focar"; color: ColorScheme.accent; font.pixelSize: DesignTokens.fontSizeXS; font.bold: true; font.family: Style.fontUI }
                                                MouseArea {
                                                    id: appWindowMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.ref) modelData.ref.activate();
                                                        closeLauncher();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: launcherBlockGap
                                visible: previewPanelMode === "window"

                                Text {
                                    text: "USO DE RECURSOS"
                                    color: root.launcherSectionLabelColor
                                    font.pixelSize: DesignTokens.fontSizeXS
                                    font.weight: DesignTokens.fontWeightSemiBold
                                    font.family: Style.fontUI
                                    font.letterSpacing: DesignTokens.letterSpacingCaps
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    radius: launcherCardRadius
                                    color: launcherCardFill
                                    border.color: launcherCardBorder
                                    border.width: 1

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: DesignTokens.spacingLG
                                        spacing: launcherChipGap

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "RAM da janela"; color: root.launcherTextSoft; font.pixelSize: DesignTokens.fontSizeXS + 1; font.family: Style.fontUI }
                                            Item { Layout.fillWidth: true }
                                            Text { text: previewWindowDetails.ramText || "carregando…"; color: ColorScheme.text; font.pixelSize: DesignTokens.fontSizeXS + 1; font.bold: true; font.family: Style.fontUI }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 10
                                            radius: 5
                                            color: launcherTrackFill

                                            Rectangle {
                                                width: parent.width * Math.max(0.03, previewWindowDetails.ramRatio)
                                                height: parent.height
                                                radius: parent.radius
                                                color: ColorScheme.accent
                                                Behavior on width {
                                                    enabled: !FeatureFlags.reducedMotion
                                                    NumberAnimation { duration: DesignTokens.durationSlow; easing.type: Easing.OutCubic }
                                                }
                                            }
                                        }

                                        Text {
                                            text: previewWindowDetails.pid > 0 ? ("PID " + previewWindowDetails.pid) : "PID indisponível"
                                            color: root.launcherTextMuted
                                            font.pixelSize: DesignTokens.fontSizeXS
                                            font.family: Style.fontUI
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: launcherBlockGap
                                visible: previewPanelMode === "system_audio"

                                Text {
                                    text: "ÁUDIO"
                                    color: root.launcherSectionLabelColor
                                    font.pixelSize: DesignTokens.fontSizeXS
                                    font.weight: DesignTokens.fontWeightSemiBold
                                    font.family: Style.fontUI
                                    font.letterSpacing: DesignTokens.letterSpacingCaps
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    radius: launcherCardRadius
                                    color: launcherCardFill
                                    border.color: launcherCardBorder
                                    border.width: 1

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: DesignTokens.spacingLG
                                        spacing: launcherBlockGap

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: launcherDefaultSink()
                                                    ? (launcherDefaultSink().description || launcherDefaultSink().name || "Saída padrão")
                                                    : "Sem saída padrão"
                                                color: ColorScheme.text
                                                font.pixelSize: DesignTokens.fontSizeXS + 1
                                                font.bold: true
                                                font.family: Style.fontUI
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: launcherSinkMuted() ? "mudo" : (launcherSinkPercent() + "%")
                                                color: root.launcherTextMuted
                                                font.pixelSize: DesignTokens.fontSizeXS + 1
                                                font.family: Style.fontUI
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 26
                                            radius: launcherInnerRadius
                                            color: launcherTrackFill

                                            Rectangle {
                                                width: parent.width * (launcherSinkPercent() / 150.0)
                                                height: parent.height
                                                radius: parent.radius
                                                color: ColorScheme.accent
                                            }

                                            Slider {
                                                id: audioSlider
                                                anchors.fill: parent
                                                from: 0
                                                to: 150
                                                value: launcherSinkPercent()
                                                opacity: 0
                                                onMoved: root.launcherSetSinkRatio(value / 100.0)
                                            }
                                        }
                                    }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: launcherChipGap
                                    visible: root._cachedAudioSinks.length > 0

                                    Repeater {
                                        model: root._cachedAudioSinks

                                        delegate: Rectangle {
                                            required property var modelData
                                            width: root._cachedAudioSinks.length > 1
                                                ? Math.max((scrollCol.width - launcherChipGap) / 2, sinkLabel.implicitWidth + 32)
                                                : scrollCol.width
                                            height: 36
                                            radius: 18
                                            color: modelData === root.launcherDefaultSink()
                                                ? ColorScheme.withAlpha(ColorScheme.accent, 0.20)
                                                : launcherCardFill
                                            border.color: modelData === root.launcherDefaultSink()
                                                ? ColorScheme.withAlpha(ColorScheme.accent, 0.36)
                                                : launcherCardBorder
                                            border.width: 1

                                            Text {
                                                id: sinkLabel
                                                anchors.centerIn: parent
                                                text: modelData.description || modelData.name || "Saída"
                                                color: modelData === root.launcherDefaultSink() ? ColorScheme.accent : ColorScheme.text
                                                font.pixelSize: DesignTokens.fontSizeXS
                                                font.bold: modelData === root.launcherDefaultSink()
                                                font.family: Style.fontUI
                                                elide: Text.ElideRight
                                                width: parent.width - 20
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.launcherMakeSinkDefault(modelData)
                                            }
                                        }
                                    }
                                }

                                AppVolumeMixer {
                                    Layout.fillWidth: true
                                    visible: previewPanelMode === "system_audio"
                                    settingsStore: root.settingsStore
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: launcherBlockGap
                                visible: previewPanelMode === "system_bluetooth"

                                Text {
                                    text: "DISPOSITIVOS"
                                    color: root.launcherSectionLabelColor
                                    font.pixelSize: DesignTokens.fontSizeXS
                                    font.weight: DesignTokens.fontWeightSemiBold
                                    font.family: Style.fontUI
                                    font.letterSpacing: DesignTokens.letterSpacingCaps
                                }

                                Text {
                                    visible: previewBluetoothDevices.length === 0
                                    text: bluetoothStatusProc.enabled ? "Nenhum dispositivo detectado." : "Bluetooth desligado."
                                    color: root.launcherTextMuted
                                    font.pixelSize: DesignTokens.fontSizeXS + 1
                                    font.family: Style.fontUI
                                }

                                Repeater {
                                    model: previewBluetoothDevices.slice(0, 6)

                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 72
                                        radius: launcherInnerRadius
                                        color: launcherCardFill
                                        border.color: launcherCardBorder
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: DesignTokens.spacingLG
                                            spacing: launcherChipGap

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3
                                        Text { text: modelData.name || modelData.mac || "Dispositivo"; color: ColorScheme.text; font.pixelSize: DesignTokens.fontSizeXS + 1; font.bold: true; font.family: Style.fontUI; elide: Text.ElideRight; Layout.fillWidth: true }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 96
                                                height: 30
                                                radius: launcherInnerRadius
                                                color: btDeviceMa.containsMouse
                                                    ? ColorScheme.withAlpha(modelData.connected ? ColorScheme.red : ColorScheme.accent, 0.24)
                                                    : ColorScheme.withAlpha(modelData.connected ? ColorScheme.red : ColorScheme.accent, 0.14)
                                                border.color: ColorScheme.withAlpha(modelData.connected ? ColorScheme.red : ColorScheme.accent, btDeviceMa.containsMouse ? 0.30 : 0.18)
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.connected ? "Desconectar" : (modelData.paired ? "Conectar" : "Parear")
                                                    color: modelData.connected ? ColorScheme.red : ColorScheme.accent
                                                    font.pixelSize: DesignTokens.fontSizeXS
                                                    font.bold: true
                                                    font.family: Style.fontUI
                                                }
                                                MouseArea {
                                                    id: btDeviceMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        handleBluetoothDeviceAction(modelData);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                BluetoothPairPrompt {
                                    Layout.fillWidth: true
                                    promptVisible: bluetoothPairPromptVisible
                                    deviceLabel: bluetoothPairPromptLabel
                                    onConfirmed: submitBluetoothPairPrompt(value)
                                    onCancelled: clearBluetoothPairPrompt()
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: launcherBlockGap
                                visible: previewPanelMode === "system_wifi"

                                Text {
                                    text: "REDE"
                                    color: root.launcherSectionLabelColor
                                    font.pixelSize: DesignTokens.fontSizeXS
                                    font.weight: DesignTokens.fontWeightSemiBold
                                    font.family: Style.fontUI
                                    font.letterSpacing: DesignTokens.letterSpacingCaps
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    radius: launcherCardRadius
                                    color: launcherCardFill
                                    border.color: launcherCardBorder
                                    border.width: 1

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: DesignTokens.spacingLG
                                        spacing: launcherChipGap

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: wifiStatusProc.enabled ? "Wi-Fi ligado" : "Wi-Fi desligado"; color: ColorScheme.text; font.pixelSize: DesignTokens.fontSizeSM; font.bold: true; font.family: Style.fontUI }
                                            Item { Layout.fillWidth: true }
                                            Text { text: wifiStatusProc.signal > 0 ? (wifiStatusProc.signal + "%") : "—"; color: root.launcherTextMuted; font.pixelSize: DesignTokens.fontSizeXS + 1; font.family: Style.fontUI }
                                        }

                                        Text {
                                            text: wifiStatusProc.ssid !== "" ? ("Conectado em " + wifiStatusProc.ssid) : "Nenhuma rede ativa"
                                            color: root.launcherTextSoft
                                            font.pixelSize: DesignTokens.fontSizeXS + 1
                                            font.family: Style.fontUI
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: launcherBlockGap
                                visible: previewPanelMode === "system_power"

                                Text {
                                    text: "RESUMO DA SESSÃO"
                                    color: root.launcherSectionLabelColor
                                    font.pixelSize: DesignTokens.fontSizeXS
                                    font.weight: DesignTokens.fontWeightSemiBold
                                    font.family: Style.fontUI
                                    font.letterSpacing: DesignTokens.letterSpacingCaps
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    radius: launcherCardRadius
                                    color: launcherCardFill
                                    border.color: root.launcherCardBorder
                                    border.width: 1

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: DesignTokens.spacingLG
                                        spacing: DesignTokens.spacingSM

                                        Text {
                                            text: Qt.formatDateTime(new Date(), "HH:mm")
                                            color: ColorScheme.accent
                                            font.pixelSize: DesignTokens.fontSizeHero - 2
                                            font.bold: true
                                            font.family: Style.fontUI
                                        }
                                        Text {
                                            text: root.activeWorkspaceLabel() + (BatteryStatsService.hasBattery ? (" • bateria " + BatteryStatsService.batteryPercent + "%") : "")
                                            color: root.launcherTextSoft
                                            font.pixelSize: DesignTokens.fontSizeXS + 1
                                            font.family: Style.fontUI
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: root.launcherBlockGap
                                visible: root.previewPanelMode === "system_brightness"

                                Text {
                                    text: "BRILHO"
                                    color: root.launcherSectionLabelColor
                                    font.pixelSize: DesignTokens.fontSizeXS
                                    font.weight: DesignTokens.fontWeightSemiBold
                                    font.family: Style.fontUI
                                    font.letterSpacing: DesignTokens.letterSpacingCaps
                                }

                                BrightnessSlider {
                                    Layout.fillWidth: true
                                    visible: root.previewPanelMode === "system_brightness"
                                }
                            }
                        }
                    }

                    // ─── Footer: Metadata ───
                    Text {
                        id: previewMeta
                        Layout.fillWidth: true
                        color: root.launcherTextSubtle
                        font.pixelSize: DesignTokens.fontSizeXS + 1
                        font.family: Style.fontMono
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTrailing
                        spacing: DesignTokens.spacingXS
                        visible: root.searchLoading

                        Rectangle {
                            width: 7
                            height: 7
                            radius: 3.5
                            color: ColorScheme.withAlpha(ColorScheme.accent, 0.74)
                            opacity: 0.35

                            SequentialAnimation on opacity {
                                running: root.searchLoading && !FeatureFlags.reducedMotion
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.0; duration: 650; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            text: root.searchLoadingLabel !== "" ? root.searchLoadingLabel : "carregando"
                            color: root.launcherTextSubtle
                            font.pixelSize: DesignTokens.fontSizeXS
                            font.family: Style.fontUI
                        }
                    }
                }
}
