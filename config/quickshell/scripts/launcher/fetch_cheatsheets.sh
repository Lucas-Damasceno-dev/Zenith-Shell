#!/bin/sh
if [ "${1:-}" = "--self-test" ]; then
    echo ok
    exit 0
fi

python_bin="$(command -v python3 || echo "python3")"

script_dir="$(dirname -- "$0")"
exec "$python_bin" "$script_dir/get_cheatsheets.py" "$@"
