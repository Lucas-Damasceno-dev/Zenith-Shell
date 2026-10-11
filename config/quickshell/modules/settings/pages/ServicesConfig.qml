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
        title: "Weather Service"
        description: "Live meteorological forecast engine and location preferences."
        iconGlyph: "\uf185"

        SettingsRow {
            title: "Weather Engine Provider"
            description: "API service used to fetch current temperature and forecast."
            iconGlyph: "\uf0c2"

            SettingsChoice {
                configKey: "services.weatherProvider"
                options: [
                    { label: "Open-Meteo", value: "open-meteo" },
                    { label: "wttr.in", value: "wttr.in" }
                ]
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Custom City / Location"
            description: "Override IP auto-detection with specific city name (e.g. 'Sao Paulo')."
            iconGlyph: "\uf041"

            SettingsTextField {
                configKey: "services.weatherCity"
                placeholderText: "Auto (IP geolocation)"
                preferredWidth: 240
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Measurement Units"
            description: "Temperature and wind speed units."
            iconGlyph: "\uf2c9"

            SettingsChoice {
                configKey: "services.weatherUnits"
                options: [
                    { label: "Metric (°C, km/h)", value: "metric" },
                    { label: "Imperial (°F, mph)", value: "imperial" }
                ]
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Forecast Refresh Interval"
            description: "Minutes between weather background syncs."
            iconGlyph: "\uf021"

            SettingsSlider {
                configKey: "services.weatherRefreshMin"
                from: 15
                to: 120
                stepSize: 15
                unit: "min"
            }
        }
    }

    SettingsCard {
        title: "Media & Audio Visualizer"
        description: "MPRIS media player prioritization and cava audio visualizer."
        iconGlyph: "\uf001"

        SettingsRow {
            title: "Audio Spectrum Visualizer"
            description: "Render live audio waveform frequency visualizer behind the bar."
            iconGlyph: "\uf080"

            SettingsSwitch {
                configKey: "services.mediaSpectrumEnabled"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Preferred Player Filter"
            description: "Prioritize specific MPRIS player (e.g. spotify, firefox, mpv)."
            iconGlyph: "\uf144"

            SettingsTextField {
                configKey: "services.mediaPreferredPlayer"
                placeholderText: "e.g. spotify"
                preferredWidth: 200
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Filter Duplicate Player Instances"
            description: "Ignore secondary browser tab players when primary media is playing."
            iconGlyph: "\uf0b0"

            SettingsSwitch {
                configKey: "services.mediaFilterDuplicates"
            }
        }
    }

    SettingsCard {
        title: "Default System Applications"
        description: "Applications opened when clicking shell shortcuts and tiles."
        iconGlyph: "\uf108"

        SettingsRow {
            title: "Terminal Emulator"
            description: "Default terminal binary."
            iconGlyph: "\uf120"

            SettingsTextField {
                configKey: "services.appTerminal"
                placeholderText: "kitty"
                preferredWidth: 160
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Web Browser"
            description: "Default browser executable."
            iconGlyph: "\uf269"

            SettingsTextField {
                configKey: "services.appBrowser"
                placeholderText: "firefox"
                preferredWidth: 160
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "File Manager"
            description: "Graphical file explorer."
            iconGlyph: "\uf07b"

            SettingsTextField {
                configKey: "services.appFileManager"
                placeholderText: "thunar"
                preferredWidth: 160
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Code / Text Editor"
            description: "Text or IDE editor for quick notes and config editing."
            iconGlyph: "\uf121"

            SettingsTextField {
                configKey: "services.appEditor"
                placeholderText: "codium"
                preferredWidth: 160
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Task Manager"
            description: "System monitor command (e.g. btop, htop)."
            iconGlyph: "\uf201"

            SettingsTextField {
                configKey: "services.appTaskManager"
                placeholderText: "btop"
                preferredWidth: 160
            }
        }
    }
}
