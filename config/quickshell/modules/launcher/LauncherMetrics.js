.pragma library

function createSessionMetrics(nowMs) {
    return {
        sessionStartMs: Number(nowMs || Date.now()),
        sessionEndMs: 0,
        durationMs: 0,
        searches: 0,
        modeHits: ({}),
        previews: 0,
        launches: 0,
        kills: 0,
        contextActions: 0,
        asyncSearches: 0,
        errors: 0,
        searchCancels: 0,
        watchdogTimeouts: 0,
        stateRestores: 0,
        lastMode: "",
        lastQuery: ""
    };
}

function formatPreviewFooterEntry(entry) {
    if (entry === undefined || entry === null)
        return "";
    if (typeof entry === "string")
        return String(entry).trim();
    if (typeof entry === "object") {
        var label = entry.label !== undefined && entry.label !== null ? String(entry.label).trim() : "";
        var value = entry.value !== undefined && entry.value !== null ? String(entry.value).trim() : "";
        if (label !== "" && value !== "")
            return label + ": " + value;
        if (label !== "")
            return label;
        return value;
    }
    return String(entry).trim();
}

function buildPreviewFooterText(parts) {
    var values = [];
    for (var i = 0; i < parts.length; i++) {
        var value = formatPreviewFooterEntry(parts[i]);
        if (value !== "")
            values.push(value);
    }
    return values.join(" • ");
}

function recordSearch(metrics, mode, query) {
    metrics.searches += 1;
    metrics.lastMode = String(mode || "");
    metrics.lastQuery = String(query || "");
    metrics.modeHits[metrics.lastMode] = (metrics.modeHits[metrics.lastMode] || 0) + 1;
}

function recordPreview(metrics, itemType) {
    metrics.previews += 1;
    metrics.lastMode = String(itemType || "");
}

function recordLaunch(metrics, itemType) {
    metrics.launches += 1;
    if (String(itemType || "") === "kill")
        metrics.kills += 1;
}

function recordContextAction(metrics, action) {
    metrics.contextActions += 1;
    var key = "ctx:" + String(action || "");
    metrics.modeHits[key] = (metrics.modeHits[key] || 0) + 1;
}

function finalizeSessionMetrics(metrics, nowMs) {
    if (!metrics || !metrics.sessionStartMs)
        return metrics;
    metrics.sessionEndMs = Number(nowMs || Date.now());
    metrics.durationMs = metrics.sessionEndMs - Number(metrics.sessionStartMs || 0);
    return metrics;
}
