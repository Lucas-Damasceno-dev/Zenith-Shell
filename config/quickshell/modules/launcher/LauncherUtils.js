.pragma library

var CACHE_COUNT_KEY = "\u0000count";

function normalizeText(text, cache) {
    if (!text)
        return "";

    var key = String(text);
    if (cache && cache[key] !== undefined)
        return cache[key];

    var result = key.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
    if (cache) {
        cache[key] = result;
        if (cache.__count === undefined)
            cache.__count = 0;
        cache.__count += 1;
        cache[CACHE_COUNT_KEY] = cache.__count;
    }
    return result;
}

function normalizeCacheSize(cache) {
    if (!cache || cache[CACHE_COUNT_KEY] === undefined)
        return 0;
    return Number(cache[CACHE_COUNT_KEY]) || 0;
}

function safeMathEvaluate(expr) {
    var source = String(expr || "").trim();
    if (source === "")
        return null;

    var tokens = [];
    var index = 0;

    while (index < source.length) {
        var ch = source.charAt(index);
        if (/\s/.test(ch)) {
            index++;
            continue;
        }

        if ("+-*/^()%".indexOf(ch) >= 0) {
            tokens.push({ type: ch });
            index++;
            continue;
        }

        var rest = source.substring(index);
        var numberMatch = rest.match(/^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/);
        if (numberMatch) {
            tokens.push({ type: "number", value: parseFloat(numberMatch[0]) });
            index += numberMatch[0].length;
            continue;
        }

        var nameMatch = rest.match(/^[a-zA-Z_][a-zA-Z0-9_]*/);
        if (nameMatch) {
            tokens.push({ type: "name", value: nameMatch[0].toLowerCase() });
            index += nameMatch[0].length;
            continue;
        }

        return null;
    }

    var position = 0;

    function peek() {
        return position < tokens.length ? tokens[position] : null;
    }

    function consume(type) {
        var token = peek();
        if (!token || token.type !== type)
            return null;
        position++;
        return token;
    }

    function applyPercentSuffix(value) {
        while (peek() && peek().type === "%") {
            position++;
            value = value / 100;
        }
        return value;
    }

    function applyFunction(name, value) {
        switch (name) {
        case "sin":
            return Math.sin(value);
        case "cos":
            return Math.cos(value);
        case "tan":
            return Math.tan(value);
        case "sqrt":
            return Math.sqrt(value);
        case "log":
            return Math.log(value) / Math.LN10;
        case "ln":
            return Math.log(value);
        case "abs":
            return Math.abs(value);
        default:
            return null;
        }
    }

    function parseExpression() {
        var value = parseTerm();
        if (value === null)
            return null;

        while (peek() && (peek().type === "+" || peek().type === "-")) {
            var op = peek().type;
            position++;
            var rhs = parseTerm();
            if (rhs === null)
                return null;
            value = op === "+" ? value + rhs : value - rhs;
        }
        return value;
    }

    function parseTerm() {
        var value = parseUnary();
        if (value === null)
            return null;

        while (peek() && (peek().type === "*" || peek().type === "/")) {
            var op = peek().type;
            position++;
            var rhs = parseUnary();
            if (rhs === null)
                return null;
            value = op === "*" ? value * rhs : value / rhs;
        }
        return value;
    }

    function parseUnary() {
        var token = peek();
        if (token && token.type === "+") {
            position++;
            return parseUnary();
        }
        if (token && token.type === "-") {
            position++;
            var negative = parseUnary();
            return negative === null ? null : -negative;
        }
        return parsePower();
    }

    function parsePower() {
        var left = parsePrimary();
        if (left === null)
            return null;

        if (peek() && peek().type === "^") {
            position++;
            var right = parseUnary();
            if (right === null)
                return null;
            return Math.pow(left, right);
        }
        return left;
    }

    function parsePrimary() {
        var token = peek();
        if (!token)
            return null;

        if (token.type === "number") {
            position++;
            return applyPercentSuffix(token.value);
        }

        if (token.type === "name") {
            position++;
            var name = token.value;
            if (name === "pi")
                return applyPercentSuffix(Math.PI);
            if (name === "e")
                return applyPercentSuffix(Math.E);

            if (!peek() || peek().type !== "(")
                return null;

            position++;
            var value = parseExpression();
            if (value === null || !peek() || peek().type !== ")")
                return null;
            position++;
            value = applyFunction(name, value);
            if (value === null)
                return null;
            return applyPercentSuffix(value);
        }

        if (token.type === "(") {
            position++;
            var inner = parseExpression();
            if (inner === null || !peek() || peek().type !== ")")
                return null;
            position++;
            return applyPercentSuffix(inner);
        }

        return null;
    }

    var result = parseExpression();
    if (result === null || position !== tokens.length || !isFinite(result) || isNaN(result))
        return null;
    return result;
}

function fuzzyScore(query, target, cache) {
    if (!query || !target)
        return 0;

    var q = normalizeText(query, cache);
    var t = normalizeText(target, cache);
    if (q === "")
        return 1;
    if (t === q)
        return 10000;
    if (t.startsWith(q))
        return 5000 + (1000 - t.length);

    var words = t.split(/[\s\-_.]+/);
    for (var w = 0; w < words.length; w++) {
        if (words[w].startsWith(q))
            return 4000 + (500 - t.length) + (w === 0 ? 200 : 0);
    }

    var qWords = q.split(/\s+/);
    if (qWords.length > 1) {
        var allMatch = true;
        var wordScore = 0;
        for (var qw = 0; qw < qWords.length; qw++) {
            var found = false;
            for (var tw = 0; tw < words.length; tw++) {
                if (words[tw].startsWith(qWords[qw])) {
                    found = true;
                    wordScore += 30;
                    break;
                }
            }
            if (!found) {
                allMatch = false;
                break;
            }
        }
        if (allMatch)
            return 3500 + wordScore + Math.max(0, 100 - t.length);
    }

    var rawTarget = String(target || "");
    var qi = 0, score = 0, consecutive = 0, lastMatchIdx = -1;
    for (var ti = 0; ti < t.length && qi < q.length; ti++) {
        if (t[ti] === q[qi]) {
            qi++;
            if (lastMatchIdx === ti - 1) {
                consecutive++;
                score += consecutive * 12;
            } else {
                consecutive = 1;
                score += 5;
            }
            var prev = ti > 0 ? t[ti - 1] : "";
            if (ti === 0 || prev === " " || prev === "-" || prev === "_" || prev === ".")
                score += 25;
            else if (ti > 0 && rawTarget[ti] >= "A" && rawTarget[ti] <= "Z" && rawTarget[ti - 1] >= "a" && rawTarget[ti - 1] <= "z")
                score += 20;
            if (lastMatchIdx >= 0)
                score -= (ti - lastMatchIdx - 1);
            lastMatchIdx = ti;
        }
    }
    if (qi < q.length)
        return 0;
    score += Math.max(0, 50 - t.length);
    return Math.max(1, score);
}

function htmlEscape(text) {
    return String(text || "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

function cleanExecString(cmd) {
    return String(cmd || "")
        .replace(/%[fFuUdDnNickvm]/g, "")
        .replace(/\s+/g, " ")
        .trim();
}

function requireIconResolver(iconResolver) {
    if (!iconResolver || typeof iconResolver.iconFallbackPath !== "function" ||
        typeof iconResolver.resolveIconSource !== "function" ||
        typeof iconResolver.buildCandidates !== "function") {
        throw new Error("LauncherUtils requires an explicit icon resolver dependency");
    }
    return iconResolver;
}

function iconFallbackPath(iconName, iconResolver) {
    return requireIconResolver(iconResolver).iconFallbackPath(iconName);
}

function resolveIconSource(iconName, iconResolver) {
    return requireIconResolver(iconResolver).resolveIconSource(iconName);
}

function buildIconCandidates(iconName, iconResolver, extraRoots) {
    return requireIconResolver(iconResolver).buildCandidates(iconName, extraRoots);
}

function modeIconName(mode) {
    var map = {
        "calc": "accessories-calculator",
        "nix": "nix-snowflake",
        "options": "preferences-system",
        "web": "internet-web-browser",
        "files": "folder",
        "file": "text-x-generic",
        "folder": "folder",
        "cmd": "utilities-terminal",
        "cmd_terminal": "utilities-terminal",
        "clipboard": "edit-copy",
        "emoji": "face-smile",
        "windows": "preferences-system-windows",
        "window": "preferences-system-windows",
        "translate": "accessories-dictionary",
        "recentProjects": "folder-git",
        "project": "folder-git",
        "recentFiles": "text-x-generic",
        "recentFile": "text-x-generic",
        "snippets": "text-x-script",
        "snippet": "text-x-script",
        "ai": "applications-science",
        "ai_assist": "applications-science",
        "kill": "process-stop",
        "volume": "audio-volume-high",
        "hw_volume": "audio-volume-high",
        "brightness": "display-brightness-symbolic",
        "hw_brightness": "display-brightness-symbolic",
        "system_audio": "audio-volume-high",
        "system_wifi": "network-wireless",
        "system_bluetooth": "preferences-system-bluetooth",
        "system_power": "system-shutdown",
        "system_brightness": "display-brightness-symbolic"
    };
    return map[mode] || "";
}

function resolvedModeIconSource(mode, iconResolver) {
    var iconName = modeIconName(mode);
    if (iconName === "")
        return "";
    return resolveIconSource(iconName, iconResolver);
}

function inferAppIcon(app, cache) {
    if (!app)
        return "application-x-executable";

    var candidates = [
        app.icon || "",
        app.id || "",
        app.desktopId || "",
        app.name || "",
        cleanExecString(app.execString || "")
    ];

    for (var i = 0; i < candidates.length; i++) {
        var raw = String(candidates[i] || "").trim();
        if (raw === "")
            continue;
        var normalized = normalizeText(raw, cache);
        if (normalized.includes("qt5") && normalized.includes("settings"))
            return "preferences-desktop-theme";
        if (normalized.includes("qt6") && normalized.includes("settings"))
            return "preferences-desktop-theme";
        if (normalized.includes("qt5ct") || normalized.includes("qt6ct"))
            return "preferences-desktop-theme";
        if (normalized.includes("qt creator") || normalized.includes("qtcreator"))
            return "text-x-script";
    }

    var icon = String(app.icon || app.id || app.desktopId || "").trim();
    if (icon === "")
        return "application-x-executable";
    return icon.replace(/\.desktop$/i, "") || "application-x-executable";
}

function safeAudioRatio(value) {
    var num = Number(value || 0);
    if (!isFinite(num) || isNaN(num))
        return 0;
    return Math.max(0, Math.min(num, 1.5));
}

function queryMatchesKeyword(query, keywords) {
    var normalizedQuery = normalizeText(query).trim();
    if (normalizedQuery === "" || normalizedQuery.length < 2)
        return false;
    for (var i = 0; i < keywords.length; i++) {
        var token = normalizeText(keywords[i]);
        if (token.indexOf(normalizedQuery) >= 0 || normalizedQuery.indexOf(token) >= 0)
            return true;
    }
    return false;
}

function parentDirectoryForPath(path) {
    var target = String(path || "").trim();
    if (target === "")
        return "";
    var slashIndex = target.lastIndexOf("/");
    if (slashIndex < 0)
        return target;
    if (slashIndex === 0)
        return "/";
    return target.substring(0, slashIndex);
}

function fileGlyphForPath(path, explicitExt, isFolder, iconName) {
    if (isFolder === true)
        return iconName === "folder-git" ? "\u{f1d3}" : "\u{f07b}";
    var ext = String(explicitExt || "").toLowerCase();
    if (ext === "") {
        var fileName = String(path || "").split("/").pop() || "";
        var dotIndex = fileName.lastIndexOf(".");
        if (dotIndex >= 0)
            ext = fileName.substring(dotIndex + 1).toLowerCase();
    }
    if (["png", "jpg", "jpeg", "gif", "bmp", "svg", "webp", "avif"].includes(ext))
        return "\u{f1c5}";
    if (["mp4", "mkv", "avi", "webm", "mov", "m4v"].includes(ext))
        return "\u{f03d}";
    if (["mp3", "flac", "ogg", "wav", "aac", "m4a"].includes(ext))
        return "\u{f001}";
    if (["zip", "tar", "gz", "xz", "7z", "rar", "bz2"].includes(ext))
        return "\u{f1c6}";
    switch (ext) {
    case "pdf": return "\u{f1c1}";
    case "nix": return "\u{f313}";
    case "sh":
    case "bash":
    case "zsh":
    case "fish": return "\u{f120}";
    case "py": return "\u{e73c}";
    case "js":
    case "jsx": return "\u{e61f}";
    case "ts":
    case "tsx": return "\u{e628}";
    case "rs": return "\u{e718}";
    case "json":
    case "toml":
    case "yaml":
    case "yml":
    case "qml":
    case "lua":
    case "c":
    case "cpp":
    case "h":
    case "hpp":
    case "go":
    case "java":
    case "kt":
    case "html":
    case "css":
    case "scss":
    case "xml": return "\u{f1c9}";
    case "md":
    case "txt":
    case "rst": return "\u{f15c}";
    default: return "\u{f15b}";
    }
}

function windowGlyphForAppId(appId, title) {
    var key = String(appId || "").replace(/\.desktop$/i, "").trim().toLowerCase();
    var text = normalizeText((key || "") + " " + String(title || ""));
    if (text.includes("firefox")) return "\u{f269}";
    if (text.includes("brave") || text.includes("chrome") || text.includes("chromium")) return "\u{f268}";
    if (text.includes("kitty") || text.includes("ghostty") || text.includes("foot") || text.includes("alacritty") || text.includes("wezterm") || text.includes("terminal")) return "\u{f120}";
    if (text.includes("code") || text.includes("codium") || text.includes("opencode") || text.includes("jetbrains")) return "\u{db84}\u{de1e}";
    if (text.includes("discord") || text.includes("vesktop")) return "\u{f392}";
    if (text.includes("spotify")) return "\u{f1bc}";
    if (text.includes("thunar") || text.includes("nautilus") || text.includes("dolphin") || text.includes("pcmanfm") || text.includes("file")) return "\u{f07b}";
    if (text.includes("telegram") || text.includes("signal") || text.includes("whatsapp")) return "\u{f2c6}";
    if (text.includes("slack") || text.includes("element") || text.includes("chat")) return "\u{f075}";
    if (text.includes("thunderbird") || text.includes("mail")) return "\u{f0e0}";
    if (text.includes("steam")) return "\u{db83}\u{dcd3}";
    if (text.includes("obsidian")) return "\u{db85}\u{dce7}";
    if (text.includes("vlc") || text.includes("mpv") || text.includes("video")) return "\u{f03d}";
    if (text.includes("gimp") || text.includes("inkscape") || text.includes("krita") || text.includes("image")) return "\u{f1fc}";
    if (text.includes("pavucontrol") || text.includes("easyeffects") || text.includes("audio")) return "\u{f028}";
    if (text.includes("bluetooth")) return "\u{f293}";
    if (text.includes("wifi") || text.includes("network")) return "\u{f1eb}";
    return "\u{f2d0}";
}
