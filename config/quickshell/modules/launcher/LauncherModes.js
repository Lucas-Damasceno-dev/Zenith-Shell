.pragma library

var MODE_INFO = {
    "apps":           { icon: "\u{f002}", label: "Apps" },
    "calc":           { icon: "\u{f1ec}", label: "Calculadora" },
    "nix":            { icon: "\u{f313}", label: "NixOS Pkgs" },
    "options":        { icon: "\u{f013}", label: "NixOS Opts" },
    "web":            { icon: "\u{f0ac}", label: "Web Search" },
    "files":          { icon: "\u{f07b}", label: "Arquivos" },
    "folder":         { icon: "\u{f07b}", label: "Pasta" },
    "file":           { icon: "\u{f15b}", label: "Arquivo" },
    "cmd":            { icon: "\u{f120}", label: "Comando" },
    "cmd_terminal":   { icon: "\u{f120}", label: "Terminal" },
    "clipboard":      { icon: "\u{f0ea}", label: "Clipboard" },
    "emoji":          { icon: "\u{f118}", label: "Emoji" },
    "windows":        { icon: "\u{f2d0}", label: "Janelas" },
    "window":         { icon: "\u{f2d0}", label: "Janela" },
    "system_audio":   { icon: "\u{f028}", label: "Áudio" },
    "system_bluetooth": { icon: "\u{f293}", label: "Bluetooth" },
    "system_wifi":    { icon: "\u{f1eb}", label: "Wi-Fi" },
    "system_power":   { icon: "\u{f011}", label: "Energia" },
    "system_brightness": { icon: "\u{f185}", label: "Brilho" },
    "translate":      { icon: "\u{f1ab}", label: "Tradução" },
    "recentProjects": { icon: "\u{f07c}", label: "Projetos" },
    "project":        { icon: "\u{f07c}", label: "Projeto" },
    "recentFiles":    { icon: "\u{f016}", label: "Recentes" },
    "recentFile":     { icon: "\u{f017}", label: "Recente" },
    "snippets":       { icon: "\u{f121}", label: "Snippets" },
    "snippet":        { icon: "\u{f121}", label: "Snippet" },
    "ai":             { icon: "\u{f135}", label: "IA" },
    "ai_assist":      { icon: "\u{f135}", label: "IA" },
    "unicode":        { icon: "\u{f3b4}", label: "Unicode" },
    "kill":           { icon: "\u{f00d}", label: "Kill" },
    "volume":         { icon: "\u{f028}", label: "Volume" },
    "hw_volume":      { icon: "\u{f028}", label: "Volume" },
    "brightness":     { icon: "\u{f185}", label: "Brilho" },
    "hw_brightness":  { icon: "\u{f185}", label: "Brilho" }
};

var MODE_COLORS = {
    "apps": "accent",
    "calc": "yellow",
    "nix": "blue",
    "options": "teal",
    "web": "green",
    "files": "peach",
    "cmd": "red",
    "clipboard": "mauve",
    "emoji": "yellow",
    "windows": "teal",
    "translate": "green",
    "recentProjects": "peach",
    "recentFiles": "blue",
    "snippets": "mauve",
    "ai": "blue",
    "unicode": "lavender",
    "kill": "red",
    "volume": "blue",
    "brightness": "yellow"
};

function detectMode(query) {
    var text = String(query || "");
    if (text.trim() === "")
        return "apps";
    if (text.startsWith("="))
        return "calc";
    if (text.startsWith("nix?"))
        return "nix";
    if (text.startsWith("opt?"))
        return "options";
    if (text.startsWith("g?"))
        return "web";
    if (text.startsWith("/"))
        return "files";
    if (text.startsWith(">"))
        return "cmd";
    if (text.startsWith("cb?"))
        return "clipboard";
    if (text.startsWith("em?"))
        return "emoji";
    if (text.startsWith("w?"))
        return "windows";
    if (text.startsWith("tr?"))
        return "translate";
    if (text.startsWith("rp?"))
        return "recentProjects";
    if (text.startsWith("rf?"))
        return "recentFiles";
    if (text.startsWith("sn?"))
        return "snippets";
    if (text.startsWith("ai?"))
        return "ai";
    if (text.startsWith("uc?") || text.startsWith("un?"))
        return "unicode";
    if (text.startsWith("kill?"))
        return "kill";
    if (/^vol\s/i.test(text))
        return "volume";
    if (/^bri\s/i.test(text))
        return "brightness";
    return "apps";
}

for (var modeKey in MODE_INFO)
    Object.freeze(MODE_INFO[modeKey]);
Object.freeze(MODE_INFO);
Object.freeze(MODE_COLORS);

function getModeInfo(mode) {
    return MODE_INFO[mode] || MODE_INFO.apps;
}

function getModeColor(mode) {
    return MODE_COLORS[mode] || "accent";
}
