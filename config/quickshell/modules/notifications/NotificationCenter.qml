import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"

/**
 * NotificationCenter - Glassmorphic notification panel.
 *
 * Uses Quickshell.Services.Notifications.NotificationServer to
 * capture D-Bus notifications. The server must be instantiated
 * for Quickshell to become the notification daemon.
 */
AnimatedWindow {
    id: root

    anchors.top: true
    anchors.right: true

    implicitWidth: 350
    implicitHeight: 500

    glassRadius: 16
    glassBackground: ColorScheme.glassPopup
    glassBorderColor: ColorScheme.outlineVariant
    slideY: 10
    originY: 0.0
    originX: 1.0
    useAtmosphereBackdrop: !FeatureFlags.lowPowerUiMode && !FeatureFlags.reducedMotion
    atmosphereTintOpacity: 0.08
    atmosphereGlowOpacity: 0.70
    atmosphereNoiseOpacity: 0.024
    atmosphereVignetteOpacity: 0.05

    // ─── Notification Server ─────────────────────────────────────
    // Instantiating this makes Quickshell the notification daemon
    NotificationServer {
        id: notifServer
        keepOnReload: true
    }

    // Badge count for the bar
    property int unreadCount: notifServer.trackedNotifications.values.length

    // ─── Relative timestamp helper ──────────────────────────────
    function relativeTime(dt) {
        var _ = MinuteTicker.minuteStamp; // shared minute-aligned tick
        if (!dt) return "now";
        var now = new Date();
        var diff = Math.floor((now.getTime() - dt.getTime()) / 1000);
        if (diff < 60) return "now";
        if (diff < 3600) return Math.floor(diff / 60) + "m ago";
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago";
        return Math.floor(diff / 86400) + "d ago";
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: 52
        anchors.rightMargin: 12

        Rectangle {
            id: ncCard
            anchors.fill: parent
            radius: 18
            color: ColorScheme.withAlpha(ColorScheme.glassModal, 0.96)
            border.color: ColorScheme.glassBorder
            border.width: 1

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: ColorScheme.withAlpha(ColorScheme.accent, 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1
                radius: 18
                color: ColorScheme.glassHighlight
            }
        }

        Rectangle {
            anchors.fill: ncCard
            anchors.topMargin: DesignTokens.shadowPopup.offsetY
            radius: ncCard.radius
            color: Qt.rgba(0, 0, 0, DesignTokens.shadowPopup.alpha)
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Notifications"
                    color: ColorScheme.text
                    font.bold: true
                    font.pixelSize: DesignTokens.fontSizeLG
                    font.family: Style.fontUI
                }

                // Badge count
                Rectangle {
                    width: badgeText.implicitWidth + 12
                    height: 20
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.accent, 0.2)
                    visible: root.unreadCount > 0

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: root.unreadCount
                        color: ColorScheme.accent
                        font.pixelSize: 10
                        font.bold: true
                        font.family: Style.fontUI
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: clearLabel.implicitWidth + 16
                    implicitHeight: 26
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    z: 3
                    radius: 13
                    color: clearMa.containsMouse
                        ? ColorScheme.stateHover
                        : ColorScheme.glassCard
                    border.color: clearMa.containsMouse
                        ? ColorScheme.withAlpha(ColorScheme.red, 0.3)
                        : "transparent"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Clear All"
                        color: clearMa.containsMouse ? ColorScheme.red : Style.textSecondary
                        font.pixelSize: 11
                        font.family: Style.fontUI
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        acceptedButtons: Qt.LeftButton
                        onPressed: function(mouse) { mouse.accepted = true; }
                        onClicked: {
                            let notifs = notifServer.trackedNotifications.values;
                            for (let i = notifs.length - 1; i >= 0; i--) {
                                notifs[i].dismiss();
                            }
                        }
                    }
                }
            }

            ListView {
                id: notificationList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: notifServer.trackedNotifications
                spacing: 8
                clip: true
                cacheBuffer: FeatureFlags.lowPowerUiMode ? 140 : 240
                reuseItems: true

                // Reverse order: newest first
                verticalLayoutDirection: ListView.TopToBottom

                delegate: Rectangle {
                    id: notifItem
                    width: notificationList.width
                    height: notifContentCol.implicitHeight + 24
                    color: {
                        if (modelData.urgency === NotificationUrgency.Critical)
                            return ColorScheme.withAlpha(ColorScheme.red, 0.10);
                        if (modelData.urgency === NotificationUrgency.Low)
                            return ColorScheme.glassCard;
                        return ColorScheme.glassCard;
                    }
                    radius: 12
                    border.color: modelData.urgency === NotificationUrgency.Critical
                        ? ColorScheme.withAlpha(ColorScheme.red, 0.35)
                        : ColorScheme.glassBorder
                    border.width: 1

                    // Urgency accent stripe
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 1
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        width: 3
                        radius: 1.5
                        visible: modelData.urgency !== undefined
                            && modelData.urgency !== NotificationUrgency.Normal
                        color: modelData.urgency === NotificationUrgency.Critical
                            ? ColorScheme.red
                            : ColorScheme.withAlpha(ColorScheme.accent, 0.3)
                    }

                    // Cascade animation
                    opacity: 0
                    transform: Translate { id: notifTrans; x: 20 }
                    Component.onCompleted: notifEnterAnim.start()
                    ListView.onReused: {
                        notifItem.opacity = 0;
                        notifTrans.x = 20;
                        notifEnterAnim.restart();
                    }
                    ListView.onPooled: {
                        notifEnterAnim.stop();
                        notifItem.opacity = 0;
                        notifTrans.x = 20;
                    }

                    ParallelAnimation {
                        id: notifEnterAnim
                        NumberAnimation {
                            target: notifItem; property: "opacity"
                            to: 1; duration: 180; easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: notifTrans; property: "x"
                            to: 0; duration: 200; easing.type: Easing.OutCubic
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        // App icon
                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 10
                            color: ColorScheme.withAlpha(ColorScheme.accent, 0.08)

                            Image {
                                anchors.centerIn: parent
                                width: 22; height: 22
                                asynchronous: true
                                sourceSize.width: 44
                                sourceSize.height: 44
                                source: {
                                    let ico = modelData.appIcon || "";
                                    if (!ico || ico === "") return "image://icon/dialog-information";
                                    if (ico.startsWith("/")) return "file://" + ico;
                                    return "image://icon/" + ico;
                                }
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                            }
                        }

                        ColumnLayout {
                            id: notifContentCol
                            Layout.fillWidth: true
                            spacing: 2

                            // App name + time
                            RowLayout {
                                Layout.fillWidth: true
                            Text {
                                text: {
                                    var name = String(modelData.appName || "").trim();
                                    return name === "" ? "System" : name;
                                }
                                color: ColorScheme.accent
                                font.pixelSize: 10
                                font.bold: true
                                font.family: Style.fontUI
                                opacity: 0.8
                            }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.relativeTime(modelData.lastUpdated)
                                    color: Style.textTertiary
                                    font.pixelSize: 9
                                    font.family: Style.fontUI
                                }
                            }

                            Text {
                                text: {
                                    var sum = String(modelData.summary || "").trim();
                                    return sum === "" ? "Notification" : sum;
                                }
                                color: ColorScheme.text
                                font.bold: true
                                font.pixelSize: 12
                                font.family: Style.fontUI
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.body || ""
                                color: Style.textSecondary
                                font.pixelSize: 11
                                font.family: Style.fontUI
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                visible: text !== ""
                            }

                            // Action buttons
                            Row {
                                spacing: 6
                                visible: modelData.actions && modelData.actions.length > 0
                                Layout.topMargin: 4

                                Repeater {
                                    model: modelData.actions || []
                                    delegate: Rectangle {
                                        width: actionText.implicitWidth + 16
                                        height: 22
                                        radius: 6
                                        color: actionMa.containsMouse
                                            ? ColorScheme.withAlpha(ColorScheme.accent, 0.2)
                                            : ColorScheme.withAlpha(ColorScheme.surface, 0.5)
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Text {
                                            id: actionText
                                            anchors.centerIn: parent
                                            text: modelData.text || modelData.identifier || ""
                                            color: ColorScheme.accent
                                            font.pixelSize: 10
                                            font.family: Style.fontUI
                                        }

                                        MouseArea {
                                            id: actionMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: modelData.invoke()
                                        }
                                    }
                                }
                            }
                        }

                        // Dismiss button
                        Item {
                            width: 28; height: 28
                            Layout.alignment: Qt.AlignTop
                            z: 6

                            Rectangle {
                                anchors.fill: parent
                                radius: 14
                                color: dismissMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.red, 0.2) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f00d}"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    color: dismissMa.containsMouse ? ColorScheme.red : Style.textTertiary
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }

                            MouseArea {
                                id: dismissMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                acceptedButtons: Qt.LeftButton
                                onPressed: function(mouse) { mouse.accepted = true; }
                                onClicked: modelData.dismiss()
                            }
                        }
                        }
                    }
                }

                // Empty state
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: notificationList.count === 0

                    // Accent halo behind icon
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 52; height: 52

                        Rectangle {
                            anchors.centerIn: parent
                            width: 48; height: 48
                            radius: 24
                            color: ColorScheme.withAlpha(ColorScheme.accent, 0.08)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\u{f00c}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Style.iconSizeXL
                            color: ColorScheme.withAlpha(ColorScheme.accent, 0.55)
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "All caught up"
                        color: Style.textSecondary
                        font.pixelSize: DesignTokens.fontSizeMD
                        font.bold: true
                        font.family: Style.fontUI
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No new notifications"
                        color: Style.textTertiary
                        font.pixelSize: 11
                        font.family: Style.fontUI
                    }
                }
            }
        }
    }
