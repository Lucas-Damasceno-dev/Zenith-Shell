.pragma library

function sendCommand(commandSender, runtimePaths, action, target) {
    var payload = JSON.stringify({ action: action, target: target });
    commandSender.exec([
        "bash",
        runtimePaths.scriptFile("send_command.sh"),
        payload
    ]);
}

function openWorkspaceSwitcher(workspaceSwitcherLoader) {
    if (!workspaceSwitcherLoader.active) {
        workspaceSwitcherLoader.active = true;
        return;
    }

    if (workspaceSwitcherLoader.item) {
        if (!workspaceSwitcherLoader.item.isOpen) {
            workspaceSwitcherLoader.item.isOpen = true;
        } else {
            workspaceSwitcherLoader.item.cycleNext();
        }
    }
}

function reloadDailyBriefing(dailyBriefingNotifyProc, runtimePaths) {
    dailyBriefingNotifyProc.exec(["bash", runtimePaths.scriptFile("daily_briefing.sh"), "--notify"]);
}

function triggerOsd(shellRoot, osdLoader, popupUtils, action) {
    shellRoot.pendingOsdAction = action;
    popupUtils.ensureLoaded(osdLoader);
    shellRoot.flushPendingOsdAction();
}

function updateContext(shellRoot, payload, shellController, logger) {
    try {
        var data = JSON.parse(payload);
        shellRoot.contextData = shellController.normalizeContextData(data);
    } catch (e) {
        logger.warn("Shell", "Failed to parse context data", String(e));
    }
}

function updateConnectivity(payload, connectivityService, logger) {
    if (!connectivityService.handleIpcPayload(payload)) {
        logger.warn("Shell", "Failed to parse connectivity payload");
    }
}
