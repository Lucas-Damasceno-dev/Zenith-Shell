.pragma library

function parsePowerProfile(text) {
    var value = String(text || "").trim().toLowerCase();
    if (value.indexOf("performance") >= 0)
        return "performance";
    if (value.indexOf("power-saver") >= 0 || value.indexOf("powersaver") >= 0)
        return "power-saver";
    return "balanced";
}
