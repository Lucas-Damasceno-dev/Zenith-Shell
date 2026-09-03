pragma Singleton
import QtQuick

QtObject {
    // ── Spacing (multiples of 4) ───────────────────────────────
    readonly property int spacingXXS: 2
    readonly property int spacingXS:  4
    readonly property int spacingSM:  6
    readonly property int spacingMD:  8
    readonly property int spacingLG:  12
    readonly property int spacingXL:  16
    readonly property int spacingXXL: 24

    // ── Radius ────────────────────────────────────────────────
    readonly property int radiusXS:  4
    readonly property int radiusSM:  8
    readonly property int radiusMD:  12
    readonly property int radiusLG:  16    // pill / main panel
    readonly property int radiusXL:  20

    // ── Animation Durations (ms) ──────────────────────────────
    readonly property int durationInstant: 40
    readonly property int durationFast:    70
    readonly property int durationNormal:  100
    readonly property int durationSlow:    150
    readonly property int durationSlower:  250

    // ── Surface Motion + Atmosphere ───────────────────────────
    readonly property int popupRevealDurationMs:    180
    readonly property int surfaceRevealDurationMs:  150
    readonly property int surfaceTransitionDurationMs: 140
    readonly property real backdropTintOpacity:     0.10
    readonly property real backdropGlowOpacity:     0.78
    readonly property real backdropNoiseOpacity:    0.028
    readonly property real backdropVignetteOpacity: 0.06
    readonly property real cardHoverLift:           0.012
    readonly property real cardHoverGlowOpacity:    0.18

    // ── Easing (use in Behavior { NumberAnimation { easing.type: } }) ──
    readonly property int easingDefault:  Easing.OutQuint
    readonly property int easingBounce:   Easing.OutBack
    readonly property int easingLinear:   Easing.Linear

    // ── Opacity levels ────────────────────────────────────────
    readonly property real disabledOpacity: 0.38
    readonly property real mutedOpacity:    0.55
    readonly property real subtleOpacity:   0.65
    readonly property real dimOpacity:      0.35

    // ── Micro-interaction scales ──────────────────────────────
    readonly property real hoverScale:   1.08
    readonly property real pressedScale: 0.94
    readonly property real activeScale:  1.15

    // ── Bar sizing ────────────────────────────────────────────
    readonly property int barItemHeight:        30
    readonly property int barExpandedHeight:    44
    readonly property int barCompactHeight:     36
    readonly property int barRevealStripHeight: 6
    readonly property int barLeftSpacing:       12
    readonly property int barCenterSpacing:     8
    readonly property int barRightSpacing:      6

    // ── Bar widget widths ──────────────────────────────────────
    readonly property int barMediaMaxWidth:      240
    readonly property int barFocusedAppMaxWidth: 240
    readonly property int barWeatherMaxWidth:     96
    readonly property int barIconButtonSize:      30
    readonly property int barIconFontSize:        14
    readonly property int barLabelFontSize:       11

    // ── Icon sizing ───────────────────────────────────────────
    readonly property int iconSizeXS: 14
    readonly property int iconSizeSM: 16
    readonly property int iconSizeMD: 20
    readonly property int iconSizeLG: 24
    readonly property int iconSizeXL: 32

    // ── Semantic opacities ────────────────────────────────────
    readonly property real textOpacitySecondary: 0.72
    readonly property real textOpacityTertiary:  0.56
    readonly property real textOpacityDisabled:  0.38
    readonly property real innerGlowOpacity:     0.05
    readonly property real hoverBorderOpacity:   0.14
    readonly property real activeBorderOpacity:   0.28
    readonly property real scrimOpacityDim:      0.18
    readonly property real scrimOpacityDefault:  0.42

    // ── Shadow presets ────────────────────────────────────────
    readonly property var shadowPanel:   ({ offsetY: 2, alpha: 0.16 })
    readonly property var shadowPopup:   ({ offsetY: 4, alpha: 0.22 })
    readonly property var shadowDock:    ({ offsetY: 4, alpha: 0.20 })
    readonly property var shadowLauncher: ({ offsetY: 6, alpha: 0.26 })
    readonly property int elevationRaised: 1

    // ── Tooltip ────────────────────────────────────────────────
    readonly property int tooltipDelayMs:   350
    readonly property int tooltipTimeoutMs: 4000

    // ── Spring Animation Presets ──────────────────────────────
    // Use in: Behavior { SpringAnimation { spring: DesignTokens.springDefault; damping: DesignTokens.dampingDefault } }
    readonly property real springDefault: 5.5    // smooth generic transitions
    readonly property real springBouncy:  8.0    // bouncy widget pops
    readonly property real springSnappy: 11.0    // micro-interaction press feedback

    readonly property real dampingDefault: 0.78  // critically damped
    readonly property real dampingBouncy:  0.52  // underdamped, bouncy
    readonly property real dampingSnappy:  0.58  // slightly underdamped

    // ── Typography ────────────────────────────────────────────
    // NativeRendering avoids subpixel hinting artifacts on Wayland.
    readonly property string fontFamilyUI:   "Inter"
    readonly property string fontFamilyMono: "JetBrainsMono Nerd Font"
    // Font sizes (px)
    readonly property int fontSizeXS: 9
    readonly property int fontSizeSM: 11
    readonly property int fontSizeMD: 13
    readonly property int fontSizeLG: 15
    readonly property int fontSizeXL:   18
    readonly property int fontSizeXXL:  24
    readonly property int fontSizeHero: 32

    // ── Font Weights ─────────────────────────────────────────────
    readonly property int fontWeightRegular:  Font.Normal     // 400
    readonly property int fontWeightMedium:   Font.Medium     // 500
    readonly property int fontWeightSemiBold: Font.DemiBold   // 600
    readonly property int fontWeightBold:     Font.Bold       // 700

    // ── Line Heights (multipliers) ───────────────────────────────
    readonly property real lineHeightTight:   1.1
    readonly property real lineHeightNormal:  1.4
    readonly property real lineHeightRelaxed: 1.6

    // ── Letter Spacing (px) ──────────────────────────────────────
    readonly property real letterSpacingLabel:   0.3
    readonly property real letterSpacingHeading: -0.3
    readonly property real letterSpacingTimer:   1.2
    readonly property real letterSpacingBadge:   0.5
    readonly property real letterSpacingCaps:    0.8

    // ── Density Modes (multiplier against base spacing) ──────────
    readonly property real densityCompact:     0.75
    readonly property real densityNormal:      1.0
    readonly property real densityComfortable: 1.25

    // ── Shadow Tokens ────────────────────────────────────────────
    readonly property var shadowSM:  ({ offsetY: 1,  blur: 3,  spread: 0, alpha: 0.12 })
    readonly property var shadowMD:  ({ offsetY: 2,  blur: 8,  spread: 1, alpha: 0.18 })
    readonly property var shadowLG:  ({ offsetY: 4,  blur: 16, spread: 2, alpha: 0.25 })
    readonly property var shadowXL:  ({ offsetY: 8,  blur: 32, spread: 4, alpha: 0.35 })

    // ── Gradient Tokens ──────────────────────────────────────────
    readonly property real gradientAngle: 135  // consistent diagonal direction

    // ── Animation Families ───────────────────────────────────────
    readonly property var animHover:        ({ duration: 80,  easing: Easing.OutCubic })
    readonly property var animPopup:        ({ duration: 200, easing: Easing.OutQuint })
    readonly property var animNavigation:   ({ duration: 150, easing: Easing.OutCubic })
    readonly property var animConfirmation: ({ duration: 300, easing: Easing.OutBack })
    readonly property var animToast:        ({ duration: 250, easing: Easing.OutQuint })
    readonly property var animMicro:        ({ duration: 60,  easing: Easing.OutQuad })

    // ── Reveal / Auto-hide ───────────────────────────────────────
    readonly property int revealDelayMs:       100
    readonly property int revealDurationMs:    150
    readonly property int autohideDelayMs:     500
    readonly property int barDockSyncDurationMs: 220  // Unified duration for bar/dock auto-hide
    readonly property real revealStripOpacity: 0.35

    // ── Border Tokens ────────────────────────────────────────────
    readonly property int borderDefault:   1
    readonly property int borderFocus:     2
    readonly property int borderError:     2
    readonly property int borderSelection: 2
    readonly property int borderUrgent:    2

    // ── Hero / Confirmation Scales ───────────────────────────────
    readonly property real scaleHero:         1.05
    readonly property real scaleConfirmation: 0.96
    readonly property real scaleCardHover:    1.02
    readonly property real scaleCardActive:   0.98

    // ── Legacy poll intervals (for remaining pollers) ─────────
    readonly property int pollFastMs:   1000
    readonly property int pollNormalMs: 5000
    readonly property int pollSlowMs:  15000
}
