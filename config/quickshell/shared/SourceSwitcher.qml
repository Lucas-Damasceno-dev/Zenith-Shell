import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../core"
import "../services"
import "../overlays/AudioPopupUtils.js" as AudioPopupUtils

ColumnLayout {
    id: root
    spacing: 8

    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.text
    property var customSources: []
    property var selectSourceById: null

    TimedProcess {
        id: cliSwitcherProc
        timeoutMs: 2000
        onExited: AudioStatusService.refreshCliStatus()
    }

    readonly property var audioSources: {
        if (customSources && customSources.length > 0) return customSources;
        if (!Pipewire.nodes) return [];
        var allNodes = Pipewire.nodes.values || [];
        var filtered = [];
        for (var i = 0; i < allNodes.length; i++) {
            var s = allNodes[i];
            if (s && !s.isSink && !s.isStream && s.audio && !AudioPopupUtils.isMonitorSource(s))
                filtered.push(s);
        }
        return filtered;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            text: "\u{f0552} Dispositivos de Entrada"
            color: textColor
            font.bold: true
            font.pixelSize: 13
            font.family: Style.fontUI
            Layout.fillWidth: true
        }
        Text {
            text: root.audioSources.length + (root.audioSources.length === 1 ? " microfone" : " microfones")
            color: ColorScheme.withAlpha(textColor, 0.5)
            font.pixelSize: 10
            font.family: Style.fontUI
        }
    }

    Repeater {
        model: root.audioSources

        delegate: Rectangle {
            id: sourceItem
            Layout.fillWidth: true
            height: 48
            radius: 10
            readonly property bool isDefault: {
                if (!modelData) return false;
                if (modelData.__cli === true) return modelData.default === true;
                if (!Pipewire.defaultAudioSource) return false;
                return Pipewire.defaultAudioSource.id === modelData.id || Pipewire.defaultAudioSource === modelData;
            }
            color: isDefault
                   ? ColorScheme.withAlpha(accentColor, 0.16)
                   : (sourceMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.text, 0.08) : ColorScheme.withAlpha(ColorScheme.surface, 0.22))

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
                            if (desc.includes("headset") || desc.includes("headphones") || desc.includes("airpods") || desc.includes("buds") || desc.includes("handsfree"))
                                return "file://" + RuntimePaths.quickshellDir + "/shared/icons/audio-headphones.svg";
                            return "file://" + RuntimePaths.quickshellDir + "/shared/icons/audio-input.svg";
                        }
                        iconColor: isDefault ? accentColor : textColor
                        fallbackGlyph: {
                            var desc = String(modelData.description || modelData.name || "").toLowerCase();
                            if (desc.includes("cam") || desc.includes("c920") || desc.includes("video")) return "\u{f03d}";
                            if (desc.includes("headset") || desc.includes("headphones")) return "\u{f025}";
                            return "\u{f130}";
                        }
                        size: 16
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: modelData.description || modelData.name || ("Entrada " + modelData.id)
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
                            if (desc.includes("headset") || desc.includes("headphones")) return "Microfone do Headset";
                            if (desc.includes("cam") || desc.includes("c920")) return "Microfone da Webcam";
                            if (desc.includes("usb")) return "Microfone USB";
                            return "Microfone integrado";
                        }
                        color: ColorScheme.withAlpha(textColor, 0.55)
                        font.pixelSize: 10
                        font.family: Style.fontUI
                    }
                }

                // Active badge / checkmark
                Rectangle {
                    height: 20
                    width: isDefault ? checkSourceText.implicitWidth + 14 : 20
                    radius: 10
                    color: isDefault ? ColorScheme.withAlpha(accentColor, 0.25) : ColorScheme.withAlpha(ColorScheme.text, 0.06)
                    border.color: isDefault ? ColorScheme.withAlpha(accentColor, 0.4) : "transparent"
                    border.width: 1

                    Text {
                        id: checkSourceText
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
                id: sourceMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData && modelData.id !== undefined) {
                        cliSwitcherProc.exec(["wpctl", "set-default", String(modelData.id)]);
                        if (typeof root.selectSourceById === "function") {
                            root.selectSourceById(modelData.id);
                        }
                    }
                }
            }
        }
    }
}
