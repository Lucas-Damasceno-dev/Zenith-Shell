import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import "../core"
import "../services/MprisUtils.js" as MprisUtils

/**
 * MediaPlayer - MPRIS media widget with adaptive album art colors.
 *
 * Features:
 *   - Blurred album art background with color tinting
 *   - Glass overlay with semi-transparent controls
 *   - Smooth crossfade on track change (title & artist)
 *   - Gradient progress bar (accent → accentAlt)
 *   - Motion-based empty state with pulsing icon
 *   - Hero/expanded mode variant (heroMode property)
 *   - Rich hover/pressed micro-interactions on controls
 */
Rectangle {
    id: root
    width: heroMode ? 420 : 300
    height: heroMode ? 180 : 130
    radius: heroMode ? DesignTokens.radiusXL : DesignTokens.radiusLG
    color: ColorScheme.withAlpha(ColorScheme.surface, 0.56)
    clip: true
    border.color: ColorScheme.glassBorder
    border.width: 1

    Behavior on width  {
        enabled: !FeatureFlags.reducedMotion
        NumberAnimation { duration: DesignTokens.durationSlower; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        enabled: !FeatureFlags.reducedMotion
        NumberAnimation { duration: DesignTokens.durationSlower; easing.type: Easing.OutCubic }
    }
    Behavior on radius {
        enabled: !FeatureFlags.reducedMotion
        NumberAnimation { duration: DesignTokens.durationSlower; easing.type: Easing.OutCubic }
    }

    property var player: shellRoot.activeMprisPlayer
    property bool hasMedia: player !== null
    property string artSource: String(MprisUtils.artUrlForPlayer(root.player) || "")
    readonly property bool reducedMotion: FeatureFlags.reducedMotion
        || FeatureFlags.lowPowerUiMode

    /** Hero/expanded mode — makes the card larger with more visual presence. */
    property bool heroMode: false

    // ─── Empty State (motion-based) ─────────────────────────────
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: !root.hasMedia

        Text {
            id: emptyIcon
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\u{f001}"  // music note
            font.family: Style.fontMono
            font.pixelSize: root.heroMode ? 36 : 28
            color: ColorScheme.text
            opacity: 0.4

            transform: Scale {
                id: emptyIconScale
                origin.x: emptyIcon.width / 2
                origin.y: emptyIcon.height / 2
                xScale: 1.0; yScale: 1.0
            }

            SequentialAnimation on opacity {
                running: !root.hasMedia && root.visible && !root.reducedMotion
                loops: Animation.Infinite
                NumberAnimation { to: 0.2;  duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.4;  duration: 1800; easing.type: Easing.InOutSine }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nada tocando"
            color: ColorScheme.text
            font.pixelSize: root.heroMode ? DesignTokens.fontSizeMD : DesignTokens.fontSizeSM
            font.family: Style.fontUI
            opacity: 0.4

            SequentialAnimation on opacity {
                running: !root.hasMedia && root.visible && !root.reducedMotion
                loops: Animation.Infinite
                NumberAnimation { to: 0.2;  duration: 2000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.4;  duration: 2000; easing.type: Easing.InOutSine }
            }
        }
    }

    // ─── Active Media ───────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: root.hasMedia

        // Album art tint — blurred art bleeds color into the card bg
        Image {
            id: artTintSource
            anchors.fill: parent
            source: root.artSource
            sourceSize.width: Math.max(64, Math.min(256, Math.max(root.width, root.height)))
            sourceSize.height: Math.max(64, Math.min(256, Math.max(root.width, root.height)))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

            MultiEffect {
                anchors.fill: parent
                source: artTintSource
                blurEnabled: !root.reducedMotion
                blurMax: root.reducedMotion ? 0 : 28
                blur: root.reducedMotion ? 0.0 : 1.0
                saturation: 0.3
                brightness: -0.15
                opacity: artTintSource.status === Image.Ready && !root.reducedMotion ? 0.20 : 0.0
            Behavior on opacity {
                enabled: !root.reducedMotion
                NumberAnimation { duration: DesignTokens.durationSlower; easing.type: Easing.OutCubic }
            }
        }

        // Semi-transparent overlay to keep text readable
        Rectangle {
            anchors.fill: parent
            color: ColorScheme.withAlpha(ColorScheme.background, 0.65)
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.heroMode ? DesignTokens.spacingXL + DesignTokens.spacingXS : DesignTokens.spacingLG
            spacing: root.heroMode ? DesignTokens.spacingXL + DesignTokens.spacingXS : DesignTokens.spacingLG

            // Album Art with rounded mask
            Item {
                Layout.preferredWidth:  root.heroMode ? 100 : 70
                Layout.preferredHeight: root.heroMode ? 100 : 70

                Rectangle {
                    id: artMask
                    anchors.fill: parent
                    radius: root.heroMode ? DesignTokens.radiusLG : DesignTokens.radiusMD
                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.3)
                }

                Image {
                    id: albumArt
                    anchors.fill: parent
                    source: root.artSource
                    sourceSize.width: Math.max(64, Math.min(192, parent.width * 2))
                    sourceSize.height: Math.max(64, Math.min(192, parent.height * 2))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready

                    layer.enabled: root.hasMedia
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                        maskSource: Rectangle {
                            width: albumArt.width
                            height: albumArt.height
                            radius: root.heroMode ? DesignTokens.radiusLG : DesignTokens.radiusMD
                            color: "white"
                        }
                    }

                    // Crossfade on track change
                    opacity: 1.0
                    Behavior on source {
                        enabled: !root.reducedMotion
                        SequentialAnimation {
                            NumberAnimation { target: albumArt; property: "opacity"; to: 0; duration: 150 }
                            PropertyAction { target: albumArt; property: "source" }
                            NumberAnimation { target: albumArt; property: "opacity"; to: 1; duration: 250 }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.heroMode ? DesignTokens.radiusLG : DesignTokens.radiusMD
                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.18)
                    visible: albumArt.status !== Image.Ready

                    Column {
                        anchors.centerIn: parent
                        spacing: DesignTokens.spacingXS

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "\u{f001}"
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.72)
                            font.family: Style.fontMono
                            font.pixelSize: root.heroMode ? DesignTokens.fontSizeXL + 6 : DesignTokens.fontSizeLG + 3
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Sem capa"
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.46)
                            font.family: Style.fontUI
                            font.pixelSize: root.heroMode ? DesignTokens.fontSizeSM : DesignTokens.fontSizeXS + 1
                        }
                    }
                }

                // Subtle border on album art
                Rectangle {
                    anchors.fill: parent
                    radius: root.heroMode ? DesignTokens.radiusLG : DesignTokens.radiusMD
                    color: "transparent"
                    border.color: ColorScheme.withAlpha(ColorScheme.text, 0.1)
                    border.width: 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.heroMode ? 4 : 3

                // Title — true crossfade between old/new text
                Item {
                    id: titleContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: titleCurrent.implicitHeight
                    clip: true

                    property string displayTitle: MprisUtils.titleForPlayer(root.player) || "Sem titulo"
                    property string _prev: ""
                    property string _curr: displayTitle

                    onDisplayTitleChanged: {
                        if (_curr !== displayTitle) {
                            _prev = _curr;
                            _curr = displayTitle;
                            if (!root.reducedMotion)
                                titleFade.restart();
                        }
                    }

                    Text {
                        id: titlePrev
                        anchors { left: parent.left; right: parent.right }
                        text: titleContainer._prev
                        color: ColorScheme.foreground
                        font { weight: Font.Bold; pixelSize: root.heroMode ? 16 : 13; family: Style.fontUI }
                        elide: Text.ElideRight
                        opacity: 0
                    }

                    Text {
                        id: titleCurrent
                        anchors { left: parent.left; right: parent.right }
                        text: titleContainer._curr
                        color: ColorScheme.foreground
                        font { weight: Font.Bold; pixelSize: root.heroMode ? 16 : 13; family: Style.fontUI }
                        elide: Text.ElideRight
                        opacity: 1
                    }

                    ParallelAnimation {
                        id: titleFade
                        NumberAnimation { target: titlePrev;    property: "opacity"; from: 1; to: 0; duration: DesignTokens.durationSlower; easing.type: Easing.OutCubic }
                        NumberAnimation { target: titleCurrent; property: "opacity"; from: 0; to: 1; duration: DesignTokens.durationSlower; easing.type: Easing.OutCubic }
                    }
                }

                // Artist — true crossfade
                Item {
                    id: artistContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: artistCurrent.implicitHeight
                    clip: true

                    property string displayArtist: {
                        let a = MprisUtils.artistForPlayer(root.player);
                        return a !== "" ? a : "Artista desconhecido";
                    }
                    property string _prev: ""
                    property string _curr: displayArtist

                    onDisplayArtistChanged: {
                        if (_curr !== displayArtist) {
                            _prev = _curr;
                            _curr = displayArtist;
                            if (!root.reducedMotion)
                                artistFade.restart();
                        }
                    }

                    Text {
                        id: artistPrev
                        anchors { left: parent.left; right: parent.right }
                        text: artistContainer._prev
                        color: ColorScheme.withAlpha(ColorScheme.foreground, 0.7)
                        font { pixelSize: root.heroMode ? 13 : 11; family: Style.fontUI }
                        elide: Text.ElideRight
                        opacity: 0
                    }

                    Text {
                        id: artistCurrent
                        anchors { left: parent.left; right: parent.right }
                        text: artistContainer._curr
                        color: ColorScheme.withAlpha(ColorScheme.foreground, 0.7)
                        font { pixelSize: root.heroMode ? 13 : 11; family: Style.fontUI }
                        elide: Text.ElideRight
                        opacity: 1
                    }

                    ParallelAnimation {
                        id: artistFade
                        NumberAnimation { target: artistPrev;    property: "opacity"; from: 1; to: 0; duration: DesignTokens.durationSlower; easing.type: Easing.OutCubic }
                        NumberAnimation { target: artistCurrent; property: "opacity"; from: 0; to: 1; duration: DesignTokens.durationSlower; easing.type: Easing.OutCubic }
                    }
                }

                // Gradient progress bar (accent → accentAlt)
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: root.heroMode ? 10 : 8
                    height: root.heroMode ? 5 : 4

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.15)

                        Rectangle {
                            width: root.player
                                ? parent.width * Math.min(1.0, root.player.position / Math.max(1, root.player.length))
                                : 0
                            height: parent.height
                            radius: 2

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: ColorScheme.accent }
                                GradientStop { position: 1.0; color: ColorScheme.accentAlt }
                            }

                            Behavior on width {
                                enabled: !root.reducedMotion
                                NumberAnimation { duration: 800; easing.type: Easing.Linear }
                            }
                        }
                    }
                }

                // Controls with rich hover/pressed states
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: root.heroMode ? 8 : 6
                    spacing: 0
                    Layout.alignment: Qt.AlignHCenter

                    Repeater {
                        model: [
                            { icon: "\u{f048}", action: "previous", size: 14 },
                            { icon: (root.player?.playbackState === MprisPlaybackState.Playing) ? "\u{f04c}" : "\u{f04b}", action: "playPause", size: 18 },
                            { icon: "\u{f051}", action: "next", size: 14 }
                        ]

                        delegate: Item {
                            width: root.heroMode ? 44 : 36
                            height: root.heroMode ? 34 : 28
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                id: ctrlBg
                                anchors.fill: parent
                                radius: DesignTokens.radiusSM

                                color: ctrlMa.pressed
                                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.18)
                                    : ctrlMa.containsMouse
                                        ? ColorScheme.withAlpha(ColorScheme.accent, 0.10)
                                        : "transparent"

                                border.color: ctrlMa.containsMouse
                                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.25)
                                    : "transparent"
                                border.width: 1

                                Behavior on color {
                                    enabled: !root.reducedMotion
                                    ColorAnimation { duration: DesignTokens.durationFast }
                                }
                                Behavior on border.color {
                                    enabled: !root.reducedMotion
                                    ColorAnimation { duration: DesignTokens.durationFast }
                                }

                                scale: ctrlMa.pressed
                                    ? DesignTokens.pressedScale
                                    : ctrlMa.containsMouse ? DesignTokens.hoverScale : 1.0

                                Behavior on scale {
                                    enabled: !root.reducedMotion
                                    NumberAnimation { duration: DesignTokens.durationFast; easing.type: Easing.OutCubic }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.pixelSize: root.heroMode ? Math.round(modelData.size * 1.2) : modelData.size
                                    font.family: Style.fontMono

                                    color: ctrlMa.pressed
                                        ? ColorScheme.accent
                                        : ctrlMa.containsMouse
                                            ? ColorScheme.foreground
                                            : ColorScheme.withAlpha(ColorScheme.foreground, 0.85)

                                    Behavior on color {
                                        enabled: !root.reducedMotion
                                        ColorAnimation { duration: DesignTokens.durationFast }
                                    }
                                }
                            }

                            MouseArea {
                                id: ctrlMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.action === "previous") root.player?.previous();
                                    else if (modelData.action === "playPause") root.player?.playPause();
                                    else if (modelData.action === "next") root.player?.next();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
