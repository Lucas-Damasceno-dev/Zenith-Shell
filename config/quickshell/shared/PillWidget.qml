import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../core"

/**
 * PillWidget - Generic reusable pill-shaped bar widget.
 *
 * Features:
 * - NativeRendering typography, Spring micro-interactions
 * - Variants: "default", "primary", "secondary"
 * - States: disabled, loading, elevated, checked, popupOpen
 * - Badge counter, click ripple, hover tooltip data
 * - Adaptive Material You accent color support
 *
 * Usage:
 *   PillWidget {
 *       iconText: "\uf028"
 *       iconColor: ColorScheme.accent
 *       labelText: "72%"
 *       variant: "primary"
 *       badgeText: "3"
 *       tooltipText: "Volume"
 *       onClicked: doSomething()
 *   }
 */
Item {
    id: pillRoot

    // ── Public API ──────────────────────────────────────────────────────
    property string iconSource: ""
    property string iconText: ""
    property int    iconFontSize: DesignTokens.barIconFontSize
    property string iconFontFamily: DesignTokens.fontFamilyMono
    property real   iconYOffset: 0
    property real   sourceSize: Math.max(16, iconFontSize * 2)
    property string labelText: ""
    property int    labelFontSize: DesignTokens.barLabelFontSize
    property bool   labelVisible: labelText !== ""
    property color  iconColor: ColorScheme.accent
    property color  labelColor: ColorScheme.text
    property bool   busy: false
    property bool   disabled: false
    property bool   loading: false
    property bool   elevated: false
    property bool   checked: false
    property bool   popupOpen: false
    property bool   anyPopupOpen: false
    property string variant: "default"
    property string badgeText: ""
    property color  badgeColor: ColorScheme.red
    property int    labelWeight: Font.Bold
    property color  activeLabelColor: labelColor
    property string tooltipText: ""
    property alias  mouseArea: ma

    property bool   _realHover: false
    readonly property bool _activeState: checked || popupOpen
    readonly property bool _pressed: ma.pressed
    readonly property color _pillColor: {
        if (_effectiveDisabled)
            return ColorScheme.withAlpha(ColorScheme.foreground, 0.04);
        if (_pressed)
            return ColorScheme.statePressed;
        if (_activeState)
            return ColorScheme.stateSelected;
        if (_realHover)
            return ColorScheme.stateHover;
        return ColorScheme.withAlpha(ColorScheme.surface, ColorScheme.isDark ? 0.12 : 0.08);
    }
    readonly property color _pillBorderColor: {
        if (_effectiveDisabled)
            return ColorScheme.withAlpha(ColorScheme.foreground, 0.06);
        if (_pressed)
            return ColorScheme.withAlpha(iconColor, DesignTokens.activeBorderOpacity);
        if (_activeState)
            return ColorScheme.withAlpha(iconColor, DesignTokens.activeBorderOpacity);
        if (_realHover)
            return ColorScheme.withAlpha(ColorScheme.foreground, DesignTokens.hoverBorderOpacity);
        return ColorScheme.glassBorder;
    }
    readonly property color _iconChipColor: {
        if (_effectiveDisabled)
            return ColorScheme.withAlpha(ColorScheme.foreground, 0.05);
        if (_pressed)
            return ColorScheme.withAlpha(iconColor, ColorScheme.isDark ? 0.18 : 0.24);
        if (_activeState)
            return ColorScheme.withAlpha(iconColor, ColorScheme.isDark ? 0.26 : 0.34);
        if (_realHover)
            return ColorScheme.withAlpha(iconColor, ColorScheme.isDark ? 0.12 : 0.18);
        return "transparent";
    }

    signal clicked()
    signal pressAndHold()

    readonly property bool _effectiveDisabled: disabled || busy
    readonly property bool _showHalo: popupOpen && !_effectiveDisabled
    readonly property bool reducedMotion: FeatureFlags.reducedMotion

    // ── Sizing ──────────────────────────────────────────────────────────
    implicitWidth: row.implicitWidth
    implicitHeight: DesignTokens.barItemHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: pillRoot._pillColor
        border.width: 1
        border.color: pillRoot._pillBorderColor
        Behavior on color {
            enabled: !pillRoot.reducedMotion
            ColorAnimation { duration: DesignTokens.durationNormal }
        }
        Behavior on border.color {
            enabled: !pillRoot.reducedMotion
            ColorAnimation { duration: DesignTokens.durationNormal }
        }
    }

    Behavior on implicitWidth {
        enabled: !pillRoot.reducedMotion
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        enabled: !pillRoot.reducedMotion
        NumberAnimation { duration: DesignTokens.durationFast; easing.type: Easing.OutCubic }
    }

    opacity: _effectiveDisabled ? DesignTokens.disabledOpacity : 1.0
    Behavior on opacity {
        enabled: !pillRoot.reducedMotion
        NumberAnimation { duration: DesignTokens.durationFast }
    }

    // ── Popup-open halo ring ────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: DesignTokens.radiusSM + 3
        color: "transparent"
        border.width: _showHalo ? 1.5 : 0
        border.color: ColorScheme.withAlpha(pillRoot.iconColor, 0.35)
        visible: _showHalo
        Behavior on border.width {
            enabled: !pillRoot.reducedMotion
            NumberAnimation { duration: DesignTokens.durationNormal }
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: DesignTokens.spacingXS

        // ── Icon Button ────────────────────────────────────────────────
        Rectangle {
            id: iconBg
            implicitWidth:  Math.max(DesignTokens.barIconButtonSize, iconTextElement.contentWidth + 16)
            implicitHeight: DesignTokens.barIconButtonSize
            radius: height / 2
            clip: true

            readonly property bool showHover: pillRoot._realHover && !pillRoot.checked
                && !pillRoot.anyPopupOpen && !pillRoot._effectiveDisabled

            color: {
                let isDark = ColorScheme.isDark;
                if (pillRoot.labelVisible) return pillRoot._iconChipColor;
                if (pillRoot.variant === "primary")
                    return pillRoot.checked
                        ? ColorScheme.withAlpha(pillRoot.iconColor, isDark ? 0.30 : 0.40)
                        : (showHover ? ColorScheme.withAlpha(pillRoot.iconColor, isDark ? 0.14 : 0.22)
                                     : ColorScheme.withAlpha(pillRoot.iconColor, isDark ? 0.08 : 0.14));
                if (pillRoot.variant === "secondary")
                    return pillRoot.checked
                        ? ColorScheme.withAlpha(ColorScheme.foreground, isDark ? 0.16 : 0.25)
                        : (showHover ? ColorScheme.glassHover : "transparent");
                return pillRoot.checked
                    ? ColorScheme.withAlpha(pillRoot.iconColor, isDark ? 0.22 : 0.35)
                    : (showHover ? ColorScheme.glassHover : "transparent");
            }
            border.width: pillRoot._activeState || showHover ? 1 : 0
            border.color: pillRoot._activeState
                ? ColorScheme.withAlpha(pillRoot.iconColor, DesignTokens.activeBorderOpacity)
                : (showHover
                    ? ColorScheme.withAlpha(ColorScheme.foreground, DesignTokens.hoverBorderOpacity)
                    : "transparent")

            Behavior on color {
                enabled: !pillRoot.reducedMotion
                ColorAnimation { duration: DesignTokens.durationFast }
            }

            // Elevated bottom accent line
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1; radius: 1
                color: ColorScheme.withAlpha(ColorScheme.foreground, 0.06)
                visible: pillRoot.elevated && !pillRoot._effectiveDisabled
            }

            DynamicIcon {
                id: svgIcon
                anchors.centerIn: parent
                visible: pillRoot.iconSource !== "" && !pillRoot.loading
                iconSource: pillRoot.iconSource
                iconColor: pillRoot.iconColor
                size: pillRoot.iconFontSize
                sourceSize: pillRoot.sourceSize
            }

            Text {
                id: iconTextElement
                anchors.centerIn: parent
                anchors.verticalCenterOffset: pillRoot.iconYOffset
                visible: pillRoot.iconSource === "" && !pillRoot.loading
                text: pillRoot.iconText
                font.family: pillRoot.iconFontFamily
                font.pixelSize: pillRoot.iconFontSize
                renderType: Text.NativeRendering
                color: pillRoot.iconColor
                Behavior on color {
                    enabled: !pillRoot.reducedMotion
                    ColorAnimation { duration: DesignTokens.durationNormal }
                }
            }

            // Loading spinner
                Text {
                    anchors.centerIn: parent
                    visible: pillRoot.loading
                    text: "\uf110"
                    font.family: DesignTokens.fontFamilyMono
                font.pixelSize: pillRoot.iconFontSize
                renderType: Text.NativeRendering
                    color: pillRoot.iconColor
                    opacity: 0.7
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 1000
                        loops: Animation.Infinite; running: pillRoot.loading && !pillRoot.reducedMotion
                    }
                }

            // Click ripple
            Rectangle {
                id: ripple
                anchors.centerIn: parent
                width: 0; height: 0
                radius: width / 2
                color: ColorScheme.withAlpha(pillRoot.iconColor, 0.18)
                opacity: 0
                ParallelAnimation {
                    id: rippleAnim
                    NumberAnimation { target: ripple; property: "width";   from: 0; to: iconBg.width * 1.6;  duration: 400; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ripple; property: "height";  from: 0; to: iconBg.height * 1.6; duration: 400; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ripple; property: "opacity"; from: 0.25; to: 0;                duration: 400; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1
                radius: parent.radius
                color: ColorScheme.withAlpha(ColorScheme.text, DesignTokens.innerGlowOpacity)
                visible: pillRoot._activeState || iconBg.showHover || pillRoot._realHover
            }

            // Badge counter
            Rectangle {
                visible: pillRoot.badgeText !== ""
                width: Math.max(14, badgeLabel.contentWidth + 6)
                height: 14; radius: 7
                color: pillRoot.badgeColor
                anchors.right: parent.right; anchors.top: parent.top
                anchors.rightMargin: -4; anchors.topMargin: -4
                Text {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: pillRoot.badgeText
                    font.pixelSize: 9; font.weight: Font.Bold
                    font.family: DesignTokens.fontFamilyUI
                    font.letterSpacing: DesignTokens.letterSpacingBadge
                    renderType: Text.NativeRendering
                    color: ColorScheme.onPrimary
                }
            }
        }

        // ── Optional Label ─────────────────────────────────────────────
        Text {
            id: labelText_
            visible: pillRoot.labelVisible
            opacity: pillRoot.labelVisible ? 1.0 : 0.0
            Behavior on opacity {
                enabled: !pillRoot.reducedMotion
                NumberAnimation { duration: DesignTokens.durationNormal }
            }
            text: pillRoot.labelText
            color: pillRoot._activeState ? pillRoot.activeLabelColor : pillRoot.labelColor
            font.pixelSize: pillRoot.labelFontSize
            font.weight: pillRoot.labelWeight
            font.family: DesignTokens.fontFamilyUI
            renderType: Text.NativeRendering
            elide: Text.ElideRight
            Layout.maximumWidth: 72
            Layout.rightMargin: DesignTokens.spacingSM
            Behavior on color {
                enabled: !pillRoot.reducedMotion
                ColorAnimation { duration: DesignTokens.durationNormal }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pillRoot._effectiveDisabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        onEntered: pillRoot._realHover = true
        onExited:  pillRoot._realHover = false
        onClicked: {
            if (pillRoot._effectiveDisabled) return;
            pillRoot._realHover = false;
            rippleAnim.stop();
            ripple.width = 0; ripple.height = 0; ripple.opacity = 0;
            if (!pillRoot.reducedMotion)
                rippleAnim.start();
            pillRoot.clicked();
        }
        onPressAndHold: {
            if (!pillRoot._effectiveDisabled) pillRoot.pressAndHold();
        }
        onPressed:  pillRoot.scale = (pillRoot._effectiveDisabled || pillRoot.reducedMotion) ? 1.0 : DesignTokens.pressedScale
        onReleased: pillRoot.scale = 1.0
    }

    ToolTip.visible: pillRoot._realHover && pillRoot.tooltipText !== "" && !pillRoot._effectiveDisabled
    ToolTip.delay: 600
    ToolTip.text: pillRoot.tooltipText
}
