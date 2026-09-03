import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../core"

/**
 * HotCorners - Invisible zones at screen corners that trigger actions
 *
 * Corner actions:
 *   - Top Left: Overview (SUPER+Space equivalent)
 *   - Top Right: Expose mode (all windows on all workspaces)
 *   - Bottom Left: Launcher
 *   - Bottom Right: Special workspace toggle
 *
 * Each corner is a small invisible window that activates on hover.
 * A brief delay prevents accidental triggers.
 */
Item {
    id: root

    required property var modelData
    required property var launcherLoader
    required property var overviewLoader
    required property var overviewCurrentLoader
    required property var exposeLoader
    property var screenData: modelData

    // Corner size (how large the trigger zone is)
    readonly property int cornerSize: 18
    // Hover delay before triggering (ms)
    readonly property int triggerDelay: 80
    // Cooldown after trigger (ms)
    readonly property int cooldownTime: 450

    // Prevent rapid re-triggers
    property bool onCooldown: false

    Timer {
        id: cooldownTimer
        interval: root.cooldownTime
        onTriggered: root.onCooldown = false
    }

    function triggerAction(corner) {
        if (root.onCooldown) return;
        root.onCooldown = true;
        cooldownTimer.restart();

        switch (corner) {
            case "topLeft":
                // Overview (all workspaces)
                PopupUtils.togglePopup(root, root.overviewLoader);
                break;
            case "topRight":
                // Expose popup (all windows from all workspaces)
                PopupUtils.togglePopup(root, root.exposeLoader);
                break;
            case "bottomLeft":
                // Launcher
                PopupUtils.togglePopup(root, root.launcherLoader);
                break;
            case "bottomRight":
                // Toggle the special workspace that corresponds to the workspace
                // the user was on when they activated the corner. If we can't
                // determine the current workspace id, fall back to sp1.
                var wsId = null;
                if (Hyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id)
                    wsId = Hyprland.focusedWorkspace.id;
                else if (Hyprland && Hyprland.activeToplevel && Hyprland.activeToplevel.workspace && Hyprland.activeToplevel.workspace.id)
                    wsId = Hyprland.activeToplevel.workspace.id;

                if (!wsId || wsId < 1) wsId = 1;

                // Clamp to 1..10 (special workspaces are sp1..sp10 in this config)
                if (wsId > 10) wsId = ((wsId - 1) % 10) + 1;

                Hyprland.dispatch("togglespecialworkspace sp" + wsId);
                break;
        }
    }

    // Top Left Corner
    PanelWindow {
        id: topLeftCorner
        screen: root.screenData
        
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:hotcorner"
        
        anchors.top: true
        anchors.left: true

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        width: root.cornerSize
        height: root.cornerSize
        
        color: "transparent"
        
        property bool hovered: false
        
        Timer {
            id: topLeftTimer
            interval: root.triggerDelay
            onTriggered: {
                if (topLeftCorner.hovered) {
                    root.triggerAction("topLeft");
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                topLeftCorner.hovered = true;
                topLeftTimer.start();
            }
            onExited: {
                topLeftCorner.hovered = false;
                topLeftTimer.stop();
            }
        }
    }

    // Top Right Corner
    PanelWindow {
        id: topRightCorner
        screen: root.screenData
        
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:hotcorner"
        
        anchors.top: true
        anchors.right: true

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        width: root.cornerSize
        height: root.cornerSize
        
        color: "transparent"
        
        property bool hovered: false
        
        Timer {
            id: topRightTimer
            interval: root.triggerDelay
            onTriggered: {
                if (topRightCorner.hovered) {
                    root.triggerAction("topRight");
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                topRightCorner.hovered = true;
                topRightTimer.start();
            }
            onExited: {
                topRightCorner.hovered = false;
                topRightTimer.stop();
            }
        }
    }

    // Bottom Left Corner
    PanelWindow {
        id: bottomLeftCorner
        screen: root.screenData
        
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:hotcorner"
        
        anchors.bottom: true
        anchors.left: true

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        width: root.cornerSize
        height: root.cornerSize
        
        color: "transparent"
        
        property bool hovered: false
        
        Timer {
            id: bottomLeftTimer
            interval: root.triggerDelay
            onTriggered: {
                if (bottomLeftCorner.hovered) {
                    root.triggerAction("bottomLeft");
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                bottomLeftCorner.hovered = true;
                bottomLeftTimer.start();
            }
            onExited: {
                bottomLeftCorner.hovered = false;
                bottomLeftTimer.stop();
            }
        }
    }

    // Bottom Right Corner
    PanelWindow {
        id: bottomRightCorner
        screen: root.screenData
        
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:hotcorner"
        
        anchors.bottom: true
        anchors.right: true

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        width: root.cornerSize
        height: root.cornerSize
        
        color: "transparent"
        
        property bool hovered: false
        
        Timer {
            id: bottomRightTimer
            interval: root.triggerDelay
            onTriggered: {
                if (bottomRightCorner.hovered) {
                    root.triggerAction("bottomRight");
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                bottomRightCorner.hovered = true;
                bottomRightTimer.start();
            }
            onExited: {
                bottomRightCorner.hovered = false;
                bottomRightTimer.stop();
            }
        }
    }
}
