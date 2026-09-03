import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "../core"
import "../services"

ColumnLayout {
    id: root
    spacing: 10
    
    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.text
    readonly property string scriptsDir: RuntimePaths.quickshellScriptsDir
    
    Text {
        text: "\u{f0ea} Clipboard History"
        color: textColor
        font.bold: true
        font.pixelSize: 14
    }

    ListModel { id: clipModel }

    TimedProcess {
        id: clipLoader
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onRead: {
                let lines = data.split('\n').slice(0, 10); // Limit to top 10
                clipModel.clear();
                lines.forEach(line => {
                    let parts = line.split('\t');
                    if (parts.length > 1) {
                        let isImg = parts[1].includes("[[ binary data"); 
                        let mimeMatch = parts[1].match(/image\/[a-zA-Z0-9.+-]+/);
                        clipModel.append({ 
                            clipId: parts[0], 
                            content: isImg ? ("[Imagem] " + (mimeMatch ? mimeMatch[0] : "binary")) : parts[1],
                            isImage: isImg 
                        });
                    }
                });
            }
        }
    }

    property bool pollActive: visible

    Timer {
        interval: FeatureFlags.lowPowerUiMode ? 10000 : 5000
        running: root.pollActive
        repeat: true
        onTriggered: clipLoader.exec(["cliphist", "list"])
    }

    Component.onCompleted: clipLoader.exec(["cliphist", "list"])

    TimedProcess { id: clipPaster }

    GridView {
        id: grid
        Layout.fillWidth: true
        Layout.preferredHeight: 180
        cellWidth: width / 2
        cellHeight: 60
        model: clipModel
        interactive: false
        clip: true

        delegate: Rectangle {
            width: grid.cellWidth - 5
            height: grid.cellHeight - 5
            color: ColorScheme.glassHover
            radius: 8
            border.color: ma.containsMouse ? accentColor : "transparent"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                DynamicIcon {
                    iconSource: model.isImage ? "image-x-generic" : "text-x-generic"
                    iconColor: accentColor
                    size: 16
                }

                Text {
                    text: model.content
                    color: textColor
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    clipPaster.exec(["bash", RuntimePaths.scriptFile("launcher_cliphist_copy.sh"), model.clipId]);
                }
            }
        }
    }
}
