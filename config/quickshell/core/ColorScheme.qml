pragma Singleton
import QtQuick
import Quickshell.Io

/**
 * ColorScheme - Singleton Stylix-aware color provider.
 */
QtObject {
    id: scheme

    // ─── Base16 Palette (Mocha defaults) ────────────────────────
    readonly property color base00: "#11111b"
    readonly property color base01: "#181825"
    readonly property color base02: "#313244"
    readonly property color base03: "#45475a"
    readonly property color base04: "#6c7086"
    readonly property color base05: "#cdd6f4"
    readonly property color base06: "#f5e0dc"
    readonly property color base07: "#b4befe"
    readonly property color base08: "#f38ba8"
    readonly property color base09: "#fab387"
    readonly property color base0A: "#f9e2af"
    readonly property color base0B: "#a6e3a1"
    readonly property color base0C: "#94e2d5"
    readonly property color base0D: "#89b4fa"
    readonly property color base0E: "#cba6f7"
    readonly property color base0F: "#f2cdcd"

    // ─── Matugen Backend (Backing Properties) ───────────────────
    property bool _hasMatugenAccent: false
    property bool _hasMatugenOnSurface: false
    property bool _hasMatugenBackground: false
    property color _matugenAccent: base0D
    property color _matugenOnSurface: base05
    property color _matugenBackground: base00
    property string _matugenMode: ""
    property var _matugenColors: ({})

    Behavior on _matugenAccent { ColorAnimation { duration: 300 } }
    Behavior on _matugenOnSurface { ColorAnimation { duration: 300 } }
    Behavior on _matugenBackground { ColorAnimation { duration: 350 } }

    // ─── Theme Detection ────────────────────────────────────────
    property bool isDark: {
        if (_matugenMode === "dark") return true;
        if (_matugenMode === "light") return false;
        if (_hasMatugenBackground) return colorLuminance(_matugenBackground) < 0.5;
        let hour = new Date().getHours();
        return hour < 6 || hour >= 18;
    }

    // ─── Semantic Aliases ───────────────────────────────────────
    property color background: {
        let c = matugenTokenColor("background", "surface");
        return c !== "" ? c : (_hasMatugenBackground ? _matugenBackground : (isDark ? base00 : "#ffffff"));
    }
    Behavior on background { enabled: !FeatureFlags.reducedMotion; ColorAnimation { duration: 350; easing.type: Easing.OutCubic } }

    property color surface: {
        let c = matugenTokenColor("surface", "background");
        return c !== "" ? c : (_hasMatugenBackground ? _matugenBackground : (isDark ? base02 : "#fafafa"));
    }
    Behavior on surface { enabled: !FeatureFlags.reducedMotion; ColorAnimation { duration: 350; easing.type: Easing.OutCubic } }

    property color surfaceLow: {
        let c = matugenTokenColor("surface_container_low");
        return c !== "" ? c : (isDark ? lighter(surface, 1.05) : darker(surface, 1.02));
    }
    Behavior on surfaceLow { enabled: !FeatureFlags.reducedMotion; ColorAnimation { duration: 350; easing.type: Easing.OutCubic } }

    property color surfaceContainer: {
        let c = matugenTokenColor("surface_container", "surface_variant");
        return c !== "" ? c : (isDark ? lighter(background, 1.20) : darker(background, 1.05));
    }
    Behavior on surfaceContainer { enabled: !FeatureFlags.reducedMotion; ColorAnimation { duration: 350; easing.type: Easing.OutCubic } }

    property color surfaceMid: {
        let c = matugenTokenColor("surface_container_high", "surface_container");
        return c !== "" ? c : (isDark ? lighter(surfaceContainer, 1.06) : darker(surfaceContainer, 1.03));
    }
    Behavior on surfaceMid { enabled: !FeatureFlags.reducedMotion; ColorAnimation { duration: 350; easing.type: Easing.OutCubic } }

    property color surfaceHigh: {
        let c = matugenTokenColor("surface_container_highest", "surface_container_high");
        return c !== "" ? c : (isDark ? lighter(surfaceMid, 1.05) : darker(surfaceMid, 1.02));
    }
    Behavior on surfaceHigh { enabled: !FeatureFlags.reducedMotion; ColorAnimation { duration: 350; easing.type: Easing.OutCubic } }

    property color accent: {
        let c = matugenTokenColor("primary");
        return c !== "" ? c : (_hasMatugenAccent ? _matugenAccent : base0D);
    }
    Behavior on accent { enabled: !FeatureFlags.reducedMotion; ColorAnimation { duration: 350; easing.type: Easing.OutCubic } }

    property color accentAlt: {
        let c = matugenTokenColor("secondary", "tertiary");
        return c !== "" ? c : (isDark ? lighter(accent, 1.16) : darker(accent, 1.10));
    }
    Behavior on accentAlt { enabled: !FeatureFlags.reducedMotion; ColorAnimation { duration: 350; easing.type: Easing.OutCubic } }

    readonly property color onPrimary: {
        let c = matugenTokenColor("on_primary");
        return c !== "" ? c : contrastColorFor(accent);
    }

    property color text: {
        let c = matugenTokenColor("on_surface", "on_background");
        if (c === "" && _hasMatugenOnSurface) c = _matugenOnSurface;
        if (c !== "") {
            let lum = colorLuminance(c);
            if (isDark && lum < 0.42) return "#eeeeee";
            if (!isDark && lum > 0.70) return "#1a1a1a";
            return c;
        }
        return isDark ? base05 : "#1a1a1a";
    }
    Behavior on text { enabled: !FeatureFlags.reducedMotion; ColorAnimation { duration: 350; easing.type: Easing.OutCubic } }
    readonly property color textSecondary: withAlpha(text, isDark ? 0.74 : 0.80)
    readonly property color textTertiary: withAlpha(text, isDark ? 0.56 : 0.62)
    readonly property color textDisabled: withAlpha(text, isDark ? 0.38 : 0.42)
    readonly property color textAlt: textSecondary
    readonly property color subtext1: textSecondary
    readonly property color subtext0: textTertiary
    readonly property color onSurface: text
    readonly property color foreground: text
    readonly property color scrim: Qt.rgba(0, 0, 0, isDark ? 0.42 : 0.28)
    readonly property color glassHighlight: withAlpha(text, 0.05)
    property color overlay: {
        let c = matugenTokenColor("surface_variant", "outline_variant");
        return c !== "" ? c : blend(surfaceContainer, foreground, isDark ? 0.18 : 0.10);
    }
    Behavior on overlay { enabled: !FeatureFlags.reducedMotion; ColorAnimation { duration: 350; easing.type: Easing.OutCubic } }

    property color outlineVariant: {
        let c = matugenTokenColor("outline_variant", "outline");
        return c !== "" ? c : withAlpha(text, isDark ? 0.18 : 0.14);
    }
    Behavior on outlineVariant { enabled: !FeatureFlags.reducedMotion; ColorAnimation { duration: 350; easing.type: Easing.OutCubic } }

    readonly property color red:    base08
    readonly property color peach:  base09
    readonly property color yellow: base0A
    readonly property color green:  base0B
    readonly property color teal:   base0C
    readonly property color blue:   base0D
    readonly property color mauve:  base0E

    // ─── Glassmorphism Presets (Adaptive Opacity) ───────────────
    readonly property color panelBg: withAlpha(surfaceContainer, isDark ? 0.84 : 0.94)
    readonly property color glassBg: withAlpha(surfaceContainer, isDark ? 0.86 : 0.96)
    readonly property color glassBorder: withAlpha(outlineVariant, isDark ? 0.60 : 0.78)
    readonly property color glassShadow: Qt.rgba(0, 0, 0, isDark ? 0.45 : 0.15)
    readonly property color glassBar: withAlpha(surfaceContainer, isDark ? 0.90 : 0.98)
    readonly property color glassDock: withAlpha(surfaceMid, isDark ? 0.45 : 0.65)
    readonly property color glassCard: withAlpha(surfaceContainer, isDark ? 0.74 : 0.92)
    readonly property color glassPopup: withAlpha(surfaceMid, isDark ? 0.60 : 0.80)
    readonly property color glassModal: withAlpha(surfaceHigh, isDark ? 0.94 : 0.99)
    readonly property color glassHover: withAlpha(foreground, isDark ? 0.10 : 0.08)

    // ─── State Colors ───────────────────────────────────────────
    readonly property color stateSelected: withAlpha(accent, isDark ? 0.25 : 0.35)
    readonly property color stateHover: withAlpha(accent, isDark ? 0.12 : 0.10)
    readonly property color statePressed: withAlpha(accent, isDark ? 0.20 : 0.16)
    readonly property color stateDisabled: withAlpha(foreground, isDark ? 0.10 : 0.08)
    readonly property color stateLoading: withAlpha(accentAlt, isDark ? 0.16 : 0.12)
    readonly property color stateDestructive: withAlpha(red, isDark ? 0.18 : 0.14)
    readonly property color stateSuccess: withAlpha(green, isDark ? 0.18 : 0.14)
    readonly property color stateWarning: withAlpha(yellow, isDark ? 0.18 : 0.14)

    // ─── Gradients ──────────────────────────────────────────────
    readonly property color accentGradientStart: accent
    readonly property color accentGradientEnd: accentAlt
    readonly property color successGradientStart: green
    readonly property color successGradientEnd: blend(green, teal, 0.35)
    readonly property color warningGradientStart: yellow
    readonly property color warningGradientEnd: blend(yellow, peach, 0.45)
    readonly property color dangerGradientStart: red
    readonly property color dangerGradientEnd: blend(red, peach, 0.35)

    // ─── Matugen Loader ─────────────────────────────────────────
    readonly property string colorsPath: RuntimePaths.joinPath(RuntimePaths.genericCacheDir, "quickshell/matugen/colors.json")

    function reload() {
        _colorLoader.running = false;
        _colorLoader.running = true;
    }

    property var _colorLoader: Process {
        id: colorLoader
        running: false
        command: ["cat", colorsPath]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = String(text || "").trim();
                if (raw === "") return;
                try {
                    let json = JSON.parse(raw);
                    if (!json || !json.colors) return;

                    let mode = scheme.resolveMatugenMode(json);
                    let palette = json.colors;
                    let primary = scheme.resolveMatugenColor(palette.primary, mode);
                    let onSurface = scheme.resolveMatugenColor(palette.on_surface || palette.on_background, mode);
                    let background = scheme.resolveMatugenColor(palette.background || palette.surface, mode);

                    scheme._matugenColors = palette;
                    scheme._matugenMode = mode;
                    scheme._hasMatugenAccent = primary !== "";
                    scheme._hasMatugenOnSurface = onSurface !== "";
                    scheme._hasMatugenBackground = background !== "";

                    if (primary !== "") scheme._matugenAccent = primary;
                    if (onSurface !== "") scheme._matugenOnSurface = onSurface;
                    if (background !== "") scheme._matugenBackground = background;
                } catch (e) {
                    console.warn("[ColorScheme] JSON error: " + e);
                }
            }
        }
    }

    Component.onCompleted: reload()

    // ─── Utils ──────────────────────────────────────────────────
    function asColorObject(value) {
        if (value === undefined || value === null || value === "") return null;
        if (typeof value === "string") {
            let text = value.trim();
            if (text.startsWith("#") && (text.length === 7 || text.length === 9)) {
                let r = parseInt(text.slice(1, 3), 16) / 255.0;
                let g = parseInt(text.slice(3, 5), 16) / 255.0;
                let b = parseInt(text.slice(5, 7), 16) / 255.0;
                let a = text.length === 9 ? (parseInt(text.slice(7, 9), 16) / 255.0) : 1.0;
                return Qt.rgba(r, g, b, a);
            }
            return null;
        }
        if (value.r !== undefined && value.g !== undefined && value.b !== undefined)
            return value;
        return null;
    }

    function colorLuminance(value) {
        let c = asColorObject(value);
        if (!c) return 0;
        return (c.r * 0.299) + (c.g * 0.587) + (c.b * 0.114);
    }

    function contrastColorFor(value) {
        return colorLuminance(value) > 0.58 ? "#1a1a1a" : "#f5f5f5";
    }

    function withAlpha(color, alpha) {
        let c = asColorObject(color);
        if (!c) return Qt.rgba(1, 1, 1, alpha);
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    function blend(colorA, colorB, amount) {
        let a = asColorObject(colorA);
        let b = asColorObject(colorB);
        if (!a && !b) return "transparent";
        if (!a) return b;
        if (!b) return a;
        let t = Math.max(0, Math.min(Number(amount || 0), 1));
        return Qt.rgba(
            a.r + ((b.r - a.r) * t),
            a.g + ((b.g - a.g) * t),
            a.b + ((b.b - a.b) * t),
            a.a + ((b.a - a.a) * t)
        );
    }

    function resolveMatugenMode(json) {
        if (!json) return "";
        if (json.mode === "dark" || json.mode === "light") return json.mode;
        if (typeof json.is_dark_mode === "boolean") return json.is_dark_mode ? "dark" : "light";

        let backgroundValue = json.colors ? (json.colors.background || json.colors.surface) : null;
        if (typeof backgroundValue === "string")
            return colorLuminance(backgroundValue) < 0.5 ? "dark" : "light";

        let darkColor = resolveMatugenColor(backgroundValue, "dark");
        let lightColor = resolveMatugenColor(backgroundValue, "light");
        if (darkColor !== "" && lightColor !== "" && darkColor !== lightColor)
            return colorLuminance(darkColor) <= colorLuminance(lightColor) ? "dark" : "light";

        let resolvedColor = resolveMatugenColor(backgroundValue, "default");
        if (resolvedColor !== "")
            return colorLuminance(resolvedColor) < 0.5 ? "dark" : "light";

        return "";
    }

    function resolveMatugenColor(value, preferredMode) {
        if (typeof value === "string") return value;
        if (!value) return "";

        let mode = preferredMode || _matugenMode || (isDark ? "dark" : "light");
        let altMode = mode === "dark" ? "light" : "dark";

        if (value[mode] && value[mode].color) return value[mode].color;
        if (value.default && value.default.color) return value.default.color;
        if (value[altMode] && value[altMode].color) return value[altMode].color;
        return value.color || value.hex || "";
    }

    function matugenTokenColor(name, fallbackName) {
        if (!_matugenColors) return "";

        let names = [];
        if (name) names.push(name);
        if (Array.isArray(fallbackName)) names = names.concat(fallbackName);
        else if (fallbackName) names.push(fallbackName);

        for (let i = 0; i < names.length; i++) {
            let key = names[i];
            if (!key || !_matugenColors[key]) continue;
            let color = resolveMatugenColor(_matugenColors[key], _matugenMode);
            if (color !== "") return color;
        }
        return "";
    }

    function lighter(color, factor) { return Qt.lighter(asColorObject(color) || color, factor || 1.3); }
    function darker(color, factor) { return Qt.darker(asColorObject(color) || color, factor || 1.3); }
}
