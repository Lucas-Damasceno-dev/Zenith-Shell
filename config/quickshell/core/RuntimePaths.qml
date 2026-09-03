pragma Singleton
import QtQuick
import QtCore

QtObject {
    function cleanPath(value) {
        var text = String(value || "");
        if (text.indexOf("file://") === 0)
            text = text.substring(7);
        return text;
    }

    function locationPath(location, fallback) {
        var path = cleanPath(StandardPaths.writableLocation(location).toString());
        if (path === "" && fallback !== undefined)
            return fallback;
        return path;
    }

    function joinPath(base, name) {
        var left = String(base || "");
        var right = String(name || "");
        if (left === "") return right;
        if (right === "") return left;
        if (left.charAt(left.length - 1) === "/")
            return left + right;
        return left + "/" + right;
    }

    readonly property string homeDir: locationPath(StandardPaths.HomeLocation)
    readonly property string configDir: locationPath(StandardPaths.ConfigLocation, joinPath(homeDir, ".config"))
    readonly property string appDataDir: locationPath(StandardPaths.AppLocalDataLocation, joinPath(homeDir, ".local/share"))
    readonly property string genericCacheDir: locationPath(StandardPaths.GenericCacheLocation, joinPath(homeDir, ".cache"))
    readonly property string runtimeDir: {
        var base = locationPath(StandardPaths.RuntimeLocation, "/tmp");
        return joinPath(base, "quickshell");
    }
    readonly property string stateDir: joinPath(homeDir, ".local/state/quickshell")
    readonly property string cacheDir: joinPath(genericCacheDir, "quickshell")
    readonly property string picturesDir: locationPath(StandardPaths.PicturesLocation, joinPath(homeDir, "Pictures"))
    readonly property string moviesDir: locationPath(StandardPaths.MoviesLocation, joinPath(homeDir, "Videos"))
    readonly property string documentsDir: locationPath(StandardPaths.DocumentsLocation, joinPath(homeDir, "Documents"))
    readonly property string downloadsDir: locationPath(StandardPaths.DownloadLocation, joinPath(homeDir, "Downloads"))
    readonly property string desktopDir: locationPath(StandardPaths.DesktopLocation, joinPath(homeDir, "Desktop"))
    readonly property string quickshellDir: joinPath(configDir, "quickshell")
    readonly property string quickshellScriptsDir: joinPath(quickshellDir, "scripts")
    readonly property string hyprScriptsDir: joinPath(configDir, "hypr/scripts")

    function scriptCategory(name) {
        var script = String(name || "");
        if (script === "runtime_paths.sh") return "lib";
        if (script === "context_daemon.py" || script === "context_daemon_v2.py" || script === "send_command.sh" || script === "usb_eject_daemon.sh") return "daemon";
        if (script.indexOf("quickshell_") === 0) return "ops";
        if (script.indexOf("launcher_") === 0 || script === "unicode_lookup.sh" || script === "fetch_cheatsheets.sh" || script === "get_cheatsheets.py" || script === "launcher_frecency_load.py") return "launcher";
        if (script.indexOf("utility_") === 0 || script.indexOf("shader_") === 0 || script === "presentation_mode.sh" || script === "low_power_mode_apply.sh" || script === "ensure_runtime_dirs.sh") return "ui";
        if (script.indexOf("privacy_") === 0 || script.indexOf("dashboard_") === 0 || script.indexOf("system_") === 0 || script.indexOf("system_monitor_") === 0 || script.indexOf("network_") === 0 || script.indexOf("focus_metrics_") === 0 || script.indexOf("playerctl_") === 0 || script.indexOf("perf_budget_") === 0 || script.indexOf("battery_") === 0 || script.indexOf("net_") === 0 || script === "disk_usage.sh" || script === "error_log_snapshot.sh" || script === "extended_metrics.sh" || script === "read_focus_metrics.sh" || script === "usb_devices.sh") return "system";
        if (script.indexOf("fetch_lyrics") === 0) return "media";
        return "";
    }

    function runtimeFile(name) {
        return joinPath(runtimeDir, name);
    }

    function stateFile(name) {
        return joinPath(stateDir, name);
    }

    function appDataFile(name) {
        return joinPath(appDataDir, name);
    }

    function cacheFile(name) {
        return joinPath(cacheDir, name);
    }

    function configFile(name) {
        return joinPath(configDir, name);
    }

    function scriptFile(name) {
        var category = scriptCategory(name);
        if (category !== "")
            return joinPath(joinPath(quickshellScriptsDir, category), name);
        return joinPath(quickshellScriptsDir, name);
    }

    function hyprScriptFile(name) {
        return joinPath(hyprScriptsDir, name);
    }
}
