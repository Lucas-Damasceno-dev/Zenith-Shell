.pragma library

function clampRatio(value, maxRatio) {
    var maxValue = Number(maxRatio || 1.5);
    if (!isFinite(maxValue) || maxValue <= 0) maxValue = 1.5;
    var ratio = Number(value || 0);
    if (!isFinite(ratio) || isNaN(ratio)) ratio = 0;
    return Math.max(0, Math.min(ratio, maxValue));
}

function safeVolume(audioObj) {
    if (!audioObj) return 0;
    return Math.round(clampRatio(audioObj.volume, 1.5) * 100);
}

function isMonitorSource(s) {
    if (!s) return false;
    var desc = String(s.description || "").toLowerCase().trim();
    var name = String(s.name || "").toLowerCase().trim();
    if (desc.startsWith("monitor of") || desc.startsWith("monitor de") || desc.indexOf("monitor") === 0)
        return true;
    if (name.endsWith(".monitor") || name.indexOf(".monitor.") >= 0 || name.startsWith("monitor of") || name.startsWith("monitor de"))
        return true;
    return false;
}

function volumeIcon(vol, muted) {
    if (muted) return "\u{f0580}";
    if (vol > 66) return "\u{f028}";
    if (vol > 33) return "\u{f027}";
    if (vol > 0) return "\u{f026}";
    return "\u{f0580}";
}

function parseWpctlStatus(rawText) {
    var lines = String(rawText || "").split(/\r?\n/);
    var sinks = [];
    var sources = [];
    var section = "";
    var inAudio = false;
    var hasAudioHeader = lines.some(function(l) { return l.indexOf("Audio") === 0; });

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (line.indexOf("Audio") === 0) {
            inAudio = true;
            continue;
        }
        if (line.indexOf("Video") === 0 || line.indexOf("Settings") === 0) {
            inAudio = false;
            section = "";
            break;
        }
        if (hasAudioHeader && !inAudio) {
            continue;
        }

        if (line.indexOf("Sinks:") >= 0) {
            section = "sink";
            continue;
        }
        if (line.indexOf("Sources:") >= 0) {
            section = "source";
            continue;
        }
        if (line.indexOf("Filters:") >= 0 || line.indexOf("Streams:") >= 0) {
            section = "";
            continue;
        }
        if (section === "") continue;

        var m = line.match(/^\s*[│|]?\s*(\*\s*)?(\d+)\.\s+(.*?)(?:\s+\[vol:\s*([0-9.]+)(?:\s+(MUTED))?\])?\s*$/);
        if (!m) continue;

        var isDefault = !!(m[1] && m[1].trim().length > 0);
        var idNum = Number(m[2]);
        var name = String(m[3] || "").trim();
        var vol = Number(m[4]);
        if (!isFinite(vol)) vol = 0;
        var muted = String(m[5] || "") === "MUTED";

        var entry = {
            __cli: true,
            id: idNum,
            name: name,
            description: name,
            default: isDefault,
            volume: clampRatio(vol, 1.5),
            muted: muted
        };

        if (section === "sink") sinks.push(entry);
        else if (section === "source" && !isMonitorSource(entry)) sources.push(entry);
    }

    if (sinks.length > 0 && !sinks.some(function(s) {
        return s.default === true;
    })) sinks[0].default = true;
    if (sources.length > 0 && !sources.some(function(s) {
        return s.default === true;
    })) sources[0].default = true;

    return {
        sinks: sinks,
        sources: sources
    };
}

function defaultCliDevice(devices) {
    if (!devices || devices.length === 0) return null;
    for (var i = 0; i < devices.length; i++) {
        if (devices[i] && devices[i].default === true) return devices[i];
    }
    return devices[0] || null;
}

function canUsePipewireControl(pipewireReady, pipewireNode) {
    if (!pipewireReady || !pipewireNode || !pipewireNode.audio) return false;
    var v = pipewireNode.audio.volume;
    return typeof v === "number" && !isNaN(v) && isFinite(v);
}

function sinkPercent(pipewireEnabled, pipewireAudio, cliSink) {
    if (pipewireEnabled) return safeVolume(pipewireAudio);
    return cliSink ? Math.round(clampRatio(cliSink.volume, 1.5) * 100) : 0;
}

function sourcePercent(pipewireEnabled, pipewireAudio, cliSource) {
    if (pipewireEnabled) return safeVolume(pipewireAudio);
    return cliSource ? Math.round(clampRatio(cliSource.volume, 1.5) * 100) : 0;
}

function sinkMutedState(pipewireEnabled, pipewireAudio, cliSink) {
    if (pipewireEnabled && pipewireAudio) return pipewireAudio.muted === true;
    return cliSink ? cliSink.muted === true : false;
}

function sourceMutedState(pipewireEnabled, pipewireAudio, cliSource) {
    if (pipewireEnabled && pipewireAudio) return pipewireAudio.muted === true;
    return cliSource ? cliSource.muted === true : false;
}

function realSourcesOrFallback(pipewireSources, hasPipewireSources, cliSources) {
    if (hasPipewireSources && pipewireSources) {
        var filtered = [];
        for (var i = 0; i < pipewireSources.length; i++) {
            var s = pipewireSources[i];
            if (s && s.audio && !isMonitorSource(s))
                filtered.push(s);
        }
        if (filtered.length > 0) return filtered;
    }
    return cliSources || [];
}
