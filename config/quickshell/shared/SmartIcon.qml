pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtCore
import Qt5Compat.GraphicalEffects
import Quickshell
import "IconResolver.js" as IconResolver
import "../core"

/**
 * SmartIcon - Resilient, zero-checkerboard icon component with multi-stage fallback.
 */
Item {
    id: root

    // --- Public API ---
    property string source: ""          // Name, Path, or URL
    property string label: ""           // Used for letter/glyph fallback (e.g. "Caffeinate", "Firefox")
    property string context: ""         // Rich context string (e.g. "Hyprland Power profile Perfil: performance")
    property real size: 24              // Dimensions
    property real sourceSize: size * 2   // Decode size for raster sources
    property color color: ColorScheme.text
    property bool colorOverlay: false   // If true, forces the icon to be the 'color' property
    property bool useThemeProvider: true
    property string fallbackIcon: ""    // Ultimate fallback glyph
    
    readonly property int status: iconImage ? iconImage.status : Image.Null
    readonly property real _iconImplicitWidth: iconImage ? iconImage.implicitWidth : size
    readonly property real _iconImplicitHeight: iconImage ? iconImage.implicitHeight : size
    implicitWidth: size
    implicitHeight: size

    width: size
    height: size

    // Internal candidate resolution state
    property var _candidates: []
    property int _currentIndex: 0
    property bool _imageFailed: false

    onSourceChanged: updateCandidates()
    onSourceSizeChanged: updateCandidates()
    onUseThemeProviderChanged: updateCandidates()

    Component.onCompleted: {
        IconResolver.setHomeDir(RuntimePaths.homeDir);
        updateCandidates();
    }

    function isDirectFile(src) {
        var s = String(src || "").trim();
        return s.indexOf("/") === 0 || s.indexOf("file://") === 0 || s.indexOf("data:") === 0 || s.indexOf("qrc:/") === 0;
    }

    function updateCandidates() {
        var src = String(source || "").trim();
        if (src === "") {
            _candidates = [];
            _currentIndex = 0;
            _imageFailed = true;
            if (iconImage) iconImage.source = "";
            return;
        }

        if (isDirectFile(src)) {
            _candidates = [src.indexOf("://") >= 0 ? src : ("file://" + src)];
            _currentIndex = 0;
            _imageFailed = false;
            if (iconImage) iconImage.source = _candidates[0];
            return;
        }

        // Action titles / notification summaries with spaces are not icon filenames on disk
        if (src.indexOf(" ") >= 0) {
            _candidates = [];
            _currentIndex = 0;
            _imageFailed = true;
            if (iconImage) iconImage.source = "";
            return;
        }

        _candidates = IconResolver.buildCandidates(src);
        _currentIndex = 0;
        _imageFailed = _candidates.length === 0;

        if (iconImage) {
            if (_candidates.length > 0) {
                iconImage.source = _candidates[0];
            } else {
                iconImage.source = "";
            }
        }
    }

    Component.onCompleted: updateCandidates()

    // ── Semantic Color Palette ──────────────────────────────────
    function getFallbackColor(str) {
        var raw = String(str || "").toLowerCase();
        if (raw.indexOf("desativado") >= 0 || raw.indexOf("desactivado") >= 0 || raw.indexOf("unmuted") >= 0 || raw.indexOf("restaurad") >= 0)
            return ColorScheme.green;
        if (raw.indexOf("dnd") >= 0 || raw.indexOf("disturb") >= 0 || raw.indexOf("perturbe") >= 0 || raw.indexOf("silenc") >= 0)
            return ColorScheme.yellow;
        if (raw.indexOf("performance") >= 0 || raw.indexOf("desempenho") >= 0)
            return ColorScheme.red;
        if (raw.indexOf("power saver") >= 0 || raw.indexOf("powersaver") >= 0 || raw.indexOf("power-saver") >= 0 || raw.indexOf("saver") >= 0 || raw.indexOf("economia") >= 0 || raw.indexOf("poupanca") >= 0)
            return ColorScheme.green;
        if (raw.indexOf("balanced") >= 0 || raw.indexOf("equilibrado") >= 0)
            return ColorScheme.blue;
        if (raw.indexOf("caffein") >= 0 || raw.indexOf("coffee") >= 0 || raw.indexOf("idle") >= 0)
            return ColorScheme.peach;
        if (raw.indexOf("power") >= 0 || raw.indexOf("energy") >= 0 || raw.indexOf("battery") >= 0)
            return ColorScheme.peach;
        if (raw.indexOf("game") >= 0)
            return ColorScheme.green;
        if (raw.indexOf("record") >= 0 || raw.indexOf("grava") >= 0 || raw.indexOf("critical") >= 0)
            return ColorScheme.red;
        if (raw.indexOf("lens") >= 0 || raw.indexOf("search") >= 0 || raw.indexOf("ocr") >= 0)
            return ColorScheme.blue;
        if (raw.indexOf("wall") >= 0 || raw.indexOf("image") >= 0)
            return ColorScheme.mauve;

        let hash = 0;
        for (let i = 0; i < raw.length; i++) {
            hash = raw.charCodeAt(i) + ((hash << 5) - hash);
        }
        const colors = [
            ColorScheme.red, ColorScheme.peach, ColorScheme.yellow, 
            ColorScheme.green, ColorScheme.teal, ColorScheme.blue, 
            ColorScheme.mauve, ColorScheme.accent
        ];
        return colors[Math.abs(hash) % colors.length];
    }

    readonly property color _fallbackColor: getFallbackColor(root.context || root.label || root.source)
    readonly property color fallbackColor: _fallbackColor

    // ── Semantic Glyph ──────────────────────────────────────────
    readonly property string _resolvedGlyph: {
        var g = IconResolver.fallbackGlyph(root.context || root.label || root.source);
        if (g && g !== "" && g !== "\uf0f3") return g;
        if (root.fallbackIcon !== "") return root.fallbackIcon;
        return g || "\uf0f3";
    }

    // 1. Main Image Component
    Image {
        id: iconImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
        sourceSize.width: Math.max(1, root.sourceSize)
        sourceSize.height: Math.max(1, root.sourceSize)
        
        visible: status === Image.Ready && !root._imageFailed && implicitWidth > 1 && implicitHeight > 1
        
        onStatusChanged: {
            if (status === Image.Error || (status === Image.Ready && (implicitWidth <= 1 || implicitHeight <= 1))) {
                tryNextCandidate();
            } else if (status === Image.Ready) {
                IconResolver.rememberSuccess(root.source, source);
            }
        }

        function tryNextCandidate() {
            if (root._currentIndex + 1 < root._candidates.length) {
                root._currentIndex++;
                source = root._candidates[root._currentIndex];
            } else {
                root._imageFailed = true;
                source = "";
            }
        }
    }

    // 2. High-Definition Nerd Font Glyph
    Text {
        id: glyphText
        anchors.centerIn: parent
        visible: !iconImage.visible && root._resolvedGlyph !== ""
        text: root._resolvedGlyph
        font.family: DesignTokens.fontFamilyMono + ", Symbols Nerd Font Mono, monospace"
        font.pixelSize: Math.round(root.size * 0.75)
        color: root._fallbackColor
        renderType: Text.NativeRendering
    }

    // 3. Initial Avatar Fallback
    Text {
        id: letterText
        anchors.centerIn: parent
        visible: !iconImage.visible && !glyphText.visible && (root.label !== "" || (root.source !== "" && !root.source.includes("/")))
        text: {
            let t = root.label || root.source;
            if (t.includes(".")) t = t.split(".").pop();
            return t.charAt(0).toUpperCase();
        }
        font.family: DesignTokens.fontFamilyUI
        font.weight: Font.Bold
        font.pixelSize: Math.round(root.size * 0.70)
        color: root._fallbackColor
        renderType: Text.NativeRendering
    }

    // 4. Default Bell Fallback
    Text {
        id: defaultText
        anchors.centerIn: parent
        visible: !iconImage.visible && !glyphText.visible && !letterText.visible
        text: "\u{f0f3}"
        font.family: DesignTokens.fontFamilyMono + ", Symbols Nerd Font Mono, monospace"
        font.pixelSize: Math.round(root.size * 0.75)
        color: ColorScheme.accent
        renderType: Text.NativeRendering
    }
}
