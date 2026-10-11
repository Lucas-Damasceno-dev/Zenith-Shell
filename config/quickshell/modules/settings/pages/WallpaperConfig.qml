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
        title: "Wallpaper Engine & Source"
        description: "Rendering backend, active background image, and slideshow cycles."
        iconGlyph: "\uf03e"

        SettingsRow {
            title: "Wallpaper Backend"
            description: "Compositor engine used to paint wallpapers onto Wayland layers."
            iconGlyph: "\uf108"

            SettingsChoice {
                configKey: "wallpaper.backend"
                options: [
                    { label: "swww", value: "swww" },
                    { label: "hyprpaper", value: "hyprpaper" },
                    { label: "mpvpaper", value: "mpvpaper" },
                    { label: "swaybg", value: "swaybg" }
                ]
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Wallpaper File Path"
            description: "Direct path to an image file or video loop."
            iconGlyph: "\uf15b"

            SettingsTextField {
                configKey: "wallpaper.wallpaperPath"
                placeholderText: "/home/user/Pictures/wallpapers/neon.png"
                preferredWidth: 320
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Automatic Slideshow"
            description: "Cycles through pictures in your wallpaper folder periodically."
            iconGlyph: "\uf021"

            SettingsSwitch {
                configKey: "wallpaper.slideshow"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Slideshow Interval"
            description: "Minutes elapsed before selecting the next wallpaper."
            iconGlyph: "\uf017"

            SettingsSlider {
                configKey: "wallpaper.slideshowIntervalMin"
                from: 5
                to: 120
                stepSize: 5
                unit: "min"
            }
        }
    }

    SettingsCard {
        title: "Visual Effects & Transitions"
        description: "Transition animations, parallax scrolling, and power efficiency."
        iconGlyph: "\uf0d0"

        SettingsRow {
            title: "Transition Effect"
            description: "Transition shader animation applied on wallpaper swap."
            iconGlyph: "\uf149"

            SettingsChoice {
                configKey: "wallpaper.effects"
                options: [
                    { label: "None", value: "none" },
                    { label: "Fade", value: "fade" },
                    { label: "Wipe", value: "wipe" },
                    { label: "Wave", value: "wave" }
                ]
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Pause Animation On Battery"
            description: "Stops live animated wallpapers when running on battery to save power."
            iconGlyph: "\uf242"

            SettingsSwitch {
                configKey: "wallpaper.pauseAnimationOnBattery"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Hide Wallpaper When Fullscreen"
            description: "Unloads wallpaper layers when an application is full screen."
            iconGlyph: "\uf065"

            SettingsSwitch {
                configKey: "wallpaper.hideWhenFullscreen"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Parallax Scrolling"
            description: "Shifts wallpaper horizontally during workspace transitions."
            iconGlyph: "\uf07e"

            SettingsSwitch {
                configKey: "wallpaper.parallax"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Overview Blur Radius"
            description: "Blur intensity applied to wallpaper when overview is invoked."
            iconGlyph: "\uf28b"

            SettingsSlider {
                configKey: "wallpaper.blurRadius"
                from: 0
                to: 32
                stepSize: 2
                unit: "px"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Wallpaper Dim Opacity"
            description: "Subtle dark vignette tint over bright wallpapers."
            iconGlyph: "\uf186"

            SettingsSlider {
                configKey: "wallpaper.dimOpacity"
                from: 0.0
                to: 0.6
                stepSize: 0.05
                decimals: 2
                unit: "opacity"
            }
        }
    }
}
