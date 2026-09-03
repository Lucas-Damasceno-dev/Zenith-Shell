.pragma library

function begin(label, startedAtMs) {
    var start = Number(startedAtMs);
    if (!isFinite(start) || start < 0)
        start = Date.now();

    return {
        label: String(label || "popup"),
        startedAtMs: start
    };
}

function finish(sample, endedAtMs) {
    var end = Number(endedAtMs);
    if (!isFinite(end) || end < 0)
        end = Date.now();

    var startedAtMs = sample && sample.startedAtMs !== undefined
        ? Number(sample.startedAtMs)
        : end;
    if (!isFinite(startedAtMs) || startedAtMs < 0)
        startedAtMs = end;

    var elapsedMs = Math.max(0, Math.round(end - startedAtMs));

    return {
        label: sample && sample.label ? String(sample.label) : "popup",
        startedAtMs: startedAtMs,
        endedAtMs: end,
        elapsedMs: elapsedMs
    };
}

function format(sample) {
    return String(sample && sample.label ? sample.label : "popup") + " loaded in " + String(Number(sample && sample.elapsedMs ? sample.elapsedMs : 0)) + " ms";
}

function isSlow(sample, thresholdMs) {
    var threshold = Number(thresholdMs);
    if (!isFinite(threshold) || threshold <= 0)
        threshold = 300;
    return Number(sample && sample.elapsedMs ? sample.elapsedMs : 0) >= threshold;
}
