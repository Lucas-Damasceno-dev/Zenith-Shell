pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../shared"
import "../../core/TrayIconUtils.js" as TrayIconUtils

Rectangle {
    id: delegate

    required property var launcher
    required property int index
    required property var model

    readonly property var launcherObj: launcher && typeof launcher === "object" ? launcher : null
    readonly property var appsList: launcherObj && launcherObj.appsListObj ? launcherObj.appsListObj : null
    readonly property int rowIndex: index
    readonly property var row: model && typeof model === "object" ? model : ({})
    readonly property bool searchHasText: launcherObj ? launcherObj.searchHasText === true : false
    readonly property bool highlighted: ListView.isCurrentItem
    readonly property bool hovered: rowMouse.containsMouse

    readonly property string displayName: String(row.name || row.title || row.result || row.appId || row.type || "")
    readonly property string displayDescription: String(row.description || row.subtitle || row.extra || row.path || row.term || "")
    readonly property string displayIcon: String(row.iconSource || row.icon || "")
    readonly property string displayType: String(row.type || "")
    readonly property string displayValue: String(row.result || "")
    readonly property bool displayFavorite: row.favorite === true
    readonly property int displayScore: Number(row.score || 0)
    readonly property string displayAppId: String(row.appId || "")

    readonly property string resolvedIconSource: displayIcon

    function glyphItem() {
            return {
            type: displayType,
            result: displayValue,
            iconSource: displayIcon,
            icon: displayIcon,
            name: displayName,
            title: displayName,
            description: displayDescription,
            appId: displayAppId,
            score: displayScore,
            favorite: displayFavorite,
            extra: String(row.extra || ""),
            path: String(row.path || ""),
            term: String(row.term || "")
        };
    }

    function resultGlyphIcon(item) {
        if (launcherObj && launcherObj.resultGlyphIcon)
            return launcherObj.resultGlyphIcon(item);
        return String(item && item.icon || item && item.iconSource || "");
    }

    function updatePreview(itemIndex) {
        if (launcherObj && launcherObj.updatePreview)
            launcherObj.updatePreview(itemIndex);
    }

    function launchItem(itemIndex) {
        if (launcherObj && launcherObj.launchItem)
            launcherObj.launchItem(itemIndex);
    }

    function openContextMenu(itemIndex) {
        if (launcherObj && launcherObj.openContextMenu)
            launcherObj.openContextMenu(itemIndex);
    }

    width: appsList ? appsList.width : 0
    height: 46
    radius: DesignTokens.radiusSM + 2
    color: highlighted
        ? ColorScheme.stateSelected
        : (hovered ? ColorScheme.stateHover : "transparent")
    border.width: highlighted ? 1 : 0
    border.color: highlighted
        ? ColorScheme.withAlpha(ColorScheme.accent, 0.22)
        : "transparent"
    clip: true

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 10
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: DesignTokens.spacingLG

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: DesignTokens.radiusSM + 2
            color: delegate.highlighted
                ? ColorScheme.stateSelected
                : (delegate.hovered ? ColorScheme.stateHover : ColorScheme.withAlpha(ColorScheme.surface, 0.5))
            border.width: delegate.highlighted ? 1 : 0
            border.color: delegate.highlighted
                ? ColorScheme.withAlpha(ColorScheme.accent, 0.3)
                : "transparent"

            Text {
                anchors.centerIn: parent
                text: displayType === "emoji" ? displayValue : ""
                font.pixelSize: DesignTokens.fontSizeXL
                visible: displayType === "emoji"
            }

            SmartIcon {
                id: delegateIcon
                anchors.centerIn: parent
                size: Style.iconSizeLG
                source: resolvedIconSource
                label: displayName
                color: ColorScheme.text
                colorOverlay: displayType !== "app"
                fallbackIcon: displayType === "app"
                    ? TrayIconUtils.fallbackGlyph(delegate.glyphItem())
                    : delegate.resultGlyphIcon(delegate.glyphItem())
                visible: displayType !== "emoji"
            }
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            Text {
                text: displayName
                color: ColorScheme.text
                font.weight: DesignTokens.fontWeightSemiBold
                font.pixelSize: DesignTokens.fontSizeSM + 1
                font.family: Style.fontUI
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                text: displayDescription
                color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                font.pixelSize: DesignTokens.fontSizeXS + 1
                font.family: Style.fontUI
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: displayDescription !== ""
            }
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: badgesRow.implicitWidth
            Layout.preferredHeight: badgesRow.implicitHeight
            visible: displayType === "app" && (displayFavorite || searchHasText)

            Row {
                id: badgesRow
                spacing: 4

                Rectangle {
                    visible: displayFavorite
                    width: 18
                    height: 16
                    radius: DesignTokens.radiusSM
                    color: ColorScheme.withAlpha(ColorScheme.yellow, 0.12)
                    border.color: ColorScheme.withAlpha(ColorScheme.yellow, 0.28)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f005}"
                        font.family: Style.fontMono
                        font.pixelSize: 10
                        color: ColorScheme.yellow
                    }
                }

                Rectangle {
                    visible: searchHasText
                    width: 30
                    height: 16
                    radius: DesignTokens.radiusSM
                    color: ColorScheme.withAlpha(ColorScheme.accent, 0.1)

                    Text {
                        anchors.centerIn: parent
                        text: displayScore > 0 ? Math.round(displayScore) : ""
                        color: ColorScheme.withAlpha(ColorScheme.accent, 0.5)
                        font.pixelSize: DesignTokens.fontSizeXS - 1
                        font.family: Style.fontUI
                    }
                }
            }
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                openContextMenu(rowIndex);
                return;
            }

            if (displayType.indexOf("system_") === 0) {
                updatePreview(rowIndex);
                return;
            }

            launchItem(rowIndex);
        }
    }
}
