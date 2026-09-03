import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import "../core"
import "../services"
import "../modules/notifications"

PopupWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    showScrim: false
    glassRadius: 0
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0
    originY: 0.0
    originX: 0.5
    slideY: 10

    property bool muted: false
    property real anchorX: -1
    property real popupMargin: DesignTokens.spacingLG
    property bool outsideCloseEnabled: false
    property var settingsStore

    property string filterMode: "all" // all | unread | critical | app
    property string searchQuery: ""
    property string appFilter: ""
    property bool focusMode: false
    property int retentionLimit: 120
    property bool persistHistory: true

    property int unreadCount: 0
    property int criticalUnreadCount: 0
    property bool hasCritical: criticalUnreadCount > 0
    property int activeToastCount: 0

    property string historyPath: RuntimePaths.appDataFile("notifications-history.json")
    property bool historyLoaded: false
    property bool syncingStore: false
    property var notificationRefs: ({})
    property int modelTick: 0

    property alias toastEntries: notificationModel
    property alias notificationModel: notificationModel

    function _toInt(value, fallback) {
        var n = Number(value);
        return isNaN(n) ? fallback : n;
    }

    function _entryId(entry) {
        if (!entry) return -1;
        return _toInt(entry.entryId, -1);
    }

    function _entryApp(entry) {
        if (!entry) return "System";
        var app = String(entry.appName || "").trim();
        if (app !== "" && app !== "Unknown") return app;
        
        var sum = String(entry.summary || "").trim();
        if (sum !== "" && sum.length < 24) return sum;
        return "System";
    }

    function _entrySummary(entry) {
        if (!entry) return "Notification";
        var sum = String(entry.summary || "").trim();
        if (sum !== "") return sum;
        
        var app = String(entry.appName || "").trim();
        if (app !== "" && app !== "Unknown") return app;
        return "Notification";
    }

    function _entryUrgency(entry) {
        if (!entry) return NotificationUrgency.Normal;
        return _toInt(entry.urgency, NotificationUrgency.Normal);
    }

    function _entryUnread(entry) {
        if (!entry) return false;
        return entry.unread === true;
    }

    function _findEntryIndex(entryId) {
        for (var i = 0; i < notificationModel.count; i++) {
            if (_entryId(notificationModel.get(i)) === entryId) return i;
        }
        return -1;
    }

    function _setNotificationRef(entryId, notification) {
        var refs = notificationRefs || ({});
        refs[String(entryId)] = notification;
        notificationRefs = refs;
    }

    function _getNotificationRef(entryId) {
        if (!notificationRefs) return null;
        var key = String(entryId);
        return notificationRefs[key] || null;
    }

    function _clearNotificationRef(entryId) {
        if (!notificationRefs) return;
        var key = String(entryId);
        var refs = notificationRefs;
        if (refs[key] === undefined) return;
        delete refs[key];
        notificationRefs = refs;
    }

    function _dismissLiveRef(entryId) {
        var ref = _getNotificationRef(entryId);
        if (ref && ref.dismiss) ref.dismiss();
    }

    function refreshCounts() {
        var unread = 0;
        var critical = 0;
        var toasts = 0;
        for (var i = 0; i < notificationModel.count; i++) {
            var row = notificationModel.get(i);
            if (row && row.toastVisible === true) toasts += 1;
            if (!_entryUnread(row)) continue;
            unread += 1;
            if (_entryUrgency(row) === NotificationUrgency.Critical) critical += 1;
        }
        unreadCount = unread;
        criticalUnreadCount = critical;
        activeToastCount = toasts;
    }

    function markRead(entryId) {
        var idx = _findEntryIndex(entryId);
        if (idx < 0) return;
        notificationModel.setProperty(idx, "unread", false);
        modelTick++;
        refreshCounts();
        persistTimer.restart();
    }

    function markToastConsumed(entryId) {
        var idx = _findEntryIndex(entryId);
        if (idx < 0) return;
        notificationModel.setProperty(idx, "toastVisible", false);
        modelTick++;
        refreshCounts();
        persistTimer.restart();
    }

    function markClosed(entryId) {
        var idx = _findEntryIndex(entryId);
        if (idx < 0) return;
        notificationModel.setProperty(idx, "unread", false);
        notificationModel.setProperty(idx, "toastVisible", false);
        modelTick++;
        refreshCounts();
        persistTimer.restart();
    }

    function dismissEntry(entryId) {
        var idx = _findEntryIndex(entryId);
        if (idx < 0) return;
        _dismissLiveRef(entryId);
        _clearNotificationRef(entryId);
        notificationModel.remove(idx);
        modelTick++;
        refreshCounts();
        persistTimer.restart();
    }

    function dismissByApp(appName, appLabel) {
        var targetAppName = String(appName || "").trim();
        var targetAppLabel = String(appLabel || "").trim();
        for (var i = notificationModel.count - 1; i >= 0; i--) {
            var row = notificationModel.get(i);
            var rowAppName = String(row.appName || "").trim();
            var matches = false;
            if (targetAppName !== "") {
                matches = rowAppName === targetAppName;
                if (!matches && rowAppName === "")
                    matches = _entryApp(row) === targetAppLabel;
            } else {
                matches = _entryApp(row) === targetAppLabel;
            }
            if (!matches) continue;
            _dismissLiveRef(_entryId(row));
            _clearNotificationRef(_entryId(row));
            notificationModel.remove(i);
        }
        modelTick++;
        refreshCounts();
        persistTimer.restart();
    }

    function clearAllNotifications() {
        for (var i = 0; i < notificationModel.count; i++) {
            var row = notificationModel.get(i);
            _dismissLiveRef(_entryId(row));
        }
        notificationModel.clear();
        notificationRefs = ({});
        modelTick++;
        refreshCounts();
        persistTimer.restart();
    }

    function trimRetention() {
        var keep = Math.max(20, Math.min(500, retentionLimit));
        var changed = false;
        while (notificationModel.count > keep) {
            var idx = notificationModel.count - 1;
            var row = notificationModel.get(idx);
            _clearNotificationRef(_entryId(row));
            notificationModel.remove(idx);
            changed = true;
        }
        if (changed) modelTick++;
    }

    function appendNotification(notification) {
        var app = String(notification.appName || "").trim();
        var summary = String(notification.summary || "").trim();
        var body = String(notification.body || "").trim();
        var appIcon = String(notification.appIcon || "").trim();
        var image = String(notification.image || "").trim();
        var urgency = _toInt(notification.urgency, NotificationUrgency.Normal);
        var id = _toInt(notification.id, Date.now());

        var entry = {
            entryId: id,
            appName: app,
            appIcon: appIcon,
            image: image,
            summary: summary,
            body: body,
            urgency: urgency,
            unread: true,
            toastVisible: true,
            timestamp: Date.now(),
            threadKey: summary === "" ? "general" : summary.substring(0, 42),
            actions: []
        };

        // Deep copy actions to avoid reference issues
        if (notification.actions && notification.actions.length > 0) {
            for (var i = 0; i < notification.actions.length; i++) {
                var action = notification.actions[i];
                entry.actions.push({
                    text: String(action.text || ""),
                    identifier: String(action.identifier || ""),
                    invoke: action.invoke
                });
            }
        }

        var existing = _findEntryIndex(id);
        if (existing >= 0) {
            notificationModel.remove(existing);
            _clearNotificationRef(id);
        }
        _setNotificationRef(id, notification);
        notificationModel.insert(0, entry);
        modelTick++;
        trimRetention();
        refreshCounts();
        persistTimer.restart();

        notification.closed.connect(function() {
            root.markClosed(id);
            root._clearNotificationRef(id);
        });
    }

    function toPersistedArray() {
        var rows = [];
        var keep = Math.max(20, Math.min(500, retentionLimit));
        for (var i = 0; i < Math.min(notificationModel.count, keep); i++) {
            var row = notificationModel.get(i);
            rows.push({
                entryId: _entryId(row),
                appName: _entryApp(row),
                appIcon: String(row.appIcon || ""),
                image: String(row.image || ""),
                summary: _entrySummary(row),
                body: String(row.body || ""),
                urgency: _entryUrgency(row),
                unread: _entryUnread(row),
                toastVisible: false,
                timestamp: _toInt(row.timestamp, Date.now()),
                threadKey: String(row.threadKey || "")
            });
        }
        return rows;
    }

    function loadPersistedHistory(rawJson) {
        if (!rawJson || rawJson.trim() === "") return;
        var parsed;
        try {
            parsed = JSON.parse(rawJson);
        } catch (e) {
            return;
        }
        if (!Array.isArray(parsed)) return;

        notificationModel.clear();
        var seen = ({});
        for (var i = 0; i < parsed.length; i++) {
            var row = parsed[i];
            if (!row) continue;
            var entryId = _toInt(row.entryId, Date.now() + i);
            if (seen[String(entryId)] === true) continue;
            seen[String(entryId)] = true;
            notificationModel.append({
                entryId: entryId,
                appName: String(row.appName || "Unknown"),
                appIcon: String(row.appIcon || ""),
                image: String(row.image || ""),
                summary: String(row.summary || ""),
                body: String(row.body || ""),
                urgency: _toInt(row.urgency, NotificationUrgency.Normal),
                unread: row.unread === true,
                toastVisible: false,
                timestamp: _toInt(row.timestamp, Date.now()),
                threadKey: String(row.threadKey || ""),
                actions: []
            });
        }
        trimRetention();
        refreshCounts();
    }

    function syncStorePreferences() {
        if (!historyLoaded) return;
        historyAdapter.persistHistory = persistHistory;
        historyAdapter.retentionLimit = retentionLimit;
        historyAdapter.muted = muted;
    }

    onMutedChanged: {
        if (!historyLoaded || syncingStore) return;
        dndNotifyProc.exec([
            "notify-send",
            "-a", "Do Not Disturb",
            muted ? "Do Not Disturb ativado" : "Do Not Disturb desativado",
            muted ? "Somente alertas visuais." : "Notificações normais restauradas."
        ]);
        persistTimer.restart();
    }
    onRetentionLimitChanged: if (historyLoaded && !syncingStore) { trimRetention(); persistTimer.restart(); }
    onPersistHistoryChanged: if (historyLoaded && !syncingStore) persistTimer.restart();

    onIsOpenChanged: {
        if (isOpen) {
            outsideCloseEnabled = false;
            closeEnableTimer.restart();
            refreshCounts();
        } else {
            outsideCloseEnabled = false;
        }
    }

    Timer {
        id: closeEnableTimer
        interval: 120
        repeat: false
        running: false
        onTriggered: root.outsideCloseEnabled = true
    }

    Timer {
        id: persistTimer
        interval: 700
        repeat: false
        running: false
        onTriggered: {
            if (!historyLoaded) return;
            root.syncStorePreferences();
            historyAdapter.persistHistory = true;
            historyAdapter.historyJson = JSON.stringify(root.toPersistedArray());
            historyFile.writeAdapter();
        }
    }

    ListModel {
        id: notificationModel
    }

    FileView {
        id: historyFile
        path: root.historyPath
        preload: true
        printErrors: false

        onLoaded: {
            root.syncingStore = true;
            root.persistHistory = true;
            root.retentionLimit = historyAdapter.retentionLimit;
            root.muted = historyAdapter.muted;
            historyAdapter.persistHistory = true;
            root.syncingStore = false;
            root.loadPersistedHistory(historyAdapter.historyJson);
            root.historyLoaded = true;
            persistTimer.restart();
        }

        onLoadFailed: function(error) {
            root.syncingStore = true;
            root.persistHistory = true;
            historyAdapter.persistHistory = true;
            root.syncingStore = false;
            if (error === FileViewError.FileNotFound) {
                historyFile.writeAdapter();
            }
            root.historyLoaded = true;
        }

        JsonAdapter {
            id: historyAdapter
            property bool persistHistory: true
            property int retentionLimit: 120
            property bool muted: false
            property string historyJson: "[]"
        }
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        bodySupported: true
        inlineReplySupported: true
        imageSupported: true
        bodyImagesSupported: true
        actionIconsSupported: true

        onNotification: function(notification) {
            var app = String(notification.appName || "").trim();
            var sum = String(notification.summary || "").trim();
            var isSystemFeedback = app === "Do Not Disturb" || app === "Energy Core" || (app === "Hyprland" && (sum.indexOf("Power profile") >= 0 || sum.indexOf("Context profile") >= 0 || sum.indexOf("Layout") >= 0)) || notification.urgency === NotificationUrgency.Critical;
            if (root.muted && !isSystemFeedback) {
                notification.dismiss();
                return;
            }
            notification.tracked = true;
            root.appendNotification(notification);
        }
    }

    TimedProcess {
        id: dndNotifyProc
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        onClicked: (mouse) => {
            var p = mapToItem(popupCard, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > popupCard.width || p.y > popupCard.height) {
                root.isOpen = false;
            }
        }
    }

    Item {
        id: popupCard
        width: 430
        height: 560
        anchors.top: parent.top
        anchors.topMargin: popupTopMargin
        x: Math.max(
            root.popupMargin,
            Math.min(
                root.width - width - root.popupMargin,
                (root.anchorX >= 0 ? root.anchorX : root.width / 2) - width / 2
            )
        )
        z: 1

        Rectangle {
            id: popupBg
            anchors.fill: parent
            radius: 18
            color: ColorScheme.withAlpha(ColorScheme.background, 0.72)
            border.color: ColorScheme.glassBorder
            border.width: 1
        }

        Rectangle {
            anchors.fill: popupBg
            anchors.topMargin: 6
            radius: popupBg.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Notifications"
                    color: ColorScheme.text
                    font.pixelSize: 15
                    font.bold: true
                    font.family: "Inter"
                }

                Rectangle {
                    visible: root.unreadCount > 0
                    width: unreadText.implicitWidth + 14
                    height: 20
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.accent, 0.18)

                    Text {
                        id: unreadText
                        anchors.centerIn: parent
                        text: root.unreadCount > 99 ? "99+" : root.unreadCount
                        color: ColorScheme.accent
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Inter"
                    }
                }

                Rectangle {
                    visible: root.criticalUnreadCount > 0
                    width: critText.implicitWidth + 14
                    height: 20
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.red, 0.22)

                    Text {
                        id: critText
                        anchors.centerIn: parent
                        text: "Critical " + root.criticalUnreadCount
                        color: ColorScheme.red
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Inter"
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: dndText.implicitWidth + 16
                    implicitHeight: 26
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    Layout.alignment: Qt.AlignRight
                    z: 2
                    radius: 13
                    color: root.muted
                        ? ColorScheme.withAlpha(ColorScheme.yellow, 0.20)
                        : ColorScheme.withAlpha(ColorScheme.surface, 0.35)
                    border.color: root.muted
                        ? ColorScheme.withAlpha(ColorScheme.yellow, 0.4)
                        : "transparent"
                    border.width: 1

                    Text {
                        id: dndText
                        anchors.centerIn: parent
                        text: root.muted ? "DND On" : "DND"
                        color: root.muted ? ColorScheme.yellow : ColorScheme.withAlpha(ColorScheme.text, 0.75)
                        font.pixelSize: 10
                        font.family: "Inter"
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        acceptedButtons: Qt.LeftButton
                        onPressed: function(mouse) { mouse.accepted = true; }
                        onClicked: root.muted = !root.muted
                    }
                }

                Rectangle {
                    implicitWidth: clearText.implicitWidth + 16
                    implicitHeight: 26
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    Layout.alignment: Qt.AlignRight
                    z: 2
                    radius: 13
                    color: clearMa.containsMouse
                        ? ColorScheme.withAlpha(ColorScheme.red, 0.16)
                        : ColorScheme.withAlpha(ColorScheme.surface, 0.35)

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: "Clear"
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.75)
                        font.pixelSize: 10
                        font.family: "Inter"
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        acceptedButtons: Qt.LeftButton
                        onPressed: function(mouse) { mouse.accepted = true; }
                        onClicked: root.clearAllNotifications()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { key: "all", label: "All" },
                        { key: "unread", label: "Unread" },
                        { key: "critical", label: "Critical" },
                        { key: "app", label: "App" }
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 26
                        radius: 13
                        color: root.filterMode === modelData.key
                            ? ColorScheme.withAlpha(ColorScheme.accent, 0.20)
                            : ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                        border.color: root.filterMode === modelData.key
                            ? ColorScheme.withAlpha(ColorScheme.accent, 0.42)
                            : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.filterMode === modelData.key ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.75)
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Inter"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.filterMode = modelData.key
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                TextField {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    placeholderText: "Buscar texto..."
                    text: root.searchQuery
                    onTextChanged: root.searchQuery = text
                    font.pixelSize: 10
                    font.family: "Inter"
                    color: ColorScheme.text
                    placeholderTextColor: ColorScheme.withAlpha(ColorScheme.text, 0.4)
                    background: Rectangle {
                        radius: 8
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                        border.color: ColorScheme.withAlpha(ColorScheme.text, 0.12)
                        border.width: 1
                    }
                }

                TextField {
                    visible: root.filterMode === "app"
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 30
                    placeholderText: "Nome do app"
                    text: root.appFilter
                    onTextChanged: root.appFilter = text
                    font.pixelSize: 10
                    font.family: "Inter"
                    color: ColorScheme.text
                    placeholderTextColor: ColorScheme.withAlpha(ColorScheme.text, 0.4)
                    background: Rectangle {
                        radius: 8
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                        border.color: ColorScheme.withAlpha(ColorScheme.text, 0.12)
                        border.width: 1
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    width: focusText.implicitWidth + 14
                    height: 24
                    radius: 12
                    color: root.focusMode
                        ? ColorScheme.withAlpha(ColorScheme.red, 0.22)
                        : ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                    Text {
                        id: focusText
                        anchors.centerIn: parent
                        text: root.focusMode ? "Focus: Critical" : "Focus Off"
                        color: root.focusMode ? ColorScheme.red : ColorScheme.withAlpha(ColorScheme.text, 0.7)
                        font.pixelSize: 9
                        font.family: "Inter"
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellController.toggleFocusMode()
                    }
                }

                Rectangle {
                    width: persistText.implicitWidth + 14
                    height: 24
                    radius: 12
                    color: ColorScheme.withAlpha(ColorScheme.green, 0.20)
                    Text {
                        id: persistText
                        anchors.centerIn: parent
                        text: "Persist ON"
                        color: ColorScheme.green
                        font.pixelSize: 9
                        font.family: "Inter"
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.persistHistory = true;
                            persistTimer.restart();
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Retenção"
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.6)
                    font.pixelSize: 9
                    font.family: "Inter"
                }

                SpinBox {
                    from: 20
                    to: 500
                    value: root.retentionLimit
                    editable: true
                    onValueModified: root.retentionLimit = value
                    implicitHeight: 24
                    implicitWidth: 74
                    background: Rectangle {
                        radius: 6
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                        border.color: ColorScheme.withAlpha(ColorScheme.text, 0.12)
                        border.width: 1
                    }
                    contentItem: TextInput {
                        text: parent.textFromValue(parent.value, parent.locale)
                        font.pixelSize: 10
                        font.family: "Inter"
                        color: ColorScheme.text
                        selectionColor: ColorScheme.accent
                        selectedTextColor: ColorScheme.background
                        horizontalAlignment: Qt.AlignHCenter
                        verticalAlignment: Qt.AlignVCenter
                        readOnly: !parent.editable
                        validator: parent.validator
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                    up.indicator: Rectangle {
                        x: parent.width - width
                        height: parent.height
                        width: 18
                        radius: 4
                        color: parent.up.pressed ? ColorScheme.withAlpha(ColorScheme.accent, 0.2) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: 10
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.6)
                        }
                    }
                    down.indicator: Rectangle {
                        x: 0
                        height: parent.height
                        width: 18
                        radius: 4
                        color: parent.down.pressed ? ColorScheme.withAlpha(ColorScheme.accent, 0.2) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "−"
                            font.pixelSize: 10
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.6)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: ColorScheme.withAlpha(ColorScheme.text, 0.08)
            }

            NotificationList {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                notifications: root.notificationModel
                modelTick: root.modelTick
                muted: root.muted
                filterMode: root.filterMode
                searchQuery: root.searchQuery
                appFilter: root.appFilter
                focusMode: root.focusMode
                dismissAppFn: function(appName) { root.dismissByApp(appName); }
                dismissFn: function(entryId) { root.dismissEntry(entryId); }
                markReadFn: function(entryId) { root.markRead(entryId); }
            }
        }
    }
}
