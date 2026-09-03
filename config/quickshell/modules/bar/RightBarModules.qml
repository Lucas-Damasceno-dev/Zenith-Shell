import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import "../../core"
import "../../shared"
import "../../services"
import "components"

Item {
    id: root

    required property color accentColor
    required property color textColor

    required property var systemMonitorPopup
    required property var errorPopup
    required property var audioPopup
    required property var networkPopup
    required property var batteryPopup
    required property var sessionPopup
    property var contextPopup: null
    required property var clipboardPopup
    required property var nixMonitorPopup
    required property var usbPopup
    required property var contextData
    required property bool anyPopupOpen
    required property var binaryStatus
    required property bool healthChecked
    required property bool shellDegraded

    readonly property bool focusMode: FeatureFlags.focusMode
    readonly property bool networkAvailable: depsReady(["nmcli", "bluetoothctl"])
    readonly property bool audioAvailable: depsReady(["wpctl"])
    readonly property bool batteryAvailable: depsReady(["upower", "brightnessctl", "powerprofilesctl"])

    function binaryReady(name) {
        if (!healthChecked) return true;
        return !!(binaryStatus && binaryStatus[name] === true);
    }

    function depsReady(deps) {
        for (var i = 0; i < deps.length; i++) {
            if (!binaryReady(deps[i])) return false;
        }
        return true;
    }

    function togglePopup(popup) {
        ShellController.togglePopup(root, popup);
    }

    implicitWidth: rightRow.implicitWidth
    implicitHeight: rightRow.implicitHeight

    RowLayout {
        id: rightRow
        anchors.fill: parent
        spacing: DesignTokens.spacingXS

        // ── Privacy Indicator ─────────────────────────────────────────
        BarPrivacyIndicator {
            Layout.alignment: Qt.AlignVCenter
            accentColor: root.accentColor
            textColor: root.textColor
            anyPopupOpen: root.anyPopupOpen
        }


        // ── System Cluster (KDE Connect, Tray, Clipboard, Hardware Monitors) ────
        RowLayout {
            id: systemCluster
            Layout.alignment: Qt.AlignVCenter
            spacing: DesignTokens.spacingXXS
            visible: !root.focusMode && (FeatureFlags.showSystemTray || FeatureFlags.showHardwareMonitors || FeatureFlags.showClipboardTile)

            BarKdeConnect {
                Layout.alignment: Qt.AlignVCenter
                accentColor: root.accentColor
                textColor: root.textColor
            }

            SystemTray {
                id: sysTray
                visible: FeatureFlags.showSystemTray && sysTray.hasVisibleItems
                Layout.alignment: Qt.AlignVCenter
                iconColor: root.accentColor
            }

            Rectangle {
                visible: FeatureFlags.showSystemTray && sysTray.hasVisibleItems
                Layout.alignment: Qt.AlignVCenter
                width: 1
                height: 16
                color: ColorScheme.withAlpha(ColorScheme.foreground, 0.08)
            }

            BarClipboardStatus {
                visible: FeatureFlags.showClipboardTile && !root.focusMode
                Layout.alignment: Qt.AlignVCenter
                accentColor: root.accentColor
                textColor: root.textColor
                popupInstance: root.clipboardPopup
                anyPopupOpen: root.anyPopupOpen
            }

            BarHardwareMonitorTile {
                accentColor: root.accentColor
                systemMonitorPopup: root.systemMonitorPopup
                nixMonitorPopup: root.nixMonitorPopup
                anyPopupOpen: root.anyPopupOpen
            }
        }

        // ── Status Cluster (Network, Audio, Battery, Nix, USB, Layout) ─
        RowLayout {
            id: statusCluster
            Layout.alignment: Qt.AlignVCenter
            spacing: DesignTokens.spacingXS

            BarNetworkStatus {
                Layout.alignment: Qt.AlignVCenter
                accentColor: root.accentColor
                textColor: root.textColor
                popupInstance: root.networkPopup
                anyPopupOpen: root.anyPopupOpen
                enabled: root.networkAvailable
                opacity: root.networkAvailable ? 1.0 : 0.45
            }

            BarAudioStatus {
                Layout.alignment: Qt.AlignVCenter
                accentColor: root.accentColor
                textColor: root.textColor
                popupInstance: root.audioPopup
                anyPopupOpen: root.anyPopupOpen
                enabled: root.audioAvailable
                opacity: root.audioAvailable ? 1.0 : 0.45
            }

            BarBatteryStatus {
                Layout.alignment: Qt.AlignVCenter
                accentColor: root.accentColor
                textColor: root.textColor
                popupInstance: root.batteryPopup
                anyPopupOpen: root.anyPopupOpen
                enabled: root.batteryAvailable
                opacity: root.batteryAvailable ? 1.0 : 0.45
            }

            BarUSBStatus {
                Layout.alignment: Qt.AlignVCenter
                accentColor: root.accentColor
                textColor: root.textColor
                popupInstance: root.usbPopup
                anyPopupOpen: root.anyPopupOpen
            }

            BarKeyboardLayout {
                Layout.alignment: Qt.AlignVCenter
                accentColor: root.accentColor
                textColor: root.textColor
                anyPopupOpen: root.anyPopupOpen
            }
        }

        // ── Action Cluster (Session) ────────────────────────────────
        RowLayout {
            id: actionCluster
            Layout.alignment: Qt.AlignVCenter
            spacing: DesignTokens.spacingXS

            PillWidget {
                id: sessionTile
                visible: FeatureFlags.showSessionButton
                Layout.alignment: Qt.AlignVCenter

                readonly property bool isOpen: ShellController.isPopupOpen(root.sessionPopup)

                iconText: "\u{f011}"
                iconColor: isOpen ? ColorScheme.red : ColorScheme.accent
                checked: isOpen
                popupOpen: checked
                anyPopupOpen: root.anyPopupOpen
                tooltipText: isOpen ? "Session menu open" : "Session actions"

                onClicked: root.togglePopup(root.sessionPopup)
            }
        }
    }
}
