.pragma library

function _pushLine(lines, text) {
    var value = String(text || "");
    if (value !== "")
        lines.push(value);
}

function summarize(options) {
    var input = options || {};
    var healthChecked = input.healthChecked === true;
    var binaryStatus = input.binaryStatus || {};
    var recoveryState = input.recoveryState || {};
    var sanityIssues = Array.isArray(input.sanityIssues) ? input.sanityIssues.slice(0) : [];
    var lastFailure = input.lastFailure || {};
    var missing = [];

    for (var key in binaryStatus) {
        if (!Object.prototype.hasOwnProperty.call(binaryStatus, key))
            continue;
        if (binaryStatus[key] !== true)
            missing.push(key);
    }

    var lines = [];
    var isLoading = recoveryState.kind === "loading";
    if (recoveryState.kind && recoveryState.kind !== "idle" && recoveryState.kind !== "ready" && !isLoading)
        _pushLine(lines, recoveryState.summary || recoveryState.message || recoveryState.scope || "Recuperação em andamento");

    if (sanityIssues.length > 0)
        _pushLine(lines, "Sanidade: " + sanityIssues.join(", "));

    if (missing.length > 0)
        _pushLine(lines, "Dependências ausentes: " + missing.join(", "));

    if (lastFailure && lastFailure.label) {
        var failureLine = "Falha recente: " + String(lastFailure.label);
        if (lastFailure.exitCode !== undefined && lastFailure.exitCode !== null && lastFailure.exitCode !== "")
            failureLine += " (exit " + String(lastFailure.exitCode) + ")";
        if (lastFailure.message !== undefined && lastFailure.message !== null && String(lastFailure.message).trim() !== "")
            failureLine += " — " + String(lastFailure.message);
        _pushLine(lines, failureLine);
    }

    var degraded = lines.length > 0;
    var level = degraded ? "degraded" : (isLoading ? "loading" : (healthChecked ? "ok" : "idle"));
    var headline = degraded
        ? lines[0]
        : (isLoading
            ? (recoveryState.summary || recoveryState.message || recoveryState.scope || "Verificando saúde")
            : (healthChecked ? "Ambiente saudável" : "Aguardando verificação"));
    var detailLines = lines.length > 1 ? lines.slice(1) : [];

    return {
        level: level,
        headline: headline,
        detail: detailLines.join(" · "),
        missing: missing,
        issues: lines,
        healthChecked: healthChecked
    };
}
