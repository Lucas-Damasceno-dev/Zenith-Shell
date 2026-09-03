pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Item {
    id: root

    property int nightLightValue: 0
    property int grayscaleValue: 0
    readonly property bool nightLightActive: nightLightValue > 0
    readonly property bool grayscaleActive: grayscaleValue > 0

    property int _appliedNight: -1
    property int _appliedGray: -1

    function setNightLight(value) {
        var v = Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
        if (root.nightLightValue === v) return;
        root.nightLightValue = v;
        flushTimer.restart();
    }

    function setGrayscale(value) {
        var v = Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
        if (root.grayscaleValue === v) return;
        root.grayscaleValue = v;
        flushTimer.restart();
    }

    function stepNightLight(delta) {
        setNightLight(root.nightLightValue + delta);
    }

    function stepGrayscale(delta) {
        setGrayscale(root.grayscaleValue + delta);
    }

    function toggleNightLight() {
        setNightLight(root.nightLightActive ? 0 : 50);
    }

    function toggleGrayscale() {
        setGrayscale(root.grayscaleActive ? 0 : 70);
    }

    function refresh() {
        readStateProc.exec([
            "bash",
            RuntimePaths.scriptFile("shader_intensity.sh"),
            "get-all"
        ]);
    }

    Timer {
        id: flushTimer
        interval: 35
        repeat: false
        onTriggered: {
            root._flush();
        }
    }

    function _flush() {
        if (setProc.running) return;
        if (root.nightLightValue === root._appliedNight && root.grayscaleValue === root._appliedGray) return;

        root._appliedNight = root.nightLightValue;
        root._appliedGray = root.grayscaleValue;

        var script = RuntimePaths.scriptFile("shader_intensity.sh");
        Logger.info("ScreenFilterService", "setting shaders", {
            night: root.nightLightValue,
            gray: root.grayscaleValue,
            script: script
        });
        setProc.exec([
            "bash",
            script,
            "set-all",
            String(root.nightLightValue),
            String(root.grayscaleValue)
        ]);
    }

    TimedProcess {
        id: setProc
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "")
                    console.log("[ScreenFilterService] stderr:", text.trim());
            }
        }
        onExited: function(exitCode) {
            if (root.nightLightValue !== root._appliedNight || root.grayscaleValue !== root._appliedGray) {
                root._flush();
            }
        }
    }

    TimedProcess {
        id: readStateProc
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("=");
                    if (parts.length === 2) {
                        var k = parts[0].trim();
                        var val = parseInt(parts[1].trim());
                        if (!isNaN(val)) {
                            if (k === "night-light" && !flushTimer.running && !setProc.running) {
                                root.nightLightValue = Math.max(0, Math.min(100, val));
                                root._appliedNight = root.nightLightValue;
                            } else if (k === "grayscale" && !flushTimer.running && !setProc.running) {
                                root.grayscaleValue = Math.max(0, Math.min(100, val));
                                root._appliedGray = root.grayscaleValue;
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        refresh();
    }
}
