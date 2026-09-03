import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../core"

Item {
    id: root

    property string iconSource: ""
    property color iconColor: ColorScheme.text
    property real size: 24
    property real sourceSize: size * 2
    property string fallbackGlyph: ""

    readonly property int status: smartIcon.status

    width: size
    height: size

    SmartIcon {
        id: smartIcon
        anchors.fill: parent
        source: root.iconSource
        size: root.size
        sourceSize: root.sourceSize
        color: root.iconColor
        colorOverlay: true
        fallbackIcon: root.fallbackGlyph
    }
}
