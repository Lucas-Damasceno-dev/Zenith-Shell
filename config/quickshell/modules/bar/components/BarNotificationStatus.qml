import QtQuick
import "../../../core"
import "../../../shared"

/**
 * BarNotificationStatus - Widget moderno, ultra-eficiente e responsivo de notificações.
 *
 * Melhorias implementadas:
 * 1. Zero conflito de animações com Behavior on color (performance 60/144 fps).
 * 2. Gestos completos no mouse: Esquerdo (Popup), Direito (DND toggle), Meio (Limpar todas).
 * 3. Badge integrada ao PillWidget nativo sem duplicação de nós no Scene Graph.
 * 4. Tooltip reativo e contextual com indicação de atalhos.
 * 5. Escalação visual de cores para DND e Alertas Críticos.
 */
PillWidget {
    id: root

    required property color accentColor
    required property color textColor
    required property var popupInstance

    readonly property int unreadCount: popupInstance && popupInstance.unreadCount !== undefined
        ? popupInstance.unreadCount : 0
    readonly property int criticalCount: popupInstance && popupInstance.criticalUnreadCount !== undefined
        ? popupInstance.criticalUnreadCount : 0
    readonly property bool muted: !!(popupInstance && popupInstance.muted === true)
    readonly property bool hasCritical: criticalCount > 0 || !!(popupInstance && popupInstance.hasCritical === true)

    // Sincronização de estado com PillWidget
    checked: ShellController.isPopupOpen(root.popupInstance)
    popupOpen: checked

    // Ícone semântico
    iconText: root.muted ? "\u{f1f6}" : "\u{f0f3}"
    iconFontFamily: DesignTokens.fontFamilyMono

    // Cores de estado semânticas
    iconColor: {
        if (root.muted) return ColorScheme.yellow;
        if (root.hasCritical && root.unreadCount > 0) return ColorScheme.red;
        if (root.unreadCount > 0) return root.accentColor;
        return ColorScheme.withAlpha(root.textColor, 0.75);
    }

    // Badge integrada nativa do PillWidget (sem duplicação de retângulos/textos)
    badgeText: root.unreadCount > 0 ? (root.unreadCount > 99 ? "99+" : String(root.unreadCount)) : ""
    badgeColor: root.hasCritical ? ColorScheme.red : ColorScheme.accent

    // Tooltip rico e contextual
    tooltipText: {
        var base = "";
        if (root.muted) {
            base = "Não Perturbe (DND) ativado";
        } else if (root.unreadCount === 0) {
            base = "Nenhuma notificação nova";
        } else if (root.hasCritical) {
            base = root.unreadCount + " notificações (" + root.criticalCount + " críticas)";
        } else {
            base = root.unreadCount + (root.unreadCount === 1 ? " notificação pendente" : " notificações pendentes");
        }
        return base + "\n• Botão Direito: alternar DND\n• Botão Meio: limpar notificações";
    }

    // Interações avançadas de Mouse
    mouseArea.acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    mouseArea.onClicked: (mouse) => {
        _realHover = false;
        if (mouse.button === Qt.RightButton) {
            root.toggleDnd();
            return;
        }
        if (mouse.button === Qt.MiddleButton) {
            root.clearOrMarkAllRead();
            return;
        }
        root.togglePopup();
    }

    function togglePopup() {
        ShellController.togglePopup(root, root.popupInstance);
    }

    function toggleDnd() {
        if (root.popupInstance && root.popupInstance.muted !== undefined) {
            root.popupInstance.muted = !root.popupInstance.muted;
        }
    }

    function clearOrMarkAllRead() {
        if (!root.popupInstance) return;
        if (typeof root.popupInstance.clearAllNotifications === "function") {
            root.popupInstance.clearAllNotifications();
        }
    }

    // Pulso de alerta crítico em camada de contorno isolada (não recalcula cores do ícone continuamente)
    Rectangle {
        id: criticalGlow
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.color: ColorScheme.red
        border.width: 1.5
        visible: root.hasCritical && !root.muted && root.unreadCount > 0
        opacity: 0.0

        SequentialAnimation on opacity {
            running: criticalGlow.visible && !(FeatureFlags.reducedMotion || FeatureFlags.lowPowerUiMode)
            loops: Animation.Infinite
            NumberAnimation { to: 0.7; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.0; duration: 500; easing.type: Easing.InOutSine }
        }
    }
}
