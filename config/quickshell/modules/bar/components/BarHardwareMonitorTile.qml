import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../services"

Item {
    id: root

    required property color accentColor
    required property var systemMonitorPopup
    required property var nixMonitorPopup
    required property bool anyPopupOpen

    property bool _monHover: false

    visible: FeatureFlags.showHardwareMonitors
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: hwMonitors.width + 12
    implicitHeight: 26
    width: implicitWidth
    height: implicitHeight
    enabled: true
    opacity: 1.0

    Binding {
        target: SystemMetricsService
        property: "active"
        value: root.visible || ShellController.isPopupOpen(root.systemMonitorPopup) || ShellController.isPopupOpen(root.nixMonitorPopup)
        restoreMode: Binding.RestoreNone
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        readonly property bool isOpen: ShellController.isPopupOpen(root.systemMonitorPopup)
        color: isOpen
            ? ColorScheme.withAlpha(root.accentColor, 0.22)
            : (root._monHover && !isOpen && !root.anyPopupOpen ? ColorScheme.glassHover : ColorScheme.withAlpha(ColorScheme.surface, 0.10))
        border.width: 1
        border.color: isOpen
            ? ColorScheme.withAlpha(root.accentColor, DesignTokens.activeBorderOpacity)
            : (root._monHover && !isOpen && !root.anyPopupOpen ? ColorScheme.withAlpha(ColorScheme.foreground, DesignTokens.hoverBorderOpacity) : ColorScheme.glassBorder)
        Behavior on color { ColorAnimation { duration: DesignTokens.durationFast } }
    }

    HardwareMonitors {
        id: hwMonitors
        anchors.centerIn: parent
        gaugeSize: 20
        accentColor: root.accentColor
        onClicked: function(mouseButton, gaugeIndex) {
            if (mouseButton === Qt.LeftButton) {
                ShellController.togglePopup(root, root.systemMonitorPopup);
            }
        }
    }

    HoverHandler {
        id: monHoverHandler
        onHoveredChanged: root._monHover = hovered
    }
}
