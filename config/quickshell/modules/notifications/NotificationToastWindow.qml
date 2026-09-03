import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../../core"
import "../../shared"

PanelWindow {
    id: root

    property var notificationCenter
    property bool useAtmosphereBackdrop: false
    property string atmosphereSource: ""

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"
    // Only map surface when there are active toasts to save compositor blur & composition
    readonly property bool hasActiveToasts: !!(notificationCenter && notificationCenter.activeToastCount > 0)
    visible: hasActiveToasts && !(notificationCenter && notificationCenter.isOpen)
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-tooltip"

    // Click-through outside toasts
    mask: Region { item: inputRegion }

    function timeoutForUrgency(urgency) {
        if (urgency === NotificationUrgency.Critical) return 0; // Sticky (never auto-dismiss)
        if (urgency === NotificationUrgency.Low) return 3000;
        return 5500;
    }

    function urgencyColor(urgency) {
        if (urgency === NotificationUrgency.Critical) return ColorScheme.red;
        if (urgency === NotificationUrgency.Low) return ColorScheme.withAlpha(ColorScheme.accent, 0.55);
        return ColorScheme.accent;
    }

    Item {
        id: overlayRoot
        anchors.fill: parent

        Item {
            id: toastHost
            width: 420
            height: Math.max(320, Math.round((overlayRoot.height || 1080) * 0.80))
            anchors.top: parent.top
            anchors.topMargin: (FeatureFlags.barCompactMode ? DesignTokens.barCompactHeight : DesignTokens.barExpandedHeight) + DesignTokens.spacingLG
            anchors.horizontalCenter: parent.horizontalCenter

            ListView {
                id: toastList
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 10
                anchors.bottomMargin: 8
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: FeatureFlags.lowPowerUiMode ? 48 : 96
                model: root.notificationCenter ? root.notificationCenter.toastEntries : null
                verticalLayoutDirection: ListView.TopToBottom

                add: Transition {
                    enabled: !FeatureFlags.reducedMotion
                    ParallelAnimation {
                        NumberAnimation { properties: "y"; from: -20; to: 0; duration: 220; easing.type: Easing.OutCubic }
                        NumberAnimation { properties: "opacity"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                    }
                }
                displaced: Transition {
                    enabled: !FeatureFlags.reducedMotion
                    NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutCubic }
                }
                remove: Transition {
                    enabled: !FeatureFlags.reducedMotion
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "y"; to: -20; duration: 150; easing.type: Easing.OutCubic }
                    }
                }
                removeDisplaced: Transition {
                    enabled: !FeatureFlags.reducedMotion
                    NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: toastDelegate

                    required property int entryId
                    required property string appName
                    required property string summary
                    required property string body
                    required property int urgency
                    required property bool toastVisible
                    required property string appIcon
                    required property string image
                    property var actions: []

                    readonly property string effectiveAppName: {
                        var a = String(toastDelegate.appName || "").trim();
                        if (a !== "" && a !== "Unknown" && a.toLowerCase() !== "notify-send") return a;
                        var s = String(toastDelegate.summary || "").trim();
                        if (s !== "" && s.length < 32) return s;
                        return "Sistema";
                    }

                    readonly property bool isSystemSender: {
                        var a = effectiveAppName.toLowerCase();
                        return a === "hyprland" || a === "do not disturb" || a === "energy core" || a === "sistema" || a === "system" || a === "quickshell" || a === "notify-send" || a === "wallpaper engine";
                    }

                    readonly property string effectiveIconSource: {
                        var ico = String(toastDelegate.appIcon || "").trim();
                        if (ico !== "" && (ico.indexOf("/") >= 0 || (!isSystemSender && ico !== "dnd"))) return ico;
                        var img = String(toastDelegate.image || "").trim();
                        if (img !== "") return img;
                        if (!isSystemSender && effectiveAppName !== "" && effectiveAppName !== "Sistema") return effectiveAppName;
                        return "";
                    }

                    readonly property string effectiveLabel: {
                        if (!isSystemSender && effectiveAppName !== "" && effectiveAppName !== "Sistema") return effectiveAppName;
                        var s = String(toastDelegate.summary || "").trim();
                        if (s !== "" && s.length < 32) return s;
                        return effectiveAppName;
                    }

                    readonly property string effectiveContext: {
                        var a = String(toastDelegate.appName || "").trim();
                        var s = String(toastDelegate.summary || "").trim();
                        var b = String(toastDelegate.body || "").trim();
                        return (a + " " + s + " " + b).trim();
                    }

                    readonly property bool isCritical: urgency === NotificationUrgency.Critical
                    readonly property int totalTimeout: root.timeoutForUrgency(urgency)
                    property real life: 1.0
                    property bool closing: false
                    property bool dismissMode: false
                    property bool isHovered: cardMouse.containsMouse || closeMa.containsMouse

                    visible: toastVisible
                    width: ListView.view ? ListView.view.width : 376
                    implicitHeight: visible ? (toastCard.implicitHeight + 6) : 0
                    height: implicitHeight
                    opacity: visible ? 1.0 : 0.0
                    scale: closing ? 0.98 : 1.0
                    x: 0

                    Behavior on scale {
                        enabled: !FeatureFlags.reducedMotion
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }

                    function startClose(dismiss) {
                        if (closing || !toastVisible) return;
                        closing = true;
                        dismissMode = dismiss === true;
                        lifeTimer.stop();
                        closeAnim.start();
                    }

                    // Hover-pause timer: decrements life smoothly and freezes when hovered or critical
                    Timer {
                        id: lifeTimer
                        interval: 50
                        repeat: true
                        running: toastDelegate.visible && !toastDelegate.closing && !toastDelegate.isHovered && !toastDelegate.isCritical && toastDelegate.totalTimeout > 0
                        onTriggered: {
                            toastDelegate.life -= (50 / toastDelegate.totalTimeout);
                            if (toastDelegate.life <= 0) {
                                lifeTimer.stop();
                                toastDelegate.startClose(false);
                            }
                        }
                    }

                    Rectangle {
                        id: toastCard
                        width: parent.width
                        implicitHeight: Math.max(76, mainLayout.implicitHeight + 20)
                        radius: 14
                        color: ColorScheme.withAlpha(ColorScheme.background, 0.88)
                        border.color: toastDelegate.isCritical ? ColorScheme.red : ColorScheme.withAlpha(root.urgencyColor(urgency), 0.45)
                        border.width: toastDelegate.isCritical ? 1.5 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: ColorScheme.withAlpha(root.urgencyColor(urgency), 0.09) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 2
                            radius: parent.radius
                            color: Qt.rgba(0, 0, 0, 0.16)
                            z: -1
                        }

                        // Critical urgency accent stripe
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 1
                            anchors.topMargin: 6
                            anchors.bottomMargin: 6
                            width: 3.5
                            radius: 1.75
                            visible: toastDelegate.isCritical
                            color: ColorScheme.red
                        }

                        // Main Card Content Layout
                        ColumnLayout {
                            id: mainLayout
                            anchors.left: parent.left
                            anchors.right: closeBtn.left
                            anchors.top: parent.top
                            anchors.leftMargin: 14
                            anchors.rightMargin: 8
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                // App Icon Chip
                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    Layout.alignment: Qt.AlignTop
                                    radius: 10
                                    color: ColorScheme.withAlpha(toastIcon.fallbackColor, 0.14)
                                    border.color: ColorScheme.withAlpha(toastIcon.fallbackColor, 0.28)
                                    border.width: 1
                                    clip: true

                                    SmartIcon {
                                        id: toastIcon
                                        anchors.centerIn: parent
                                        size: 22
                                        source: toastDelegate.effectiveIconSource
                                        label: toastDelegate.effectiveLabel
                                        context: toastDelegate.effectiveContext
                                        fallbackIcon: "\u{f0f3}"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: toastDelegate.effectiveAppName
                                            color: ColorScheme.withAlpha(ColorScheme.accent, 0.90)
                                            font.pixelSize: 10
                                            font.bold: true
                                            font.family: DesignTokens.fontFamilyUI
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            visible: toastDelegate.isCritical
                                            Layout.preferredWidth: critBadge.implicitWidth + 8
                                            Layout.preferredHeight: 14
                                            radius: 7
                                            color: ColorScheme.withAlpha(ColorScheme.red, 0.25)
                                            border.color: ColorScheme.red
                                            border.width: 1

                                            Text {
                                                id: critBadge
                                                anchors.centerIn: parent
                                                text: "CRÍTICO"
                                                color: ColorScheme.red
                                                font.pixelSize: 8
                                                font.bold: true
                                                font.family: DesignTokens.fontFamilyUI
                                            }
                                        }

                                        Text {
                                            text: "agora"
                                            color: ColorScheme.withAlpha(ColorScheme.text, 0.45)
                                            font.pixelSize: 9
                                            font.family: DesignTokens.fontFamilyUI
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: toastDelegate.summary || "Notificação"
                                        color: ColorScheme.text
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: DesignTokens.fontFamilyUI
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: toastDelegate.body || ""
                                visible: text !== ""
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.75)
                                font.pixelSize: 11
                                font.family: DesignTokens.fontFamilyUI
                                wrapMode: Text.Wrap
                                maximumLineCount: toastDelegate.isHovered ? 6 : 3
                                elide: Text.ElideRight
                                lineHeight: 1.15
                            }

                            // Dynamic Action Chips
                            Row {
                                id: actionsRow
                                Layout.fillWidth: true
                                spacing: 6
                                visible: toastDelegate.actions && toastDelegate.actions.length > 0
                                Layout.topMargin: 4

                                Repeater {
                                    model: toastDelegate.actions || []
                                    delegate: Rectangle {
                                        implicitWidth: actionLabel.implicitWidth + 16
                                        implicitHeight: 24
                                        radius: 12
                                        color: actionMa.containsMouse
                                            ? ColorScheme.accent
                                            : ColorScheme.withAlpha(ColorScheme.surface, 0.45)
                                        border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.3)
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Text {
                                            id: actionLabel
                                            anchors.centerIn: parent
                                            text: modelData.text || modelData.identifier || "Ação"
                                            color: actionMa.containsMouse ? ColorScheme.background : ColorScheme.accent
                                            font.pixelSize: 10
                                            font.bold: true
                                            font.family: DesignTokens.fontFamilyUI
                                        }

                                        MouseArea {
                                            id: actionMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData && modelData.invoke) modelData.invoke();
                                                if (root.notificationCenter) root.notificationCenter.markRead(toastDelegate.entryId);
                                                toastDelegate.startClose(false);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Life progress bar (pauses on hover)
                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 1
                            anchors.bottomMargin: 1
                            width: (parent.width - 2) * Math.max(0.0, Math.min(1.0, toastDelegate.life))
                            height: 2
                            radius: 1
                            visible: !toastDelegate.isCritical && toastDelegate.totalTimeout > 0
                            color: root.urgencyColor(urgency)

                            // Glow indicator on active life edge
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 5
                                radius: 2.5
                                color: root.urgencyColor(urgency)
                                opacity: 0.5
                                visible: toastDelegate.life > 0.02 && toastDelegate.life < 0.98
                            }
                        }

                        // Close button (X)
                        Item {
                            id: closeBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.top: parent.top
                            anchors.topMargin: 6
                            width: 24
                            height: 24
                            z: 2

                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: closeMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.red, 0.2) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f00d}"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    color: closeMa.containsMouse ? ColorScheme.red : ColorScheme.withAlpha(ColorScheme.text, 0.64)
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }

                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                acceptedButtons: Qt.LeftButton
                                onPressed: mouse.accepted = true
                                onClicked: {
                                    toastDelegate.startClose(true);
                                }
                            }
                        }

                        // Card mouse area: Left click (default action/open), Middle click (instant dismiss)
                        MouseArea {
                            id: cardMouse
                            z: 0
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.MiddleButton) {
                                    toastDelegate.startClose(true);
                                    return;
                                }
                                if (toastDelegate.actions && toastDelegate.actions.length > 0) {
                                    var action = toastDelegate.actions[0];
                                    if (action && action.invoke) action.invoke();
                                }
                                if (root.notificationCenter) root.notificationCenter.markRead(toastDelegate.entryId);
                                toastDelegate.startClose(false);
                            }
                        }
                    }

                    SequentialAnimation {
                        id: closeAnim
                        running: false

                        ParallelAnimation {
                            NumberAnimation { target: toastDelegate; property: "opacity"; to: 0.0; duration: 160; easing.type: Easing.InCubic }
                            NumberAnimation { target: toastDelegate; property: "y"; to: -10; duration: 160; easing.type: Easing.InCubic }
                        }

                        ScriptAction {
                            script: {
                                if (!root.notificationCenter) return;
                                if (toastDelegate.dismissMode) root.notificationCenter.dismissEntry(entryId);
                                else root.notificationCenter.markToastConsumed(entryId);
                            }
                        }
                    }
                }
            }

            Item {
                id: inputRegion
                x: toastList.x
                y: toastList.y
                width: toastList.width
                height: Math.min(
                    toastList.height,
                    Math.max(0, toastList.contentHeight + toastList.spacing)
                )
            }
        }
    }
}
