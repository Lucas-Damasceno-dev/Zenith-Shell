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
        title: "Hyprland Tiling & Gaps"
        description: "Window tiling geometry, inner/outer gaps, and border boundaries."
        iconGlyph: "\uf108"

        SettingsRow {
            title: "Tiling Algorithm Layout"
            description: "Default window placement algorithm."
            iconGlyph: "\uf009"

            SettingsChoice {
                configKey: "compositor.layout"
                options: [
                    { label: "Dwindle (Fibonacci)", value: "dwindle" },
                    { label: "Master & Stack", value: "master" }
                ]
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Inner Gaps (Between Windows)"
            description: "Spacing in pixels between adjacent tiled windows."
            iconGlyph: "\uf07e"

            SettingsSlider {
                configKey: "compositor.gapsIn"
                from: 0
                to: 24
                stepSize: 1
                unit: "px"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Outer Gaps (Screen Edge)"
            description: "Spacing in pixels between windows and monitor screen edges."
            iconGlyph: "\uf065"

            SettingsSlider {
                configKey: "compositor.gapsOut"
                from: 0
                to: 40
                stepSize: 2
                unit: "px"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Window Border Thickness"
            description: "Width of window outline border."
            iconGlyph: "\uf0c8"

            SettingsSlider {
                configKey: "compositor.borderSize"
                from: 0
                to: 6
                stepSize: 1
                unit: "px"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Active Window Border Color"
            description: "Border highlight color of the currently focused window."
            iconGlyph: "\uf53f"

            SettingsColorPicker {
                configKey: "compositor.activeBorderColor"
            }
        }
    }

    SettingsCard {
        title: "Input Devices & Cursor"
        description: "Pointer speed, touchpad gestures, and natural scrolling."
        iconGlyph: "\uf245"

        SettingsRow {
            title: "Cursor Sensitivity / Speed"
            description: "Pointer acceleration multiplier."
            iconGlyph: "\uf047"

            SettingsSlider {
                configKey: "compositor.cursorSensitivity"
                from: 0.2
                to: 2.0
                stepSize: 0.1
                decimals: 1
                unit: "speed"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Touchpad Natural Scrolling"
            description: "Reverse touchpad scroll direction to mirror finger movement."
            iconGlyph: "\uf0dc"

            SettingsSwitch {
                configKey: "compositor.touchpadNaturalScroll"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Touchpad Tap-to-Click"
            description: "Simulate left click when tapping the touchpad surface."
            iconGlyph: "\uf25a"

            SettingsSwitch {
                configKey: "compositor.touchpadTapToClick"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Compositor Animation Profile"
            description: "Hyprland window animation curve profile."
            iconGlyph: "\uf135"

            SettingsChoice {
                configKey: "compositor.animationSpeed"
                options: [
                    { label: "Snappy", value: "snappy" },
                    { label: "Smooth", value: "smooth" },
                    { label: "Disabled", value: "none" }
                ]
            }
        }
    }
}
