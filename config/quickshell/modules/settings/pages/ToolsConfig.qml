import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../widgets"
import "../"

ColumnLayout {
    id: root

    spacing: DesignTokens.spacingLG
    Layout.fillWidth: true

    property string currentSection: "recorder"

    SettingsSubnav {
        activeTab: root.currentSection
        tabs: [
            { id: "recorder", label: "Screen Recording", icon: "\uf03d" },
            { id: "screenshot", label: "Screenshot & OCR", icon: "\uf030" },
            { id: "gaming", label: "Gaming Overlay", icon: "\uf11b" }
        ]
        onTabSelected: section => root.currentSection = section
    }

    // --- Screen Recording ---
    ColumnLayout {
        visible: root.currentSection === "recorder"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "wf-recorder & Screen Capture"
            description: "Hardware-accelerated screen recording formats and bitrates."
            iconGlyph: "\uf03d"

            SettingsRow {
                title: "Frame Rate (FPS)"
                description: "Target capture frame rate."
                iconGlyph: "\uf0e4"

                SettingsChoice {
                    configKey: "tools.screenRecordFps"
                    options: [
                        { label: "30 FPS", value: 30 },
                        { label: "60 FPS", value: 60 },
                        { label: "120 FPS", value: 120 }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Video Codec"
                description: "Encoding compression algorithm."
                iconGlyph: "\uf1c8"

                SettingsChoice {
                    configKey: "tools.screenRecordVideoCodec"
                    options: [
                        { label: "H.264 (libx264)", value: "libx264" },
                        { label: "HEVC (libx265)", value: "libx265" },
                        { label: "VP9 (libvpx)", value: "libvpx-vp9" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Audio Source"
                description: "Audio streams bundled into recording."
                iconGlyph: "\uf130"

                SettingsChoice {
                    configKey: "tools.screenRecordAudioSource"
                    options: [
                        { label: "System & Mic", value: "both" },
                        { label: "System Only", value: "system" },
                        { label: "Mic Only", value: "mic" },
                        { label: "Muted", value: "none" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "File Container Format"
                description: "Container format for saved video clips."
                iconGlyph: "\uf15b"

                SettingsChoice {
                    configKey: "tools.screenRecordContainer"
                    options: [
                        { label: "MKV (Matroska)", value: "mkv" },
                        { label: "MP4", value: "mp4" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Recording Save Directory"
                description: "Destination folder for captured video files."
                iconGlyph: "\uf07b"

                SettingsTextField {
                    configKey: "tools.screenRecordSavePath"
                    placeholderText: "~/Videos/Recordings"
                    preferredWidth: 260
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Discord Compression"
                description: "Automatically compress captured clip to fit Discord 10MB/25MB limits."
                iconGlyph: "\uf392"

                SettingsSwitch {
                    configKey: "tools.screenRecordDiscordCompress"
                }
            }
        }
    }

    // --- Screenshot & OCR ---
    ColumnLayout {
        visible: root.currentSection === "screenshot"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Screenshot, OCR & Visual Search"
            description: "Still captures, optical character recognition, and reverse image lens."
            iconGlyph: "\uf030"

            SettingsRow {
                title: "Image Format"
                description: "File format for saved screenshots."
                iconGlyph: "\uf1c5"

                SettingsChoice {
                    configKey: "tools.screenshotFormat"
                    options: [
                        { label: "PNG (Lossless)", value: "png" },
                        { label: "WebP", value: "webp" },
                        { label: "JPEG", value: "jpg" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Default Snip Mode"
                description: "Initial selection mode when capture hotkey is pressed."
                iconGlyph: "\uf125"

                SettingsChoice {
                    configKey: "tools.screenshotMode"
                    options: [
                        { label: "Region Snip", value: "region" },
                        { label: "Window", value: "window" },
                        { label: "Full Screen", value: "full" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Capture Delay"
                description: "Seconds countdown before triggering capture."
                iconGlyph: "\uf017"

                SettingsSlider {
                    configKey: "tools.screenshotDelaySec"
                    from: 0
                    to: 10
                    stepSize: 1
                    unit: "s"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "OCR Language"
                description: "Tesseract optical character recognition language model."
                iconGlyph: "\uf1ab"

                SettingsChoice {
                    configKey: "tools.ocrLanguage"
                    options: [
                        { label: "English", value: "eng" },
                        { label: "Português", value: "por" },
                        { label: "Español", value: "spa" },
                        { label: "Japanese", value: "jpn" }
                    ]
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Visual Search Provider (Lens)"
                description: "Reverse image search engine used when searching snipped area."
                iconGlyph: "\uf002"

                SettingsChoice {
                    configKey: "tools.lensProvider"
                    options: [
                        { label: "Google Lens", value: "google" },
                        { label: "Bing Visual", value: "bing" },
                        { label: "Yandex Image", value: "yandex" }
                    ]
                }
            }
        }
    }

    // --- Gaming Overlay ---
    ColumnLayout {
        visible: root.currentSection === "gaming"
        spacing: DesignTokens.spacingLG
        Layout.fillWidth: true

        SettingsCard {
            title: "Hardware Crosshair Overlay"
            description: "Zero-latency centered reticle overlay for games without crosshairs."
            iconGlyph: "\uf05b"

            SettingsRow {
                title: "Enable Center Crosshair"
                description: "Renders persistent crosshair overlay at exact center of screen."
                iconGlyph: "\uf205"

                SettingsSwitch {
                    configKey: "tools.crosshairEnable"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Crosshair Reticle Color"
                description: "Color hue of crosshair lines."
                iconGlyph: "\uf53f"

                SettingsColorPicker {
                    configKey: "tools.crosshairColor"
                }
            }

            SettingsDivider {}

            SettingsRow {
                title: "Reticle Size"
                description: "Diameter in pixels of the center crosshair."
                iconGlyph: "\uf07d"

                SettingsSlider {
                    configKey: "tools.crosshairSize"
                    from: 8
                    to: 48
                    stepSize: 2
                    unit: "px"
                }
            }
        }
    }
}
