.pragma library

var _customHomeDir = "";

function setHomeDir(path) {
    _customHomeDir = String(path || "");
}

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
    "battery": "battery-good",
    "btop": "system-monitor",
    "preferences-system-network": "network-wireless",
    "nm connection editor": "preferences-system-network",
    "qt6ct": "preferences-desktop-theme",
    "qt6-settings": "preferences-desktop-theme",
    "qt5ct": "preferences-desktop-theme",
    "qt5-settings": "preferences-desktop-theme",
    "com.mitchellh.ghostty": "utilities-terminal",
    "ghostty": "utilities-terminal",
    "org.wezfurlong.wezterm": "utilities-terminal",
    "pcmanfm": "system-file-manager",
    "nautilus": "org.gnome.Nautilus",
    "dolphin": "folder-open",
    "org.kde.dolphin": "folder-open",
    "ark": "utilities-archiver",
    "transmission": "transmission",
    "qbittorrent": "qbittorrent",
    "org.qbittorrent.qBittorrent": "qbittorrent",
    "pavucontrol": "audio-card",
    "inkscape": "inkscape",
    "gimp": "gimp",
    "kdenlive": "kdenlive",
    "virt-manager": "virt-manager",
    "wireshark": "wireshark",
    "blender": "blender",
    "hyprland": "hyprland",
    "wallpaper": "preferences-desktop-wallpaper",
    "wallpaper engine": "preferences-desktop-wallpaper",
    "random wallpaper": "preferences-desktop-wallpaper",
    "dnd": "dnd",
    "dnd mode": "dnd",
    "não perturbe": "dnd",
    "nao perturbe": "dnd",
    "do not disturb": "dnd",
    "do not disturb ativado": "dnd",
    "do not disturb desativado": "dnd",
    "caffeine": "caffeine",
    "caffeinate": "caffeine",
    "energy core": "power",
    "energy": "power",
    "presentation mode": "video-display",
    "presentation": "video-display",
    "utility hub": "applications-utilities",
    "utility": "applications-utilities",
    "color picker": "color-picker",
    "hyprpicker": "color-picker",
    "google lens": "system-search",
    "recording": "media-record",
    "record": "media-record",
    "quickshell usb": "drive-removable-media",
    "usb": "drive-removable-media",
    "gamemode": "input-gaming",
    "game mode": "input-gaming",
    "quick note": "accessories-text-editor",
    "quicknote": "accessories-text-editor",
    "ocr": "edit-copy",
    "screenshot": "applets-screenshooter",
    "screenshooter": "applets-screenshooter",
    "grim": "applets-screenshooter",
    "slurp": "applets-screenshooter",
    "brightness": "display-brightness",
    "power profile": "power",
    "system": "dialog-information",
    "sistema": "dialog-information",
    "quickshell": "dialog-information",
    "dashboard": "preferences-system",
    "daily briefing": "dialog-information",
    "nixos": "nix-snowflake",
    "nix-snowflake": "nix-snowflake",
    "chromium-browser": "chromium-browser",
    "neovim": "nvim",
    "nvim": "nvim",
    "vim": "vim",
    "emacs": "emacs",
    "lutris": "lutris",
    "heroic": "heroic",
    "obs-studio": "obs",
    "element": "element-desktop",
    "thunderbird": "thunderbird",
    "geany": "geany",
    "gedit": "org.gnome.gedit",
    "leafpad": "leafpad",
    "mousepad": "org.xfce.mousepad",
    "calculator": "accessories-calculator",
    "gnome-calculator": "accessories-calculator",
    "kcalc": "accessories-calculator"
};

var _reverseAliases = null;
var _normalizeCache = {};
var _aliasCache = {};
var _candidateCache = {};
var _successCache = {};
var _normalizedAliases = null;
var _normalizedAliasKeys = null;

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

    if (text.charAt(0) === "/" || text.indexOf("/nix/store/") >= 0)
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
        if (typeof item === "string") {
            push(item);
        } else {
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

function _ensureNormalizedAliases() {
    if (_normalizedAliases !== null)
        return;

    _normalizedAliases = {};
    _normalizedAliasKeys = [];

    for (var key in iconAliases) {
        var normalized = normalizeKey(key);
        if (normalized === "")
            continue;
        if (_normalizedAliases[normalized] === undefined)
            _normalizedAliases[normalized] = iconAliases[key];
        if (_normalizedAliasKeys.indexOf(normalized) < 0)
            _normalizedAliasKeys.push(normalized);
    }
}

function _lookupAlias(name) {
    _ensureNormalizedAliases();

    if (iconAliases[name] !== undefined)
        return iconAliases[name];

    var normalized = normalizeKey(name);
    if (normalized !== "" && _normalizedAliases[normalized] !== undefined)
        return _normalizedAliases[normalized];

    return "";
}

function _resolveAliasTarget(name) {
    var current = stringify(name);
    var resolved = current;
    var seen = {};

    while (current !== "") {
        var normalized = normalizeKey(current);
        if (normalized === "" || seen[normalized])
            break;

        seen[normalized] = true;

        var next = _lookupAlias(current);
        if (!next)
            break;

        resolved = next;
        current = next;
    }

    return resolved;
}

function resolveAliasName(item) {
    _ensureReverseAliases();
    var values = candidateValues(item);
    var cacheKey = values.join("\u001f");
    if (_aliasCache[cacheKey] !== undefined)
        return _aliasCache[cacheKey];

    var i;
    for (i = 0; i < values.length; i++) {
        var exact = _lookupAlias(values[i]);
        if (exact) {
            _aliasCache[cacheKey] = _resolveAliasTarget(exact);
            return _aliasCache[cacheKey];
        }
    }

    for (i = 0; i < values.length; i++) {
        var normalized = normalizeKey(values[i]);
        if (normalized === "")
            continue;

        for (var keyIndex = 0; keyIndex < _normalizedAliasKeys.length; keyIndex++) {
            var key = _normalizedAliasKeys[keyIndex];
            if (normalized.indexOf(key) >= 0) {
                _aliasCache[cacheKey] = _resolveAliasTarget(_lookupAlias(key));
                return _aliasCache[cacheKey];
            }
        }
    }

    _aliasCache[cacheKey] = "";
    return "";
}

function primaryIconSource(item) {
    if (!item) return "";
    if ((item.status === 2 || String(item.status || "").indexOf("NeedsAttention") >= 0) && item.attentionIcon) {
        return normalizeSource(item.attentionIcon);
    }
    return normalizeSource(item.icon || "");
}

function fallbackSource(item) {
    return normalizeSource(resolveAliasName(item) || "preferences-system-windows");
}

function fallbackGlyph(item) {
    var raw = normalizeKey(item);
    var alias = resolveAliasName(item);
    var name = (raw + " " + alias).trim();

    // Specific Power Profiles
    if (name.indexOf("performance") >= 0 || name.indexOf("desempenho") >= 0)
        return "\uf0e4";
    if (name.indexOf("power saver") >= 0 || name.indexOf("powersaver") >= 0 || name.indexOf("power-saver") >= 0 || name.indexOf("saver") >= 0 || name.indexOf("economia") >= 0 || name.indexOf("poupanca") >= 0)
        return "\uf242";
    if (name.indexOf("balanced") >= 0 || name.indexOf("equilibrado") >= 0)
        return "\uf0e7";

    // DND States (Active vs Restored)
    if (name.indexOf("desativado") >= 0 || name.indexOf("desactivado") >= 0 || name.indexOf("unmuted") >= 0 || name.indexOf("restaurad") >= 0)
        return "\uf0f3";
    if (name.indexOf("dnd") >= 0 || name.indexOf("perturbe") >= 0 || name.indexOf("disturb") >= 0 || name.indexOf("silenc") >= 0)
        return "\uf1f6";

    // Hardware metrics
    if (name === "cpu" || name.indexOf("cpu") >= 0)
        return "\uf2db";
    if (name === "memory" || name === "ram" || name.indexOf("mem") >= 0)
        return "\uf538";
    if (name === "temp" || name === "temperature" || name.indexOf("temp") >= 0)
        return "\uf2c9";
    if (name === "gpu" || name.indexOf("gpu") >= 0)
        return "\uf26c";

    if (name.indexOf("caffein") >= 0 || name.indexOf("coffee") >= 0 || name.indexOf("idle") >= 0)
        return "\uf0f4";
    if (name.indexOf("present") >= 0)
        return "\uf26c";
    if (name.indexOf("color") >= 0 || name.indexOf("picker") >= 0 || name.indexOf("cor") >= 0)
        return "\uf1fb";
    if (name.indexOf("lens") >= 0)
        return "\uf002";
    if (name.indexOf("record") >= 0 || name.indexOf("grava") >= 0)
        return "\uf03d";
    if (name.indexOf("usb") >= 0)
        return "\uf287";
    if (name.indexOf("pin") >= 0)
        return "\uf08d";
    if (name.indexOf("macro") >= 0)
        return "\uf12e";
    if (name.indexOf("save") >= 0 || name.indexOf("restore") >= 0 || name.indexOf("snapshot") >= 0)
        return "\uf0c7";
    if (name.indexOf("utilit") >= 0 || name.indexOf("tool") >= 0)
        return "\uf0ad";
    if (name.indexOf("briefing") >= 0)
        return "\uf0eb";
    if (name.indexOf("chat") >= 0)
        return "\uf086";
    if (name.indexOf("monitor") >= 0 || name.indexOf("display") >= 0)
        return "\uf108";
    if (name.indexOf("dash") >= 0 || name.indexOf("fix") >= 0)
        return "\uf0e4";
    if (name.indexOf("preset") >= 0 || (name.indexOf("profile") >= 0 && name.indexOf("power") < 0))
        return "\uf1de";
    if (name === "kdeconnect" || name === "syncthing" || name === "dropbox" || name.indexOf("connect") >= 0)
        return "\uf021";
    if (name === "org.xfce.thunar" || name.indexOf("folder") >= 0 || name.indexOf("file") >= 0)
        return "\uf07b";
    if (name === "brave-browser" || name === "firefox" || name === "google-chrome" || name === "chromium-browser" || name.indexOf("browser") >= 0)
        return "\uf268";
    if (name === "vscode" || name === "vscodium" || name.indexOf("code") >= 0)
        return "\uf121";
    if (name === "utilities-terminal" || name === "kitty" || name === "foot" || name === "ghostty" || name === "wezterm" || name === "alacritty" || name.indexOf("term") >= 0)
        return "\uf120";
    if (name === "discord" || name === "vesktop")
        return "\uf392";
    if (name === "telegram")
        return "\uf2c6";
    if (name === "steam")
        return "\uf1b6";
    if (name === "blueman" || name === "bluetooth-active" || name.indexOf("blue") >= 0)
        return "\uf293";
    if (name === "audio-volume-high" || name === "audio-card" || name.indexOf("audio") >= 0 || name.indexOf("volume") >= 0 || name.indexOf("sound") >= 0 || name.indexOf("pipewire") >= 0)
        return "\uf028";
    if (name === "network-wireless" || name.indexOf("wifi") >= 0 || name.indexOf("net") >= 0 || name.indexOf("rede") >= 0)
        return "\uf1eb";
    if (name === "signal-desktop" || name === "whatsapp" || name === "slack")
        return "\uf27a";
    if (name === "input-gaming" || name.indexOf("game") >= 0)
        return "\uf11b";
    if (name.indexOf("wallpaper") >= 0 || name.indexOf("wall") >= 0)
        return "\uf03e";
    if (name.indexOf("center") >= 0 || name.indexOf("move") >= 0 || name.indexOf("janela") >= 0)
        return "\uf0b2";
    if (name.indexOf("layout") >= 0)
        return "\uf009";
    if (name.indexOf("note") >= 0)
        return "\uf249";
    if (name.indexOf("ocr") >= 0 || name.indexOf("copy") >= 0)
        return "\uf0c5";
    if (name.indexOf("screen") >= 0 || name.indexOf("shot") >= 0)
        return "\uf030";
    if (name.indexOf("power") >= 0 || name.indexOf("battery") >= 0 || name.indexOf("energy") >= 0)
        return "\uf0e7";
    if (name.indexOf("hyprland") >= 0 || name === "nix-snowflake" || name === "nixos")
        return "\uf069";
    if (name.indexOf("system") >= 0 || name.indexOf("sistema") >= 0 || name.indexOf("quickshell") >= 0)
        return "\uf0f3";

    return "\uf0f3";
}

function iconFallbackPath(iconName) {
    var id = normalizeKey(iconName);
    if (id === "")
        return "";

    var alias = resolveAliasName(id);
    if (alias !== "" && alias !== id)
        return "image://icon/" + alias;

    if (id.indexOf("terminal") >= 0)
        return "image://icon/utilities-terminal";
    if (id.indexOf("browser") >= 0)
        return "image://icon/internet-web-browser";
    if (id.indexOf("editor") >= 0)
        return "image://icon/text-editor";
    if (id.indexOf("settings") >= 0)
        return "image://icon/preferences-desktop-theme";

    return "";
}

function resolveIconSource(iconName) {
    var text = stringify(iconName);
    if (text === "")
        return "";
    if (text.indexOf("://") >= 0 || text.indexOf("data:") === 0 || text.indexOf("qrc:/") === 0)
        return text;
    if (text.charAt(0) === "/" || text.indexOf("/nix/store/") >= 0)
        return "file://" + text;

    var fallback = iconFallbackPath(text);
    if (fallback !== "")
        return fallback;

    return "image://icon/" + text;
}

function buildCandidates(iconName, extraRoots) {
    var text = stringify(iconName);
    if (text === "")
        return [];
    if (_successCache[text] !== undefined)
        return [_successCache[text]];
    if (_candidateCache[text] !== undefined)
        return _candidateCache[text];

    var pureGlyphs = ["cpu", "memory", "ram", "temp", "temperature", "gpu", "nix-snowflake", "nixos"];
    if (pureGlyphs.indexOf(text.toLowerCase()) >= 0) {
        _candidateCache[text] = [];
        return _candidateCache[text];
    }

    if (text.indexOf("file://") === 0 || text.indexOf("data:") === 0 || text.indexOf("qrc:/") === 0 || text.indexOf("image://") === 0) {
        _candidateCache[text] = [text];
        return _candidateCache[text];
    }
    if (text.charAt(0) === "/" || text.indexOf("/nix/store/") >= 0) {
        _candidateCache[text] = [normalizeSource(text)];
        return _candidateCache[text];
    }

    var alias = resolveAliasName(text);
    var names = [text];
    if (alias !== "" && names.indexOf(alias) < 0)
        names.push(alias);

    var lower = text.toLowerCase();
    if (names.indexOf(lower) < 0)
        names.push(lower);
    if (text.indexOf(".") >= 0) {
        var parts = text.split(".");
        var last = parts[parts.length - 1];
        if (last.length > 2 && names.indexOf(last) < 0)
            names.push(last);
    }

    var candidates = [];
    var h = _customHomeDir || "";
    var iconRoots = [
        "/usr/share/icons/Papirus-Dark/48x48/apps/",
        "/usr/share/icons/Papirus-Dark/24x24/apps/",
        "/usr/share/icons/Papirus/48x48/apps/",
        "/usr/share/icons/Papirus/24x24/apps/",
        "/usr/share/icons/hicolor/scalable/apps/",
        "/usr/share/icons/hicolor/256x256/apps/",
        "/usr/share/icons/hicolor/48x48/apps/",
        "/usr/share/icons/hicolor/24x24/apps/",
        "/usr/share/icons/Papirus-Dark/24x24/panel/",
        "/usr/share/icons/Papirus-Dark/24x24/status/",
        "/usr/share/icons/Papirus-Dark/24x24/actions/",
        "/usr/share/icons/Papirus-Dark/24x24/devices/",
        "/usr/share/icons/Papirus-Dark/16x16/actions/",
        "/usr/share/icons/Papirus-Dark/16x16/devices/",
        "/usr/share/icons/Papirus-Dark/16x16/panel/",
        "/usr/share/icons/Papirus-Dark/16x16/status/",
        "/usr/share/icons/Papirus-Dark/48x48/actions/",
        "/usr/share/icons/Papirus-Dark/48x48/devices/",
        "/usr/share/pixmaps/",
        "/run/current-system/sw/share/icons/hicolor/scalable/apps/",
        "/run/current-system/sw/share/icons/hicolor/256x256/apps/",
        "/run/current-system/sw/share/icons/hicolor/128x128/apps/",
        "/run/current-system/sw/share/icons/hicolor/48x48/apps/",
        "/run/current-system/sw/share/pixmaps/"
    ];

    if (h !== "") {
        iconRoots.unshift(
            h + "/.local/share/icons/Papirus-Dark/48x48/apps/",
            h + "/.local/share/icons/Papirus-Dark/24x24/apps/",
            h + "/.local/share/icons/hicolor/scalable/apps/",
            h + "/.local/share/icons/hicolor/256x256/apps/",
            h + "/.local/share/icons/hicolor/48x48/apps/",
            h + "/.nix-profile/share/icons/Papirus-Dark/48x48/apps/",
            h + "/.nix-profile/share/icons/Papirus-Dark/24x24/apps/",
            h + "/.nix-profile/share/icons/hicolor/scalable/apps/",
            h + "/.nix-profile/share/icons/hicolor/256x256/apps/",
            h + "/.nix-profile/share/icons/hicolor/48x48/apps/",
            h + "/.nix-profile/share/pixmaps/"
        );
    }

    if (lower.startsWith("dialog-") || lower.startsWith("document-") || lower.startsWith("edit-") || lower.startsWith("help-")) {
        iconRoots.unshift("/usr/share/icons/Papirus-Dark/24x24/actions/", "/usr/share/icons/Papirus-Dark/16x16/actions/");
        if (h !== "") {
            iconRoots.unshift(h + "/.local/share/icons/Papirus-Dark/24x24/actions/", h + "/.nix-profile/share/icons/Papirus-Dark/24x24/actions/");
        }
    } else if (lower.indexOf("device") >= 0 || lower.indexOf("blueman") >= 0 || lower.indexOf("bluetooth") >= 0) {
        iconRoots.unshift("/usr/share/icons/Papirus-Dark/16x16/devices/", "/usr/share/icons/Papirus-Dark/24x24/devices/");
        if (h !== "") {
            iconRoots.unshift(h + "/.local/share/icons/Papirus-Dark/16x16/devices/", h + "/.nix-profile/share/icons/Papirus-Dark/16x16/devices/");
        }
    } else if (lower.indexOf("battery") >= 0 || lower.indexOf("network") >= 0 || lower.indexOf("wifi") >= 0 || lower.indexOf("volume") >= 0) {
        iconRoots.unshift("/usr/share/icons/Papirus-Dark/24x24/status/", "/usr/share/icons/Papirus-Dark/24x24/panel/");
        if (h !== "") {
            iconRoots.unshift(h + "/.local/share/icons/Papirus-Dark/24x24/status/", h + "/.nix-profile/share/icons/Papirus-Dark/24x24/status/");
        }
    }

    if (extraRoots && extraRoots.length !== undefined) {
        for (var extraIndex = extraRoots.length - 1; extraIndex >= 0; extraIndex--) {
            var extraRoot = stringify(extraRoots[extraIndex]);
            if (extraRoot !== "")
                iconRoots.unshift(extraRoot);
        }
    }

    for (var i = 0; i < names.length; i++) {
        var name = names[i];
        if (!name || name === "")
            continue;
        for (var j = 0; j < iconRoots.length; j++) {
            candidates.push("file://" + iconRoots[j] + name + ".svg");
            candidates.push("file://" + iconRoots[j] + name + ".png");
        }
    }

    var resolvedSource = resolveIconSource(text);
    if (resolvedSource !== "" && candidates.indexOf(resolvedSource) < 0)
        candidates.push(resolvedSource);

    for (var k = 0; k < names.length; k++)
        if (candidates.indexOf("image://icon/" + names[k]) < 0)
            candidates.push("image://icon/" + names[k]);

    _candidateCache[text] = candidates;
    return candidates;
}

function rememberSuccess(iconName, workingSource) {
    var text = stringify(iconName);
    var src = stringify(workingSource);
    if (text !== "" && src !== "") {
        _successCache[text] = src;
        _candidateCache[text] = [src];
    }
}

var IconResolver = {
    stringify: stringify,
    normalizeKey: normalizeKey,
    normalizeSource: normalizeSource,
    candidateValues: candidateValues,
    resolveAliasName: resolveAliasName,
    primaryIconSource: primaryIconSource,
    fallbackSource: fallbackSource,
    fallbackGlyph: fallbackGlyph,
    iconFallbackPath: iconFallbackPath,
    resolveIconSource: resolveIconSource,
    buildCandidates: buildCandidates,
    rememberSuccess: rememberSuccess,
    setHomeDir: setHomeDir
};
