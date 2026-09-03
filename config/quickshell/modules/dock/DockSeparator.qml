import QtQuick
import "../../core"

Rectangle {
    property real separatorHeight: 24
    property real magnification: 1.0
    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion
    
    width: 1
    Behavior on width {
        enabled: !reducedEffects
        SpringAnimation { spring: 4.5; damping: 0.6 }
    }
    
    height: separatorHeight
    color: ColorScheme.withAlpha(ColorScheme.overlay, 0.18)
    radius: 1
    opacity: 0.8
    Behavior on opacity {
        enabled: !reducedEffects
        NumberAnimation { duration: DesignTokens.durationNormal }
    }
}
