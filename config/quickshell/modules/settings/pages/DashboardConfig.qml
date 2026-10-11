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
        title: "Dashboard Overview & Hub"
        description: "Welcome overview hub panel with daily briefing, tasks, and system gauges."
        iconGlyph: "\uf0e4"

        SettingsRow {
            title: "Enable Dashboard Hub"
            description: "Show centered dashboard overlay when invoked."
            iconGlyph: "\uf205"

            SettingsSwitch {
                configKey: "dashboard.enable"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Header Greeting Message"
            description: "Personalized welcome header banner text."
            iconGlyph: "\uf075"

            SettingsTextField {
                configKey: "dashboard.greetingText"
                placeholderText: "Welcome back"
                preferredWidth: 220
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Show Header Banner"
            description: "Display greeting title, date, and user avatar."
            iconGlyph: "\uf2bd"

            SettingsSwitch {
                configKey: "dashboard.showHeader"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Show Session Power Buttons"
            description: "Quick reboot, lock, and power-off buttons at the top of dashboard."
            iconGlyph: "\uf011"

            SettingsSwitch {
                configKey: "dashboard.showPowerButtons"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Dashboard Width Ratio"
            description: "Width percentage of the screen occupied by dashboard panel."
            iconGlyph: "\uf07e"

            SettingsSlider {
                configKey: "dashboard.widthRatio"
                from: 0.30
                to: 0.70
                stepSize: 0.05
                decimals: 2
                unit: "ratio"
            }
        }
    }

    SettingsCard {
        title: "Active Dashboard Widgets"
        description: "Modular card sections rendered within the dashboard hub."
        iconGlyph: "\uf009"

        SettingsRow {
            title: "Weather Forecast Card"
            description: "Live 3-day temperature and condition forecast."
            iconGlyph: "\uf185"

            SettingsSwitch {
                configKey: "dashboard.showWeatherSection"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Media Player Card"
            description: "Expanded playback album artwork, scrubber, and playback controls."
            iconGlyph: "\uf001"

            SettingsSwitch {
                configKey: "dashboard.showMediaSection"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "System Hardware Gauges"
            description: "Circular dials for CPU, RAM, GPU, and disk metrics."
            iconGlyph: "\uf201"

            SettingsSwitch {
                configKey: "dashboard.showSystemSection"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Sticky Quick Notes"
            description: "Scratchpad note-taking pad persisted directly on the dashboard."
            iconGlyph: "\uf249"

            SettingsSwitch {
                configKey: "dashboard.showQuickNotes"
            }
        }
    }
}
