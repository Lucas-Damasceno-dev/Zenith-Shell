import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Notifications
import "../../core"
import "../../shared"
import "./NotificationListUtils.js" as NotificationListUtils

Item {
    id: root

    property var notifications: []
    property string filterMode: "all" // all | unread | critical | app
    property string searchQuery: ""
    property string appFilter: ""
    property bool focusMode: false
    property bool muted: false
    property var dismissAppFn
    property var dismissFn
    property var markReadFn

    property int modelTick: 0
    property var collapsedGroups: ({})
    property bool _syncPending: false

    function _notificationCount() { return NotificationListUtils.notificationCount(notifications); }
    function _notificationAt(index) { return NotificationListUtils.notificationAt(notifications, index); }
    function _findEntryById(entryId) { return NotificationListUtils.findEntryById(notifications, entryId); }
    function _entryId(entry) { return NotificationListUtils.entryId(entry); }
    function _entryUnread(entry) { return NotificationListUtils.entryUnread(entry); }
    function _entryUrgency(entry) { return NotificationListUtils.entryUrgency(entry, NotificationUrgency.Normal); }
    function _entryApp(entry) { return NotificationListUtils.entryApp(entry); }
    function _entryAppName(entry) { return NotificationListUtils.entryAppName(entry); }
    function _entryAppIcon(entry) { return NotificationListUtils.entryAppIcon(entry); }
    function _entryImage(entry) { return NotificationListUtils.entryImage(entry); }
    function _entrySummary(entry) { return NotificationListUtils.entrySummary(entry); }
    function _entryBody(entry) { return NotificationListUtils.entryBody(entry); }
    function _entryThread(entry) { return NotificationListUtils.entryThread(entry); }

    function getEntriesForGroup(key) {
        var _ = modelTick;
        return NotificationListUtils.getEntriesForGroup(notifications, key, {
            focusMode: focusMode,
            filterMode: filterMode,
            appFilter: appFilter,
            searchQuery: searchQuery,
            criticalUrgency: NotificationUrgency.Critical,
            normalUrgency: NotificationUrgency.Normal
        });
    }

    function _matchesFilter(entry) {
        return NotificationListUtils.matchesFilter(entry, {
            focusMode: focusMode,
            filterMode: filterMode,
            appFilter: appFilter,
            searchQuery: searchQuery,
            criticalUrgency: NotificationUrgency.Critical,
            normalUrgency: NotificationUrgency.Normal
        });
    }

    function _dismiss(entry) {
        var id = _entryId(entry);
        if (dismissFn) dismissFn(id);
    }

    function _markRead(entry) {
        var id = _entryId(entry);
        if (markReadFn) markReadFn(id);
    }

    function _dismissApp(entry) {
        var app = _entryApp(entry);
        var appName = _entryAppName(entry);
        if (dismissAppFn) dismissAppFn(appName, app);
    }

    function _pruneCollapsedGroups(activeGroups) {
        collapsedGroups = NotificationListUtils.pruneCollapsedGroups(collapsedGroups, activeGroups);
    }

    function syncRows() {
        rowsModel.clear();
        var grouped = NotificationListUtils.buildGroupedRows(notifications, {
            focusMode: focusMode,
            filterMode: filterMode,
            appFilter: appFilter,
            searchQuery: searchQuery,
            criticalUrgency: NotificationUrgency.Critical,
            normalUrgency: NotificationUrgency.Normal
        });
        for (var i = 0; i < grouped.rows.length; i++)
            rowsModel.append(grouped.rows[i]);
        _pruneCollapsedGroups(grouped.activeGroups);
    }

    function refreshLayout() {
        syncRows();
    }

    function scheduleSyncRows() {
        if (_syncPending)
            return;
        _syncPending = true;
        syncRowsTimer.restart();
    }

    onModelTickChanged: scheduleSyncRows()
    onNotificationsChanged: scheduleSyncRows()
    onFilterModeChanged: scheduleSyncRows()
    onSearchQueryChanged: scheduleSyncRows()
    onAppFilterChanged: scheduleSyncRows()
    onFocusModeChanged: scheduleSyncRows()
    Component.onCompleted: scheduleSyncRows()

    Timer {
        id: syncRowsTimer
        interval: FeatureFlags.lowPowerUiMode ? 40 : 20
        repeat: false
        onTriggered: {
            root._syncPending = false;
            root.syncRows();
        }
    }

    ListModel {
        id: rowsModel
    }

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        spacing: 8
        model: rowsModel
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: FeatureFlags.lowPowerUiMode ? 120 : 240

        add: Transition {
            enabled: !FeatureFlags.reducedMotion
            NumberAnimation { properties: "opacity,y"; from: 0; duration: 180; easing.type: Easing.OutCubic }
        }
        remove: Transition {
            enabled: !FeatureFlags.reducedMotion
            NumberAnimation { properties: "opacity,y"; to: 0; duration: 140; easing.type: Easing.InCubic }
        }
        displaced: Transition {
            enabled: !FeatureFlags.reducedMotion
            NumberAnimation { properties: "y"; duration: 140; easing.type: Easing.OutCubic }
        }

        delegate: Loader {
            id: rowLoader
            width: ListView.view.width
            height: item ? item.height : 0
            opacity: 1
            sourceComponent: groupRow

            property string m_groupKey: typeof groupKey !== "undefined" ? groupKey : ""
            property string m_title: typeof title !== "undefined" ? title : ""
            property int m_count: typeof count !== "undefined" ? count : 0

            function applyRoleData() {
                if (!item) return;
                item.groupKey = String(m_groupKey || "");
                item.title = String(m_title || "");
                item.count = Number(m_count || 0);
            }

            onLoaded: rowLoader.applyRoleData()
            onM_groupKeyChanged: rowLoader.applyRoleData()
            onM_titleChanged: rowLoader.applyRoleData()
            onM_countChanged: rowLoader.applyRoleData()
        }
    }

    Component {
        id: groupRow
        Rectangle {
            id: groupCard
            property string groupKey: ""
            property string title: ""
            property int count: 0
            readonly property bool isCollapsed: root.collapsedGroups && root.collapsedGroups[groupKey] === true
            readonly property var entryIds: root.getEntriesForGroup(groupKey)

            width: listView.width
            radius: 10
            clip: true
            color: ColorScheme.withAlpha(ColorScheme.text, 0.06)
            border.color: ColorScheme.withAlpha(ColorScheme.text, 0.07)
            border.width: 1
            implicitHeight: groupContent.implicitHeight + 8
            height: implicitHeight

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: ColorScheme.withAlpha(ColorScheme.accent, 0.05) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Behavior on height {
                enabled: !FeatureFlags.reducedMotion
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Column {
                id: groupContent
                width: parent.width
                spacing: 6

                Item {
                    id: headerItem
                    width: parent.width
                    height: 32

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: groupCard.isCollapsed ? "\u{f105}" : "\u{f107}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.75)
                        }

                        Text {
                            text: groupCard.title
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.85)
                            font.pixelSize: 11
                            font.bold: true
                            font.family: DesignTokens.fontFamilyUI
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            radius: 8
                            height: 16
                            width: countText.implicitWidth + 10
                            color: ColorScheme.withAlpha(ColorScheme.accent, 0.22)

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: groupCard.entryIds ? groupCard.entryIds.length : groupCard.count
                                color: ColorScheme.accent
                                font.pixelSize: 9
                                font.bold: true
                                font.family: DesignTokens.fontFamilyUI
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var next = !groupCard.isCollapsed;
                            var updated = ({});
                            var current = root.collapsedGroups || ({});
                            for (var key in current)
                                updated[key] = current[key];
                            updated[groupCard.groupKey] = next;
                            root.collapsedGroups = updated;
                        }
                    }
                }

                Item {
                    id: itemsContainer
                    width: parent.width
                    height: groupCard.isCollapsed ? 0 : itemsColumn.implicitHeight
                    implicitHeight: itemsColumn.implicitHeight
                    clip: true
                    opacity: groupCard.isCollapsed ? 0 : 1
                    scale: groupCard.isCollapsed ? 0.995 : 1.0

                    Behavior on height {
                        enabled: !FeatureFlags.reducedMotion
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Behavior on opacity {
                        enabled: !FeatureFlags.reducedMotion
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    Behavior on scale {
                        enabled: !FeatureFlags.reducedMotion
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    Column {
                        id: itemsColumn
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: groupCard.entryIds || []
                            delegate: itemRow
                        }
                    }
                }
            }
        }
    }

    Component {
        id: itemRow
        Rectangle {
            id: itemCard
            property int entryId: -1
            readonly property int resolvedEntryId: entryId >= 0
                ? entryId
                : (typeof modelData !== "undefined" ? Number(modelData || -1) : -1)
            readonly property var entry: root._findEntryById(resolvedEntryId)

            width: parent ? (parent.width - 12) : 0
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            radius: 10
            color: itemMouse.containsMouse
                ? ColorScheme.glassModal
                : ColorScheme.glassCard
            border.color: itemMouse.containsMouse
                ? ColorScheme.withAlpha(ColorScheme.text, 0.16)
                : ColorScheme.withAlpha(ColorScheme.text, 0.08)
            border.width: 1
            clip: true
            implicitHeight: Math.max(76, contentLayout.implicitHeight + 18)
            height: implicitHeight
            opacity: itemMouse.containsMouse ? 1.0 : 0.96
            scale: itemMouse.containsMouse ? 1.005 : 1.0

            Behavior on opacity {
                enabled: !FeatureFlags.reducedMotion
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Behavior on scale {
                enabled: !FeatureFlags.reducedMotion
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: ColorScheme.withAlpha(ColorScheme.accent, 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 1
                width: 3.5
                radius: 2
                color: {
                    var urgency = root._entryUrgency(entry);
                    if (urgency === NotificationUrgency.Critical) return ColorScheme.red;
                    if (urgency === NotificationUrgency.Low) return ColorScheme.withAlpha(ColorScheme.accent, 0.45);
                    return ColorScheme.accent;
                }
            }

            MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root._markRead(entry)
            }

            RowLayout {
                id: contentLayout
                anchors.left: parent.left
                anchors.right: closeBtn.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                spacing: 10

                // App Icon Chip
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 2
                    radius: 10
                    color: ColorScheme.withAlpha(listIcon.fallbackColor, 0.14)
                    border.color: ColorScheme.withAlpha(listIcon.fallbackColor, 0.28)
                    border.width: 1
                    clip: true

                    SmartIcon {
                        id: listIcon
                        anchors.centerIn: parent
                        size: 22
                        source: {
                            var app = String(root._entryApp(entry) || "").trim();
                            var a = app.toLowerCase();
                            var isSys = a === "hyprland" || a === "do not disturb" || a === "energy core" || a === "sistema" || a === "system" || a === "quickshell" || a === "notify-send" || a === "wallpaper engine";
                            var ico = root._entryAppIcon(entry);
                            if (ico !== "" && (ico.indexOf("/") >= 0 || (!isSys && ico !== "dnd"))) return ico;
                            var img = root._entryImage(entry);
                            if (img !== "") return img;
                            if (!isSys && app !== "" && app !== "System" && app !== "Sistema") return app;
                            return "";
                        }
                        label: {
                            var app = String(root._entryApp(entry) || "").trim();
                            var a = app.toLowerCase();
                            var isSys = a === "hyprland" || a === "do not disturb" || a === "energy core" || a === "sistema" || a === "system" || a === "quickshell" || a === "notify-send" || a === "wallpaper engine";
                            if (!isSys && app !== "" && app !== "System" && app !== "Sistema") return app;
                            var sum = root._entrySummary(entry);
                            if (sum !== "" && sum.length < 32) return sum;
                            return app;
                        }
                        context: {
                            var app = root._entryApp(entry);
                            var sum = root._entrySummary(entry);
                            var b = root._entryBody(entry);
                            return (app + " " + sum + " " + b).trim();
                        }
                        fallbackIcon: "\u{f0f3}"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: root._entryApp(entry)
                            color: ColorScheme.withAlpha(ColorScheme.accent, 0.85)
                            font.pixelSize: 10
                            font.bold: true
                            font.family: DesignTokens.fontFamilyUI
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root._entryUnread(entry) ? "●" : " "
                            color: root._entryUrgency(entry) === NotificationUrgency.Critical ? ColorScheme.red : ColorScheme.accent
                            font.pixelSize: 9
                            font.family: DesignTokens.fontFamilyUI
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root._entrySummary(entry)
                        color: ColorScheme.text
                        font.pixelSize: 11
                        font.bold: true
                        font.family: DesignTokens.fontFamilyUI
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root._entryBody(entry)
                        visible: text !== ""
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.72)
                        font.pixelSize: 10
                        font.family: DesignTokens.fontFamilyUI
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        lineHeight: 1.15
                    }

                    // Action buttons
                    Row {
                        spacing: 6
                        visible: !!(entry && ((entry.actions && entry.actions.length > 0) || root._entryAppName(entry) !== ""))
                        Layout.topMargin: 2

                        Repeater {
                            model: entry && entry.actions ? Math.min(3, entry.actions.length) : 0
                            delegate: Rectangle {
                                width: actionText.implicitWidth + 14
                                height: 22
                                radius: 11
                                color: actionMa.containsMouse
                                    ? ColorScheme.accent
                                    : ColorScheme.withAlpha(ColorScheme.surface, 0.45)
                                border.color: ColorScheme.withAlpha(ColorScheme.accent, 0.25)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: actionText
                                    anchors.centerIn: parent
                                    text: {
                                        if (!entry || !entry.actions || entry.actions.length <= index) return "Action";
                                        return entry.actions[index].text || entry.actions[index].identifier || "Action";
                                    }
                                    color: actionMa.containsMouse ? ColorScheme.background : ColorScheme.accent
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.family: DesignTokens.fontFamilyUI
                                }

                                MouseArea {
                                    id: actionMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!entry || !entry.actions || entry.actions.length <= index) return;
                                        var action = entry.actions[index];
                                        if (action && action.invoke) action.invoke();
                                        root._markRead(entry);
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: dismissAppText.implicitWidth + 14
                            height: 22
                            radius: 11
                            color: dismissAppMa.containsMouse
                                ? ColorScheme.red
                                : ColorScheme.withAlpha(ColorScheme.red, 0.12)
                            border.color: ColorScheme.withAlpha(ColorScheme.red, 0.25)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                id: dismissAppText
                                anchors.centerIn: parent
                                text: "Dispensar app"
                                color: dismissAppMa.containsMouse ? ColorScheme.background : ColorScheme.red
                                font.pixelSize: 9
                                font.bold: true
                                font.family: DesignTokens.fontFamilyUI
                            }
                            MouseArea {
                                id: dismissAppMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root._dismissApp(entry)
                            }
                        }
                    }
                }
            }

            Item {
                id: closeBtn
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 8
                width: 24
                height: 24
                z: 6
                opacity: itemMouse.containsMouse ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: closeMa.containsMouse
                        ? ColorScheme.withAlpha(ColorScheme.red, 0.2)
                        : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "\u{f00d}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.7)
                    }
                }

                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    acceptedButtons: Qt.LeftButton
                    onPressed: function(mouse) { mouse.accepted = true; }
                    onClicked: root._dismiss(entry)
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 8
        visible: rowsModel.count === 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.muted ? "\u{f1f6}" : "\u{f0f3}"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 28
            color: ColorScheme.withAlpha(ColorScheme.text, 0.2)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.muted ? "Do Not Disturb" : "Sem notificações"
            color: ColorScheme.withAlpha(ColorScheme.text, 0.35)
            font.pixelSize: 11
            font.family: DesignTokens.fontFamilyUI
        }
    }
}
