pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * QuickNotesService - Manages quick notes with persistence
 * Notes are saved to RuntimePaths.appDataFile("notes.json")
 */
Singleton {
    id: root

    // Public properties
    readonly property var notes: _notes
    readonly property int noteCount: _notes.length

    // Private state
    property var _notes: []
    property bool _loaded: false
    property string _notesPath: ""

    // Signals
    signal noteAdded(var note)
    signal noteRemoved(string noteId)

    function addNote(text, color) {
        if (!text || text.trim() === "") return;
        
        var note = {
            id: Date.now().toString(),
            text: text.trim(),
            color: color || "default",
            created: Date.now(),
            pinned: false
        };
        
        _notes = [note].concat(_notes);
        saveNotes();
        noteAdded(note);
        notesChanged();
    }

    function removeNote(noteId) {
        _notes = _notes.filter(function(n) { return n.id !== noteId; });
        saveNotes();
        noteRemoved(noteId);
        notesChanged();
    }

    function updateNote(noteId, newText) {
        for (var i = 0; i < _notes.length; i++) {
            if (_notes[i].id === noteId) {
                _notes[i].text = newText;
                _notes[i].modified = Date.now();
                break;
            }
        }
        _notes = _notes.slice(); // Trigger binding update
        saveNotes();
        notesChanged();
    }

    function togglePin(noteId) {
        for (var i = 0; i < _notes.length; i++) {
            if (_notes[i].id === noteId) {
                _notes[i].pinned = !_notes[i].pinned;
                break;
            }
        }
        // Sort: pinned first, then by creation date
        _notes = _notes.slice().sort(function(a, b) {
            if (a.pinned && !b.pinned) return -1;
            if (!a.pinned && b.pinned) return 1;
            return b.created - a.created;
        });
        saveNotes();
        notesChanged();
    }

    function moveNote(fromIndex, toIndex) {
        if (fromIndex < 0 || fromIndex >= _notes.length) return;
        if (toIndex < 0 || toIndex >= _notes.length) return;
        if (fromIndex === toIndex) return;
        
        var newNotes = _notes.slice();
        var note = newNotes.splice(fromIndex, 1)[0];
        newNotes.splice(toIndex, 0, note);
        _notes = newNotes;
        saveNotes();
        notesChanged();
    }

    function clearAll() {
        _notes = [];
        saveNotes();
        notesChanged();
    }

    function saveNotes() {
        if (!_notesPath) return;
        var json = JSON.stringify(_notes, null, 2);
        saveProc.exec([
            "bash", "-lc",
            "dir=$(dirname \"${1}\") && mkdir -p \"$dir\" && printf '%s' \"${2}\" > \"${1}\"",
            "--", _notesPath, json
        ]);
    }

    function loadNotes() {
        if (_loaded || !_notesPath) return;
        loadProc.exec(["bash", "-c", "cat '" + _notesPath + "' 2>/dev/null || echo '[]'"]);
    }

    TimedProcess {
        id: saveProc
        timeoutMs: 3000
        timeoutLabel: "SaveNotes"
    }

    TimedProcess {
        id: loadProc
        timeoutMs: 3000
        timeoutLabel: "LoadNotes"
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text.trim());
                    if (Array.isArray(parsed)) {
                        root._notes = parsed;
                        root._loaded = true;
                        root.notesChanged();
                    }
                } catch (e) {
                    Logger.warn("QuickNotesService", "Failed to parse notes: " + e);
                    root._notes = [];
                    root._loaded = true;
                }
            }
        }
    }

    Component.onCompleted: {
        _notesPath = RuntimePaths.appDataFile("notes.json");
        loadNotes();
    }
}
