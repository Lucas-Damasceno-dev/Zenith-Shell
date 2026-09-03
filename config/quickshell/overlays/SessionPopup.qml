import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../core"
import "../core/ConfirmationGate.js" as ConfirmationGate
import "../services"

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
    property string confirmingAction: ""

    function notifyFeedback(label) {
        feedbackProc.exec([
            "notify-send",
            "-a", "Session Gate",
            "Sessão",
            "Executando: " + label
        ]);
    }

    function requestConfirmation(actionKey) {
        var result = ConfirmationGate.nextState(root.confirmingAction, actionKey);
        root.confirmingAction = result.confirmingAction;
        if (!result.confirmed) {
            confirmTimer.restart();
            return false;
        }
        confirmTimer.stop();
        return true;
    }

    function executeAction(modelData) {
        var dangerous = modelData.key === "shutdown" || modelData.key === "reboot" || modelData.key === "hibernate" || modelData.key === "logout";
        if (dangerous && !root.requestConfirmation(modelData.key))
            return;

        root.notifyFeedback(modelData.label);
        sessionProc.exec(modelData.cmd);
        root.isOpen = false;
    }

    function triggerByKey(hotkeyChar) {
        var k = String(hotkeyChar || "").toLowerCase();
        for (var i = 0; i < root.actions.length; i++) {
            if (root.actions[i].hotkey.toLowerCase() === k) {
                executeAction(root.actions[i]);
                return true;
            }
        }
        return false;
    }

    onIsOpenChanged: {
        if (!isOpen) {
            confirmingAction = "";
        } else {
            BatteryStatsService.refreshUptime();
            keyReceiver.forceActiveFocus();
        }
    }

    function getActionColor(key) {
        if (key === "shutdown") return ColorScheme.red;
        if (key === "reboot") return ColorScheme.blue;
        if (key === "suspend") return ColorScheme.mauve;
        if (key === "hibernate") return ColorScheme.teal;
        if (key === "logout") return ColorScheme.yellow;
        if (key === "lock") return ColorScheme.green;
        return ColorScheme.text;
    }

    readonly property var actions: [
        { key: "shutdown", icon: "\u{23fb}", label: "Desligar", hotkey: "S", cmd: ["systemctl", "poweroff"] },
        { key: "reboot",   icon: "\u{f0e2}", label: "Reiniciar", hotkey: "R", cmd: ["systemctl", "reboot"] },
        { key: "suspend",  icon: "\u{f186}", label: "Suspender", hotkey: "U", cmd: ["bash", "-c", "loginctl lock-session; systemctl suspend"] },
        { key: "hibernate", icon: "\u{f2dc}", label: "Hibernar", hotkey: "H", cmd: ["bash", "-c", "loginctl lock-session; systemctl hibernate"] },
        { key: "logout",   icon: "\u{f2f5}", label: "Sair",      hotkey: "E", cmd: ["bash", "-c", "bash " + RuntimePaths.hyprScriptsDir + "/session_save.sh 2>/dev/null || true; hyprctl dispatch exit"] },
        { key: "lock",     icon: "\u{f023}", label: "Bloquear",  hotkey: "L", cmd: ["hyprlock"] }
    ]

    TimedProcess { id: sessionProc; timeoutMs: 0 }
    TimedProcess { id: feedbackProc }

    Timer {
        id: confirmTimer
        interval: 3000; repeat: false
        onTriggered: root.confirmingAction = ""
    }

    Item {
        id: keyReceiver
        anchors.fill: parent
        focus: root.isOpen
        Keys.onEscapePressed: { root.isOpen = false; }
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.isOpen = false;
                event.accepted = true;
            } else if (event.text && event.text.length > 0) {
                if (root.triggerByKey(event.text)) {
                    event.accepted = true;
                }
            }
        }
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
        width: 360
        height: 380
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: popupTopMargin
        anchors.rightMargin: root.popupMargin
        z: 1

        Rectangle {
            id: popupBg
            anchors.fill: parent
            radius: 16
            color: ColorScheme.glassPopup
            border.color: ColorScheme.outlineVariant
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // ── Header: Title + Diagnostics Pills ────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "\u{23fb}  Sessão"
                    color: ColorScheme.text
                    font.pixelSize: 16; font.weight: Font.DemiBold; font.family: "Inter"
                    font.letterSpacing: DesignTokens.letterSpacingHeading
                }

                Item { Layout.fillWidth: true }

                // Uptime Pill
                Rectangle {
                    height: 22
                    implicitWidth: uptimeRow.implicitWidth + 12
                    radius: 11
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.06)
                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                    border.width: 1

                    RowLayout {
                        id: uptimeRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "\u{f017}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: ColorScheme.accent
                        }
                        Text {
                            text: BatteryStatsService.systemUptime !== "N/A" ? BatteryStatsService.systemUptime : "Ativo"
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.8)
                            font.pixelSize: 10
                            font.family: "Inter"
                            font.weight: Font.Medium
                        }
                    }
                }

                // Power/Battery Pill
                Rectangle {
                    height: 22
                    implicitWidth: powerRow.implicitWidth + 12
                    radius: 11
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.06)
                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                    border.width: 1

                    RowLayout {
                        id: powerRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: BatteryStatsService.hasBattery ? (BatteryStatsService.battery && BatteryStatsService.battery.state === 2 ? "\u{f0e7}" : "\u{f240}") : "\u{f1e6}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: BatteryStatsService.hasBattery && BatteryStatsService.batteryPercent <= 20 ? ColorScheme.red : ColorScheme.teal
                        }
                        Text {
                            text: BatteryStatsService.hasBattery ? (BatteryStatsService.batteryPercent + "%") : "AC"
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.8)
                            font.pixelSize: 10
                            font.family: "Inter"
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.06) }

            // ── Grid of 6 Actions ────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 10
                columnSpacing: 10

                Repeater {
                    model: root.actions
                    delegate: Rectangle {
                        property color dynamicColor: root.getActionColor(modelData.key)
                        property bool isConfirming: root.confirmingAction === modelData.key
                        Layout.fillWidth: true
                        height: 84
                        radius: 14
                        color: actionMa.containsMouse || isConfirming
                            ? ColorScheme.withAlpha(dynamicColor, isConfirming ? 0.25 : 0.16)
                            : ColorScheme.withAlpha(ColorScheme.text, 0.04)
                        border.color: isConfirming ? dynamicColor : (actionMa.containsMouse ? ColorScheme.withAlpha(dynamicColor, 0.5) : "transparent")
                        border.width: isConfirming ? 2 : 1

                        Behavior on color { ColorAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 130 } }

                        scale: actionMa.containsMouse ? 1.05 : 1.0
                        Behavior on scale { SpringAnimation { spring: 5; damping: 0.5; epsilon: 0.02 } }

                        // Hotkey indicator badge in top right
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: 16; height: 16; radius: 4
                            color: isConfirming ? dynamicColor : ColorScheme.withAlpha(ColorScheme.text, actionMa.containsMouse ? 0.15 : 0.07)
                            Text {
                                anchors.centerIn: parent
                                text: modelData.hotkey
                                font.pixelSize: 9
                                font.bold: true
                                font.family: "Inter"
                                color: isConfirming ? "#ffffff" : ColorScheme.withAlpha(ColorScheme.text, actionMa.containsMouse ? 0.9 : 0.45)
                            }
                        }

                        // Subtle glow behind icon on hover
                        Rectangle {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -6
                            width: 36; height: 36; radius: 18
                            color: actionMa.containsMouse || isConfirming
                                ? ColorScheme.withAlpha(dynamicColor, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: modelData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 24
                                color: isConfirming
                                    ? dynamicColor
                                    : (actionMa.containsMouse ? dynamicColor : ColorScheme.withAlpha(ColorScheme.text, 0.75))
                                Layout.alignment: Qt.AlignHCenter
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Text {
                                text: isConfirming ? "Confirmar?" : modelData.label
                                color: isConfirming ? dynamicColor : ColorScheme.text
                                font.pixelSize: 10; font.weight: Font.Bold; font.family: "Inter"
                                font.letterSpacing: DesignTokens.letterSpacingLabel
                                Layout.alignment: Qt.AlignHCenter
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                        }

                        MouseArea {
                            id: actionMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.executeAction(modelData)
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.06) }

            // ── Footer: Hotkeys help ─────────────────────────────────
            Text {
                text: root.confirmingAction !== "" ? "Clique novamente para confirmar (3s)" : "Atalhos: S · R · U · H · E · L  |  ESC fechar"
                color: root.confirmingAction !== "" ? ColorScheme.peach : ColorScheme.withAlpha(ColorScheme.text, 0.50)
                font.pixelSize: 10
                font.family: "Inter"
                font.weight: root.confirmingAction !== "" ? Font.Bold : Font.Normal
                Layout.alignment: Qt.AlignHCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }
}
