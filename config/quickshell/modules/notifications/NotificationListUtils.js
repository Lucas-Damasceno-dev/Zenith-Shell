.pragma library

function notificationCount(notifications) {
    if (!notifications) return 0;
    if (notifications.count !== undefined) return notifications.count;
    if (notifications.length !== undefined) return notifications.length;
    return 0;
}

function notificationAt(notifications, index) {
    if (!notifications) return null;
    if (notifications.get) return notifications.get(index);
    return notifications[index];
}

function entryId(entry) {
    if (!entry) return -1;
    if (entry.entryId !== undefined) return Number(entry.entryId);
    if (entry.id !== undefined) return Number(entry.id);
    return -1;
}

function entryUnread(entry) {
    if (!entry) return false;
    if (entry.unread === undefined) return true;
    return entry.unread === true;
}

function entryUrgency(entry, normalUrgency) {
    if (!entry) return normalUrgency;
    return Number(entry.urgency || normalUrgency);
}

function entryApp(entry) {
    if (!entry) return "System";
    var app = String(entry.appName || "").trim();
    if (app !== "" && app !== "Unknown" && app.toLowerCase() !== "notify-send") return app;

    var sum = String(entry.summary || "").trim();
    if (sum !== "" && sum.length < 32) return sum;
    return "System";
}

function entryAppName(entry) {
    if (!entry) return "";
    return String(entry.appName || "").trim();
}

function entrySummary(entry) {
    if (!entry) return "Notification";
    var sum = String(entry.summary || "").trim();
    if (sum !== "") return sum;

    var app = String(entry.appName || "").trim();
    if (app !== "" && app !== "Unknown") return app;
    return "Notification";
}

function entryAppIcon(entry) {
    if (!entry) return "";
    return String(entry.appIcon || "").trim();
}

function entryImage(entry) {
    if (!entry) return "";
    return String(entry.image || "").trim();
}

function entryBody(entry) {
    if (!entry) return "";
    return String(entry.body || "").trim();
}

function entryThread(entry) {
    if (!entry) return "";
    var thread = String(entry.threadKey || "").trim();
    if (thread !== "") return thread;
    var summary = entrySummary(entry);
    return summary === "" ? "general" : summary.substring(0, 42);
}

function findEntryById(notifications, targetId) {
    var count = notificationCount(notifications);
    var numericId = Number(targetId);
    for (var i = 0; i < count; i++) {
        var candidate = notificationAt(notifications, i);
        if (entryId(candidate) === numericId) return candidate;
    }
    return null;
}

function matchesFilter(entry, options) {
    if (!entry) return false;
    var opts = options || ({});

    var normalUrgency = Number(opts.normalUrgency || 0);
    var criticalUrgency = Number(opts.criticalUrgency || normalUrgency);
    var urgency = entryUrgency(entry, normalUrgency);
    var unread = entryUnread(entry);
    var app = entryApp(entry);
    var summary = entrySummary(entry);
    var body = entryBody(entry);

    if (opts.focusMode === true && urgency !== criticalUrgency) return false;
    if (String(opts.filterMode || "all") === "unread" && !unread) return false;
    if (String(opts.filterMode || "all") === "critical" && urgency !== criticalUrgency) return false;

    var appFilter = String(opts.appFilter || "").trim().toLowerCase();
    if (String(opts.filterMode || "all") === "app" && appFilter !== "" && app.toLowerCase() !== appFilter) return false;

    var query = String(opts.searchQuery || "").trim().toLowerCase();
    if (query !== "") {
        var haystack = (app + " " + summary + " " + body).toLowerCase();
        if (haystack.indexOf(query) < 0) return false;
    }

    return true;
}

function buildGroupedRows(notifications, options) {
    var grouped = ({});
    var activeGroups = ({});
    var groupEntriesByKey = ({});
    var order = [];

    var count = notificationCount(notifications);
    for (var i = 0; i < count; i++) {
        var entry = notificationAt(notifications, i);
        if (!entry) continue;
        if (!matchesFilter(entry, options)) continue;

        var app = entryApp(entry);
        var thread = entryThread(entry);
        var groupKey = app + "::" + thread;
        var groupTitle = thread === "general" ? app : (app + " • " + thread);

        if (!grouped[groupKey]) {
            grouped[groupKey] = {
                key: groupKey,
                title: groupTitle,
                entries: []
            };
            order.push(groupKey);
            activeGroups[groupKey] = true;
        }
        grouped[groupKey].entries.push(entryId(entry));
    }

    var rows = [];
    for (var j = 0; j < order.length; j++) {
        var key = order[j];
        var group = grouped[key];
        if (!group) continue;
        groupEntriesByKey[group.key] = group.entries.slice();
        rows.push({
            rowType: "group",
            groupKey: group.key,
            title: group.title,
            count: group.entries.length
        });
    }

    return {
        rows: rows,
        activeGroups: activeGroups,
        groupEntriesByKey: groupEntriesByKey
    };
}

function getEntriesForGroup(notifications, groupKey, options) {
    var count = notificationCount(notifications);
    var entries = [];
    for (var i = 0; i < count; i++) {
        var entry = notificationAt(notifications, i);
        if (!entry) continue;
        if (!matchesFilter(entry, options)) continue;

        var app = entryApp(entry);
        var thread = entryThread(entry);
        var key = app + "::" + thread;
        if (key === groupKey) {
            entries.push(entryId(entry));
        }
    }
    return entries;
}

function pruneCollapsedGroups(collapsedGroups, activeGroups) {
    var current = collapsedGroups || ({});
    var next = ({});
    for (var key in current) {
        if (activeGroups && activeGroups[key] === true)
            next[key] = current[key];
    }
    return next;
}

function invokeFirstAction(entry) {
    if (!entry) return;
    var actions = entry.actions;
    if (!actions || actions.length === 0) return;
    var action = actions[0];
    if (action && action.invoke) action.invoke();
}
