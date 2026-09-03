.pragma library

function buildDesktopEntryCache(allApps) {
    var vals = typeof allApps.values !== "undefined" ? allApps.values : null;
    var apps = [];
    if (vals && typeof vals.length === "number") {
        for (var i = 0; i < vals.length; i++)
            apps.push(vals[i]);
    } else if (typeof allApps.length === "number") {
        for (var j = 0; j < allApps.length; j++)
            apps.push(allApps[j]);
    }

    var cache = {};
    for (var k = 0; k < apps.length; k++) {
        var app = apps[k];
        if (!app)
            continue;
        var id = (app.id || "").toLowerCase();
        cache[id] = app;
        cache[id.replace(".desktop", "")] = app;
        var name = (app.name || "").toLowerCase();
        if (!cache[name])
            cache[name] = app;
    }
    return cache;
}

function lookupDesktopEntry(appId, cache) {
    if (!appId)
        return null;
    var lowerId = appId.toLowerCase();
    var result = null;

    var cached = cache[lowerId] || cache[lowerId + ".desktop"];
    if (cached)
        result = cached;

    if (!result) {
        var flatpakShort = lowerId.split(".").pop();
        if (flatpakShort && flatpakShort !== lowerId) {
            cached = cache[flatpakShort] || cache[flatpakShort + ".desktop"];
            if (cached)
                result = cached;
        }
    }

    if (!result) {
        for (var key in cache) {
            var entryByClass = cache[key];
            if (entryByClass && entryByClass.startupWMClass && entryByClass.startupWMClass.toLowerCase() === lowerId) {
                result = entryByClass;
                break;
            }
        }
    }

    if (!result) {
        for (var k in cache) {
            var entry = cache[k];
            if (!entry)
                continue;
            var name = (entry.name || "").toLowerCase();
            var exec = (entry.execString || "").toLowerCase();
            if (name === lowerId || exec.indexOf(lowerId) >= 0 || lowerId.indexOf(name) >= 0) {
                result = entry;
                break;
            }
        }
    }

    return result;
}

function buildLaunchCommand(item, extraArgs) {
    if (!item)
        return "";

    var cmd = "";
    if (item.desktopEntry && item.desktopEntry.execString)
        cmd = String(item.desktopEntry.execString).replace(/%[fFuUniickv]/g, "").trim();
    if (cmd === "")
        cmd = String(item.appId || "").trim();
    if (cmd === "")
        return "";

    if (extraArgs && extraArgs.length > 0) {
        var args = [];
        for (var i = 0; i < extraArgs.length; i++) {
            var arg = String(extraArgs[i] || "").trim();
            if (arg !== "")
                args.push(arg);
        }
        if (args.length > 0)
            cmd = (cmd + " " + args.join(" ")).trim();
    }

    return cmd;
}
