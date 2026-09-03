#!/usr/bin/env bash
set -euo pipefail

user_name="${USER:-$(id -un)}"
home_dir="${HOME:-}"
if [[ -z "$home_dir" ]]; then
    home_dir="$(awk -F: -v user="$user_name" '$1==user {print $6; exit}' /etc/passwd 2>/dev/null || true)"
    if [[ -z "$home_dir" ]]; then
        home_dir="/home/$user_name"
    fi
    export HOME="$home_dir"
fi

export PATH="$home_dir/.npm-global/bin:$home_dir/.nix-profile/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:${PATH:-}"
if [[ -n "${GCC_LIB_DIR:-}" ]]; then
    export LD_LIBRARY_PATH="$GCC_LIB_DIR:${LD_LIBRARY_PATH:-}"
fi
export NIX_LD="${NIX_LD:-/run/current-system/sw/share/nix-ld/lib/ld.so}"
export NIX_LD_LIBRARY_PATH="${NIX_LD_LIBRARY_PATH:-/run/current-system/sw/share/nix-ld/lib}"
export OPENCODE_PERMISSION='{"*": "allow"}'
export OPENCODE_DISABLE_AUTOUPDATE=true

if [[ "${1:-}" == "--self-test" ]]; then
    command -v python3 >/dev/null 2>&1 || { echo "missing python3"; exit 1; }
    command -v timeout >/dev/null 2>&1 || { echo "missing timeout"; exit 1; }
    echo "ok"
    exit 0
fi

tier="${1:-default}"
shift || true
export PROMPT_DATA="$*"

[[ -n "$PROMPT_DATA" ]] || exit 0

prepare_popup_context() {
    local runtime_base="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    mkdir -p "$runtime_base"
    chmod 0700 "$runtime_base" 2>/dev/null || true
    OPENCODE_RUN_DIR="$(mktemp -d "${runtime_base}/opencode-popup.XXXXXX")"
    trap 'rm -rf "$OPENCODE_RUN_DIR"' EXIT
    cd "$OPENCODE_RUN_DIR" || true
}

run_model() {
    local label="$1"
    local model="$2"
    local variant="$3"
    local err_file status
    local runtime_base="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    mkdir -p "$runtime_base"
    chmod 0700 "$runtime_base" 2>/dev/null || true
    err_file="$(mktemp "${runtime_base}/opencode_err.XXXXXX")"
    chmod 0600 "$err_file"
    status=0

    local timeout_s=180

    local isolated_data_dir="${runtime_base}/opencode_data_${label//[^a-zA-Z0-9_-]/_}"
    mkdir -p "$isolated_data_dir"
    chmod 0700 "$isolated_data_dir" 2>/dev/null || true
    mkdir -p "$isolated_data_dir/opencode"
    if [[ -f "$home_dir/.local/share/opencode/auth.json" ]]; then
        cp -u "$home_dir/.local/share/opencode/auth.json" "$isolated_data_dir/opencode/" 2>/dev/null || true
        chmod 0600 "$isolated_data_dir/opencode/auth.json" 2>/dev/null || true
    fi

    local -a cmd=(opencode run)
    if [[ -n "${OPENCODE_RUN_DIR:-}" ]]; then
        cmd+=(--dir "$OPENCODE_RUN_DIR")
    fi
    cmd+=("$PROMPT_DATA" --model "$model")
    if [[ -n "$variant" && "$variant" != "medium" && "$variant" != "default" ]]; then
        cmd+=(--variant "$variant")
    fi

    # Print the model label immediately
    printf 'MODEL:%s\n' "$label"
    
    # Use python pty to fake a TTY aggressively so opencode Node.js streams per-token, avoiding script hangs
    export NO_COLOR=1
    export XDG_DATA_HOME="$isolated_data_dir"
    
    timeout "$timeout_s" python3 -c '
import pty, os, sys
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], sys.argv[1:])
else:
    while True:
        try:
            data = os.read(fd, 1024)
        except OSError:
            break
        if not data:
            break
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()
    _, status = os.waitpid(pid, 0)
    sys.exit(os.waitstatus_to_exitcode(status) if hasattr(os, "waitstatus_to_exitcode") else os.WEXITSTATUS(status))
' "${cmd[@]}" 2>"$err_file" || status=$?

    if [[ "$status" -ne 0 ]]; then
        local err_content=""
        if [[ -s "$err_file" ]]; then
            err_content="$(grep -i 'error\|failed\|rate limit\|timeout' "$err_file" | tail -3 || true)"
        fi

        if [[ -n "$err_content" ]]; then
            printf '\n\nErro: %s\n\n' "$err_content"
        elif [[ "$status" -eq 124 ]]; then
            printf '\n\nFalha: tempo esgotado ao consultar %s.\n\n' "$model"
        fi
    fi

    rm -f "$err_file"
    return 0
}

case "$tier" in
    custom)
        custom_label="${1:-slot}"
        custom_model="${2:-github-copilot/gpt-5-mini}"
        custom_variant="${3:-medium}"
        shift 3 || true
        export PROMPT_DATA="$*"
        [[ -n "$PROMPT_DATA" ]] || exit 0
        prepare_popup_context
        run_model "$custom_label" "$custom_model" "$custom_variant"
        ;;
    fast)
        prepare_popup_context
        run_model "flash" "google/gemini-2.5-flash" "default"
        ;;
    smart)
        prepare_popup_context
        run_model "pro" "google/gemini-2.5-pro" "default"
        ;;
    all)
        prepare_popup_context
        run_model "flash" "google/gemini-2.5-flash" "default"
        run_model "gpt5mini" "github-copilot/gpt-5-mini" "medium"
        ;;
    *)
        prepare_popup_context
        run_model "gpt5mini" "github-copilot/gpt-5-mini" "medium"
        ;;
esac
