import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../core"
import "../shared"
import "../services"
import "./ProductivityCalendarUtils.js" as ProductivityCalendarUtils

/**
 * ProductivityPopup - Unified productivity hub
 * Tabs: Daily · Calendar · To-Do · Pomodoro · Notes
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
    property color textColor: ColorScheme.text
    property real popupMargin: DesignTokens.spacingLG
    readonly property int dailyViewMinWidth: 340
    readonly property int calendarViewMinWidth: 320
    readonly property int weekViewMinWidth: 540
    readonly property int notesViewMinWidth: 320

    // ─── Tab state ─────────────────────────────────────────────
    property int activeTab: 0

    // ─── Calendar state ────────────────────────────────────────
    property int displayMonth: new Date().getMonth()
    property int displayYear: new Date().getFullYear()
    property date weekStartDate: getWeekStart(new Date())
    property string calendarView: "month"
    property real _calendarGridOpacity: 1.0
    property int _nextMonth: -1
    property int _nextYear: -1

    // ─── Stopwatch state ───────────────────────────────────────
    property real swElapsed: 0
    property bool swRunning: false

    // ─── Timer state ───────────────────────────────────────────
    property int timerDuration: 300
    property bool timerRunning: false

    // ─── Pomodoro state ────────────────────────────────────────
    property int pomodoroWorkMinutes: 25
    property int pomodoroBreakMinutes: 5
    property int pomodoroLongBreakMinutes: 15
    property int pomodoroSessionsBeforeLongBreak: 4
    property int pomodoroCurrentSession: 0
    property int pomodoroCompletedSessions: 0

    // ─── Daily briefing state ──────────────────────────────────
    property var dailyData: ({})
    property bool dailyLoading: true
    property bool dailyDataReady: false

    // ─── Notes editing state ───────────────────────────────────
    property string editingNoteId: ""
    property string editingText: ""
    property string selectedColor: "default"
    property int dragFromIndex: -1
    property int dragToIndex: -1

    // ─── Data models (via Service) ─────────────────────────────
    readonly property var todoModel: ProductivityService.todoModel
    readonly property var noteColors: [
        { id: "default", color: ColorScheme.glassCard },
        { id: "red", color: "#e74c3c" },
        { id: "orange", color: "#e67e22" },
        { id: "yellow", color: "#f1c40f" },
        { id: "green", color: "#2ecc71" },
        { id: "blue", color: "#3498db" },
        { id: "purple", color: "#9b59b6" }
    ]

    // ─── Integration Helpers ───────────────────────────────────
    function saveTodo() {
        ProductivityService.saveTodo();
    }

    function convertNoteToTask(noteId) {
        // Find the note
        for (var i = 0; i < QuickNotesService.notes.length; i++) {
            var note = QuickNotesService.notes[i];
            if (note.id === noteId) {
                ProductivityService.addTodo({
                    text: note.text,
                    done: false,
                    date: formatDateKey(new Date()),
                    time: "",
                    pomodoros: 0,
                    isPriority: false
                });
                // Remove from notes
                QuickNotesService.removeNote(noteId);
                break;
            }
        }
    }

    function selectTaskForFocus(id, text) {
        ProductivityService.focusedTaskId = id;
        ProductivityService.focusedTaskText = text;
        root.activeTab = 3; // Go to Pomodoro tab
    }

    // ─── Greeting logic ────────────────────────────────────────
    function greeting() {
        return ProductivityCalendarUtils.greeting();
    }

    function dayOfWeekPortuguese(date) {
        return ProductivityCalendarUtils.dayOfWeekPortuguese(date);
    }

    function monthName(month) {
        return ProductivityCalendarUtils.monthName(month);
    }

    function shortMonthName(month) {
        return ProductivityCalendarUtils.shortMonthName(month);
    }

    function dayName(dayIndex) {
        return ProductivityCalendarUtils.dayName(dayIndex);
    }

    // ─── Date helpers ──────────────────────────────────────────
    function getWeekStart(date) {
        return ProductivityCalendarUtils.getWeekStart(date);
    }

    function formatDateKey(date) {
        return ProductivityCalendarUtils.formatDateKey(date);
    }

    function daysInMonth(month, year) { return ProductivityCalendarUtils.daysInMonth(month, year); }
    function firstDayOfWeek(month, year) { return ProductivityCalendarUtils.firstDayOfWeek(month, year); }

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

    function getWeekHeaderText() {
        return ProductivityCalendarUtils.getWeekHeaderText(weekStartDate);
    }

    function getTodosForDate(dateKey) {
        var todos = [];
        for (var i = 0; i < todoModel.count; i++) {
            var todo = todoModel.get(i);
            if (todo.date === dateKey || (!todo.date && dateKey === formatDateKey(new Date()))) {
                todos.push({ index: i, id: todo.id || String(i), text: todo.text || todo.task || "", task: todo.task || todo.text || "", done: todo.done, date: todo.date, time: todo.time || "", pomodoros: todo.pomodoros || 0, isPriority: todo.isPriority || false });
            }
        }
        return todos;
    }

    function getNotesForDate(dateKey) {
        var count = 0;
        var notes = QuickNotesService.notes;
        for (var i = 0; i < notes.length; i++) {
            var noteDate = formatDateKey(new Date(notes[i].created));
            if (noteDate === dateKey) count++;
        }
        return count;
    }

    TimedProcess {
        id: dailyBriefingProc
        command: ["bash", RuntimePaths.scriptFile("daily_briefing.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.dailyData = JSON.parse(String(text || "{}"));
                    root.dailyDataReady = true;
                } catch (e) {
                    root.dailyData = {};
                    root.dailyDataReady = false;
                }
                root.dailyLoading = false;
            }
        }
    }

    function loadDailyBriefing() {
        root.dailyLoading = true;
        root.dailyDataReady = false;
        root.dailyData = ({});
        dailyBriefingProc.exec();
    }

    Component.onCompleted: {
        loadDailyBriefing();
    }

    onIsOpenChanged: {
        if (isOpen) {
            root.activeTab = 0;
            root.editingNoteId = "";
            root.editingText = "";
            root.selectedColor = "default";
            root.dragFromIndex = -1;
            root.dragToIndex = -1;
            loadDailyBriefing();
        }
    }

    // ─── Timer logic ───────────────────────────────────────────
    function formatTime(secs) {
        return ProductivityCalendarUtils.formatStopwatchTime(secs);
    }

    function formatTimerTime(secs) {
        return ProductivityCalendarUtils.formatTimerTime(secs);
    }

    function startPomodoro() {
        ProductivityService.pomodoroRunning = true;
        ProductivityService.pomodoroIsBreak = false;
        pomodoroCurrentSession = 1;
        timerDuration = pomodoroWorkMinutes * 60;
        ProductivityService.timerRemaining = timerDuration;
        timerRunning = true;
        root.activeTab = 3;
    }

    function handlePomodoroComplete() {
        timerRunning = false;
        pomodoroNotifyProc.exec(["bash", "-c", "paplay /run/current-system/sw/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true"]);

        if (!ProductivityService.pomodoroIsBreak) {
            pomodoroCompletedSessions++;

            // Increment pomodoro count for the focused task via service
            if (ProductivityService.focusedTaskId) {
                ProductivityService.incrementTodoPomodoros(ProductivityService.focusedTaskId, 1);
            }
            ProductivityService.recordPomodoroSession();
            // Save metrics logic simplified or moved to service later if needed
        }

        if (ProductivityService.pomodoroIsBreak) {
            ProductivityService.pomodoroIsBreak = false;
            pomodoroCurrentSession++;
            timerDuration = pomodoroWorkMinutes * 60;
            ProductivityService.timerRemaining = timerDuration;
        } else {
            ProductivityService.pomodoroIsBreak = true;
            if (pomodoroCompletedSessions % pomodoroSessionsBeforeLongBreak === 0) {
                timerDuration = pomodoroLongBreakMinutes * 60;
            } else {
                timerDuration = pomodoroBreakMinutes * 60;
            }
            ProductivityService.timerRemaining = timerDuration;
        }
    }

    function stopPomodoro() {
        ProductivityService.pomodoroRunning = false;
        timerRunning = false;
        ProductivityService.timerRemaining = timerDuration;
        ProductivityService.focusedTaskId = "";
        ProductivityService.focusedTaskText = "";
    }

    TimedProcess { id: pomodoroNotifyProc }

    Timer {
        interval: 500; repeat: true
        running: root.swRunning
        onTriggered: root.swElapsed += 0.5
    }

    Timer {
        interval: 500; repeat: true
        running: root.timerRunning && ProductivityService.timerRemaining > 0
        onTriggered: {
            ProductivityService.timerRemaining = Math.max(0, ProductivityService.timerRemaining - 0.5);
            if (ProductivityService.timerRemaining <= 0) {
                if (ProductivityService.pomodoroRunning) root.handlePomodoroComplete();
                else root.timerRunning = false;
            }
        }
    }

    SequentialAnimation {
        id: monthTransition
        NumberAnimation { target: root; property: "_calendarGridOpacity"; to: 0.0; duration: 100; easing.type: Easing.OutQuad }
        ScriptAction { script: { root.displayMonth = root._nextMonth; root.displayYear = root._nextYear; } }
        NumberAnimation { target: root; property: "_calendarGridOpacity"; to: 1.0; duration: 150; easing.type: Easing.InOutQuad }
    }

    // ─── Notes helpers ─────────────────────────────────────────
    function getNoteColor(colorId) {
        return ProductivityCalendarUtils.resolveNoteColor(noteColors, colorId, ColorScheme.glassCard);
    }

    function copyToClipboard(text) {
        copyProc.exec(["bash", "-c", "printf '%s' \"$1\" | wl-copy", "--", text]);
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

    TimedProcess { id: copyProc; timeoutMs: 2000; timeoutLabel: "CopyNote" }

    // ─── Close on click outside ────────────────────────────────
    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        onClicked: (mouse) => {
            var p = mapToItem(container, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > container.width || p.y > container.height) {
                root.isOpen = false;
            }
        }
    }

    // ─── Main container ────────────────────────────────────────
    Item {
        id: container
        width: contentLayout.implicitWidth + 40
        height: contentLayout.implicitHeight + 40
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

        scale: root.isOpen ? 1.0 : 0.92
        opacity: root.isOpen ? 1.0 : 0.0
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.48; epsilon: 0.005 } }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Rectangle {
            id: cardBg
            anchors.fill: parent
            color: ColorScheme.glassPopup
            radius: DesignTokens.radiusXL
            border.color: ColorScheme.glassBorder
            border.width: 1

            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 1
                height: 1; radius: DesignTokens.radiusXL
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }

        Rectangle {
            anchors.fill: cardBg; anchors.topMargin: 6; radius: cardBg.radius
            color: Qt.rgba(0, 0, 0, DesignTokens.shadowPopup.alpha); z: -1
        }

        ColumnLayout {
            id: contentLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: DesignTokens.spacingXL
            spacing: DesignTokens.spacingMD

            // ─── Tab bar ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: DesignTokens.spacingXS

                Repeater {
                    model: [
                        { label: "Daily",  icon: "\u{f185}", idx: 0 },
                        { label: "Calendar", icon: "\u{f133}", idx: 1 },
                        { label: "Tasks", icon: "\u{f0ae}", idx: 2 },
                        { label: "Focus",  icon: "\u{f017}", idx: 3 },
                        { label: "Notes",  icon: "\u{f249}", idx: 4 }
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 14
                        color: root.activeTab === modelData.idx
                            ? ColorScheme.withAlpha(root.accentColor, 0.22)
                            : (tabMa.containsMouse ? ColorScheme.glassHover : "transparent")
                        Behavior on color { ColorAnimation { duration: DesignTokens.durationNormal } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: modelData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                color: root.activeTab === modelData.idx ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.5)
                            }
                            Text {
                                text: modelData.label
                                color: root.activeTab === modelData.idx ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.55)
                                font.pixelSize: 9
                                font.bold: root.activeTab === modelData.idx
                                font.family: "Inter"
                            }
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

            // ═══ Tab 0 — Daily Briefing ════════════════════════
            ColumnLayout {
                visible: root.activeTab === 0
                Layout.fillWidth: true
                Layout.minimumWidth: root.dailyViewMinWidth
                spacing: DesignTokens.spacingMD

                Item { visible: root.dailyLoading; Layout.preferredHeight: 80
                    BusyIndicator {
                        anchors.centerIn: parent
                        running: root.dailyLoading
                        width: 32; height: 32
                        contentItem: Rectangle {
                            color: "transparent"
                            border.color: root.accentColor; border.width: 3
                            radius: 16
                            opacity: 0.3
                        }
                    }
                    Text {
                        anchors.top: parent.bottom; anchors.topMargin: DesignTokens.spacingSM
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Carregando resumo..."; color: root.textColor; opacity: 0.4
                        font.pixelSize: 10; font.family: "Inter"
                        visible: root.dailyLoading
                    }
                }

                Item { visible: !root.dailyLoading && root.dailyDataReady; Layout.fillWidth: true; Layout.preferredHeight: dailyBriefingCard.implicitHeight
                    Rectangle {
                        id: dailyBriefingCard
                        implicitHeight: dailyLayout.implicitHeight + 32
                        width: parent.width
                        radius: DesignTokens.radiusMD
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.2)

                        ColumnLayout {
                            id: dailyLayout
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: DesignTokens.spacingMD

                            // Date
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: DesignTokens.spacingSM

                                Text {
                                    text: "\u{f073}"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
                                    color: root.accentColor
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        text: greeting() + ", Lucas!"
                                        color: root.textColor
                                        font.pixelSize: 14; font.bold: true; font.family: "Inter"
                                    }
                                    Text {
                                        text: root.dayOfWeekPortuguese(new Date()) + ", " + new Date().getDate() + " de " + monthName(new Date().getMonth()) + " de " + new Date().getFullYear()
                                        color: root.textColor; opacity: 0.5
                                        font.pixelSize: 10; font.family: "Inter"
                                    }
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: ColorScheme.withAlpha(root.textColor, 0.06) }

                            // Priority Tasks section
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                visible: {
                                    for (var i = 0; i < todoModel.count; i++) {
                                        if (todoModel.get(i).isPriority && !todoModel.get(i).done) return true;
                                    }
                                    return false;
                                }
                                Text {
                                    text: "PRIORIDADES DE HOJE"
                                    color: root.accentColor; font.pixelSize: 8; font.bold: true; font.family: "Inter"
                                }
                                Repeater {
                                    model: todoModel
                                    delegate: Rectangle {
                                        visible: model.isPriority && !model.done
                                        Layout.fillWidth: true; height: visible ? 26 : 0; radius: DesignTokens.radiusXS
                                        color: ColorScheme.withAlpha(root.accentColor, 0.1)
                                        RowLayout {
                                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                                            Text { text: "\u{f005}"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: "#f1c40f" }
                                            Text { text: model.text; color: root.textColor; font.pixelSize: 10; font.family: "Inter"; Layout.fillWidth: true; elide: Text.ElideRight }
                                            Text { text: "\u{f05b}"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: ColorScheme.red; opacity: dailyFocusMa.containsMouse ? 1.0 : 0.4
                                                MouseArea { id: dailyFocusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectTaskForFocus(model.id || index.toString(), model.text) }
                                            }
                                        }
                                    }
                                }
                                Rectangle { width: parent.width; height: 1; color: ColorScheme.withAlpha(root.textColor, 0.06); Layout.topMargin: 4 }
                            }

                            // Info cards row
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3; rowSpacing: DesignTokens.spacingSM; columnSpacing: DesignTokens.spacingSM

                                // Weather
                                Rectangle {
                                    Layout.fillWidth: true; height: 56; radius: DesignTokens.radiusSM
                                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.3)
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: 2
                                        Text {
                                            text: root.dailyData.weather || "\u{26c0} --°"
                                            color: root.textColor; font.pixelSize: 14
                                            font.bold: true; font.family: "Inter"
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Text {
                                            text: "Clima"
                                            color: root.textColor; opacity: 0.4
                                            font.pixelSize: 8; font.family: "Inter"
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }

                                // Tasks
                                Rectangle {
                                    Layout.fillWidth: true; height: 56; radius: DesignTokens.radiusSM
                                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.3)
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: 2
                                        Text {
                                            text: String(ProductivityService.pendingTodoCount)
                                            color: ProductivityService.pendingTodoCount > 0 ? root.accentColor : root.textColor
                                            font.pixelSize: 18; font.bold: true; font.family: DesignTokens.fontFamilyMono
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Text {
                                            text: "Tarefas pendentes"
                                            color: root.textColor; opacity: 0.4
                                            font.pixelSize: 8; font.family: "Inter"
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }

                                // Pomodoro
                                Rectangle {
                                    Layout.fillWidth: true; height: 56; radius: DesignTokens.radiusSM
                                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.3)
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: 2
                                        Text {
                                            text: String(ProductivityService.pomodoroSessionCount)
                                            color: root.accentColor
                                            font.pixelSize: 18; font.bold: true; font.family: DesignTokens.fontFamilyMono
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Text {
                                            text: "Pomodoros feitos"
                                            color: root.textColor; opacity: 0.4
                                            font.pixelSize: 8; font.family: "Inter"
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                }
                            }
                        }

                        Rectangle {
                            visible: root.dailyData && root.dailyData.todayTasks && root.dailyData.todayTasks.length > 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: DesignTokens.radiusSM
                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.18)
                            border.width: 1
                            border.color: ColorScheme.withAlpha(root.accentColor, 0.08)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 6

                                Text {
                                    text: "\u{f0ae}"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    color: root.accentColor
                                }

                                Text {
                                    text: {
                                        var tasks = root.dailyData.todayTasks || [];
                                        var preview = tasks.slice(0, 3).join(" • ");
                                        if (tasks.length > 3) preview += " …";
                                        return preview;
                                    }
                                    color: root.textColor
                                    font.pixelSize: 9
                                    font.family: "Inter"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    opacity: 0.75
                                }
                            }
                        }

                        // Quick Pomodoro start
                        Rectangle {
                            Layout.fillWidth: true; height: 32; radius: 16
                            color: ColorScheme.withAlpha(ColorScheme.red, 0.15)
                                border.color: ColorScheme.withAlpha(ColorScheme.red, 0.3)

                                RowLayout {
                                    anchors.centerIn: parent; spacing: DesignTokens.spacingSM
                                    Text {
                                        text: "\u{f0f4}"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11; color: ColorScheme.red
                                    }
                                    Text {
                                        text: "Iniciar Foco (" + pomodoroWorkMinutes + "min)"
                                        color: ColorScheme.red; font.pixelSize: 10
                                        font.bold: true; font.family: "Inter"
                                    }
                                    Rectangle {
                                        width: 100; height: 22; radius: 11
                                        color: dailyPomStartMa.pressed ? ColorScheme.withAlpha(ColorScheme.red, 0.4) : "transparent"
                                        Text {
                                            anchors.centerIn: parent; text: "Iniciar →"
                                            color: ColorScheme.red; font.pixelSize: 9; font.bold: true; font.family: "Inter"
                                        }
                                        MouseArea {
                                            id: dailyPomStartMa; anchors.fill: parent
                                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { root.activeTab = 3; root.startPomodoro(); }
                                        }
                                    }
                            }
                        }

                        // Recent notes preview
                        Repeater {
                            model: {
                                    var recent = root.dailyData && root.dailyData.recentNotes ? root.dailyData.recentNotes : [];
                                    if (recent.length > 0)
                                        return recent.slice(0, 3);

                                    var out = [];
                                    var notes = QuickNotesService.notes || [];
                                    for (var i = 0; i < notes.length && out.length < 3; i++) {
                                        var note = notes[i];
                                        out.push(note.text || note.title || String(note || ""));
                                    }
                                    return out;
                                }
                                delegate: Rectangle {
                                    Layout.fillWidth: true; height: 28; radius: DesignTokens.radiusXS
                                    color: ColorScheme.withAlpha(ColorScheme.surface, 0.2)
                                    Text {
                                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                        text: "\u{f249} " + modelData
                                        color: root.textColor; font.pixelSize: 10
                                        font.family: "Inter"
                                        elide: Text.ElideRight; opacity: 0.6
                                        horizontalAlignment: Text.AlignLeft; verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═══ Tab 1 — Calendar ══════════════════════════════
            ColumnLayout {
                visible: root.activeTab === 1
                Layout.fillWidth: true
                Layout.minimumWidth: root.calendarView === "week" ? root.weekViewMinWidth : root.calendarViewMinWidth
                spacing: DesignTokens.spacingMD

                RowLayout {
                    Layout.fillWidth: true
                    spacing: DesignTokens.spacingMD

                    // Month/Week toggle
                    Rectangle {
                        width: 70; height: 24; radius: 12
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.3)
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 2; spacing: 0
                            Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true; radius: 10
                                color: calendarView === "month" ? ColorScheme.withAlpha(root.accentColor, 0.3) : "transparent"
                                Text {
                                    anchors.centerIn: parent; text: "M"
                                    color: calendarView === "month" ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.5)
                                    font.pixelSize: 9; font.bold: calendarView === "month"; font.family: "Inter"
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calendarView = "month" }
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true; radius: 10
                                color: calendarView === "week" ? ColorScheme.withAlpha(root.accentColor, 0.3) : "transparent"
                                Text {
                                    anchors.centerIn: parent; text: "W"
                                    color: calendarView === "week" ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.5)
                                    font.pixelSize: 9; font.bold: calendarView === "week"; font.family: "Inter"
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calendarView = "week" }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: prevMa.containsMouse ? ColorScheme.glassHover : "transparent"
                        Behavior on color { ColorAnimation { duration: DesignTokens.durationFast } }
                        Text {
                            anchors.centerIn: parent; text: "\u{f053}"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                            color: root.textColor; opacity: 0.5
                        }
                        MouseArea {
                            id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: calendarView === "month" ? root.prevMonth() : root.prevWeek()
                        }
                    }

                    Text {
                        text: calendarView === "month" ? root.monthName(root.displayMonth) + " " + root.displayYear : root.getWeekHeaderText()
                        color: root.accentColor; font.pixelSize: 12; font.bold: true; font.family: "Inter"
                        opacity: root._calendarGridOpacity; Behavior on opacity { NumberAnimation { duration: 80 } }
                    }

                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: nextMa.containsMouse ? ColorScheme.glassHover : "transparent"
                        Behavior on color { ColorAnimation { duration: DesignTokens.durationFast } }
                        Text {
                            anchors.centerIn: parent; text: "\u{f054}"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                            color: root.textColor; opacity: 0.5
                        }
                        MouseArea {
                            id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: calendarView === "month" ? root.nextMonth() : root.nextWeek()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 46; height: 22; radius: 11
                        color: todayBtnMa.containsMouse ? ColorScheme.withAlpha(root.accentColor, 0.25) : ColorScheme.withAlpha(root.accentColor, 0.15)
                        Text {
                            anchors.centerIn: parent; text: "Hoje"
                            color: root.accentColor; font.pixelSize: 8; font.bold: true; font.family: "Inter"
                        }
                        MouseArea {
                            id: todayBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var now = new Date();
                                if (calendarView === "month") {
                                    if (monthTransition.running) return;
                                    root._nextMonth = now.getMonth(); root._nextYear = now.getFullYear();
                                    monthTransition.start();
                                } else {
                                    weekStartDate = getWeekStart(now);
                                }
                            }
                        }
                    }
                }

                // Month view
                ColumnLayout {
                    visible: calendarView === "month"
                    Layout.fillWidth: true; spacing: DesignTokens.spacingXS

                    RowLayout {
                        Layout.fillWidth: true; spacing: 0
                        Repeater {
                            model: ["D", "S", "T", "Q", "Q", "S", "S"]
                            delegate: Text {
                                text: modelData; color: root.accentColor
                                font.bold: true; font.pixelSize: 9; font.family: "Inter"
                                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; opacity: 0.45
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: ColorScheme.withAlpha(root.accentColor, 0.08) }

                    GridLayout {
                        columns: 7; rowSpacing: 2; columnSpacing: 2
                        Layout.fillWidth: true; opacity: root._calendarGridOpacity

                        Repeater {
                            model: 42
                            delegate: Item {
                                width: 28; height: 28; Layout.fillWidth: true

                                property int dayNumber: {
                                    var offset = root.firstDayOfWeek(root.displayMonth, root.displayYear);
                                    var day = index - offset + 1;
                                    var maxDays = root.daysInMonth(root.displayMonth, root.displayYear);
                                    return (day >= 1 && day <= maxDays) ? day : 0;
                                }
                                property string dateKey: dayNumber > 0
                                    ? root.displayYear + "-" + String(root.displayMonth + 1).padStart(2, '0') + "-" + String(dayNumber).padStart(2, '0')
                                    : ""
                                property var dayTodos: dateKey !== "" ? root.getTodosForDate(dateKey) : []

                                Rectangle {
                                    anchors.centerIn: parent; width: 26; height: 26; radius: 13
                                    color: {
                                        if (dayNumber === 0) return "transparent";
                                        if (root.isToday(dayNumber)) return root.accentColor;
                                        if (dayCalMa.containsMouse) return ColorScheme.glassHover;
                                        return "transparent";
                                    }
                                    Behavior on color { ColorAnimation { duration: DesignTokens.durationFast } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: dayNumber > 0 ? dayNumber : ""
                                    color: {
                                        if (dayNumber === 0) return "transparent";
                                        if (root.isToday(dayNumber)) return ColorScheme.onPrimary;
                                        if (index % 7 === 0 || index % 7 === 6) return ColorScheme.withAlpha(root.textColor, 0.5);
                                        return root.textColor;
                                    }
                                    font.bold: root.isToday(dayNumber)
                                    font.pixelSize: 10; font.family: "Inter"
                                    opacity: root.isToday(dayNumber) ? 1.0 : 0.72
                                }

                                Rectangle {
                                    visible: dayTodos.length > 0
                                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 2
                                    width: 4; height: 4; radius: 2
                                    color: root.isToday(dayNumber) ? ColorScheme.onPrimary : ColorScheme.blue
                                }

                                MouseArea {
                                    id: dayCalMa; anchors.fill: parent; hoverEnabled: true; visible: dayNumber > 0
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var clickedDate = new Date(root.displayYear, root.displayMonth, dayNumber);
                                        weekStartDate = getWeekStart(clickedDate);
                                        calendarView = "week";
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // Week view
                ColumnLayout {
                    visible: calendarView === "week"
                    Layout.fillWidth: true; Layout.minimumWidth: root.weekViewMinWidth; spacing: 2

                    // Day headers
                    RowLayout {
                        Layout.fillWidth: true; spacing: 0
                        Item { width: 35 }
                        Repeater {
                            model: 7
                            delegate: Item {
                                Layout.fillWidth: true; height: 32
                                property date dayDate: { var d = new Date(weekStartDate); d.setDate(d.getDate() + index); return d; }
                                property bool isCurrentDay: isTodayDate(dayDate)

                                Column { anchors.centerIn: parent; spacing: 0
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter; text: dayName(index)
                                        color: isCurrentDay ? root.accentColor : ColorScheme.withAlpha(root.textColor, 0.5)
                                        font.pixelSize: 8; font.family: "Inter"; font.bold: isCurrentDay
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter; text: dayDate.getDate()
                                        color: isCurrentDay ? root.accentColor : root.textColor
                                        font.pixelSize: 12; font.family: "Inter"; font.bold: isCurrentDay
                                    }
                                }
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: ColorScheme.withAlpha(root.accentColor, 0.08) }

                    ScrollView {
                        Layout.fillWidth: true; Layout.preferredHeight: 180; clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            width: parent.width; spacing: 0
                            Repeater {
                                model: 24
                                delegate: RowLayout {
                                    property int hourIndex: index
                                    Layout.fillWidth: true; height: 24; spacing: 0
                                    Text {
                                        Layout.preferredWidth: 35; rightPadding: 4
                                        text: String(hourIndex).padStart(2, '0') + ":00"
                                        color: ColorScheme.withAlpha(root.textColor, 0.4); font.pixelSize: 7
                                        font.family: DesignTokens.fontFamilyMono
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    Repeater {
                                        model: 7
                                        delegate: Rectangle {
                                            property int dayIndex: index
                                            Layout.fillWidth: true; Layout.fillHeight: true
                                            property date cellDate: { var d = new Date(weekStartDate); d.setDate(d.getDate() + dayIndex); return d; }
                                            property string cellDateKey: formatDateKey(cellDate)
                                            property var cellTodos: {
                                                var todos = getTodosForDate(cellDateKey);
                                                return todos.filter(function(t) {
                                                    if (!t.time) return hourIndex === 9;
                                                    var h = parseInt(t.time.split(":")[0]);
                                                    return h === hourIndex;
                                                });
                                            }
                                            property bool isCurrentHour: isTodayDate(cellDate) && new Date().getHours() === hourIndex

                                            color: {
                                                if (isCurrentHour) return ColorScheme.withAlpha(root.accentColor, 0.08);
                                                if (cellSlotMa.containsMouse) return ColorScheme.withAlpha(ColorScheme.surface, 0.2);
                                                return ColorScheme.withAlpha(ColorScheme.surface, 0.08);
                                            }
                                            border.color: ColorScheme.withAlpha(root.textColor, 0.05)
                                            border.width: 1

                                            Text {
                                                anchors.fill: parent; anchors.margins: 1
                                                text: cellTodos.length > 0 ? (cellTodos[0].text || cellTodos[0].task || "") : ""
                                                color: cellTodos.length > 0 && cellTodos[0].done ? ColorScheme.withAlpha(root.textColor, 0.4) : root.textColor
                                                font.pixelSize: 7; font.family: "Inter"
                                                font.strikeout: cellTodos.length > 0 && cellTodos[0].done
                                                elide: Text.ElideRight; wrapMode: Text.NoWrap
                                            }

                                            Rectangle {
                                                visible: cellTodos.length > 1
                                                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 1
                                                width: 8; height: 8; radius: 4; color: ColorScheme.blue
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "+" + (cellTodos.length - 1); color: "white"
                                                    font.pixelSize: 5; font.bold: true
                                                }
                                            }

                                            MouseArea {
                                                id: cellSlotMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    // Quick add todo for this time slot
                                                    var timeStr = String(hourIndex).padStart(2, '0') + ":00";
                                                    ProductivityService.addTodo({ text: "Nova tarefa", done: false, date: cellDateKey, time: timeStr, pomodoros: 0, isPriority: false });
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Activity Summary for selected day (Timeline step 4)
                    Rectangle {
                        Layout.fillWidth: true; height: 40; radius: DesignTokens.radiusSM
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.15)
                        border.color: ColorScheme.withAlpha(root.accentColor, 0.1)

                        property date selectedDate: {
                            var d = new Date(weekStartDate);
                            var today = new Date();
                            // If today is in this week, show today, else show week start
                            if (today >= weekStartDate && today <= new Date(weekStartDate.getTime() + 7*24*60*60*1000)) {
                                return today;
                            }
                            return d;
                        }
                        property string dateKey: formatDateKey(selectedDate)

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: DesignTokens.spacingLG

                            Text {
                                text: "Resumo de " + selectedDate.getDate() + "/" + (selectedDate.getMonth()+1)
                                color: root.accentColor; font.pixelSize: 9; font.bold: true; font.family: "Inter"
                            }

                            RowLayout {
                                spacing: 10
                                // Tasks summary
                                RowLayout {
                                    spacing: 4
                                    Text { text: "\u{f0ae}"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: root.textColor; opacity: 0.5 }
                                    Text {
                                        text: {
                                            var tasks = root.getTodosForDate(root.formatDateKey(root.weekStartDate)); // Fallback value logic
                                            // More robust way to get the parent's dateKey
                                            var dk = parent.parent.parent.parent.dateKey;
                                            var tks = root.getTodosForDate(dk);
                                            var done = 0;
                                            for(var i=0; i<tks.length; i++) if(tks[i].done) done++;
                                            return done + "/" + tks.length + " tarefas";
                                        }
                                        color: root.textColor; font.pixelSize: 9; font.family: "Inter"
                                    }
                                }
                                // Notes summary
                                RowLayout {
                                    spacing: 4
                                    Text { text: "\u{f249}"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: root.textColor; opacity: 0.5 }
                                    Text {
                                        text: root.getNotesForDate(parent.parent.parent.parent.dateKey) + " notas"
                                        color: root.textColor; font.pixelSize: 9; font.family: "Inter"
                                    }
                                }
                                // Focus summary
                                RowLayout {
                                    spacing: 4
                                    Text { text: "\u{f017}"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: root.textColor; opacity: 0.5 }
                                    Text {
                                        text: {
                                            var dk = parent.parent.parent.parent.dateKey;
                                            var tks = root.getTodosForDate(dk);
                                            var poms = 0;
                                            for(var i=0; i<tks.length; i++) poms += (tks[i].pomodoros || 0);
                                            return poms + " focos";
                                        }
                                        color: root.textColor; font.pixelSize: 9; font.family: "Inter"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═══ Tab 2 — To-Do ═════════════════════════════════
            ColumnLayout {
                visible: root.activeTab === 2
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: DesignTokens.spacingMD
                Layout.topMargin: DesignTokens.spacingMD

                RowLayout {
                    Layout.fillWidth: true; spacing: DesignTokens.spacingSM

                    TextField {
                        id: todoInput; Layout.fillWidth: true
                        placeholderText: "Nova tarefa..."
                        color: root.textColor; font.pixelSize: 11; font.family: "Inter"
                        placeholderTextColor: ColorScheme.withAlpha(root.textColor, 0.4)
                        background: Rectangle { radius: 8; color: ColorScheme.withAlpha(ColorScheme.surface, 0.36); border.color: ColorScheme.withAlpha(root.textColor, 0.15) }
                        onAccepted: {
                            if (text.trim() !== "") {
                                ProductivityService.addTodo({ text: text.trim(), done: false, date: formatDateKey(new Date()), time: "", pomodoros: 0, isPriority: false });
                                text = "";
                            }
                        }
                    }

                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: ColorScheme.withAlpha(root.accentColor, 0.2)
                        Text { anchors.centerIn: parent; text: "+"; color: root.accentColor; font.pixelSize: 14; font.bold: true; font.family: "Inter" }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (todoInput.text.trim() !== "") {
                                    ProductivityService.addTodo({ text: todoInput.text.trim(), done: false, date: formatDateKey(new Date()), time: "", pomodoros: 0, isPriority: false });
                                    todoInput.text = "";
                                }
                            }
                        }
                    }
                }

                // Stats bar
                RowLayout {
                    Layout.fillWidth: true; spacing: DesignTokens.spacingSM
                    Text {
                        property int total: todoModel.count
                        property int done: {
                            var c = 0;
                            for (var i = 0; i < todoModel.count; i++) { if (todoModel.get(i).done) c++; }
                            return c;
                        }
                        text: done + "/" + total + " concluídas"
                        color: ColorScheme.withAlpha(root.textColor, 0.5); font.pixelSize: 9; font.family: "Inter"
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        visible: {
                            for (var i = 0; i < todoModel.count; i++) { if (todoModel.get(i).done) return true; }
                            return false;
                        }
                        width: 80; height: 20; radius: 10
                        color: clearCompletedMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.red, 0.2) : "transparent"
                        Text {
                            anchors.centerIn: parent; text: "Limpar feitas"; color: ColorScheme.red; font.pixelSize: 8; font.family: "Inter"
                        }
                        MouseArea {
                            id: clearCompletedMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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
                    id: todoList; Layout.fillWidth: true; Layout.fillHeight: true; model: todoModel; spacing: DesignTokens.spacingXS; clip: true

                    delegate: Rectangle {
                        width: ListView.view.width; height: 38; radius: DesignTokens.radiusSM
                        color: model.isPriority ? ColorScheme.withAlpha(root.accentColor, 0.12) : ColorScheme.withAlpha(ColorScheme.surface, 0.2)
                        border.width: model.isPriority ? 1 : 0
                        border.color: ColorScheme.withAlpha(root.accentColor, 0.3)
                        opacity: model.done ? DesignTokens.mutedOpacity : 1.0
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 6; spacing: DesignTokens.spacingSM

                            Rectangle {
                                width: 18; height: 18; radius: 5
                                color: model.done ? ColorScheme.withAlpha(ColorScheme.green, 0.4) : "transparent"
                                border.color: model.done ? ColorScheme.green : ColorScheme.withAlpha(root.textColor, 0.4)
                                border.width: 1
                                Text { anchors.centerIn: parent; visible: model.done; text: "\u{f00c}"; color: ColorScheme.green; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font" }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: ProductivityService.setTodoDone(model.id || index.toString(), !model.done)
                                    }
                                }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text {
                                    text: model.text; Layout.fillWidth: true
                                    color: model.done ? ColorScheme.withAlpha(root.textColor, 0.4) : root.textColor
                                    font.pixelSize: 11; font.family: "Inter"
                                    font.strikeout: model.done; elide: Text.ElideRight
                                }
                                RowLayout {
                                    visible: model.date || model.time || model.pomodoros > 0
                                    spacing: 6
                                    Text {
                                        text: (model.date || "") + (model.time ? " " + model.time : "")
                                        color: ColorScheme.withAlpha(root.textColor, 0.35); font.pixelSize: 7; font.family: "Inter"
                                    }
                                    Text {
                                        visible: model.pomodoros > 0
                                        text: "\u{f0f4} " + model.pomodoros
                                        color: ColorScheme.red; font.pixelSize: 7; font.family: "JetBrainsMono Nerd Font"
                                    }
                                }
                            }

                            // Quick Actions
                            RowLayout {
                                spacing: 4

                                // Priority toggle
                                Text {
                                    text: model.isPriority ? "\u{f005}" : "\u{f006}"
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                                    color: model.isPriority ? "#f1c40f" : root.textColor; opacity: 0.5
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: ProductivityService.setTodoPriority(model.id || index.toString(), !model.isPriority)
                                    }
                                }

                                // Focus this task
                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    color: focusBtnMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.red, 0.2) : "transparent"
                                    Text { anchors.centerIn: parent; text: "\u{f05b}"; color: ColorScheme.red; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
                                    MouseArea {
                                        id: focusBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectTaskForFocus(model.id || index.toString(), model.text)
                                    }
                                }

                                Rectangle {
                                    width: 20; height: 20; radius: 10; color: "transparent"
                                    Text { anchors.centerIn: parent; text: "\u{f00d}"; color: ColorScheme.red; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8; opacity: 0.6 }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: ProductivityService.removeTodo(model.id || index.toString())
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═══ Tab 3 — Pomodoro/Focus ════════════════════════
            ColumnLayout {
                visible: root.activeTab === 3
                Layout.alignment: Qt.AlignHCenter; spacing: DesignTokens.spacingMD
                Layout.topMargin: DesignTokens.spacingLG

                // Focused Task Display
                Rectangle {
                    visible: ProductivityService.focusedTaskText !== ""
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true; Layout.maximumWidth: 280; height: 32; radius: 16
                    color: ColorScheme.withAlpha(ColorScheme.red, 0.08)
                    border.color: ColorScheme.withAlpha(ColorScheme.red, 0.2)

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                        Text { text: "\u{f05b}"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: ColorScheme.red }
                        Text {
                            text: ProductivityService.focusedTaskText; color: root.textColor; font.pixelSize: 10; font.family: "Inter"
                            Layout.fillWidth: true; elide: Text.ElideRight; font.bold: true
                        }
                        Text {
                            text: "\u{f00d}"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: root.textColor; opacity: 0.4
                            MouseArea { anchors.fill: parent; onClicked: { ProductivityService.focusedTaskId = ""; ProductivityService.focusedTaskText = ""; } }
                        }
                    }
                }

                // Task Selector (if none focused)
                ColumnLayout {
                    visible: ProductivityService.focusedTaskText === "" && !timerRunning
                    Layout.alignment: Qt.AlignHCenter; spacing: 4
                    Text { text: "Selecione uma tarefa para focar:"; color: root.textColor; font.pixelSize: 8; opacity: 0.5; Layout.alignment: Qt.AlignHCenter }
                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: todoModel
                            delegate: Rectangle {
                                visible: !model.done && (index < 3 || model.isPriority)
                                width: 80; height: 24; radius: 12
                                color: selTaskMa.containsMouse ? ColorScheme.glassHover : ColorScheme.withAlpha(ColorScheme.surface, 0.2)
                                Text { anchors.fill: parent; anchors.margins: 6; text: model.text; font.pixelSize: 8; color: root.textColor; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                MouseArea { id: selTaskMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.selectTaskForFocus(model.id || index.toString(), model.text) }
                            }
                        }
                    }
                }

                // Pomodoro mode toggle
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: pomodoroRow.implicitWidth + 20; height: 28; radius: 14
                    color: ProductivityService.pomodoroRunning ? ColorScheme.withAlpha(ColorScheme.red, 0.15) : ColorScheme.withAlpha(ColorScheme.surface, 0.2)
                    border.color: ProductivityService.pomodoroRunning ? ColorScheme.withAlpha(ColorScheme.red, 0.3) : "transparent"

                    RowLayout {
                        id: pomodoroRow
                        anchors.centerIn: parent; spacing: DesignTokens.spacingXS

                        Text { text: "\u{f0f4}"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: ProductivityService.pomodoroRunning ? ColorScheme.red : ColorScheme.withAlpha(root.textColor, 0.5) }
                        Text {
                            text: "Pomodoro"
                            font.pixelSize: 10; font.family: "Inter"; font.bold: ProductivityService.pomodoroRunning
                            color: ProductivityService.pomodoroRunning ? ColorScheme.red : ColorScheme.withAlpha(root.textColor, 0.6)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: { if (ProductivityService.pomodoroRunning) stopPomodoro(); else startPomodoro(); }
                    }
                }

                // Pomodoro status
                RowLayout {
                    visible: ProductivityService.pomodoroRunning; Layout.alignment: Qt.AlignHCenter; spacing: DesignTokens.spacingMD

                    Text {
                        text: ProductivityService.pomodoroIsBreak ? "Intervalo" : "Foco"
                        color: ProductivityService.pomodoroIsBreak ? ColorScheme.green : ColorScheme.red
                        font.pixelSize: 11; font.bold: true; font.family: "Inter"
                    }
                    Rectangle { width: 1; height: 14; color: ColorScheme.withAlpha(root.textColor, 0.2) }
                    Text {
                        text: "Sessão " + pomodoroCurrentSession
                        color: ColorScheme.withAlpha(root.textColor, 0.6); font.pixelSize: 10; font.family: "Inter"
                    }
                    Rectangle { width: 1; height: 14; color: ColorScheme.withAlpha(root.textColor, 0.2) }
                    RowLayout {
                        spacing: 3
                        Repeater {
                            model: pomodoroSessionsBeforeLongBreak
                            delegate: Rectangle {
                                width: 6; height: 6; radius: 3
                                color: index < (pomodoroCompletedSessions % pomodoroSessionsBeforeLongBreak) ? ColorScheme.red : ColorScheme.withAlpha(root.textColor, 0.2)
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.formatTimerTime(ProductivityService.timerRemaining)
                    color: {
                        if (ProductivityService.pomodoroRunning && ProductivityService.pomodoroIsBreak) return ColorScheme.green;
                        if (ProductivityService.timerRemaining <= 10 && root.timerRunning) return ColorScheme.red;
                        return root.textColor;
                    }
                    font.pixelSize: 36; font.weight: Font.Light; font.family: DesignTokens.fontFamilyMono
                    font.letterSpacing: DesignTokens.letterSpacingTimer
                    Behavior on color { ColorAnimation { duration: DesignTokens.durationNormal } }
                }

                // Preset buttons
                RowLayout {
                    visible: !ProductivityService.pomodoroRunning
                    Layout.alignment: Qt.AlignHCenter; spacing: DesignTokens.spacingXS
                    Repeater {
                        model: [{ label: "1m", secs: 60 }, { label: "5m", secs: 300 }, { label: "10m", secs: 600 }, { label: "15m", secs: 900 }, { label: "30m", secs: 1800 }]
                        delegate: Rectangle {
                            width: 40; height: 22; radius: 11
                            color: presetMa.containsMouse ? ColorScheme.withAlpha(root.accentColor, 0.18) : ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                            Behavior on color { ColorAnimation { duration: DesignTokens.durationFast } }
                            Text {
                                anchors.centerIn: parent; text: modelData.label
                                color: ColorScheme.withAlpha(root.textColor, 0.65); font.pixelSize: 9; font.family: "Inter"
                            }
                            MouseArea {
                                id: presetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.timerDuration = modelData.secs; ProductivityService.timerRemaining = modelData.secs; root.timerRunning = false; }
                            }
                        }
                    }
                }

                // Pomodoro settings
                RowLayout {
                    visible: ProductivityService.pomodoroRunning && !timerRunning
                    Layout.alignment: Qt.AlignHCenter; spacing: DesignTokens.spacingSM

                    Column {
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter; text: "Foco"
                            color: ColorScheme.withAlpha(root.textColor, 0.5); font.pixelSize: 8; font.family: "Inter"
                        }
                        RowLayout {
                            spacing: 2
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: pomWorkMinusMa.pressed ? ColorScheme.withAlpha(ColorScheme.green, 0.15) : ColorScheme.withAlpha(ColorScheme.green, 0.1)
                                Text { anchors.centerIn: parent; text: "-"; color: ColorScheme.green; font.pixelSize: 12 }
                                MouseArea {
                                    id: pomWorkMinusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onPressed: if (pomodoroWorkMinutes > 5) pomodoroWorkMinutes -= 5;
                                }
                            }
                            Text {
                                text: pomodoroWorkMinutes + "m"
                                color: ColorScheme.green; font.pixelSize: 10; font.bold: true; font.family: "Inter"
                            }
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: pomWorkPlusMa.pressed ? ColorScheme.withAlpha(ColorScheme.green, 0.15) : ColorScheme.withAlpha(ColorScheme.green, 0.1)
                                Text { anchors.centerIn: parent; text: "+"; color: ColorScheme.green; font.pixelSize: 12 }
                                MouseArea {
                                    id: pomWorkPlusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onPressed: if (pomodoroWorkMinutes < 60) pomodoroWorkMinutes += 5;
                                }
                            }
                        }
                    }
                    Rectangle { width: 1; height: 28; color: ColorScheme.withAlpha(root.textColor, 0.1) }
                    Column {
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter; text: "Pausa"
                            color: ColorScheme.withAlpha(root.textColor, 0.5); font.pixelSize: 8; font.family: "Inter"
                        }
                        RowLayout {
                            spacing: 2
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: pomBreakMinusMa.pressed ? ColorScheme.withAlpha(ColorScheme.text, 0.15) : "transparent"
                                Text { anchors.centerIn: parent; text: "-"; color: root.textColor; font.pixelSize: 12 }
                                MouseArea {
                                    id: pomBreakMinusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onPressed: if (pomodoroBreakMinutes > 1) pomodoroBreakMinutes -= 1;
                                }
                            }
                            Text {
                                text: pomodoroBreakMinutes + "m"
                                color: root.textColor; font.pixelSize: 10; font.family: "Inter"
                            }
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: pomBreakPlusMa.pressed ? ColorScheme.withAlpha(ColorScheme.text, 0.15) : "transparent"
                                Text { anchors.centerIn: parent; text: "+"; color: root.textColor; font.pixelSize: 12 }
                                MouseArea {
                                    id: pomBreakPlusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onPressed: if (pomodoroBreakMinutes < 15) pomodoroBreakMinutes += 1;
                                }
                            }
                        }
                    }
                }

                // +/- 30s
                RowLayout {
                    visible: !ProductivityService.pomodoroRunning
                    Layout.alignment: Qt.AlignHCenter; spacing: DesignTokens.spacingMD
                    Rectangle {
                        width: 48; height: 24; radius: 12
                        color: minusMa.containsMouse ? ColorScheme.glassHover : ColorScheme.withAlpha(ColorScheme.surface, 0.20)
                        Text { anchors.centerIn: parent; text: "−30s"; color: ColorScheme.withAlpha(root.textColor, 0.6); font.pixelSize: 10; font.family: "Inter" }
                        MouseArea {
                            id: minusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.timerDuration = Math.max(30, root.timerDuration - 30); if (!root.timerRunning) ProductivityService.timerRemaining = root.timerDuration; }
                        }
                    }
                    Rectangle {
                        width: 48; height: 24; radius: 12
                        color: plusMa.containsMouse ? ColorScheme.glassHover : ColorScheme.withAlpha(ColorScheme.surface, 0.20)
                        Text { anchors.centerIn: parent; text: "+30s"; color: ColorScheme.withAlpha(root.textColor, 0.6); font.pixelSize: 10; font.family: "Inter" }
                        MouseArea {
                            id: plusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.timerDuration += 30; if (!root.timerRunning) ProductivityService.timerRemaining = root.timerDuration; }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter; spacing: DesignTokens.spacingLG
                    Rectangle {
                        width: 68; height: 30; radius: 15
                        color: timerResetMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.surface, 0.50) : ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                        Behavior on color { ColorAnimation { duration: DesignTokens.durationFast } }
                        Text { anchors.centerIn: parent; text: "Reset"; color: ColorScheme.withAlpha(root.textColor, 0.7); font.pixelSize: 11; font.family: "Inter" }
                        MouseArea {
                            id: timerResetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.timerRunning = false; ProductivityService.timerRemaining = root.timerDuration; }
                        }
                    }
                    Rectangle {
                        width: 90; height: 34; radius: 17
                        color: root.timerRunning ? ColorScheme.withAlpha(ColorScheme.red, 0.22) : ColorScheme.withAlpha(root.accentColor, 0.22)
                        Behavior on color { ColorAnimation { duration: DesignTokens.durationNormal } }
                        scale: timerStartMa.pressed ? 0.93 : 1.0
                        Behavior on scale { SpringAnimation { spring: 5; damping: 0.5; epsilon: 0.02 } }
                        Text {
                            anchors.centerIn: parent
                            text: root.timerRunning ? "Pause" : "Start"
                            color: root.timerRunning ? ColorScheme.red : root.accentColor
                            font.pixelSize: 12; font.bold: true; font.family: "Inter"
                        }
                        MouseArea {
                            id: timerStartMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (ProductivityService.pomodoroRunning && !timerRunning && ProductivityService.timerRemaining === timerDuration) {
                                    timerDuration = pomodoroWorkMinutes * 60;
                                    ProductivityService.timerRemaining = timerDuration;
                                }
                                root.timerRunning = !root.timerRunning;
                            }
                        }
                    }
                }

                Text {
                    visible: ProductivityService.pomodoroRunning && pomodoroCompletedSessions > 0
                    Layout.alignment: Qt.AlignHCenter
                    text: pomodoroCompletedSessions + " sessões completas hoje"
                    color: ColorScheme.withAlpha(root.textColor, 0.4); font.pixelSize: 9; font.family: "Inter"
                }
            }

            // ═══ Tab 4 — Notes ═════════════════════════════════
            ColumnLayout {
                visible: root.activeTab === 4
                Layout.fillWidth: true
                Layout.minimumWidth: root.notesViewMinWidth
                Layout.preferredHeight: 340
                spacing: DesignTokens.spacingMD

                // New note row
                RowLayout {
                    Layout.fillWidth: true; spacing: DesignTokens.spacingXS

                    Rectangle {
                        Layout.fillWidth: true; height: 32; radius: DesignTokens.radiusSM
                        color: ColorScheme.glassHover
                        border.width: newNoteInput.activeFocus ? 2 : 0
                        border.color: root.accentColor

                        TextInput {
                            id: newNoteInput
                            anchors.fill: parent; anchors.margins: 10
                            font.pixelSize: 11; font.family: "Inter"; color: root.textColor; clip: true
                            property string placeholderText: "Nova nota..."
                            Text {
                                anchors.fill: parent; text: parent.placeholderText
                                font: parent.font; color: root.textColor; opacity: 0.4
                                visible: !parent.text && !parent.activeFocus
                            }
                            onAccepted: {
                                if (text.trim()) { QuickNotesService.addNote(text, root.selectedColor); text = ""; }
                            }
                            Keys.onEscapePressed: root.editingNoteId = ""
                        }
                    }

                    Row {
                        spacing: 3
                        Repeater {
                            model: root.noteColors
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: modelData.color
                                border.width: root.selectedColor === modelData.id ? 2 : 0
                                border.color: root.textColor
                                opacity: nColorMa.containsMouse ? 1.0 : 0.7
                                MouseArea {
                                    id: nColorMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedColor = modelData.id
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: QuickNotesService.noteCount > 0

                    Text {
                        text: QuickNotesService.noteCount + (QuickNotesService.noteCount === 1 ? " nota" : " notas")
                        color: ColorScheme.withAlpha(root.textColor, 0.5)
                        font.pixelSize: 9
                        font.family: "Inter"
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Limpar tudo"
                        color: ColorScheme.red
                        opacity: clearNotesMa.containsMouse ? 1.0 : 0.65
                        font.pixelSize: 9
                        font.family: "Inter"

                        MouseArea {
                            id: clearNotesMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: QuickNotesService.clearAll()
                        }
                    }
                }

                // Notes list with scrollbar
                ScrollView {
                    id: notesScroll
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true

                    ScrollBar.vertical: ScrollBar {
                        policy: notesList.contentHeight > notesScroll.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 6; radius: 3
                            color: ColorScheme.withAlpha(root.accentColor, parent.pressed ? 0.6 : (parent.hovered ? 0.4 : 0.25))
                        }
                        background: Rectangle { implicitWidth: 6; radius: 3; color: ColorScheme.withAlpha(root.textColor, 0.05) }
                    }

                    ListView {
                        id: notesList
                        width: notesScroll.width - 12
                        spacing: DesignTokens.spacingXS
                        model: QuickNotesService.notes
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: noteCard
                            required property var modelData
                            required property int index
                            width: notesList.width
                            height: root.editingNoteId === modelData.id ? editArea.implicitHeight + 16 : noteContent.implicitHeight + 16
                            radius: DesignTokens.radiusSM
                            color: root.editingNoteId === modelData.id ? ColorScheme.withAlpha(ColorScheme.surface, 0.3) : root.getNoteColor(modelData.color)
                            opacity: noteMa.containsMouse ? 1.0 : 0.9

                            MouseArea { id: noteMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 8; spacing: DesignTokens.spacingXS

                                Rectangle {
                                    visible: QuickNotesService.noteCount > 1 && root.editingNoteId !== modelData.id
                                    Layout.preferredWidth: 6
                                    Layout.fillHeight: true
                                    radius: 3
                                    color: ColorScheme.withAlpha(root.textColor, dragMa.pressed ? 0.5 : (dragMa.containsMouse ? 0.3 : 0.12))

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

                                // Display mode
                                Text {
                                    id: noteContent
                                    visible: root.editingNoteId !== modelData.id
                                    text: modelData.text
                                    font.pixelSize: 11; font.family: "Inter"
                                    color: root.textColor; wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                    MouseArea { anchors.fill: parent; onDoubleClicked: root.startEditing(modelData.id, modelData.text) }
                                }

                                // Edit mode
                                ColumnLayout {
                                    id: editArea
                                    visible: root.editingNoteId === modelData.id
                                    Layout.fillWidth: true; spacing: 4

                                    TextArea {
                                        id: editInput
                                        Layout.fillWidth: true; Layout.minimumHeight: 48; Layout.maximumHeight: 100
                                        text: root.editingText; font.pixelSize: 11; font.family: "Inter"
                                        color: root.textColor; wrapMode: Text.WordWrap
                                        background: Rectangle {
                                            color: ColorScheme.withAlpha(ColorScheme.surface, 0.2); radius: DesignTokens.radiusXS
                                            border.width: 1; border.color: root.accentColor
                                        }
                                        onTextChanged: root.editingText = text
                                        onVisibleChanged: if (visible) forceActiveFocus()
                                        Keys.onEscapePressed: root.cancelEditing()
                                    }

                                    RowLayout {
                                        spacing: 6
                                        Rectangle {
                                            width: 48; height: 20; radius: 10
                                            color: saveEditMa.containsMouse ? root.accentColor : ColorScheme.withAlpha(root.accentColor, 0.3)
                                            Text {
                                                anchors.centerIn: parent; text: "Salvar"
                                                font.pixelSize: 8; font.family: "Inter"
                                                color: saveEditMa.containsMouse ? ColorScheme.onPrimary : root.textColor
                                            }
                                            MouseArea { id: saveEditMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.saveEditing() }
                                        }
                                        Text {
                                            text: "Cancelar"
                                            font.pixelSize: 8; font.family: "Inter"
                                            color: root.textColor; opacity: cancelEditMa.containsMouse ? 1.0 : 0.6
                                            MouseArea { id: cancelEditMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cancelEditing() }
                                        }
                                    }
                                }

                                // Quick actions
                                RowLayout {
                                    visible: root.editingNoteId !== modelData.id
                                    spacing: 2; Layout.alignment: Qt.AlignTop

                                    // Convert to Task
                                    Text {
                                        text: "\u{f0ae}"
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                                        color: root.accentColor; opacity: noteToTaskMa.containsMouse ? 1.0 : 0.4
                                        MouseArea { id: noteToTaskMa; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.convertNoteToTask(modelData.id) }
                                    }

                                    Text {
                                        text: modelData.pinned ? "\u{f08d}" : "\u{f08e}"
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                                        color: modelData.pinned ? root.accentColor : root.textColor
                                        opacity: pinMa.containsMouse ? 1.0 : 0.4
                                        MouseArea { id: pinMa; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: QuickNotesService.togglePin(modelData.id) }
                                    }

                                    Text {
                                        text: "\u{f044}"
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                                        color: root.textColor; opacity: noteEditMa.containsMouse ? 1.0 : 0.4
                                        MouseArea { id: noteEditMa; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.startEditing(modelData.id, modelData.text) }
                                    }

                                    Text {
                                        text: "\u{f0c5}"
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                                        color: root.textColor; opacity: noteCopyMa.containsMouse ? 1.0 : 0.4
                                        MouseArea { id: noteCopyMa; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.copyToClipboard(modelData.text) }
                                    }

                                    Text {
                                        text: "\u{f00d}"
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                                        color: ColorScheme.red; opacity: noteDeleteMa.containsMouse ? 1.0 : 0.4
                                        MouseArea { id: noteDeleteMa; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: QuickNotesService.removeNote(modelData.id) }
                                    }
                                }
                            }
                        }

                        // Empty state
                        Text {
                            anchors.centerIn: parent
                            text: "Nenhuma nota ainda\nDigite acima para criar"
                            font.pixelSize: 11; font.family: "Inter"
                            color: root.textColor; opacity: 0.4
                            horizontalAlignment: Text.AlignHCenter
                            visible: QuickNotesService.noteCount === 0
                        }
                    }
                }
            }
        }
    }
}
