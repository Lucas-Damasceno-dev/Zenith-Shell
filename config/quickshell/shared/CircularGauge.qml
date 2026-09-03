import QtQuick
import QtQuick.Shapes
import Quickshell
import "../core"

Item {
    id: root
    property real size: 32
    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    property real strokeWidth: Math.max(2.0, root.size * 0.09375)
    property real usage: 0.0        // raw 0..1 input
    property string iconName: "cpu"
    property string iconGlyph: ""
    property color activeColor: ColorScheme.accent
    property color inactiveColor: ColorScheme.withAlpha(ColorScheme.text, 0.12)

    // ─── Smoothed value drives the arc — avoids jumpy re-render ──
    property real _smoothed: 0.0
    Behavior on _smoothed {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    onUsageChanged: _smoothed = usage

    // Clamped arc value: 0.9995 max to prevent a degenerate arc where start==end
    // at exactly 100% (PathArc from (cx,top) to (cx,top) renders nothing).
    readonly property real _arcVal: Math.min(Math.max(0.0001, _smoothed), 0.9995)

    // Dynamic geometric calculations based on size and strokeWidth
    readonly property real _center: root.size / 2
    readonly property real _radius: Math.max(1.0, (root.size - root.strokeWidth) / 2)
    readonly property real _topY: root._center - root._radius
    readonly property real _bottomY: root._center + root._radius
    readonly property real iconSize: Math.max(8, Math.round(root.size * 0.44))

    // ─── Arc color: red when > 90%, peach when > 70%, accent otherwise ─────────────
    readonly property color arcColor: _smoothed > 0.9 ? ColorScheme.red
                                    : _smoothed > 0.7 ? ColorScheme.peach
                                    : root.activeColor
    property color _arcColorSmoothed: arcColor
    Behavior on _arcColorSmoothed { ColorAnimation { duration: 300 } }
    onArcColorChanged: _arcColorSmoothed = arcColor

    Shape {
        anchors.fill: parent
        antialiasing: true

        // Background arc
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.inactiveColor
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap
            startX: root._center; startY: root._topY
            PathArc { x: root._center; y: root._bottomY; radiusX: root._radius; radiusY: root._radius; useLargeArc: true }
            PathArc { x: root._center; y: root._topY; radiusX: root._radius; radiusY: root._radius; useLargeArc: true }
        }

        // Progress arc driven by _arcVal (clamped _smoothed)
        ShapePath {
            fillColor: "transparent"
            strokeColor: root._arcColorSmoothed
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap
            startX: root._center; startY: root._topY
            PathArc {
                x: root._center + root._radius * Math.sin(root._arcVal * 2 * Math.PI)
                y: root._center - root._radius * Math.cos(root._arcVal * 2 * Math.PI)
                radiusX: root._radius; radiusY: root._radius
                useLargeArc: root._arcVal > 0.5
            }
        }
    }

    Item {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        visible: root.iconGlyph !== ""

        Text {
            anchors.centerIn: parent
            text: root.iconGlyph
            color: root._smoothed > 0.9 ? ColorScheme.red : ColorScheme.withAlpha(ColorScheme.text, 0.85)
            font.family: DesignTokens.fontFamilyMono
            font.pixelSize: root.iconSize
            renderType: Text.NativeRendering
        }
    }

    DynamicIcon {
        anchors.centerIn: parent
        size: root.iconSize
        iconSource: root.iconName
        iconColor: root._smoothed > 0.9 ? ColorScheme.red : ColorScheme.withAlpha(ColorScheme.text, 0.85)
        visible: root.iconGlyph === ""
    }
}
