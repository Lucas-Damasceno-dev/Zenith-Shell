import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../widgets"
import "../"

ColumnLayout {
    id: root

    spacing: DesignTokens.spacingLG
    Layout.fillWidth: true

    property string statusMessage: ""

    SettingsCard {
        title: "Runtime Performance & Memory"
        description: "V8/QML garbage collector, memory budgets, and GPU shader performance."
        iconGlyph: "\uf0ad"

        SettingsRow {
            title: "JavaScript GC Threshold"
            description: "Heap threshold in megabytes that forces V8 garbage collection."
            iconGlyph: "\uf1c0"

            SettingsSlider {
                configKey: "advanced.jsgcThresholdMb"
                from: 64
                to: 512
                stepSize: 32
                unit: "MB"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Memory Warning Notifications"
            description: "Alert when shell VmRSS approaches latency budget limits."
            iconGlyph: "\uf071"

            SettingsSwitch {
                configKey: "advanced.memoryWarningNotification"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Low Power Auto-Engage Threshold"
            description: "Battery percentage that automatically triggers low power mode."
            iconGlyph: "\uf243"

            SettingsSlider {
                configKey: "advanced.lowPowerThreshold"
                from: 5
                to: 40
                stepSize: 5
                unit: "%"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Compositor Shader Blur"
            description: "Hardware accelerated dual-kawase blur shader passes."
            iconGlyph: "\uf28b"

            SettingsSwitch {
                configKey: "advanced.compositorBlur"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Shell Log Verbosity"
            description: "Logging level written to ~/.local/state/quickshell/shell.log."
            iconGlyph: "\uf15c"

            SettingsChoice {
                configKey: "advanced.logLevel"
                options: [
                    { label: "Info", value: "info" },
                    { label: "Warning", value: "warn" },
                    { label: "Debug", value: "debug" }
                ]
            }
        }
    }

    SettingsCard {
        title: "Configuration Backup & Maintenance"
        description: "Export, restore, or reset Zenith-Shell configuration file."
        iconGlyph: "\uf1da"

        SettingsRow {
            title: "Configuration File Actions"
            description: "Flush current state, reset to default schema, or export JSON."
            iconGlyph: "\uf0c7"

            RowLayout {
                spacing: DesignTokens.spacingSM

                SettingsButton {
                    text: "Save & Flush"
                    iconGlyph: "\uf0c7"
                    isPrimary: true
                    onClicked: {
                        SettingsConfig.flush();
                        root.statusMessage = "Configuration flushed to disk.";
                    }
                }

                SettingsButton {
                    text: "Reset Defaults"
                    iconGlyph: "\uf0e2"
                    isDanger: true
                    onClicked: {
                        SettingsConfig.resetDefaults();
                        root.statusMessage = "Configuration reset to factory defaults.";
                    }
                }
            }
        }

        Text {
            visible: root.statusMessage.length > 0
            text: root.statusMessage
            font.family: Style.fontUI
            font.pixelSize: Style.fontSizeSM
            color: ColorScheme.accent
            renderType: Style.renderType
            Layout.alignment: Qt.AlignRight
        }
    }
}
