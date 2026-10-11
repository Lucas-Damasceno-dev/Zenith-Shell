import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../widgets"
import "../"

ColumnLayout {
    id: root

    spacing: DesignTokens.spacingLG
    Layout.fillWidth: true

    property string currentSection: "geometry"

    SettingsSubnav {
        activeTab: root.currentSection
        tabs: [
            { id: "geometry", label: "Geometry & Style", icon: "\uf2d0" },
            { id: "behavior", label: "Behavior & Hide", icon: "\uf070" },
            { id: "modules", label: "Modules & Layout", icon: "\uf12e" },
            { id: "tray", label: "System Tray", icon: "\uf2db" }
        ]
        onTabSelected: section => root.currentSection = section
    }

    // --- Geometry & Style ---
    ColumnLayout {
        visible: root.currentSection === "geometry"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Bar Geometry & Profile"
            description: "Control positioning, height profiles, and corner curvature."
            iconGlyph: "\uf2d0"

            SettingsRow {
                title: "Bar Position"
                description: "Screen edge where the main panel is anchored."
                iconGlyph: "\uf062"

                SettingsChoice {
                    configKey: "bar.position"
                    options: [
                        { label: "Top Edge", value: "top" },
                        { label: "Bottom Edge", value: "bottom" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Corner Styling"
                description: "Visual relationship with screen corners."
                iconGlyph: "\uf0c8"

                SettingsChoice {
                    configKey: "bar.cornerStyle"
                    options: [
                        { label: "Floating Glass", value: "floating" },
                        { label: "Rounded Strip", value: "rounded" },
                        { label: "Edge-to-Edge", value: "square" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Standard Bar Height"
                description: "Full expanded height in pixels."
                iconGlyph: "\uf07d"

                SettingsSlider {
                    configKey: "bar.height"
                    from: 32
                    to: 64
                    stepSize: 2
                    unit: "px"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Compact Bar Height"
                description: "Height when compact mode is engaged."
                iconGlyph: "\uf07e"

                SettingsSlider {
                    configKey: "bar.compactHeight"
                    from: 28
                    to: 48
                    stepSize: 2
                    unit: "px"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Corner Radius"
                description: "Curvature radius of panel corners."
                iconGlyph: "\uf196"

                SettingsSlider {
                    configKey: "bar.customRounding"
                    from: 0
                    to: 24
                    stepSize: 2
                    unit: "px"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Drop Shadow & Floating Elevation"
                description: "Renders ambient drop shadow under the floating bar."
                iconGlyph: "\uf185"

                SettingsSwitch {
                    configKey: "bar.floatStyleShadow"
                }
            }
        }
    }

    // --- Behavior & Hide ---
    ColumnLayout {
        visible: root.currentSection === "behavior"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Smart Auto-Hide Engine"
            description: "Intelligent auto-hide on window collision or inactivity."
            iconGlyph: "\uf070"

            SettingsRow {
                title: "Enable Bar Auto-Hide"
                description: "Retracts the bar when unhovered or obscured by active windows."
                iconGlyph: "\uf06e"

                SettingsSwitch {
                    configKey: "bar.autoHide"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Auto-Hide Reveal Delay"
                description: "Hover dwell time before revealing the panel."
                iconGlyph: "\uf251"

                SettingsSlider {
                    configKey: "bar.autoHideDelayMs"
                    from: 50
                    to: 800
                    stepSize: 50
                    unit: "ms"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Engage Compact Mode"
                description: "Forces slim compact mode profile permanently."
                iconGlyph: "\uf066"

                SettingsSwitch {
                    configKey: "bar.compactMode"
                }
            }
        }
    }

    // --- Modules & Layout ---
    ColumnLayout {
        visible: root.currentSection === "modules"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Center Bar Modules"
            description: "Modules positioned in the central dynamic island cluster."
            iconGlyph: "\uf12e"

            SettingsRow {
                title: "Clock & Date Capsule"
                description: "Central time, date, and calendar quick-toggle."
                iconGlyph: "\uf017"

                SettingsSwitch {
                    configKey: "bar.showCenterClock"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Media Player Island"
                description: "Active MPRIS playback title, artist, and track progress."
                iconGlyph: "\uf001"

                SettingsSwitch {
                    configKey: "bar.showCenterMedia"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Weather Capsule"
                description: "Live weather conditions, temperature, and forecast popup."
                iconGlyph: "\uf185"

                SettingsSwitch {
                    configKey: "bar.showCenterWeather"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Notification Hub"
                description: "Bell badge counter and notification center drawer."
                iconGlyph: "\uf0f3"

                SettingsSwitch {
                    configKey: "bar.showCenterNotifications"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Utility Hub Pill"
                description: "Capture, recording, OCR, and tools quick-launcher."
                iconGlyph: "\uf0ad"

                SettingsSwitch {
                    configKey: "bar.showCenterUtilityHub"
                }
            }
        }

        SettingsCard {
            title: "Right Bar Modules"
            description: "Hardware monitors, status tiles, and session control."
            iconGlyph: "\uf109"

            SettingsRow {
                title: "Hardware Monitors Cluster"
                description: "Live CPU load, memory usage, and Nix package monitor."
                iconGlyph: "\uf080"

                SettingsSwitch {
                    configKey: "bar.showHardwareMonitors"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Clipboard History Tile"
                description: "Quick-access tile for cliphist clipboard manager."
                iconGlyph: "\uf0ea"

                SettingsSwitch {
                    configKey: "bar.showClipboardTile"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Privacy Indicator"
                description: "Camera and microphone active usage indicator."
                iconGlyph: "\uf023"

                SettingsSwitch {
                    configKey: "bar.showPrivacyIndicator"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Power & Session Tile"
                description: "Session popup toggle for lock, suspend, reboot, and power-off."
                iconGlyph: "\uf011"

                SettingsSwitch {
                    configKey: "bar.showSessionButton"
                }
            }
        }
    }

    // --- System Tray ---
    ColumnLayout {
        visible: root.currentSection === "tray"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "StatusNotifier System Tray"
            description: "Background application indicators and tray icons."
            iconGlyph: "\uf2db"

            SettingsRow {
                title: "Show System Tray"
                description: "Enable the StatusNotifierItem (SNI) tray cluster."
                iconGlyph: "\uf06e"

                SettingsSwitch {
                    configKey: "bar.showSystemTray"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Monochrome Tray Icons"
                description: "Desaturates third-party tray icons to fit shell aesthetics."
                iconGlyph: "\uf042"

                SettingsSwitch {
                    configKey: "bar.trayMonochromeIcons"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Filter Passive Tray Items"
                description: "Hides items with 'Passive' status until activated."
                iconGlyph: "\uf0b0"

                SettingsSwitch {
                    configKey: "bar.trayFilterPassive"
                }
            }
        }
    }
}
