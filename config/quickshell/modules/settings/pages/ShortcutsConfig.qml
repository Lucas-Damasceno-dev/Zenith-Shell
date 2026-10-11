import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../widgets"
import "../"

ColumnLayout {
    id: root

    spacing: DesignTokens.spacingLG
    Layout.fillWidth: true

    readonly property var shortcutsList: [
        { key: "Super + Space", action: "Toggle Application Launcher", category: "Navigation" },
        { key: "Super + ,", action: "Open Zenith Settings Menu", category: "Navigation" },
        { key: "Super + Tab", action: "Toggle Workspace Overview / Exposé", category: "Navigation" },
        { key: "Super + D", action: "Toggle Dashboard Overview Hub", category: "Navigation" },
        { key: "Super + V", action: "Toggle Clipboard History Manager", category: "Utilities" },
        { key: "Super + B", action: "Toggle Top Bar Auto-Hide", category: "Panel" },
        { key: "Super + Shift + S", action: "Interactive Region Screenshot", category: "Capture" },
        { key: "Super + Shift + R", action: "Screen Recorder (wf-recorder)", category: "Capture" },
        { key: "Super + Shift + C", action: "Toggle CheatSheet Keybind Overlay", category: "Utilities" },
        { key: "Super + Return", action: "Launch Default Terminal Emulator", category: "Apps" },
        { key: "Super + Q", action: "Close Active Focused Window", category: "Window" },
        { key: "Super + F", action: "Toggle Window Fullscreen", category: "Window" }
    ]

    SettingsCard {
        title: "Keybindings & Shortcuts Reference"
        description: "Hyprland and Zenith-Shell global keyboard shortcuts."
        iconGlyph: "\uf11c"

        Repeater {
            model: root.shortcutsList

            delegate: ColumnLayout {
                id: itemCol
                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: DesignTokens.spacingMD

                RowLayout {
                    Layout.fillWidth: true
                    spacing: DesignTokens.spacingMD

                    Text {
                        text: modelData.action
                        font.family: Style.fontUI
                        font.pixelSize: Style.fontSizeMD
                        font.weight: Font.Medium
                        color: ColorScheme.text
                        renderType: Style.renderType
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredHeight: 26
                        implicitWidth: keyText.implicitWidth + DesignTokens.spacingMD * 2
                        radius: DesignTokens.radiusXS
                        color: ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.70)
                        border.width: 1
                        border.color: ColorScheme.withAlpha(ColorScheme.outline, 0.20)

                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: modelData.key
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeXS
                            font.weight: Font.Bold
                            color: ColorScheme.accent
                            renderType: Style.renderType
                        }
                    }
                }

                SettingsDivider {
                    visible: index < root.shortcutsList.length - 1
                }
            }
        }
    }
}
