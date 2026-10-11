import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../widgets"
import "../"

ColumnLayout {
    id: root

    spacing: DesignTokens.spacingLG
    Layout.fillWidth: true

    property string currentSection: "audio"

    SettingsSubnav {
        activeTab: root.currentSection
        tabs: [
            { id: "audio", label: "Audio", icon: "\uf028" },
            { id: "power", label: "Power & Battery", icon: "\uf240" },
            { id: "security", label: "Display & Security", icon: "\uf023" },
            { id: "locale", label: "Locale & Time", icon: "\uf017" }
        ]
        onTabSelected: section => root.currentSection = section
    }

    // --- Audio Section ---
    ColumnLayout {
        visible: root.currentSection === "audio"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Audio Routing & Limits"
            description: "Default output and input devices, volume granularity, and protection."
            iconGlyph: "\uf028"

            SettingsRow {
                title: "Preferred Output Device (Sink)"
                description: "Name or pattern of the preferred PipeWire audio sink."
                iconGlyph: "\uf026"

                SettingsTextField {
                    configKey: "system.audioPreferredSink"
                    placeholderText: "e.g. alsa_output.pci..."
                    preferredWidth: 260
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Preferred Input Device (Source)"
                description: "Name or pattern of the preferred microphone."
                iconGlyph: "\uf130"

                SettingsTextField {
                    configKey: "system.audioPreferredSource"
                    placeholderText: "e.g. alsa_input.pci..."
                    preferredWidth: 260
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Volume Adjustment Step"
                description: "Volume percentage changed per keypress or scroll event."
                iconGlyph: "\uf0de"

                SettingsSlider {
                    configKey: "system.audioVolumeStep"
                    from: 0.01
                    to: 0.10
                    stepSize: 0.01
                    decimals: 2
                    unit: "step"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Audio Protection"
                description: "Prevent accidental jumps above 100% volume to protect hearing."
                iconGlyph: "\uf132"

                SettingsSwitch {
                    configKey: "system.audioProtection"
                }
            }
        }
    }

    // --- Power & Battery Section ---
    ColumnLayout {
        visible: root.currentSection === "power"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Battery & Energy Management"
            description: "Charge thresholds, power profiles, and automatic suspension."
            iconGlyph: "\uf240"

            SettingsRow {
                title: "Active Power Profile"
                description: "System power profile configured via power-profiles-daemon."
                iconGlyph: "\uf0e4"

                SettingsChoice {
                    configKey: "system.batteryPowerProfile"
                    options: [
                        { label: "Power-Saver", value: "power-saver" },
                        { label: "Balanced", value: "balanced" },
                        { label: "Performance", value: "performance" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Charge Threshold Limit"
                description: "Maximum battery charge limit to extend battery longevity."
                iconGlyph: "\uf1e6"

                SettingsSlider {
                    configKey: "system.batteryChargeLimit"
                    from: 60
                    to: 100
                    stepSize: 5
                    unit: "%"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Low Battery Warning Threshold"
                description: "Triggers notification and prompts low power mode."
                iconGlyph: "\uf243"

                SettingsSlider {
                    configKey: "system.batteryLowThreshold"
                    from: 10
                    to: 35
                    stepSize: 5
                    unit: "%"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Critical Battery Threshold"
                description: "Level where emergency sleep or hibernate action engages."
                iconGlyph: "\uf071"

                SettingsSlider {
                    configKey: "system.batteryCriticalThreshold"
                    from: 3
                    to: 15
                    stepSize: 1
                    unit: "%"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Notify When Fully Charged"
                description: "Desktop toast notification when battery reaches limit."
                iconGlyph: "\uf0f3"

                SettingsSwitch {
                    configKey: "system.batteryNotifyFull"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Auto-Suspend Timeout"
                description: "Minutes of inactivity before machine goes to sleep (0 to disable)."
                iconGlyph: "\uf186"

                SettingsSlider {
                    configKey: "system.suspendTimeoutMin"
                    from: 0
                    to: 60
                    stepSize: 5
                    unit: "min"
                }
            }
        }
    }

    // --- Display & Security Section ---
    ColumnLayout {
        visible: root.currentSection === "security"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Night Light & Comfort"
            description: "Blue light reduction and visual comfort filters."
            iconGlyph: "\uf185"

            SettingsRow {
                title: "Enable Night Light"
                description: "Warm color temperature for late-night viewing comfort."
                iconGlyph: "\uf186"

                SettingsSwitch {
                    configKey: "system.nightLightEnabled"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Color Temperature"
                description: "Kelvin color warmth value (lower = warmer / redder)."
                iconGlyph: "\uf2c9"

                SettingsSlider {
                    configKey: "system.nightLightValue"
                    from: 2500
                    to: 6500
                    stepSize: 250
                    unit: "K"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Grayscale Filter Intensity"
                description: "Desaturate screen colors to reduce eye fatigue and dopamine triggers."
                iconGlyph: "\uf042"

                SettingsSlider {
                    configKey: "system.grayscaleValue"
                    from: 0
                    to: 100
                    stepSize: 5
                    unit: "%"
                }
            }
        }

        SettingsCard {
            title: "Lock Screen & Hyprlock"
            description: "Security boundaries, lock screen visuals, and authentication."
            iconGlyph: "\uf023"

            SettingsRow {
                title: "Hyprlock Blur Radius"
                description: "Background blur amount applied when the screen is locked."
                iconGlyph: "\uf28b"

                SettingsSlider {
                    configKey: "system.hyprlockBlur"
                    from: 0
                    to: 16
                    stepSize: 1
                    unit: "px"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Grace Period"
                description: "Seconds after locking where unlocking requires no password."
                iconGlyph: "\uf252"

                SettingsSlider {
                    configKey: "system.hyprlockGraceSec"
                    from: 0
                    to: 30
                    stepSize: 5
                    unit: "s"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Show Clock On Lock Screen"
                description: "Display typography clock on the lock screen."
                iconGlyph: "\uf017"

                SettingsSwitch {
                    configKey: "system.hyprlockShowClock"
                }
            }
        }
    }

    // --- Locale & Time Section ---
    ColumnLayout {
        visible: root.currentSection === "locale"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Date, Time & Productivity"
            description: "Formatting standards and Pomodoro focus intervals."
            iconGlyph: "\uf017"

            SettingsRow {
                title: "Time Format"
                description: "Choose 24-hour military format or 12-hour AM/PM format."
                iconGlyph: "\uf017"

                SettingsChoice {
                    configKey: "system.timeFormat"
                    options: [
                        { label: "24-Hour", value: "24h" },
                        { label: "12-Hour AM/PM", value: "12h" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Date Format String"
                description: "Format string for bar clock and calendar headers."
                iconGlyph: "\uf073"

                SettingsTextField {
                    configKey: "system.dateFormat"
                    placeholderText: "ddd, dd/MM"
                    preferredWidth: 200
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Show Seconds Precision"
                description: "Display ticking seconds on clock widgets."
                iconGlyph: "\uf253"

                SettingsSwitch {
                    configKey: "system.secondPrecision"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Pomodoro Focus Duration"
                description: "Minutes per Pomodoro focus session."
                iconGlyph: "\uf2f2"

                SettingsSlider {
                    configKey: "system.pomodoroFocusMin"
                    from: 15
                    to: 60
                    stepSize: 5
                    unit: "min"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Pomodoro Break Duration"
                description: "Minutes per short relaxation break."
                iconGlyph: "\uf0f4"

                SettingsSlider {
                    configKey: "system.pomodoroBreakMin"
                    from: 3
                    to: 15
                    stepSize: 1
                    unit: "min"
                }
            }
        }
    }
}
