.pragma library

function serviceChecks() {
    return [
        { key: "nmcli", cmd: "nmcli general status >/dev/null 2>&1" },
        { key: "playerctl", cmd: "playerctl --list-all >/dev/null 2>&1" },
        { key: "upower", cmd: "upower -e >/dev/null 2>&1" },
        { key: "wpctl", cmd: "wpctl status >/dev/null 2>&1" }
    ];
}

function checkArgs() {
    var checks = serviceChecks();
    var script = "printf '__SANITY_BEGIN__\\n';";
    for (var i = 0; i < checks.length; i++) {
        var c = checks[i];
        script += "if " + c.cmd + "; then printf '" + c.key + "=1\\n'; else printf '" + c.key + "=0\\n'; fi;";
    }
    script += "printf '__SANITY_END__\\n'";
    return ["bash", "-c", script];
}

function parse(rawText) {
    var status = {};
    var text = String(rawText || "");
    var start = text.indexOf("__SANITY_BEGIN__");
    var end = text.indexOf("__SANITY_END__");
    if (start < 0 || end <= start) return status;

    var payload = text.substring(start + "__SANITY_BEGIN__".length, end);
    var lines = payload.split(/\r?\n/);
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "" || line.indexOf("=") <= 0) continue;
        var idx = line.indexOf("=");
        status[line.substring(0, idx)] = line.substring(idx + 1) === "1";
    }
    return status;
}

function failedKeys(status) {
    var failed = [];
    for (var k in status) {
        if (Object.prototype.hasOwnProperty.call(status, k) && !status[k]) failed.push(k);
    }
    return failed;
}
