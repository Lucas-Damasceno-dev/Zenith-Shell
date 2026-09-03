import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"
import "../services"

/**
 * ClipboardPopup - High-performance, low-latency Wayland Clipboard Manager.
 * Features instant search, category filtering with live counters, keyboard navigation,
 * single-item deletion, two-step wipe confirmation, and theme-adaptive glassmorphism.
 */
PopupWindow {
    id: root

    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.text
    property real popupMargin: DesignTokens.spacingLG

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    showScrim: false
    glassRadius: 0
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0
    originY: 0.0
    originX: 1.0
    slideY: 12

    property string searchQuery: ""
    property string activeCategory: "all"
    property bool confirmWipeArmed: false
    property string toastMessage: ""

    // In-memory cache of raw parsed clip items and filtered display list
    property var rawClipsList: []
    property var filteredClips: []

    property int countTotal: 0
    property int countText: 0
    property int countCode: 0
    property int countUrl: 0
    property int countImage: 0

    onIsOpenChanged: {
        if (isOpen) {
            searchQuery = "";
            activeCategory = "all";
            confirmWipeArmed = false;
            toastMessage = "";
            searchInput.text = "";
            refreshClipboard();
            searchInput.forceActiveFocus();
        } else {
            confirmWipeArmed = false;
        }
    }

    Component.onCompleted: {
        if (isOpen) {
            refreshClipboard();
        }
    }

    function refreshClipboard() {
        clipLoader.exec([
            "bash", "-c",
            "export PATH=\"/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}\"; cliphist list 2>/dev/null || true"
        ]);
    }

    function copyClip(clipId) {
        if (!clipId) return;
        clipCopyProc.exec([
            "bash", "-c",
            "export PATH=\"/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}\"; cliphist decode \"$1\" | wl-copy",
            "--", String(clipId)
        ]);
        showToast("Copiado para o clipboard!");
        closeTimer.restart();
    }

    function deleteClip(clipId, modelIndex) {
        if (!clipId) return;
        clipDeleteProc.exec([
            "bash", "-c",
            "export PATH=\"/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}\"; cliphist list | awk -F'\\t' -v id=\"$1\" '$1 == id { print $0; exit }' | cliphist delete 2>/dev/null || true",
            "--", String(clipId)
        ]);
        
        // Remove immediately from memory for instantaneous UI feedback
        var nextList = [];
        for (var i = 0; i < rawClipsList.length; i++) {
            if (String(rawClipsList[i].clipId) !== String(clipId)) {
                nextList.push(rawClipsList[i]);
            }
        }
        rawClipsList = nextList;
        updateCounts();
        applyFilter();
        showToast("Item removido");
    }

    function wipeHistory() {
        clipWipeProc.exec([
            "bash", "-c",
            "export PATH=\"/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}\"; cliphist wipe 2>/dev/null || true"
        ]);
        rawClipsList = [];
        updateCounts();
        filteredClips = [];
        confirmWipeArmed = false;
        showToast("Histórico limpo");
    }

    function showToast(msg) {
        toastMessage = msg;
        toastTimer.restart();
    }

    function detectCategory(text, isImg) {
        if (isImg) return "image";
        var t = String(text || "").trim();
        if (t.indexOf("http://") === 0 || t.indexOf("https://") === 0 || t.indexOf("www.") === 0) return "url";
        if (t.indexOf("const ") === 0 || t.indexOf("let ") === 0 || t.indexOf("function ") === 0 ||
            t.indexOf("import ") === 0 || t.indexOf("class ") === 0 || t.indexOf("def ") === 0 ||
            t.indexOf("curl ") === 0 || t.indexOf("nix") === 0 || t.indexOf("#!/") === 0 ||
            t.indexOf("SELECT ") === 0 || (t.indexOf("{") === 0 && t.lastIndexOf("}") === t.length - 1)) {
            return "code";
        }
        return "text";
    }

    function getCategoryIcon(cat) {
        if (cat === "image") return "\u{f03e}";
        if (cat === "url") return "\u{f0c1}";
        if (cat === "code") return "\u{f121}";
        return "\u{f0f6}";
    }

    function updateCounts() {
        var total = rawClipsList.length;
        var cText = 0, cCode = 0, cUrl = 0, cImg = 0;
        for (var i = 0; i < total; i++) {
            var c = rawClipsList[i].category;
            if (c === "image") cImg++;
            else if (c === "code") cCode++;
            else if (c === "url") cUrl++;
            else cText++;
        }
        countTotal = total;
        countText = cText;
        countCode = cCode;
        countUrl = cUrl;
        countImage = cImg;
    }

    function parseClipboardData(rawData) {
        var str = String(rawData || "").trim();
        if (!str) {
            rawClipsList = [];
            updateCounts();
            applyFilter();
            return;
        }

        var lines = str.split("\n");
        var maxItems = 100;
        var parsedList = [];

        for (var i = 0; i < lines.length && parsedList.length < maxItems; i++) {
            var line = lines[i].trim();
            if (!line) continue;
            var tabIdx = line.indexOf("\t");
            var id = "";
            var preview = "";
            if (tabIdx > 0) {
                id = line.substring(0, tabIdx).trim();
                preview = line.substring(tabIdx + 1).trim();
            } else {
                var spaceIdx = line.indexOf(" ");
                if (spaceIdx > 0) {
                    id = line.substring(0, spaceIdx).trim();
                    preview = line.substring(spaceIdx + 1).trim();
                } else {
                    id = String(i);
                    preview = line;
                }
            }

            if (!preview) continue;

            var isImg = preview.indexOf("[[ binary data") >= 0 || preview.indexOf("image/") >= 0;
            var cat = detectCategory(preview, isImg);

            var cleanPreview = preview;
            if (isImg) {
                var mimeMatch = preview.match(/image\/[a-zA-Z0-9.+-]+/);
                cleanPreview = "[Imagem] " + (mimeMatch ? mimeMatch[0] : "PNG/JPG");
            }

            parsedList.push({
                "clipId": id || String(i),
                "rawContent": preview,
                "displayContent": cleanPreview,
                "isImage": isImg,
                "category": cat || "text",
                "iconText": getCategoryIcon(cat)
            });
        }

        rawClipsList = parsedList;
        updateCounts();
        applyFilter();
    }

    function applyFilter() {
        var q = root.searchQuery.toLowerCase().trim();
        var cat = root.activeCategory;
        var maxItems = 80;
        var result = [];

        for (var i = 0; i < rawClipsList.length && result.length < maxItems; i++) {
            var item = rawClipsList[i];
            if (cat !== "all" && item.category !== cat) continue;
            if (q !== "" && item.rawContent.toLowerCase().indexOf(q) < 0) continue;

            result.push(item);
        }

        root.filteredClips = result;

        if (result.length > 0) {
            clipListView.currentIndex = 0;
        } else {
            clipListView.currentIndex = -1;
        }
    }

    TimedProcess {
        id: clipLoader
        timeoutMs: 5000
        timeoutLabel: "ClipList"
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseClipboardData(text);
            }
            onRead: (data) => {
                if (data && String(data).trim().length > 0) {
                    root.parseClipboardData(data);
                }
            }
        }
    }

    TimedProcess { id: clipCopyProc; timeoutMs: 3000; timeoutLabel: "ClipCopy" }
    TimedProcess { id: clipDeleteProc; timeoutMs: 3000; timeoutLabel: "ClipDelete" }
    TimedProcess { id: clipWipeProc; timeoutMs: 3000; timeoutLabel: "ClipWipe" }

    Timer {
        id: toastTimer
        interval: 1800
        repeat: false
        onTriggered: root.toastMessage = ""
    }

    Timer {
        id: closeTimer
        interval: 180
        repeat: false
        onTriggered: root.isOpen = false
    }

    Timer {
        id: confirmWipeTimer
        interval: 4000
        repeat: false
        onTriggered: root.confirmWipeArmed = false
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        onClicked: function(mouse) {
            var p = mapToItem(popupCard, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > popupCard.width || p.y > popupCard.height) {
                root.isOpen = false;
            }
        }
    }

    Item {
        id: popupCard
        width: 400
        height: 540
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: popupTopMargin
        anchors.rightMargin: root.popupMargin
        z: 1

        Rectangle {
            id: popupBg
            anchors.fill: parent
            radius: DesignTokens.radiusLG
            color: ColorScheme.glassPopup
            border.width: 1
            border.color: ColorScheme.outlineVariant
        }

        Rectangle {
            anchors.fill: popupBg
            anchors.topMargin: 6
            radius: popupBg.radius
            color: Qt.rgba(0, 0, 0, 0.18)
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: DesignTokens.spacingMD
            spacing: DesignTokens.spacingSM

            // ── Header ──────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: DesignTokens.spacingSM

                Rectangle {
                    width: 32
                    height: 32
                    radius: DesignTokens.radiusSM
                    color: ColorScheme.withAlpha(root.accentColor, 0.18)

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f0ea}"
                        font.family: DesignTokens.fontFamilyMono
                        font.pixelSize: 16
                        color: root.accentColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "Área de Transferência"
                        font.pixelSize: DesignTokens.fontSizeMD
                        font.bold: true
                        font.family: DesignTokens.fontFamily
                        color: root.textColor
                    }

                    Text {
                        text: root.filteredClips.length > 0 
                            ? (root.filteredClips.length + " itens · ↑↓ navegar · ↵ colar")
                            : "Histórico vazio"
                        font.pixelSize: 10
                        font.family: DesignTokens.fontFamily
                        color: ColorScheme.withAlpha(root.textColor, 0.45)
                    }
                }

                // Toast Feedback
                Rectangle {
                    visible: root.toastMessage !== ""
                    height: 24
                    radius: 12
                    color: ColorScheme.withAlpha(ColorScheme.green, 0.20)
                    border.width: 1
                    border.color: ColorScheme.withAlpha(ColorScheme.green, 0.40)
                    implicitWidth: toastTxt.implicitWidth + 16

                    Text {
                        id: toastTxt
                        anchors.centerIn: parent
                        text: root.toastMessage
                        color: ColorScheme.green
                        font.pixelSize: 10
                        font.bold: true
                    }
                }

                // Wipe / Clear History Button
                Rectangle {
                    id: wipeBtn
                    width: root.confirmWipeArmed ? 90 : 30
                    height: 30
                    radius: DesignTokens.radiusSM
                    color: root.confirmWipeArmed
                        ? ColorScheme.withAlpha(ColorScheme.red, 0.25)
                        : (wipeMa.containsMouse ? ColorScheme.glassHover : "transparent")
                    border.width: 1
                    border.color: root.confirmWipeArmed
                        ? ColorScheme.red
                        : (wipeMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.foreground, DesignTokens.hoverBorderOpacity) : "transparent")

                    Behavior on width {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "\u{f1f8}"
                            font.family: DesignTokens.fontFamilyMono
                            font.pixelSize: 12
                            color: root.confirmWipeArmed ? ColorScheme.red : ColorScheme.withAlpha(root.textColor, 0.65)
                        }

                        Text {
                            visible: root.confirmWipeArmed
                            text: "Limpar?"
                            font.pixelSize: 10
                            font.bold: true
                            color: ColorScheme.red
                        }
                    }

                    MouseArea {
                        id: wipeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.confirmWipeArmed) {
                                root.confirmWipeArmed = true;
                                confirmWipeTimer.restart();
                            } else {
                                root.wipeHistory();
                            }
                        }
                    }
                }
            }

            // ── Search Input (Theme-Adaptive) ────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: DesignTokens.radiusMD
                color: ColorScheme.withAlpha(ColorScheme.surfaceContainer, ColorScheme.isDark ? 0.55 : 0.85)
                border.width: 1
                border.color: searchInput.activeFocus ? root.accentColor : ColorScheme.withAlpha(ColorScheme.foreground, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "\u{f002}"
                        font.family: DesignTokens.fontFamilyMono
                        font.pixelSize: 13
                        color: ColorScheme.withAlpha(root.textColor, 0.45)
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.pixelSize: 12
                        font.family: DesignTokens.fontFamily
                        color: root.textColor
                        selectByMouse: true
                        clip: true
                        onTextChanged: {
                            root.searchQuery = text;
                            root.applyFilter();
                        }

                        Keys.onDownPressed: function(event) {
                            if (clipListView.count > 0) {
                                clipListView.currentIndex = Math.min(clipListView.currentIndex + 1, clipListView.count - 1);
                                clipListView.positionViewAtIndex(clipListView.currentIndex, ListView.Contain);
                                event.accepted = true;
                            }
                        }

                        Keys.onUpPressed: function(event) {
                            if (clipListView.count > 0) {
                                clipListView.currentIndex = Math.max(clipListView.currentIndex - 1, 0);
                                clipListView.positionViewAtIndex(clipListView.currentIndex, ListView.Contain);
                                event.accepted = true;
                            }
                        }

                        Keys.onReturnPressed: function(event) {
                            if (clipListView.currentIndex >= 0 && clipListView.currentIndex < root.filteredClips.length) {
                                var item = root.filteredClips[clipListView.currentIndex];
                                if (item && item.clipId) {
                                    root.copyClip(item.clipId);
                                    event.accepted = true;
                                }
                            }
                        }

                        Keys.onEscapePressed: function(event) {
                            root.isOpen = false;
                            event.accepted = true;
                        }

                        Text {
                            anchors.fill: parent
                            text: "Pesquisar no histórico..."
                            color: ColorScheme.withAlpha(root.textColor, 0.35)
                            font.pixelSize: 12
                            font.family: DesignTokens.fontFamily
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }

                    Text {
                        visible: searchInput.text !== ""
                        text: "\u{f00d}"
                        font.family: DesignTokens.fontFamilyMono
                        font.pixelSize: 12
                        color: ColorScheme.withAlpha(root.textColor, 0.45)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // ── Category Filter Chips ────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { key: "all", label: "Todos", count: root.countTotal, icon: "\u{f0ca}" },
                        { key: "text", label: "Texto", count: root.countText, icon: "\u{f0f6}" },
                        { key: "code", label: "Código", count: root.countCode, icon: "\u{f121}" },
                        { key: "url", label: "Links", count: root.countUrl, icon: "\u{f0c1}" },
                        { key: "image", label: "Imagens", count: root.countImage, icon: "\u{f03e}" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isSelected: root.activeCategory === modelData.key

                        Layout.fillWidth: true
                        height: 26
                        radius: 13
                        color: isSelected
                            ? ColorScheme.withAlpha(root.accentColor, 0.22)
                            : (chipMa.containsMouse ? ColorScheme.glassHover : ColorScheme.withAlpha(ColorScheme.surfaceContainer, ColorScheme.isDark ? 0.30 : 0.50))
                        border.width: 1
                        border.color: isSelected
                            ? root.accentColor
                            : ColorScheme.withAlpha(ColorScheme.foreground, 0.10)

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: modelData.icon
                                font.family: DesignTokens.fontFamilyMono
                                font.pixelSize: 10
                                color: isSelected ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.65)
                            }

                            Text {
                                text: modelData.label
                                font.pixelSize: 10
                                font.bold: isSelected
                                color: isSelected ? root.textColor : ColorScheme.withAlpha(root.textColor, 0.75)
                            }

                            Text {
                                visible: modelData.count > 0
                                text: String(modelData.count)
                                font.pixelSize: 9
                                font.family: DesignTokens.fontFamilyMono
                                color: isSelected ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.40)
                            }
                        }

                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeCategory = modelData.key;
                                root.applyFilter();
                            }
                        }
                    }
                }
            }

            // ── Items List View ──────────────────────────────────
            ListView {
                id: clipListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.filteredClips
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: 0
                visible: root.filteredClips.length > 0

                ScrollBar.vertical: ScrollBar {
                    active: true
                    width: 4
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    id: itemDelegate
                    required property var modelData
                    required property int index

                    readonly property bool isCurrent: clipListView.currentIndex === index
                    readonly property bool isHovered: itemMa.containsMouse
                    readonly property bool isImageClip: !!(modelData && modelData.isImage)
                    readonly property string clipCategory: (modelData && modelData.category) ? String(modelData.category) : "text"
                    readonly property string clipIdText: (modelData && modelData.clipId) ? String(modelData.clipId) : ""
                    readonly property string clipDisplayText: (modelData && modelData.displayContent) ? String(modelData.displayContent) : ""
                    readonly property string clipIconText: (modelData && modelData.iconText) ? String(modelData.iconText) : "\u{f0f6}"

                    height: isImageClip ? 56 : 46
                    width: clipListView.width

                    radius: DesignTokens.radiusMD
                    color: isCurrent
                        ? ColorScheme.withAlpha(root.accentColor, 0.20)
                        : (isHovered ? ColorScheme.glassHover : ColorScheme.withAlpha(ColorScheme.surfaceContainer, ColorScheme.isDark ? 0.35 : 0.55))
                    border.width: 1
                    border.color: isCurrent
                        ? root.accentColor
                        : (isHovered ? ColorScheme.withAlpha(root.accentColor, 0.40) : ColorScheme.withAlpha(ColorScheme.foreground, 0.08))

                    Behavior on color { ColorAnimation { duration: 80 } }
                    Behavior on border.color { ColorAnimation { duration: 80 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        // Category Icon Badge
                        Rectangle {
                            width: 28
                            height: 28
                            radius: DesignTokens.radiusSM
                            color: ColorScheme.withAlpha(
                                itemDelegate.clipCategory === "image" ? ColorScheme.peach : 
                                (itemDelegate.clipCategory === "code" ? ColorScheme.yellow : 
                                (itemDelegate.clipCategory === "url" ? ColorScheme.teal : root.accentColor)), 
                                0.18
                            )
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: itemDelegate.clipIconText
                                font.family: DesignTokens.fontFamilyMono
                                font.pixelSize: 13
                                color: itemDelegate.clipCategory === "image" ? ColorScheme.peach : 
                                       (itemDelegate.clipCategory === "code" ? ColorScheme.yellow : 
                                       (itemDelegate.clipCategory === "url" ? ColorScheme.teal : root.accentColor))
                            }
                        }

                        // Content Snippet
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            Text {
                                text: itemDelegate.clipDisplayText
                                color: root.textColor
                                font.pixelSize: itemDelegate.clipCategory === "code" ? 11 : 12
                                font.family: itemDelegate.clipCategory === "code" ? DesignTokens.fontFamilyMono : DesignTokens.fontFamily
                                elide: Text.ElideRight
                                maximumLineCount: itemDelegate.isImageClip ? 1 : 2
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: itemDelegate.isImageClip 
                                    ? "Imagem binária · Clique para copiar" 
                                    : ("#" + itemDelegate.clipIdText + " · " + itemDelegate.clipCategory.toUpperCase())
                                color: ColorScheme.withAlpha(root.textColor, 0.40)
                                font.pixelSize: 9
                                font.family: DesignTokens.fontFamilyMono
                            }
                        }

                        // Quick Delete Button (Revealed on Hover / Focus)
                        Rectangle {
                            width: 26
                            height: 26
                            radius: 13
                            color: delMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.red, 0.25) : "transparent"
                            opacity: isHovered || isCurrent ? 1.0 : 0.0
                            Layout.alignment: Qt.AlignVCenter

                            Behavior on opacity {
                                NumberAnimation { duration: 100 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\u{f1f8}"
                                font.family: DesignTokens.fontFamilyMono
                                font.pixelSize: 11
                                color: delMa.containsMouse ? ColorScheme.red : ColorScheme.withAlpha(root.textColor, 0.55)
                            }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (itemDelegate.modelData && itemDelegate.modelData.clipId) {
                                        root.deleteClip(itemDelegate.modelData.clipId, itemDelegate.index);
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            clipListView.currentIndex = index;
                            if (itemDelegate.modelData && itemDelegate.modelData.clipId) {
                                root.copyClip(itemDelegate.modelData.clipId);
                            }
                        }
                    }
                }
            }

            // ── Empty State ──────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.filteredClips.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "\u{f0ea}"
                        font.family: DesignTokens.fontFamilyMono
                        font.pixelSize: 36
                        color: ColorScheme.withAlpha(root.textColor, 0.20)
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.searchQuery !== "" 
                            ? ("Nenhum resultado para '" + root.searchQuery + "'")
                            : "Nenhum item copiado ainda"
                        font.pixelSize: 13
                        font.bold: true
                        color: ColorScheme.withAlpha(root.textColor, 0.60)
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.searchQuery !== ""
                            ? "Tente buscar com outros termos ou categorias"
                            : "Copie textos ou imagens para vê-los listados aqui"
                        font.pixelSize: 10
                        color: ColorScheme.withAlpha(root.textColor, 0.40)
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
