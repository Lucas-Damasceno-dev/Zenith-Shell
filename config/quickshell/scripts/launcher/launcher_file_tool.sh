#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v fd >/dev/null 2>&1 || { echo "missing fd"; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "missing jq"; exit 1; }
  command -v stat >/dev/null 2>&1 || { echo "missing stat"; exit 1; }
  command -v file >/dev/null 2>&1 || { echo "missing file"; exit 1; }
  echo "ok"
  exit 0
fi

cmd="${1:-}"

human_size() {
  local bytes="${1:-0}"
  local value unit
  if [[ "$bytes" =~ ^[0-9]+$ ]] && command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec-i --suffix=B "$bytes"
    return 0
  fi
  value="${bytes:-0}"
  unit="B"
  if [[ "$value" -ge 1073741824 ]]; then
    printf '%.1f GiB\n' "$(awk "BEGIN { print $value / 1073741824 }")"
  elif [[ "$value" -ge 1048576 ]]; then
    printf '%.1f MiB\n' "$(awk "BEGIN { print $value / 1048576 }")"
  elif [[ "$value" -ge 1024 ]]; then
    printf '%.1f KiB\n' "$(awk "BEGIN { print $value / 1024 }")"
  else
    printf '%s %s\n' "$value" "$unit"
  fi
}

icon_for_path() {
  local kind="$1"
  local path="$2"
  local base ext
  base="$(basename -- "$path")"
  ext="${base##*.}"
  ext="${ext,,}"
  if [[ "$kind" == "dir" ]]; then
    if [[ -d "$path/.git" ]]; then
      printf 'folder-git'
    else
      printf 'folder'
    fi
    return 0
  fi
  case "$ext" in
    png|jpg|jpeg|gif|bmp|svg|webp|avif) printf 'image-x-generic' ;;
    mp4|mkv|avi|webm|mov|m4v) printf 'video-x-generic' ;;
    mp3|flac|ogg|wav|aac|m4a) printf 'audio-x-generic' ;;
    pdf) printf 'application-pdf' ;;
    zip|tar|gz|xz|7z|rar|7zip|bz2) printf 'package-x-generic' ;;
    nix) printf 'nix-snowflake' ;;
    rs|py|js|ts|c|cpp|h|go|hs|lua|sh|qml|json|yaml|yml|md|toml|css|scss|html|xml) 
      case "$ext" in
        rs) printf 'text-x-rust' ;;
        py) printf 'text-x-python' ;;
        js) printf 'text-x-javascript' ;;
        ts) printf 'text-x-typescript' ;;
        go) printf 'text-x-go' ;;
        sh) printf 'text-x-script' ;;
        nix) printf 'nix-snowflake' ;;
        md) printf 'text-markdown' ;;
        *) printf 'text-x-script' ;;
      esac
      ;;
    exe|msi|appimage|bin) printf 'application-x-executable' ;;
    *) printf 'text-x-generic' ;;
  esac
}

print_search_rows() {
  local raw_term="${1:-}"
  local base_dir="${2:-$HOME}"
  local expanded search_root search_term term_dir term_name
  local -a search_roots

  emit_row() {
    local path="$1"
    local kind base parent ext icon
    [[ -n "$path" && -e "$path" ]] || return 0
    if [[ -d "$path" ]]; then
      kind="dir"
    else
      kind="file"
    fi
    base="$(basename -- "$path")"
    parent="$(dirname -- "$path")"
    ext=""
    if [[ "$kind" == "file" && "$base" == *.* ]]; then
      ext="${base##*.}"
      ext="${ext,,}"
    fi
    icon="$(icon_for_path "$kind" "$path")"
    printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' "$kind" "$path" "$base" "$parent" "$ext" "$icon"
  }

  list_directory_rows() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    find -L "$dir" -mindepth 1 -maxdepth 1 2>/dev/null | sort | head -n 32 | while IFS= read -r path; do
      emit_row "$path"
    done
  }

  run_search() {
    local term="$1"
    shift || true
    local root path
    for root in "$@"; do
      [[ -d "$root" ]] || continue
      if command -v fd >/dev/null 2>&1; then
        fd --absolute-path --hidden --follow --ignore-case --max-results 32 \
          --exclude .cache --exclude node_modules --exclude .git --exclude .cargo --exclude target --exclude .direnv \
          --type f --type d "$term" "$root" 2>/dev/null | while IFS= read -r path; do
          emit_row "$path"
        done
      else
        find -L "$root" \( -type f -o -type d \) -iname "*${term}*" 2>/dev/null | head -n 32 | while IFS= read -r path; do
          emit_row "$path"
        done
      fi
    done
  }

  search_root="$base_dir"
  search_term="$raw_term"
  expanded="${raw_term/#\~/$HOME}"
  search_roots=("$base_dir")
  if [[ -d "/etc/nixos" && "/etc/nixos" != "$base_dir" ]]; then
    search_roots+=("/etc/nixos")
  fi

  if [[ -z "$raw_term" ]]; then
    list_directory_rows "$base_dir"
    if [[ -d "/etc/nixos" && "/etc/nixos" != "$base_dir" ]]; then
      list_directory_rows "/etc/nixos"
    fi
    return 0
  fi

  if [[ "$expanded" == /* ]]; then
    if [[ -d "$expanded" ]]; then
      list_directory_rows "$expanded"
      return 0
    fi
    term_dir="$(dirname -- "$expanded")"
    term_name="$(basename -- "$expanded")"
    if [[ -d "$term_dir" ]]; then
      search_root="$term_dir"
      search_term="$term_name"
      search_roots=("$search_root")
    fi
  elif [[ "$expanded" == */* ]]; then
    if [[ -d "$base_dir/$expanded" ]]; then
      list_directory_rows "$base_dir/$expanded"
      return 0
    fi
    term_dir="$(dirname -- "$expanded")"
    term_name="$(basename -- "$expanded")"
    if [[ -d "$base_dir/$term_dir" ]]; then
      search_root="$base_dir/$term_dir"
      search_term="$term_name"
      search_roots=("$search_root")
    fi
  fi

  run_search "$search_term" "${search_roots[@]}" | awk '!seen[$0]++'
}

emit_metadata() {
  local path="${1:-}"
  [[ -n "$path" && -e "$path" ]] || exit 0
  local kind size_bytes perms modified mime parent base child_count preview_note size_human
  base="$(basename -- "$path")"
  parent="$(dirname -- "$path")"
  perms="$(stat -c '%A' -- "$path" 2>/dev/null || true)"
  modified="$(stat -c '%y' -- "$path" 2>/dev/null | cut -d'.' -f1 || true)"
  mime="$(file -Lb --mime-type -- "$path" 2>/dev/null || true)"
  if [[ -d "$path" ]]; then
    kind="directory"
    size_bytes=0
    child_count="$(find "$path" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')"
    preview_note="Pasta com ${child_count:-0} itens"
    size_human="${child_count:-0} itens"
  else
    kind="file"
    size_bytes="$(stat -c '%s' -- "$path" 2>/dev/null || echo 0)"
    child_count=0
    preview_note=""
    size_human="$(human_size "$size_bytes")"
  fi
  jq -cn \
    --arg path "$path" \
    --arg base "$base" \
    --arg parent "$parent" \
    --arg kind "$kind" \
    --arg perms "$perms" \
    --arg modified "$modified" \
    --arg mime "$mime" \
    --arg previewNote "$preview_note" \
    --arg sizeHuman "$size_human" \
    --argjson sizeBytes "${size_bytes:-0}" \
    --argjson childCount "${child_count:-0}" \
    '{
      path: $path,
      base: $base,
      parent: $parent,
      kind: $kind,
      permissions: $perms,
      modified: $modified,
      mime: $mime,
      previewNote: $previewNote,
      sizeHuman: $sizeHuman,
      sizeBytes: $sizeBytes,
      childCount: $childCount
    }'
}

emit_thumbnail() {
  local path="${1:-}"
  [[ -n "$path" && -e "$path" ]] || exit 0
  local cache_dir hash ext thumb
  ext="${path##*.}"
  ext="${ext,,}"
  case "$ext" in
    png|jpg|jpeg|gif|bmp|svg|webp|avif)
      printf '%s\n' "$path"
      return 0
      ;;
    mp4|mkv|avi|webm|mov|m4v)
      ;;
    *)
      exit 0
      ;;
  esac

  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/launcher-thumbs"
  mkdir -p "$cache_dir"
  hash="$(printf '%s' "$path" | sha256sum | awk '{print $1}')"
  thumb="${cache_dir}/${hash}.jpg"
  if [[ -s "$thumb" ]]; then
    printf '%s\n' "$thumb"
    return 0
  fi

  if command -v ffmpegthumbnailer >/dev/null 2>&1; then
    ffmpegthumbnailer -i "$path" -o "$thumb" -s 640 >/dev/null 2>&1 || true
  elif command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -hide_banner -loglevel error -y -ss 00:00:02 -i "$path" -frames:v 1 -vf "scale=640:-1" "$thumb" >/dev/null 2>&1 || true
  fi

  if [[ -s "$thumb" ]]; then
    printf '%s\n' "$thumb"
  fi
}

delete_path() {
  local path="${1:-}"
  [[ -n "$path" && -e "$path" ]] || exit 0
  if command -v gio >/dev/null 2>&1; then
    gio trash -- "$path"
    exit 0
  fi
  if command -v trash-put >/dev/null 2>&1; then
    trash-put -- "$path"
    exit 0
  fi
  echo "Lixeira indisponível (nem 'gio' nem 'trash-put' encontrados). Recusando exclusão permanente por segurança." >&2
  exit 1
}

case "$cmd" in
  search)
    print_search_rows "${2:-}" "${3:-$HOME}"
    ;;
  metadata)
    emit_metadata "${2:-}"
    ;;
  thumbnail)
    emit_thumbnail "${2:-}"
    ;;
  delete)
    delete_path "${2:-}"
    ;;
  *)
    echo "unknown command: $cmd" >&2
    exit 1
    ;;
esac
