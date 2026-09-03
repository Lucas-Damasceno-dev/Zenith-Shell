.pragma library

function trackedBinaries() {
    return [
        "nmcli",
        "bluetoothctl",
        "playerctl",
        "grim",
        "slurp",
        "wf-recorder",
        "hyprpicker",
        "tesseract",
        "curl",
        "swappy",
        "wpctl",
        "upower",
        "powerprofilesctl",
        "brightnessctl",
        "hyprctl",
        "quickshell",
        "btop",
        "wl-copy",
        "xdg-open"
    ];
}

function defaultStatus() {
    var bins = trackedBinaries();
    var status = {};
    for (var i = 0; i < bins.length; i++) status[bins[i]] = false;
    return status;
}

function checkArgs() {
    var bins = trackedBinaries();
    var script = "export PATH=\"$HOME/.nix-profile/bin:$PATH\";"
        + "printf \"__HEALTH_BEGIN__\\n\";"
        + "for b in " + bins.join(" ")
        + "; do if command -v \"$b\" >/dev/null 2>&1; then printf \"%s=1\\n\" \"$b\"; else printf \"%s=0\\n\" \"$b\"; fi; done;"
        + "printf \"__HEALTH_END__\\n\"";
    return ["bash", "-c", script];
}

function parseStatus(rawText) {
    var status = defaultStatus();
    var lines = String(rawText || "").split(/\r?\n/);

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "" || line.indexOf("=") <= 0) continue;
        var idx = line.indexOf("=");
        var key = line.substring(0, idx);
        var value = line.substring(idx + 1);
        if (status[key] !== undefined) status[key] = value === "1" || value === "true";
    }

    return status;
}

function isAvailable(status, binary) {
    if (!status || status[binary] === undefined) return false;
    return status[binary] === true;
}

function dependenciesForAction(actionKey) {
    if (actionKey === "shot-full") return ["grim", "wl-copy"];
    if (actionKey === "shot-window") return ["grim", "wl-copy"];
    if (actionKey === "shot-region") return ["grim", "slurp", "wl-copy"];
    if (actionKey === "shot-annotate") return ["grim", "slurp", "swappy", "wl-copy"];
    if (actionKey === "shot-active-mode") return ["grim", "wl-copy", "slurp"];
    if (actionKey === "rec-full") return ["wf-recorder"];
    if (actionKey === "rec-region") return ["wf-recorder", "slurp"];
    if (actionKey === "ocr") return ["grim", "slurp", "tesseract", "wl-copy"];
    if (actionKey === "lens") return ["grim", "slurp", "curl", "xdg-open"];
    if (actionKey === "color") return ["hyprpicker", "wl-copy"];
    if (actionKey === "copy-color-rgb" || actionKey === "copy-color-hsl") return ["hyprpicker", "wl-copy"];
    if (actionKey && actionKey.indexOf("display-") === 0) return ["hyprctl"];
    return [];
}

function missingDependencies(status, deps) {
    var missing = [];
    for (var i = 0; i < deps.length; i++) {
        if (!isAvailable(status, deps[i])) missing.push(deps[i]);
    }
    return missing;
}

function utilityHubDeps() {
    return ["grim", "slurp", "wf-recorder", "hyprpicker", "tesseract", "swappy"];
}

function utilityHubAvailable(status) {
    return missingDependencies(status, utilityHubDeps()).length === 0;
}
