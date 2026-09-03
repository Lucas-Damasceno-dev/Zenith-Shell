import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../core"

/**
 * DockUtilities — Quick system tools that participate in magnification.
 */
Item {
    id: root

    property real baseSize: 48
    property bool zenActive: false
    property real magnification: 1.0
    property real riseOffset: 0
    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion
    
    readonly property real displaySize: baseSize * magnification

    Behavior on magnification {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 72; easing.type: Easing.OutCubic }
    }
    Behavior on riseOffset {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 72; easing.type: Easing.OutCubic }
    }

    readonly property var utilities: [
        { id: "colorpicker", icon: "\u{f1fb}", color: "mauve",  name: "Color Picker" },
        { id: "killswitch",  icon: "\u{f00d}", color: "red",    name: "Kill Window" },
        { id: "zenmode",     icon: zenActive ? "\u{f185}" : "\u{f0e7}", color: "yellow", name: zenActive ? "Exit Zen" : "Zen Mode" },
        { id: "pip",         icon: "\u{f2d0}", color: "teal",   name: "Picture-in-Picture" },
        { id: "quake",       icon: "\u{f120}", color: "green",  name: "Quick Terminal" }
    ]

    width: utilRow.width
    height: displaySize

    signal hovered(bool isHovered)

    Row {
        id: utilRow
        anchors.centerIn: parent
        spacing: 2 * magnification

        Repeater {
            model: root.utilities

            delegate: Item {
                width: root.displaySize
                height: root.displaySize

                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -root.riseOffset
                    width: root.displaySize * 0.85
                    height: root.displaySize * 0.85
                    radius: 12 * magnification
                    color: utilMouse.containsMouse
                        ? ColorScheme.withAlpha(ColorScheme.surface, 0.35)
                        : "transparent"
                    Behavior on color {
                        enabled: !root.reducedEffects
                        ColorAnimation { duration: 120 }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -root.riseOffset
                    text: modelData.icon
                    font.pixelSize: root.displaySize * 0.45
                    font.family: Style.fontMono
                    color: {
                        var c = modelData.color;
                        if (c === "mauve") return ColorScheme.mauve;
                        if (c === "red") return ColorScheme.red;
                        if (c === "yellow") return ColorScheme.yellow;
                        if (c === "teal") return ColorScheme.teal;
                        if (c === "green") return ColorScheme.green;
                        return ColorScheme.text;
                    }
                    opacity: utilMouse.containsMouse ? 1.0 : 0.7
                    Behavior on opacity {
                        enabled: !root.reducedEffects
                        NumberAnimation { duration: 120 }
                    }
                }

                scale: utilMouse.pressed ? DesignTokens.pressedScale : 1.0
                Behavior on scale {
                    enabled: !root.reducedEffects
                    SpringAnimation { spring: DesignTokens.springSnappy; damping: DesignTokens.dampingSnappy; epsilon: 0.01 }
                }

                MouseArea {
                    id: utilMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onContainsMouseChanged: root.hovered(containsMouse)
                    onClicked: {
                        if (modelData.id === "colorpicker") colorPickerProc.running = true;
                        else if (modelData.id === "killswitch") Hyprland.dispatch("killactive");
                        else if (modelData.id === "zenmode") toggleZen();
                        else if (modelData.id === "pip") togglePip();
                        else if (modelData.id === "quake") toggleQuake();
                    }
                }
            }
        }
    }

    Process {
        id: colorPickerProc
        command: ["hyprpicker", "-a", "-f", "hex"]
        onExited: {
            if (code !== 0) {
                errorNotifyProc.command = ["notify-send", "-a", "Quickshell", "Error", "Check if hyprpicker is installed or if the action was cancelled."];
                errorNotifyProc.running = true;
            }
        }
    }
    Process { id: errorNotifyProc }

    property int savedGapsIn: 5
    property int savedGapsOut: 8
    property int savedRounding: 14

    Process {
        id: fetchOptionsProc
        command: ["bash", "-c", "echo $(hyprctl -j getoption general:gaps_in | grep -o '\"int\": [0-9]*' | cut -d' ' -f2) $(hyprctl -j getoption general:gaps_out | grep -o '\"int\": [0-9]*' | cut -d' ' -f2) $(hyprctl -j getoption decoration:rounding | grep -o '\"int\": [0-9]*' | cut -d' ' -f2)"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = String(text || "").trim().split(" ");
                if (parts.length >= 3) {
                    root.savedGapsIn = parseInt(parts[0]) || 5;
                    root.savedGapsOut = parseInt(parts[1]) || 8;
                    root.savedRounding = parseInt(parts[2]) || 14;
                }
                var batch = "keyword general:gaps_in 0 ; keyword general:gaps_out 0 ; keyword decoration:rounding 0 ; keyword animations:enabled false";
                Hyprland.dispatch("batch " + batch);
            }
        }
    }

    function toggleZen() {
        root.zenActive = !root.zenActive;
        if (root.zenActive) {
            fetchOptionsProc.running = true;
        } else {
            var batch = "keyword general:gaps_in " + root.savedGapsIn + " ; keyword general:gaps_out " + root.savedGapsOut + " ; keyword decoration:rounding " + root.savedRounding + " ; keyword animations:enabled true";
            Hyprland.dispatch("batch " + batch);
        }
    }

    function togglePip() {
        var mon = Hyprland.focusedMonitor;
        if (!mon) return;
        var pipW = Math.round(mon.width * 0.25);
        var pipH = Math.round(mon.height * 0.25);
        var pipX = mon.width - pipW - 10;
        var pipY = mon.height - pipH - 90;
        
        var batch = "dispatch togglefloating ; dispatch pin ; dispatch resizeactive exact " +
                    pipW + " " + pipH + " ; dispatch moveactive exact " + pipX + " " + pipY;
        
        Hyprland.dispatch("batch " + batch);
    }

    function toggleQuake() {
        Hyprland.dispatch("togglespecialworkspace quick-term");
    }
}
