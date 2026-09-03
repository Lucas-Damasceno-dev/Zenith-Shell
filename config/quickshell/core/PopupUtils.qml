pragma Singleton
import QtQuick

QtObject {
    id: root

    function triggerCenterX(triggerItem) {
        if (!triggerItem)
            return -1;

        try {
            var center = triggerItem.mapToItem(null, triggerItem.width / 2, triggerItem.height / 2);
            return center.x;
        } catch (e) {
            return -1;
        }
    }

    function applyPopupDefaults(triggerItem, popup) {
        if (!popup)
            return;

        if (popup.popupMargin !== undefined) {
            var margin = ConfigFacade.popupCenterOffsetY();
            var settingsStore = null;
            if (popup.settingsStore !== undefined && popup.settingsStore)
                settingsStore = popup.settingsStore;
            else if (triggerItem && triggerItem.settingsStore !== undefined && triggerItem.settingsStore)
                settingsStore = triggerItem.settingsStore;
            if (settingsStore && settingsStore.get) {
                var storedMargin = Number(settingsStore.get("popupCenterOffsetY", margin));
                if (!isNaN(storedMargin) && storedMargin >= 0)
                    margin = storedMargin;
            }
            if (triggerItem && triggerItem.popupMargin !== undefined) {
                var triggerMargin = Number(triggerItem.popupMargin);
                if (!isNaN(triggerMargin) && triggerMargin >= 0)
                    margin = triggerMargin;
            }
            popup.popupMargin = margin;
        }
        if (popup.outsideCloseEnabled !== undefined)
            popup.outsideCloseEnabled = false;
        if (popup.anchorX !== undefined)
            popup.anchorX = -1;
    }

    function setPopupAnchor(triggerItem, popup) {
        if (!popup || popup.anchorX === undefined)
            return;
        popup.anchorX = -1;
    }

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
        if (isLoader(target)) {
            if (!target.active || !target.item)
                return false;
        }
        var resolved = resolveTarget(target);
        if (!resolved)
            return false;
        if (resolved.isOpen !== undefined)
            return resolved.isOpen === true;
        if (resolved.visible !== undefined)
            return resolved.visible === true;
        return false;
    }

    function ensureLoaded(target) {
        if (isLoader(target) && !target.active)
            target.active = true;
    }

    function setOpen(triggerItem, target, open) {
        if (!target)
            return;

        if (isLoader(target)) {
            if (!target.active) {
                if (target.openOnLoad !== undefined)
                    target.openOnLoad = open === true;
                if (open === false && target.pendingOpenOptions !== undefined)
                    target.pendingOpenOptions = null;
                target.active = open === true;
                return;
            }

            if (!target.item) {
                if (target.openOnLoad !== undefined)
                    target.openOnLoad = open === true;
                if (open === false)
                    target.active = false;
                if (open === false && target.pendingOpenOptions !== undefined)
                    target.pendingOpenOptions = null;
                return;
            }
        }

        var resolved = resolveTarget(target);
        if (!resolved)
            return;

        applyPopupDefaults(triggerItem, resolved);
        setPopupAnchor(triggerItem, resolved);

        if (resolved.isOpen !== undefined)
            resolved.isOpen = open;
        else if (resolved.visible !== undefined)
            resolved.visible = open;
    }

    function openPopup(triggerItem, popup) {
        setOpen(triggerItem, popup, true);
    }

    function closePopup(triggerItem, popup) {
        setOpen(triggerItem, popup, false);
    }

    function toggleTarget(triggerItem, target) {
        if (!target)
            return;

        setOpen(triggerItem, target, !isOpen(target));
    }

    function togglePopup(triggerItem, popup, options) {
        if (!popup) return;

        // Handle options for special popups like Overview
        if (options && typeof options === "object") {
            if (isLoader(popup) && (!popup.item || !popup.active) && popup.pendingOpenOptions !== undefined)
                popup.pendingOpenOptions = options;

            var resolved = resolveTarget(popup);
            if (resolved) {
                // Apply any extra options to the resolved popup
                for (var key in options) {
                    if (options.hasOwnProperty(key) && resolved[key] !== undefined) {
                        resolved[key] = options[key];
                    }
                }
            }
        }

        toggleTarget(triggerItem, popup);
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
            { key: "errorLogPopup", loader: shellRoot.errorLogLoader },
            { key: "clipboardPopup", loader: shellRoot.clipboardLoader }
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
}
