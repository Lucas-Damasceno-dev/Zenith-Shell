.pragma library

var DANGEROUS_PATTERNS = [
    /(^|\s)rm\s+-rf(\s|$)/,
    /(^|\s)mkfs(\s|$)/,
    /(^|\s)dd\s+if=/,
    /(^|\s)(shutdown|reboot|poweroff|halt)(\s|$)/,
    /(^|\s)systemctl\s+(poweroff|reboot)(\s|$)/,
    /(^|\s)kill\s+-9\s+1(\s|$)/,
    /\>\s*\/dev\/sd[a-z]/,
    /:\(\)\s*\{\s*:\|:\&\s*\};:/,
    /(^|\s)(bash|sh|zsh|fish)\s+-c(\s|$)/,
    /\$\(/,
    /(^|\s)eval(\s|$)/
];

function isDangerousCommand(cmd) {
    var text = String(cmd || "").trim().toLowerCase();
    if (text === "")
        return false;

    var normalized = text.replace(/[`'\"]/g, " ").replace(/\s+/g, " ");
    for (var i = 0; i < DANGEROUS_PATTERNS.length; i++) {
        if (DANGEROUS_PATTERNS[i].test(text))
            return true;
        if (DANGEROUS_PATTERNS[i].test(normalized))
            return true;
    }
    return false;
}
