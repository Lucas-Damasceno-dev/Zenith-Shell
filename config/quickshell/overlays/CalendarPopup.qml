import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import "../core"
import "../services"
import "./ProductivityCalendarUtils.js" as ProductivityCalendarUtils

/**
 * CalendarPopup - Advanced productivity hub with calendar, to-do, pomodoro, and notes.
 */
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
    originX: 0.5

    property color accentColor: ColorScheme.accent
    property color bgColor: ColorScheme.withAlpha(ColorScheme.background, 0.72)
    property color textColor: ColorScheme.text
    property real popupMargin: DesignTokens.spacingLG
    readonly property int monthViewMinWidth: 320
    readonly property int weekViewMinWidth: 540
    readonly property int notesViewMinWidth: 360
    readonly property int calendarContentMinWidth: activeTab === 0
        ? (calendarView === "week" ? weekViewMinWidth : monthViewMinWidth)
        : (activeTab === 4 ? notesViewMinWidth : monthViewMinWidth)

    // Current display month/year
    property int displayMonth: new Date().getMonth()
    property int displayYear: new Date().getFullYear()
    
    // Week view: start date (Sunday of the displayed week)
    property date weekStartDate: getWeekStart(new Date())

    // Active tab: 0=Calendar, 1=To-Do, 2=Stopwatch, 3=Pomodoro, 4=Notes
    property int activeTab: 0
    onActiveTabChanged: if (activeTab === 4) resetNotesState()
    onIsOpenChanged: if (isOpen && activeTab === 4) resetNotesState()
    
    // Calendar view mode: "month" or "week"
    property string calendarView: "month"
    property string selectedDateKey: formatDateKey(new Date())
    property int selectedHour: -1

    // Month transition animation state
    property real _calendarGridOpacity: 1.0
    property int _nextMonth: -1
    property int _nextYear: -1

    // Stopwatch state
    property real swElapsed: 0
    property bool swRunning: false

    // Timer state
    property int timerDuration: 300  // seconds
    property real timerRemaining: 300
    property bool timerRunning: false
    
    // Pomodoro state
    property bool pomodoroMode: false
    property int pomodoroWorkMinutes: 25
    property int pomodoroBreakMinutes: 5
    property int pomodoroLongBreakMinutes: 15
    property int pomodoroSessionsBeforeLongBreak: 4
    property int pomodoroCurrentSession: 0
    property bool pomodoroIsBreak: false
    property int pomodoroCompletedSessions: 0

    readonly property var todoModel: ProductivityService.todoModel
    readonly property var eventsModel: ProductivityService.eventsModel
    property var quickNotesPopup: null
    readonly property var noteColors: [
        { id: "default", color: ColorScheme.glassCard },
        { id: "red", color: "#e74c3c" },
        { id: "orange", color: "#e67e22" },
        { id: "yellow", color: "#f1c40f" },
        { id: "green", color: "#2ecc71" },
        { id: "blue", color: "#3498db" },
        { id: "purple", color: "#9b59b6" }
    ]

    property string editingNoteId: ""
    property string editingText: ""
    property string selectedColor: "default"
    property int dragFromIndex: -1
    property int dragToIndex: -1

    function openDedicatedNotesPopup() {
        if (!root.quickNotesPopup)
            return;
        ShellController.openPopup(root, root.quickNotesPopup);
    }
    
    // Helper functions
    function getWeekStart(date) {
        return ProductivityCalendarUtils.getWeekStart(date);
    }
    
    function formatDateKey(date) {
        return ProductivityCalendarUtils.formatDateKey(date);
    }
    
    function getEventsForDate(dateKey) {
        var events = [];
        for (var i = 0; i < eventsModel.count; i++) {
            var ev = eventsModel.get(i);
            if (ev.date === dateKey) {
                events.push(ev);
            }
        }
        return events;
    }
    
    function getTodosForDate(dateKey) {
        var _rev = ProductivityService.todoRevision;
        var todos = [];
        var today = formatDateKey(new Date());
        for (var i = 0; i < todoModel.count; i++) {
            var todo = todoModel.get(i);
            var todoDate = String(todo.date || "");
            if (todoDate === dateKey || (!todoDate && dateKey === today)) {
                todos.push({ index: i, id: todo.id || String(i), text: todo.text || todo.task || "", task: todo.task || todo.text || "", done: todo.done, date: todo.date, time: todo.time || "", pomodoros: todo.pomodoros || 0, isPriority: todo.isPriority || false });
            }
        }
        return todos;
    }

    function parseHourValue(timeText) {
        return ProductivityCalendarUtils.parseHourValue(timeText);
    }

    function timeSortValue(timeText) {
        return ProductivityCalendarUtils.timeSortValue(timeText);
    }

    function currentSelectionDateKey() {
        return selectedDateKey && selectedDateKey !== "" ? selectedDateKey : formatDateKey(new Date());
    }

    function selectedHourLabel() {
        return selectedHour >= 0 ? String(selectedHour).padStart(2, "0") + ":00" : "Dia inteiro";
    }

    function selectionTimeValue() {
        return selectedHour >= 0 ? String(selectedHour).padStart(2, "0") + ":00" : "";
    }

    function selectedDateLabel() {
        return ProductivityCalendarUtils.selectedDateLabel(currentSelectionDateKey());
    }

    function todoMatchesSelection(todo) {
        var item = todo || {};
        var todoDate = String(item.date || "");
        var today = formatDateKey(new Date());
        var wantedDate = currentSelectionDateKey();
        if ((todoDate === "" ? today : todoDate) !== wantedDate)
            return false;
        if (selectedHour < 0)
            return true;
        var todoHour = parseHourValue(item.time || "");
        if (todoHour < 0) return selectedHour === 9;
        return todoHour === selectedHour;
    }

    function getTodosForSelection() {
        var _rev = ProductivityService.todoRevision;
        var selected = [];
        for (var i = 0; i < todoModel.count; i++) {
            var todo = todoModel.get(i);
            if (!todoMatchesSelection(todo))
                continue;
            selected.push({
                id: todo.id || String(i),
                text: todo.text || todo.task || "",
                task: todo.task || todo.text || "",
                done: todo.done === true,
                date: todo.date || "",
                time: todo.time || "",
                pomodoros: todo.pomodoros || 0,
                isPriority: todo.isPriority === true
            });
        }
        selected.sort(function(a, b) {
            if (a.done !== b.done) return a.done ? 1 : -1;
            var ta = timeSortValue(a.time);
            var tb = timeSortValue(b.time);
            if (ta !== tb) return ta - tb;
            var an = String(a.text || a.task || "");
            var bn = String(b.text || b.task || "");
            return an.localeCompare(bn);
        });
        return selected;
    }

    function addTodoForSelection(text) {
        var value = String(text || "").trim();
        if (value === "") return false;
        ProductivityService.addTodo({
            text: value,
            done: false,
            date: currentSelectionDateKey(),
            time: selectionTimeValue(),
            pomodoros: 0,
            isPriority: false
        });
        return true;
    }

    function saveTodo() { ProductivityService.saveTodo(); }
    function saveEvents() { ProductivityService.saveEvents(); }

    function daysInMonth(month, year) { return ProductivityCalendarUtils.daysInMonth(month, year); }
    function firstDayOfWeek(month, year) { return ProductivityCalendarUtils.firstDayOfWeek(month, year); }
    function monthName(month) {
        return ProductivityCalendarUtils.monthName(month);
    }
    function shortMonthName(month) {
        return ProductivityCalendarUtils.shortMonthName(month);
    }
    function getWeekHeaderText() {
        return ProductivityCalendarUtils.getWeekHeaderText(weekStartDate);
    }
    function dayName(dayIndex) {
        return ProductivityCalendarUtils.dayName(dayIndex);
    }
    function isToday(day) {
        return ProductivityCalendarUtils.isToday(day, displayMonth, displayYear);
    }
    function isTodayDate(date) {
        return ProductivityCalendarUtils.isTodayDate(date);
    }
    function prevMonth() {
        if (monthTransition.running) return;
        var prev = ProductivityCalendarUtils.previousMonth(displayMonth, displayYear);
        _nextMonth = prev.month;
        _nextYear = prev.year;
        monthTransition.start();
    }
    function nextMonth() {
        if (monthTransition.running) return;
        var next = ProductivityCalendarUtils.nextMonth(displayMonth, displayYear);
        _nextMonth = next.month;
        _nextYear = next.year;
        monthTransition.start();
    }
    function prevWeek() {
        weekStartDate = ProductivityCalendarUtils.shiftWeek(weekStartDate, -7);
    }
    function nextWeek() {
        weekStartDate = ProductivityCalendarUtils.shiftWeek(weekStartDate, 7);
    }
    function formatTime(secs) {
        return ProductivityCalendarUtils.formatStopwatchTime(secs);
    }
    function formatTimerTime(secs) {
        return ProductivityCalendarUtils.formatTimerTime(secs);
    }
    
    // Pomodoro functions
    function startPomodoro() {
        pomodoroMode = true;
        pomodoroIsBreak = false;
        pomodoroCurrentSession = 1;
        timerDuration = pomodoroWorkMinutes * 60;
        timerRemaining = timerDuration;
        timerRunning = true;
        ProductivityService.pomodoroRunning = true;
        ProductivityService.pomodoroIsBreak = false;
        ProductivityService.timerRemaining = timerRemaining;
    }
    
    function handlePomodoroComplete() {
        timerRunning = false;
        
        // Play notification sound
        pomodoroNotifyProc.exec(["bash", "-c", "canberra-gtk-play -i complete 2>/dev/null || paplay $(find /run/current-system/sw/share/sounds /usr/share/sounds -name complete.oga 2>/dev/null | head -n1) 2>/dev/null || true"]);
        
        if (pomodoroIsBreak) {
            // Break finished, start next work session
            pomodoroIsBreak = false;
            pomodoroCurrentSession++;
            timerDuration = pomodoroWorkMinutes * 60;
            timerRemaining = timerDuration;
            ProductivityService.pomodoroIsBreak = false;
            ProductivityService.timerRemaining = timerRemaining;
        } else {
            // Work session finished
            pomodoroCompletedSessions++;
            pomodoroIsBreak = true;
            ProductivityService.recordPomodoroSession();
            ProductivityService.pomodoroRunning = true;
            
            if (pomodoroCompletedSessions % pomodoroSessionsBeforeLongBreak === 0) {
                // Long break
                timerDuration = pomodoroLongBreakMinutes * 60;
            } else {
                // Short break
                timerDuration = pomodoroBreakMinutes * 60;
            }
            timerRemaining = timerDuration;
            ProductivityService.pomodoroIsBreak = true;
            ProductivityService.timerRemaining = timerRemaining;
        }
    }
    
    function stopPomodoro() {
        pomodoroMode = false;
        timerRunning = false;
        timerRemaining = timerDuration;
        ProductivityService.pomodoroRunning = false;
        ProductivityService.pomodoroIsBreak = false;
        ProductivityService.timerRemaining = timerRemaining;
    }

    function getNoteColor(colorId) {
        return ProductivityCalendarUtils.resolveNoteColor(noteColors, colorId, ColorScheme.glassCard);
    }

    function copyToClipboard(text) {
        notesCopyProc.exec(["bash", "-c", "printf '%s' \"$1\" | wl-copy", "--", text]);
    }

    function startEditing(noteId, noteText) {
        editingNoteId = noteId;
        editingText = noteText;
    }

    function saveEditing() {
        if (editingNoteId && editingText.trim()) {
            QuickNotesService.updateNote(editingNoteId, editingText.trim());
        }
        editingNoteId = "";
        editingText = "";
    }

    function cancelEditing() {
        editingNoteId = "";
        editingText = "";
    }

    function resetNotesState() {
        editingNoteId = "";
        editingText = "";
        selectedColor = "default";
        dragFromIndex = -1;
        dragToIndex = -1;
    }

    TimedProcess { id: pomodoroNotifyProc }
    TimedProcess {
        id: notesCopyProc
        timeoutMs: 2000
        timeoutLabel: "CopyNote"
    }

    Timer {
        interval: 500; repeat: true
        running: root.swRunning
        onTriggered: root.swElapsed += 0.5
    }

    Timer {
        interval: 500; repeat: true
        running: root.timerRunning && root.timerRemaining > 0
        onTriggered: {
            root.timerRemaining = Math.max(0, root.timerRemaining - 0.5);
            ProductivityService.timerRemaining = root.timerRemaining;
            if (root.timerRemaining <= 0) {
                if (root.pomodoroMode) {
                    root.handlePomodoroComplete();
                } else {
                    root.timerRunning = false;
                    ProductivityService.pomodoroRunning = false;
                }
            }
        }
    }

    SequentialAnimation {
        id: monthTransition
        NumberAnimation { target: root; property: "_calendarGridOpacity"; to: 0.0; duration: 100; easing.type: Easing.OutQuad }
        ScriptAction { script: { root.displayMonth = root._nextMonth; root.displayYear = root._nextYear; } }
        NumberAnimation { target: root; property: "_calendarGridOpacity"; to: 1.0; duration: 150; easing.type: Easing.InOutQuad }
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: (mouse) => {
            var p = mapToItem(container, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > container.width || p.y > container.height) {
                root.isOpen = false;
            }
        }
    }

    Item {
        id: container
        readonly property int chromePadding: 36
        readonly property real maxContainerHeight: Math.max(260, root.height - popupTopMargin - root.popupMargin)
        width: Math.max(root.calendarContentMinWidth, contentLayout.implicitWidth + chromePadding)
        height: Math.min(contentLayout.implicitHeight + chromePadding, maxContainerHeight)
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
        
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        scale: root.isOpen ? 1.0 : 0.92
        opacity: root.isOpen ? 1.0 : 0.0
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.48; epsilon: 0.005 } }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        transformOrigin: Item.Top

        Rectangle {
            id: calCard
            anchors.fill: parent
            color: root.bgColor
            radius: 18
            border.color: ColorScheme.glassBorder
            border.width: 1

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1; radius: 18
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }

        // Lightweight shadow
        Rectangle {
            anchors.fill: calCard
            anchors.topMargin: 6
            radius: calCard.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: -1
        }

        ScrollView {
            id: contentScroll
            anchors.fill: parent
            anchors.margins: 18
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: contentLayout.implicitHeight > height
                ? ScrollBar.AsNeeded
                : ScrollBar.AlwaysOff

            ColumnLayout {
                id: contentLayout
                width: contentScroll.availableWidth
                spacing: 12

            // Tab bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        { label: "Calendar", idx: 0 },
                        { label: "To-Do", idx: 1 },
                        { label: "Stopwatch", idx: 2 },
                        { label: "Pomodoro", idx: 3 },
                        { label: "Notes", idx: 4 }
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 26
                        radius: 13
                        color: root.activeTab === modelData.idx
                            ? ColorScheme.withAlpha(root.accentColor, 0.22)
                            : (tabMa.containsMouse ? ColorScheme.glassHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.activeTab === modelData.idx
                                ? root.accentColor
                                : ColorScheme.withAlpha(root.textColor, 0.55)
                            font.pixelSize: 10
                            font.bold: root.activeTab === modelData.idx
                            font.family: "Inter"
                        }

                        MouseArea {
                            id: tabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTab = modelData.idx
                        }
                    }
                }
            }

            // ═══ Calendar Tab ═══
            ColumnLayout {
                visible: root.activeTab === 0
                Layout.fillWidth: true
                spacing: 10

                // View switcher + Month navigation
                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: root.calendarContentMinWidth - 36
                    spacing: 8
                    
                    // View toggle (Month/Week)
                    Rectangle {
                        width: 70
                        height: 24
                        radius: 12
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.3)
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 2
                            spacing: 0
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: calendarView === "month" ? ColorScheme.withAlpha(root.accentColor, 0.3) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "M"
                                    color: calendarView === "month" ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.5)
                                    font.pixelSize: 9
                                    font.bold: calendarView === "month"
                                    font.family: "Inter"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarView = "month"
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: calendarView === "week" ? ColorScheme.withAlpha(root.accentColor, 0.3) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "W"
                                    color: calendarView === "week" ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.5)
                                    font.pixelSize: 9
                                    font.bold: calendarView === "week"
                                    font.family: "Inter"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarView = "week"
                                }
                            }
                        }
                    }
                    
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: prevMa.containsMouse ? ColorScheme.glassHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "\u{f053}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: root.textColor; opacity: 0.5
                        }
                        MouseArea {
                            id: prevMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: calendarView === "month" ? root.prevMonth() : root.prevWeek()
                        }
                    }

                    Text {
                        text: calendarView === "month" 
                            ? root.monthName(root.displayMonth) + " " + root.displayYear
                            : root.getWeekHeaderText()
                        color: root.accentColor
                        font.pixelSize: 13; font.bold: true; font.family: "Inter"
                        opacity: root._calendarGridOpacity
                        Behavior on opacity { NumberAnimation { duration: 80 } }
                    }

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: nextMa.containsMouse ? ColorScheme.glassHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "\u{f054}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: root.textColor; opacity: 0.5
                        }
                        MouseArea {
                            id: nextMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: calendarView === "month" ? root.nextMonth() : root.nextWeek()
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Today button
                    Rectangle {
                        width: 50; height: 24; radius: 12
                        color: todayBtnMa.containsMouse ? ColorScheme.withAlpha(root.accentColor, 0.25) : ColorScheme.withAlpha(root.accentColor, 0.15)
                        Text {
                            anchors.centerIn: parent
                            text: "Hoje"
                            color: root.accentColor
                            font.pixelSize: 9; font.bold: true; font.family: "Inter"
                        }
                        MouseArea {
                            id: todayBtnMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var now = new Date();
                                root.selectedDateKey = formatDateKey(now);
                                root.selectedHour = -1;
                                if (calendarView === "month") {
                                    if (monthTransition.running) return;
                                    root._nextMonth = now.getMonth();
                                    root._nextYear = now.getFullYear();
                                    monthTransition.start();
                                } else {
                                    weekStartDate = getWeekStart(now);
                                }
                            }
                        }
                    }
                }

                // ═══ Month View ═══
                ColumnLayout {
                    visible: calendarView === "month"
                    Layout.fillWidth: true
                    Layout.minimumWidth: root.monthViewMinWidth - 36
                    spacing: 8

                    // Day-of-week headers
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Repeater {
                            model: ["D", "S", "T", "Q", "Q", "S", "S"]
                            delegate: Text {
                                text: modelData
                                color: root.accentColor
                                font.bold: true; font.pixelSize: 10; font.family: "Inter"
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                opacity: 0.45
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 1
                        color: ColorScheme.withAlpha(root.accentColor, 0.08)
                    }

                    // Day grid
                    GridLayout {
                        columns: 7; rowSpacing: 3; columnSpacing: 3
                        Layout.fillWidth: true
                        opacity: root._calendarGridOpacity

                        Repeater {
                            model: 42
                            delegate: Item {
                                width: 32; height: 32
                                Layout.fillWidth: true

                                property int dayNumber: {
                                    var offset = root.firstDayOfWeek(root.displayMonth, root.displayYear);
                                    var day = index - offset + 1;
                                    var maxDays = root.daysInMonth(root.displayMonth, root.displayYear);
                                    return (day >= 1 && day <= maxDays) ? day : 0;
                                }
                                
                                property string dateKey: dayNumber > 0 
                                    ? root.displayYear + "-" + String(root.displayMonth + 1).padStart(2, '0') + "-" + String(dayNumber).padStart(2, '0')
                                    : ""
                                property bool isSelectedDay: dateKey !== "" && dateKey === root.currentSelectionDateKey()
                                property var dayTodos: dateKey !== "" ? root.getTodosForDate(dateKey) : []
                                property bool hasTodos: dayTodos.length > 0

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 30; height: 30; radius: 15
                                    color: {
                                        if (dayNumber === 0) return "transparent";
                                        if (root.isToday(dayNumber)) return root.accentColor;
                                        if (isSelectedDay) return ColorScheme.withAlpha(root.accentColor, 0.22);
                                        if (dayCalMa.containsMouse) return ColorScheme.glassHover;
                                        return "transparent";
                                    }
                                    border.color: root.isToday(dayNumber)
                                        ? ColorScheme.withAlpha(root.accentColor, 0.35)
                                        : (isSelectedDay ? ColorScheme.withAlpha(root.accentColor, 0.45) : "transparent")
                                    border.width: root.isToday(dayNumber) ? 2.5 : (isSelectedDay ? 1.2 : 0)
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: dayNumber > 0 ? dayNumber : ""
                                    color: {
                                        if (dayNumber === 0) return "transparent";
                                        if (root.isToday(dayNumber)) return ColorScheme.onPrimary;
                                        if (isSelectedDay) return root.accentColor;
                                        if (index % 7 === 0 || index % 7 === 6) return ColorScheme.withAlpha(ColorScheme.foreground, 0.5);
                                        return root.textColor;
                                    }
                                    font.bold: root.isToday(dayNumber)
                                    font.pixelSize: 11; font.family: "Inter"
                                    opacity: root.isToday(dayNumber) ? 1.0 : 0.72
                                }
                                
                                // Todo indicator dot
                                Rectangle {
                                    visible: hasTodos
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: 2
                                    width: 4; height: 4; radius: 2
                                    color: root.isToday(dayNumber) ? ColorScheme.onPrimary : ColorScheme.blue
                                }

                                MouseArea {
                                    id: dayCalMa; anchors.fill: parent
                                    hoverEnabled: true; visible: dayNumber > 0
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // Switch to week view centered on this day
                                        var clickedDate = new Date(root.displayYear, root.displayMonth, dayNumber);
                                        root.selectedDateKey = dateKey;
                                        root.selectedHour = -1;
                                        weekStartDate = getWeekStart(clickedDate);
                                        calendarView = "week";
                                    }
                                }
                            }
                        }
                    }
                }

                // ═══ Week View with Time Slots ═══
                ColumnLayout {
                    visible: calendarView === "week"
                    Layout.fillWidth: true
                    Layout.minimumWidth: root.weekViewMinWidth - 36
                    spacing: 6

                    // Day headers
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        // Time column spacer
                        Item { width: 35 }
                        
                        Repeater {
                            model: 7
                            delegate: Item {
                                Layout.fillWidth: true
                                height: 36
                                
                                property date dayDate: {
                                    var d = new Date(weekStartDate);
                                    d.setDate(d.getDate() + index);
                                    return d;
                                }
                                property string dayDateKey: formatDateKey(dayDate)
                                property bool isCurrentDay: isTodayDate(dayDate)
                                property bool isSelectedDay: dayDateKey === root.currentSelectionDateKey()
                                
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: 8
                                    color: isCurrentDay
                                        ? ColorScheme.withAlpha(root.accentColor, 0.2)
                                        : (isSelectedDay ? ColorScheme.withAlpha(root.accentColor, 0.12) : "transparent")
                                }
                                
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: dayName(index)
                                        color: isCurrentDay ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.5)
                                        font.pixelSize: 9
                                        font.family: "Inter"
                                        font.bold: isCurrentDay
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: dayDate.getDate()
                                        color: (isCurrentDay || isSelectedDay) ? root.accentColor : root.textColor
                                        font.pixelSize: 13
                                        font.family: "Inter"
                                        font.bold: isCurrentDay || isSelectedDay
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedDateKey = dayDateKey;
                                        root.selectedHour = -1;
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 1
                        color: ColorScheme.withAlpha(root.accentColor, 0.08)
                    }

                    // Time slots grid (scrollable)
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        
                        ColumnLayout {
                            width: parent.width
                            spacing: 0
                            
                            Repeater {
                                model: 24  // 24 hours
                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    height: 28
                                    
                                    // Hour label
                                    Text {
                                        Layout.preferredWidth: 35
                                        text: String(index).padStart(2, '0') + ":00"
                                        color: ColorScheme.withAlpha(root.textColor, 0.4)
                                        font.pixelSize: 8
                                        font.family: DesignTokens.fontFamilyMono
                                        horizontalAlignment: Text.AlignRight
                                        rightPadding: 4
                                    }
                                    
                                    // Day cells for this hour
                                    Repeater {
                                        model: 7
                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            
                                            property date cellDate: {
                                                var d = new Date(weekStartDate);
                                                d.setDate(d.getDate() + index);
                                                return d;
                                            }
                                            property string dateKey: formatDateKey(cellDate)
                                            property int hourIndex: parent.parent.index || 0
                                            property bool isSelectedSlot: root.currentSelectionDateKey() === dateKey && root.selectedHour === hourIndex
                                            property var cellTodos: {
                                                var todos = getTodosForDate(dateKey);
                                                return todos.filter(function(t) {
                                                    if (!t.time) return hourIndex === 9; // Default to 9 AM
                                                    var h = parseInt(t.time.split(":")[0]);
                                                    return h === hourIndex;
                                                });
                                            }
                                            property bool isCurrentHour: isTodayDate(cellDate) && new Date().getHours() === hourIndex
                                            
                                            color: {
                                                if (isSelectedSlot) return ColorScheme.withAlpha(root.accentColor, 0.22);
                                                if (isCurrentHour) return ColorScheme.withAlpha(root.accentColor, 0.08);
                                                if (cellSlotMa.containsMouse) return ColorScheme.withAlpha(ColorScheme.surface, 0.3);
                                                return ColorScheme.withAlpha(ColorScheme.surface, 0.1);
                                            }
                                            border.color: ColorScheme.withAlpha(root.textColor, 0.05)
                                            border.width: 1
                                            radius: 3
                                            
                                            // Show todo if exists
                                            Text {
                                                anchors.fill: parent
                                                anchors.margins: 2
                                                text: cellTodos.length > 0 ? (cellTodos[0].text || cellTodos[0].task || "") : ""
                                                color: cellTodos.length > 0 && cellTodos[0].done ? ColorScheme.withAlpha(root.textColor, 0.4) : root.textColor
                                                font.pixelSize: 7
                                                font.family: "Inter"
                                                font.strikeout: cellTodos.length > 0 && cellTodos[0].done
                                                elide: Text.ElideRight
                                                wrapMode: Text.NoWrap
                                            }
                                            
                                            // Multiple todos indicator
                                            Rectangle {
                                                visible: cellTodos.length > 1
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                anchors.margins: 1
                                                width: 10; height: 10; radius: 5
                                                color: ColorScheme.blue
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "+" + (cellTodos.length - 1)
                                                    color: "white"
                                                    font.pixelSize: 6
                                                    font.bold: true
                                                }
                                            }
                                            
                                            MouseArea {
                                                id: cellSlotMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.selectedDateKey = dateKey;
                                                    root.selectedHour = hourIndex;
                                                    if (calendarTodoInput.visible)
                                                        calendarTodoInput.forceActiveFocus();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: root.calendarContentMinWidth - 36
                    radius: 10
                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.16)
                    border.color: ColorScheme.withAlpha(root.textColor, 0.08)
                    border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "To-Do • " + root.selectedDateLabel() + " • " + root.selectedHourLabel()
                                color: root.textColor
                                font.pixelSize: 10
                                font.bold: true
                                font.family: "Inter"
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: root.getTodosForSelection().length + " itens"
                                color: ColorScheme.withAlpha(root.textColor, 0.45)
                                font.pixelSize: 9
                                font.family: "Inter"
                            }

                            Rectangle {
                                visible: root.selectedHour >= 0
                                width: 74
                                height: 20
                                radius: 10
                                color: clearHourMa.containsMouse ? ColorScheme.withAlpha(root.accentColor, 0.2) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Sem horário"
                                    color: root.accentColor
                                    font.pixelSize: 8
                                    font.family: "Inter"
                                    font.bold: true
                                }

                                MouseArea {
                                    id: clearHourMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedHour = -1
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            clip: true

                            TextField {
                                id: calendarTodoInput
                                Layout.fillWidth: true
                                placeholderText: "Adicionar tarefa para a seleção..."
                                color: root.textColor
                                font.pixelSize: 11
                                font.family: "Inter"
                                placeholderTextColor: ColorScheme.withAlpha(root.textColor, 0.4)
                                background: Rectangle {
                                    radius: 8
                                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.35)
                                    border.color: ColorScheme.withAlpha(root.textColor, 0.15)
                                }
                                onAccepted: {
                                    if (root.addTodoForSelection(text))
                                        text = "";
                                }
                            }

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 8
                                color: ColorScheme.withAlpha(root.accentColor, 0.2)
                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: root.accentColor
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.family: "Inter"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.addTodoForSelection(calendarTodoInput.text))
                                            calendarTodoInput.text = "";
                                    }
                                }
                            }
                        }

                        ListView {
                            id: selectionTodoList
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(72, Math.min(contentHeight, 140))
                            clip: true
                            spacing: 4
                            model: root.getTodosForSelection()

                            delegate: Rectangle {
                                required property var modelData

                                width: selectionTodoList.width
                                height: 32
                                radius: 6
                                color: ColorScheme.withAlpha(ColorScheme.surface, 0.28)
                                opacity: modelData.done ? DesignTokens.mutedOpacity : 1.0

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: 4
                                        color: modelData.done ? ColorScheme.withAlpha(ColorScheme.green, 0.35) : "transparent"
                                        border.color: modelData.done ? ColorScheme.green : ColorScheme.withAlpha(root.textColor, 0.4)
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            visible: modelData.done
                                            text: "\u{f00c}"
                                            color: ColorScheme.green
                                            font.pixelSize: 9
                                            font.family: "JetBrainsMono Nerd Font"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: ProductivityService.setTodoDone(modelData.id, !modelData.done)
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        Text {
                                            text: modelData.text || modelData.task
                                            Layout.fillWidth: true
                                            color: modelData.done ? ColorScheme.withAlpha(root.textColor, 0.4) : root.textColor
                                            font.pixelSize: 10
                                            font.family: "Inter"
                                            font.strikeout: modelData.done
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: modelData.time ? modelData.time : "Dia inteiro"
                                            color: ColorScheme.withAlpha(root.textColor, 0.35)
                                            font.pixelSize: 8
                                            font.family: "Inter"
                                        }
                                    }

                                    Text {
                                        text: "\u{f005}"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: modelData.isPriority ? "#f1c40f" : ColorScheme.withAlpha(root.textColor, 0.35)
                                        opacity: priorityToggleMa.containsMouse ? 1.0 : 0.7

                                        MouseArea {
                                            id: priorityToggleMa
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: ProductivityService.setTodoPriority(modelData.id, !modelData.isPriority)
                                        }
                                    }

                                    Text {
                                        text: "\u{f00d}"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                        color: ColorScheme.red
                                        opacity: deleteSelectionTodoMa.containsMouse ? 1.0 : 0.6

                                        MouseArea {
                                            id: deleteSelectionTodoMa
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: ProductivityService.removeTodo(modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: selectionTodoList.count === 0
                            text: "Sem tarefas para este recorte. Clique no horário e adicione acima."
                            color: ColorScheme.withAlpha(root.textColor, 0.45)
                            font.pixelSize: 9
                            font.family: "Inter"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // ═══ To-Do Tab ═══
            ColumnLayout {
                visible: root.activeTab === 1
                Layout.fillWidth: true
                Layout.preferredHeight: 280
                spacing: 10
                Layout.topMargin: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    
                    TextField {
                        id: todoInput
                        Layout.fillWidth: true
                        placeholderText: "Nova tarefa..."
                        color: root.textColor
                        font.pixelSize: 11
                        font.family: "Inter"
                        placeholderTextColor: ColorScheme.withAlpha(root.textColor, 0.4)
                                background: Rectangle {
                                    radius: 8
                                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.28)
                                    border.color: ColorScheme.withAlpha(root.textColor, 0.12)
                                }
                        onAccepted: {
                            if (root.addTodoForSelection(text)) {
                                text = "";
                            }
                        }
                    }

                    Rectangle {
                        width: 32; height: 32; radius: 8
                        color: ColorScheme.withAlpha(root.accentColor, 0.2)
                        Text { anchors.centerIn: parent; text: "+"; color: root.accentColor; font.pixelSize: 14; font.bold: true; font.family: "Inter" }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.addTodoForSelection(todoInput.text)) {
                                    todoInput.text = "";
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    clip: true

                    Text {
                        text: "Agenda ativa: " + root.selectedDateLabel() + " • " + root.selectedHourLabel()
                        color: ColorScheme.withAlpha(root.textColor, 0.45)
                        font.pixelSize: 9
                        font.family: "Inter"
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Hoje"
                        color: root.accentColor
                        font.pixelSize: 9
                        font.family: "Inter"
                        opacity: todayFilterMa.containsMouse ? 1.0 : 0.7

                        MouseArea {
                            id: todayFilterMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedDateKey = formatDateKey(new Date());
                                root.selectedHour = -1;
                            }
                        }
                    }
                }

                // Todo stats
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Text {
                        text: ProductivityService.completedTodoCount + "/" + ProductivityService.todoCount + " concluídas"
                        color: ColorScheme.withAlpha(root.textColor, 0.5)
                        font.pixelSize: 9
                        font.family: "Inter"
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Clear completed button
                    Rectangle {
                        visible: ProductivityService.completedTodoCount > 0
                        width: 80; height: 20; radius: 10
                        color: clearCompletedMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.red, 0.2) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "Limpar feitas"
                            color: ColorScheme.red
                            font.pixelSize: 8
                            font.family: "Inter"
                        }
                        MouseArea {
                            id: clearCompletedMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                for (var i = todoModel.count - 1; i >= 0; i--) {
                                    if (todoModel.get(i).done) {
                                        ProductivityService.removeTodo(i.toString());
                                    }
                                }
                            }
                        }
                    }
                }

                ListView {
                    id: todoList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: todoModel
                    spacing: 6
                    clip: true
                    
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 36
                        radius: 8
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.2)
                        opacity: model.done ? DesignTokens.mutedOpacity : 1.0
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8
                            
                            Rectangle {
                                width: 18; height: 18; radius: 4
                                color: model.done ? ColorScheme.withAlpha(ColorScheme.green, 0.4) : "transparent"
                                border.color: model.done ? ColorScheme.green : ColorScheme.withAlpha(root.textColor, 0.4)
                                border.width: 1
                                Text { anchors.centerIn: parent; visible: model.done; text: "\u{f00c}"; color: ColorScheme.green; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ProductivityService.setTodoDone(model.id || index.toString(), !model.done);
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                
                                Text {
                                    text: model.text || model.task
                                    Layout.fillWidth: true
                                    color: model.done ? ColorScheme.withAlpha(root.textColor, 0.4) : root.textColor
                                    font.pixelSize: 11
                                    font.family: "Inter"
                                    font.strikeout: model.done
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    visible: model.date || model.time
                                    text: (model.date || "") + (model.time ? " " + model.time : "")
                                    color: ColorScheme.withAlpha(root.textColor, 0.35)
                                    font.pixelSize: 8
                                    font.family: "Inter"
                                }
                            }

                            Text {
                                text: "\u{f005}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: model.isPriority ? "#f1c40f" : ColorScheme.withAlpha(root.textColor, 0.35)
                                opacity: priorityMa.containsMouse ? 1.0 : 0.7

                                MouseArea {
                                    id: priorityMa
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ProductivityService.setTodoPriority(model.id || index.toString(), !model.isPriority)
                                }
                            }

                            Text {
                                text: "\u{f017}"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: ColorScheme.withAlpha(root.accentColor, 0.9)
                                opacity: scheduleMa.containsMouse ? 1.0 : 0.65

                                MouseArea {
                                    id: scheduleMa
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ProductivityService.setTodoSchedule(
                                        model.id || index.toString(),
                                        root.currentSelectionDateKey(),
                                        root.selectionTimeValue()
                                    )
                                }
                            }
                             
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: "transparent"
                                Text { anchors.centerIn: parent; text: "\u{f00d}"; color: ColorScheme.red; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; opacity: 0.6 }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ProductivityService.removeTodo(model.id || index.toString());
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═══ Stopwatch Tab ═══
            ColumnLayout {
                visible: root.activeTab === 2
                Layout.alignment: Qt.AlignHCenter
                spacing: 16
                Layout.topMargin: 20

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.formatTime(root.swElapsed)
                    color: root.textColor
                    font.pixelSize: 36
                    font.weight: Font.Light
                    font.family: DesignTokens.fontFamilyMono
                    font.letterSpacing: DesignTokens.letterSpacingTimer
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    Rectangle {
                        width: 70; height: 32; radius: 16
                        color: swResetMa.containsMouse
                            ? ColorScheme.withAlpha(ColorScheme.surface, 0.5)
                            : ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent; text: "Reset"
                            color: ColorScheme.withAlpha(root.textColor, 0.7)
                            font.pixelSize: 11; font.family: "Inter"
                        }
                        MouseArea {
                            id: swResetMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.swRunning = false; root.swElapsed = 0; }
                        }
                    }

                    Rectangle {
                        width: 90; height: 36; radius: 18
                        color: root.swRunning
                            ? ColorScheme.withAlpha(ColorScheme.red, 0.22)
                            : ColorScheme.withAlpha(root.accentColor, 0.22)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        scale: swStartMa.pressed ? 0.93 : 1.0
                        Behavior on scale { SpringAnimation { spring: 5; damping: 0.5; epsilon: 0.02 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.swRunning ? "Stop" : "Start"
                            color: root.swRunning ? ColorScheme.red : root.accentColor
                            font.pixelSize: 12; font.bold: true; font.family: "Inter"
                        }
                        MouseArea {
                            id: swStartMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.swRunning = !root.swRunning
                        }
                    }
                }

                Item { height: 20 }
            }

            // ═══ Pomodoro Tab ═══
            ColumnLayout {
                visible: root.activeTab === 3
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                Layout.topMargin: 12

                // Pomodoro mode toggle
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: pomodoroRow.implicitWidth + 20
                    height: 28
                    radius: 14
                    color: pomodoroMode ? ColorScheme.withAlpha(ColorScheme.red, 0.15) : ColorScheme.withAlpha(ColorScheme.surface, 0.2)
                    border.color: pomodoroMode ? ColorScheme.withAlpha(ColorScheme.red, 0.3) : "transparent"
                    
                    RowLayout {
                        id: pomodoroRow
                        anchors.centerIn: parent
                        spacing: 6
                        
                        Text {
                            text: "\u{f0f4}"  // coffee icon
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: pomodoroMode ? ColorScheme.red : ColorScheme.withAlpha(root.textColor, 0.5)
                        }
                        Text {
                            text: "Pomodoro"
                            font.pixelSize: 10
                            font.family: "Inter"
                            font.bold: pomodoroMode
                            color: pomodoroMode ? ColorScheme.red : ColorScheme.withAlpha(root.textColor, 0.6)
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (pomodoroMode) {
                                stopPomodoro();
                            } else {
                                startPomodoro();
                            }
                        }
                    }
                }
                
                // Pomodoro status
                RowLayout {
                    visible: pomodoroMode
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12
                    
                    Text {
                        text: pomodoroIsBreak ? "Intervalo" : "Foco"
                        color: pomodoroIsBreak ? ColorScheme.green : ColorScheme.red
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Inter"
                    }
                    
                    Rectangle {
                        width: 1; height: 14
                        color: ColorScheme.withAlpha(root.textColor, 0.2)
                    }
                    
                    Text {
                        text: "Sessão " + pomodoroCurrentSession
                        color: ColorScheme.withAlpha(root.textColor, 0.6)
                        font.pixelSize: 10
                        font.family: "Inter"
                    }
                    
                    Rectangle {
                        width: 1; height: 14
                        color: ColorScheme.withAlpha(root.textColor, 0.2)
                    }
                    
                    // Session dots
                    RowLayout {
                        spacing: 3
                        Repeater {
                            model: pomodoroSessionsBeforeLongBreak
                            delegate: Rectangle {
                                width: 6; height: 6; radius: 3
                                color: index < (pomodoroCompletedSessions % pomodoroSessionsBeforeLongBreak) 
                                    ? ColorScheme.red 
                                    : ColorScheme.withAlpha(root.textColor, 0.2)
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.formatTimerTime(root.timerRemaining)
                    color: {
                        if (pomodoroMode && pomodoroIsBreak) return ColorScheme.green;
                        if (root.timerRemaining <= 10 && root.timerRunning) return ColorScheme.red;
                        return root.textColor;
                    }
                    font.pixelSize: 36
                    font.weight: Font.Light
                    font.family: DesignTokens.fontFamilyMono
                    font.letterSpacing: DesignTokens.letterSpacingTimer
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                // Preset buttons (hidden in pomodoro mode)
                RowLayout {
                    visible: !pomodoroMode
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "1m", secs: 60 },
                            { label: "5m", secs: 300 },
                            { label: "10m", secs: 600 },
                            { label: "15m", secs: 900 },
                            { label: "30m", secs: 1800 }
                        ]
                        delegate: Rectangle {
                            width: 40; height: 24; radius: 12
                            color: presetMa.containsMouse
                                ? ColorScheme.withAlpha(root.accentColor, 0.18)
                                : ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: ColorScheme.withAlpha(root.textColor, 0.65)
                                font.pixelSize: 9; font.family: "Inter"
                            }
                            MouseArea {
                                id: presetMa; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.timerDuration = modelData.secs;
                                    root.timerRemaining = modelData.secs;
                                    root.timerRunning = false;
                                }
                            }
                        }
                    }
                }
                
                // Pomodoro settings (shown when in pomodoro mode and not running)
                RowLayout {
                    visible: pomodoroMode && !timerRunning
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    
                    // Work duration
                    Column {
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Foco"
                            color: ColorScheme.withAlpha(root.textColor, 0.5)
                            font.pixelSize: 8
                            font.family: "Inter"
                        }
                        RowLayout {
                            spacing: 2
                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: pomWorkMinusMa.containsMouse ? ColorScheme.glassHover : "transparent"
                                Text { anchors.centerIn: parent; text: "-"; color: root.textColor; font.pixelSize: 10 }
                                MouseArea {
                                    id: pomWorkMinusMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (pomodoroWorkMinutes > 5) pomodoroWorkMinutes -= 5;
                                }
                            }
                            Text {
                                text: pomodoroWorkMinutes + "m"
                                color: root.textColor
                                font.pixelSize: 10
                                font.family: "Inter"
                            }
                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: pomWorkPlusMa.containsMouse ? ColorScheme.glassHover : "transparent"
                                Text { anchors.centerIn: parent; text: "+"; color: root.textColor; font.pixelSize: 10 }
                                MouseArea {
                                    id: pomWorkPlusMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (pomodoroWorkMinutes < 60) pomodoroWorkMinutes += 5;
                                }
                            }
                        }
                    }
                    
                    Rectangle { width: 1; height: 30; color: ColorScheme.withAlpha(root.textColor, 0.1) }
                    
                    // Break duration
                    Column {
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Pausa"
                            color: ColorScheme.withAlpha(root.textColor, 0.5)
                            font.pixelSize: 8
                            font.family: "Inter"
                        }
                        RowLayout {
                            spacing: 2
                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: pomBreakMinusMa.containsMouse ? ColorScheme.glassHover : "transparent"
                                Text { anchors.centerIn: parent; text: "-"; color: root.textColor; font.pixelSize: 10 }
                                MouseArea {
                                    id: pomBreakMinusMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (pomodoroBreakMinutes > 1) pomodoroBreakMinutes -= 1;
                                }
                            }
                            Text {
                                text: pomodoroBreakMinutes + "m"
                                color: root.textColor
                                font.pixelSize: 10
                                font.family: "Inter"
                            }
                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: pomBreakPlusMa.containsMouse ? ColorScheme.glassHover : "transparent"
                                Text { anchors.centerIn: parent; text: "+"; color: root.textColor; font.pixelSize: 10 }
                                MouseArea {
                                    id: pomBreakPlusMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (pomodoroBreakMinutes < 15) pomodoroBreakMinutes += 1;
                                }
                            }
                        }
                    }
                }

                // +/- 30s (hidden in pomodoro mode)
                RowLayout {
                    visible: !pomodoroMode
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    Rectangle {
                        width: 50; height: 26; radius: 13
                        color: minusMa.containsMouse ? ColorScheme.glassHover : ColorScheme.withAlpha(ColorScheme.surface, 0.20)
                        Text { anchors.centerIn: parent; text: "−30s"; color: ColorScheme.withAlpha(root.textColor, 0.6); font.pixelSize: 10; font.family: "Inter" }
                        MouseArea {
                            id: minusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.timerDuration = Math.max(30, root.timerDuration - 30);
                                if (!root.timerRunning) root.timerRemaining = root.timerDuration;
                            }
                        }
                    }
                    Rectangle {
                        width: 50; height: 26; radius: 13
                        color: plusMa.containsMouse ? ColorScheme.glassHover : ColorScheme.withAlpha(ColorScheme.surface, 0.20)
                        Text { anchors.centerIn: parent; text: "+30s"; color: ColorScheme.withAlpha(root.textColor, 0.6); font.pixelSize: 10; font.family: "Inter" }
                        MouseArea {
                            id: plusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.timerDuration += 30;
                                if (!root.timerRunning) root.timerRemaining = root.timerDuration;
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    Rectangle {
                        width: 70; height: 32; radius: 16
                        color: timerResetMa.containsMouse
                            ? ColorScheme.withAlpha(ColorScheme.surface, 0.5)
                            : ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent; text: "Reset"
                            color: ColorScheme.withAlpha(root.textColor, 0.7)
                            font.pixelSize: 11; font.family: "Inter"
                        }
                        MouseArea {
                            id: timerResetMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.timerRunning = false;
                                if (pomodoroMode) {
                                    // Reset current phase
                                    root.timerRemaining = root.timerDuration;
                                } else {
                                    root.timerRemaining = root.timerDuration;
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 90; height: 36; radius: 18
                        color: root.timerRunning
                            ? ColorScheme.withAlpha(ColorScheme.red, 0.22)
                            : ColorScheme.withAlpha(root.accentColor, 0.22)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        scale: timerStartMa.pressed ? 0.93 : 1.0
                        Behavior on scale { SpringAnimation { spring: 5; damping: 0.5; epsilon: 0.02 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.timerRunning ? "Pause" : "Start"
                            color: root.timerRunning ? ColorScheme.red : root.accentColor
                            font.pixelSize: 12; font.bold: true; font.family: "Inter"
                        }
                        MouseArea {
                            id: timerStartMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (pomodoroMode && !timerRunning && timerRemaining === timerDuration) {
                                    // Starting fresh pomodoro
                                    timerDuration = pomodoroWorkMinutes * 60;
                                    timerRemaining = timerDuration;
                                }
                                root.timerRunning = !root.timerRunning;
                            }
                        }
                    }
                }
                
                // Total pomodoro sessions completed
                Text {
                    visible: pomodoroMode && pomodoroCompletedSessions > 0
                    Layout.alignment: Qt.AlignHCenter
                    text: pomodoroCompletedSessions + " sessões completas hoje"
                    color: ColorScheme.withAlpha(root.textColor, 0.4)
                    font.pixelSize: 9
                    font.family: "Inter"
                }

            }

            // ═══ Notes Tab ═══
            ColumnLayout {
                    visible: root.activeTab === 4
                    Layout.fillWidth: true
                    Layout.minimumWidth: root.notesViewMinWidth
                    Layout.preferredHeight: 360
                    spacing: 10
                    Layout.topMargin: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "\u{f249}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            color: root.accentColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: "Notas"
                                color: root.textColor
                                font.pixelSize: 14
                                font.bold: true
                                font.family: "Inter"
                            }

                            Text {
                                text: QuickNotesService.noteCount > 0
                                    ? QuickNotesService.noteCount + (QuickNotesService.noteCount === 1 ? " nota" : " notas")
                                    : "Sem notas ainda"
                                color: ColorScheme.withAlpha(root.textColor, 0.5)
                                font.pixelSize: 9
                                font.family: "Inter"
                            }
                        }

                        Rectangle {
                            width: 120
                            height: 24
                            radius: 12
                            color: openDedicatedMa.containsMouse
                                ? ColorScheme.withAlpha(root.accentColor, 0.22)
                                : ColorScheme.withAlpha(ColorScheme.surface, 0.22)

                            Text {
                                anchors.centerIn: parent
                                text: "Popup dedicado"
                                color: openDedicatedMa.containsMouse ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.65)
                                font.pixelSize: 8
                                font.family: "Inter"
                                font.bold: true
                            }

                            MouseArea {
                                id: openDedicatedMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openDedicatedNotesPopup()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 34
                            radius: 8
                            clip: true
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.22)
                            border.width: noteInput.activeFocus ? 2 : 1
                            border.color: noteInput.activeFocus
                                ? ColorScheme.withAlpha(root.accentColor, 0.8)
                                : ColorScheme.withAlpha(root.textColor, 0.12)

                            TextInput {
                                id: noteInput
                                anchors.fill: parent
                                anchors.margins: 10
                                font.pixelSize: 11
                                font.family: "Inter"
                                color: root.textColor
                                clip: true

                                property string placeholderText: "Nova nota..."

                                Text {
                                    anchors.fill: parent
                                    text: parent.placeholderText
                                    font: parent.font
                                    color: root.textColor
                                    opacity: 0.4
                                    visible: !parent.text && !parent.activeFocus
                                }

                                onAccepted: {
                                    if (text.trim()) {
                                        QuickNotesService.addNote(text, root.selectedColor);
                                        text = "";
                                    }
                                }

                                Keys.onEscapePressed: root.activeTab = 0
                            }
                        }

                        Row {
                            spacing: 3
                            Repeater {
                                model: root.noteColors
                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: modelData.color
                                    border.width: root.selectedColor === modelData.id ? 2 : 0
                                    border.color: root.textColor
                                    opacity: colorMa.containsMouse ? 1.0 : 0.7

                                    MouseArea {
                                        id: colorMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedColor = modelData.id
                                    }
                                }
                            }
                        }
                    }

                    ScrollView {
                        id: notesScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ScrollBar.vertical: ScrollBar {
                            policy: notesList.contentHeight > notesScroll.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: ColorScheme.withAlpha(root.accentColor, parent.pressed ? 0.6 : (parent.hovered ? 0.4 : 0.25))
                            }

                            background: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: ColorScheme.withAlpha(root.textColor, 0.05)
                            }
                        }

                        ListView {
                            id: notesList
                            width: notesScroll.width - 12
                            spacing: 8
                            model: QuickNotesService.notes
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: noteCard
                                required property var modelData
                                required property int index

                                width: notesList.width
                                height: root.editingNoteId === modelData.id
                                    ? editArea.implicitHeight + 20
                                    : noteContent.implicitHeight + 20
                                radius: 8
                                color: root.getNoteColor(modelData.color)
                                opacity: noteMa.containsMouse ? 1.0 : 0.9

                                Rectangle {
                                    visible: QuickNotesService.noteCount > 1 && root.editingNoteId !== modelData.id
                                    width: 4
                                    height: parent.height - 16
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 2
                                    color: ColorScheme.withAlpha(root.textColor, dragMa.pressed ? 0.5 : (dragMa.containsMouse ? 0.3 : 0.1))

                                    MouseArea {
                                        id: dragMa
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.SizeVerCursor
                                        drag.target: noteCard
                                        drag.axis: Drag.YAxis

                                        onPressed: {
                                            root.dragFromIndex = index;
                                            root.dragToIndex = index;
                                        }

                                        onPositionChanged: {
                                            var targetIndex = notesList.indexAt(noteCard.x + noteCard.width / 2, noteCard.y + noteCard.height / 2);
                                            if (targetIndex >= 0)
                                                root.dragToIndex = targetIndex;
                                        }

                                        onReleased: {
                                            if (root.dragFromIndex !== -1 && root.dragToIndex !== -1 && root.dragFromIndex !== root.dragToIndex) {
                                                QuickNotesService.moveNote(root.dragFromIndex, root.dragToIndex);
                                            }
                                            root.dragFromIndex = -1;
                                            root.dragToIndex = -1;
                                            noteCard.y = noteCard.y;
                                        }
                                    }
                                }

                                MouseArea {
                                    id: noteMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    anchors.leftMargin: QuickNotesService.noteCount > 1 ? 16 : 10
                                    spacing: 8

                                    Text {
                                        id: noteContent
                                        visible: root.editingNoteId !== modelData.id
                                        text: modelData.text
                                        font.pixelSize: 12
                                        font.family: "Inter"
                                        color: root.textColor
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true

                                        MouseArea {
                                            anchors.fill: parent
                                            onDoubleClicked: root.startEditing(modelData.id, modelData.text)
                                        }
                                    }

                                    ColumnLayout {
                                        id: editArea
                                        visible: root.editingNoteId === modelData.id
                                        Layout.fillWidth: true
                                        spacing: 6

                                        TextArea {
                                            id: editInput
                                            Layout.fillWidth: true
                                            Layout.minimumHeight: 60
                                            Layout.maximumHeight: 150
                                            text: root.editingText
                                            font.pixelSize: 12
                                            font.family: "Inter"
                                            color: root.textColor
                                            wrapMode: Text.WordWrap
                                            background: Rectangle {
                                                color: ColorScheme.withAlpha(ColorScheme.background, 0.3)
                                                radius: 4
                                                border.width: 1
                                                border.color: root.accentColor
                                            }

                                            onTextChanged: root.editingText = text
                                            onVisibleChanged: if (visible) forceActiveFocus()
                                            Keys.onEscapePressed: root.cancelEditing()
                                        }

                                        RowLayout {
                                            spacing: 8

                                            Rectangle {
                                                width: saveEditText.width + 16
                                                height: 24
                                                radius: 12
                                                color: saveEditMa.containsMouse ? root.accentColor : ColorScheme.withAlpha(root.accentColor, 0.3)

                                                Text {
                                                    id: saveEditText
                                                    anchors.centerIn: parent
                                                    text: "Salvar"
                                                    font.pixelSize: 10
                                                    font.family: "Inter"
                                                    color: saveEditMa.containsMouse ? ColorScheme.background : root.textColor
                                                }

                                                MouseArea {
                                                    id: saveEditMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.saveEditing()
                                                }
                                            }

                                            Text {
                                                text: "Cancelar"
                                                font.pixelSize: 10
                                                font.family: "Inter"
                                                color: root.textColor
                                                opacity: cancelEditMa.containsMouse ? 1.0 : 0.6

                                                MouseArea {
                                                    id: cancelEditMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.cancelEditing()
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        visible: root.editingNoteId !== modelData.id
                                        spacing: 4
                                        Layout.alignment: Qt.AlignTop

                                        Text {
                                            text: modelData.pinned ? "\u{f08d}" : "\u{f08e}"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            color: modelData.pinned ? root.accentColor : root.textColor
                                            opacity: pinMa.containsMouse ? 1.0 : 0.5

                                            MouseArea {
                                                id: pinMa
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: QuickNotesService.togglePin(modelData.id)
                                            }
                                        }

                                        Text {
                                            text: "\u{f044}"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            color: root.textColor
                                            opacity: editMa.containsMouse ? 1.0 : 0.5

                                            MouseArea {
                                                id: editMa
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.startEditing(modelData.id, modelData.text)
                                            }
                                        }

                                        Text {
                                            text: "\u{f0c5}"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            color: root.textColor
                                            opacity: copyMa.containsMouse ? 1.0 : 0.5

                                            MouseArea {
                                                id: copyMa
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.copyToClipboard(modelData.text)
                                            }
                                        }

                                        Text {
                                            text: "\u{f05a}"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            color: root.accentColor
                                            opacity: noteToTaskMa.containsMouse ? 1.0 : 0.45

                                            MouseArea {
                                                id: noteToTaskMa
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    ProductivityService.addTodo({
                                                        text: modelData.text,
                                                        done: false,
                                                        date: formatDateKey(new Date()),
                                                        time: "",
                                                        pomodoros: 0,
                                                        isPriority: false
                                                    });
                                                    root.activeTab = 1;
                                                }
                                            }
                                        }

                                        Text {
                                            text: "\u{f00d}"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            color: "#e74c3c"
                                            opacity: deleteMa.containsMouse ? 1.0 : 0.5

                                            MouseArea {
                                                id: deleteMa
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: QuickNotesService.removeNote(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Nenhuma nota ainda\nDigite acima para criar"
                                font.pixelSize: 12
                                font.family: "Inter"
                                color: root.textColor
                                opacity: 0.5
                                horizontalAlignment: Text.AlignHCenter
                                visible: QuickNotesService.noteCount === 0
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: QuickNotesService.noteCount > 0

                        Text {
                            text: "Dica: clique duplo para editar"
                            font.pixelSize: 10
                            font.family: "Inter"
                            color: root.textColor
                            opacity: 0.4
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "Limpar tudo"
                            font.pixelSize: 11
                            font.family: "Inter"
                            color: "#e74c3c"
                            opacity: clearMa.containsMouse ? 1.0 : 0.6

                            MouseArea {
                                id: clearMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: QuickNotesService.clearAll()
                            }
                        }
                    }
                }

                Item { height: 6 }
            }
        }
    }
}
