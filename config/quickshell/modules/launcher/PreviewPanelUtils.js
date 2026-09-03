.pragma library

function showSmartIcon(previewPanelMode) {
    var hiddenModes = ["calc", "web", "clipboard", "translate", "snippets", "snippet", "ai", "ai_assist", "cmd", "cmd_terminal", "hw_volume", "hw_brightness", "window"];
    return hiddenModes.indexOf(String(previewPanelMode || "")) < 0;
}

function fallbackIconForItem(currentMode, item, getModeInfoFn, resultGlyphIconFn) {
    if (String(currentMode || "") === "ai" && !item) return getModeInfoFn("ai").icon;
    return resultGlyphIconFn(item);
}
