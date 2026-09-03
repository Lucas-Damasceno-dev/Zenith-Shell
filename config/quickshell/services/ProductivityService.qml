pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * ProductivityService - Centralized data for tasks, focus and metrics.
 * Shares data between the Bar and the Productivity Popup.
 */
Singleton {
    id: root

    // ─── Data models ───────────────────────────────────────────
    readonly property alias todoModel: _todoModel
    readonly property alias eventsModel: _eventsModel
    readonly property int todoCount: _todoModel.count
    readonly property int eventCount: _eventsModel.count

    property int pendingTodoCount: 0
    property int completedTodoCount: 0
    property int priorityCount: 0
    property int todayTodoCount: 0
    property int totalTodoPomodoros: 0
    property int todoRevision: 0
    
    ListModel { id: _todoModel }
    ListModel { id: _eventsModel }

    // ─── State ──────────────────────────────────────────────────
    property bool pomodoroRunning: false
    property real timerRemaining: 1500
    property bool pomodoroIsBreak: false
    property string focusedTaskText: ""
    property string focusedTaskId: ""

    // ─── Paths ──────────────────────────────────────────────────
    readonly property string todoFilePath: RuntimePaths.stateFile("calendar-todo.json")
    readonly property string eventsFilePath: RuntimePaths.stateFile("calendar-events.json")
    readonly property string metricsFilePath: RuntimePaths.stateFile("quickshell-focus-metrics.json")
    readonly property string pomodoroMetricsFilePath: RuntimePaths.stateFile("quickshell-productivity-metrics.json")
    property int pomodoroSessionCount: 0

    function todayKey() {
        var d = new Date();
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    function makeId(prefix) {
        return String(prefix || "item") + "-" + Date.now().toString() + "-" + Math.random().toString(36).slice(2, 8);
    }

    function touchTodoRevision() {
        root.todoRevision = root.todoRevision + 1;
    }

    function normalizeDateValue(value) {
        var raw = String(value !== undefined && value !== null ? value : "").trim();
        if (raw === "") return "";
        var match = raw.match(/^(\d{4})-(\d{2})-(\d{2})$/);
        if (!match) return "";
        var y = Number(match[1]);
        var m = Number(match[2]);
        var d = Number(match[3]);
        if (!isFinite(y) || !isFinite(m) || !isFinite(d)) return "";
        if (m < 1 || m > 12 || d < 1 || d > 31) return "";
        var parsed = new Date(y, m - 1, d);
        if (parsed.getFullYear() !== y || (parsed.getMonth() + 1) !== m || parsed.getDate() !== d) return "";
        return match[1] + "-" + match[2] + "-" + match[3];
    }

    function normalizeTimeValue(value) {
        var raw = String(value !== undefined && value !== null ? value : "").trim();
        if (raw === "") return "";
        var match = raw.match(/^(\d{1,2})(?::(\d{2}))?$/);
        if (!match) return "";
        var h = Number(match[1]);
        var min = Number(match[2] !== undefined ? match[2] : "0");
        if (!isFinite(h) || !isFinite(min)) return "";
        if (h < 0 || h > 23 || min < 0 || min > 59) return "";
        return String(h).padStart(2, "0") + ":" + String(min).padStart(2, "0");
    }

    function normalizeTodoItem(item) {
        var source = item || {};
        var text = String(source.text !== undefined ? source.text : (source.task !== undefined ? source.task : "")).trim();
        return {
            id: source.id !== undefined && source.id !== null && String(source.id) !== "" ? String(source.id) : makeId("todo"),
            text: text,
            task: text,
            done: source.done === true,
            date: normalizeDateValue(source.date),
            time: normalizeTimeValue(source.time),
            pomodoros: Number(source.pomodoros || 0) || 0,
            isPriority: source.isPriority === true
        };
    }

    function normalizeEventItem(item) {
        var source = item || {};
        return {
            id: source.id !== undefined && source.id !== null && String(source.id) !== "" ? String(source.id) : makeId("event"),
            title: source.title !== undefined && source.title !== null ? String(source.title) : "",
            date: source.date !== undefined && source.date !== null ? String(source.date) : "",
            hour: source.hour !== undefined && source.hour !== null ? String(source.hour) : "",
            duration: Number(source.duration || 1) || 1
        };
    }

    function refreshTodoStats() {
        var pending = 0;
        var completed = 0;
        var priority = 0;
        var totalPomodoros = 0;
        var today = 0;
        var todayDate = todayKey();

        for (var i = 0; i < _todoModel.count; i++) {
            var item = _todoModel.get(i);
            var done = item.done === true;
            if (done) completed++; else pending++;
            if (item.isPriority && !done) priority++;
            totalPomodoros += Number(item.pomodoros || 0) || 0;
            if (String(item.date || "") === todayDate) today++;
        }

        root.pendingTodoCount = pending;
        root.completedTodoCount = completed;
        root.priorityCount = priority;
        root.totalTodoPomodoros = totalPomodoros;
        root.todayTodoCount = today;
    }

    function updatePriorityCount() {
        refreshTodoStats();
    }

    function findTodoIndex(identifier) {
        if (identifier === undefined || identifier === null || identifier === "") return -1;
        var wanted = String(identifier);
        for (var i = 0; i < _todoModel.count; i++) {
            var item = _todoModel.get(i);
            if (String(i) === wanted) return i;
            if (String(item.id || "") === wanted) return i;
        }
        return -1;
    }

    function updateTodoFields(identifier, fields) {
        var index = findTodoIndex(identifier);
        if (index < 0) return false;

        var keys = Object.keys(fields || {});
        for (var i = 0; i < keys.length; i++) {
            var key = keys[i];
            _todoModel.setProperty(index, key, fields[key]);
        }

        saveTodo();
        return true;
    }

    function addTodo(todo) {
        var item = normalizeTodoItem(todo);
        _todoModel.append(item);
        saveTodo();
        return item.id;
    }

    function removeTodo(identifier) {
        var index = findTodoIndex(identifier);
        if (index < 0) return false;
        _todoModel.remove(index);
        saveTodo();
        return true;
    }

    function setTodoDone(identifier, done) {
        return updateTodoFields(identifier, { done: done === true });
    }

    function setTodoPriority(identifier, isPriority) {
        return updateTodoFields(identifier, { isPriority: isPriority === true });
    }

    function setTodoText(identifier, text) {
        var value = String(text || "").trim();
        return updateTodoFields(identifier, { text: value, task: value });
    }

    function setTodoSchedule(identifier, date, time) {
        return updateTodoFields(identifier, {
            date: normalizeDateValue(date),
            time: normalizeTimeValue(time)
        });
    }

    function incrementTodoPomodoros(identifier, amount) {
        var index = findTodoIndex(identifier);
        if (index < 0) return false;
        var current = Number(_todoModel.get(index).pomodoros || 0) || 0;
        _todoModel.setProperty(index, "pomodoros", current + (amount || 1));
        saveTodo();
        return true;
    }

    function clearTodos() {
        _todoModel.clear();
        saveTodo();
    }

    function addEvent(eventItem) {
        var item = normalizeEventItem(eventItem);
        _eventsModel.append(item);
        saveEvents();
        return item.id;
    }

    function clearEvents() {
        _eventsModel.clear();
        saveEvents();
    }

    function savePomodoroMetrics() {
        var payload = {
            completed_sessions: pomodoroSessionCount,
            count: pomodoroSessionCount,
            pomodoro_count: pomodoroSessionCount,
            pomodoros: pomodoroSessionCount,
            sessions: pomodoroSessionCount,
            total_sessions: pomodoroSessionCount
        };
        var jsonStr = JSON.stringify(payload).replace(/'/g, "'\\''");
        savePomodoroMetricsProc.exec(["sh", "-c", "mkdir -p " + RuntimePaths.stateDir + " && printf '%s' '" + jsonStr + "' > '" + root.pomodoroMetricsFilePath + "'"]);
    }

    function loadPomodoroMetrics() {
        loadPomodoroMetricsProc.exec();
    }

    function recordPomodoroSession() {
        root.pomodoroSessionCount = Math.max(0, Number(root.pomodoroSessionCount || 0) + 1);
        savePomodoroMetrics();
    }

    // ─── Persistence ───────────────────────────────────────────
    function saveTodo() {
        refreshTodoStats();
        touchTodoRevision();
        var items = [];
        for (var i = 0; i < _todoModel.count; i++) {
            var item = _todoModel.get(i);
            items.push({
                id: item.id || makeId("todo"),
                text: item.text || item.task || "",
                task: item.text || item.task || "",
                done: item.done || false,
                date: item.date || "",
                time: item.time || "",
                pomodoros: item.pomodoros || 0,
                isPriority: item.isPriority || false
            });
        }
        var jsonStr = JSON.stringify(items).replace(/'/g, "'\\''");
        saveTodoProc.exec(["sh", "-c", "mkdir -p " + RuntimePaths.stateDir + " && printf '%s' '" + jsonStr + "' > '" + root.todoFilePath + "'"]);
    }

    function loadTodo() {
        loadTodoProc.exec();
    }

    function saveEvents() {
        var items = [];
        for (var i = 0; i < _eventsModel.count; i++) {
            var item = _eventsModel.get(i);
            items.push({
                id: item.id || makeId("event"),
                title: item.title || "",
                date: item.date || "",
                hour: item.hour || "",
                duration: item.duration || 1
            });
        }
        var jsonStr = JSON.stringify(items).replace(/'/g, "'\\''");
        saveEventsProc.exec(["sh", "-c", "mkdir -p " + RuntimePaths.stateDir + " && printf '%s' '" + jsonStr + "' > '" + root.eventsFilePath + "'"]);
    }

    function loadEvents() {
        loadEventsProc.exec();
    }

    TimedProcess { id: saveTodoProc }
    TimedProcess {
        id: loadTodoProc
        command: ["sh", "-c", "cat '" + root.todoFilePath + "' 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var items = JSON.parse(String(text || "[]"));
                    _todoModel.clear();
                    for (var i = 0; i < items.length; i++) {
                        _todoModel.append(normalizeTodoItem(items[i]));
                    }
                    refreshTodoStats();
                    touchTodoRevision();
                } catch(e) { _todoModel.clear(); refreshTodoStats(); touchTodoRevision(); }
            }
        }
    }

    TimedProcess { id: saveEventsProc }
    TimedProcess {
        id: loadEventsProc
        command: ["sh", "-c", "cat '" + root.eventsFilePath + "' 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var items = JSON.parse(String(text || "[]"));
                    _eventsModel.clear();
                    for (var i = 0; i < items.length; i++) {
                        _eventsModel.append(normalizeEventItem(items[i]));
                    }
                } catch(e) { _eventsModel.clear(); }
            }
        }
    }

    TimedProcess { id: savePomodoroMetricsProc }
    TimedProcess {
        id: loadPomodoroMetricsProc
        command: ["sh", "-c", "cat '" + root.pomodoroMetricsFilePath + "' 2>/dev/null || echo '{}' "]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = String(text || "{}").trim();
                    var data = raw ? JSON.parse(raw) : {};
                    var value = 0;
                    var keys = ["completed_sessions", "count", "pomodoro_count", "pomodoros", "sessions", "total_sessions"];
                    for (var i = 0; i < keys.length; i++) {
                        var key = keys[i];
                        if (data && typeof data[key] === "number") { value = data[key]; break; }
                    }
                    root.pomodoroSessionCount = Math.max(0, value);
                } catch (e) {
                    root.pomodoroSessionCount = 0;
                }
            }
        }
    }

    Component.onCompleted: {
        loadTodo();
        loadEvents();
        loadPomodoroMetrics();
    }
}
