import QtCore
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Wayland
import "../../core"
import "../../shared"
import "../../services"
import "../../services/MprisUtils.js" as MprisUtils

PanelWindow {
    id: menuWindow

    property var itemData: null
    property point globalPos: Qt.point(0, 0)
    property bool showMenu: false
    property bool shiftHeld: false
    property var appSpecificActions: []
    property var _thunarBookmarks: []
    property bool _thunarBookmarksLoaded: false
    
    readonly property string scriptsDir: RuntimePaths.quickshellScriptsDir
    readonly property string homeDir: RuntimePaths.homeDir

    function _arrayFrom(value) {
        if (!value) return [];
        if (Array.isArray(value)) return value;
        if (value.values && value.values.length !== undefined) {
            var vals = [];
            for (var i = 0; i < value.values.length; i++) vals.push(value.values[i]);
            return vals;
        }
        if (value.length !== undefined) {
            var items = [];
            for (var j = 0; j < value.length; j++) items.push(value[j]);
            return items;
        }
        return [];
    }

    function _lower(value) {
        return String(value || "").toLowerCase();
    }

    function _appSummary(item) {
        var entry = item && item.desktopEntry ? item.desktopEntry : null;
        var parts = [
            item && item.appId ? item.appId : "",
            item && item.name ? item.name : "",
            entry && entry.id ? entry.id : "",
            entry && entry.name ? entry.name : "",
            entry && entry.genericName ? entry.genericName : "",
            entry && entry.execString ? entry.execString : "",
            entry && entry.startupWMClass ? entry.startupWMClass : ""
        ];
        parts = parts.concat(_arrayFrom(entry ? entry.categories : []));
        parts = parts.concat(_arrayFrom(entry ? entry.keywords : []));
        return _lower(parts.join(" "));
    }

    function _hasAny(text, needles) {
        var hay = _lower(text);
        for (var i = 0; i < needles.length; i++) {
            if (hay.indexOf(_lower(needles[i])) >= 0) return true;
        }
        return false;
    }

    function _detectRole(summary) {
        if (_hasAny(summary, ["webbrowser", "browser", "internet", "chrome", "chromium", "firefox", "brave", "vivaldi", "opera", "edge"]))
            return "browser";
        if (_hasAny(summary, ["filemanager", "file manager", "files", "folder", "directory", "thunar", "dolphin", "nautilus", "nemo", "pcmanfm"]))
            return "filemanager";
        if (_hasAny(summary, ["audiovideo", "audio/video", "media player", "player", "music", "video", "vlc", "mpv", "celluloid", "smplayer", "totem"]))
            return "media";
        if (_hasAny(summary, ["terminalemulator", "terminal emulator", "terminal", "shell", "console", "kitty", "alacritty", "foot", "wezterm", "konsole"]))
            return "terminal";
        if (_hasAny(summary, ["discord", "telegram", "signal", "element", "matrix", "slack", "teams", "whatsapp", "messenger"]))
            return "messenger";
        if (_hasAny(summary, ["code", "vscode", "codium", "sublime", "atom", "zed", "helix", "neovim", "vim", "emacs", "texteditor", "ide"]))
            return "editor";
        if (_hasAny(summary, ["game", "steam", "lutris", "heroic", "bottles", "proton", "wine", "gamescope"]))
            return "gaming";
        if (_hasAny(summary, ["mail", "email", "thunderbird", "evolution", "geary", "mailspring"]))
            return "email";
        if (_hasAny(summary, ["obs", "obs-studio", "screenrecord", "screencapture", "kooha", "peek"]))
            return "recorder";
        if (_hasAny(summary, ["spotify", "spotube", "tidal", "deezer", "amazon music", "youtube music"]))
            return "musicstream";
        return "generic";
    }

    function _desktopActions(entry) {
        if (!entry || !entry.actions) return [];
        var vals = entry.actions.values || entry.actions;
        return _arrayFrom(vals);
    }

    function _findDesktopAction(entry, patterns) {
        var actions = _desktopActions(entry);
        for (var i = 0; i < actions.length; i++) {
            var action = actions[i];
            var label = _lower((action && (action.name || action.id || action.label)) || "");
            for (var p = 0; p < patterns.length; p++) {
                if (label.indexOf(_lower(patterns[p])) >= 0)
                    return action;
            }
        }
        return null;
    }

    function _privateLaunchArgs(summary) {
        if (_hasAny(summary, ["firefox", "librewolf", "waterfox", "icecat", "floorp", "zen", "palemoon", "firedragon"]))
            return ["--private-window"];
        if (_hasAny(summary, ["chrome", "chromium", "brave", "vivaldi", "opera", "edge", "thorium", "ungoogled", "yandex", "cromite"]))
            return ["--incognito"];
        if (_hasAny(summary, ["falkon"]))
            return ["--private-window"];
        if (_hasAny(summary, ["midori"]))
            return ["-p"];
        return [];
    }

    function _defaultFolderActions(item) {
        var homeAction = DockService.buildLaunchCommand(item, [homeDir]);
        var downloadsAction = DockService.buildLaunchCommand(item, [RuntimePaths.downloadsDir]);
        var documentsAction = DockService.buildLaunchCommand(item, [RuntimePaths.documentsDir]);
        var desktopAction = DockService.buildLaunchCommand(item, [RuntimePaths.desktopDir]);
        var actions = [];
        if (homeAction)
            actions.push({ text: "Pasta pessoal", icon: "\u{f015}", command: homeAction });
        if (downloadsAction)
            actions.push({ text: "Downloads", icon: "\u{f07b}", command: downloadsAction });
        if (documentsAction)
            actions.push({ text: "Documentos", icon: "\u{f07b}", command: documentsAction });
        if (desktopAction)
            actions.push({ text: "Área de trabalho", icon: "\u{f07b}", command: desktopAction });
        return actions;
    }

    function _mediaPlayerForItem(item) {
        var preferred = "";
        if (item && item.desktopEntry && item.desktopEntry.id)
            preferred = String(item.desktopEntry.id);
        else if (item && item.appId)
            preferred = String(item.appId);
        else if (item && item.name)
            preferred = String(item.name);

        return MprisUtils.selectPlayerWithPreference(Mpris.players, MprisPlaybackState.Playing, preferred);
    }

    function _loadThunarBookmarks() {
        if (_bookmarkProc.running) return;
        _bookmarkProc.command = ["bash", "-lc", "cat \"$HOME/.config/gtk-3.0/bookmarks\" 2>/dev/null || true"];
        _bookmarkProc.running = true;
    }

    function refreshAppSpecificActions() {
        var actions = [];
        var item = menuWindow.itemData;
        if (!item) {
            menuWindow.appSpecificActions = actions;
            return;
        }

        var entry = item.desktopEntry || null;
        var summary = _appSummary(item);
        var role = _detectRole(summary);

        if (role === "browser") {
            var privateAction = _findDesktopAction(entry, ["private", "incognito", "anon"]);
            if (!privateAction) {
                var privateArgs = _privateLaunchArgs(summary);
                var privateCmd = privateArgs.length > 0 ? DockService.buildLaunchCommand(item, privateArgs) : "";
                if (privateCmd)
                    actions.push({ text: "Abrir janela privada", icon: "\u{f070}", command: privateCmd });
            }
        }

        if (role === "filemanager") {
            if (!_thunarBookmarksLoaded)
                _loadThunarBookmarks();

            for (var i = 0; i < _thunarBookmarks.length; i++) {
                var bm = _thunarBookmarks[i];
                if (!bm || !bm.path) continue;
                var bookmarkCmd = DockService.buildLaunchCommand(item, [bm.path]);
                if (!bookmarkCmd) continue;
                actions.push({
                    text: bm.label || bm.path,
                    icon: "\u{f07b}",
                    command: bookmarkCmd
                });
            }
            actions = actions.concat(_defaultFolderActions(item));
        }

        if (role === "media") {
            var player = _mediaPlayerForItem(item);
            if (player) {
                actions.push({
                    text: MprisUtils.hasPlayableMetadata(player) && MprisUtils.titleForPlayer(player)
                        ? (player.playbackState === MprisPlaybackState.Playing ? "Pausar" : "Reproduzir")
                        : "Reproduzir / Pausar",
                    icon: player.playbackState === MprisPlaybackState.Playing ? "\u{f04c}" : "\u{f04b}",
                    invoke: function() { player.togglePlaying(); }
                });
                actions.push({
                    text: "Faixa anterior",
                    icon: "\u{f048}",
                    invoke: function() { player.previous(); }
                });
                actions.push({
                    text: "Próxima faixa",
                    icon: "\u{f051}",
                    invoke: function() { player.next(); }
                });
            }
        }

        // Messenger apps: quick actions
        if (role === "messenger") {
            var muteCmd = DockService.buildLaunchCommand(item, ["--start-minimized"]);
            if (muteCmd)
                actions.push({ text: "Iniciar em segundo plano", icon: "\u{f070}", command: muteCmd });
        }

        // Music streaming: playback controls
        if (role === "musicstream") {
            var sPlayer = _mediaPlayerForItem(item);
            if (sPlayer) {
                actions.push({
                    text: sPlayer.playbackState === MprisPlaybackState.Playing ? "Pausar" : "Reproduzir",
                    icon: sPlayer.playbackState === MprisPlaybackState.Playing ? "\u{f04c}" : "\u{f04b}",
                    invoke: function() { sPlayer.togglePlaying(); }
                });
                actions.push({
                    text: "Faixa anterior",
                    icon: "\u{f048}",
                    invoke: function() { sPlayer.previous(); }
                });
                actions.push({
                    text: "Próxima faixa",
                    icon: "\u{f051}",
                    invoke: function() { sPlayer.next(); }
                });
            }
        }

        // Code editors: quick project open
        if (role === "editor") {
            var recentAction = _findDesktopAction(entry, ["recent", "recents", "recent files"]);
            if (!recentAction) {
                var homeCode = DockService.buildLaunchCommand(item, [homeDir]);
                if (homeCode)
                    actions.push({ text: "Abrir pasta home", icon: "\u{f07b}", command: homeCode });
            }
        }

        // Gaming: Steam-related shortcuts
        if (role === "gaming") {
            if (_hasAny(summary, ["steam"])) {
                actions.push({ text: "Big Picture Mode", icon: "\u{f11b}", command: ["steam", "steam://open/bigpicture"] });
                actions.push({ text: "Ver Downloads", icon: "\u{f019}", command: ["steam", "steam://open/downloads"] });
                actions.push({ text: "Biblioteca", icon: "\u{f0c0}", command: ["steam", "steam://open/games"] });
            }
        }

        // Email clients: compose action
        if (role === "email") {
            var composeAction = _findDesktopAction(entry, ["compose", "new", "escrever", "novo"]);
            if (!composeAction) {
                var composeCmd = DockService.buildLaunchCommand(item, ["--compose"]);
                if (composeCmd)
                    actions.push({ text: "Nova mensagem", icon: "\u{f1d8}", command: composeCmd });
            }
        }

        // Screen recorders: quick record
        if (role === "recorder") {
            if (_hasAny(summary, ["obs"])) {
                actions.push({ text: "Iniciar gravação", icon: "\u{f111}", command: ["obs", "--startrecording"] });
                actions.push({ text: "Iniciar stream", icon: "\u{f1c8}", command: ["obs", "--startstreaming"] });
            }
        }

        // Terminal: open new window
        if (role === "terminal") {
            var newWinCmd = DockService.buildLaunchCommand(item, []);
            if (newWinCmd)
                actions.push({ text: "Nova janela", icon: "\u{f2d0}", command: newWinCmd });
        }

        menuWindow.appSpecificActions = actions;
    }

    visible: showMenu && itemData !== null
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Capture all clicks to dismiss when clicking outside
    WlrLayershell.exclusiveZone: -1
    anchors { left: true; right: true; top: true; bottom: true }

    onItemDataChanged: {
        if (showMenu && itemData)
            refreshAppSpecificActions();
        else
            menuWindow.appSpecificActions = [];
    }
    onShowMenuChanged: {
        if (showMenu && itemData) {
            _thunarBookmarksLoaded = false;
            _thunarBookmarks = [];
            refreshAppSpecificActions();
        }
    }

    // Backdrop to catch clicks outside the menu
    MouseArea {
        anchors.fill: parent
        onPressed: menuWindow.showMenu = false
    }


    // Centered container for the menu relative to the click position
    Item {
        id: menuContainer
        width: menuCard.width
        height: menuCard.height
        x: Math.max(4, Math.min(globalPos.x - width / 2, parent.width - width - 4))
        y: parent.height - height - 68 // 60px dock + 8px gap

        // Shadow
        Rectangle {
            anchors.fill: menuCard
            anchors.topMargin: 4
            radius: menuCard.radius
            color: Qt.rgba(0, 0, 0, 0.35)
            z: -1
        }

        Rectangle {
            id: menuCard
            width: menuColumn.width + 16
            height: menuColumn.height + 12
            radius: DesignTokens.radiusMD
            color: ColorScheme.glassPopup
            border.width: 1
            border.color: ColorScheme.glassBorder

            // Top highlight
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1
                radius: parent.radius
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            Column {
                id: menuColumn
                anchors.centerIn: parent
                width: 210
                spacing: 2
                topPadding: 6
                bottomPadding: 6

            // App name header
            RowLayout {
                width: parent.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                
                SmartIcon {
                    source: menuWindow.itemData ? menuWindow.itemData.icon : ""
                    size: 18
                    label: menuWindow.itemData ? (menuWindow.itemData.name || menuWindow.itemData.appId) : ""
                }

                Column {
                    Layout.fillWidth: true
                    Text {
                        width: parent.width
                        text: menuWindow.itemData ? (menuWindow.itemData.name || menuWindow.itemData.appId || "Aplicativo") : "Aplicativo"
                        color: ColorScheme.text
                        font.pixelSize: 12
                        font.family: Style.fontUI
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: menuWindow.itemData ? (menuWindow.itemData.appId || "") : ""
                        color: ColorScheme.textAlt
                        font.pixelSize: 10
                        font.family: Style.fontMono
                        elide: Text.ElideRight
                        visible: text !== "" && text !== menuWindow.itemData.name
                    }
                }
            }

            Rectangle { 
                width: parent.width - 12
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                color: ColorScheme.withAlpha(ColorScheme.foreground, 0.08)
            }

            // Desktop actions from .desktop file
            Repeater {
                model: {
                    if (!menuWindow.itemData || !menuWindow.itemData.desktopEntry) return [];
                    var actsObj = menuWindow.itemData.desktopEntry.actions;
                    // Support both .values and direct array access depending on Quickshell version
                    let vals = actsObj ? (actsObj.values || actsObj) : [];
                    return (vals && vals.length) ? vals : [];
                }

                delegate: ContextMenuItem {
                    text: modelData.name || modelData.id
                    icon: "\u{f144}"
                    onClicked: {
                        modelData.execute();
                        menuWindow.showMenu = false;
                    }
                }
            }

            // Separator if we had desktop actions
            Rectangle { 
                width: parent.width - 12; anchors.horizontalCenter: parent.horizontalCenter
                height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.08)
                visible: menuWindow.itemData && menuWindow.itemData.desktopEntry && 
                         menuWindow.itemData.desktopEntry.actions && 
                         (menuWindow.itemData.desktopEntry.actions.values || menuWindow.itemData.desktopEntry.actions).length > 0
            }

            // App-specific actions
            Repeater {
                model: menuWindow.appSpecificActions

        delegate: ContextMenuItem {
            text: modelData.text || ""
            icon: modelData.icon || ""
            onClicked: {
                if (modelData.invoke) {
                    modelData.invoke();
                } else if (modelData.desktopAction && modelData.desktopAction.execute) {
                    modelData.desktopAction.execute();
                } else if (modelData.command) {
                    DockService.runCommand(modelData.mode || "direct", modelData.command, !!modelData.confirmDangerous);
                }
                menuWindow.showMenu = false;
            }
        }
    }

            Rectangle { 
                width: parent.width - 12; anchors.horizontalCenter: parent.horizontalCenter
                height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.08)
                visible: menuWindow.appSpecificActions.length > 0
            }

            // --- Standard Actions ---

            // New Window
            ContextMenuItem {
                text: "Nova Janela"
                icon: "\u{f067}"
                onClicked: {
                    if (menuWindow.itemData)
                        DockService.launchNewInstance(menuWindow.itemData);
                    menuWindow.showMenu = false;
                }
            }

            // Run as Root
            ContextMenuItem {
                text: "Rodar como Root"
                icon: "\u{f084}"
                onClicked: {
                    var exec = DockService.buildLaunchCommand(menuWindow.itemData, []);
                    if (exec)
                        DockService.runCommand("root", exec);
                    menuWindow.showMenu = false;
                }
            }

            // Run in Terminal
            ContextMenuItem {
                text: "Rodar no Terminal"
                icon: "\u{f120}"
                onClicked: {
                    var exec = DockService.buildLaunchCommand(menuWindow.itemData, []);
                    if (exec)
                        DockService.runCommand("terminal", exec);
                    menuWindow.showMenu = false;
                }
            }

            // Open Folder
            ContextMenuItem {
                text: "Abrir Pasta do Atalho"
                icon: "\u{f07c}"
                visible: menuWindow.itemData && menuWindow.itemData.desktopEntry
                onClicked: {
                    if (menuWindow.itemData && menuWindow.itemData.appId) {
                        var appId = menuWindow.itemData.appId;
                        DockService.runCommand("direct", "bash -lc 'for d in \"" + RuntimePaths.appDataDir + "/applications\" /run/current-system/sw/share/applications /etc/profiles/per-user/lucas/share/applications; do f=\"$d/" + appId + ".desktop\"; [ -f \"$f\" ] && thunar \"$d\" && exit; done'");
                    }
                    menuWindow.showMenu = false;
                }
            }

            Rectangle { 
                width: parent.width - 12; anchors.horizontalCenter: parent.horizontalCenter
                height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.08)
            }

            // Pin/Unpin
            ContextMenuItem {
                text: menuWindow.itemData && menuWindow.itemData.pinned ? "Desafixar da Dock" : "Fixar na Dock"
                icon: menuWindow.itemData && menuWindow.itemData.pinned ? "\u{f08d}" : "\u{f276}"
                onClicked: {
                    if (menuWindow.itemData)
                        DockService.togglePin(menuWindow.itemData.appId);
                    menuWindow.showMenu = false;
                }
            }

            Rectangle { 
                width: parent.width - 12; anchors.horizontalCenter: parent.horizontalCenter
                height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.08); 
                visible: menuWindow.itemData && menuWindow.itemData.running 
            }

            // --- Running App Actions ---

            // Minimize / Restore all
            ContextMenuItem {
                property bool _allMinimized: menuWindow.itemData && menuWindow.itemData.minimizedAll
                text: _allMinimized ? "Restaurar Todas" : "Minimizar Todas"
                icon: _allMinimized ? "\u{f2d2}" : "\u{f2d1}"
                visible: menuWindow.itemData && menuWindow.itemData.running
                onClicked: {
                    if (menuWindow.itemData && menuWindow.itemData.toplevels) {
                        var isAllMin = menuWindow.itemData.minimizedAll;
                        for (var i = 0; i < menuWindow.itemData.toplevels.length; i++) {
                            var tl = menuWindow.itemData.toplevels[i];
                            if (!tl || !tl.lastIpcObject) continue;
                            var addr = "address:" + tl.lastIpcObject.address;
                            if (isAllMin)
                                Hyprland.dispatch("focuswindow " + addr);
                            else
                                Hyprland.dispatch("movetoworkspacesilent special:minimize," + addr);
                        }
                    }
                    menuWindow.showMenu = false;
                }
            }

            // Toggle Float / Tile
            ContextMenuItem {
                readonly property bool isFloating: (menuWindow.itemData && menuWindow.itemData.toplevels &&
                                                    menuWindow.itemData.toplevels[0] &&
                                                    menuWindow.itemData.toplevels[0].lastIpcObject &&
                                                    menuWindow.itemData.toplevels[0].lastIpcObject.floating)
                text: isFloating ? "Tornar Tiled" : "Tornar Flutuante"
                icon: isFloating ? "\u{f009}" : "\u{f2d0}"
                visible: menuWindow.itemData && menuWindow.itemData.running &&
                         menuWindow.itemData.toplevels && menuWindow.itemData.toplevels.length > 0
                onClicked: {
                    if (menuWindow.itemData && menuWindow.itemData.toplevels) {
                        for (var i = 0; i < menuWindow.itemData.toplevels.length; i++) {
                            var tl = menuWindow.itemData.toplevels[i];
                            if (tl && tl.lastIpcObject)
                                Hyprland.dispatch("togglefloating address:" + tl.lastIpcObject.address);
                        }
                    }
                    menuWindow.showMenu = false;
                }
            }

            // Move to current workspace
            ContextMenuItem {
                text: "Trazer p/ Workspace Atual"
                icon: "\u{f0b2}"
                visible: menuWindow.itemData && menuWindow.itemData.running
                onClicked: {
                    if (menuWindow.itemData && menuWindow.itemData.toplevels) {
                        for (var i = 0; i < menuWindow.itemData.toplevels.length; i++) {
                            var tl = menuWindow.itemData.toplevels[i];
                            if (tl && tl.lastIpcObject)
                                Hyprland.dispatch("movetoworkspace e+0,address:" + tl.lastIpcObject.address);
                        }
                    }
                    menuWindow.showMenu = false;
                }
            }

            ContextMenuItem {
                text: "Próxima Janela"
                icon: "\u{f061}"
                visible: menuWindow.itemData && menuWindow.itemData.running && menuWindow.itemData.instanceCount > 1
                onClicked: {
                    DockService.focusNextInstance(menuWindow.itemData.appId, 1);
                    menuWindow.showMenu = false;
                }
            }

            ContextMenuItem {
                text: "Abrir Pasta do App"
                icon: "\u{f07b}"
                visible: menuWindow.itemData && menuWindow.itemData.desktopEntry
                onClicked: {
                    if (menuWindow.itemData && menuWindow.itemData.appId) {
                        var appId = menuWindow.itemData.appId;
                        _commandProc.exec(["bash", "-c",
                            "for d in \"" + RuntimePaths.appDataDir + "/applications\" /run/current-system/sw/share/applications /etc/profiles/per-user/lucas/share/applications; do " +
                            "f=\"$d/" + appId + ".desktop\"; [ -f \"$f\" ] && thunar \"$d\" && exit; done"
                        ]);
                    }
                    menuWindow.showMenu = false;
                }
            }

            ContextMenuItem {
                text: "Copiar ID do App"
                icon: "\u{f0c5}"
                visible: menuWindow.itemData && menuWindow.itemData.appId
                onClicked: {
                    if (menuWindow.itemData && menuWindow.itemData.appId)
                        _commandProc.exec(["bash", "-lc", "printf %s \"" + String(menuWindow.itemData.appId).replace(/\"/g, '\\\"') + "\" | wl-copy"]);
                    menuWindow.showMenu = false;
                }
            }

            ContextMenuItem {
                text: "Janela Anterior"
                icon: "\u{f060}"
                visible: menuWindow.itemData && menuWindow.itemData.running && menuWindow.itemData.instanceCount > 1
                onClicked: {
                    DockService.focusNextInstance(menuWindow.itemData.appId, -1);
                    menuWindow.showMenu = false;
                }
            }

            ContextMenuItem {
                text: "Restaurar da Dock"
                icon: "\u{f2d2}"
                visible: menuWindow.itemData && menuWindow.itemData.running && menuWindow.itemData.minimizedAll
                onClicked: {
                    DockService.restoreItem(menuWindow.itemData);
                    menuWindow.showMenu = false;
                }
            }

            Rectangle { 
                width: parent.width - 12; anchors.horizontalCenter: parent.horizontalCenter
                height: 1; color: ColorScheme.withAlpha(ColorScheme.foreground, 0.08); 
                visible: menuWindow.itemData && menuWindow.itemData.running 
            }

            // Close all instances
            ContextMenuItem {
                text: (menuWindow.itemData && menuWindow.itemData.instanceCount > 1) ? "Fechar Todas as Janelas" : "Fechar Janela"
                icon: "\u{f00d}"
                textColor: ColorScheme.red
                visible: menuWindow.itemData && menuWindow.itemData.running
                onClicked: {
                    if (menuWindow.itemData && menuWindow.itemData.toplevels) {
                        for (var i = 0; i < menuWindow.itemData.toplevels.length; i++) {
                            var tl = menuWindow.itemData.toplevels[i];
                            if (tl && tl.lastIpcObject)
                                Hyprland.dispatch("closewindow address:" + tl.lastIpcObject.address);
                        }
                    }
                    menuWindow.showMenu = false;
                }
            }

            // --- Emergency / Debug Actions (Shift Only) ---

            // Force Kill
            ContextMenuItem {
                text: "Forçar Encerramento (SIGKILL)"
                icon: "\u{f0e7}"
                textColor: ColorScheme.red
                fontBold: true
                visible: menuWindow.itemData && menuWindow.itemData.running && menuWindow.shiftHeld
                onClicked: {
                    if (menuWindow.itemData && menuWindow.itemData.toplevels) {
                        for (var i = 0; i < menuWindow.itemData.toplevels.length; i++) {
                            var tl = menuWindow.itemData.toplevels[i];
                            if (tl && tl.lastIpcObject && tl.lastIpcObject.pid) {
                                _commandProc.exec(["kill", "-9", String(tl.lastIpcObject.pid)]);
                            }
                        }
                    }
                    menuWindow.showMenu = false;
                }
            }

            Rectangle { 
                width: parent.width - 12; anchors.horizontalCenter: parent.horizontalCenter
                height: 1; color: ColorScheme.glassBorder; visible: menuWindow.shiftHeld 
            }

            ContextMenuItem {
                text: "Salvar Layout da Dock"
                icon: "\u{f0c7}"
                visible: menuWindow.shiftHeld
                onClicked: { DockService.saveLayout(); menuWindow.showMenu = false; }
            }

            ContextMenuItem {
                text: "Restaurar Layout da Dock"
                icon: "\u{f2f9}"
                visible: menuWindow.shiftHeld
                onClicked: { DockService.restoreLayout(); menuWindow.showMenu = false; }
            }
        }
    }
}

    // --- Helper Components ---
    
    component ContextMenuItem : Rectangle {
        id: itemRoot
        property string text: ""
        property string icon: ""
        property color textColor: ColorScheme.text
        property bool fontBold: false
        signal clicked()

        width: 200
        height: 32
        radius: DesignTokens.radiusXS
        color: itemMouse.containsMouse ? ColorScheme.stateHover : "transparent"
        anchors.horizontalCenter: parent.horizontalCenter

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            spacing: 12
            
            Text {
                text: itemRoot.icon
                color: itemMouse.containsMouse ? (itemRoot.textColor === ColorScheme.red ? ColorScheme.red : ColorScheme.accent) : ColorScheme.textAlt
                font.family: Style.fontMono
                font.pixelSize: 13
                visible: text !== ""
            }

            Text {
                Layout.fillWidth: true
                text: itemRoot.text
                color: itemRoot.textColor
                font.pixelSize: 12
                font.family: Style.fontUI
                font.bold: itemRoot.fontBold
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: itemRoot.clicked()
        }
    }

    Process {
        id: _bookmarkProc
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (text || "").split(/\r?\n/);
                var bookmarks = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;

                    var splitIndex = line.indexOf(" ");
                    var uri = splitIndex >= 0 ? line.slice(0, splitIndex) : line;
                    var label = splitIndex >= 0 ? line.slice(splitIndex + 1).trim() : "";
                    var path = uri.replace(/^file:\/\//, "");
                    if (!path) continue;

                    try {
                        path = decodeURIComponent(path);
                    } catch (e) {}

                    if (!label) {
                        var parts = path.split("/").filter(function(part) { return part !== ""; });
                        label = parts.length > 0 ? parts[parts.length - 1] : path;
                    }

                    bookmarks.push({ path: path, label: label });
                }

                menuWindow._thunarBookmarks = bookmarks;
                menuWindow._thunarBookmarksLoaded = true;
                menuWindow.refreshAppSpecificActions();
            }
        }
    }

    TimedProcess { id: _commandProc }
}
