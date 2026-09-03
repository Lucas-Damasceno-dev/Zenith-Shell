function isLoader(target) {
    return !!(target && target.active !== undefined && target.sourceComponent !== undefined);
}

function resolveTarget(target) {
    if (!target)
        return null;
    if (isLoader(target)) {
        if (!target.active)
            return target;
        if (target.item)
            return target.item;
    }
    return target;
}

function isOpen(target) {
    if (isLoader(target) && !target.active)
        return false;
    var resolved = resolveTarget(target);
    if (!resolved)
        return false;
    if (resolved.isOpen !== undefined)
        return resolved.isOpen === true;
    if (resolved.visible !== undefined)
        return resolved.visible === true;
    return false;
}

function shellPopupEntries(shellRoot) {
    if (!shellRoot)
        return [];

    return [
        { key: "calendarPopup", loader: shellRoot.calendarLoader },
        { key: "notificationPopup", loader: shellRoot.notificationPopupWindow },
        { key: "utilityMenu", loader: shellRoot.utilityMenuLoader },
        { key: "audioPopup", loader: shellRoot.audioLoader },
        { key: "networkPopup", loader: shellRoot.networkLoader },
        { key: "batteryPopup", loader: shellRoot.batteryLoader },
        { key: "sessionPopup", loader: shellRoot.sessionLoader },
        { key: "errorLogPopup", loader: shellRoot.errorLogLoader }
    ];
}

function barPopupEntries(bar) {
    if (!bar)
        return [];

    return [
        bar.launcherInstance,
        bar.overviewInstance,
        bar.calendarInstance,
        bar.notificationCenter,
        bar.mediaPopup,
        bar.weatherPopup,
        bar.utilityHub,
        bar.audioPopup,
        bar.networkPopup,
        bar.batteryPopup,
        bar.sessionPopup,
        bar.systemMonitorPopup,
        bar.errorPopup,
        bar.contextPopup,
        bar.nixMonitorPopup,
        bar.quickNotesPopup,
        bar.usbPopup,
        bar.volumeMixerPopup,
        bar.clipboardPopup
    ];
}

function anyBarPopupOpen(bar) {
    if (!bar)
        return false;

    var entries = barPopupEntries(bar);
    for (var i = 0; i < entries.length; i++) {
        if (isOpen(entries[i]))
            return true;
    }
    return false;
}

function missingShellPopups(shellRoot) {
    if (!shellRoot)
        return [];

    var missing = [];
    var entries = shellPopupEntries(shellRoot);
    for (var i = 0; i < entries.length; i++) {
        if (!entries[i].loader)
            missing.push(entries[i].key);
    }
    return missing;
}
