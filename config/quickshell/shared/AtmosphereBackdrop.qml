pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import "../core"

Item {
    id: root

    property string source: ""
    property real tintOpacity: DesignTokens.backdropTintOpacity
    property real glowOpacity: DesignTokens.backdropGlowOpacity
    property real noiseOpacity: DesignTokens.backdropNoiseOpacity
    property real vignetteOpacity: DesignTokens.backdropVignetteOpacity
    property bool reducedMotion: FeatureFlags.reducedMotion
    readonly property bool backdropEnabled: !root.reducedMotion && !FeatureFlags.lowPowerUiMode && root.source !== ""

    Image {
        id: sourceImage
        anchors.fill: parent
        source: root.backdropEnabled ? root.source : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: root.backdropEnabled
        visible: false
        sourceSize.width: root.backdropEnabled ? Math.max(96, Math.min(320, Math.max(root.width, root.height))) : 1
        sourceSize.height: root.backdropEnabled ? Math.max(96, Math.min(320, Math.max(root.width, root.height))) : 1
    }

    MultiEffect {
        anchors.fill: parent
        source: sourceImage
        visible: root.backdropEnabled && sourceImage.status === Image.Ready
        blurEnabled: root.backdropEnabled
        blurMax: root.backdropEnabled ? 18 : 0
        blur: root.backdropEnabled ? 1.0 : 0.0
        saturation: 0.42
        brightness: -0.10
        opacity: visible ? 0.65 : 0.0
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Style.glassBackdropGlow }
            GradientStop { position: 0.35; color: Style.glassBackdropTint }
            GradientStop { position: 1.0; color: ColorScheme.withAlpha(ColorScheme.background, 0.04) }
        }
        opacity: 1.0
    }

    Rectangle {
        anchors.fill: parent
        color: ColorScheme.withAlpha(ColorScheme.background, 0.12)
        opacity: 0.65
    }

    Rectangle {
        anchors.fill: parent
        opacity: root.noiseOpacity
        color: ColorScheme.foreground
        visible: true
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: ColorScheme.withAlpha(ColorScheme.background, 0.0) }
            GradientStop { position: 1.0; color: Style.glassBackdropVignette }
        }
    }
}
