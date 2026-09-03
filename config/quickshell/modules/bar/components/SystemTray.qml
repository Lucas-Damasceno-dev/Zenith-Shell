import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../../../core"
import "../../../core/TrayIconUtils.js" as TrayIconUtils

RowLayout {
    id: root
    spacing: DesignTokens.spacingXXS
    Layout.alignment: Qt.AlignVCenter

    property color iconColor: ColorScheme.accent
    property bool isOpen: true
    property bool _triggerHover: false
    readonly property real trayIconScale: 1.14
    readonly property int trayIconSize: 18
    readonly property int delegateSize: 26

    function shouldShowItem(item) {
        if (!item) return false;
        var id = String(item.id || "").toLowerCase();
        var title = String(item.title || item.tooltipTitle || "").toLowerCase();
        // Hide duplicate network tray item; network is already surfaced by BarNetworkStatus.
        if (id.indexOf("nm-applet") >= 0 || id.indexOf("networkmanager") >= 0) return false;
        if (title.indexOf("network") >= 0 || title.indexOf("wi-fi") >= 0 || title.indexOf("wifi") >= 0) return false;
        if (id.indexOf("kdeconnect") >= 0) return false;
        return true;
    }

    property int visibleItemCount: 0
    property int attentionCount: 0
    readonly property bool hasVisibleItems: visibleItemCount > 0
    readonly property bool hasAttentionItem: attentionCount > 0

    function updateStats() {
        var visibleCount = 0;
        var urgentCount = 0;
        for (var i = 0; i < trayRepeater.count; i++) {
            var item = trayRepeater.itemAt(i);
            if (item && item.isItemVisible) {
                visibleCount++;
                if (item.needsAttention) urgentCount++;
            }
        }
        root.visibleItemCount = visibleCount;
        root.attentionCount = urgentCount;
    }

    Timer {
        id: statsDebounce
        interval: 30
        repeat: false
        onTriggered: root.updateStats()
    }

    visible: hasVisibleItems

    // ── 1. Gatilho Estilizado (Pill Chevron com Indicador de Atenção) ───
    Item {
        id: triggerPill
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: width
        Layout.preferredHeight: height
        width: 26
        height: 26

        Rectangle {
            id: triggerBg
            anchors.fill: parent
            radius: height / 2
            color: root.isOpen
                ? ColorScheme.withAlpha(root.iconColor, 0.22)
                : (root.hasAttentionItem
                    ? ColorScheme.withAlpha(ColorScheme.warning || "#f59e0b", 0.20)
                    : (root._triggerHover ? ColorScheme.glassHover : "transparent"))
            border.width: 1
            border.color: root.isOpen
                ? ColorScheme.withAlpha(root.iconColor, 0.35)
                : (root.hasAttentionItem
                    ? ColorScheme.withAlpha(ColorScheme.warning || "#f59e0b", 0.60)
                    : (root._triggerHover ? ColorScheme.glassBorder : "transparent"))

            Behavior on color { ColorAnimation { duration: DesignTokens.durationFast } }
            Behavior on border.color { ColorAnimation { duration: DesignTokens.durationFast } }
        }

        Text {
            id: triggerGlyph
            anchors.centerIn: parent
            text: "\u{f053}" // FontAwesome / Nerd Font chevron-left
            font.family: DesignTokens.fontFamilyMono
            font.pixelSize: 11
            color: root.hasAttentionItem && !root.isOpen
                ? (ColorScheme.warning || "#f59e0b")
                : (root.isOpen ? root.iconColor : ColorScheme.withAlpha(ColorScheme.foreground, 0.75))
            renderType: Text.NativeRendering

            rotation: root.isOpen ? 180 : 0
            Behavior on rotation {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }

        // Ponto pulsante / indicador quando houver item que precisa de atenção e o tray estiver fechado
        Rectangle {
            id: attentionBadge
            visible: root.hasAttentionItem && !root.isOpen
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.rightMargin: 1
            width: 7
            height: 7
            radius: 3.5
            color: ColorScheme.warning || "#f59e0b"
            border.width: 1
            border.color: ColorScheme.background

            SequentialAnimation on opacity {
                running: attentionBadge.visible
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.35; duration: 750; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.35; to: 1.0; duration: 750; easing.type: Easing.InOutQuad }
            }
        }

        MouseArea {
            id: triggerMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root._triggerHover = true
            onExited: root._triggerHover = false
            onClicked: {
                root._triggerHover = false;
                root.isOpen = !root.isOpen;
            }
        }
    }

    // ── 2. Gaveta de Itens (Drawer com Animação Suave) ─────────────────
    Rectangle {
        id: drawer
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: height
        height: 28
        color: ColorScheme.withAlpha(ColorScheme.surface, 0.20)
        radius: height / 2
        border.width: root.isOpen ? 1 : 0
        border.color: ColorScheme.glassBorder
        clip: true

        implicitWidth: root.isOpen ? (trayRow.implicitWidth + DesignTokens.spacingXS * 2) : 0
        opacity: root.isOpen ? 1.0 : 0.0

        Behavior on implicitWidth {
            NumberAnimation { duration: DesignTokens.durationNormal; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: DesignTokens.durationFast; easing.type: Easing.OutCubic }
        }

        Row {
            id: trayRow
            anchors.left: parent.left
            anchors.leftMargin: DesignTokens.spacingXS
            anchors.verticalCenter: parent.verticalCenter
            spacing: DesignTokens.spacingXXS

            Repeater {
                id: trayRepeater
                model: SystemTray.items

                onCountChanged: statsDebounce.restart()

                delegate: Item {
                    id: trayDelegate
                    readonly property var itemData: modelData
                    readonly property bool isItemVisible: root.shouldShowItem(itemData)
                    readonly property bool needsAttention: isItemVisible && itemData && (itemData.status === 2 || String(itemData.status || "").indexOf("NeedsAttention") >= 0)

                    property string primaryIconSource: TrayIconUtils.primaryIconSource(itemData)
                    property string fallbackIconSource: TrayIconUtils.fallbackSource(itemData)
                    property string fallbackGlyph: TrayIconUtils.fallbackGlyph(itemData)
                    property bool useFallbackIcon: false
                    property bool iconLoadFailed: false

                    onPrimaryIconSourceChanged: {
                        useFallbackIcon = primaryIconSource === "";
                        iconLoadFailed = false;
                    }

                    onIsItemVisibleChanged: statsDebounce.restart()
                    onNeedsAttentionChanged: statsDebounce.restart()

                    visible: isItemVisible && root.isOpen
                    width: (isItemVisible && root.isOpen) ? root.delegateSize : 0
                    height: isItemVisible ? root.delegateSize : 0
                    transformOrigin: Item.Center

                    Component.onCompleted: {
                        useFallbackIcon = primaryIconSource === "";
                        statsDebounce.restart();
                    }
                    Component.onDestruction: {
                        statsDebounce.restart();
                    }

                    QsMenuAnchor {
                        id: trayContextMenu
                        menu: itemData && itemData.hasMenu ? itemData.menu : null
                        anchor.item: trayDelegate
                    }

                    // Fundo de Hover e Destaque
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: trayDelegate.needsAttention
                            ? ColorScheme.withAlpha(ColorScheme.warning || "#f59e0b", 0.25)
                            : (itemMouse.containsMouse ? ColorScheme.glassHover : "transparent")
                        border.width: trayDelegate.needsAttention ? 1 : 0
                        border.color: ColorScheme.withAlpha(ColorScheme.warning || "#f59e0b", 0.6)

                        Behavior on color { ColorAnimation { duration: DesignTokens.durationFast } }
                    }

                    // Container do Ícone com Micro-interação de Escala
                    Item {
                        id: iconContainer
                        anchors.centerIn: parent
                        width: root.trayIconSize
                        height: root.trayIconSize
                        scale: itemMouse.pressed ? 0.90 : (itemMouse.containsMouse ? root.trayIconScale : 1.0)

                        Behavior on scale {
                            NumberAnimation { duration: 75; easing.type: Easing.OutCubic }
                        }

                        Image {
                            id: trayIcon
                            anchors.fill: parent
                            source: trayDelegate.useFallbackIcon ? trayDelegate.fallbackIconSource : trayDelegate.primaryIconSource
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: root.trayIconSize * 2
                            sourceSize.height: root.trayIconSize * 2
                            asynchronous: true
                            smooth: true
                            visible: status === Image.Ready
                            opacity: itemMouse.containsMouse ? 1.0 : (trayDelegate.needsAttention ? 1.0 : 0.88)

                            Behavior on opacity { NumberAnimation { duration: DesignTokens.durationFast } }

                            onStatusChanged: {
                                if (status === Image.Ready) {
                                    trayDelegate.iconLoadFailed = false;
                                    return;
                                }

                                if (status === Image.Error) {
                                    if (!trayDelegate.useFallbackIcon
                                            && trayDelegate.fallbackIconSource !== ""
                                            && trayDelegate.fallbackIconSource !== trayDelegate.primaryIconSource) {
                                        trayDelegate.useFallbackIcon = true;
                                        trayDelegate.iconLoadFailed = false;
                                    } else {
                                        trayDelegate.iconLoadFailed = true;
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: trayDelegate.iconLoadFailed
                            text: trayDelegate.fallbackGlyph
                            color: trayDelegate.needsAttention ? (ColorScheme.warning || "#f59e0b") : root.iconColor
                            font.family: DesignTokens.fontFamilyMono
                            font.pixelSize: 14
                            renderType: Text.NativeRendering
                            opacity: itemMouse.containsMouse ? 1.0 : 0.85
                        }

                        // Badge de atenção no próprio item
                        Rectangle {
                            visible: trayDelegate.needsAttention
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: -2
                            anchors.rightMargin: -2
                            width: 5
                            height: 5
                            radius: 2.5
                            color: ColorScheme.warning || "#f59e0b"
                        }
                    }

                    // Tratamento Completo de Eventos de Mouse (SNI Spec)
                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: (mouse) => {
                            if (!itemData) return;
                            if (mouse.button === Qt.LeftButton) {
                                if (typeof itemData.activate === "function") {
                                    itemData.activate();
                                }
                            } else if (mouse.button === Qt.MiddleButton) {
                                if (typeof itemData.secondaryActivate === "function") {
                                    itemData.secondaryActivate();
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                if (itemData.hasMenu && trayContextMenu.menu) {
                                    trayContextMenu.open();
                                } else if (typeof itemData.secondaryActivate === "function") {
                                    itemData.secondaryActivate();
                                }
                            }
                        }

                        onWheel: (wheel) => {
                            if (!itemData || typeof itemData.scroll !== "function") return;
                            var dy = wheel.angleDelta.y;
                            var dx = wheel.angleDelta.x;
                            if (dy !== 0) {
                                itemData.scroll(dy, false);
                            } else if (dx !== 0) {
                                itemData.scroll(dx, true);
                            }
                        }
                    }
                }
            }
        }
    }
}
