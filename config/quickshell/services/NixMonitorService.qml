pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * NixMonitorService - Monitors NixOS system state including store size,
 * generations, daemon status, and build activity.
 */
Singleton {
    id: root

    // Store information
    property string storeSize: "..."
    property string storePath: "/nix/store"
    property int storePathCount: 0
    
    // Generation information
    property int currentGeneration: 0
    property string currentGenerationDate: ""
    property int totalGenerations: 0
    
    // Daemon status
    property bool daemonRunning: false
    property bool daemonBusy: false
    property int activeBuilds: 0
    
    // Update status
    property bool updateAvailable: false
    property string lastUpdateCheck: ""
    
    // Garbage collection
    property string gcReclaimable: "..."
    property bool gcRunning: false
    property int refreshTick: 0
    
    // Combined status icon
    readonly property string statusIcon: {
        if (gcRunning) return "\u{f1f8}";  // trash - GC running
        if (activeBuilds > 0) return "\u{f110}";  // spinner - building
        if (updateAvailable) return "\u{f019}";  // download - update available
        if (!daemonRunning) return "\u{f071}";  // warning - daemon not running
        return "\u{f313}";  // nix snowflake
    }
    
    readonly property color statusColor: {
        if (!daemonRunning) return "#f38ba8";  // red
        if (gcRunning) return "#fab387";  // peach
        if (activeBuilds > 0) return "#89b4fa";  // blue
        if (updateAvailable) return "#a6e3a1";  // green
        return "#cdd6f4";  // text
    }
    
    property int refreshInterval: FeatureFlags.lowPowerUiMode ? 600000 : 300000
    readonly property int storeRefreshEvery: FeatureFlags.lowPowerUiMode ? 6 : 4
    readonly property int generationsRefreshEvery: FeatureFlags.lowPowerUiMode ? 3 : 2
    
    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }
    
    function refresh(forceHeavy) {
        var heavy = forceHeavy === true;
        refreshTick += 1;
        checkDaemonStatus();

        if (heavy || storeSize === "..." || (refreshTick % storeRefreshEvery) === 0)
            checkStoreSize();

        if (heavy || currentGeneration <= 0 || (refreshTick % generationsRefreshEvery) === 0)
            checkGenerations();

        checkActiveBuilds();
    }
    
    function checkDaemonStatus() {
        daemonCheckProc.exec(["systemctl", "is-active", "nix-daemon"]);
    }
    
    function checkStoreSize() {
        storeSizeProc.exec(["bash", "-c", "df -h /nix/store 2>/dev/null | awk 'NR==2 {print $3}' || echo 'N/A'"]);
    }
    
    function checkGenerations() {
        generationProc.exec(["bash", "-c", "readlink /nix/var/nix/profiles/system 2>/dev/null | grep -o '[0-9]*' || true"]);
    }
    
    function checkActiveBuilds() {
        buildsProc.exec(["bash", "-c", "pgrep -f 'nix-build|nixos-rebuild|nix build' >/dev/null && echo 1 || echo 0"]);
    }
    
    function runGarbageCollection() {
        if (gcRunning) return;
        gcRunning = true;
        gcProc.exec(["nix-collect-garbage", "-d"]);
    }
    
    function checkGCReclaimable() {
        gcCheckProc.exec(["bash", "-c", "nix-store --gc --print-dead 2>/dev/null | wc -l"]);
    }

    TimedProcess {
        id: daemonCheckProc
        timeoutMs: 5000
        stdout: StdioCollector {
            onStreamFinished: {
                root.daemonRunning = text.trim() === "active";
                root.daemonBusy = root.daemonRunning && root.activeBuilds > 0;
            }
        }
        onFailed: { root.daemonRunning = false; }
    }
    
    TimedProcess {
        id: storeSizeProc
        timeoutMs: 10000
        stdout: StdioCollector {
            onStreamFinished: {
                root.storeSize = text.trim() || "N/A";
            }
        }
    }
    
    TimedProcess {
        id: storeCountProc
        timeoutMs: 10000
        stdout: StdioCollector {
            onStreamFinished: {
                root.storePathCount = parseInt(text.trim()) || 0;
            }
        }
    }
    
    TimedProcess {
        id: generationProc
        timeoutMs: 5000
        stdout: StdioCollector {
            onStreamFinished: {
                var gen = parseInt(text.trim());
                if (!isNaN(gen) && gen > 0) {
                    root.currentGeneration = gen;
                    root.totalGenerations = gen;
                }
            }
        }
    }
    
    TimedProcess {
        id: buildsProc
        timeoutMs: 10000
        stdout: StdioCollector {
            onStreamFinished: {
                root.activeBuilds = parseInt(String(text || "0").trim()) || 0;
                root.daemonBusy = root.daemonRunning && root.activeBuilds > 0;
            }
        }
    }
    
    TimedProcess {
        id: gcProc
        timeoutMs: 300000  // 5 minutes for GC
        stdout: StdioCollector {
            onStreamFinished: {
                root.gcRunning = false;
                root.refresh();  // Refresh after GC
            }
        }
        onFailed: { root.gcRunning = false; }
        onTimedOut: { root.gcRunning = false; }
    }
    
    TimedProcess {
        id: gcCheckProc
        timeoutMs: 30000
        stdout: StdioCollector {
            onStreamFinished: {
                var count = parseInt(text.trim()) || 0;
                if (count > 0) {
                    root.gcReclaimable = count + " paths";
                } else {
                    root.gcReclaimable = "Clean";
                }
            }
        }
    }

    Component.onCompleted: {
        // Defer the first refresh so shell startup and popup creation
        // are not blocked by Nix/NixOS probes.
        Qt.callLater(function() {
            root.refresh(true);
        });
    }
}
