import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "../core"
import "../services"
import "../shared"

/**
 * SystemHub & Datasheet - Fullscreen system control, live tweaks, and keybinding reference overlay.
 * Dynamic and complete for all system/features/tools.
 */
PopupWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    showScrim: true
    scrimOpacity: 0.65
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0

    // Hub View Modes
    property string activeMode: "cheatsheet" // "cheatsheet" | "hyprland" | "nixos" | "daemons"

    property var categoryCache: ({})
    property string activeCategory: "hyprland"
    property string pendingCategory: ""
    property string activeTagFilter: ""
    property var availableTags: []
    
    property var categories: [
        { id: "quickshell", name: "Quickshell", icon: "\u{f108}" },
        { id: "hyprland", name: "Hyprland", icon: "\u{f359}" },
        { id: "neovim", name: "Neovim", icon: "\u{f121}" },
        { id: "tmux", name: "Tmux", icon: "\u{f248}" },
        { id: "nixos", name: "NixOS", icon: "\u{f313}" },
        { id: "cli", name: "CLI & Env", icon: "\u{f120}" },
        { id: "opencode", name: "OpenCode", icon: "\u{f085}" }
    ]

    ListModel { id: bindModel }
    ListModel { id: visibleModel }

    readonly property string scriptsDir: RuntimePaths.quickshellScriptsDir
    readonly property string hyprScriptsDir: RuntimePaths.hyprScriptsDir

    TimedProcess {
        id: dataFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                var output = String(text || "").trim();
                if (output === "") return;
                try {
                    var payload = JSON.parse(output);
                    var category = String(payload.category || root.pendingCategory || root.activeCategory || "").trim();
                    var entries = payload.entries || [];
                    if (category === "") return;
                    root.categoryCache[category] = entries;
                    if (category === root.activeCategory)
                        loadCategory(category);
                } catch(e) {
                    console.warn("[CheatSheet] JSON Parse Error: " + e + "\nStart: " + output.substring(0, 100));
                }
            }
        }
        stderr: StdioCollector { onRead: console.error("[CheatSheet] Error: " + data) }
    }

    onIsOpenChanged: if (isOpen) {
        root.categoryCache = ({});
        root.pendingCategory = "";
        root.loadCategory(root.activeCategory);
        SystemMetricsService.refreshNow();
        NixMonitorService.refresh(true);
    }

    function requestCategory(catId) {
        var category = String(catId || "").trim();
        if (category === "")
            return;
        root.pendingCategory = category;
        dataFetcher.exec([
            "sh",
            RuntimePaths.scriptFile("fetch_cheatsheets.sh"),
            "--category",
            category
        ]);
    }

    function loadCategory(catId) {
        var category = String(catId || "").trim();
        if (category === "")
            return;

        root.activeCategory = category;
        root.activeTagFilter = "";
        bindModel.clear();

        var list = root.categoryCache[category];
        if (list && list.length !== undefined) {
            for (var i = 0; i < list.length; i++)
                bindModel.append(list[i]);
            refreshVisibleEntries();
            return;
        }

        root.requestCategory(category);
    }

    function entryTag(entry) {
        var parts = splitActionText(entry && entry.action ? entry.action : "");
        return parts.tag;
    }

    function refreshVisibleEntries() {
        visibleModel.clear();
        var tags = {};
        for (var i = 0; i < bindModel.count; i++) {
            var entry = bindModel.get(i);
            var tag = entryTag(entry);
            if (tag !== "")
                tags[tag] = true;
            if (root.activeTagFilter !== "" && tag !== root.activeTagFilter)
                continue;
            visibleModel.append(entry);
        }
        root.availableTags = Object.keys(tags).sort();
    }

    function cleanActionText(text) {
        var clean = String(text || "");
        clean = clean.replace(/\*\*/g, "");
        clean = clean.replace(/\_\_/g, "");
        return clean;
    }

    function splitActionText(text) {
        var clean = cleanActionText(text).trim();
        var match = clean.match(/^\[([^\]]+)\]\s*(.*)$/);
        if (!match)
            return { tag: "", body: clean };
        return { tag: match[1].trim(), body: match[2].trim() };
    }

    // ─── Central Glass Card ─────────────────────────────────────
    Rectangle {
        id: cheatCard
        anchors.centerIn: parent
        width: parent.width * 0.88
        height: parent.height * 0.88
        radius: 22
        color: ColorScheme.withAlpha(ColorScheme.background, 0.82)
        border.color: ColorScheme.glassBorder
        border.width: 1

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 1
            radius: 22
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ─── SIDEBAR ─────────────────────────────────
            Rectangle {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.35)
                radius: 22
                
                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 22
                    color: parent.color
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 1
                    color: ColorScheme.glassBorder
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    // Hub Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "\u{f013}"
                            color: ColorScheme.accent
                            font.pixelSize: 22
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: "System Hub"
                                color: ColorScheme.text
                                font.bold: true
                                font.pixelSize: 18
                                font.family: "Inter"
                            }
                            Text {
                                text: "DataSheet & Control Center"
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.45)
                                font.pixelSize: 10
                                font.family: "Inter"
                            }
                        }
                    }

                    // Mode Switcher Tabs
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 12
                        color: ColorScheme.withAlpha(ColorScheme.background, 0.6)
                        border.color: ColorScheme.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 3
                            spacing: 3

                            // Tab 1: Cheatsheet
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 9
                                color: root.activeMode === "cheatsheet" ? ColorScheme.accent : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f11c} Sheet"
                                    color: root.activeMode === "cheatsheet" ? ColorScheme.background : ColorScheme.withAlpha(ColorScheme.text, 0.7)
                                    font.bold: true
                                    font.pixelSize: 11
                                    font.family: "Inter"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeMode = "cheatsheet"
                                }
                            }

                            // Tab 2: Compositor / Tweaks
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 9
                                color: root.activeMode === "hyprland" ? ColorScheme.accent : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f359} Tweaks"
                                    color: root.activeMode === "hyprland" ? ColorScheme.background : ColorScheme.withAlpha(ColorScheme.text, 0.7)
                                    font.bold: true
                                    font.pixelSize: 11
                                    font.family: "Inter"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeMode = "hyprland"
                                }
                            }

                            // Tab 3: NixOS
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 9
                                color: root.activeMode === "nixos" ? ColorScheme.accent : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f313} NixOS"
                                    color: root.activeMode === "nixos" ? ColorScheme.background : ColorScheme.withAlpha(ColorScheme.text, 0.7)
                                    font.bold: true
                                    font.pixelSize: 11
                                    font.family: "Inter"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeMode = "nixos"
                                }
                            }
                        }
                    }

                    // Mode Specific Sidebar Items: Cheatsheet Categories
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: root.activeMode === "cheatsheet"

                        Text {
                            text: "Categories"
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.42)
                            font.bold: true
                            font.pixelSize: 9
                            font.family: "Inter"
                            font.letterSpacing: 0.8
                        }

                        Repeater {
                            model: root.categories
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: 10
                                property bool hovered: false
                                color: root.activeCategory === modelData.id
                                    ? ColorScheme.withAlpha(ColorScheme.accent, 0.16)
                                    : (hovered ? ColorScheme.withAlpha(ColorScheme.surface, 0.45) : "transparent")
                                border.color: root.activeCategory === modelData.id ? ColorScheme.withAlpha(ColorScheme.accent, 0.34) : ColorScheme.withAlpha(ColorScheme.text, 0.06)
                                border.width: 1

                                Rectangle {
                                    visible: root.activeCategory === modelData.id
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 18
                                    radius: 2
                                    color: ColorScheme.accent
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 10

                                    Text {
                                        text: modelData.icon
                                        color: root.activeCategory === modelData.id ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.62)
                                        font.pixelSize: 15
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        text: modelData.name
                                        color: root.activeCategory === modelData.id ? ColorScheme.text : ColorScheme.withAlpha(ColorScheme.text, 0.72)
                                        font.pixelSize: 12
                                        font.bold: root.activeCategory === modelData.id
                                        font.family: "Inter"
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: root.loadCategory(modelData.id)
                                    onEntered: parent.hovered = true
                                    onExited: parent.hovered = false
                                }
                            }
                        }
                    }

                    // Mode Specific Sidebar Items: Hyprland Quick Links
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: root.activeMode === "hyprland"

                        Text {
                            text: "Preset Profiles"
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.42)
                            font.bold: true
                            font.pixelSize: 9
                            font.family: "Inter"
                            font.letterSpacing: 0.8
                        }

                        Repeater {
                            model: [
                                { id: "work", name: "Work / Focus", icon: "\u{f0b1}" },
                                { id: "study", name: "Study / Research", icon: "\u{f02d}" },
                                { id: "gaming", name: "Gaming / Max FPS", icon: "\u{f11b}" },
                                { id: "streaming", name: "Streaming Mode", icon: "\u{f03d}" }
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: 10
                                property bool active: HyprlandRuntimeService.activePreset === modelData.id
                                color: active ? ColorScheme.withAlpha(ColorScheme.accent, 0.20) : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                                border.color: active ? ColorScheme.accent : ColorScheme.glassBorder
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8
                                    Text {
                                        text: modelData.icon
                                        color: parent.parent.active ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.7)
                                        font.pixelSize: 14
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                    Text {
                                        text: modelData.name
                                        color: ColorScheme.text
                                        font.pixelSize: 11
                                        font.family: "Inter"
                                        font.bold: parent.parent.active
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: HyprlandRuntimeService.applyPreset(modelData.id)
                                }
                            }
                        }
                    }

                    // Mode Specific Sidebar Items: NixOS Quick Status
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: root.activeMode === "nixos"

                        Text {
                            text: "Nix Store Status"
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.42)
                            font.bold: true
                            font.pixelSize: 9
                            font.family: "Inter"
                            font.letterSpacing: 0.8
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: 12
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.3)
                            border.color: ColorScheme.glassBorder
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Store Size:"; color: ColorScheme.withAlpha(ColorScheme.text, 0.6); font.pixelSize: 11; font.family: "Inter" }
                                    Item { Layout.fillWidth: true }
                                    Text { text: NixMonitorService.storeSize; color: ColorScheme.accent; font.bold: true; font.pixelSize: 12; font.family: "Inter" }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Generation:"; color: ColorScheme.withAlpha(ColorScheme.text, 0.6); font.pixelSize: 11; font.family: "Inter" }
                                    Item { Layout.fillWidth: true }
                                    Text { text: "#" + NixMonitorService.currentGeneration; color: ColorScheme.text; font.bold: true; font.pixelSize: 12; font.family: "Inter" }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        text: "Press ESC or click outside to close"
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.3)
                        font.italic: true
                        font.pixelSize: 10
                        font.family: "Inter"
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // ─── MAIN CONTENT AREA ─────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // --- VIEW 1: CHEATSHEETS ---
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 18
                    visible: root.activeMode === "cheatsheet"

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: {
                                var name = "Commands";
                                for (let i = 0; i < root.categories.length; i++) {
                                    if (root.categories[i].id === root.activeCategory) {
                                        name = root.categories[i].name + " Commands";
                                        break;
                                    }
                                }
                                return name + " (" + visibleModel.count + ")";
                            }
                            color: ColorScheme.text
                            font.bold: true
                            font.pixelSize: 22
                            font.family: "Inter"
                        }
                        Item { Layout.fillWidth: true }

                        // Filter Menu Button
                        Rectangle {
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 32
                            radius: 16
                            color: root.activeTagFilter === "" ? ColorScheme.withAlpha(ColorScheme.surface, 0.36) : ColorScheme.withAlpha(ColorScheme.accent, 0.2)
                            border.color: root.activeTagFilter === "" ? ColorScheme.glassBorder : ColorScheme.accent
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 6
                                Text { text: "\uf0b0"; color: ColorScheme.accent; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font" }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.activeTagFilter === "" ? "All filters" : root.activeTagFilter
                                    color: ColorScheme.text
                                    font.pixelSize: 11
                                    font.family: "Inter"
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tagMenu.popup()
                            }
                        }

                        Menu {
                            id: tagMenu
                            Repeater {
                                model: ["All shortcuts"].concat(root.availableTags)
                                delegate: MenuItem {
                                    text: modelData
                                    checkable: true
                                    checked: (modelData === "All shortcuts" && root.activeTagFilter === "") || root.activeTagFilter === modelData
                                    onTriggered: {
                                        root.activeTagFilter = modelData === "All shortcuts" ? "" : modelData;
                                        refreshVisibleEntries();
                                    }
                                }
                            }
                        }
                    }

                    GridView {
                        id: grid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cellWidth: Math.max(280, Math.floor(width / 3))
                        cellHeight: 88
                        model: visibleModel
                        clip: true

                        delegate: Rectangle {
                            width: grid.cellWidth - 10
                            height: 80
                            clip: true
                            radius: 12
                            property bool hovered: false
                            property var actionParts: splitActionText(model.action)
                            color: hovered ? ColorScheme.withAlpha(ColorScheme.surface, 0.48) : ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                            border.color: hovered ? ColorScheme.withAlpha(ColorScheme.accent, 0.30) : ColorScheme.glassBorder
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Rectangle {
                                        Layout.preferredHeight: 24
                                        Layout.preferredWidth: Math.min(Math.max(keycapText.implicitWidth + 16, 60), 200)
                                        radius: 6
                                        color: ColorScheme.withAlpha(ColorScheme.background, 0.90)
                                        border.color: ColorScheme.withAlpha(ColorScheme.text, 0.16)
                                        border.width: 1

                                        Text {
                                            id: keycapText
                                            anchors.centerIn: parent
                                            text: (model.mod && model.mod !== "" ? model.mod + " + " : "") + model.key
                                            color: ColorScheme.text
                                            font.bold: true
                                            font.pixelSize: 11
                                            font.family: "JetBrainsMono Nerd Font"
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        visible: actionParts.tag !== ""
                                        Layout.preferredHeight: 20
                                        Layout.preferredWidth: tagText.implicitWidth + 12
                                        radius: 10
                                        color: ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                                        border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.28)
                                        border.width: 1

                                        Text {
                                            id: tagText
                                            anchors.centerIn: parent
                                            text: actionParts.tag
                                            color: ColorScheme.accent
                                            font.bold: true
                                            font.pixelSize: 9
                                            font.family: "Inter"
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: actionParts.body
                                    color: ColorScheme.withAlpha(ColorScheme.text, 0.78)
                                    font.pixelSize: 11
                                    font.family: "Inter"
                                    elide: Text.ElideRight
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    maximumLineCount: 2
                                }
                            }
                        }
                    }
                }

                // --- VIEW 2: HYPRLAND COMPOSITOR TWEAKS ---
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 28
                    contentHeight: hyprContentCol.implicitHeight
                    clip: true
                    visible: root.activeMode === "hyprland"

                    ColumnLayout {
                        id: hyprContentCol
                        width: parent.width
                        spacing: 24

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Hyprland Live Tweaks & Customizer"
                                color: ColorScheme.text
                                font.bold: true
                                font.pixelSize: 22
                                font.family: "Inter"
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 32
                                radius: 16
                                color: ColorScheme.withAlpha(ColorScheme.accent, 0.2)
                                border.color: ColorScheme.accent
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f0e2} Reset Defaults"
                                    color: ColorScheme.accent
                                    font.bold: true
                                    font.pixelSize: 11
                                    font.family: "Inter"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: HyprlandRuntimeService.resetToDefaults()
                                }
                            }
                        }

                        // Geometry & Layout Sliders
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 180
                            radius: 16
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.3)
                            border.color: ColorScheme.glassBorder
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 14

                                Text {
                                    text: "\u{f009}  Gaps & Geometry"
                                    color: ColorScheme.accent
                                    font.bold: true
                                    font.pixelSize: 14
                                    font.family: "Inter"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 20

                                    SmartSlider {
                                        Layout.fillWidth: true
                                        title: "Outer Gaps"
                                        value: HyprlandRuntimeService.gapsOut
                                        minValue: 0
                                        maxValue: 40
                                        step: 2
                                        suffix: "px"
                                        onValueChangedByUser: (v) => HyprlandRuntimeService.setGapsOut(v)
                                    }

                                    SmartSlider {
                                        Layout.fillWidth: true
                                        title: "Inner Gaps"
                                        value: HyprlandRuntimeService.gapsIn
                                        minValue: 0
                                        maxValue: 30
                                        step: 2
                                        suffix: "px"
                                        onValueChangedByUser: (v) => HyprlandRuntimeService.setGapsIn(v)
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 20

                                    SmartSlider {
                                        Layout.fillWidth: true
                                        title: "Corner Rounding"
                                        value: HyprlandRuntimeService.rounding
                                        minValue: 0
                                        maxValue: 26
                                        step: 2
                                        suffix: "px"
                                        onValueChangedByUser: (v) => HyprlandRuntimeService.setRounding(v)
                                    }

                                    SmartSlider {
                                        Layout.fillWidth: true
                                        title: "Border Size"
                                        value: HyprlandRuntimeService.borderSize
                                        minValue: 0
                                        maxValue: 8
                                        step: 1
                                        suffix: "px"
                                        onValueChangedByUser: (v) => HyprlandRuntimeService.setBorderSize(v)
                                    }
                                }
                            }
                        }

                        // Effects & Opacity
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 180
                            radius: 16
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.3)
                            border.color: ColorScheme.glassBorder
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 14

                                Text {
                                    text: "\u{f042}  Effects & Compositor Shaders"
                                    color: ColorScheme.accent
                                    font.bold: true
                                    font.pixelSize: 14
                                    font.family: "Inter"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 20

                                    SmartSlider {
                                        Layout.fillWidth: true
                                        title: "Inactive Window Opacity"
                                        value: Math.round(HyprlandRuntimeService.inactiveOpacity * 100)
                                        minValue: 40
                                        maxValue: 100
                                        step: 5
                                        suffix: "%"
                                        onValueChangedByUser: (v) => HyprlandRuntimeService.setInactiveOpacity(v / 100.0)
                                    }

                                    SmartSlider {
                                        Layout.fillWidth: true
                                        title: "Blur Passes"
                                        value: HyprlandRuntimeService.blurPasses
                                        minValue: 1
                                        maxValue: 5
                                        step: 1
                                        suffix: "x"
                                        onValueChangedByUser: (v) => HyprlandRuntimeService.setBlurPasses(v)
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 16

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        radius: 10
                                        color: HyprlandRuntimeService.blurEnabled ? ColorScheme.withAlpha(ColorScheme.accent, 0.20) : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                                        border.color: HyprlandRuntimeService.blurEnabled ? ColorScheme.accent : ColorScheme.glassBorder
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: HyprlandRuntimeService.blurEnabled ? "\u{f00c} Blur: Enabled" : "\u{f00d} Blur: Disabled"
                                            color: ColorScheme.text
                                            font.bold: true
                                            font.pixelSize: 11
                                            font.family: "Inter"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: HyprlandRuntimeService.toggleBlur()
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        radius: 10
                                        color: HyprlandRuntimeService.animationsEnabled ? ColorScheme.withAlpha(ColorScheme.accent, 0.20) : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                                        border.color: HyprlandRuntimeService.animationsEnabled ? ColorScheme.accent : ColorScheme.glassBorder
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: HyprlandRuntimeService.animationsEnabled ? "\u{f00c} Animations: Enabled" : "\u{f00d} Animations: Disabled"
                                            color: ColorScheme.text
                                            font.bold: true
                                            font.pixelSize: 11
                                            font.family: "Inter"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: HyprlandRuntimeService.toggleAnimations()
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        radius: 10
                                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.35)
                                        border.color: ColorScheme.glassBorder
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\u{f065} Center Active Window"
                                            color: ColorScheme.text
                                            font.bold: true
                                            font.pixelSize: 11
                                            font.family: "Inter"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: HyprlandRuntimeService.centerActiveWindow()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- VIEW 3: NIXOS CONTROL & ACTIONS ---
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 20
                    visible: root.activeMode === "nixos"

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "NixOS System Management"
                            color: ColorScheme.text
                            font.bold: true
                            font.pixelSize: 22
                            font.family: "Inter"
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 32
                            radius: 16
                            color: ColorScheme.withAlpha(ColorScheme.accent, 0.2)
                            border.color: ColorScheme.accent
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "\u{f021} Refresh Store Info"
                                color: ColorScheme.accent
                                font.bold: true
                                font.pixelSize: 11
                                font.family: "Inter"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NixMonitorService.refresh(true)
                            }
                        }
                    }

                    // System Cards Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            radius: 16
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.35)
                            border.color: ColorScheme.glassBorder
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                Text { text: "\u{f313} Generation"; color: ColorScheme.accent; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
                                Text { text: "#" + NixMonitorService.currentGeneration; color: ColorScheme.text; font.bold: true; font.pixelSize: 20; font.family: "Inter" }
                                Text { text: "Total generations: " + NixMonitorService.totalGenerations; color: ColorScheme.withAlpha(ColorScheme.text, 0.5); font.pixelSize: 10; font.family: "Inter" }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            radius: 16
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.35)
                            border.color: ColorScheme.glassBorder
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                Text { text: "\u{f1c0} Nix Store"; color: ColorScheme.accent; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
                                Text { text: NixMonitorService.storeSize; color: ColorScheme.text; font.bold: true; font.pixelSize: 20; font.family: "Inter" }
                                Text { text: "Paths: " + (NixMonitorService.storePathCount > 0 ? NixMonitorService.storePathCount : "Scanning..."); color: ColorScheme.withAlpha(ColorScheme.text, 0.5); font.pixelSize: 10; font.family: "Inter" }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            radius: 16
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.35)
                            border.color: ColorScheme.glassBorder
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                Text { text: "\u{f1f8} Garbage Collection"; color: ColorScheme.accent; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
                                Text { text: NixMonitorService.gcReclaimable; color: ColorScheme.text; font.bold: true; font.pixelSize: 20; font.family: "Inter" }
                                Text { text: "Reclaimable space"; color: ColorScheme.withAlpha(ColorScheme.text, 0.5); font.pixelSize: 10; font.family: "Inter" }
                            }
                        }
                    }

                    // System Quick Actions
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        radius: 16
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.3)
                        border.color: ColorScheme.glassBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 12

                            Text {
                                text: "\u{f0e7}  Quick Build & Switch Tasks"
                                color: ColorScheme.accent
                                font.bold: true
                                font.pixelSize: 14
                                font.family: "Inter"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    radius: 12
                                    color: ColorScheme.withAlpha(ColorScheme.accent, 0.18)
                                    border.color: ColorScheme.accent
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text { text: "\u{f015}"; color: ColorScheme.accent; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font" }
                                        Text { text: "Switch Home (just homeup-fast)"; color: ColorScheme.text; font.bold: true; font.pixelSize: 11; font.family: "Inter" }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var p = Qt.createQmlObject('import Quickshell.Io; Process { command: ["kitty", "-e", "just", "homeup-fast"]; running: true }', root);
                                            p.exited.connect(function() { p.destroy(); });
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    radius: 12
                                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.40)
                                    border.color: ColorScheme.glassBorder
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text { text: "\u{f108}"; color: ColorScheme.text; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font" }
                                        Text { text: "Switch System (just sysup-fast)"; color: ColorScheme.text; font.bold: true; font.pixelSize: 11; font.family: "Inter" }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var p = Qt.createQmlObject('import Quickshell.Io; Process { command: ["kitty", "-e", "just", "sysup-fast"]; running: true }', root);
                                            p.exited.connect(function() { p.destroy(); });
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    radius: 12
                                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.40)
                                    border.color: ColorScheme.glassBorder
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text { text: "\u{f188}"; color: ColorScheme.text; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font" }
                                        Text { text: "Run Tests (just testos)"; color: ColorScheme.text; font.bold: true; font.pixelSize: 11; font.family: "Inter" }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var p = Qt.createQmlObject('import Quickshell.Io; Process { command: ["kitty", "-e", "just", "testos"]; running: true }', root);
                                            p.exited.connect(function() { p.destroy(); });
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
