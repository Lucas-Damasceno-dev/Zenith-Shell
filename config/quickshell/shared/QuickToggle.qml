import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../core"

Rectangle {
    id: root
    width: 70
    height: 70
    radius: 14
    color: checked
        ? ColorScheme.stateSelected
        : (toggleMouse.containsMouse ? ColorScheme.stateHover : ColorScheme.glassHover)
    border.width: 1
    border.color: checked
        ? ColorScheme.withAlpha(accentColor, DesignTokens.activeBorderOpacity)
        : (toggleMouse.containsMouse
            ? ColorScheme.withAlpha(ColorScheme.foreground, DesignTokens.hoverBorderOpacity)
            : ColorScheme.glassBorder)
    scale: toggleMouse.pressed ? DesignTokens.pressedScale : (toggleMouse.containsMouse ? 1.03 : 1.0)
    
    property bool checked: false
    property string iconSource: ""
    property color accentColor: ColorScheme.accent
    property color iconColor: checked ? ColorScheme.background : ColorScheme.text
    
    signal toggled()

    // Icon Container
    Item {
        width: DesignTokens.iconSizeLG
        height: DesignTokens.iconSizeLG
        anchors.centerIn: parent
        
        Image {
            id: iconImg
            anchors.fill: parent
            source: root.iconSource
            sourceSize.width: DesignTokens.iconSizeLG * 2
            sourceSize.height: DesignTokens.iconSizeLG * 2
            visible: false
            fillMode: Image.PreserveAspectFit
        }
        
        ColorOverlay {
            anchors.fill: iconImg
            source: iconImg
            color: root.iconColor
            
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
    
    MouseArea {
        id: toggleMouse
        anchors.fill: parent
        onClicked: root.toggled()
        cursorShape: Qt.PointingHandCursor
    }
    
    // Animation
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    
    // Hover effect
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: ColorScheme.withAlpha(ColorScheme.text, DesignTokens.innerGlowOpacity)
        opacity: toggleMouse.containsMouse || root.checked ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
}
