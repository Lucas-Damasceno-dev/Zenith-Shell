import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../widgets"
import "../"

ColumnLayout {
    id: root

    spacing: DesignTokens.spacingLG
    Layout.fillWidth: true

    property string currentSection: "overview"

    SettingsSubnav {
        activeTab: root.currentSection
        tabs: [
            { id: "overview", label: "Overview & Exposé", icon: "\uf009" },
            { id: "hotcorners", label: "Hot Corners", icon: "\uf247" },
            { id: "strip", label: "Workspace Strip", icon: "\uf0db" }
        ]
        onTabSelected: section => root.currentSection = section
    }

    // --- Overview & Exposé ---
    ColumnLayout {
        visible: root.currentSection === "overview"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Window Overview & Exposé Grid"
            description: "Full-screen spatial switcher for workspaces and active windows."
            iconGlyph: "\uf009"

            SettingsRow {
                title: "Grid Columns"
                description: "Number of columns in the overview workspace matrix."
                iconGlyph: "\uf0db"

                SettingsSlider {
                    configKey: "panels.overviewColumns"
                    from: 2
                    to: 6
                    stepSize: 1
                    unit: "cols"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Grid Rows"
                description: "Number of rows in the overview workspace matrix."
                iconGlyph: "\uf0c9"

                SettingsSlider {
                    configKey: "panels.overviewRows"
                    from: 1
                    to: 4
                    stepSize: 1
                    unit: "rows"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Exposé Tile Scale"
                description: "Thumbnail scale relative to actual window bounds."
                iconGlyph: "\uf065"

                SettingsSlider {
                    configKey: "panels.exposeScale"
                    from: 0.60
                    to: 0.95
                    stepSize: 0.05
                    decimals: 2
                    unit: "scale"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Backdrop Blur"
                description: "Blurs desktop background behind overview thumbnails."
                iconGlyph: "\uf28b"

                SettingsSwitch {
                    configKey: "panels.overviewBlur"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Backdrop Dim Opacity"
                description: "Darkens background for visual contrast."
                iconGlyph: "\uf042"

                SettingsSlider {
                    configKey: "panels.overviewDim"
                    from: 0.10
                    to: 0.80
                    stepSize: 0.05
                    decimals: 2
                    unit: "dim"
                }
            }
        }
    }

    // --- Hot Corners ---
    ColumnLayout {
        visible: root.currentSection === "hotcorners"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Interactive Hot Corners"
            description: "Move mouse pointer into display corners to trigger shell views."
            iconGlyph: "\uf247"

            SettingsRow {
                title: "Enable Hot Corners"
                description: "Activates corner mouse hit-boxes."
                iconGlyph: "\uf205"

                SettingsSwitch {
                    configKey: "panels.hotCornersEnable"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Top-Left Corner Action"
                description: "Triggered on top-left dwell."
                iconGlyph: "\uf148"

                SettingsChoice {
                    configKey: "panels.hotCornerTopLeft"
                    options: [
                        { label: "Overview", value: "overview" },
                        { label: "Dashboard", value: "dashboard" },
                        { label: "Launcher", value: "launcher" },
                        { label: "None", value: "none" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Top-Right Corner Action"
                description: "Triggered on top-right dwell."
                iconGlyph: "\uf149"

                SettingsChoice {
                    configKey: "panels.hotCornerTopRight"
                    options: [
                        { label: "Dashboard", value: "dashboard" },
                        { label: "Overview", value: "overview" },
                        { label: "Session", value: "session" },
                        { label: "None", value: "none" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Corner Dwell Time"
                description: "Milliseconds pointer must rest in corner before firing."
                iconGlyph: "\uf017"

                SettingsSlider {
                    configKey: "panels.hotCornerDwellMs"
                    from: 50
                    to: 400
                    stepSize: 25
                    unit: "ms"
                }
            }
        }
    }

    // --- Workspace Strip ---
    ColumnLayout {
        visible: root.currentSection === "strip"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Edge Workspace Strip"
            description: "Persistent edge strip for workspace previews and instant switching."
            iconGlyph: "\uf0db"

            SettingsRow {
                title: "Enable Workspace Strip"
                description: "Show vertical workspace strip anchored to screen edge."
                iconGlyph: "\uf205"

                SettingsSwitch {
                    configKey: "panels.workspaceStripEnable"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Anchor Side"
                description: "Display edge for the workspace strip."
                iconGlyph: "\uf061"

                SettingsChoice {
                    configKey: "panels.workspaceStripSide"
                    options: [
                        { label: "Right Edge", value: "right" },
                        { label: "Left Edge", value: "left" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Panel Width"
                description: "Width of preview strip when expanded."
                iconGlyph: "\uf07e"

                SettingsSlider {
                    configKey: "panels.workspaceStripWidth"
                    from: 300
                    to: 600
                    stepSize: 20
                    unit: "px"
                }
            }
        }
    }
}
