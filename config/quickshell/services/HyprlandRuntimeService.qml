pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * HyprlandRuntimeService - Live tweaks for Hyprland compositor (Hyprmod-style).
 * Enables live-tuning of gaps, rounding, borders, blur, animations, and scene presets
 * without touching declarative NixOS configurations.
 */
Singleton {
    id: root

    // Compositor Runtime Properties with safe defaults matching default.nix
    property int gapsIn: 6
    property int gapsOut: 10
    property int borderSize: 3
    property int rounding: 14
    property real activeOpacity: 1.0
    property real inactiveOpacity: 0.92
    property bool blurEnabled: true
    property int blurSize: 6
    property int blurPasses: 2
    property bool animationsEnabled: true
    property string activeLayout: "dwindle"
    property string activePreset: "work"

    readonly property string hyprScriptsDir: RuntimePaths.hyprScriptsDir

    Process {
        id: cmdRunner
        command: []
    }

    function runCmd(args) {
        if (!args || args.length === 0) return;
        cmdRunner.exec(args);
    }

    function setKeyword(key, val) {
        runCmd(["hyprctl", "keyword", String(key), String(val)]);
    }

    // --- Live Mutators ---
    function setGapsIn(val) {
        gapsIn = Math.max(0, Math.min(50, Math.round(val)));
        setKeyword("general:gaps_in", gapsIn);
    }

    function setGapsOut(val) {
        gapsOut = Math.max(0, Math.min(80, Math.round(val)));
        setKeyword("general:gaps_out", gapsOut);
    }

    function setBorderSize(val) {
        borderSize = Math.max(0, Math.min(10, Math.round(val)));
        setKeyword("general:border_size", borderSize);
    }

    function setRounding(val) {
        rounding = Math.max(0, Math.min(30, Math.round(val)));
        setKeyword("decoration:rounding", rounding);
    }

    function setActiveOpacity(val) {
        activeOpacity = Math.max(0.2, Math.min(1.0, Number(val) || 1.0));
        setKeyword("decoration:active_opacity", activeOpacity.toFixed(2));
    }

    function setInactiveOpacity(val) {
        inactiveOpacity = Math.max(0.2, Math.min(1.0, Number(val) || 0.92));
        setKeyword("decoration:inactive_opacity", inactiveOpacity.toFixed(2));
    }

    function toggleBlur() {
        blurEnabled = !blurEnabled;
        setKeyword("decoration:blur:enabled", blurEnabled ? "true" : "false");
    }

    function setBlurPasses(val) {
        blurPasses = Math.max(1, Math.min(5, Math.round(val)));
        setKeyword("decoration:blur:passes", blurPasses);
    }

    function toggleAnimations() {
        animationsEnabled = !animationsEnabled;
        setKeyword("animations:enabled", animationsEnabled ? "true" : "false");
    }

    function setLayout(layoutName) {
        activeLayout = layoutName;
        setKeyword("general:layout", layoutName);
    }

    function applyPreset(presetName) {
        activePreset = presetName;
        runCmd(["bash", hyprScriptsDir + "/scene_preset.sh", presetName]);
    }

    function centerActiveWindow() {
        runCmd(["bash", hyprScriptsDir + "/center_window.sh"]);
    }

    function resetToDefaults() {
        setGapsIn(6);
        setGapsOut(10);
        setBorderSize(3);
        setRounding(14);
        setActiveOpacity(1.0);
        setInactiveOpacity(0.92);
        blurEnabled = true;
        setKeyword("decoration:blur:enabled", "true");
        setBlurPasses(2);
        animationsEnabled = true;
        setKeyword("animations:enabled", "true");
        setLayout("dwindle");
        runCmd(["hyprctl", "reload"]);
    }
}
