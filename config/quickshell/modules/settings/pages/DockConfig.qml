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
        title: "Dock Geometry & Placement"
        description: "Application launcher dock styling, dimensions, and positioning."
        iconGlyph: "\uf2d2"

        SettingsRow {
            title: "Enable Application Dock"
            description: "Show floating dock on configured displays."
            iconGlyph: "\uf205"

            SettingsSwitch {
                configKey: "dock.enable"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Dock Position"
            description: "Screen edge where dock is anchored."
            iconGlyph: "\uf063"

            SettingsChoice {
                configKey: "dock.position"
                options: [
                    { label: "Bottom", value: "bottom" },
                    { label: "Left", value: "left" },
                    { label: "Right", value: "right" }
                ]
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Dock Panel Height"
            description: "Overall height of the dock pill."
            iconGlyph: "\uf07d"

            SettingsSlider {
                configKey: "dock.height"
                from: 40
                to: 72
                stepSize: 2
                unit: "px"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Application Icon Size"
            description: "Dimensions of pinned and active application icons."
            iconGlyph: "\uf03e"

            SettingsSlider {
                configKey: "dock.iconSize"
                from: 24
                to: 56
                stepSize: 2
                unit: "px"
            }
        }
    }

    SettingsCard {
        title: "Behavior & Reveal Triggers"
        description: "Auto-hide behavior and cursor hit detection."
        iconGlyph: "\uf06e"

        SettingsRow {
            title: "Hover To Reveal (Intelligent Auto-Hide)"
            description: "Hides dock until cursor approaches the screen edge."
            iconGlyph: "\uf245"

            SettingsSwitch {
                configKey: "dock.hoverToReveal"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Hover Hitbox Thickness"
            description: "Depth of invisible hover detection zone along screen edge."
            iconGlyph: "\uf07d"

            SettingsSlider {
                configKey: "dock.hoverRegionHeight"
                from: 2
                to: 16
                stepSize: 2
                unit: "px"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Aero Blur Glass"
            description: "Glassmorphism blur filter behind dock icons."
            iconGlyph: "\uf28b"

            SettingsSwitch {
                configKey: "dock.enableBlurGlass"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Monochrome App Icons"
            description: "Applies unified theme tinting to third-party app icons."
            iconGlyph: "\uf042"

            SettingsSwitch {
                configKey: "dock.monochromeIcons"
            }
        }
    }

    SettingsCard {
        title: "Integrated Dock Utilities"
        description: "Extra accessory modules pinned to the dock."
        iconGlyph: "\uf0ad"

        SettingsRow {
            title: "Media Player Control Pill"
            description: "Inline play/pause button and track thumbnail on dock."
            iconGlyph: "\uf001"

            SettingsSwitch {
                configKey: "dock.showMpris"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Scratchpad Drop Target"
            description: "Special workspace drop area for minimized utility windows."
            iconGlyph: "\uf24d"

            SettingsSwitch {
                configKey: "dock.showScratchpad"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Trash Can Icon"
            description: "Direct trash bin shortcut with item counter and drag-to-delete."
            iconGlyph: "\uf1f8"

            SettingsSwitch {
                configKey: "dock.showTrash"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Recent Files Drawer"
            description: "Quick-access stack for recently opened documents and downloads."
            iconGlyph: "\uf15c"

            SettingsSwitch {
                configKey: "dock.showRecentFiles"
            }
        }
    }
}
