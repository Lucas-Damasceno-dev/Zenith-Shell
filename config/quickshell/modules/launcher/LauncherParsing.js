.pragma library

function _string(value) {
    if (value === undefined || value === null)
        return "";
    return String(value);
}

function normalizeText(text, cache) {
    if (cache && typeof cache === "object" && text in cache)
        return cache[text];
    var value = _string(text);
    if (value === "")
        return "";
    var result = value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
    if (cache && typeof cache === "object") {
        cache[text] = result;
        cache.__count = (cache.__count || 0) + 1;
    }
    return result;
}

function splitLines(text) {
    return _string(text).replace(/\r\n/g, "\n").split("\n");
}

function _trimmed(value) {
    return _string(value).trim();
}

function _basenameFromPath(path) {
    var value = _trimmed(path);
    if (value === "")
        return "";
    if (value === "/")
        return "/";

    var segments = value.split("/");
    var tail = _trimmed(segments[segments.length - 1]);
    if (tail !== "")
        return tail;
    if (segments.length >= 2)
        return _trimmed(segments[segments.length - 2]);
    return value;
}

function normalizeResultItem(item) {
    if (!item || typeof item !== "object")
        return null;

    var normalized = {};
    for (var key in item)
        normalized[key] = item[key];

    var typeValue = _trimmed(normalized.type || "");
    var titleValue = _trimmed(normalized.title || "");
    var nameValue = _trimmed(normalized.name || "");
    var resultValue = _trimmed(normalized.result || "");
    var pathValue = _trimmed(normalized.path || "");
    var descriptionCandidate = _trimmed(normalized.description || normalized.subtitle || "");
    var fallbackName = titleValue || nameValue || _basenameFromPath(pathValue) || resultValue || descriptionCandidate;

    if (fallbackName === "")
        return null;

    normalized.type = typeValue;
    normalized.name = fallbackName;
    normalized.title = titleValue !== "" ? titleValue : fallbackName;

    var descriptionValue = _trimmed(normalized.description || "");
    var subtitleValue = _trimmed(normalized.subtitle || "");
    if (descriptionValue === "" && subtitleValue !== "")
        descriptionValue = subtitleValue;
    if (subtitleValue === "" && descriptionValue !== "")
        subtitleValue = descriptionValue;
    if (descriptionValue === fallbackName)
        descriptionValue = "";
    if (subtitleValue === fallbackName)
        subtitleValue = descriptionValue;
    normalized.description = descriptionValue;
    normalized.subtitle = subtitleValue;

    var iconValue = _trimmed(normalized.iconSource || normalized.icon || "");
    normalized.icon = iconValue;
    normalized.iconSource = iconValue;

    normalized.appId = _string(normalized.appId || "");
    normalized.extra = _string(normalized.extra || "");
    normalized.path = pathValue;
    normalized.result = _string(normalized.result || "");
    normalized.term = _string(normalized.term || "");

    var scoreValue = Number(normalized.score || 0);
    normalized.score = (isFinite(scoreValue) && !isNaN(scoreValue)) ? scoreValue : 0;

    return normalized;
}

function _collectionToArray(collection) {
    var items = [];
    if (!collection)
        return items;

    var source = collection;
    if (typeof collection.values === "function") {
        try {
            source = collection.values();
        } catch (e) {
            source = null;
        }
    } else if (typeof collection.values !== "undefined") {
        source = collection.values;
    }

    if (!source)
        return items;

    if (typeof source.length === "number") {
        for (var i = 0; i < source.length; i++)
            items.push(source[i]);
        return items;
    }

    if (typeof Array.from === "function") {
        try {
            var converted = Array.from(source);
            for (var j = 0; j < converted.length; j++)
                items.push(converted[j]);
        } catch (e) {
        }
    }

    return items;
}

function headLines(text, limit) {
    var source = _string(text).replace(/\r\n/g, "\n");
    var max = Math.max(0, Math.floor(Number(limit || 0)));
    var lines = [];

    if (max <= 0)
        return lines;

    var start = 0;
    while (start <= source.length && lines.length < max) {
        var end = source.indexOf("\n", start);
        if (end < 0)
            end = source.length;

        lines.push(source.substring(start, end));
        if (end >= source.length)
            break;
        start = end + 1;
    }

    return lines;
}

function appendResults(model, items) {
    if (!model || !items || typeof items.length !== "number")
        return;

    for (var i = 0; i < items.length; i++) {
        var normalized = normalizeResultItem(items[i]);
        if (normalized)
            model.append(normalized);
    }
}

function snapshotDesktopEntries(allApps) {
    return _collectionToArray(allApps);
}

function _desktopEntryCoverage(snapshot) {
    var named = 0;
    var searchable = 0;

    if (!snapshot || typeof snapshot.length !== "number")
        return { named: 0, searchable: 0 };

    for (var i = 0; i < snapshot.length; i++) {
        var entry = snapshot[i];
        if (!entry || typeof entry !== "object")
            continue;

        var name = _string(entry.name || "").trim();
        var genericName = _string(entry.genericName || "").trim();
        var comment = _string(entry.comment || "").trim();
        var appId = _string(entry.id || entry.desktopId || "").trim();
        var execString = _string(entry.execString || "").trim();
        var keywords = entry.keywords && typeof entry.keywords.join === "function"
            ? _string(entry.keywords.join(" ")).trim()
            : _string(entry.keywords || "").trim();
        var categories = entry.categories && typeof entry.categories.join === "function"
            ? _string(entry.categories.join(" ")).trim()
            : _string(entry.categories || "").trim();

        var hasDisplayMetadata = name !== "" || genericName !== "" || comment !== "";
        var hasSearchableMetadata = hasDisplayMetadata
            || appId !== ""
            || execString !== ""
            || keywords !== ""
            || categories !== "";

        if (hasDisplayMetadata)
            named += 1;
        if (hasSearchableMetadata)
            searchable += 1;
    }

    return { named: named, searchable: searchable };
}

function shouldRefreshDesktopEntriesSearch(previousCount, nextCount, stampChanged, previousSnapshot, nextSnapshot) {
    var prev = parseInt(_string(previousCount), 10);
    var next = parseInt(_string(nextCount), 10);
    if (!isFinite(prev) || isNaN(prev) || prev < 0)
        prev = 0;
    if (!isFinite(next) || isNaN(next) || next < 0)
        next = 0;

    if (stampChanged === true)
        return true;

    if (prev === 0 && next > 0)
        return true;

    if (prev === next && next > 0) {
        var previousCoverage = _desktopEntryCoverage(previousSnapshot);
        var nextCoverage = _desktopEntryCoverage(nextSnapshot);

        if (previousCoverage.named === 0 && nextCoverage.named > 0)
            return true;
        if (previousCoverage.searchable === 0 && nextCoverage.searchable > 0)
            return true;
        if (nextCoverage.named > previousCoverage.named)
            return true;
        if (nextCoverage.searchable > previousCoverage.searchable)
            return true;
    }

    return false;
}

function parseFileSearchOutput(text, homeDir) {
    var items = [];
    var lines = splitLines(text);
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "")
            continue;

        var parts = line.split("\u001f");
        if (parts.length < 6)
            continue;

        var kind = parts[0];
        var fullPath = parts[1];
        var base = parts[2];
        var parent = parts[3];
        var ext = parts[4];
        var icon = parts[5];
        var displayParent = parent;
        if (homeDir && displayParent.indexOf(homeDir) === 0)
            displayParent = "~" + displayParent.substring(homeDir.length);

        items.push({
            name: base,
            description: displayParent,
            icon: icon,
            type: kind === "dir" ? "folder" : "file",
            path: fullPath,
            appId: "",
            appIdx: 0,
            extra: ext,
            result: kind,
            term: "",
            score: 0
        });
    }

    return items;
}

function parseOptionsOutput(text) {
    var items = [];
    var blocks = _string(text).replace(/\r\n/g, "\n").split("\n\n");
    for (var i = 0; i < blocks.length; i++) {
        var lines = blocks[i].trim().split("\n");
        if (lines.length === 0)
            continue;

        var name = lines[0].trim();
        if (name.startsWith("#"))
            name = name.substring(1).trim();
        if (name === "")
            continue;

        items.push({
            name: name,
            description: lines.length > 1 ? lines[1].trim() : "NixOS Option",
            icon: "",
            type: "calc",
            result: name,
            appId: "",
            appIdx: 0,
            extra: "",
            path: "",
            term: "",
            score: 0
        });
    }

    return items;
}

function parseClipboardSearchOutput(text, searchTerm, normalizer) {
    var normalize = typeof normalizer === "function" ? normalizer : normalizeText;
    var normTerm = normalize(searchTerm);
    var items = [];
    // Inspect recent history (up to 500 lines) and collect up to 50 matching items.
    var lines = headLines(text, 500);

    for (var i = 0; i < lines.length && items.length < 50; i++) {
        var line = lines[i];
        var parts = line.split("\t");
        if (parts.length < 2)
            continue;

        var content = parts.slice(1).join("\t");
        if (normTerm !== "" && normalize(content).indexOf(normTerm) < 0)
            continue;

        var mimeMatch = content.match(/image\/[a-zA-Z0-9.+-]+/);
        var mime = mimeMatch ? mimeMatch[0] : "";
        var isImage = content.indexOf("[[ binary data") >= 0;

        items.push({
            name: isImage ? ("[Imagem] " + (mime || "binary")) : content.substring(0, 80),
            description: "ID: " + parts[0] + (mime ? (" • " + mime) : ""),
            icon: "",
            type: "clipboard",
            result: parts[0],
            appId: "",
            appIdx: 0,
            extra: content,
            path: "",
            term: "",
            score: 0
        });
    }

    return items;
}

function parseRecentProjectsOutput(text) {
    var items = [];
    var lines = splitLines(text);
    for (var i = 0; i < lines.length; i++) {
        var path = lines[i].trim();
        if (path === "")
            continue;

        var name = path.split("/").pop();
        items.push({
            name: name,
            description: path,
            icon: path.indexOf("nixos") !== -1 ? "nix-snowflake" : "folder-git",
            type: "project",
            path: path,
            appId: "",
            appIdx: 0,
            extra: "",
            result: path,
            term: "",
            score: 0
        });
    }

    return items;
}

function parseRecentFilesOutput(text, homeDir) {
    var items = [];
    var lines = splitLines(text);
    for (var i = 0; i < lines.length; i++) {
        var path = lines[i].trim();
        if (path === "")
            continue;

        var base = path.split("/").pop();
        var dir = path.substring(0, path.length - base.length - 1) || "~";
        if (homeDir && dir.indexOf(homeDir) === 0)
            dir = "~" + dir.substring(homeDir.length);

        var ext = base.indexOf(".") >= 0 ? base.split(".").pop().toLowerCase() : "";
        var icon = ext === "pdf" ? "application-pdf"
            : ["png", "jpg", "jpeg", "gif", "webp", "svg"].indexOf(ext) >= 0 ? "image-x-generic"
            : ["qml", "js", "ts", "py", "nix", "sh", "md"].indexOf(ext) >= 0 ? "text-x-script"
            : "text-x-generic";

        items.push({
            name: base,
            description: dir,
            icon: icon,
            type: "recentFile",
            result: path,
            path: path,
            extra: ext,
            appId: "",
            appIdx: 0,
            term: "",
            score: i
        });
    }

    return items;
}

function parseFrecencyOutput(text) {
    var map = {};
    var lines = splitLines(text);

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "")
            continue;

        var parts = line.split("\t");
        if (parts.length < 2)
            continue;

        var appId = _string(parts[0]).trim();
        var count = parseInt(_string(parts[1]).trim(), 10);
        if (appId === "" || isNaN(count))
            continue;

        map[appId] = count;
    }

    return map;
}

function parseFrecencyJson(jsonText) {
    var map = {};
    if (!jsonText)
        return map;
    try {
        var data = JSON.parse(_string(jsonText));
        if (data && typeof data === "object") {
            for (var key in data) {
                var count = parseInt(String(data[key]).trim(), 10);
                if (!isNaN(count) && count > 0) {
                    map[String(key).trim()] = count;
                }
            }
        }
    } catch (e) {}
    return map;
}

function parseFileMetaOutput(text) {
    try {
        return JSON.parse(_string(text || "{}"));
    } catch (e) {
        return {};
    }
}

function parseBluetoothStatusOutput(text) {
    try {
        var parsed = JSON.parse(_string(text || "{}"));
        return {
            enabled: parsed.enabled === true
        };
    } catch (e) {
        return { enabled: false };
    }
}

function parseBluetoothDevicesOutput(text) {
    var devices = [];
    var lines = splitLines(text);
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "")
            continue;

        var parts = line.split("|");
        if (parts.length < 6)
            continue;

        devices.push({
            mac: _string(parts[0]).trim(),
            name: _string(parts[1]).trim(),
            paired: /^(yes|sim|true)$/i.test(_string(parts[2]).trim()),
            connected: /^(yes|sim|true)$/i.test(_string(parts[3]).trim()),
            icon: _string(parts[4]).trim(),
            battery: _string(parts[5]).trim()
        });
    }
    return devices;
}

function parseWifiStatusOutput(text) {
    try {
        var parsed = JSON.parse(_string(text || "{}"));
        return {
            enabled: parsed.enabled === true,
            ssid: _string(parsed.ssid || ""),
            signal: parseInt(parsed.signal || 0, 10) || 0
        };
    } catch (e) {
        return { enabled: false, ssid: "", signal: 0 };
    }
}

function parseWindowMemoryOutput(text) {
    try {
        var parsed = JSON.parse(_string(text || "{}"));
        var rssMiB = parseInt(parsed.rssMiB || 0, 10) || 0;
        var ratio = Number(parsed.ratio || 0);
        if (!isFinite(ratio) || isNaN(ratio))
            ratio = 0;
        ratio = Math.max(0, Math.min(ratio, 1));
        return {
            rssMiB: rssMiB,
            ratio: ratio,
            ramText: rssMiB + " MiB"
        };
    } catch (e) {
        return { rssMiB: 0, ratio: 0, ramText: "--" };
    }
}

function _cleanAiText(text, cleanText) {
    if (typeof cleanText === "function")
        return cleanText(text);
    return _string(text);
}

function parseAiOutput(rawText, cleanText) {
    var sections = {};
    var currentKey = "primary";
    var lines = splitLines(rawText);
    var buffer = [];

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (line.startsWith("MODEL:")) {
            if (buffer.length > 0)
                sections[currentKey] = _cleanAiText(buffer.join("\n"), cleanText);
            currentKey = line.substring(6).trim();
            buffer = [];
        } else {
            buffer.push(line);
        }
    }

    if (buffer.length > 0)
        sections[currentKey] = _cleanAiText(buffer.join("\n"), cleanText);

    if (Object.keys(sections).length === 0) {
        sections.primary = _cleanAiText(rawText, cleanText);
    } else {
        var keys = Object.keys(sections);
        for (var j = 0; j < keys.length; j++)
            sections[keys[j]] = _cleanAiText(sections[keys[j]], cleanText);
    }

    return sections;
}
