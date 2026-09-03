pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../core"

/**
 * KeyboardLayoutService - Monitors and switches keyboard layouts
 * Integrates with Hyprland's keyboard layout system
 */
Singleton {
    id: root

    readonly property string currentLayout: _currentLayout
    readonly property string currentLayoutShort: _currentLayoutShort
    readonly property var availableLayouts: _availableLayouts
    readonly property int layoutCount: _availableLayouts.length

    property string _currentLayout: "us"
    property string _currentLayoutShort: "US"
    property var _availableLayouts: []
    property bool _refreshInFlight: false
    property bool _refreshQueued: false

    readonly property var layoutNames: ({
        "us": "English (US)",
        "br": "Portuguese (Brazil)",
        "pt": "Portuguese (Portugal)",
        "de": "German",
        "fr": "French",
        "es": "Spanish",
        "it": "Italian",
        "ru": "Russian",
        "jp": "Japanese",
        "kr": "Korean",
        "cn": "Chinese",
        "gb": "English (UK)",
        "latam": "Spanish (Latin America)",
        "dvorak": "Dvorak",
        "colemak": "Colemak"
    })

    readonly property var layoutFlags: ({
        "us": "\u{1f1fa}\u{1f1f8}",
        "br": "\u{1f1e7}\u{1f1f7}",
        "pt": "\u{1f1f5}\u{1f1f9}",
        "de": "\u{1f1e9}\u{1f1ea}",
        "fr": "\u{1f1eb}\u{1f1f7}",
        "es": "\u{1f1ea}\u{1f1f8}",
        "it": "\u{1f1ee}\u{1f1f9}",
        "ru": "\u{1f1f7}\u{1f1fa}",
        "jp": "\u{1f1ef}\u{1f1f5}",
        "kr": "\u{1f1f0}\u{1f1f7}",
        "cn": "\u{1f1e8}\u{1f1f3}",
        "gb": "\u{1f1ec}\u{1f1e7}",
        "latam": "\u{1f30e}"
    })

    signal layoutChanged(string layout)

    function getLayoutName(code) {
        return layoutNames[code] || code.toUpperCase();
    }

    function getLayoutFlag(code) {
        return layoutFlags[code] || "\u{2328}";
    }

    function switchToLayout(layout) {
        Hyprland.dispatch("switchxkblayout all " + layout);
        requestRefresh();
    }

    function nextLayout() {
        if (_availableLayouts.length < 2) return;
        
        var currentIdx = -1;
        for (var i = 0; i < _availableLayouts.length; i++) {
            if (_availableLayouts[i].code === _currentLayout) {
                currentIdx = i;
                break;
            }
        }
        
        var nextIdx = (currentIdx + 1) % _availableLayouts.length;
        Hyprland.dispatch("switchxkblayout all next");
        requestRefresh();
    }

    function requestRefresh() {
        if (_refreshInFlight) {
            _refreshQueued = true;
            return;
        }
        refreshDebounce.restart();
    }

    function scheduleRefreshForEvent(eventName) {
        var n = String(eventName || "");
        if (n === "")
            return;
        if (n === "activelayout" || n === "configreloaded" || n.indexOf("layout") >= 0)
            requestRefresh();
    }

    function refresh() {
        if (_refreshInFlight) {
            _refreshQueued = true;
            return;
        }
        _refreshInFlight = true;
        _refreshQueued = false;
        refreshProc.exec(["bash", "-c", `
            # Get current layout from hyprctl
            current=$(hyprctl devices -j 2>/dev/null | jq -r '
                ([.keyboards[]? | select(.main == true) | .active_keymap][0]) // .keyboards[0]?.active_keymap // "us"
            ' | tr '[:upper:]' '[:lower:]' | cut -d'(' -f1 | tr -d ' ')
            
            # Get configured layouts from hyprland config
            layouts=$(hyprctl getoption input:kb_layout -j 2>/dev/null | jq -r '.str // "us"')
            
            echo "current=$current"
            echo "layouts=$layouts"
        `]);
    }

    TimedProcess {
        id: refreshProc
        timeoutMs: 3000
        timeoutLabel: "KeyboardLayout"
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var current = "us";
                var layouts = "us";
                
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (line.startsWith("current=")) {
                        current = line.substring(8).trim();
                    } else if (line.startsWith("layouts=")) {
                        layouts = line.substring(8).trim();
                    }
                }
                
                // Parse current layout
                root._currentLayout = current.split(",")[0].trim();
                root._currentLayoutShort = root._currentLayout.toUpperCase().substring(0, 2);
                
                // Parse available layouts
                var layoutList = layouts.split(",");
                root._availableLayouts = layoutList.map(function(l) {
                    var code = l.trim();
                    return {
                        code: code,
                        name: root.getLayoutName(code),
                        flag: root.getLayoutFlag(code),
                        short: code.toUpperCase().substring(0, 2)
                    };
                });
                
                root.layoutChanged(root._currentLayout);
            }
        }
        onExited: {
            root._refreshInFlight = false;
            if (root._refreshQueued) {
                root._refreshQueued = false;
                refreshDebounce.restart();
            }
        }
    }

    Timer {
        id: refreshDebounce
        interval: FeatureFlags.lowPowerUiMode ? 220 : 120
        running: false
        repeat: false
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            root.scheduleRefreshForEvent(event && event.name ? event.name : "");
        }
    }

    Component.onCompleted: {
        root.requestRefresh();
    }
}
