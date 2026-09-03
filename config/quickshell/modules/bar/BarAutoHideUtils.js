.pragma library

function shouldHideByWindow(focusedWorkspace, toplevels, monitorName, expectedBarHeight) {
    if (!focusedWorkspace) return false;
    var windows = toplevels || [];
    var monName = String(monitorName || "");
    var barHeight = Number(expectedBarHeight || 0);

    for (var i = 0; i < windows.length; i++) {
        var win = windows[i];
        if (!win || !win.workspace || String(win.workspace.id) !== String(focusedWorkspace.id)) continue;

        var winMonitor = win.workspace.monitor;
        if (!winMonitor || winMonitor.name !== monName) continue;

        if (win.lastIpcObject && win.lastIpcObject.minimized) continue;

        var isFullscreen = win.fullscreen || (win.lastIpcObject && win.lastIpcObject.fullscreen);
        if (isFullscreen) return true;

        var isFloating = (win.floating === true) || (win.lastIpcObject && win.lastIpcObject.floating === true);
        if (!isFloating) return true;

        var winX = -1;
        var winY = -1;
        var winW = 0;
        var winH = 0;
        if (win.at) {
            winX = win.at.x;
            winY = win.at.y;
        } else if (win.lastIpcObject && win.lastIpcObject.at) {
            winX = win.lastIpcObject.at[0];
            winY = win.lastIpcObject.at[1];
        }
        if (win.size) {
            winW = win.size.width;
            winH = win.size.height;
        } else if (win.lastIpcObject && win.lastIpcObject.size) {
            winW = win.lastIpcObject.size[0];
            winH = win.lastIpcObject.size[1];
        }

        if (winX !== -1 && winY !== -1) {
            var monX = winMonitor.x !== undefined ? winMonitor.x : 0;
            var monY = winMonitor.y !== undefined ? winMonitor.y : 0;
            var monWidth = winMonitor.width !== undefined ? winMonitor.width : 1920;

            var barTop = monY;
            var barBottom = monY + barHeight + 20;
            var barLeft = monX;
            var barRight = monX + monWidth;

            var winBottom = winY + winH;
            var winRight = winX + winW;

            var overlapY = (winY < barBottom) && (winBottom > barTop);
            var overlapX = (winX < barRight) && (winRight > barLeft);

            if (overlapY && overlapX) return true;
        }
    }

    return false;
}
