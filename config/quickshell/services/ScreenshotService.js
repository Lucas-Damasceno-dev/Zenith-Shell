.pragma library

function _flag(value) {
    return value ? "1" : "0";
}

function _shell() {
    return "bash";
}

function _path(p) {
    var s = String(p || "");
    if (s.indexOf("file:///") === 0) return s.substring(7);
    if (s.indexOf("file://") === 0) return s.substring(7);
    return s;
}

function screenshotArgs(scriptsDir, mode) {
    var sd = _path(scriptsDir);
    var scriptPath = sd ? (sd + "/ui/utility_screenshot.sh") : "utility_screenshot.sh";
    var args = [_shell(), scriptPath, mode || "full"];
    var options = arguments.length > 2 ? (arguments[2] || {}) : {};
    if (options.format) {
        args.push("--format");
        args.push(String(options.format));
    }
    if (options.destination) {
        args.push("--dest");
        args.push(_path(options.destination));
    }
    if (options.template) {
        args.push("--template");
        args.push(String(options.template));
    }
    if (options.copyPathThumb === true) args.push("--copy-path-thumb");
    if (options.annotate === true) args.push("--annotate");
    if (options.delaySec !== undefined && options.delaySec !== null) {
        var delay = Number(options.delaySec);
        if (isFinite(delay) && !isNaN(delay) && delay > 0) {
            args.push("--delay");
            args.push(String(Math.max(1, Math.round(delay))));
        }
    }
    return args;
}

function ocrArgs(scriptsDir, anonymize, lang) {
    var args = [_shell(), _path(scriptsDir) + "/ui/utility_ocr.sh"];
    if (anonymize === true) args.push("--anonymize");
    if (lang && String(lang).trim() !== "") {
        args.push("--lang");
        args.push(String(lang).trim());
    }
    return args;
}

function lensArgs(scriptsDir, anonymize, provider) {
    var args = [_shell(), _path(scriptsDir) + "/ui/utility_lens_search.sh", "--confirm"];
    if (anonymize === true) args.push("--anonymize");
    if (provider && String(provider).trim() !== "") {
        args.push("--provider");
        args.push(String(provider).trim());
    }
    return args;
}

function colorPickArgs(scriptsDir) {
    var args = [_shell(), _path(scriptsDir) + "/ui/utility_color_pick.sh"];
    if (arguments.length > 1 && arguments[1]) {
        args.push(String(arguments[1]));
    }
    return args;
}

function recordStatusArgs(scriptsDir) {
    return [_shell(), _path(scriptsDir) + "/ui/utility_record_toggle.sh", "status"];
}

function recordStopArgs(scriptsDir) {
    return [_shell(), _path(scriptsDir) + "/ui/utility_record_toggle.sh", "stop"];
}

function recordPauseArgs(scriptsDir) {
    return [_shell(), _path(scriptsDir) + "/ui/utility_record_toggle.sh", "pause"];
}

function recordToggleArgs(scriptsDir, mode, micEnabled, systemEnabled, isRecording) {
    if (isRecording) return recordStopArgs(scriptsDir);

    var sd = _path(scriptsDir);
    var cmd = "start-full";
    if (mode === "region") cmd = "start-region";
    else if (mode === "gif") cmd = "start-gif";

    var args = [
        _shell(),
        sd + "/ui/utility_record_toggle.sh",
        cmd,
        "--mic", _flag(micEnabled),
        "--system", _flag(systemEnabled)
    ];
    var options = arguments.length > 5 ? (arguments[5] || {}) : {};
    if (options.container) {
        args.push("--container");
        args.push(String(options.container));
    }
    if (options.codec) {
        args.push("--codec");
        args.push(String(options.codec));
    }
    if (options.fps) {
        args.push("--fps");
        args.push(String(options.fps));
    }
    if (options.quality) {
        args.push("--quality");
        args.push(String(options.quality));
    }
    if (options.destination) {
        args.push("--dest");
        args.push(_path(options.destination));
    }
    if (options.template) {
        args.push("--template");
        args.push(String(options.template));
    }
    return args;
}

function parseRecordStatus(rawText) {
    var status = {
        running: false,
        pid: "",
        mode: "",
        file: "",
        mic: false,
        system: false,
        started: 0,
        duration: 0,
        paused: false
    };

    var lines = String(rawText || "").split(/\r?\n/);
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "" || line.indexOf("=") <= 0) continue;
        var idx = line.indexOf("=");
        var key = line.substring(0, idx);
        var value = line.substring(idx + 1);
        if (key === "paused") status.paused = (value === "1" || value === "true");

        if (key === "running") status.running = value === "1" || value === "true";
        else if (key === "pid") status.pid = value;
        else if (key === "mode") status.mode = value;
        else if (key === "file") status.file = value;
        else if (key === "mic") status.mic = value === "1" || value === "true";
        else if (key === "system") status.system = value === "1" || value === "true";
        else if (key === "started") status.started = parseInt(value) || 0;
        else if (key === "duration") status.duration = parseInt(value) || 0;
    }

    if (!/^[0-9]+$/.test(status.pid || "")) status.pid = "";
    if (status.mode !== "full" && status.mode !== "region") status.mode = "";
    if (status.file && status.file.charAt(0) !== "/") status.file = "";
    if (status.running && status.pid === "") status.running = false;
    if (status.duration < 0) status.duration = 0;

    return status;
}

function normalizeHexColor(rawText) {
    var text = String(rawText || "").trim();
    if (text === "") return "";

    var match = text.match(/#?[0-9a-fA-F]{6,8}/);
    if (!match) return "";
    var color = match[0];
    if (color.charAt(0) !== "#") color = "#" + color;
    return color.toUpperCase();
}

function colorStatusArgs(scriptsDir) {
    return [_shell(), _path(scriptsDir) + "/ui/utility_color_pick.sh", "status"];
}

function captureHistoryArgs(scriptsDir) {
    return [_shell(), _path(scriptsDir) + "/ui/utility_capture_history.sh", "6"];
}

function copyTextArgs(scriptsDir, text, primary) {
    var args = [_shell(), _path(scriptsDir) + "/ui/utility_copy_text.sh"];
    if (primary === true) args.push("--primary");
    args.push(String(text || ""));
    return args;
}
