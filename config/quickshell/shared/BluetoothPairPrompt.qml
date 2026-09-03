pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property bool promptVisible: false
    property string deviceLabel: ""
    property string helperText: "Digite o PIN ou a senha exibida no dispositivo. Deixe em branco se não houver código."
    property string inputValue: ""

    signal confirmed(string value)
    signal cancelled()

    visible: promptVisible
    Layout.fillWidth: true
    Layout.preferredHeight: visible ? implicitHeight : 0
    implicitHeight: promptCol.implicitHeight + 16
    radius: 10
    color: ColorScheme.withAlpha(ColorScheme.surface, 0.26)
    border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.22)
    border.width: 1
    clip: true

    function focusInput() {
        Qt.callLater(function() {
            if (promptField.visible && root.visible) {
                promptField.forceActiveFocus();
                promptField.selectAll();
            }
        });
    }

    function resetInput() {
        inputValue = "";
    }

    onVisibleChanged: {
        if (visible) {
            resetInput();
            focusInput();
        } else {
            resetInput();
        }
    }

    ColumnLayout {
        id: promptCol
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        Text {
            text: root.deviceLabel !== "" ? ("Parear: " + root.deviceLabel) : "Parear dispositivo"
            color: ColorScheme.text
            font.pixelSize: 10
            font.bold: true
            font.family: "Inter"
        }

        Text {
            text: root.helperText
            color: ColorScheme.withAlpha(ColorScheme.text, 0.6)
            font.pixelSize: 10
            font.family: "Inter"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        TextField {
            id: promptField
            Layout.fillWidth: true
            placeholderText: "PIN ou senha (opcional)"
            placeholderTextColor: ColorScheme.withAlpha(ColorScheme.text, 0.35)
            text: root.inputValue
            echoMode: TextInput.Password
            font.pixelSize: 10
            font.family: "Inter"
            leftPadding: 10
            rightPadding: 10
            topPadding: 6
            bottomPadding: 6
            background: Rectangle {
                radius: 8
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.20)
                border.width: 1
                border.color: promptField.activeFocus
                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.35)
                    : ColorScheme.withAlpha(ColorScheme.text, 0.10)
            }
            onTextChanged: root.inputValue = text
            onAccepted: root.confirmed(root.inputValue)
            Keys.onEscapePressed: root.cancelled()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                height: 24
                radius: 12
                color: ColorScheme.withAlpha(ColorScheme.accent, 0.20)
                Text {
                    anchors.centerIn: parent
                    text: "Parear"
                    color: ColorScheme.accent
                    font.pixelSize: 9
                    font.bold: true
                    font.family: "Inter"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.confirmed(root.inputValue)
                }
            }

            Rectangle {
                width: 74
                height: 24
                radius: 12
                color: ColorScheme.withAlpha(ColorScheme.red, 0.18)
                Text {
                    anchors.centerIn: parent
                    text: "Cancelar"
                    color: ColorScheme.red
                    font.pixelSize: 9
                    font.family: "Inter"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelled()
                }
            }
        }
    }
}
