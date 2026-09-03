import QtQuick

AnimatedWindow {
    id: root

    readonly property int popupTopMargin: (FeatureFlags.barCompactMode ? DesignTokens.barCompactHeight : DesignTokens.barExpandedHeight) + DesignTokens.spacingLG

    showScrim: false
    glassRadius: 0
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0
    slideY: 12
    originY: 0.0
    originX: 1.0
}
