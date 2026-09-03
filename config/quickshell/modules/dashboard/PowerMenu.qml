import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"
import "../../core/ConfirmationGate.js" as ConfirmationGate
import "../../services"

/**
 * PowerMenu - Fullscreen session overlay with confirmation gate, keyboard mnemonics, and diagnostics.
 */
AnimatedWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    showScrim: true
    scrimOpacity: 0.75
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0

    property string confirmingAction: ""

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

        feedbackProc.exec([
            "notify-send",
            "-a", "Power Menu",
            "Sessão",
            "Executando: " + modelData.label
        ]);
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
        return ColorScheme.accent;
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

    Rectangle {
        anchors.fill: parent
        color: ColorScheme.withAlpha(ColorScheme.background, 0.82)
        z: -1
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.isOpen = false
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 40
        z: 1

        // ── Clock & Diagnostics ──────────────────────────────────────
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Text {
                text: Qt.formatDateTime(new Date(), "HH:mm")
                color: ColorScheme.accent
                font.pixelSize: 84
                font.bold: true
                font.family: "Inter"
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16

                Text {
                    text: "\u{f017} Atividade: " + (BatteryStatsService.systemUptime !== "N/A" ? BatteryStatsService.systemUptime : "Ativo")
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.70)
                    font.pixelSize: 13
                    font.family: "Inter"
                    font.weight: Font.Medium
                }

                Rectangle { width: 4; height: 4; radius: 2; color: ColorScheme.withAlpha(ColorScheme.text, 0.3) }

                Text {
                    text: (BatteryStatsService.hasBattery ? ("\u{f240} Bateria: " + BatteryStatsService.batteryPercent + "%") : "\u{f1e6} Alimentação AC") + " · " + BatteryStatsService.powerProfile
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.70)
                    font.pixelSize: 13
                    font.family: "Inter"
                    font.weight: Font.Medium
                }
            }
        }

        // ── 6 Action Cards ───────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 24

            Repeater {
                model: root.actions

                delegate: Item {
                    width: 110; height: 140

                    readonly property color actionColor: root.getActionColor(modelData.key)
                    readonly property bool isConfirming: root.confirmingAction === modelData.key

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12

                        Rectangle {
                            id: btnContainer
                            Layout.preferredWidth: 88
                            Layout.preferredHeight: 88
                            Layout.alignment: Qt.AlignHCenter
                            radius: 44

                            color: isConfirming
                                ? ColorScheme.withAlpha(actionColor, 0.35)
                                : (ma.containsMouse ? ColorScheme.withAlpha(actionColor, 0.22) : ColorScheme.withAlpha(ColorScheme.text, 0.05))

                            border.color: isConfirming ? actionColor : (ma.containsMouse ? actionColor : ColorScheme.withAlpha(actionColor, 0.4))
                            border.width: isConfirming ? 3 : (ma.containsMouse ? 2 : 1)

                            scale: ma.containsMouse ? 1.08 : 1.0
                            Behavior on scale { SpringAnimation { spring: 4; damping: 0.4 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            // Hotkey badge
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 4
                                width: 18; height: 18; radius: 9
                                color: isConfirming ? actionColor : ColorScheme.withAlpha(ColorScheme.text, 0.12)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.hotkey
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.family: "Inter"
                                    color: isConfirming ? "#ffffff" : ColorScheme.withAlpha(ColorScheme.text, 0.8)
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.pixelSize: 34
                                font.family: "JetBrainsMono Nerd Font"
                                color: isConfirming ? actionColor : (ma.containsMouse ? "#ffffff" : actionColor)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Text {
                            text: isConfirming ? "Confirmar?" : modelData.label
                            color: isConfirming ? actionColor : (ma.containsMouse ? "#ffffff" : ColorScheme.withAlpha(ColorScheme.text, 0.85))
                            font.pixelSize: 13
                            font.family: "Inter"
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.executeAction(modelData)
                    }
                }
            }
        }

        // ── Footer Hint ──────────────────────────────────────────────
        Text {
            text: root.confirmingAction !== "" ? "Clique novamente para confirmar a ação" : "Atalhos: S (Desligar) · R (Reiniciar) · U (Suspender) · H (Hibernar) · E (Sair) · L (Bloquear) · ESC para cancelar"
            color: root.confirmingAction !== "" ? ColorScheme.peach : ColorScheme.withAlpha(ColorScheme.accent, 0.6)
            font.pixelSize: 12
            font.family: "Inter"
            font.bold: root.confirmingAction !== ""
            Layout.alignment: Qt.AlignHCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
}
