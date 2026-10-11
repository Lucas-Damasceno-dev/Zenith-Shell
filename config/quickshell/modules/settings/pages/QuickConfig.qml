import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../widgets"
import "../"

ColumnLayout {
    id: root

    spacing: DesignTokens.spacingLG
    Layout.fillWidth: true

    SettingsCard {
        title: "Quick Customization"
        description: "Core shell presets, active wallpaper, and overall shell dialect."
        iconGlyph: "\uf0e7"

        SettingsRow {
            title: "Wallpaper Path"
            description: "Direct path to current wallpaper image or video."
            iconGlyph: "\uf03e"

            SettingsTextField {
                configKey: "quick.wallpaperPath"
                placeholderText: "/path/to/wallpaper.png"
                preferredWidth: 320
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Layout Preset"
            description: "Arrangement style of the desktop shell and panels."
            iconGlyph: "\uf009"

            SettingsChoice {
                configKey: "quick.layoutPreset"
                options: [
                    { label: "Default", value: "default" },
                    { label: "Compact", value: "compact" },
                    { label: "Floating", value: "floating" },
                    { label: "Minimal", value: "minimal" }
                ]
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Accent Color"
            description: "Quickly override the dominant accent color."
            iconGlyph: "\uf53f"

            SettingsColorPicker {
                configKey: "quick.accentColor"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Matugen Color Scheme"
            description: "Color generation algorithm derived from wallpaper."
            iconGlyph: "\uf1fc"

            SettingsChoice {
                configKey: "quick.colorScheme"
                options: [
                    { label: "Tonal Spot", value: "tonal_spot" },
                    { label: "Vibrant", value: "vibrant" },
                    { label: "Expressive", value: "expressive" },
                    { label: "Monochrome", value: "monochrome" }
                ]
            }
        }
    }

    SettingsCard {
        title: "Quick Shell Toggles"
        description: "Instant master overrides for behavior, animations, and privacy."
        iconGlyph: "\uf205"

        SettingsRow {
            title: "Bar Auto-Hide"
            description: "Automatically hide top bar when windows are maximized or not hovered."
            iconGlyph: "\uf070"

            SettingsSwitch {
                configKey: "bar.autoHide"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Compact Bar Mode"
            description: "Slim 36px bar profile with reduced padding."
            iconGlyph: "\uf066"

            SettingsSwitch {
                configKey: "bar.compactMode"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Reduced Motion"
            description: "Disables spring physics and spring bounces for maximum speed."
            iconGlyph: "\uf0e4"

            SettingsSwitch {
                configKey: "quick.reducedMotion"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Privacy Mode"
            description: "Anonymize sensitive media titles, notifications, and network SSIDs."
            iconGlyph: "\uf023"

            SettingsSwitch {
                configKey: "quick.privacyMode"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Focus Mode (Do Not Disturb)"
            description: "Silences notifications, hides distractions, and pins productivity."
            iconGlyph: "\uf1ea"

            SettingsSwitch {
                configKey: "quick.focusMode"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Low Power UI Mode"
            description: "Throttles background refresh rates, disables audio visualizers and blur."
            iconGlyph: "\uf242"

            SettingsSwitch {
                configKey: "quick.lowPowerMode"
            }
        }
    }
}
