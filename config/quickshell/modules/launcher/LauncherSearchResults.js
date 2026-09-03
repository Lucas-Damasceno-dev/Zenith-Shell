.pragma library

// ─── Helper Functions ───────────────────────────────────────────
function _string(value) {
    if (value === null || value === undefined)
        return "";
    return String(value);
}

var SYSTEM_ENTRIES = [
    {
        type: "system_audio",
        name: "Painel de Áudio",
        description: "Volume mestre, mute e saídas disponíveis",
        icon: "audio-volume-high",
        keywords: ["audio", "som", "volume", "speaker", "saida", "saída", "fone", "headphone"]
    },
    {
        type: "system_bluetooth",
        name: "Bluetooth",
        description: "Bateria, conexão e energia dos dispositivos",
        icon: "preferences-system-bluetooth",
        keywords: ["bluetooth", "fone bluetooth", "earbuds", "headset"]
    },
    {
        type: "system_wifi",
        name: "Wi-Fi",
        description: "Status da rede, SSID atual e toggle rápido",
        icon: "network-wireless",
        keywords: ["wifi", "wi-fi", "rede", "internet", "network"]
    },
    {
        type: "system_power",
        name: "Energia & Sessão",
        description: "Bloquear, suspender, reiniciar ou desligar",
        icon: "system-shutdown",
        keywords: ["power", "energia", "desligar", "reiniciar", "reboot", "shutdown", "lock", "logout", "sessao", "sessão"]
    },
    {
        type: "system_brightness",
        name: "Brilho",
        description: "Slider rápido para a tela atual",
        icon: "display-brightness-symbolic",
        keywords: ["brilho", "brightness", "tela", "screen"]
    }
];

function queryMatchesKeyword(query, keywords, normalizeText) {
    var normalizer = typeof normalizeText === "function" ? normalizeText : function(text) { return String(text || ""); };
    var normalizedQuery = normalizer(query).trim();
    if (normalizedQuery === "" || normalizedQuery.length < 2)
        return false;
    for (var i = 0; i < keywords.length; i++) {
        var token = normalizer(keywords[i]);
        if (token.indexOf(normalizedQuery) >= 0 || normalizedQuery.indexOf(token) >= 0)
            return true;
    }
    return false;
}

function systemResults(query, normalizeText) {
    var normalizer = typeof normalizeText === "function" ? normalizeText : function(text) { return String(text || ""); };
    var normalizedQuery = normalizer(query).trim();
    var results = [];
    if (normalizedQuery === "")
        return results;

    for (var i = 0; i < SYSTEM_ENTRIES.length; i++) {
        var entry = SYSTEM_ENTRIES[i];
        if (!queryMatchesKeyword(normalizedQuery, entry.keywords, normalizer))
            continue;
        results.push({
            name: entry.name,
            description: entry.description,
            icon: entry.icon,
            iconSource: entry.icon,
            type: entry.type,
            appId: "",
            appIdx: 0,
            extra: "",
            path: "",
            result: "",
            term: "",
            score: 50000 - i
        });
    }
    return results;
}

function snippetResults(term, snippetLibrary, normalizeText) {
    var normalizer = typeof normalizeText === "function" ? normalizeText : function(text) { return String(text || ""); };
    var normTerm = normalizer(term);
    var results = [];
    if (!snippetLibrary || typeof snippetLibrary.length !== "number")
        return results;
    for (var i = 0; i < snippetLibrary.length; i++) {
        var snippet = snippetLibrary[i];
        if (normTerm === "" || normalizer(snippet.name).indexOf(normTerm) >= 0 || (snippet.tags && normalizer(snippet.tags).indexOf(normTerm) >= 0)) {
            results.push({
                name: snippet.name,
                description: snippet.cmd.substring(0, 60),
                icon: "text-x-script",
                type: "snippet",
                result: snippet.cmd,
                appId: "",
                appIdx: 0,
                extra: snippet.tags || "",
                path: "",
                term: "",
                score: 0
            });
        }
    }
    return results;
}

var _killSnapshotCacheText = "";
var _killSnapshotCache = [];
var _killFilterCacheSnapshot = null;
var _killFilterCacheTerm = "";
var _killFilterCacheResults = [];

function _parseKillSnapshot(psText, normalizeText) {
    var text = String(psText || "");
    if (text === _killSnapshotCacheText)
        return _killSnapshotCache;

    var normalizer = typeof normalizeText === "function" ? normalizeText : function(value) { return String(value || ""); };
    var results = [];
    var lines = text.replace(/\r\n/g, "\n").split("\n");

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "")
            continue;

        var match = line.match(/^(\d+)\s+(\S+)\s+([0-9.]+)\s+([0-9.]+)\s+(\S+)\s+(.*)$/);
        if (!match)
            continue;

        var pid = parseInt(match[1], 10);
        if (!isFinite(pid) || isNaN(pid))
            continue;

        var user = match[2];
        var cpu = parseFloat(match[3]);
        var mem = parseFloat(match[4]);
        var commandName = match[5];
        var command = match[6] || commandName;
        var lowerCommandName = commandName.toLowerCase();
        var lowerCommand = command.toLowerCase();

        if (lowerCommandName === "ps" || lowerCommandName === "kill")
            continue;
        if (lowerCommand.indexOf("quickshell") >= 0 || lowerCommand.indexOf("launcher.qml") >= 0)
            continue;

        results.push({
            name: commandName + " • PID " + pid,
            description: user + " • " + (isFinite(cpu) ? cpu.toFixed(1) : "0.0") + "% CPU • " + (isFinite(mem) ? mem.toFixed(1) : "0.0") + "% MEM • " + command.substring(0, 80),
            icon: "process-stop",
            type: "kill",
            pid: pid,
            user: user,
            cpu: isFinite(cpu) ? cpu : 0,
            mem: isFinite(mem) ? mem : 0,
            command: command,
            appId: "",
            appIdx: 0,
            extra: command,
            path: "",
            result: String(pid),
            term: "",
            score: Math.round((isFinite(cpu) ? cpu : 0) * 1000 + (isFinite(mem) ? mem : 0) * 100),
            searchText: normalizer([pid, user, commandName, command].join(" "))
        });
    }

    results.sort(function(a, b) {
        if (b.cpu !== a.cpu)
            return b.cpu - a.cpu;
        if (b.mem !== a.mem)
            return b.mem - a.mem;
        return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0);
    });

    _killSnapshotCacheText = text;
    _killSnapshotCache = results;
    _killFilterCacheSnapshot = null;
    _killFilterCacheTerm = "";
    _killFilterCacheResults = [];
    return results;
}

function _filterKillSnapshot(term, snapshot, normalizeText) {
    var normalizer = typeof normalizeText === "function" ? normalizeText : function(value) { return String(value || ""); };
    var normTerm = normalizer(term).trim();
    if (snapshot === _killFilterCacheSnapshot && normTerm === _killFilterCacheTerm)
        return _killFilterCacheResults;

    var results = [];
    if (!snapshot || typeof snapshot.length !== "number")
        return results;

    if (normTerm === "") {
        results = snapshot.slice(0, 40);
    } else {
        for (var i = 0; i < snapshot.length && results.length < 40; i++) {
            var entry = snapshot[i];
            if (!entry || !entry.searchText)
                continue;
            if (entry.searchText.indexOf(normTerm) < 0)
                continue;
            results.push(entry);
        }
    }

    _killFilterCacheSnapshot = snapshot;
    _killFilterCacheTerm = normTerm;
    _killFilterCacheResults = results;
    return results;
}

function killResults(term, psTextOrSnapshot, normalizeText) {
    var snapshot = psTextOrSnapshot;
    if (typeof snapshot === "string" || snapshot === undefined || snapshot === null)
        snapshot = _parseKillSnapshot(snapshot, normalizeText);
    return _filterKillSnapshot(term, snapshot, normalizeText);
}

function isFavoriteAppId(appId, favoriteAppIds) {
    var normalizedId = _string(appId).trim();
    if (normalizedId === "" || !favoriteAppIds)
        return false;

    if (typeof favoriteAppIds.length === "number" && typeof favoriteAppIds !== "string") {
        for (var i = 0; i < favoriteAppIds.length; i++) {
            if (_string(favoriteAppIds[i]).trim() === normalizedId)
                return true;
        }
        return false;
    }

    if (typeof favoriteAppIds === "object")
        return favoriteAppIds[normalizedId] === true;

    return false;
}

function scoreApplications(query, apps, options) {
    var normalizer = options && typeof options.normalizeText === "function" ? options.normalizeText : normalizeText;
    var scorer = options && typeof options.fuzzyScore === "function" ? options.fuzzyScore : null;
    var frecencyMap = options && options.frecencyMap ? options.frecencyMap : {};
    var favoriteAppIds = options && options.favoriteAppIds ? options.favoriteAppIds : {};
    var categoryFilter = options && options.categoryFilter ? _string(options.categoryFilter).trim() : "";
    var normalizedQuery = normalizer(query).trim();
    var hasQuery = normalizedQuery !== "";
    var scored = [];

    if (!apps || typeof apps.length !== "number")
        return scored;

    for (var i = 0; i < apps.length; i++) {
        var app = apps[i];
        if (!app || app.noDisplay)
            continue;

        var appName = _string(app.name || app.genericName || app.id || app.desktopId || "").trim();
        var appDescription = _string(app.genericName || app.comment || "").trim();
        var appId = _string(app.id || app.desktopId || "").trim();
        var keywordsText = app.keywords && typeof app.keywords.join === "function"
            ? _string(app.keywords.join(" "))
            : _string(app.keywords || "");
        var categoriesText = app.categories && typeof app.categories.join === "function"
            ? _string(app.categories.join(" "))
            : _string(app.categories || "");
        var searchableText = normalizer([appName, appDescription, appId, keywordsText, categoriesText].join(" "));

        if (appName === "" && appDescription === "" && appId === "" &&
            _string(keywordsText).trim() === "" && _string(categoriesText).trim() === "")
            continue;

        if (categoryFilter !== "") {
            var categories = app.categories || [];
            if (!categories || typeof categories.indexOf !== "function" || categories.indexOf(categoryFilter) < 0)
                continue;
        }

        var bestScore = 1;
        if (hasQuery) {
            var queryTokens = normalizedQuery.split(/\s+/).filter(function(token) { return token !== ""; });
            var directMatch = true;
            for (var tokenIndex = 0; tokenIndex < queryTokens.length; tokenIndex++) {
                if (searchableText.indexOf(queryTokens[tokenIndex]) < 0) {
                    directMatch = false;
                    break;
                }
            }

            var nameScore = scorer ? scorer(query, appName) : 0;
            var descScore = scorer ? scorer(query, appDescription) : 0;
            var idScore = scorer ? scorer(query, appId) : 0;
            var kwScore = scorer ? scorer(query, keywordsText) : 0;
            var catScore = scorer ? scorer(query, categoriesText) : 0;
            bestScore = Math.max(nameScore, descScore * 0.7, idScore * 0.6, kwScore * 0.5, catScore * 0.3);

            var fuzzyThreshold = normalizedQuery.length <= 2
                ? 260
                : (normalizedQuery.length <= 4 ? 140 : 80);

            if (!directMatch && bestScore < fuzzyThreshold)
                continue;
        }

        var freq = parseInt(_string(frecencyMap[appId] || 0).trim(), 10);
        if (!isFinite(freq) || isNaN(freq) || freq < 0)
            freq = 0;

        var favorite = isFavoriteAppId(appId, favoriteAppIds);
        var favoriteBoost = hasQuery ? (favorite ? 100 : 0) : (favorite ? 10000 : 0);
        var score = bestScore + freq * 50 + favoriteBoost;

        scored.push({
            app: app,
            score: score,
            idx: i,
            favorite: favorite,
            frecency: freq
        });
    }

    scored.sort(function(a, b) {
        if (b.score !== a.score)
            return b.score - a.score;
        if (a.favorite !== b.favorite)
            return a.favorite ? -1 : 1;

        var aName = _string(a.app && (a.app.name || a.app.genericName || a.app.id || a.app.desktopId) ? (a.app.name || a.app.genericName || a.app.id || a.app.desktopId) : "").toLowerCase();
        var bName = _string(b.app && (b.app.name || b.app.genericName || b.app.id || b.app.desktopId) ? (b.app.name || b.app.genericName || b.app.id || b.app.desktopId) : "").toLowerCase();
        if (aName !== bName)
            return aName < bName ? -1 : 1;
        return a.idx - b.idx;
    });

    return scored;
}
