.pragma library

function _text(value) {
    if (value === undefined || value === null) return "";
    return String(value).trim();
}

function _metadataValue(metadata, key) {
    if (!metadata) return "";
    var value = metadata[key];
    if (value === undefined || value === null) return "";
    return value;
}

function _firstTextFromValue(value) {
    if (value === undefined || value === null) return "";

    if (Array.isArray(value)) {
        for (var i = 0; i < value.length; i++) {
            var t = _text(value[i]);
            if (t !== "") return t;
        }
        return "";
    }

    return _text(value);
}

function playerList(players) {
    if (!players) return [];

    if (Array.isArray(players)) return players;
    if (Array.isArray(players.values)) return players.values;
    if (players.values && players.values.length !== undefined) return players.values;

    if (players.length !== undefined) {
        var list = [];
        for (var i = 0; i < players.length; i++) {
            list.push(players[i]);
        }
        return list;
    }

    return [];
}

function titleForPlayer(player) {
    if (!player) return "";

    var title = _text(player.trackTitle);
    if (title !== "") return title;

    title = _firstTextFromValue(_metadataValue(player.metadata, "xesam:title"));
    if (title !== "") return title;

    title = _firstTextFromValue(_metadataValue(player.metadata, "title"));
    if (title !== "") return title;

    title = _firstTextFromValue(_metadataValue(player.metadata, "xesam:url"));
    if (title !== "") return title;

    return _text(player.identity);
}

function hasPlayableMetadata(player) {
    if (!player) return false;
    if (_text(player.trackTitle) !== "") return true;
    if (_firstTextFromValue(_metadataValue(player.metadata, "xesam:title")) !== "") return true;
    if (_firstTextFromValue(_metadataValue(player.metadata, "title")) !== "") return true;
    if (_firstTextFromValue(_metadataValue(player.metadata, "xesam:url")) !== "") return true;
    var state = _text(player.playbackState).toLowerCase();
    if ((state === "playing" || state === "paused") && _text(player.identity) !== "") return true;
    return false;
}

function artistForPlayer(player) {
    if (!player) return "";

    var artist = _text(player.trackArtist);
    if (artist !== "") return artist;

    artist = _firstTextFromValue(_metadataValue(player.metadata, "xesam:artist"));
    if (artist !== "") return artist;

    artist = _firstTextFromValue(_metadataValue(player.metadata, "xesam:albumArtist"));
    if (artist !== "") return artist;

    artist = _firstTextFromValue(_metadataValue(player.metadata, "xesam:composer"));
    if (artist !== "") return artist;

    return _text(player.identity);
}

function artUrlForPlayer(player) {
    if (!player) return "";

    var art = _text(player.trackArtUrl);
    if (art !== "") return art;

    art = _firstTextFromValue(_metadataValue(player.metadata, "mpris:artUrl"));
    if (art !== "") return art;

    return "";
}

function _isBrowserPlayer(player) {
    if (!player) return false;

    var id = (_text(player.dbusName) + " " + _text(player.desktopEntry) + " " + _text(player.identity)).toLowerCase();
    return id.indexOf("brave") >= 0
        || id.indexOf("chrome") >= 0
        || id.indexOf("chromium") >= 0
        || id.indexOf("edge") >= 0
        || id.indexOf("vivaldi") >= 0
        || id.indexOf("opera") >= 0
        || id.indexOf("firefox") >= 0
        || id.indexOf("plasma-browser-integration") >= 0;
}

function _domainFromUrl(value) {
    var url = _text(value).toLowerCase();
    if (url === "") return "";
    var noProto = url.replace(/^https?:\/\//, "");
    var host = noProto.split("/")[0];
    return host;
}

function _domainScore(url) {
    var domain = _domainFromUrl(url);
    if (domain === "") return 0;
    if (domain.indexOf("music.youtube.com") >= 0) return 180;
    if (domain.indexOf("youtube.com") >= 0) return 140;
    if (domain.indexOf("open.spotify.com") >= 0) return 220;
    if (domain.indexOf("soundcloud.com") >= 0) return 130;
    if (domain.indexOf("deezer.com") >= 0) return 120;
    if (domain.indexOf("bandcamp.com") >= 0) return 100;
    return 30;
}

function _playerScore(player, playingState) {
    if (!player) return -1;

    var state = _text(player.playbackState);
    var playing = _text(playingState);
    var title = _text(titleForPlayer(player));
    var artist = _text(artistForPlayer(player));
    var browser = _isBrowserPlayer(player);
    var id = (_text(player.dbusName) + " " + _text(player.desktopEntry) + " " + _text(player.identity) + " " + _text(_metadataValue(player.metadata, "xesam:url"))).toLowerCase();

    var score = 0;
    if (player.playbackState === playingState || state.toLowerCase() === "playing" || state.toLowerCase() === playing.toLowerCase()) {
        score += 1000;
    } else if (state.toLowerCase() === "paused") {
        score += 200;
    }

    if (title !== "") score += 160;
    if (artist !== "") score += 35;
    if (hasPlayableMetadata(player)) score += 60;
    if (player.position > 0) score += 20;
    if (_text(artUrlForPlayer(player)) !== "") score += 10;
    if (browser) score += 60;
    if (id.indexOf("youtube") >= 0) score += 120;
    if (id.indexOf("music.youtube") >= 0) score += 120;
    score += _domainScore(_metadataValue(player.metadata, "xesam:url"));

    return score;
}

function selectPlayer(players, playingState) {
    var list = playerList(players);
    if (list.length === 0) return null;

    var best = null;
    var bestScore = -1;

    for (var i = 0; i < list.length; i++) {
        try {
            var player = list[i];
            var score = _playerScore(player, playingState);
            if (score > bestScore) {
                bestScore = score;
                best = player;
            }
        } catch (_ignored) {
        }
    }

    return best || list[0];
}

function _matchesPreferred(player, preferred) {
    if (!player || !preferred || String(preferred).trim() === "") return false;
    var pref = String(preferred).trim().toLowerCase();
    var id = (
        _text(player.dbusName) + " "
        + _text(player.desktopEntry) + " "
        + _text(player.identity)
    ).toLowerCase();
    return id.indexOf(pref) >= 0;
}

function selectPlayerWithPreference(players, playingState, preferred) {
    var list = playerList(players);
    if (list.length === 0) return null;

    if (_text(preferred) !== "") {
        var preferredBest = null;
        var preferredScore = -1;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!_matchesPreferred(p, preferred)) continue;
            var score = _playerScore(p, playingState);
            if (score > preferredScore) {
                preferredBest = p;
                preferredScore = score;
            }
        }
        if (preferredBest) return preferredBest;
    }

    return selectPlayer(players, playingState);
}

function loopStatusText(loopStatus) {
    if (loopStatus === undefined || loopStatus === null) return "None";
    var raw = String(loopStatus);
    if (raw.indexOf("Track") >= 0) return "Track";
    if (raw.indexOf("Playlist") >= 0) return "Playlist";
    return "None";
}
