pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../../core"
import "../../../shared"

/**
 * BarOverviewButton - Dedicated workspace overview (Mission Control) trigger widget.
 *
 * Provides a clean glass button with hover/press micro-interactions,
 * active indicator when overview is open, wheel navigation across workspaces,
 * and quick exposé/switcher triggers.
 */
Item {
    id: root

    // ─── Public API ──────────────────────────────────────────────
    required property var overviewInstance
    property var exposeInstance: null
    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.foreground
    property bool compact: false
    property bool anyPopupOpen: false

    readonly property bool isOverviewOpen: ShellController.isPopupOpen(root.overviewInstance)
    readonly property bool isExposeOpen: root.exposeInstance ? ShellController.isPopupOpen(root.exposeInstance) : false
    readonly property bool isOpen: isOverviewOpen || isExposeOpen
    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion

    implicitWidth: pill.implicitWidth
    implicitHeight: DesignTokens.barItemHeight

    function toggleOverview() {
        ShellController.togglePopup(root, root.overviewInstance);
    }

    function toggleExpose() {
        if (root.exposeInstance) {
            ShellController.togglePopup(root, root.exposeInstance);
        } else {
            ShellController.togglePopup(root, root.overviewInstance);
        }
    }

    PillWidget {
        id: pill
        anchors.fill: parent

        iconText: "\u{f009}" // Modern 4-square grid / Mission Control icon
        iconFontFamily: DesignTokens.fontFamilyMono
        iconFontSize: root.compact ? 12 : 14
        iconColor: root.isOpen ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.75)

        checked: root.isOpen
        popupOpen: root.isOpen
        anyPopupOpen: root.anyPopupOpen
        tooltipText: "Visão Geral (Overview)\n• Clique: Workspaces (Mission Control)\n• Botão Direito: Exposé / Janelas\n• Scroll: Alternar Workspaces"

        mouseArea.acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        mouseArea.onClicked: (mouse) => {
            pill._realHover = false;
            if (mouse.button === Qt.RightButton) {
                root.toggleExpose();
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                ShellController.togglePopup(root, root.overviewInstance, { currentWorkspaceOnly: !root.isOpen });
                return;
            }
            root.toggleOverview();
        }

        // Active State Glow Dot
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 2
            width: root.isOpen ? 4 : 0
            height: root.isOpen ? 4 : 0
            radius: 2
            color: root.accentColor
            visible: root.isOpen

            Behavior on width {
                enabled: !root.reducedEffects
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
            Behavior on height {
                enabled: !root.reducedEffects
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
        }
    }

    // Scroll wheel over the overview button quickly flips through Hyprland workspaces
    WheelHandler {
        target: root
        orientation: Qt.Vertical
        onWheel: (event) => {
            var step = event.angleDelta.y > 0 ? "e-1" : "e+1";
            Hyprland.dispatch("workspace " + step);
        }
    }
}
