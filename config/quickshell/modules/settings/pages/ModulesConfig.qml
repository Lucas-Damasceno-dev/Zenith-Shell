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
        title: "Master Shell Modules"
        description: "Granular master activation switches for every panel, overlay, and service."
        iconGlyph: "\uf12e"

        SettingsRow {
            title: "Top Glassmorphic Bar"
            description: "Main status bar anchored to screen edge."
            iconGlyph: "\uf2d0"

            SettingsSwitch {
                configKey: "modules.bar"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Application Dock"
            description: "Pinned apps and active task switcher dock."
            iconGlyph: "\uf2d2"

            SettingsSwitch {
                configKey: "modules.dock"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Application Launcher"
            description: "Full-screen fuzzy app search, calculator, and actions."
            iconGlyph: "\uf002"

            SettingsSwitch {
                configKey: "modules.launcher"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Window Overview & Exposé"
            description: "Visual workspace matrix with interactive window thumbnails."
            iconGlyph: "\uf009"

            SettingsSwitch {
                configKey: "modules.overview"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Dashboard Overview Hub"
            description: "Centralized hub with daily briefing, weather, and quick notes."
            iconGlyph: "\uf0e4"

            SettingsSwitch {
                configKey: "modules.dashboard"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Notification Center & Toasts"
            description: "Desktop notification banners and notification history list."
            iconGlyph: "\uf0f3"

            SettingsSwitch {
                configKey: "modules.notifications"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "On-Screen Display (OSD)"
            description: "Volume, brightness, mic, and power profile feedback HUDs."
            iconGlyph: "\uf26c"

            SettingsSwitch {
                configKey: "modules.osd"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "CheatSheet Shortcut Overlay"
            description: "Quick keybinding reference cards for Hyprland, Tmux, and Neovim."
            iconGlyph: "\uf11c"

            SettingsSwitch {
                configKey: "modules.cheatsheet"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Hardware System Monitor"
            description: "Process manager and real-time CPU/RAM/Network diagnostics."
            iconGlyph: "\uf201"

            SettingsSwitch {
                configKey: "modules.systemMonitor"
            }
        }
    }
}
