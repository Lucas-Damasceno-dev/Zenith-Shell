.pragma library

function cleanPath(pathValue) {
    var value = String(pathValue || "");
    if (value.indexOf("file://") === 0) return value.substring(7);
    return value;
}

function buildProcessCommand(scriptPath, sortMode, filterText) {
    return [
        "bash",
        "-c",
        "bash " + cleanPath(scriptPath) + " " + String(sortMode || "cpu") + " " + String(filterText || "").trim()
    ];
}

function buildServiceCommand(scriptPath) {
    return [
        "bash",
        "-c",
        "bash " + cleanPath(scriptPath)
    ];
}

function parseProcessRows(rawText) {
    var lines = String(rawText || "").trim().split(/\r?\n/);
    var rows = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "") continue;
        var p = line.split("|");
        if (p.length < 4) continue;
        rows.push({
            pid: p[0],
            name: p[1],
            cpu: p[2],
            mem: p[3]
        });
    }
    return rows;
}

function parseServiceRows(rawText) {
    var lines = String(rawText || "").trim().split(/\r?\n/);
    var rows = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "") continue;
        var p = line.split("|");
        if (p.length < 4) continue;
        rows.push({
            unit: p[0],
            active: p[1],
            sub: p[2],
            description: p[3]
        });
    }
    return rows;
}
