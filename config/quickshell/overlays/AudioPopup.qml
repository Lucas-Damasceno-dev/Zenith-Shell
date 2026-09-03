import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../core"
import "../shared"
import "../services"
import "./AudioPopupUtils.js" as AudioPopupUtils

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
    readonly property bool hasPipewireSinks: {
        if (!Pipewire.nodes) return false;
        var allNodes = Pipewire.nodes.values || [];
        return allNodes.some(function(n) { return n && n.isSink && n.audio; });
    }
    readonly property bool hasPipewireSources: {
        if (!Pipewire.nodes) return false;
        var allNodes = Pipewire.nodes.values || [];
        return allNodes.some(function(n) { return n && !n.isSink && !n.isStream && n.audio && !AudioPopupUtils.isMonitorSource(n); });
    }
    readonly property int appStreamsCount: {
        if (!Pipewire.nodes) return 0;
        var allNodes = Pipewire.nodes.values || [];
        var count = 0;
        for (var i = 0; i < allNodes.length; i++) {
            var n = allNodes[i];
            if (n && n.isStream && n.audio) count++;
        }
        return count;
    }
    property var cliSinks: []
    property var cliSources: []
    readonly property bool usingCliFallback: Pipewire.ready && !hasPipewireSinks && !hasPipewireSources
    readonly property bool hasSinks: hasPipewireSinks || cliSinks.length > 0 || AudioStatusService.hasSinkReady
    readonly property bool hasSources: hasPipewireSources || cliSources.length > 0 || AudioStatusService.hasSourceReady

    function safeVolume(audioObj) {
        return AudioPopupUtils.safeVolume(audioObj);
    }

    function volumeIcon(vol, muted) {
        return AudioPopupUtils.volumeIcon(vol, muted);
    }

    function volumeIconSource(muted) {
        return muted ? "file://" + RuntimePaths.quickshellDir + "/shared/icons/mute.svg" : "file://" + RuntimePaths.quickshellDir + "/shared/icons/audio-output.svg";
    }

    function outputIconSource() {
        return "file://" + RuntimePaths.quickshellDir + "/shared/icons/audio-output.svg";
    }

    function inputIconSource() {
        return "file://" + RuntimePaths.quickshellDir + "/shared/icons/audio-input.svg";
    }

    function audioGlyph(muted) {
        return muted ? "\u{f026}" : "\u{f028}";
    }

    function microphoneGlyph(muted) {
        return muted ? "\u{f131}" : "\u{f130}";
    }

    function parseWpctlStatus(rawText) {
        var parsed = AudioPopupUtils.parseWpctlStatus(rawText);
        cliSinks = parsed.sinks;
        cliSources = parsed.sources;
    }

    function refreshCliAudioStatus() {
        cliAudioStatusProc.exec(["wpctl", "status"]);
        AudioStatusService.refreshCliStatus();
    }

    function setSinkVolumeRatio(value) {
        AudioStatusService.setSinkVolumeRatio(value);
    }

    function setSourceVolumeRatio(value) {
        AudioStatusService.setSourceVolumeRatio(value);
    }

    function toggleSinkMute() {
        AudioStatusService.toggleSinkMute();
    }

    function toggleSourceMute() {
        AudioStatusService.toggleSourceMute();
    }

    function setSinkDefaultById(idValue) {
        if (idValue === undefined || idValue === null) return;
        cliAudioActionProc.exec(["wpctl", "set-default", String(idValue)]);
    }

    function setSourceDefaultById(idValue) {
        if (idValue === undefined || idValue === null) return;
        cliAudioActionProc.exec(["wpctl", "set-default", String(idValue)]);
    }

    function defaultCliSink() {
        return AudioPopupUtils.defaultCliDevice(cliSinks);
    }

    function defaultCliSource() {
        return AudioPopupUtils.defaultCliDevice(cliSources);
    }

    function sinkPercent() {
        return AudioStatusService.volume;
    }

    function sourcePercent() {
        return AudioStatusService.sourceVolume;
    }

    function sinkMutedState() {
        return AudioStatusService.muted;
    }

    function sourceMutedState() {
        return AudioStatusService.sourceMuted;
    }

    function canUsePipewireSinkControl() {
        return AudioPopupUtils.canUsePipewireControl(Pipewire.ready, Pipewire.defaultAudioSink);
    }

    function canUsePipewireSourceControl() {
        return AudioPopupUtils.canUsePipewireControl(Pipewire.ready, Pipewire.defaultAudioSource);
    }

    readonly property var audioSources: {
        if (!Pipewire.nodes) return cliSources || [];
        var allNodes = Pipewire.nodes.values || [];
        var list = [];
        for (var i = 0; i < allNodes.length; i++) {
            var n = allNodes[i];
            if (n && !n.isSink && !n.isStream && n.audio && !AudioPopupUtils.isMonitorSource(n))
                list.push(n);
        }
        return list.length > 0 ? list : (cliSources || []);
    }

    function persistPreferredDevices() {
        if (!settingsStore || !settingsStore.ready || !root.isOpen) return;
        var sinkName = Pipewire.defaultAudioSink ? String((Pipewire.defaultAudioSink.properties && Pipewire.defaultAudioSink.properties["node.name"]) || Pipewire.defaultAudioSink.name || "") : "";
        var sourceName = Pipewire.defaultAudioSource ? String((Pipewire.defaultAudioSource.properties && Pipewire.defaultAudioSource.properties["node.name"]) || Pipewire.defaultAudioSource.name || "") : "";
        
        if (sinkName !== "" && settingsStore.get("audioPreferredSinkName", "") !== sinkName)
            settingsStore.set("audioPreferredSinkName", sinkName);
        if (sourceName !== "" && settingsStore.get("audioPreferredSourceName", "") !== sourceName)
            settingsStore.set("audioPreferredSourceName", sourceName);
    }

    function applyPreferredDevices() {
        if (!settingsStore || !settingsStore.ready) return;
        var prefSinkName = String(settingsStore.get("audioPreferredSinkName", "") || "");
        var prefSourceName = String(settingsStore.get("audioPreferredSourceName", "") || "");
        var allNodes = (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : [];
        
        if (prefSinkName !== "") {
            for (var i = 0; i < allNodes.length; i++) {
                var s = allNodes[i];
                if (!s || !s.isSink) continue;
                var sName = String((s.properties && s.properties["node.name"]) || s.name || "");
                if (sName === prefSinkName && typeof s.makeDefault === "function") {
                    var curSinkName = Pipewire.defaultAudioSink ? String((Pipewire.defaultAudioSink.properties && Pipewire.defaultAudioSink.properties["node.name"]) || Pipewire.defaultAudioSink.name || "") : "";
                    if (curSinkName !== prefSinkName) {
                        s.makeDefault();
                    }
                    break;
                }
            }
        }
        
        if (prefSourceName !== "") {
            for (var j = 0; j < allNodes.length; j++) {
                var src = allNodes[j];
                if (!src || src.isSink || src.isStream) continue;
                var srcName = String((src.properties && src.properties["node.name"]) || src.name || "");
                if (srcName === prefSourceName && typeof src.makeDefault === "function") {
                    var curSourceName = Pipewire.defaultAudioSource ? String((Pipewire.defaultAudioSource.properties && Pipewire.defaultAudioSource.properties["node.name"]) || Pipewire.defaultAudioSource.name || "") : "";
                    if (curSourceName !== prefSourceName) {
                        src.makeDefault();
                    }
                    break;
                }
            }
        }
    }

    Connections {
        target: Pipewire
        function onReadyChanged() {
            if (Pipewire.ready) {
                Qt.callLater(root.applyPreferredDevices);
                root.refreshCliAudioStatus();
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            if (Pipewire.ready) Qt.callLater(applyPreferredDevices);
            refreshCliAudioStatus();
        });
    }

    onIsOpenChanged: {
        if (isOpen) { outsideCloseEnabled = false; closeEnableTimer.restart(); } else { outsideCloseEnabled = false; }
        if (isOpen) {
            applyPreferredDevices();
            refreshCliAudioStatus();
        }
    }

    onSettingsStoreChanged: Qt.callLater(applyPreferredDevices)

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() { if (root.isOpen) root.persistPreferredDevices(); }
        function onDefaultAudioSourceChanged() { if (root.isOpen) root.persistPreferredDevices(); }
    }

    TimedProcess {
        id: cliAudioStatusProc
        stdout: StdioCollector {
            onStreamFinished: root.parseWpctlStatus(text)
        }
    }

    TimedProcess {
        id: cliAudioActionProc
        onExited: cliAudioRefreshDelay.restart()
    }

    Timer {
        id: cliAudioPollTimer
        interval: FeatureFlags.lowPowerUiMode ? 15000 : 8000
        repeat: true
        running: root.isOpen && (!Pipewire.ready || root.usingCliFallback)
        triggeredOnStart: true
        onTriggered: root.refreshCliAudioStatus()
    }

    Timer {
        id: cliAudioRefreshDelay
        interval: 350
        repeat: false
        onTriggered: root.refreshCliAudioStatus()
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        onClicked: (mouse) => {
            if (!root.outsideCloseEnabled) return;
            var p = mapToItem(popupCard, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > popupCard.width || p.y > popupCard.height) {
                root.isOpen = false;
            }
        }
    }

    property string activeTab: "all"

    Item {
        id: popupCard
        width: 370
        height: activeTab === "all" ? 600 : (activeTab === "mixer" ? 460 : 400)
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
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

        Flickable {
            anchors.fill: parent
            anchors.margins: 14
            contentHeight: mainCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                active: true
                width: 4
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: mainCol
                width: parent.width
                spacing: 14

                // ─── Header & Title ───────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "\u{f025} Controle de Áudio"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        font.bold: true
                        color: ColorScheme.text
                        Layout.fillWidth: true
                    }
                }

                // ─── Segmented Tabs ───────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { id: "all", label: "Tudo", icon: "\u{f009}" },
                            { id: "sink", label: "Saída", icon: "\u{f028}" },
                            { id: "source", label: "Microfone", icon: "\u{f130}" },
                            { id: "mixer", label: root.appStreamsCount > 0 ? ("Apps (" + root.appStreamsCount + ")") : "Apps", icon: "\u{f0550}" }
                        ]

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            radius: 14
                            readonly property bool isSelected: root.activeTab === modelData.id
                            color: isSelected
                                ? ColorScheme.withAlpha(ColorScheme.accent, 0.22)
                                : (tabMa.containsMouse ? ColorScheme.glassHover : ColorScheme.withAlpha(ColorScheme.surface, 0.20))
                            border.color: isSelected ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.08)
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: modelData.icon
                                    color: isSelected ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.75)
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                }

                                Text {
                                    text: modelData.label
                                    color: isSelected ? ColorScheme.text : ColorScheme.withAlpha(ColorScheme.text, 0.70)
                                    font.pixelSize: 10
                                    font.family: "Inter"
                                    font.bold: isSelected
                                }
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeTab = modelData.id
                            }
                        }
                    }
                }

                // ─── Section: Output (Sink) ───────────────────
                ColumnLayout {
                    id: sinkSection
                    Layout.fillWidth: true
                    spacing: 12
                    visible: root.activeTab === "all" || root.activeTab === "sink"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        DynamicIcon {
                            iconSource: root.outputIconSource()
                            iconColor: ColorScheme.accent
                            size: 16
                            sourceSize: 32
                            fallbackGlyph: root.audioGlyph(false)
                        }

                        Text {
                            text: "Saída de Áudio"
                            color: ColorScheme.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            font.family: "Inter"
                            font.letterSpacing: DesignTokens.letterSpacingLabel
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    // Main volume slider with step buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            width: 16
                            height: 16

                            SequentialAnimation {
                                id: sinkMutePulse
                                NumberAnimation { target: sinkMuteIconGraphic; property: "scale"; to: 1.12; duration: 100; easing.type: Easing.OutQuad }
                                NumberAnimation { target: sinkMuteIconGraphic; property: "scale"; to: 1.0; duration: 100; easing.type: Easing.InQuad }
                            }

                            DynamicIcon {
                                id: sinkMuteIconGraphic
                                anchors.fill: parent
                                iconSource: root.volumeIconSource(root.sinkMutedState())
                                iconColor: root.sinkMutedState() ? ColorScheme.red : ColorScheme.accent
                                fallbackGlyph: root.audioGlyph(root.sinkMutedState())
                                size: 16
                                sourceSize: 32
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { sinkMutePulse.start(); root.toggleSinkMute(); }
                            }
                        }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: stepSinkMinusMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.text, 0.15) : ColorScheme.withAlpha(ColorScheme.text, 0.08)
                            Text { anchors.centerIn: parent; text: "-"; color: ColorScheme.text; font.pixelSize: 13; font.bold: true }
                            MouseArea {
                                id: stepSinkMinusMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var cur = root.sinkPercent() / 100.0;
                                    root.setSinkVolumeRatio(Math.max(0, cur - 0.05));
                                }
                            }
                        }

                        Slider {
                            id: sinkSlider
                            Layout.fillWidth: true
                            from: 0; to: 1.5; stepSize: 0.01
                            enabled: root.hasSinks
                            Binding on value {
                                when: !sinkSlider.pressed
                                value: AudioStatusService.volume / 100.0
                            }
                            onMoved: {
                                AudioStatusService.setSinkVolumeRatio(value);
                                if (value > 0 && root.sinkMutedState()) {
                                    root.toggleSinkMute();
                                }
                            }
                            background: Rectangle {
                                implicitWidth: 160
                                implicitHeight: 6
                                radius: 3
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.10)
                                Rectangle {
                                    width: sinkSlider.visualPosition * parent.width
                                    height: parent.height; radius: 3
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: root.sinkPercent() > 100 ? ColorScheme.warningGradientStart : ColorScheme.accent }
                                        GradientStop { position: 1.0; color: root.sinkPercent() > 100 ? ColorScheme.warningGradientEnd : ColorScheme.accentAlt }
                                    }
                                }
                            }
                            handle: Rectangle {
                                x: sinkSlider.leftPadding + sinkSlider.visualPosition * (sinkSlider.availableWidth - width)
                                y: sinkSlider.topPadding + sinkSlider.availableHeight / 2 - height / 2
                                width: 14
                                height: 14
                                radius: 7
                                color: root.sinkMutedState() ? ColorScheme.red : ColorScheme.accent
                                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.15); border.width: 1
                            }
                        }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: stepSinkPlusMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.text, 0.15) : ColorScheme.withAlpha(ColorScheme.text, 0.08)
                            Text { anchors.centerIn: parent; text: "+"; color: ColorScheme.text; font.pixelSize: 13; font.bold: true }
                            MouseArea {
                                id: stepSinkPlusMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var cur = root.sinkPercent() / 100.0;
                                    root.setSinkVolumeRatio(Math.min(1.5, cur + 0.05));
                                }
                            }
                        }

                        Text {
                            text: root.sinkMutedState() ? "Mudo" : (root.sinkPercent() + "%")
                            color: root.sinkMutedState() ? ColorScheme.red : ColorScheme.text
                            font.pixelSize: 11; font.family: "Inter"; font.bold: true
                            Layout.preferredWidth: 38
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // Sink switcher
                    SinkSwitcher {
                        Layout.fillWidth: true
                        visible: root.hasSinks
                        accentColor: ColorScheme.accent
                        textColor: ColorScheme.text
                        customSinks: root.usingCliFallback ? root.cliSinks : []
                        selectSinkById: root.setSinkDefaultById
                    }

                    Column {
                        Layout.fillWidth: true
                        visible: !root.hasSinks
                        spacing: 6
                        opacity: 0.4

                        DynamicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            iconSource: root.outputIconSource()
                            iconColor: ColorScheme.text
                            size: 24
                            sourceSize: 48
                            fallbackGlyph: root.audioGlyph(false)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Nenhum dispositivo de saída detectado"
                            color: ColorScheme.text
                            font.pixelSize: 11
                            font.family: "Inter"
                        }
                    }
                }

                // ─── Section: Input (Microphone) ──────────────
                ColumnLayout {
                    id: sourceSection
                    Layout.fillWidth: true
                    spacing: 12
                    visible: root.activeTab === "all" || root.activeTab === "source"

                    Rectangle {
                        Layout.fillWidth: true; height: 1
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                        visible: root.activeTab === "all"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        DynamicIcon {
                            iconSource: root.inputIconSource()
                            iconColor: ColorScheme.accent
                            size: 16
                            sourceSize: 32
                            fallbackGlyph: root.microphoneGlyph(false)
                        }

                        Text {
                            text: "Entrada (Microfone)"
                            color: ColorScheme.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            font.family: "Inter"
                            font.letterSpacing: DesignTokens.letterSpacingLabel
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Status badge (Em uso / Livre)
                        Rectangle {
                            height: 18
                            width: micStatusText.implicitWidth + 10
                            radius: 9
                            color: PrivacyService.micActive
                                ? ColorScheme.withAlpha(ColorScheme.accent, 0.20)
                                : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                            border.color: PrivacyService.micActive ? ColorScheme.accent : "transparent"
                            border.width: 1

                            Text {
                                id: micStatusText
                                anchors.centerIn: parent
                                text: PrivacyService.micActive ? "Em uso" : "Pronto"
                                color: PrivacyService.micActive ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.6)
                                font.pixelSize: 9
                                font.family: "Inter"
                                font.bold: PrivacyService.micActive
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            width: 16
                            height: 16

                            SequentialAnimation {
                                id: sourceMutePulse
                                NumberAnimation { target: sourceMuteIconGraphic; property: "scale"; to: 1.12; duration: 100; easing.type: Easing.OutQuad }
                                NumberAnimation { target: sourceMuteIconGraphic; property: "scale"; to: 1.0; duration: 100; easing.type: Easing.InQuad }
                            }

                            DynamicIcon {
                                id: sourceMuteIconGraphic
                                anchors.fill: parent
                                iconSource: root.sourceMutedState() ? "file://" + RuntimePaths.quickshellDir + "/shared/icons/mute.svg" : "file://" + RuntimePaths.quickshellDir + "/shared/icons/audio-input.svg"
                                iconColor: root.sourceMutedState() ? ColorScheme.red : ColorScheme.accent
                                fallbackGlyph: root.microphoneGlyph(root.sourceMutedState())
                                size: 16
                                sourceSize: 32
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { sourceMutePulse.start(); root.toggleSourceMute(); }
                            }
                        }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: stepSourceMinusMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.text, 0.15) : ColorScheme.withAlpha(ColorScheme.text, 0.08)
                            Text { anchors.centerIn: parent; text: "-"; color: ColorScheme.text; font.pixelSize: 13; font.bold: true }
                            MouseArea {
                                id: stepSourceMinusMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var cur = root.sourcePercent() / 100.0;
                                    root.setSourceVolumeRatio(Math.max(0, cur - 0.05));
                                }
                            }
                        }

                        Slider {
                            id: sourceSlider
                            Layout.fillWidth: true
                            from: 0; to: 1.5; stepSize: 0.01
                            enabled: root.hasSources
                            Binding on value {
                                when: !sourceSlider.pressed
                                value: AudioStatusService.sourceVolume / 100.0
                            }
                            onMoved: {
                                AudioStatusService.setSourceVolumeRatio(value);
                                if (value > 0 && root.sourceMutedState()) {
                                    root.toggleSourceMute();
                                }
                            }
                            background: Rectangle {
                                implicitWidth: 160
                                implicitHeight: 6
                                radius: 3
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.10)
                                Rectangle {
                                    width: sourceSlider.visualPosition * parent.width
                                    height: parent.height; radius: 3
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: root.sourcePercent() > 100 ? ColorScheme.warningGradientStart : ColorScheme.accent }
                                        GradientStop { position: 1.0; color: root.sourcePercent() > 100 ? ColorScheme.warningGradientEnd : ColorScheme.accentAlt }
                                    }
                                }
                            }
                            handle: Rectangle {
                                x: sourceSlider.leftPadding + sourceSlider.visualPosition * (sourceSlider.availableWidth - width)
                                y: sourceSlider.topPadding + sourceSlider.availableHeight / 2 - height / 2
                                width: 14
                                height: 14
                                radius: 7
                                color: root.sourceMutedState() ? ColorScheme.red : ColorScheme.accent
                                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.15); border.width: 1
                            }
                        }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: stepSourcePlusMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.text, 0.15) : ColorScheme.withAlpha(ColorScheme.text, 0.08)
                            Text { anchors.centerIn: parent; text: "+"; color: ColorScheme.text; font.pixelSize: 13; font.bold: true }
                            MouseArea {
                                id: stepSourcePlusMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var cur = root.sourcePercent() / 100.0;
                                    root.setSourceVolumeRatio(Math.min(1.5, cur + 0.05));
                                }
                            }
                        }

                        Text {
                            text: root.sourceMutedState() ? "Mudo" : (root.sourcePercent() + "%")
                            color: root.sourceMutedState() ? ColorScheme.red : ColorScheme.text
                            font.pixelSize: 11; font.family: "Inter"; font.bold: true
                            Layout.preferredWidth: 38
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // Live Mic VU / Peak Meter Indicator
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: root.hasSources

                        Text {
                            text: "Nível:"
                            font.pixelSize: 10
                            font.family: "Inter"
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.6)
                        }

                        Row {
                            Layout.fillWidth: true
                            height: 6
                            spacing: 3

                            Repeater {
                                model: 16
                                delegate: Rectangle {
                                    width: (parent.width - (15 * 3)) / 16
                                    height: 6
                                    radius: 2
                                    readonly property bool lit: {
                                        if (root.sourceMutedState()) return false;
                                        if (PrivacyService.micActive) {
                                            return index < Math.min(16, Math.max(2, Math.round((root.sourcePercent() / 100.0) * 12)));
                                        }
                                        return index < Math.min(4, Math.round((root.sourcePercent() / 100.0) * 3));
                                    }
                                    color: {
                                        if (!lit) return ColorScheme.withAlpha(ColorScheme.text, 0.08);
                                        if (index > 12) return ColorScheme.red;
                                        if (index > 9) return ColorScheme.yellow;
                                        return ColorScheme.accent;
                                    }
                                }
                            }
                        }
                    }

                    // Source Switcher
                    SourceSwitcher {
                        Layout.fillWidth: true
                        visible: root.hasSources
                        accentColor: ColorScheme.accent
                        textColor: ColorScheme.text
                        customSources: root.usingCliFallback ? root.cliSources : []
                        selectSourceById: root.setSourceDefaultById
                    }

                    Column {
                        Layout.fillWidth: true
                        visible: !root.hasSources
                        spacing: 6
                        opacity: 0.4

                        DynamicIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            iconSource: root.inputIconSource()
                            iconColor: ColorScheme.text
                            size: 24
                            sourceSize: 48
                            fallbackGlyph: root.microphoneGlyph(false)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Nenhuma fonte de entrada detectada"
                            color: ColorScheme.text
                            font.pixelSize: 11
                            font.family: "Inter"
                        }
                    }
                }

                // ─── Section: App Mixer ───────────────────────
                ColumnLayout {
                    id: mixerSection
                    Layout.fillWidth: true
                    spacing: 12
                    visible: root.activeTab === "all" || root.activeTab === "mixer"

                    Rectangle {
                        Layout.fillWidth: true; height: 1
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
                        visible: root.activeTab === "all"
                    }

                    AppVolumeMixer {
                        Layout.fillWidth: true
                        accentColor: ColorScheme.accent
                        textColor: ColorScheme.text
                        settingsStore: root.settingsStore
                    }
                }
            }
        }
    }
}
