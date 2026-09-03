import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../core"
import "../services"

ColumnLayout {
    id: root
    spacing: 8
    
    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.text
    property var customSinks: []
    property var selectSinkById: null

    TimedProcess {
        id: cliSwitcherProc
        timeoutMs: 2000
        onExited: AudioStatusService.refreshCliStatus()
    }

    readonly property var audioSinks: {
        if (customSinks && customSinks.length > 0) return customSinks;
        if (!Pipewire.nodes) return [];
        var allNodes = Pipewire.nodes.values || [];
        var filtered = [];
        for (var i = 0; i < allNodes.length; i++) {
            var s = allNodes[i];
            if (s && s.isSink && s.audio) filtered.push(s);
        }
        return filtered;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            text: "\u{f0553} Dispositivos de Saída"
            color: textColor
            font.bold: true
            font.pixelSize: 13
            font.family: Style.fontUI
            Layout.fillWidth: true
        }
        Text {
            text: root.audioSinks.length + (root.audioSinks.length === 1 ? " dispositivo" : " dispositivos")
            color: ColorScheme.withAlpha(textColor, 0.5)
            font.pixelSize: 10
            font.family: Style.fontUI
        }
    }

    Repeater {
        model: root.audioSinks
        
        delegate: Rectangle {
            id: sinkItem
            Layout.fillWidth: true
            height: 48
            radius: 10
            readonly property bool isDefault: {
                if (!modelData) return false;
                if (modelData.__cli === true) return modelData.default === true;
                if (!Pipewire.defaultAudioSink) return false;
                return Pipewire.defaultAudioSink.id === modelData.id || Pipewire.defaultAudioSink === modelData;
            }
            color: isDefault 
                   ? ColorScheme.withAlpha(accentColor, 0.16) 
                   : (sinkMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.text, 0.08) : ColorScheme.withAlpha(ColorScheme.surface, 0.22))
            
            border.color: isDefault ? ColorScheme.withAlpha(accentColor, 0.6) : ColorScheme.withAlpha(ColorScheme.text, 0.06)
            border.width: isDefault ? 1.5 : 1

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // Device Icon in rounded chip
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: isDefault ? ColorScheme.withAlpha(accentColor, 0.25) : ColorScheme.withAlpha(ColorScheme.text, 0.08)

                    DynamicIcon {
                        anchors.centerIn: parent
                        iconSource: {
                            var desc = String(modelData.description || modelData.name || "").toLowerCase();
                            if (desc.includes("headset") || desc.includes("headphones") || desc.includes("fone"))
                                return "file://" + RuntimePaths.quickshellDir + "/shared/icons/audio-headphones.svg";
                            if (desc.includes("hdmi") || desc.includes("displayport") || desc.includes("tv"))
                                return "file://" + RuntimePaths.quickshellDir + "/shared/icons/video-display.svg";
                            return "file://" + RuntimePaths.quickshellDir + "/shared/icons/audio-output.svg";
                        }
                        iconColor: isDefault ? accentColor : textColor
                        fallbackGlyph: {
                            var desc = String(modelData.description || modelData.name || "").toLowerCase();
                            if (desc.includes("headset") || desc.includes("headphones")) return "\u{f025}";
                            if (desc.includes("hdmi") || desc.includes("displayport")) return "\u{f26c}";
                            return "\u{f028}";
                        }
                        size: 16
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: modelData.description || modelData.name || ("Saída " + modelData.id)
                        color: textColor
                        font.pixelSize: 12
                        font.bold: isDefault
                        font.family: Style.fontUI
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: {
                            var desc = String(modelData.description || modelData.name || "").toLowerCase();
                            if (desc.includes("headset") || desc.includes("headphones")) return "Fone de ouvido";
                            if (desc.includes("hdmi") || desc.includes("displayport")) return "Áudio Digital HDMI";
                            if (desc.includes("usb")) return "Áudio USB";
                            return "Alto-falantes internos";
                        }
                        color: ColorScheme.withAlpha(textColor, 0.55)
                        font.pixelSize: 10
                        font.family: Style.fontUI
                    }
                }

                // Active badge / checkmark
                Rectangle {
                    height: 20
                    width: isDefault ? checkText.implicitWidth + 14 : 20
                    radius: 10
                    color: isDefault ? ColorScheme.withAlpha(accentColor, 0.25) : ColorScheme.withAlpha(ColorScheme.text, 0.06)
                    border.color: isDefault ? ColorScheme.withAlpha(accentColor, 0.4) : "transparent"
                    border.width: 1

                    Text {
                        id: checkText
                        anchors.centerIn: parent
                        text: isDefault ? "✓ Ativo" : ""
                        font.pixelSize: 9
                        font.family: Style.fontUI
                        font.bold: true
                        color: accentColor
                        visible: isDefault
                    }
                }
            }

            MouseArea {
                id: sinkMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData && modelData.id !== undefined) {
                        cliSwitcherProc.exec(["wpctl", "set-default", String(modelData.id)]);
                        if (typeof root.selectSinkById === "function") {
                            root.selectSinkById(modelData.id);
                        }
                    }
                }
            }
        }
    }
}
