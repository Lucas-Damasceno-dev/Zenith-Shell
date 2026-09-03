import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../core"
import "../../../shared"
import "../../../services"

/**
 * BarPrivacyIndicator - Indicador moderno e multi-dispositivo de privacidade (Mic, Câmera, Screencast/Gravação).
 * Inspirado nos padrões Caelestia/DMS/macOS:
 * - Microfone: Âmbar / Laranja (#f59e0b)
 * - Câmera: Verde Esmeralda (#10b981)
 * - Tela/Gravação: Vermelho (#ef4444)
 * - Gestos: Botão Direito (Mudar Mudo Mic), Botão Meio (Parar Gravações).
 */
Item {
    id: root

    required property color accentColor
    required property color textColor
    property bool anyPopupOpen: false

    // Visibilidade dinâmica
    visible: PrivacyService.anyActive

    implicitWidth: visible ? (pillContainer.width + 4) : 0
    implicitHeight: DesignTokens.barItemHeight
    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion

    Behavior on implicitWidth {
        enabled: !root.reducedEffects
        NumberAnimation {
            duration: DesignTokens.durationNormal
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: pillContainer
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        height: parent.height - 4
        width: Math.max(34, contentRow.width + DesignTokens.spacingSM * 2)

        radius: height / 2
        color: ColorScheme.withAlpha(ColorScheme.surface, 0.25)
        border.width: 1
        border.color: {
            if (PrivacyService.screenShareActive) return ColorScheme.withAlpha(ColorScheme.red, 0.45);
            if (PrivacyService.cameraActive) return ColorScheme.withAlpha(ColorScheme.green, 0.45);
            if (PrivacyService.micActive) return ColorScheme.withAlpha(ColorScheme.warning || ColorScheme.yellow, 0.45);
            return ColorScheme.glassBorder;
        }

        Behavior on border.color {
            enabled: !root.reducedEffects
            ColorAnimation { duration: 150 }
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: DesignTokens.spacingXS

            // ── 🎤 Microfone ──────────────────────────────────────────
            Row {
                id: micChip
                visible: PrivacyService.micActive
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "\u{f130}"
                    font.family: DesignTokens.fontFamilyMono
                    font.pixelSize: 13
                    color: ColorScheme.warning || "#f59e0b"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    visible: PrivacyService.activeCount === 1 && PrivacyService.micApps.length > 0
                    text: PrivacyService.micAppsText
                    font.family: DesignTokens.fontFamilyUI
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: ColorScheme.warning || "#f59e0b"
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Separador sutil se múltiplos ativos
            Rectangle {
                visible: PrivacyService.micActive && (PrivacyService.cameraActive || PrivacyService.screenShareActive)
                width: 1
                height: 12
                color: ColorScheme.withAlpha(ColorScheme.foreground, 0.20)
                anchors.verticalCenter: parent.verticalCenter
            }

            // ── 📷 Câmera ────────────────────────────────────────────
            Row {
                id: camChip
                visible: PrivacyService.cameraActive
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "\u{f030}"
                    font.family: DesignTokens.fontFamilyMono
                    font.pixelSize: 13
                    color: ColorScheme.green || "#10b981"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    visible: PrivacyService.activeCount === 1 && PrivacyService.cameraApps.length > 0
                    text: PrivacyService.cameraAppsText
                    font.family: DesignTokens.fontFamilyUI
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: ColorScheme.green || "#10b981"
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Separador sutil se câmera + tela
            Rectangle {
                visible: PrivacyService.cameraActive && PrivacyService.screenShareActive
                width: 1
                height: 12
                color: ColorScheme.withAlpha(ColorScheme.foreground, 0.20)
                anchors.verticalCenter: parent.verticalCenter
            }

            // ── 🖥️ Gravação / Tela (REC) ──────────────────────────────
            Row {
                id: screenChip
                visible: PrivacyService.screenShareActive
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "\u{f03d}"
                    font.family: DesignTokens.fontFamilyMono
                    font.pixelSize: 13
                    color: ColorScheme.red || "#ef4444"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "REC"
                    font.family: DesignTokens.fontFamilyUI
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: ColorScheme.red || "#ef4444"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        MouseArea {
            id: privacyMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    PrivacyService.toggleMicMute();
                    return;
                }
                if (mouse.button === Qt.MiddleButton) {
                    PrivacyService.stopRecordings();
                    return;
                }
                PrivacyService.refresh();
            }
        }
    }
}
