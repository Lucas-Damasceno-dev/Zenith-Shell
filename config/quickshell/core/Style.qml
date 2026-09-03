pragma Singleton
import QtQuick
/**
 * Style - Unified design system singleton.
 *
 * Single import point that exposes:
 *  - Typography constants (renderType, fontFamily, sizes, hinting)
 *  - Spring animation presets (use as: spring: Style.springDefault; damping: Style.dampingDefault)
 *  - Color aliases pointing to ColorScheme + DesignTokens backend
 *
 * Components that use Style only need ONE import instead of two singletons.
 *
 * Example:
 *   Text {
 *       font.family:  Style.fontUI
 *       font.pixelSize: Style.fontSizeMD
 *       renderType:   Text.NativeRendering
 *       color:        Style.primary
 *   }
 */
QtObject {
    id: style

    // ── Typography ──────────────────────────────────────────────────────
    // NativeRendering avoids subpixel hinting artifacts on Wayland (no subpixel AA).
    readonly property int renderType:         Text.NativeRendering
    readonly property int hintingPreference:  Font.PreferFullHinting

    readonly property string fontUI:   "Inter"
    readonly property string fontMono: "JetBrainsMono Nerd Font"

    readonly property int iconSizeXS: DesignTokens.iconSizeXS
    readonly property int iconSizeSM: DesignTokens.iconSizeSM
    readonly property int iconSizeMD: DesignTokens.iconSizeMD
    readonly property int iconSizeLG: DesignTokens.iconSizeLG
    readonly property int iconSizeXL: DesignTokens.iconSizeXL

    // Fluid type scale (px)
    readonly property int fontSizeXS: 9
    readonly property int fontSizeSM: 11
    readonly property int fontSizeMD: 13
    readonly property int fontSizeLG: 15
    readonly property int fontSizeXL: 18
    readonly property int fontSizeHeading: 20

    // ── Spring Presets ──────────────────────────────────────────────────
    // Use inside: Behavior { SpringAnimation { spring: Style.springDefault; damping: Style.dampingDefault } }
    readonly property real springDefault: 4.0    // smooth, generic transitions
    readonly property real springBouncy:  7.0    // bouncy widget pops
    readonly property real springSnappy:  9.0    // micro-interactions (press feedback)

    readonly property real dampingDefault: 0.70  // critically damped
    readonly property real dampingBouncy:  0.45  // underdamped, bouncy
    readonly property real dampingSnappy:  0.50  // slightly underdamped

    // ── Color aliases ───────────────────────────────────────────────────
    // All backed by ColorScheme — changes here when matugen palette reloads.
    readonly property color primary:          ColorScheme.accent
    readonly property color onPrimary:        ColorScheme.onPrimary
    readonly property color surface:          ColorScheme.surface
    readonly property color surfaceContainer: ColorScheme.surfaceContainer
    readonly property color outline:          ColorScheme.glassBorder
    readonly property color outlineVariant:   ColorScheme.outlineVariant
    readonly property color foreground:       ColorScheme.foreground
    readonly property color muted:            ColorScheme.withAlpha(ColorScheme.foreground, 0.55)
    readonly property color dim:              ColorScheme.withAlpha(ColorScheme.foreground, 0.35)
    readonly property color textSecondary:    ColorScheme.textSecondary
    readonly property color textTertiary:     ColorScheme.textTertiary
    readonly property color textDisabled:     ColorScheme.textDisabled
    readonly property color scrim:            ColorScheme.scrim
    readonly property color error:            ColorScheme.red
    readonly property color warning:          ColorScheme.yellow
    readonly property color success:          ColorScheme.green
    readonly property color info:             ColorScheme.blue

    // Convenience: semi-transparent versions of primary for backgrounds
    readonly property color primaryContainer:  ColorScheme.withAlpha(ColorScheme.accent, 0.16)
    readonly property color primarySubtle:     ColorScheme.withAlpha(ColorScheme.accent, 0.08)

    // ── Font Weights ────────────────────────────────────────────────────
    readonly property int fontWeightRegular:  DesignTokens.fontWeightRegular
    readonly property int fontWeightMedium:   DesignTokens.fontWeightMedium
    readonly property int fontWeightSemiBold: DesignTokens.fontWeightSemiBold
    readonly property int fontWeightBold:     DesignTokens.fontWeightBold

    // ── Extended Type Scale ─────────────────────────────────────────────
    readonly property int fontSizeXXL:  DesignTokens.fontSizeXXL
    readonly property int fontSizeHero: DesignTokens.fontSizeHero

    // ── Line Heights ────────────────────────────────────────────────────
    readonly property real lineHeightTight:   DesignTokens.lineHeightTight
    readonly property real lineHeightNormal:  DesignTokens.lineHeightNormal
    readonly property real lineHeightRelaxed: DesignTokens.lineHeightRelaxed

    // ── Letter Spacing ──────────────────────────────────────────────────
    readonly property real letterSpacingLabel:   DesignTokens.letterSpacingLabel
    readonly property real letterSpacingHeading: DesignTokens.letterSpacingHeading
    readonly property real letterSpacingTimer:   DesignTokens.letterSpacingTimer
    readonly property real letterSpacingBadge:   DesignTokens.letterSpacingBadge
    readonly property real letterSpacingCaps:    DesignTokens.letterSpacingCaps

    // ── Elevation Surfaces ──────────────────────────────────────────────
    readonly property color surfaceLow:  ColorScheme.surfaceLow
    readonly property color surfaceMid:  ColorScheme.surfaceMid
    readonly property color surfaceHigh: ColorScheme.surfaceHigh

    // ── Glass Depth Aliases ─────────────────────────────────────────────
    readonly property color glassBar:   ColorScheme.glassBar
    readonly property color glassDock:  ColorScheme.glassDock
    readonly property color glassCard:  ColorScheme.glassCard
    readonly property color glassPopup: ColorScheme.glassPopup
    readonly property color glassModal: ColorScheme.glassModal
    readonly property color glassBackdropTint: ColorScheme.withAlpha(ColorScheme.accent, DesignTokens.backdropTintOpacity)
    readonly property color glassBackdropGlow: ColorScheme.withAlpha(ColorScheme.accentAlt, DesignTokens.backdropGlowOpacity * 0.18)
    readonly property color glassBackdropVignette: ColorScheme.withAlpha(ColorScheme.background, DesignTokens.backdropVignetteOpacity)

    // ── State Colors ────────────────────────────────────────────────────
    readonly property color stateSelected:    ColorScheme.stateSelected
    readonly property color stateHover:       ColorScheme.stateHover
    readonly property color statePressed:     ColorScheme.statePressed
    readonly property color stateDisabled:    ColorScheme.stateDisabled
    readonly property color stateLoading:     ColorScheme.stateLoading
    readonly property color stateDestructive: ColorScheme.stateDestructive
    readonly property color stateSuccess:     ColorScheme.stateSuccess
    readonly property color stateWarning:     ColorScheme.stateWarning

    // ── Gradient Stops ──────────────────────────────────────────────────
    readonly property color accentGradientStart:  ColorScheme.accentGradientStart
    readonly property color accentGradientEnd:    ColorScheme.accentGradientEnd
    readonly property color successGradientStart: ColorScheme.successGradientStart
    readonly property color successGradientEnd:   ColorScheme.successGradientEnd
    readonly property color warningGradientStart: ColorScheme.warningGradientStart
    readonly property color warningGradientEnd:   ColorScheme.warningGradientEnd
    readonly property color dangerGradientStart:  ColorScheme.dangerGradientStart
    readonly property color dangerGradientEnd:    ColorScheme.dangerGradientEnd

    // ── Destructive alias ───────────────────────────────────────────────
    readonly property color destructive: ColorScheme.red
}
