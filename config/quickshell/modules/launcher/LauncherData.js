.pragma library

function snippetLibrary(runtimePaths) {
    return [
    { name: "Quickshell Restart", cmd: "systemctl --user restart quickshell.service", tags: "quickshell restart reload", icon: "\u{f021}" },
    { name: "Quickshell Logs", cmd: "journalctl --user -u quickshell --no-pager -n 150", tags: "quickshell logs debug journal", icon: "\u{f15c}" },
    { name: "Quickshell Doctor", cmd: runtimePaths.scriptFile("quickshell_doctor.sh"), tags: "quickshell doctor healthcheck qa", icon: "\u{f0f0}" },
    { name: "Hyprland Reload", cmd: "hyprctl reload", tags: "hyprland reload config wm", icon: "\u{f021}" },
    { name: "Hyprland Clients", cmd: "hyprctl clients -j | jq '.[].title'", tags: "hyprland windows clients list", icon: "\u{f2d0}" },
    { name: "Refresh Wallpaper & Theme", cmd: runtimePaths.hyprScriptFile("random-wallpaper.sh") + " --reapply", tags: "theme matugen wallpaper refresh", icon: "\u{f53f}" },
    { name: "Next Wallpaper", cmd: runtimePaths.hyprScriptFile("random-wallpaper.sh") + " --next", tags: "wallpaper next theme", icon: "\u{f03e}" },
    { name: "Disk Usage", cmd: "df -h / /home 2>/dev/null | column -t", tags: "disk usage space storage df", icon: "\u{f0a0}" },
    { name: "Network Status", cmd: "nmcli device status 2>/dev/null || ip -brief addr", tags: "network wifi nmcli ip status", icon: "\u{f1eb}" },
    { name: "PipeWire Status", cmd: "wpctl status", tags: "audio pipewire wireplumber status", icon: "\u{f028}" },
    { name: "Systemd Failed Units", cmd: "systemctl --user --failed 2>/dev/null", tags: "systemd failed services errors", icon: "\u{f071}" },
    { name: "Journal Errors", cmd: "journalctl -p err -b --no-pager -n 30", tags: "journal errors log boot current", icon: "\u{f06a}" },
    { name: "Kill Process", cmd: "pkill -f ", tags: "kill process pkill terminate", icon: "\u{f00d}" }
    ];
}
