import QtQuick
import Quickshell
import Quickshell.Wayland
import "../shared"

/**
 * AnimatedWindow - Base overlay window with glassmorphism and spring physics.
 *
 * Every overlay (Launcher, Dashboard, PowerMenu, etc.) should extend this.
 * It provides:
 *   - Smooth open/close with spring physics
 *   - Glass background (blur + semi-transparent + border + shadow)
 *   - Scrim (dark backdrop for fullscreen overlays)
 *   - Automatic visibility management
 *
 * Usage:
 *   AnimatedWindow {
 *       anchors.top: true; anchors.right: true
 *       implicitWidth: 400; implicitHeight: 600
 *       glassRadius: 16
 *       showScrim: false  // true for fullscreen overlays
 *
 *       // Your content goes directly inside
 *       Rectangle { ... }
 *   }
 */
PanelWindow {
    id: root
    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion
    // Always mapped — surface lifetime is managed safely via Loader.active in shell.qml.
    // Setting visible:false directly would destroy QQuickWindow while spring animations
    // (settling time ~6s) still hold timer callbacks → SIGSEGV.
    visible: true
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    property string layerNamespace: "quickshell-popup"
    WlrLayershell.namespace: layerNamespace

    // focusable must be true always so Qt's QQuickWindow accepts keyboard
    // events on the surface.  The actual keyboard routing is controlled at
    // the Wayland layer-shell level below.
    focusable: true

    // Exclusive = compositor sends all keyboard input to this surface.
    // None      = keys go to the focused app underneath.
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // When closed, use an empty mask so the surface is fully click-through.
    mask: isOpen ? null : _emptyMask

    // An empty Region means zero clickable area → full click-through.
    Region { id: _emptyMask }

    /**
     * Emitted ~380ms after isOpen goes false (after the 280ms opacity fade + buffer).
     * shell.qml catches this and calls loader.active = false, which destroys the entire
     * QML subtree in safe dependency order: animations → items → PanelWindow → Wayland
     * surface unmapped from Hyprland.  This eliminates per-frame compositor overhead
     * for popups the user isn't using.
     */
    signal closedAndReady()

    Timer {
        id: _closeCompleteTimer
        interval: root.reducedEffects ? 0 : DesignTokens.popupRevealDurationMs + 100
        repeat: false
        onTriggered: {
            if (!root.isOpen) {
                // Remove animated content from scene graph so spring animations
                // (which settle in ~6s) no longer trigger GPU buffer commits.
                animatedContainer.visible = false
                var r = root
                // Qt.callLater defers one event loop tick so the timer call-stack
                // is fully unwound before any QML tree teardown begins.
                Qt.callLater(function() { if (!r.isOpen) r.closedAndReady() })
            }
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            animatedContainer.visible = true
            _closeCompleteTimer.stop()
        } else {
            _closeCompleteTimer.restart()
        }
    }

    // ─── Public API ─────────────────────────────────────────────
    property bool isOpen: false
    property int closeDelay: 350

    /** Glass surface customization */
    property real glassOpacity: 0.50
    property int  glassRadius: 16
    property real glassBorderWidth: 1
    property color glassBorderColor: ColorScheme.outlineVariant
    property color glassBackground: ColorScheme.glassPopup

    /** Shadow */
    property real  shadowBlur: DesignTokens.shadowPopup.blur
    property real  shadowOffsetY: DesignTokens.shadowPopup.offsetY
    property color shadowColor: Qt.rgba(0, 0, 0, DesignTokens.shadowPopup.alpha)

    /** Scrim (fullscreen darkened backdrop) */
    property bool  showScrim: false
    property real  scrimOpacity: 0.45

    /** Animation origin for scale (0.0 = top, 0.5 = center, 1.0 = bottom) */
    property real originY: 0.0
    property real originX: 0.5

    /** Background atmosphere */
    property bool useAtmosphereBackdrop: false
    property string atmosphereSource: ""
    property real atmosphereTintOpacity: DesignTokens.backdropTintOpacity
    property real atmosphereGlowOpacity: DesignTokens.backdropGlowOpacity
    property real atmosphereNoiseOpacity: DesignTokens.backdropNoiseOpacity
    property real atmosphereVignetteOpacity: DesignTokens.backdropVignetteOpacity

    /** Entry slide direction offset (pixels) */
    property real slideY: 15
    property real slideX: 0

    // Content container alias so children get parented inside the glass
    default property alias contentData: contentContainer.data

    // ─── Visibility State Machine ───────────────────────────────
    // Surface stays visible:true always.  On close, closedAndReady signal fires and
    // shell.qml deactivates the Loader (loader.active=false), destroying the QML tree
    // in proper order and unmapping the Wayland surface from the compositor.

    // ─── Scrim Layer ────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: ColorScheme.scrim
        opacity: (root.showScrim && root.isOpen) ? root.scrimOpacity : 0.0
        visible: root.showScrim && root.isOpen

        Behavior on opacity {
            enabled: !root.reducedEffects
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.showScrim
            onClicked: root.isOpen = false
        }
    }

    // ─── Animated Container ─────────────────────────────────────
    Item {
        id: animatedContainer
        anchors.fill: parent
        enabled: root.isOpen

        // Separate property for spring-animated scale to avoid
        // conflict between the scale property and Transform element
        property real animScale: root.isOpen ? 1.0 : 0.92

        opacity: root.isOpen ? 1.0 : 0.0

        transform: [
            Scale {
                origin.x: animatedContainer.width * root.originX
                origin.y: animatedContainer.height * root.originY
                xScale: animatedContainer.animScale
                yScale: animatedContainer.animScale

                Behavior on xScale {
                    enabled: !root.reducedEffects
                        NumberAnimation { duration: DesignTokens.popupRevealDurationMs; easing.type: Easing.OutCubic }
                }
                Behavior on yScale {
                    enabled: !root.reducedEffects
                    NumberAnimation { duration: DesignTokens.popupRevealDurationMs; easing.type: Easing.OutCubic }
                }
            },
            Translate {
                x: root.isOpen ? 0 : root.slideX
                y: root.isOpen ? 0 : root.slideY

                Behavior on x {
                    enabled: !root.reducedEffects
                    NumberAnimation { duration: DesignTokens.surfaceTransitionDurationMs; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    enabled: !root.reducedEffects
                    NumberAnimation { duration: DesignTokens.surfaceTransitionDurationMs; easing.type: Easing.OutCubic }
                }
            }
        ]

        Behavior on opacity {
            enabled: !root.reducedEffects
            NumberAnimation { duration: DesignTokens.surfaceRevealDurationMs; easing.type: Easing.OutCubic }
        }

        // ─── Glass Surface ──────────────────────────────────────
        Rectangle {
            id: glassSurface
            visible: root.glassBackground.a > 0
            anchors.fill: contentContainer
            radius: root.glassRadius
            color: root.glassBackground
            border.color: root.glassBorderColor
            border.width: root.glassBorderWidth

            // Subtle inner highlight at the top edge (glass refraction)
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1
                radius: root.glassRadius
                color: ColorScheme.withAlpha(ColorScheme.text, DesignTokens.innerGlowOpacity)
            }
        }

        // Shadow — only rendered when popup is open
        Rectangle {
            visible: root.isOpen && root.glassBackground.a > 0
            anchors.fill: glassSurface
            anchors.topMargin: root.shadowOffsetY
            radius: root.glassRadius
            color: root.shadowColor
            z: -1
        }

        // ─── Content Container ──────────────────────────────────
        Item {
            id: contentContainer
            anchors.fill: parent
            clip: true

            AtmosphereBackdrop {
                anchors.fill: parent
                visible: root.useAtmosphereBackdrop && root.isOpen
                source: root.isOpen ? root.atmosphereSource : ""
                tintOpacity: root.atmosphereTintOpacity
                glowOpacity: root.atmosphereGlowOpacity
                noiseOpacity: root.atmosphereNoiseOpacity
                vignetteOpacity: root.atmosphereVignetteOpacity
                reducedMotion: root.reducedEffects
            }
        }
    }

    // ─── Keyboard ───────────────────────────────────────────────
    Shortcut {
        sequence: "Escape"
        onActivated: root.isOpen = false
    }
}
