.pragma library

function isActiveFlag(flag) {
    var token = String(flag || "").trim().toLowerCase();
    return token === "yes" || token === "sim" || token === "true" || token === "active" || token === "*";
}

function isEnabledToken(flag) {
    var token = String(flag || "").trim().toLowerCase();
    return token === "enabled" || token === "habilitado" || token === "on" || token === "1" || token === "true" || token === "sim" || token === "yes";
}

function splitNmcliLine(line, expectedParts) {
    var src = String(line || "");
    var parts = [];
    var current = "";
    var escaping = false;
    for (var i = 0; i < src.length; i++) {
        var ch = src.charAt(i);
        if (escaping) {
            current += ch;
            escaping = false;
            continue;
        }
        if (ch === "\\") {
            escaping = true;
            continue;
        }
        if (ch === ":" && (expectedParts <= 0 || parts.length < (expectedParts - 1))) {
            parts.push(current);
            current = "";
            continue;
        }
        current += ch;
    }
    parts.push(current);
    return parts;
}

function parseWifiRows(rawText) {
    var lines = String(rawText || "").trim().split(/\r?\n/);
    var networks = [];
    var wifiSSID = "";
    var wifiSignal = 0;
    for (var i = 0; i < lines.length; i++) {
        var parts = splitNmcliLine(lines[i], 4);
        if (parts.length < 4) continue;
        var active = isActiveFlag(parts[0]);
        var ssid = parts[1] || "";
        var signal = parseInt(parts[2]) || 0;
        var security = parts.slice(3).join(":");
        if (ssid === "") continue;
        networks.push({ ssid: ssid, signal: signal, active: active, security: security });
        if (active) {
            wifiSSID = ssid;
            wifiSignal = signal;
        }
    }
    return {
        wifiNetworks: networks,
        wifiSSID: wifiSSID,
        wifiSignal: wifiSignal
    };
}

function parseSavedWifiRows(rawText) {
    var lines = String(rawText || "").split(/\r?\n/);
    var items = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "") continue;
        var parts = splitNmcliLine(line, 3);
        if (parts.length < 3) continue;
        var type = parts[parts.length - 1];
        if (type !== "802-11-wireless" && type !== "wifi") continue;
        var priority = parseInt(parts[parts.length - 2]);
        var name = parts.slice(0, parts.length - 2).join(":");
        items.push({ name: name, priority: isNaN(priority) ? 0 : priority });
    }
    return items;
}

function parseBtRows(rawText) {
    var lines = String(rawText || "").trim().split(/\r?\n/);
    var devices = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "") continue;
        var p = line.split("|");
        if (p.length < 6) continue;
        devices.push({
            mac: String(p[0] || "").trim(),
            name: String(p[1] || "").trim(),
            paired: isActiveFlag(p[2]),
            connected: isActiveFlag(p[3]),
            icon: String(p[4] || "").trim(),
            battery: String(p[5] || "").trim()
        });
    }
    return devices;
}

function parseNetDetails(rawText) {
    var lines = String(rawText || "").split(/\r?\n/);
    var dns = [];
    var gateway = "";
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (line.indexOf("IP4.GATEWAY:") === 0) {
            gateway = line.substring("IP4.GATEWAY:".length).trim();
        } else if (line.indexOf("IP4.DNS") === 0) {
            var idx = line.indexOf(":");
            if (idx > 0) {
                var val = line.substring(idx + 1).trim();
                if (val !== "") dns.push(val);
            }
        }
    }
    return {
        gateway: gateway,
        dnsText: dns.join(", "),
        linkSpeed: ""
    };
}

function parsePrimaryIp(rawText) {
    var match = String(rawText || "").match(/IP4\.ADDRESS[^:]*:([0-9.]+)/);
    return match ? String(match[1]).trim() : "";
}

function parseVpnAndPublic(rawText) {
    var lines = String(rawText || "").split(/\r?\n/);
    var vpnActive = false;
    var vpnName = "";
    var publicIP = "";
    for (var i = 0; i < lines.length; i++) {
        var line = String(lines[i] || "").trim();
        if (line.indexOf("VPN:") === 0) {
            var parts = line.split(":");
            vpnActive = parts.length > 1 && String(parts[1]).trim() === "1";
            vpnName = parts.length > 2 ? parts.slice(2).join(":").trim() : "";
        } else if (line.indexOf("PUB:") === 0) {
            publicIP = line.substring(4).trim();
        }
    }
    return {
        vpnActive: vpnActive,
        vpnName: vpnName,
        publicIP: publicIP
    };
}
