pragma Singleton
import QtQuick

QtObject {
    id: root

    property bool debugEnabled: true
    property int flushIntervalMs: 5000
    property int maxBatchSize: 32
    property var _pendingEntries: []

    property Timer flushTimer: Timer {
        interval: root.flushIntervalMs
        repeat: true
        running: false
        onTriggered: root.flush()
    }

    function _stringify(details) {
        if (details === undefined || details === null)
            return "";
        if (typeof details === "string")
            return details;
        try {
            return JSON.stringify(details);
        } catch (e) {
            return String(details);
        }
    }

    function _levelRank(level) {
        if (level === "ERROR")
            return 3;
        if (level === "WARN")
            return 2;
        if (level === "INFO")
            return 1;
        return 0;
    }

    function _formatEntry(entry) {
        var prefix = "[" + String(entry.scope || "App") + "][" + String(entry.level || "INFO") + "]";
        var text = String(entry.message || "");
        if (entry.details !== "")
            text += " " + entry.details;
        return prefix + " " + text;
    }

    function _batchMethod(batch) {
        var highest = 0;
        for (var i = 0; i < batch.length; i++)
            highest = Math.max(highest, _levelRank(batch[i].level));
        if (highest >= 3)
            return "error";
        if (highest >= 2)
            return "warn";
        return "log";
    }

    function _writeBatch(batch) {
        var lines = [];
        for (var i = 0; i < batch.length; i++)
            lines.push(_formatEntry(batch[i]));

        var text = lines.join("\n");
        var method = _batchMethod(batch);
        if (method === "error")
            console.error(text);
        else if (method === "warn")
            console.warn(text);
        else
            console.log(text);
    }

    function _queue(level, scope, message, details) {
        if (level === "DEBUG" && !debugEnabled)
            return;

        _pendingEntries.push({
            level: level,
            scope: scope || "App",
            message: String(message || ""),
            details: _stringify(details)
        });

        if (!flushTimer.running)
            flushTimer.start();

        if (_pendingEntries.length >= maxBatchSize)
            flush();
    }

    function flush() {
        if (_pendingEntries.length === 0) {
            flushTimer.stop();
            return;
        }

        var batch = _pendingEntries.slice(0);
        _pendingEntries = [];
        _writeBatch(batch);

        if (_pendingEntries.length === 0)
            flushTimer.stop();
    }

    function debug(scope, message, details) {
        _queue("DEBUG", scope, message, details);
    }

    function info(scope, message, details) {
        _queue("INFO", scope, message, details);
    }

    function warn(scope, message, details) {
        _queue("WARN", scope, message, details);
    }

    function error(scope, message, details) {
        _queue("ERROR", scope, message, details);
    }

    Component.onDestruction: {
        // Stop timer first to prevent race condition during teardown
        flushTimer.stop();
        // Synchronous flush of any remaining entries
        flush();
    }
}
