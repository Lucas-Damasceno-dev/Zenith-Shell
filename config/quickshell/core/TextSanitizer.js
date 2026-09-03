.pragma library

function _string(value) {
    if (value === undefined || value === null)
        return "";
    return String(value);
}

function _isSpaceCode(code) {
    return code === 9 || code === 10 || code === 11 || code === 12 || code === 13 || code === 32 || code === 160;
}

function _isControlCode(code) {
    return (code < 32 && code !== 9 && code !== 10 && code !== 13) || code === 127;
}

function _trimRight(text) {
    var source = _string(text);
    var end = source.length;
    while (end > 0) {
        var code = source.charCodeAt(end - 1);
        if (code === 32 || code === 9 || code === 13)
            end--;
        else
            break;
    }
    return source.substring(0, end);
}

function _trimLeft(text) {
    var source = _string(text);
    var start = 0;
    while (start < source.length) {
        var code = source.charCodeAt(start);
        if (code === 32 || code === 9)
            start++;
        else
            break;
    }
    return source.substring(start);
}

function _isTokenCode(code) {
    return (code >= 48 && code <= 57)
        || (code >= 65 && code <= 90)
        || (code >= 97 && code <= 122)
        || code === 95
        || code === 45
        || code === 46
        || code === 58;
}

function _isBoxDrawingLine(line) {
    var text = _trimRight(line);
    if (text === "")
        return false;

    var seen = false;
    for (var i = 0; i < text.length; i++) {
        var code = text.charCodeAt(i);
        if (code === 32 || code === 9)
            continue;
        if (code < 0x2500 || code > 0x257f)
            return false;
        seen = true;
    }
    return seen;
}

function _looksLikePromptLine(line) {
    var text = _trimLeft(_trimRight(line));
    if (text === "" || text.charAt(0) !== ">")
        return false;

    var i = 1;
    while (i < text.length && _isSpaceCode(text.charCodeAt(i)))
        i++;

    var tokenStart = i;
    while (i < text.length && _isTokenCode(text.charCodeAt(i)))
        i++;
    if (i === tokenStart)
        return false;

    while (i < text.length && _isSpaceCode(text.charCodeAt(i)))
        i++;

    var secondStart = i;
    while (i < text.length && _isTokenCode(text.charCodeAt(i)))
        i++;
    if (i > secondStart) {
        while (i < text.length && _isSpaceCode(text.charCodeAt(i)))
            i++;
    }

    return i < text.length && text.charAt(i) === "·";
}

function cleanSingleLineText(text) {
    var source = _string(text);
    if (source === "")
        return "";

    var out = "";
    var pendingSpace = false;

    for (var i = 0; i < source.length; i++) {
        var code = source.charCodeAt(i);
        if (_isControlCode(code))
            continue;
        if (_isSpaceCode(code)) {
            pendingSpace = out !== "";
            continue;
        }
        if (pendingSpace && out !== "")
            out += " ";
        pendingSpace = false;
        out += source.charAt(i);
    }

    return out.trim();
}

function cleanMultilineText(text) {
    var source = _string(text);
    if (source === "")
        return "";

    var lines = [];
    var current = "";

    for (var i = 0; i < source.length; i++) {
        var code = source.charCodeAt(i);
        if (code === 13)
            continue;
        if (code === 10) {
            lines.push(_trimRight(current));
            current = "";
            continue;
        }
        if (code === 9) {
            current += " ";
            continue;
        }
        if (_isControlCode(code))
            continue;
        current += source.charAt(i);
    }
    lines.push(_trimRight(current));

    var output = [];
    var seenContent = false;
    var blankRun = 0;

    for (var j = 0; j < lines.length; j++) {
        var line = lines[j];
        if (line === "") {
            if (seenContent)
                blankRun++;
            continue;
        }

        seenContent = true;
        if (blankRun > 2)
            blankRun = 2;
        while (blankRun > 0) {
            output.push("");
            blankRun--;
        }
        output.push(line);
    }

    while (output.length > 0 && output[0] === "")
        output.shift();
    while (output.length > 0 && output[output.length - 1] === "")
        output.pop();

    return output.join("\n");
}

function cleanAiResponseText(text) {
    var normalized = cleanMultilineText(text);
    if (normalized === "")
        return "";

    var lines = normalized.split("\n");
    var output = [];
    var seenContent = false;
    var blankRun = 0;

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (_looksLikePromptLine(line) || _isBoxDrawingLine(line))
            continue;

        if (line === "") {
            if (seenContent)
                blankRun++;
            continue;
        }

        seenContent = true;
        if (blankRun > 2)
            blankRun = 2;
        while (blankRun > 0) {
            output.push("");
            blankRun--;
        }
        output.push(line);
    }

    while (output.length > 0 && output[0] === "")
        output.shift();
    while (output.length > 0 && output[output.length - 1] === "")
        output.pop();

    return output.join("\n");
}
