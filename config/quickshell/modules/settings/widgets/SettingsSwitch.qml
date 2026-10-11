import QtQuick
import "../../../core"
import "../"

Item {
    id: root

    property string configKey: ""
    property bool checked: false
    property bool enabled: true

    signal toggled(bool nextChecked)

    implicitWidth: 44
    implicitHeight: 24

    Component.onCompleted: {
        if (configKey.length > 0 && SettingsConfig.ready) {
            root.checked = SettingsConfig.getBoolean(configKey, root.checked);
        }
    }

    Connections {
        target: SettingsConfig
        function onConfigChanged(path, value) {
            if (path === root.configKey) {
                root.checked = !!value;
            }
        }
        function onLoaded() {
            if (root.configKey.length > 0) {
                root.checked = SettingsConfig.getBoolean(root.configKey, root.checked);
            }
        }
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.surfaceVariant, 0.90)
        border.width: 1
        border.color: root.checked ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.outline, 0.30)

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }

        Rectangle {
            id: thumb
            width: parent.height - 6
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? ColorScheme.onPrimary : ColorScheme.text

            Behavior on x {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: {
            var next = !root.checked;
            root.checked = next;
            if (root.configKey.length > 0) {
                SettingsConfig.set(root.configKey, next);
            }
            root.toggled(next);
        }
    }
}
