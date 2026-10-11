import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../widgets"
import "../"

ColumnLayout {
    id: root

    spacing: DesignTokens.spacingLG
    Layout.fillWidth: true

    property string currentSection: "colors"

    SettingsSubnav {
        activeTab: root.currentSection
        tabs: [
            { id: "colors", label: "Colors & Palettes", icon: "\uf53f" },
            { id: "typography", label: "Typography & Scaling", icon: "\uf031" },
            { id: "motion", label: "Motion & Physics", icon: "\uf0e4" }
        ]
        onTabSelected: section => root.currentSection = section
    }

    // --- Colors & Palettes ---
    ColumnLayout {
        visible: root.currentSection === "colors"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Material You & Matugen Palette"
            description: "Dynamic color harmony generator derived from your wallpaper."
            iconGlyph: "\uf53f"

            SettingsRow {
                title: "Color Generation Scheme"
                description: "Matugen color harmony model."
                iconGlyph: "\uf1fc"

                SettingsChoice {
                    configKey: "quick.colorScheme"
                    options: [
                        { label: "Tonal Spot", value: "tonal_spot" },
                        { label: "Vibrant", value: "vibrant" },
                        { label: "Expressive", value: "expressive" },
                        { label: "Fruit Salad", value: "fruit_salad" },
                        { label: "Monochrome", value: "monochrome" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Accent Color Override"
                description: "Choose a custom primary color or use wallpaper extraction."
                iconGlyph: "\uf043"

                SettingsColorPicker {
                    configKey: "appearance.accentColor"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Color Theme Dialect"
                description: "Visual design language across shell surfaces."
                iconGlyph: "\uf0c8"

                SettingsChoice {
                    configKey: "appearance.globalStyle"
                    options: [
                        { label: "Material You", value: "material" },
                        { label: "Aero Glass", value: "glass" },
                        { label: "Cyberpunk", value: "cyber" },
                        { label: "Minimalist", value: "minimal" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Glass Blur & Transparency"
                description: "Enable backdrop blur filter and glass refraction."
                iconGlyph: "\uf28b"

                SettingsSwitch {
                    configKey: "appearance.glassEffect"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Surface Opacity"
                description: "Opacity of glassmorphic popup backgrounds."
                iconGlyph: "\uf042"

                SettingsSlider {
                    configKey: "appearance.blurOpacity"
                    from: 0.40
                    to: 0.98
                    stepSize: 0.02
                    decimals: 2
                    unit: "alpha"
                }
            }
        }
    }

    // --- Typography & Scaling ---
    ColumnLayout {
        visible: root.currentSection === "typography"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Typefaces & Geometry Scales"
            description: "Fonts, sizes, and border radii across the shell."
            iconGlyph: "\uf031"

            SettingsRow {
                title: "UI Font Family"
                description: "Primary interface font for labels, titles, and menus."
                iconGlyph: "\uf031"

                SettingsTextField {
                    configKey: "appearance.fontUI"
                    placeholderText: "Inter"
                    preferredWidth: 220
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Monospace Font Family"
                description: "Used for system monitors, code snippets, and clock badges."
                iconGlyph: "\uf121"

                SettingsTextField {
                    configKey: "appearance.fontMono"
                    placeholderText: "JetBrainsMono Nerd Font"
                    preferredWidth: 220
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Global UI Font Scale"
                description: "Scales text size proportionally across all panels."
                iconGlyph: "\uf0b2"

                SettingsSlider {
                    configKey: "appearance.fontSizeScale"
                    from: 0.85
                    to: 1.30
                    stepSize: 0.05
                    decimals: 2
                    unit: "x"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Corner Radius Scale"
                description: "Multiplier applied to pill, card, and window rounding."
                iconGlyph: "\uf196"

                SettingsSlider {
                    configKey: "appearance.radiusScale"
                    from: 0.50
                    to: 1.50
                    stepSize: 0.10
                    decimals: 1
                    unit: "x"
                }
            }
        }
    }

    // --- Motion & Physics ---
    ColumnLayout {
        visible: root.currentSection === "motion"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Spring Physics Engine"
            description: "Configure spring animations, stiffness, and overshoot damping."
            iconGlyph: "\uf0e4"

            SettingsRow {
                title: "Motion Profile Preset"
                description: "Preset personality for widget transitions."
                iconGlyph: "\uf135"

                SettingsChoice {
                    configKey: "appearance.motionProfile"
                    options: [
                        { label: "Snappy", value: "snappy" },
                        { label: "Bouncy", value: "bouncy" },
                        { label: "Smooth", value: "smooth" },
                        { label: "Linear", value: "linear" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Spring Stiffness (k)"
                description: "Spring force constant (higher = faster pop)."
                iconGlyph: "\uf021"

                SettingsSlider {
                    configKey: "appearance.springStiffness"
                    from: 2.0
                    to: 12.0
                    stepSize: 0.5
                    decimals: 1
                    unit: "stiff"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Damping Ratio (zeta)"
                description: "Overshoot dissipation (0.7 = critically damped; <0.5 = bouncy)."
                iconGlyph: "\uf068"

                SettingsSlider {
                    configKey: "appearance.springDamping"
                    from: 0.35
                    to: 0.95
                    stepSize: 0.05
                    decimals: 2
                    unit: "zeta"
                }
            }
        }
    }
}
