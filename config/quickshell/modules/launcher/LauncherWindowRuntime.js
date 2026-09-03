.pragma library

function normalizeAppIdKey(value) {
    return String(value || "").replace(/\.desktop$/i, "").trim().toLowerCase();
}

function getToplevelsArray(toplevelsObj) {
    if (!toplevelsObj) return [];
    var vals = typeof toplevelsObj.values !== "undefined" ? toplevelsObj.values : null;
    var arr = [];
    if (vals && typeof vals.length === "number") {
        for (var i = 0; i < vals.length; i++) arr.push(vals[i]);
    } else if (typeof toplevelsObj.length === "number") {
        for (var j = 0; j < toplevelsObj.length; j++) arr.push(toplevelsObj[j]);
    }
    return arr;
}

function activeWorkspaceId(focusedWorkspace) {
    return focusedWorkspace && focusedWorkspace.id
        ? String(focusedWorkspace.id)
        : "1";
}

function activeWorkspaceLabel(focusedWorkspace) {
    return "Workspace " + activeWorkspaceId(focusedWorkspace);
}

function windowDataForToplevel(tl) {
    var ipc = tl && tl.lastIpcObject ? tl.lastIpcObject : {};
    var workspaceId = tl && tl.workspace ? String(tl.workspace.name || tl.workspace.id || "?") : "?";
    var appId = tl && tl.appId ? String(tl.appId) : "";
    if (appId === "" && ipc.class) appId = String(ipc.class);
    if (appId === "" && ipc.initialClass) appId = String(ipc.initialClass);
    var title = tl && tl.title ? String(tl.title) : "";
    if (title === "" && ipc.title) title = String(ipc.title);
    if (title === "" && ipc.initialTitle) title = String(ipc.initialTitle);
    if (title === "" && appId !== "") title = appId;
    var rawAddr = (ipc.address && String(ipc.address) !== "undefined") ? String(ipc.address) : "";
    if (rawAddr !== "" && !rawAddr.startsWith("0x")) rawAddr = "0x" + rawAddr;
    return {
        title: title,
        appId: appId,
        address: rawAddr,
        workspaceId: workspaceId,
        workspaceLabel: tl.workspace ? (tl.workspace.name || String(tl.workspace.id)) : "?",
        pid: ipc.pid || 0
    };
}

function runningWindowsForApp(appOrId, toplevelsObj) {
    var normalized = normalizeAppIdKey(typeof appOrId === "string" ? appOrId : (appOrId && (appOrId.id || appOrId.desktopId) ? (appOrId.id || appOrId.desktopId) : ""));
    var wins = [];
    if (normalized === "") return wins;
    var toplevels = getToplevelsArray(toplevelsObj);
    for (var i = 0; i < toplevels.length; i++) {
        var data = windowDataForToplevel(toplevels[i]);
        var candidate = normalizeAppIdKey(data.appId);
        if (candidate !== normalized) continue;
        wins.push(data);
    }
    return wins;
}
