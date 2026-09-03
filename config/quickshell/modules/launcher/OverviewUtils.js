.pragma library

function categoryColor(wsId, colors, fallbackColor) {
    var idx = Number(wsId || 0) - 1;
    if (idx >= 0 && colors && idx < colors.length) return colors[idx];
    return fallbackColor;
}

function findWorkspace(workspaces, id) {
    var values = workspaces || [];
    for (var i = 0; i < values.length; i++) {
        if (values[i] && values[i].id === id) return values[i];
    }
    return null;
}

function getClientsForWorkspace(toplevels, wsId) {
    var values = toplevels || [];
    var result = [];
    for (var i = 0; i < values.length; i++) {
        var c = values[i];
        if (c && c.workspace && c.workspace.id === wsId)
            result.push(c);
    }
    return result;
}

function getIconForClient(cls) {
    if (!cls) return "\u{f2d0}";
    var map = {
        "firefox": "\u{f269}",
        "brave": "\u{f269}",
        "brave-browser": "\u{f269}",
        "chromium": "\u{f268}",
        "google-chrome": "\u{f268}",
        "kitty": "\u{f120}",
        "alacritty": "\u{f120}",
        "ghostty": "\u{f120}",
        "foot": "\u{f120}",
        "wezterm": "\u{f120}",
        "code": "\u{db84}\u{de1e}",
        "vscodium": "\u{db84}\u{de1e}",
        "neovim": "\u{f120}",
        "nvim": "\u{f120}",
        "discord": "\u{f392}",
        "spotify": "\u{f1bc}",
        "thunar": "\u{f07b}",
        "nautilus": "\u{f07b}",
        "dolphin": "\u{f07b}",
        "thunderbird": "\u{f0e0}",
        "steam": "\u{db83}\u{dcd3}",
        "obsidian": "\u{db85}\u{dce7}",
        "telegram": "\u{f2c6}",
        "telegramdesktop": "\u{f2c6}",
        "org.telegram.desktop": "\u{f2c6}",
        "vlc": "\u{db82}\u{de79}",
        "mpv": "\u{db82}\u{de79}",
        "gimp": "\u{f1fc}",
        "inkscape": "\u{f1fc}"
    };
    return map[String(cls || "").toLowerCase()] || "\u{f2d0}";
}

function normalizeAddress(address) {
    var value = String(address || "").trim();
    if (value === "") return "";
    return value.indexOf("0x") === 0 || value.indexOf("0X") === 0 ? value : ("0x" + value);
}

/**
 * Workspace list generator:
 * By default returns all 10 workspaces [1..10] so the user can easily see and navigate all spaces.
 * If activeOnly is true, returns only occupied workspaces + active workspace.
 */
function getWorkspaceIds(toplevels, activeWsId, currentWorkspaceOnly, activeOnly) {
    var activeId = Number(activeWsId || 1);
    if (!isFinite(activeId) || activeId <= 0) activeId = 1;

    if (currentWorkspaceOnly === true) {
        return [activeId];
    }

    if (activeOnly === true) {
        var set = {};
        set[activeId] = true;
        var vals = toplevels || [];
        for (var i = 0; i < vals.length; i++) {
            var c = vals[i];
            if (c && c.workspace && c.workspace.id !== undefined) {
                var wid = Number(c.workspace.id);
                if (isFinite(wid) && wid > 0) {
                    set[wid] = true;
                }
            }
        }
        var list = [];
        for (var k in set) {
            if (set.hasOwnProperty(k)) {
                list.push(Number(k));
            }
        }
        list.sort(function(a, b) { return a - b; });
        return list.length > 0 ? list : [1];
    }

    // Default: Always show all 10 workspaces
    return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
}

/**
 * Discovers and returns active/configured Special Workspaces (Scratchpads)
 */
function getSpecialWorkspaces(toplevels) {
    var foundMap = {};
    
    var defaults = [
        { name: "special:magic", label: "Magic", icon: "\u{f0d0}" },
        { name: "special:sp1", label: "SP 1", icon: "\u{f120}" },
        { name: "special:notes", label: "Notes", icon: "\u{f249}" },
        { name: "special:chat", label: "Chat", icon: "\u{f086}" },
        { name: "special:opencode", label: "OpenCode", icon: "\u{db84}\u{de1e}" }
    ];

    for (var d = 0; d < defaults.length; d++) {
        foundMap[defaults[d].name] = {
            name: defaults[d].name,
            label: defaults[d].label,
            icon: defaults[d].icon,
            clientCount: 0
        };
    }

    var vals = toplevels || [];
    for (var i = 0; i < vals.length; i++) {
        var c = vals[i];
        if (!c) continue;
        var ws = c.workspace;
        var ipc = c.lastIpcObject || {};
        var wsName = String((ws && ws.name) || (ipc.workspace && ipc.workspace.name) || "");
        var wsId = ws && ws.id !== undefined ? Number(ws.id) : (ipc.workspace ? Number(ipc.workspace.id) : 0);

        if (wsName.indexOf("special") === 0 || wsId < 0) {
            var actualName = wsName !== "" ? wsName : "special";
            if (!foundMap[actualName]) {
                foundMap[actualName] = {
                    name: actualName,
                    label: actualName.replace("special:", "SP: "),
                    icon: "\u{f0d0}",
                    clientCount: 0
                };
            }
            foundMap[actualName].clientCount++;
        }
    }

    var activeList = [];
    var inactiveList = [];

    for (var k in foundMap) {
        if (foundMap[k].clientCount > 0) {
            activeList.push(foundMap[k]);
        } else {
            inactiveList.push(foundMap[k]);
        }
    }

    // Return all active special workspaces + quick drop presets
    var result = activeList.slice();
    for (var j = 0; j < inactiveList.length && result.length < 5; j++) {
        result.push(inactiveList[j]);
    }
    return result;
}

function getClientsForSpecialWorkspace(toplevels, specialName) {
    var vals = toplevels || [];
    var result = [];
    var target = String(specialName || "special").trim();
    for (var i = 0; i < vals.length; i++) {
        var c = vals[i];
        if (!c) continue;
        var ws = c.workspace;
        var ipc = c.lastIpcObject || {};
        var wsName = String((ws && ws.name) || (ipc.workspace && ipc.workspace.name) || "");
        if (wsName === target || (target === "special" && ws && Number(ws.id) < 0)) {
            result.push(c);
        }
    }
    return result;
}

/**
 * Computes optimal column/row layout and 16:9 tile dimensions for any resolution (768p to 4K)
 * ensuring zero viewport clipping and zero layout overflow.
 */
function calcGridDimensions(count, availableW, availableH) {
    var num = Math.max(1, Number(count || 1));
    var maxW = Math.max(300, Number(availableW || 1200));
    var maxH = Math.max(180, Number(availableH || 460));
    var gap = 12;
    var aspectRatio = 16.0 / 9.0;

    var cols = 1;
    var rows = 1;

    if (num <= 1) {
        cols = 1; rows = 1;
    } else if (num === 2) {
        cols = 2; rows = 1;
    } else if (num <= 4) {
        cols = 2; rows = 2;
    } else if (num <= 6) {
        cols = 3; rows = 2;
    } else if (num <= 8) {
        cols = 4; rows = 2;
    } else if (num <= 10) {
        cols = 5; rows = 2;
    } else {
        cols = Math.min(6, Math.ceil(Math.sqrt(num)));
        rows = Math.ceil(num / cols);
    }

    var cellW = Math.floor((maxW - (cols - 1) * gap) / cols);
    var cellH = Math.floor((maxH - (rows - 1) * gap) / rows);

    var tileW = cellW;
    var tileH = Math.floor(tileW / aspectRatio);

    if (tileH > cellH) {
        tileH = cellH;
        tileW = Math.floor(tileH * aspectRatio);
    }

    tileW = Math.max(120, Math.min(tileW, 460));
    tileH = Math.max(70, Math.min(tileH, 260));

    return {
        columns: cols,
        rows: rows,
        tileWidth: tileW,
        tileHeight: tileH,
        gridWidth: cols * tileW + (cols - 1) * gap,
        gridHeight: rows * tileH + (rows - 1) * gap,
        gap: gap
    };
}
