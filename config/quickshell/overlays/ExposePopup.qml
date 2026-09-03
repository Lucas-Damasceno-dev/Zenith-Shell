import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import "../core"
import "../shared"

PopupWindow {
    id: root

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    showScrim: true
    scrimOpacity: 0.70
    glassRadius: 0
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0
    layerNamespace: "quickshell-expose"

    property string searchText: ""
    property int _tick: 0

    function normalizeAddress(value) {
        var text = String(value || "").trim();
        if (text === "") return "";
        if (text.indexOf("0x") === 0 || text.indexOf("0X") === 0) return text;
        if (/^[0-9a-fA-F]+$/.test(text)) return "0x" + text;
        return "";
    }

    function focusWindow(windowData) {
        if (!windowData) return;
        Hyprland.dispatch("workspace " + windowData.workspaceId);
        var addr = normalizeAddress(windowData.address);
        if (addr !== "")
            Hyprland.dispatch("focuswindow address:" + addr);
        root.isOpen = false;
    }

    readonly property var exposeWindows: {
        if (!root.isOpen)
            return [];
        var _t = root._tick;
        var vals = Hyprland.toplevels && Hyprland.toplevels.values ? Hyprland.toplevels.values : [];
        var filter = String(root.searchText || "").trim().toLowerCase();
        var out = [];
        for (var i = 0; i < vals.length; i++) {
            var tl = vals[i];
            if (!tl) continue;

            var ipc = tl.lastIpcObject || {};
            var wsObj = tl.workspace ? tl.workspace : (ipc.workspace ? ipc.workspace : null);
            var wsId = wsObj && wsObj.id !== undefined ? Number(wsObj.id) : 0;
            if (!isFinite(wsId) || wsId <= 0)
                continue;

            var title = String(tl.title || ipc.title || "");
            var className = String(ipc["class"] || tl.appId || "");
            var address = normalizeAddress(tl.address || ipc.address || "");
            if (address === "")
                continue;

            if (filter !== "") {
                var titleLower = title.toLowerCase();
                var classLower = className.toLowerCase();
                if (titleLower.indexOf(filter) < 0 && classLower.indexOf(filter) < 0)
                    continue;
            }

            out.push({
                address: address,
                title: title !== "" ? title : className,
                className: className,
                workspaceId: wsId
            });
        }
        return out;
    }

    onIsOpenChanged: {
        if (!isOpen)
            return;
        Hyprland.refreshToplevels();
        root._tick++;
        root.requestActivate();
        keyGrab.forceActiveFocus();
    }

    Connections {
        target: Hyprland
        enabled: root.isOpen
        function onRawEvent(event) {
            var name = event.name;
            if (name === "openwindow" || name === "closewindow" || name === "movewindow" || name === "activewindow")
                root._tick++;
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        onClicked: root.isOpen = false
    }

    Item {
        id: keyGrab
        anchors.fill: parent
        focus: root.isOpen

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.isOpen = false;
                event.accepted = true;
                return;
            }
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.exposeWindows.length > 0) {
                root.focusWindow(root.exposeWindows[0]);
                event.accepted = true;
            }
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.92, 1280)
        height: Math.min(parent.height * 0.88, 860)
        radius: DesignTokens.radiusXL
        color: ColorScheme.withAlpha(ColorScheme.surface, 0.74)
        border.color: ColorScheme.glassBorder
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true; }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: DesignTokens.spacingXL
            spacing: DesignTokens.spacingLG

            Text {
                Layout.fillWidth: true
                text: "Expose"
                color: ColorScheme.text
                font.pixelSize: 22
                font.family: Style.fontUI
                font.weight: Font.DemiBold
            }

            TextField {
                id: searchField
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                placeholderText: "Filtrar por titulo ou classe..."
                text: root.searchText
                onTextChanged: root.searchText = text
                background: Rectangle {
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.88)
                    border.width: 1
                    border.color: searchField.activeFocus ? ColorScheme.accent : ColorScheme.glassBorder
                }
                Component.onCompleted: forceActiveFocus()
            }

            Text {
                Layout.fillWidth: true
                text: root.exposeWindows.length + " janelas"
                color: ColorScheme.withAlpha(ColorScheme.text, 0.62)
                font.pixelSize: 12
                font.family: Style.fontUI
            }

            GridView {
                id: windowGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 230
                cellHeight: 148
                model: root.exposeWindows
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index

                    width: windowGrid.cellWidth - DesignTokens.spacingMD
                    height: windowGrid.cellHeight - DesignTokens.spacingMD
                    radius: DesignTokens.radiusLG
                    color: cardMouse.containsMouse
                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.18)
                        : ColorScheme.withAlpha(ColorScheme.surface, 0.52)
                    border.width: 1
                    border.color: cardMouse.containsMouse
                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.62)
                        : ColorScheme.withAlpha(ColorScheme.text, 0.10)
                    scale: cardMouse.containsMouse ? 1.02 : 1.0

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 120 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: DesignTokens.spacingLG
                        spacing: DesignTokens.spacingSM

                        SmartIcon {
                            Layout.alignment: Qt.AlignHCenter
                            source: modelData.className !== "" ? ("image://icon/" + modelData.className.toLowerCase()) : ""
                            label: modelData.className
                            size: 54
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.title || modelData.className || "Janela"
                            color: ColorScheme.text
                            font.pixelSize: 12
                            font.family: Style.fontUI
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "WS " + modelData.workspaceId + (modelData.className ? " - " + modelData.className : "")
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.62)
                            font.pixelSize: 10
                            font.family: Style.fontUI
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focusWindow(modelData)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: root.exposeWindows.length === 0
                text: "Nenhuma janela encontrada"
                color: ColorScheme.withAlpha(ColorScheme.text, 0.50)
                font.pixelSize: 12
                font.family: Style.fontUI
            }
        }
    }
}
