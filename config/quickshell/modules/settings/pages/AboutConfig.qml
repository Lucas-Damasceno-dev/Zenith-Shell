import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../widgets"
import "../"

ColumnLayout {
    id: root

    spacing: DesignTokens.spacingLG
    Layout.fillWidth: true

    readonly property var deps: [
        { name: "PipeWire (wpctl)", desc: "Low-latency audio and microphone graph server", status: "Installed" },
        { name: "NetworkManager (nmcli)", desc: "Wi-Fi, Ethernet, and connection state management", status: "Installed" },
        { name: "Power Profiles Daemon", desc: "Energy management & battery governor switcher", status: "Installed" },
        { name: "Grim & Slurp", desc: "Wayland screen pixel grabber and region selector", status: "Installed" },
        { name: "wf-recorder", desc: "Hardware-accelerated Wayland screen recorder", status: "Installed" },
        { name: "Swww Daemon", desc: "Animated Wayland wallpaper daemon with transition shaders", status: "Installed" },
        { name: "Matugen", desc: "Material You cross-app palette generator", status: "Installed" }
    ]

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 120
        radius: DesignTokens.radiusLG
        color: ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.50)
        border.width: 1
        border.color: ColorScheme.withAlpha(ColorScheme.outline, 0.15)

        RowLayout {
            anchors.fill: parent
            anchors.margins: DesignTokens.spacingXL
            spacing: DesignTokens.spacingXL

            Rectangle {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                radius: 32
                color: ColorScheme.accent

                Text {
                    anchors.centerIn: parent
                    text: "\uf013" // cog
                    font.family: Style.fontMono
                    font.pixelSize: 32
                    color: ColorScheme.onPrimary
                    renderType: Style.renderType
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    spacing: DesignTokens.spacingMD

                    Text {
                        text: "Zenith Desktop Shell"
                        font.family: Style.fontUI
                        font.pixelSize: Style.fontSizeHeading
                        font.weight: Font.Bold
                        color: ColorScheme.text
                        renderType: Style.renderType
                    }

                    Rectangle {
                        Layout.preferredHeight: 20
                        implicitWidth: verText.implicitWidth + 12
                        radius: 10
                        color: ColorScheme.withAlpha(ColorScheme.accent, 0.20)

                        Text {
                            id: verText
                            anchors.centerIn: parent
                            text: "v2.0-hybrid"
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeXS
                            font.weight: Font.DemiBold
                            color: ColorScheme.accent
                            renderType: Style.renderType
                        }
                    }
                }

                Text {
                    text: "High-performance Wayland desktop shell powered by Quickshell, Rust core, and Hyprland."
                    font.family: Style.fontUI
                    font.pixelSize: Style.fontSizeSM
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.70)
                    renderType: Style.renderType
                }
            }
        }
    }

    SettingsCard {
        title: "System Ecosystem & Dependencies"
        description: "Essential Wayland and Linux userland utilities status."
        iconGlyph: "\uf085"

        Repeater {
            model: root.deps

            delegate: ColumnLayout {
                id: itemCol
                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: DesignTokens.spacingMD

                RowLayout {
                    Layout.fillWidth: true
                    spacing: DesignTokens.spacingMD

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: modelData.name
                            font.family: Style.fontUI
                            font.pixelSize: Style.fontSizeMD
                            font.weight: Font.Medium
                            color: ColorScheme.text
                            renderType: Style.renderType
                        }

                        Text {
                            text: modelData.desc
                            font.family: Style.fontUI
                            font.pixelSize: Style.fontSizeSM
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                            renderType: Style.renderType
                        }
                    }

                    Rectangle {
                        Layout.preferredHeight: 22
                        implicitWidth: stText.implicitWidth + 12
                        radius: 11
                        color: ColorScheme.withAlpha(ColorScheme.green, 0.20)

                        Text {
                            id: stText
                            anchors.centerIn: parent
                            text: modelData.status
                            font.family: Style.fontUI
                            font.pixelSize: Style.fontSizeXS
                            font.weight: Font.Bold
                            color: ColorScheme.green
                            renderType: Style.renderType
                        }
                    }
                }

                SettingsDivider {
                    visible: index < root.deps.length - 1
                }
            }
        }
    }
}
