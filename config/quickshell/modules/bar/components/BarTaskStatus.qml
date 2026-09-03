import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../core"
import "../../../shared"
import "../../../services"

PillWidget {
    id: root

    required property color accentColor
    required property color textColor
    required property var popupInstance
    property bool pollActive: visible

    property string topName: ""
    property real   topCpu:  0.0

    TimedProcess {
        id: psProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/);
                    if (parts.length >= 3 && parts[0] !== "PID") {
                        root.topName = parts[1].substring(0, 12);
                        root.topCpu  = parseFloat(parts[2]) || 0;
                        break;
                    }
                }
            }
        }
    }

    Timer {
        interval: FeatureFlags.lowPowerUiMode ? 20000 : 10000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: psProc.exec(["ps", "-eo", "pid,comm,pcpu", "--sort=-pcpu"])
    }

    iconText: "\u{f4bc}"
    iconColor: root.topCpu > 80 ? ColorScheme.red : root.topCpu > 40 ? ColorScheme.peach : root.accentColor
    checked: ShellController.isPopupOpen(root.popupInstance)
    popupOpen: checked
    
    labelText: (root.topName !== "" ? root.topName : "idle") + (root.topCpu > 0.1 ? " " + root.topCpu.toFixed(0) + "%" : "")
    labelColor: root.topCpu > 80 ? ColorScheme.red : root.topCpu > 40 ? ColorScheme.peach : ColorScheme.withAlpha(root.textColor, 0.75)

    onClicked: ShellController.togglePopup(root, root.popupInstance)

    ToolTip {
        visible: root.mouseArea.containsMouse
        delay: 600
        text: "Top process: " + root.topName + " (" + root.topCpu.toFixed(1) + "% CPU)"
    }
}
