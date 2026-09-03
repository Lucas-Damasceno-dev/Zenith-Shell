#!/usr/bin/env python3
import urllib.request
import urllib.parse
import json
import sys

def fetch_lyrics(artist, track):
    if not artist or not track:
        return "Nenhuma música tocando no momento."
    
    url = f"https://lrclib.net/api/get?artist_name={urllib.parse.quote(artist)}&track_name={urllib.parse.quote(track)}"
    
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Quickshell-Media-Widget/1.0'})
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                # Priorizar letras não sincronizadas para o widget, 
                # pois o popup não tem auto-scroll em tempo real ainda
                lyrics = data.get("plainLyrics") or data.get("syncedLyrics")
                if lyrics:
                    return lyrics
                else:
                    return "Letra não encontrada para esta faixa."
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return "Letra não encontrada para esta faixa."
    except Exception as e:
        pass
    
    return "Erro ao buscar a letra."

if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "--self-test":
        baseline = fetch_lyrics("", "")
        if "Nenhuma música tocando" not in baseline:
            print("self-test failed")
            sys.exit(1)
        print("ok")
        sys.exit(0)

    if len(sys.argv) < 3:
        print("Uso: fetch_lyrics.py <artista> <musica>")
        sys.exit(1)
        
    artist = sys.argv[1]
    track = sys.argv[2]
    print(fetch_lyrics(artist, track))
