import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../widgets"
import "../"

ColumnLayout {
    id: root

    spacing: DesignTokens.spacingLG
    Layout.fillWidth: true

    property var autostartEntries: [
        { id: "hypridle", name: "Hypridle", command: "hypridle", desc: "Wayland idle management daemon (sleep, lock, dim)", enabled: true },
        { id: "swww", name: "Swww Daemon", command: "swww-daemon", desc: "High-performance wallpaper animation daemon", enabled: true },
        { id: "mpris", name: "Playerctl Daemon", command: "playerctld daemon", desc: "MPRIS media player prioritization daemon", enabled: true },
        { id: "polkit", name: "Polkit Agent", command: "/usr/lib/polkit-kde-authentication-agent-1", desc: "Privilege escalation authentication dialog", enabled: true },
        { id: "cliphist", name: "Cliphist Watcher", command: "wl-paste --watch cliphist store", desc: "Clipboard history storage engine", enabled: true }
    ]

    SettingsCard {
        title: "Startup Services & Daemons"
        description: "Background system daemons launched when Zenith-Shell and Hyprland start."
        iconGlyph: "\uf135"

        Repeater {
            model: root.autostartEntries

            delegate: ColumnLayout {
                id: itemCol
                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: DesignTokens.spacingMD

                SettingsRow {
                    title: modelData.name + " (" + modelData.command + ")"
                    description: modelData.desc
                    iconGlyph: "\uf013"

                    SettingsSwitch {
                        checked: modelData.enabled
                        onToggled: isChecked => {
                            modelData.enabled = isChecked;
                        }
                    }
                }

                SettingsDivider {
                    visible: index < root.autostartEntries.length - 1
                }
            }
        }
    }

    SettingsCard {
        title: "Add Custom Autostart Command"
        description: "Run custom scripts, tray applets, or user services on shell login."
        iconGlyph: "\uf067"

        SettingsRow {
            title: "Command or Script Path"
            description: "Bash command executed in the background at startup."
            iconGlyph: "\uf120"

            SettingsTextField {
                id: newCmdInput
                placeholderText: "e.g. syncthing --no-browser"
                preferredWidth: 260
            }
        }

        SettingsRow {
            title: ""
            description: ""

            SettingsButton {
                text: "Add Startup Entry"
                iconGlyph: "\uf067"
                isPrimary: true
                onClicked: {
                    if (newCmdInput.text.trim().length > 0) {
                        var list = root.autostartEntries.slice();
                        list.push({
                            id: "custom_" + Date.now(),
                            name: "Custom Application",
                            command: newCmdInput.text.trim(),
                            desc: "User defined startup command",
                            enabled: true
                        });
                        root.autostartEntries = list;
                        newCmdInput.text = "";
                    }
                }
            }
        }
    }
}
