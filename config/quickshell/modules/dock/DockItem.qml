pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"
import "../../shared"
import "../../core/TrayIconUtils.js" as TrayIconUtils

/**
 * DockItem — Individual dock icon with magnification, parabolic rise,
 * bounce-on-launch, press feedback, animated running indicators and
 * reactive accent theming.
 */
Item {
    id: root

    property var itemData: null
    property string appId: itemData ? (itemData.appId || "") : ""
    property string appName: itemData ? (itemData.name || itemData.appId || "") : ""
    property string appIcon: itemData ? (itemData.icon || itemData.appId || "") : ""
    property bool pinned: itemData ? !!itemData.pinned : false
    property bool running: itemData ? !!itemData.running : false
    property int instanceCount: itemData ? (itemData.instanceCount || 0) : 0
    property bool focused: itemData ? !!itemData.focused : false
    property bool minimizedAll: itemData ? !!itemData.minimizedAll : false
    property bool launching: itemData && itemData.appId ? DockService.isLaunching(itemData.appId) : false
    property bool urgent: itemData && itemData.appId ? DockService.getUrgent(itemData.appId) : false
    property bool floating: itemData ? !!itemData.floating : false
    property int badgeCount: itemData ? (itemData.badgeCount || 0) : 0
    property bool audioActive: itemData ? !!itemData.audioActive : false
    property bool xwayland: itemData ? !!itemData.xwayland : false
    property bool hasPip: itemData ? !!itemData.hasPip : false
    property var itemInfo: itemData
    property bool keyboardSelected: false
    // Cached icon resolution - now handled by SmartIcon
    property string iconKey: root.appIcon + "|" + root.appId + "|" + root.appName
    property string _fallbackGlyph: TrayIconUtils.fallbackGlyph({ icon: root.appIcon, id: root.appId, title: root.appName })


    // ── Magnification (driven by Dock.calculateZoom) ─────────
    property real magnification: 1.0
    
    // Spring physics for magnification
    Behavior on magnification {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 72; easing.type: Easing.OutCubic }
    }

    // ── Parabolic rise (icons float up when magnified) ───────
    property real riseOffset: 0
    Behavior on riseOffset {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 72; easing.type: Easing.OutCubic }
    }

    property real baseSize: 46
    readonly property real displaySize: baseSize * magnification

    // ── Drag support ─────────────────────────────────────────────
    property bool reducedEffects: false   // set by Dock when auto-hidden/fullscreen/low-power
    property int focusedIdx: itemData ? (itemData.focusedIdx !== undefined ? itemData.focusedIdx : 0) : 0

    // Smooth width change to avoid jittery reflow

    // ── Press feedback ───────────────────────────────────────
    property real _pressScale: 1.0
    property bool _justClicked: false

    Timer {
        id: justClickedTimer
        interval: 300
        onTriggered: root._justClicked = false
    }

    // ── Progress Tracking ───────────────────────────────────
    property real progress: -1 // -1 means no progress, 0.0 to 1.0
    onLaunchingChanged: {
        if (!root.launching && typeof iconContainer !== "undefined" && iconContainer) {
            iconContainer.resetLaunchAnimations();
        }
    }

    // ── Drag support ─────────────────────────────────────────
    property int itemIndex: -1
    property bool isDragging: dragHandler.active
    property real displacementX: 0
    
    // High-performance spring for displacement
    Behavior on displacementX {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 72; easing.type: Easing.OutCubic }
    }

    Drag.active: dragHandler.active
    Drag.source: root
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2
    Drag.dragType: Drag.Internal
    Drag.mimeData: { "text/plain": root.appId }

    width: (displaySize + DesignTokens.spacingSM) + (root.isDragging ? -displaySize : 0)
    height: baseSize * 1.6 + 16 // Consistent height to avoid vertical shifting during magnification

    signal clicked()
    signal middleClicked()
    signal rightClicked(real mx, real my, bool shiftHeld)
    signal hovered(bool isHovered)
    signal wheelScrolled(int delta)
    signal peekRequested(string appId, bool active)
    signal reorderRequested(real globalX, string appId)

    // The actual visual item is shifted by displacementX
    Item {
        id: visualWrapper
        anchors.fill: parent
        x: root.displacementX
        
        // ── Icon Container (handles bounce + rise offset) ────────
            Item {
                id: iconContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8 + root.riseOffset + _bounceOffset
            width: displaySize
            height: displaySize
            scale: (root.isDragging ? 1.1 : root._pressScale) * iconContainer._pulseScale

            Behavior on scale {
                enabled: !root.reducedEffects
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }

            property real _bounceOffset: 0
            property real _pulseScale: 1.0
            property bool _longLaunch: false
            
            // Ghost effect when launching
            opacity: root.launching ? 0.7 : (root.minimizedAll ? 0.5 : 1.0)
            Behavior on opacity {
                enabled: !root.reducedEffects
                NumberAnimation { duration: 200 }
            }

            // Launch bounce animation (first 3 seconds)
            SequentialAnimation {
                id: bounceAnim
                running: root.launching && !iconContainer._longLaunch && !root.reducedEffects
                loops: Animation.Infinite
                NumberAnimation {
                    target: iconContainer; property: "_bounceOffset"
                    to: 20; duration: 400
                    easing.type: Easing.OutQuint
                }
                NumberAnimation {
                    target: iconContainer; property: "_bounceOffset"
                    to: 0; duration: 500
                    easing.type: Easing.OutBounce
                }
                PauseAnimation { duration: 150 }
            }

            // Enhanced pulsation for long launches (after 3s)
            SequentialAnimation {
                id: pulseAnim
                running: root.launching && iconContainer._longLaunch && !root.reducedEffects
                loops: Animation.Infinite
                NumberAnimation {
                    target: iconContainer; property: "_pulseScale"
                    from: 1.0; to: 1.15; duration: 600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: iconContainer; property: "_pulseScale"
                    from: 1.15; to: 0.90; duration: 600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: iconContainer; property: "_pulseScale"
                    from: 0.90; to: 1.0; duration: 400
                    easing.type: Easing.OutBounce
                }
            }

            // Timer to switch from bounce to pulse after 3 seconds
            Timer {
                id: longLaunchTimer
                interval: 3000; repeat: false
                running: root.launching && !root.reducedEffects
                onTriggered: iconContainer._longLaunch = true
            }

            function resetLaunchAnimations() {
                bounceAnim.stop();
                pulseAnim.stop();
                _bounceOffset = 0;
                _pulseScale = 1.0;
                _longLaunch = false;
                longLaunchTimer.stop();
            }

            // ── Dominant Color Glow (focused) ─────────────────
            Rectangle {
                id: dominantGlow
                anchors.fill: parent
                anchors.margins: -8
                radius: parent.radius + 8
                color: "transparent"
                visible: root.focused && root.running
                z: -1

                // Use accent color as fallback; when Canvas extracts dominant, it updates
                property color glowColor: ColorScheme.accent
                
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: ColorScheme.withAlpha(dominantGlow.glowColor, 0.20)
                    opacity: root.focused ? 1.0 : 0.0
                    Behavior on opacity {
                        enabled: !root.reducedEffects
                        NumberAnimation { duration: 300 }
                    }
                    Behavior on color {
                        enabled: !root.reducedEffects
                        ColorAnimation { duration: 500 }
                    }
                }
            }

            // ── Background (hover / focused state) ───────────────
            Rectangle {
                id: iconBg
                anchors.fill: parent
                radius: DesignTokens.radiusMD
                color: root.keyboardSelected
                    ? ColorScheme.stateSelected
                    : (root.focused
                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.18)
                        : (mouseArea.containsMouse && !root._justClicked
                            ? ColorScheme.stateHover
                            : "transparent"))
                border.width: root.keyboardSelected
                    ? DesignTokens.borderFocus
                    : (root.urgent ? DesignTokens.borderError : (root.focused ? 1 : 0))
                border.color: root.keyboardSelected ? ColorScheme.accent : (root.urgent ? ColorScheme.red : (root.focused ? ColorScheme.withAlpha(ColorScheme.accent, 0.4) : "transparent"))

                Behavior on color {
                    enabled: !root.reducedEffects
                    ColorAnimation { duration: DesignTokens.durationNormal }
                }
                Behavior on border.width {
                    enabled: !root.reducedEffects
                    NumberAnimation { duration: DesignTokens.durationFast }
                }
            }

            // ── Urgent Glow Underlay ─────────────────────────
            Rectangle {
                anchors.fill: parent
                anchors.margins: -12
                radius: parent.radius + 12
                color: ColorScheme.withAlpha(ColorScheme.red, 0.25)
                visible: root.urgent
                z: -2
                
                SequentialAnimation on opacity {
                    running: root.urgent && !root.reducedEffects
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.1; to: 0.5; duration: 1000; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.5; to: 0.1; duration: 1000; easing.type: Easing.InOutSine }
                }
            }

            // Running reflection glow
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: -4
                width: parent.width * 0.5
                height: 4
                radius: 2
                color: ColorScheme.withAlpha(ColorScheme.accent, 0.4)
                visible: root.running && root.focused
                opacity: root.focused ? 1.0 : 0.0
                Behavior on opacity {
                    enabled: !root.reducedEffects
                    NumberAnimation { duration: 300 }
                }
            }

            // Hover glow ring & Drop Target highlight
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: iconBg.radius + 3
                color: "transparent"
                border.width: root.dropHovered ? 2 : (mouseArea.containsMouse && !root.isDragging ? 1.5 : 0)
                border.color: root.dropHovered ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                visible: (mouseArea.containsMouse && !root.isDragging && !root._justClicked) || root.dropHovered
                Behavior on border.width {
                    enabled: !root.reducedEffects
                    NumberAnimation { duration: DesignTokens.durationFast }
                }
                Behavior on border.color {
                    enabled: !root.reducedEffects
                    ColorAnimation { duration: DesignTokens.durationFast }
                }
            }

            // ── Ripple Effect (on click/launch) ─────────────────
            Rectangle {
                id: ripple
                anchors.centerIn: parent
                width: 0; height: 0
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.5)
                opacity: 0
                z: 10

                function fire() {
                    rippleAnim.restart();
                }

                ParallelAnimation {
                    id: rippleAnim
                    NumberAnimation { target: ripple; property: "width"; from: 10; to: displaySize * 2; duration: 500; easing.type: Easing.OutQuart }
                    NumberAnimation { target: ripple; property: "height"; from: 10; to: displaySize * 2; duration: 500; easing.type: Easing.OutQuart }
                    NumberAnimation { target: ripple; property: "opacity"; from: 0.6; to: 0.0; duration: 500; easing.type: Easing.OutQuart }
                }
            }

            // ── Icon Image (with squircle mask) ─────────────────────
            // layer.enabled on a Rectangle with radius creates a GPU texture
            // that clips children to the rounded corners — true squircle masking.
            Rectangle {
                id: iconMask
                anchors.centerIn: parent
                width: parent.width * 0.82
                height: parent.height * 0.82
                radius: width * 0.24
                color: "transparent"
                layer.enabled: !root.reducedEffects
                layer.smooth: true

                    SmartIcon {
                        id: iconImage
                        anchors.fill: parent
                        source: root.appIcon
                        label: root.appName
                        size: parent.width
                        fallbackIcon: root._fallbackGlyph
                    
                        opacity: root.minimizedAll ? 0.40 : (root.isDragging ? 0.30 : 1.0)
                    Behavior on opacity {
                        enabled: !root.reducedEffects
                        NumberAnimation { duration: DesignTokens.durationNormal }
                    }
                    }
                }

            // ── Progress Bar ───────────────────────────────────
            Rectangle {
                id: progressContainer
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 4
                width: parent.width * 0.7
                height: 3; radius: 1.5
                color: ColorScheme.withAlpha(ColorScheme.text, 0.2)
                visible: root.progress >= 0 && root.progress <= 1.0
                clip: true
                
                Rectangle {
                    width: parent.width * root.progress
                    height: parent.height
                    radius: parent.radius
                    color: ColorScheme.accent
                    Behavior on width {
                        enabled: !root.reducedEffects
                        NumberAnimation { duration: 300 }
                    }
                }
            }
        }

        // ── Notification badge (urgent or count) ────────────────────
            Rectangle {
                visible: root.urgent || root.badgeCount > 0
            anchors.top: iconContainer.top
            anchors.right: iconContainer.right
            anchors.topMargin: -2; anchors.rightMargin: -2
            width: badgeCountText.visible ? Math.max(16, badgeCountText.width + 8) : 14
            height: badgeCountText.visible ? 16 : 14
            radius: height / 2
            color: ColorScheme.red
            border.width: 2; border.color: ColorScheme.base00

            scale: (root.urgent || root.badgeCount > 0) ? 1.0 : 0.0
            Behavior on scale {
                enabled: !root.reducedEffects
                NumberAnimation { duration: 120; easing.type: Easing.OutBack }
            }

            Text {
                id: badgeCountText
                anchors.centerIn: parent
                visible: root.badgeCount > 0
                text: root.badgeCount > 99 ? "99+" : String(root.badgeCount)
                color: ColorScheme.base00
                font.pixelSize: 9
                font.bold: true
                font.family: Style.fontUI
            }
        }

        // ── Audio indicator ──────────────────────────────────────
        Rectangle {
            visible: root.audioActive && !root.urgent
            anchors.bottom: iconContainer.bottom
            anchors.right: iconContainer.right
            anchors.bottomMargin: -1; anchors.rightMargin: -1
            width: 14; height: 14; radius: 7
            color: ColorScheme.withAlpha(ColorScheme.base00, 0.85)
            border.width: 1; border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.3)

            Text {
                anchors.centerIn: parent
                text: "\u{f028}"
                font.family: Style.fontMono
                font.pixelSize: 8
                color: ColorScheme.accent
            }
        }

        // ── XWayland badge (hover only) ──────────────────────────
        Rectangle {
            visible: root.xwayland && mouseArea.containsMouse && !root._justClicked
            anchors.top: iconContainer.top
            anchors.left: iconContainer.left
            anchors.topMargin: -2; anchors.leftMargin: -2
            width: 16; height: 14; radius: 3
            color: ColorScheme.withAlpha(ColorScheme.yellow, 0.85)
            border.width: 1; border.color: ColorScheme.withAlpha(ColorScheme.base00, 0.3)

            Text {
                anchors.centerIn: parent
                text: "X"
                font.pixelSize: 8
                font.bold: true
                font.family: Style.fontUI
                color: ColorScheme.base00
            }

            opacity: mouseArea.containsMouse && !root._justClicked ? 1.0 : 0.0
            Behavior on opacity {
                enabled: !root.reducedEffects
                NumberAnimation { duration: 150 }
            }
        }

        // ── PiP sub-icon ─────────────────────────────────────────
        Rectangle {
            visible: root.hasPip
            anchors.bottom: iconContainer.bottom
            anchors.left: iconContainer.left
            anchors.bottomMargin: -2; anchors.leftMargin: -2
            width: 16; height: 14; radius: 3
            color: ColorScheme.withAlpha(ColorScheme.teal, 0.85)
            border.width: 1; border.color: ColorScheme.withAlpha(ColorScheme.base00, 0.3)

            Text {
                anchors.centerIn: parent
                text: "\u{f2d0}"
                font.family: Style.fontMono
                font.pixelSize: 7
                color: ColorScheme.base00
            }
        }

        // ── Special Workspace Indicator ─────────────────────────
        Rectangle {
            visible: itemData && itemData.hasSpecial
            anchors.top: iconContainer.top
            anchors.right: iconContainer.right
            anchors.topMargin: -2; anchors.rightMargin: -2
            width: 10; height: 10; radius: 5
            color: ColorScheme.blue
            border.width: 1; border.color: ColorScheme.base00
            z: 5
        }

        // ── Running indicators (pills / segmented dots) ───────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            spacing: 3
            visible: root.running

            Repeater {
                model: root.focused ? 1 : Math.max(1, Math.min(root.instanceCount, 3))
                delegate: Rectangle {
                    width: root.focused ? 16 : (root.instanceCount > 1 ? 4 : 6)
                    height: root.focused ? 3.5 : 3
                    radius: root.floating ? 1 : height / 2
                    color: root.floating
                        ? "transparent"
                        : root.focused
                            ? ColorScheme.accent
                            : root.minimizedAll
                                ? ColorScheme.withAlpha(ColorScheme.overlay, 0.30)
                                : root.urgent
                                    ? ColorScheme.red
                                    : ColorScheme.withAlpha(ColorScheme.text, 0.65)
                    border.width: root.floating ? 1 : 0
                    border.color: root.focused
                        ? ColorScheme.accent
                        : ColorScheme.withAlpha(ColorScheme.text, 0.50)

                    Behavior on width {
                        enabled: !root.reducedEffects
                        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        enabled: !root.reducedEffects
                        ColorAnimation { duration: DesignTokens.durationNormal }
                    }
                }
            }
        }
    }

    // ── Drag handler (pinned items only for reorder; running for tile) ─
    DragHandler {
        id: dragHandler
        target: null
        enabled: root.pinned || root.running

        property point _dragPos: Qt.point(0, 0)

        onActiveChanged: {
            if (!active) {
                var gp = root.mapToGlobal(_dragPos.x, _dragPos.y);
                var tiled = false;

                if (root.running && root.itemData && root.itemData.toplevels && root.itemData.toplevels.length > 0) {
                    // Check if dragged to screen edges for tiling
                    var screenW = (root.Window && root.Window.window ? root.Window.window.width : 1920);
                    var addr = root.itemData.toplevels[0].lastIpcObject ? root.itemData.toplevels[0].lastIpcObject.address : "";
                    if (addr) {
                        if (gp.x < 40) {
                            _tileProc.command = ["bash", "-c", "hyprctl dispatch movetoworkspacesilent e+0,address:" + addr + " && hyprctl dispatch resizewindowpixel exact 50% 100%,address:" + addr + " && hyprctl dispatch movewindowpixel exact 0 0,address:" + addr];
                            _tileProc.running = true;
                            tiled = true;
                        } else if (gp.x > screenW - 40) {
                            _tileProc.command = ["bash", "-c", "hyprctl dispatch movetoworkspacesilent e+0,address:" + addr + " && hyprctl dispatch resizewindowpixel exact 50% 100%,address:" + addr + " && hyprctl dispatch movewindowpixel exact 50% 0,address:" + addr];
                            _tileProc.running = true;
                            tiled = true;
                        }
                    }
                }

                if (!tiled && root.appId) {
                    root.reorderRequested(gp.x, root.appId);
                }
            }
        }
        onCentroidChanged: _dragPos = centroid.position
    }

    Process { id: _tileProc }

    property bool dropHovered: false

    DropArea {
        anchors.fill: parent
        enabled: true

        onEntered: function(drag) {
            root.dropHovered = true;
            drag.accepted = true;
        }

        onExited: {
            root.dropHovered = false;
        }

        onDropped: function(drop) {
            root.dropHovered = false;
            // External file drop → open in this app
            if (drop.hasUrls) {
                var urls = [];
                for (var i = 0; i < drop.urls.length; i++) {
                    urls.push(drop.urls[i].toString().replace(/^file:\/\//, ""));
                }
                if (urls.length > 0) {
                    DockService.launchWithFiles(root.itemData, urls);
                }
                drop.acceptProposedAction();
                return;
            }
        }
    }

    // ── Mouse interaction ────────────────────────────────────
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) root._pressScale = DesignTokens.pressedScale;
        }
        onReleased: function(mouse) { root._pressScale = 1.0; }
        onCanceled: { root._pressScale = 1.0; }

        onClicked: function(mouse) {
            root._pressScale = 1.0;
            root._justClicked = true;
            justClickedTimer.restart();
            if (mouse.button === Qt.RightButton) root.rightClicked(mouse.x, mouse.y, !!(mouse.modifiers & Qt.ShiftModifier));
            else if (mouse.button === Qt.MiddleButton) {
                if (mouse.modifiers & Qt.AltModifier)
                    root.peekRequested(root.appId, true);
                else
                    root.middleClicked();
            }
            else { ripple.fire(); root.clicked(); }
        }

        onContainsMouseChanged: {
            root.hovered(containsMouse);
            // Deactivate peek when mouse leaves
            if (!containsMouse && root.running) root.peekRequested(root.appId, false);
        }

        onWheel: function(wheel) {
            // Ignore horizontal scroll (3-finger left/right swipe for workspace change)
            if (Math.abs(wheel.angleDelta.y) > Math.abs(wheel.angleDelta.x))
                root.wheelScrolled(wheel.angleDelta.y > 0 ? -1 : 1);
        }
    }
}
