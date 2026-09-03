import QtQuick
import QtQuick.Layouts
import "../core"

PopupWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    showScrim: false
    glassRadius: 0
    glassBackground: "transparent"
    slideY: 12
    originY: 0.0
    originX: 1.0

    property real anchorX: -1
    property real popupMargin: DesignTokens.spacingLG
    property bool outsideCloseEnabled: false

    property var contextData: ({})

    readonly property var serviceRows: {
        var s = contextData.services;
        return (s && s.length !== undefined) ? s : [];
    }

    function rowStateColor(row) {
        var state = String(row && row.state ? row.state : "").toLowerCase();
        if (state === "active" || state === "running") return ColorScheme.green;
        if (state === "activating") return ColorScheme.yellow;
        if (state === "") return ColorScheme.yellow;
        return ColorScheme.red;
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        onClicked: (mouse) => {
            var p = mapToItem(popupCard, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > popupCard.width || p.y > popupCard.height) {
                root.isOpen = false;
            }
        }
    }

    Item {
        id: popupCard
        width: 340
        height: contentCol.implicitHeight + 24
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: popupTopMargin
        anchors.rightMargin: root.popupMargin
        z: 1

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: ColorScheme.glassPopup
            border.color: ColorScheme.outlineVariant
            border.width: 1
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            // ── Header: icon + project type + path + branch ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: root.contextData.icon || "\uf120"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    color: ColorScheme.accent
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: (root.contextData.project_type || "Desktop").toUpperCase()
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        color: ColorScheme.text
                    }
                    Text {
                        text: root.contextData.path || "~"
                        color: ColorScheme.subtext0
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                        width: parent.width
                    }
                }

                Row {
                    visible: !!root.contextData.git_branch
                    spacing: 4
                    Text {
                        text: "\ue0a0"
                        color: ColorScheme.green
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                    Text {
                        text: root.contextData.git_branch || ""
                        color: ColorScheme.text
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: ColorScheme.withAlpha(ColorScheme.outlineVariant, 0.4)
            }

            // ── Project notes ──
            Text {
                Layout.fillWidth: true
                visible: !!root.contextData.notes
                text: root.contextData.notes || ""
                color: ColorScheme.subtext0
                font.pixelSize: 10
                font.italic: true
                wrapMode: Text.WordWrap
                leftPadding: 4
            }

            // ── Services list ──
            ListView {
                id: serviceList
                Layout.fillWidth: true
                implicitHeight: contentHeight
                model: root.serviceRows
                clip: true
                spacing: 2

                delegate: Item {
                    width: ListView.view.width
                    height: 36

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        spacing: 8

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: root.rowStateColor(modelData)
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.label || modelData.service || "?"
                            font.bold: false
                            color: ColorScheme.text
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.state || "unknown"
                            color: root.rowStateColor(modelData)
                            font.pixelSize: 10
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: "Nenhum serviço monitorado"
                    color: ColorScheme.subtext1
                    font.italic: true
                    font.pixelSize: 11
                }
            }
        }
    }
}
