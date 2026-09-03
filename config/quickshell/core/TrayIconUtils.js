.pragma library
Qt.include("../shared/IconResolver.js")

var iconAliases = {
    "kdeconnectindicatordark": "kdeconnect",
    "kdeconnectindicator": "kdeconnect",
    "kde connect": "kdeconnect",
    "indicador do kde connect": "kdeconnect",
    "thunar": "org.xfce.thunar",
    "org xfce thunar": "org.xfce.thunar",
    "brave": "brave-browser",
    "brave browser": "brave-browser",
    "code": "vscode",
    "visual studio code": "vscode",
    "vscodium": "vscodium",
    "kitty": "utilities-terminal",
    "foot": "utilities-terminal",
    "wezterm": "utilities-terminal",
    "alacritty": "utilities-terminal",
    "firefox": "firefox",
    "google chrome": "google-chrome",
    "chrome": "google-chrome",
    "chromium": "chromium-browser",
    "discord": "discord",
    "vesktop": "discord",
    "telegram": "telegram",
    "telegram desktop": "telegram",
    "telegramdesktop": "telegram",
    "steam": "steam",
    "blueman": "blueman",
    "blueman applet": "blueman",
    "dropbox": "dropbox",
    "syncthing": "syncthing",
    "signal": "signal-desktop",
    "signal desktop": "signal-desktop",
    "whatsapp": "whatsapp",
    "spotify": "spotify-client",
    "slack": "slack",
    "obsidian": "obsidian",
    "obs": "obs",
    "obs studio": "obs",
    "zoom": "Zoom",
    "teams": "teams",
    "audio": "audio-volume-high",
    "volume": "audio-volume-high",
    "bluetooth": "bluetooth-active",
    "network": "network-wireless",
    "wifi": "network-wireless",
    "battery": "battery-good"
};

var _reverseAliases = null;
var _normalizeCache = {};

function stringify(value) {
    if (value === undefined || value === null)
        return "";

    var text = String(value).trim();
    return text === "[object Object]" ? "" : text;
}

function normalizeKey(value) {
    var text = stringify(value).toLowerCase();
    if (text === "")
        return "";

    if (_normalizeCache[text] !== undefined)
        return _normalizeCache[text];

    var result = text.replace(/[_.-]+/g, " ").replace(/\s+/g, " ").trim();
    _normalizeCache[text] = result;
    return result;
}

function normalizeSource(value) {
    var text = stringify(value);
    if (text === "")
        return "";

    if (text.indexOf("://") >= 0 || text.indexOf("data:") === 0 || text.indexOf("qrc:/") === 0)
        return text;

    if (text.charAt(0) === "/")
        return "file://" + text;

    if (text.indexOf("/nix/store/") >= 0)
        return "file://" + text;

    return "image://icon/" + text;
}

function candidateValues(item) {
    var values = [];

    function push(value) {
        var text = stringify(value);
        if (text !== "" && values.indexOf(text) < 0)
            values.push(text);
    }

    if (item) {
        push(item.icon);
        push(item.iconName);
        push(item.id);
        push(item.appId);
        push(item.title);
        push(item.tooltipTitle);

        if (item.icon && item.icon.indexOf("/") >= 0) {
            var parts = item.icon.split("/");
            var last = parts[parts.length - 1];
            push(last.replace(/\.[a-z0-9]+$/i, ""));
        }
    }

    return values;
}

function _ensureReverseAliases() {
    if (_reverseAliases !== null)
        return;
    _reverseAliases = {};
    for (var key in iconAliases) {
        var val = iconAliases[key];
        if (!_reverseAliases[val])
            _reverseAliases[val] = [];
        _reverseAliases[val].push(key);
    }
}

function resolveAliasName(item) {
    return IconResolver.resolveAliasName(item) || "preferences-system-windows";
}

function primaryIconSource(item) {
    return IconResolver.primaryIconSource(item);
}

function fallbackSource(item) {
    return IconResolver.fallbackSource(item);
}

function fallbackGlyph(item) {
    return IconResolver.fallbackGlyph(item);
}
