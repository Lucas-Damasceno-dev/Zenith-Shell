--!strict
-- Zenith Desktop Shell — MPRIS2 Media Player Service
-- Tracks player state, playback metadata, album art and playback controls

local MprisService = {
    name = "mpris",
    is_running = true,
}

export type MediaSnapshot = {
    is_available: boolean,
    is_playing: boolean,
    playing: boolean,
    player_name: string,
    status: string,
    title: string,
    artist: string,
    album: string,
    art_url: string,
    can_play: boolean?,
    can_pause: boolean?,
    can_go_next: boolean?,
    can_go_prev: boolean?,
    position: number,
    length: number,
}

function MprisService.snapshot(): MediaSnapshot
    local raw = if Zenith.Services and Zenith.Services.Media then Zenith.Services.Media() else nil
    if not raw then
        return {
            is_available = false,
            is_playing = false,
            playing = false,
            player_name = "",
            status = "Stopped",
            title = "",
            artist = "",
            album = "",
            art_url = "",
            can_play = false,
            can_pause = false,
            can_go_next = false,
            can_go_prev = false,
            position = 0,
            length = 0,
        }
    end

    local title = raw.title or ""
    local artist = raw.artist or ""
    local album = raw.album or ""
    local player_name = raw.player_name or ""
    local art_url = raw.art_url or raw.album_art or ""
    local status = raw.status or "Stopped"
    local position = raw.position or 0
    local length = raw.length or raw.length_seconds or 0
    local is_playing = raw.playing == true or raw.is_playing == true or status == "Playing"

    return {
        is_available = raw.is_available == true,
        is_playing = is_playing,
        playing = is_playing,
        player_name = player_name,
        status = status,
        title = title,
        artist = artist,
        album = album,
        art_url = art_url,
        can_play = raw.can_play,
        can_pause = raw.can_pause,
        can_go_next = raw.can_go_next,
        can_go_prev = raw.can_go_prev,
        position = position,
        length = length,
    }
end

function MprisService.play_pause()
    if Zenith.Services and Zenith.Services.MediaControl then
        Zenith.Services.MediaControl("play-pause")
    elseif Zenith.media_control then
        Zenith.media_control("play-pause")
    end
end

function MprisService.next()
    if Zenith.Services and Zenith.Services.MediaControl then
        Zenith.Services.MediaControl("next")
    elseif Zenith.media_control then
        Zenith.media_control("next")
    end
end

function MprisService.previous()
    if Zenith.Services and Zenith.Services.MediaControl then
        Zenith.Services.MediaControl("previous")
    elseif Zenith.media_control then
        Zenith.media_control("previous")
    end
end

function MprisService.start()
    MprisService.is_running = true
end

function MprisService.stop()
    MprisService.is_running = false
end

return MprisService
