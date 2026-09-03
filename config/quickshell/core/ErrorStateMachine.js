.pragma library

function _string(value) {
    if (value === undefined || value === null)
        return "";
    return String(value);
}

function _normalizeKind(kind) {
    var value = _string(kind).trim().toLowerCase();
    if (value === "idle" || value === "loading" || value === "ready" || value === "degraded" || value === "error" || value === "blocked")
        return value;
    return "idle";
}

function _sanitizeText(value, sanitizer) {
    if (typeof sanitizer === "function")
        return sanitizer(value);
    return _string(value).trim();
}

function _composeSummary(scope, message) {
    var left = _string(scope).trim();
    var right = _string(message).trim();
    if (left !== "" && right !== "")
        return left + ": " + right;
    if (left !== "")
        return left;
    return right;
}

function isRecoverableExitCode(exitCode) {
    var code = Number(exitCode);
    if (!isFinite(code) || code < 0)
        return true;
    return code !== 126 && code !== 127;
}

function makeState(kind, scope, message, options) {
    var opts = options || {};
    var sanitizer = typeof opts.sanitizeText === "function" ? opts.sanitizeText : null;
    var normalizedKind = _normalizeKind(kind);
    var safeScope = _sanitizeText(scope, sanitizer);
    var safeMessage = _sanitizeText(message, sanitizer);
    var summary = _composeSummary(safeScope, safeMessage);
    var visible = normalizedKind !== "idle" && normalizedKind !== "ready";
    var recoverable = opts.recoverable !== undefined ? opts.recoverable === true : normalizedKind !== "blocked";

    return {
        kind: normalizedKind,
        scope: safeScope,
        message: safeMessage,
        summary: summary,
        recoverable: recoverable,
        loading: normalizedKind === "loading",
        degraded: normalizedKind === "degraded" || normalizedKind === "error" || normalizedKind === "blocked",
        blocked: normalizedKind === "blocked",
        visible: visible,
        exitCode: opts.exitCode !== undefined ? opts.exitCode : null
    };
}

function idleState(scope, message, options) {
    return makeState("idle", scope || "", message || "", options);
}

function loadingState(scope, message, options) {
    return makeState("loading", scope || "", message || "", options);
}

function readyState(scope, message, options) {
    return makeState("ready", scope || "", message || "", options);
}

function degradedState(scope, message, options) {
    return makeState("degraded", scope || "", message || "", options);
}

function errorState(scope, message, options) {
    return makeState("error", scope || "", message || "", options);
}

function blockedState(scope, message, options) {
    var opts = options || {};
    opts.recoverable = false;
    return makeState("blocked", scope || "", message || "", opts);
}

function stateSummary(state) {
    if (!state)
        return "";
    if (typeof state.summary === "string" && state.summary !== "")
        return state.summary;
    return _composeSummary(state.scope, state.message);
}

function fromFailure(scope, exitCode, message, options) {
    var code = Number(exitCode);
    if (!isFinite(code))
        code = -1;

    var opts = options || {};
    if (opts.recoverable === undefined)
        opts.recoverable = isRecoverableExitCode(code);
    opts.exitCode = code;

    var text = _string(message).trim();
    if (text === "")
        text = code >= 0 ? ("Falhou com exit " + code) : "Falhou";

    return makeState(code === 0 ? "ready" : "error", scope || "", text, opts);
}
