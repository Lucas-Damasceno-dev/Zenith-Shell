import Quickshell
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtCore
import "../core"
import "../shared"
import "../services"

PopupWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    showScrim: false
    glassRadius: 0
    glassBackground: "transparent"
    slideY: 12
    originY: 0.0
    originX: 1.0

    property real anchorX: -1
    property real popupMargin: DesignTokens.spacingLG
    property bool outsideCloseEnabled: false
    property var settingsStore

    Timer {
        id: closeEnableTimer
        interval: 140
        repeat: false
        onTriggered: root.outsideCloseEnabled = true
    }

    // Battery data from UPower
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: bat && bat.isPresent
    readonly property real pctRaw: hasBat ? Number(bat.percentage) : -1
    readonly property int pct: hasBat ? Math.round(Math.max(0, Math.min(100, pctRaw <= 1 ? pctRaw * 100 : pctRaw))) : -1
    readonly property bool charging: hasBat && bat.state === UPowerDeviceState.Charging
    readonly property bool discharging: hasBat && bat.state === UPowerDeviceState.Discharging
    readonly property bool hasTimeEstimate: hasBat && ((discharging && bat.timeToEmpty > 0) || (charging && bat.timeToFull > 0))
    readonly property real watts: hasBat ? Math.abs(bat.changeRate) : 0
    readonly property int healthPct: hasBat && bat.healthSupported ? Math.round(bat.healthPercentage) : (BatteryStatsService.healthPct >= 0 ? BatteryStatsService.healthPct : -1)
    readonly property int cycleCount: BatteryStatsService.cycleCount
    readonly property string wearText: BatteryStatsService.wearText
    readonly property string modelName: BatteryStatsService.modelName

    // Smooth animated percentage for the arc gauge
    property real animatedPct: pct >= 0 ? pct : 0
    Behavior on animatedPct {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    function notifyFeedback(summary, body) {
        feedbackProc.exec([
            "notify-send",
            "-a", "Energy Core",
            summary,
            body
        ]);
    }

    function timeStr(seconds) {
        if (seconds <= 0) return "";
        var h = Math.floor(seconds / 3600);
        var m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? (h + "h " + m + "min") : (m + " min");
    }

    // Power profile
    property string powerProfile: BatteryStatsService.powerProfile || ConfigFacade.batteryPowerProfile()
    property string _pendingPowerProfileKey: ""
    property string _pendingPowerProfileLabel: ""

    function loadBatteryPreferences() {
        if (!settingsStore || !settingsStore.ready || !settingsStore.get) return;
        if (ConfigFacade.batteryPrefsInitialized() !== true) return;

        root.powerProfile = BatteryStatsService.powerProfile || ConfigFacade.batteryPowerProfile();
    }

    function persistBatteryPreferences() {
        if (!settingsStore || !settingsStore.ready || !settingsStore.set) return;
        settingsStore.set("batteryPrefsInitialized", true);
        settingsStore.set("batteryPowerProfile", String(root.powerProfile || "balanced"));
        settingsStore.set("batteryLimitActive", BatteryStatsService.limitActive === true);
        settingsStore.set("batteryCaffeineActive", BatteryStatsService.caffeineActive === true);
    }

    // Caffeine (inhibit idle)
    readonly property bool caffeineActive: BatteryStatsService.caffeineActive
    readonly property bool limitActive: BatteryStatsService.limitActive
    TimedProcess { id: feedbackProc }

    onIsOpenChanged: {
        if (isOpen) { outsideCloseEnabled = false; closeEnableTimer.restart(); } else { outsideCloseEnabled = false; }
        if (isOpen) {
            Qt.callLater(function() {
                if (!root.isOpen)
                    return;
                root.loadBatteryPreferences();
                BatteryStatsService.detailsActive = true;
                BatteryStatsService.refreshPowerProfile();
                ScreenFilterService.refresh();
            });
        } else {
            BatteryStatsService.detailsActive = false;
        }
    }

    TimedProcess {
        id: ppSet
        onExited: {
            root._pendingPowerProfileKey = "";
            root._pendingPowerProfileLabel = "";
        }
        onFailed: function(exitCode) {
            BatteryStatsService.refreshPowerProfile();
            var failedLabel = root._pendingPowerProfileLabel ? (" " + root._pendingPowerProfileLabel) : "";
            root._pendingPowerProfileKey = "";
            root._pendingPowerProfileLabel = "";
            root.notifyFeedback("Perfil de energia", "Não foi possível aplicar" + failedLabel + ".");
        }
    }

    Connections {
        target: BatteryStatsService
        function onPowerProfileChanged() {
            root.powerProfile = BatteryStatsService.powerProfile;
            root.persistBatteryPreferences();
        }
    }

    Connections {
        target: root.settingsStore && root.settingsStore.ready !== undefined ? root.settingsStore : null
        function onReadyChanged() {
            if (root.settingsStore && root.settingsStore.ready)
                root.loadBatteryPreferences();
        }
    }

    Item {
        id: keyReceiver
        anchors.fill: parent
        focus: root.isOpen
        Keys.onEscapePressed: { root.isOpen = false; }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        onClicked: (mouse) => {
            var p = mapToItem(popupCard, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > popupCard.width || p.y > popupCard.height) {
                root.isOpen = false;
            }
        }
    }

    Item {
        id: popupCard
        width: 350
        height: Math.min(680, mainCol.implicitHeight + 32)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: popupTopMargin
        anchors.rightMargin: root.popupMargin
        z: 1

        Rectangle {
            id: popupBg
            anchors.fill: parent
            radius: 16
            color: ColorScheme.glassPopup
            border.color: ColorScheme.outlineVariant
            border.width: 1
        }

        ColumnLayout {
            id: mainCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // ─── Battery Header Card ──────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 84
                radius: DesignTokens.radiusMD
                color: root.hasBat && root.pct >= 0 && root.pct < 20
                    ? ColorScheme.withAlpha(ColorScheme.red, 0.08)
                    : ColorScheme.withAlpha(ColorScheme.surface, 0.20)
                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.05)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 300 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    // Arc gauge with smooth GPU Shape animation
                    Item {
                        id: arcGauge
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64

                        property color activeColor: !root.hasBat
                            ? ColorScheme.withAlpha(ColorScheme.text, 0.65)
                            : (root.pct > 80 ? ColorScheme.green : (root.pct > 40 ? ColorScheme.yellow : (root.pct > 20 ? ColorScheme.peach : ColorScheme.red)))

                        readonly property real clampedArc: Math.min(Math.max(0.0001, root.animatedPct / 100), 0.9995)

                        Shape {
                            anchors.fill: parent
                            antialiasing: true

                            // Track
                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: ColorScheme.withAlpha(ColorScheme.foreground, 0.08)
                                strokeWidth: 5
                                capStyle: ShapePath.RoundCap
                                startX: 32; startY: 7
                                PathArc { x: 32; y: 57; radiusX: 25; radiusY: 25; useLargeArc: true }
                                PathArc { x: 32; y: 7; radiusX: 25; radiusY: 25; useLargeArc: true }
                            }

                            // Value
                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: arcGauge.activeColor
                                strokeWidth: 5
                                capStyle: ShapePath.RoundCap
                                startX: 32; startY: 7
                                PathArc {
                                    x: 32 + 25 * Math.sin(arcGauge.clampedArc * 2 * Math.PI)
                                    y: 32 - 25 * Math.cos(arcGauge.clampedArc * 2 * Math.PI)
                                    radiusX: 25; radiusY: 25
                                    useLargeArc: arcGauge.clampedArc > 0.5
                                }
                            }
                        }

                        // Central Icon or Percentage
                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -1
                            text: root.charging ? "\u{f0e7}" : (root.hasBat ? root.pct + "" : "\u{f24e}")
                            font.family: root.charging ? "JetBrainsMono Nerd Font" : "Inter"
                            font.pixelSize: root.charging ? 18 : 13
                            font.bold: true
                            color: arcGauge.activeColor
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    // Main Status & Info
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        RowLayout {
                            spacing: 6
                            Text {
                                text: root.hasBat ? root.pct + "%" : "Alimentação AC"
                                color: ColorScheme.text
                                font.pixelSize: 20
                                font.bold: true
                                font.family: "Inter"
                            }
                            Rectangle {
                                visible: root.charging
                                width: 54; height: 18; radius: 9
                                color: ColorScheme.withAlpha(ColorScheme.teal, 0.20)
                                border.color: ColorScheme.withAlpha(ColorScheme.teal, 0.35)
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "Carga"
                                    color: ColorScheme.teal
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.family: "Inter"
                                }
                            }
                        }

                        Text {
                            text: !root.hasBat
                                ? "Conectado à tomada (Desktop / AC)"
                                : (root.charging
                                    ? (root.hasTimeEstimate ? (root.timeStr(root.bat ? root.bat.timeToFull : 0) + " até 100%") : "Carregando...")
                                    : (root.discharging
                                        ? (root.hasTimeEstimate ? (root.timeStr(root.bat ? root.bat.timeToEmpty : 0) + " restante") : "Em uso na bateria")
                                        : "Bateria carregada"))
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.60)
                            font.pixelSize: 11
                            font.family: "Inter"
                        }
                    }
                }
            }

            // ─── Stats Grid ──────────────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 6
                columnSpacing: 6
                visible: root.hasBat

                // Consumo (W)
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.04)
                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.04)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8
                        Text {
                            text: "\u{f0e7}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: ColorScheme.peach
                        }
                        ColumnLayout {
                            spacing: 1
                            Text { text: "Consumo"; font.pixelSize: 9; color: ColorScheme.withAlpha(ColorScheme.text, 0.50); font.family: "Inter" }
                            Text { text: root.watts.toFixed(1) + " W"; font.pixelSize: 12; font.bold: true; color: ColorScheme.text; font.family: "Inter" }
                        }
                    }
                }

                // Saúde / Degradação (%)
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.04)
                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.04)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8
                        Text {
                            text: "\u{f21e}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: root.healthPct >= 80 ? ColorScheme.green : (root.healthPct >= 65 ? ColorScheme.yellow : ColorScheme.red)
                        }
                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true
                            RowLayout {
                                Text { text: "Saúde"; font.pixelSize: 9; color: ColorScheme.withAlpha(ColorScheme.text, 0.50); font.family: "Inter" }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.healthPct >= 0 ? (root.healthPct + "%") : root.wearText
                                    font.pixelSize: 11; font.bold: true; color: ColorScheme.text; font.family: "Inter"
                                }
                            }
                            // Health mini bar
                            Rectangle {
                                Layout.fillWidth: true
                                height: 4
                                radius: 2
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                                Rectangle {
                                    width: parent.width * (Math.max(0, Math.min(100, root.healthPct >= 0 ? root.healthPct : 80)) / 100)
                                    height: parent.height
                                    radius: 2
                                    color: root.healthPct >= 80 ? ColorScheme.green : (root.healthPct >= 65 ? ColorScheme.yellow : ColorScheme.red)
                                }
                            }
                        }
                    }
                }

                // Ciclos
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.04)
                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.04)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8
                        Text {
                            text: "\u{f0e4}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: ColorScheme.accent
                        }
                        ColumnLayout {
                            spacing: 1
                            Text { text: "Ciclos de Carga"; font.pixelSize: 9; color: ColorScheme.withAlpha(ColorScheme.text, 0.50); font.family: "Inter" }
                            Text { text: root.cycleCount >= 0 ? String(root.cycleCount) : "N/A"; font.pixelSize: 12; font.bold: true; color: ColorScheme.text; font.family: "Inter" }
                        }
                    }
                }

                // Modelo
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.04)
                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.04)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8
                        Text {
                            text: "\u{f233}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: ColorScheme.teal
                        }
                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Text { text: "Bateria / Modelo"; font.pixelSize: 9; color: ColorScheme.withAlpha(ColorScheme.text, 0.50); font.family: "Inter" }
                            Text {
                                text: root.modelName !== "N/A" ? root.modelName : (root.bat ? (root.bat.model || "Integrada") : "Integrada")
                                font.pixelSize: 11; font.bold: true; color: ColorScheme.text; font.family: "Inter"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.06) }

            // ─── Brilho da Tela ──────────────────────────────────────────
            BrightnessSlider {
                Layout.fillWidth: true
                accentColor: ColorScheme.accent
                textColor: ColorScheme.text
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.06) }

            // ─── Perfis de Energia (Segmented Control Animado) ───────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "\u{f0e7}  Perfil de Energia"
                    color: ColorScheme.text
                    font.pixelSize: 11
                    font.family: "Inter"
                    font.weight: Font.Medium
                }

                Rectangle {
                    id: segmentTrack
                    Layout.fillWidth: true
                    height: 36
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.05)
                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.06)
                    border.width: 1

                    readonly property var profiles: [
                        { key: "power-saver", label: "Eco", icon: "\u{f06c}", color: ColorScheme.teal },
                        { key: "balanced", label: "Balanceado", icon: "\u{f24e}", color: ColorScheme.green },
                        { key: "performance", label: "Performance", icon: "\u{f0e7}", color: ColorScheme.accent }
                    ]

                    readonly property int activeIndex: {
                        if (root.powerProfile === "power-saver") return 0;
                        if (root.powerProfile === "performance") return 2;
                        return 1;
                    }

                    // Sliding Pill Indicator
                    Rectangle {
                        id: segmentPill
                        width: (parent.width - 6) / 3
                        height: parent.height - 6
                        y: 3
                        x: 3 + (root.powerProfile === "power-saver" ? 0 : (root.powerProfile === "performance" ? (width * 2) : width))
                        radius: 8
                        color: ColorScheme.withAlpha(segmentTrack.profiles[segmentTrack.activeIndex].color, 0.22)
                        border.color: segmentTrack.profiles[segmentTrack.activeIndex].color
                        border.width: 1

                        Behavior on x {
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Repeater {
                            model: segmentTrack.profiles
                            delegate: Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        text: modelData.icon
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: root.powerProfile === modelData.key ? modelData.color : ColorScheme.withAlpha(ColorScheme.text, 0.65)
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                    Text {
                                        text: modelData.label
                                        font.family: "Inter"
                                        font.pixelSize: 10
                                        font.bold: root.powerProfile === modelData.key
                                        color: root.powerProfile === modelData.key ? modelData.color : ColorScheme.withAlpha(ColorScheme.text, 0.65)
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.powerProfile = modelData.key;
                                        BatteryStatsService.setPowerProfile(modelData.key);
                                        root.persistBatteryPreferences();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.06) }

            // ─── Filtros de Tela (Luz Noturna & Escala de Cinza) ───────────
            SmartSlider {
                Layout.fillWidth: true
                icon: "\u{f186}"
                title: "Luz Noturna (Filtro Quente)"
                value: ScreenFilterService.nightLightValue
                accentColor: ColorScheme.peach
                onValueChangedByUser: (newVal) => ScreenFilterService.setNightLight(newVal)
                onResetRequested: ScreenFilterService.setNightLight(0)
            }

            SmartSlider {
                Layout.fillWidth: true
                icon: "\u{f042}"
                title: "Escala de Cinza (Foco)"
                value: ScreenFilterService.grayscaleValue
                accentColor: ColorScheme.text
                onValueChangedByUser: (newVal) => ScreenFilterService.setGrayscale(newVal)
                onResetRequested: ScreenFilterService.setGrayscale(0)
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.06) }

            // ─── Ações Rápidas & Saúde da Bateria ─────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Caffeinate Toggle
                Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 10
                    color: root.caffeineActive
                        ? ColorScheme.withAlpha(ColorScheme.peach, 0.18)
                        : ColorScheme.withAlpha(ColorScheme.text, 0.04)
                    border.color: root.caffeineActive ? ColorScheme.peach : ColorScheme.withAlpha(ColorScheme.text, 0.06)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6
                        Text {
                            text: "\u{f0f4}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: root.caffeineActive ? ColorScheme.peach : ColorScheme.withAlpha(ColorScheme.text, 0.60)
                        }
                        Text {
                            text: "Caffeinate"
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.bold: true
                            color: root.caffeineActive ? ColorScheme.peach : ColorScheme.text
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            width: 28; height: 16; radius: 8
                            color: root.caffeineActive ? ColorScheme.peach : ColorScheme.withAlpha(ColorScheme.text, 0.15)
                            Rectangle {
                                width: 12; height: 12; radius: 6
                                color: ColorScheme.text
                                x: root.caffeineActive ? parent.width - width - 2 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on x { NumberAnimation { duration: 160 } }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.caffeineActive) {
                                BatteryStatsService.startCaffeine();
                                root.notifyFeedback("Caffeinate", "Inibição de suspensão ativada");
                            } else {
                                BatteryStatsService.stopCaffeine();
                                root.notifyFeedback("Caffeinate", "Inibição de suspensão desativada");
                            }
                            BatteryStatsService.refreshCaffeine();
                            root.persistBatteryPreferences();
                        }
                    }
                }

                // Health Limit 80% Toggle
                Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 10
                    visible: root.hasBat
                    color: root.limitActive
                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.18)
                        : ColorScheme.withAlpha(ColorScheme.text, 0.04)
                    border.color: root.limitActive ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.06)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6
                        Text {
                            text: "\u{f21e}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: root.limitActive ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.60)
                        }
                        Text {
                            text: "Limite 80%"
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.bold: true
                            color: root.limitActive ? ColorScheme.accent : ColorScheme.text
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            width: 28; height: 16; radius: 8
                            color: root.limitActive ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.15)
                            Rectangle {
                                width: 12; height: 12; radius: 6
                                color: ColorScheme.text
                                x: root.limitActive ? parent.width - width - 2 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on x { NumberAnimation { duration: 160 } }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            BatteryStatsService.toggleLimit();
                            root.notifyFeedback("Saúde da Bateria", root.limitActive ? "Limite de carga 80% desativado" : "Limite de carga 80% ativado");
                            root.persistBatteryPreferences();
                        }
                    }
                }
            }
        }
    }
}
