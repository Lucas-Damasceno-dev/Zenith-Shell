pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../core"
import "../../../shared"
import "../../../shared/IconResolver.js" as IconResolver

/**
 * FocusedApp - Minimalist, high-performance focused window indicator.
 *
 * Design:
 * - Clean glass pill with frosted surface & subtle Matugen accent glow on hover/press
 * - Zero intrusive popups or layout-breaking tooltips
 * - Seamless anti-flicker state holder (absorbs focus transitions <90ms)
 * - Safe C++ Hyprland IPC dispatch (Left: focus, Right: float, Middle: kill)
 * - Inner-scaled tactile press feedback (never clips or disrupts RowLayout)
 */
Item {
    id: root

    // ── Public API & Injected State ─────────────────────────────
    property var screenData: null
    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.foreground
    property bool compact: false
    property bool mediaActive: false
    readonly property bool reducedEffects: FeatureFlags.lowPowerUiMode || FeatureFlags.reducedMotion
    readonly property bool privacyMode: FeatureFlags.privacyMode

    // ── Hyprland Reactive Bindings ──────────────────────────────
    readonly property var client: Hyprland.activeToplevel
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property var clientWorkspace: client ? client.workspace : null
    readonly property var clientMonitor: client ? client.monitor : null
    readonly property string clientAddress: client ? String(client.address || "") : ""
    readonly property string rawTitle: client ? String(client.title || "") : ""

    readonly property string clientClass: {
        if (!client) return "";
        if (client.waylandSurface && client.waylandSurface.appId)
            return String(client.waylandSurface.appId || "");
        if (client.lastIpcObject && client.lastIpcObject["class"])
            return String(client.lastIpcObject["class"] || "");
        return "";
    }

    // ── Multi-Monitor Awareness ─────────────────────────────────
    readonly property bool matchesScreen: {
        if (!client) return false;
        if (!screenData) return true;
        var screenName = String(screenData.name || "");
        if (screenName === "") return true;

        if (clientMonitor && clientMonitor.name) {
            return String(clientMonitor.name) === screenName;
        }
        if (clientWorkspace && clientWorkspace.monitor && clientWorkspace.monitor.name) {
            return String(clientWorkspace.monitor.name) === screenName;
        }
        return true;
    }

    readonly property bool clientOnFocusedWorkspace: {
        if (!client) return false;
        if (!clientWorkspace || !focusedWorkspace) return true;
        var cName = String(clientWorkspace.name || "");
        var fName = String(focusedWorkspace.name || "");
        if (cName !== "" && fName !== "") return cName === fName;
        return Number(clientWorkspace.id || -99999) === Number(focusedWorkspace.id || -99998);
    }

    readonly property bool rawHasClient: !!client && matchesScreen && clientOnFocusedWorkspace && (clientClass !== "" || rawTitle !== "")

    // ── Anti-Flicker State Holder ───────────────────────────────
    property var heldClient: null
    property string heldClass: ""
    property string heldTitle: ""
    property string heldAddress: ""
    property var heldWorkspace: null
    property bool hasVisibleClient: false

    Timer {
        id: clientDebounceTimer
        interval: 90
        repeat: false
        onTriggered: root.syncClientState()
    }

    function syncClientState() {
        if (rawHasClient) {
            heldClient = client;
            heldClass = clientClass;
            heldTitle = rawTitle;
            heldAddress = clientAddress;
            heldWorkspace = clientWorkspace;
            hasVisibleClient = true;
        } else {
            heldClient = null;
            heldClass = "";
            heldTitle = "";
            heldAddress = "";
            heldWorkspace = null;
            hasVisibleClient = false;
        }
    }

    onRawHasClientChanged: {
        if (rawHasClient) {
            clientDebounceTimer.stop();
            syncClientState();
        } else {
            clientDebounceTimer.restart();
        }
    }

    Component.onCompleted: syncClientState()

    readonly property string effectiveClass: (clientClass !== "" ? clientClass : heldClass)
    readonly property string effectiveTitle: (rawTitle !== "" ? rawTitle : heldTitle)
    readonly property string effectiveAddress: (clientAddress !== "" ? clientAddress : heldAddress)
    readonly property var effectiveWorkspace: (clientWorkspace ? clientWorkspace : heldWorkspace)

    // ── Window Mode Flags ───────────────────────────────────────
    readonly property bool isFloating: {
        var c = client || heldClient;
        if (!c) return false;
        if (c.floating !== undefined && c.floating !== null) return !!c.floating;
        if (c.lastIpcObject && c.lastIpcObject["floating"]) return Number(c.lastIpcObject["floating"]) > 0;
        return false;
    }

    readonly property bool isFullscreen: {
        var c = client || heldClient;
        if (!c) return false;
        if (c.fullscreen !== undefined && c.fullscreen !== null) return !!c.fullscreen;
        if (c.lastIpcObject && c.lastIpcObject["fullscreen"]) return Number(c.lastIpcObject["fullscreen"]) > 0;
        return false;
    }

    readonly property bool isPinned: {
        var c = client || heldClient;
        if (!c) return false;
        if (c.pinned !== undefined && c.pinned !== null) return !!c.pinned;
        if (c.lastIpcObject && c.lastIpcObject["pinned"]) return Number(c.lastIpcObject["pinned"]) > 0;
        return false;
    }

    readonly property bool hasBadge: isFloating || isFullscreen || isPinned
    readonly property string layoutMode: isFullscreen ? "FULL" : (isPinned ? "PIN" : (isFloating ? "FLOAT" : ""))
    readonly property color layoutColor: isFullscreen
        ? ColorScheme.mauve
        : (isPinned ? ColorScheme.teal : ColorScheme.yellow)

    // ── Submap Reactive IPC ─────────────────────────────────────
    property string activeSubmap: "default"
    readonly property bool inSubmap: activeSubmap !== "" && activeSubmap !== "default"

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!event || event.name !== "submap") return;
            var raw = String((event.data !== undefined && event.data !== null) ? event.data : "").trim();
            root.activeSubmap = raw === "" ? "default" : raw;
        }
    }

    // ── App Name & Title Parsing ────────────────────────────────
    function extractAppName(cls, title) {
        var rawClass = String(cls || "").trim().toLowerCase();
        if (rawClass === "" && !title) return "";

        var classMap = {
            "brave-browser": "Brave",
            "brave": "Brave",
            "firefox": "Firefox",
            "google-chrome": "Chrome",
            "chromium": "Chromium",
            "chromium-browser": "Chromium",
            "kitty": "Kitty",
            "ghostty": "Ghostty",
            "com.mitchellh.ghostty": "Ghostty",
            "foot": "Foot",
            "alacritty": "Alacritty",
            "wezterm": "WezTerm",
            "org.wezfurlong.wezterm": "WezTerm",
            "code": "VS Code",
            "vscodium": "VSCodium",
            "vscode": "VS Code",
            "discord": "Discord",
            "vesktop": "Vesktop",
            "spotify": "Spotify",
            "spotify-client": "Spotify",
            "telegramdesktop": "Telegram",
            "telegram": "Telegram",
            "org.telegram.desktop": "Telegram",
            "steam": "Steam",
            "obsidian": "Obsidian",
            "thunar": "Thunar",
            "org.xfce.thunar": "Thunar",
            "nautilus": "Files",
            "org.gnome.nautilus": "Files",
            "dolphin": "Dolphin",
            "org.kde.dolphin": "Dolphin",
            "pavucontrol": "Volume",
            "blueman-manager": "Bluetooth",
            "gimp": "GIMP",
            "inkscape": "Inkscape",
            "blender": "Blender",
            "obs": "OBS Studio",
            "obs-studio": "OBS Studio",
            "vlc": "VLC",
            "mpv": "MPV",
            "zathura": "Zathura",
            "libreoffice": "LibreOffice",
            "easyeffects": "EasyEffects",
            "wireshark": "Wireshark",
            "virt-manager": "Virt Manager",
            "opencode": "OpenCode",
            "antigravity": "Antigravity",
            "btop": "Btop"
        };

        if (classMap[rawClass]) return classMap[rawClass];

        if (rawClass.indexOf(".") >= 0) {
            var parts = rawClass.split(".");
            var last = parts[parts.length - 1];
            if (last.length > 2) return last.charAt(0).toUpperCase() + last.slice(1);
        }

        if (rawClass.length > 0) {
            return rawClass.charAt(0).toUpperCase() + rawClass.slice(1);
        }

        return "App";
    }

    function sanitizeTitle(title, appName) {
        var t = String(title || "").trim();
        if (t === "") return "";

        var suffixes = [
            " - Visual Studio Code",
            " — Visual Studio Code",
            " - VSCodium",
            " — VSCodium",
            " — Mozilla Firefox",
            " - Mozilla Firefox",
            " - Brave",
            " — Brave",
            " - Google Chrome",
            " — Google Chrome",
            " — Kitty",
            " - Kitty",
            " — Ghostty",
            " - Ghostty",
            " - Obsidian",
            " — Obsidian",
            " - Discord",
            " — Discord"
        ];

        for (var i = 0; i < suffixes.length; i++) {
            if (t.endsWith(suffixes[i])) {
                t = t.substring(0, t.length - suffixes[i].length).trim();
                break;
            }
        }

        if (appName && (t.toLowerCase() === appName.toLowerCase() || t.toLowerCase() === "terminal")) {
            return "";
        }
        return t;
    }

    function normalizeAddress(addr) {
        if (!addr) return "";
        var s = String(addr).trim();
        if (s.indexOf("0x") === 0) return s;
        return "0x" + s;
    }

    readonly property string appName: extractAppName(effectiveClass, effectiveTitle)
    readonly property string sanitizedTitle: sanitizeTitle(effectiveTitle, appName)

    // ── Layout Geometry & Jitter Prevention ─────────────────────
    implicitWidth: {
        if (!hasVisibleClient) return 0;
        if (compact) return 32;
        var targetW = contentRow.implicitWidth + 20;
        var maxW = mediaActive ? 150 : DesignTokens.barFocusedAppMaxWidth;
        return Math.min(maxW, Math.max(60, targetW));
    }
    implicitHeight: DesignTokens.barItemHeight

    opacity: hasVisibleClient ? 1.0 : 0.0

    Behavior on implicitWidth {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        enabled: !root.reducedEffects
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    property real pillScale: 1.0

    // ── Glass Pill Container (Inner-scaled to protect layout) ────
    Rectangle {
        id: pillBg
        anchors.fill: parent
        scale: root.pillScale
        radius: height / 2

        color: focusedAppMa.pressed
            ? ColorScheme.withAlpha(root.accentColor, 0.16)
            : (focusedAppMa.containsMouse
                ? ColorScheme.withAlpha(ColorScheme.surface || ColorScheme.panelBg, 0.32)
                : ColorScheme.withAlpha(ColorScheme.surface || ColorScheme.panelBg, 0.16))

        border.color: focusedAppMa.pressed
            ? ColorScheme.withAlpha(root.accentColor, 0.50)
            : (focusedAppMa.containsMouse
                ? ColorScheme.withAlpha(root.accentColor, DesignTokens.hoverBorderOpacity || 0.28)
                : ColorScheme.withAlpha(root.textColor, 0.08))
        border.width: 1

        Behavior on color {
            enabled: !root.reducedEffects
            ColorAnimation { duration: DesignTokens.durationFast || 80 }
        }
        Behavior on border.color {
            enabled: !root.reducedEffects
            ColorAnimation { duration: DesignTokens.durationFast || 80 }
        }
        Behavior on scale {
            enabled: !root.reducedEffects
            NumberAnimation { duration: 90; easing.type: Easing.OutBack }
        }

        // Subtle specular highlight line at top
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 4
            height: 1
            radius: 0.5
            color: ColorScheme.withAlpha("#ffffff", 0.07)
            visible: !root.reducedEffects
        }

        // ── Content Row ─────────────────────────────────────────────
        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: DesignTokens.spacingSM || 6

            // 1. App Icon (SmartIcon with system theme / SVG / Glyph fallback)
            SmartIcon {
                id: appSmartIcon
                Layout.alignment: Qt.AlignVCenter
                size: 15
                sourceSize: 30
                source: root.effectiveClass
                label: root.appName
                context: root.effectiveClass
                color: root.accentColor
            }

            // 2. App Name (Semi-bold primary label)
            Text {
                id: appNameLabel
                Layout.alignment: Qt.AlignVCenter
                visible: !root.compact && root.appName !== ""
                text: root.privacyMode ? "Private Window" : root.appName
                color: root.textColor
                font.pixelSize: DesignTokens.barLabelFontSize || 11
                font.weight: Font.DemiBold
                font.family: DesignTokens.fontFamilyUI || "Inter"
                renderType: Text.NativeRendering
                elide: Text.ElideRight
            }

            // 3. Separator (Muted chevron / dot)
            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: !root.compact && !root.privacyMode && root.appName !== "" && root.sanitizedTitle !== ""
                text: "›"
                color: ColorScheme.withAlpha(root.textColor, 0.35)
                font.pixelSize: 11
                font.family: DesignTokens.fontFamilyUI || "Inter"
                renderType: Text.NativeRendering
            }

            // 4. Subtitle / Document Title (Cross-fades on change)
            Text {
                id: titleLabel
                Layout.alignment: Qt.AlignVCenter
                visible: !root.compact && !root.privacyMode && root.sanitizedTitle !== ""
                Layout.maximumWidth: Math.max(30, (root.mediaActive ? 68 : (DesignTokens.barFocusedAppMaxWidth - 110 - (root.inSubmap ? 48 : 0) - (root.hasBadge ? 40 : 0))))
                text: root.sanitizedTitle
                color: ColorScheme.withAlpha(root.textColor, DesignTokens.textOpacitySecondary || 0.72)
                font.pixelSize: DesignTokens.barLabelFontSize || 11
                font.family: DesignTokens.fontFamilyUI || "Inter"
                renderType: Text.NativeRendering
                elide: Text.ElideRight
                clip: true

                onTextChanged: {
                    if (!root.reducedEffects) {
                        titleFadeAnim.restart();
                    }
                }

                NumberAnimation {
                    id: titleFadeAnim
                    target: titleLabel
                    property: "opacity"
                    from: 0.35
                    to: 1.0
                    duration: 120
                    easing.type: Easing.OutQuad
                }
            }

            // 5. Window State Badge (FLOAT / FULL / PIN)
            Rectangle {
                id: layoutBadge
                Layout.alignment: Qt.AlignVCenter
                visible: !root.compact && root.hasBadge
                radius: DesignTokens.radiusXS || 4
                color: ColorScheme.withAlpha(root.layoutColor, 0.16)
                border.color: ColorScheme.withAlpha(root.layoutColor, 0.38)
                border.width: 1
                implicitWidth: layoutText.implicitWidth + 8
                implicitHeight: 16

                Text {
                    id: layoutText
                    anchors.centerIn: parent
                    text: root.layoutMode
                    color: root.layoutColor
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    font.family: DesignTokens.fontFamilyUI || "Inter"
                    font.letterSpacing: DesignTokens.letterSpacingBadge || 0.5
                    renderType: Text.NativeRendering
                }
            }

            // 6. Submap Warning Badge (Pulsing to warn user of modal input state)
            Rectangle {
                id: submapBadge
                Layout.alignment: Qt.AlignVCenter
                visible: !root.compact && root.inSubmap
                radius: DesignTokens.radiusXS || 4
                color: ColorScheme.withAlpha(ColorScheme.red, 0.20)
                border.color: ColorScheme.withAlpha(ColorScheme.red, 0.50)
                border.width: 1
                implicitWidth: submapText.implicitWidth + 8
                implicitHeight: 16

                SequentialAnimation on opacity {
                    running: root.inSubmap && !root.reducedEffects
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.50; duration: 450; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutQuad }
                }

                Text {
                    id: submapText
                    anchors.centerIn: parent
                    text: root.activeSubmap.toUpperCase()
                    color: ColorScheme.red
                    font.pixelSize: 8
                    font.bold: true
                    font.family: DesignTokens.fontFamilyUI || "Inter"
                    font.letterSpacing: DesignTokens.letterSpacingBadge || 0.5
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // ── Mouse Area & Micro-Actions (Clean, zero popup clutter) ──
    MouseArea {
        id: focusedAppMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                var addr = root.normalizeAddress(root.effectiveAddress);
                if (addr !== "") {
                    Hyprland.dispatch("focuswindow address:" + addr);
                }
            } else if (mouse.button === Qt.MiddleButton) {
                Hyprland.dispatch("killactive");
            } else if (mouse.button === Qt.RightButton) {
                Hyprland.dispatch("togglefloating");
            }
        }

        onPressed:  root.pillScale = DesignTokens.pressedScale || 0.94
        onReleased: root.pillScale = 1.0
        onCanceled: root.pillScale = 1.0
    }
}
