#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime_paths.sh
source "$script_dir/../lib/runtime_paths.sh"
qs_ensure_dirs

python3 - "${1:-}" << 'PYEOF'
import os
import sys

term = sys.argv[1].lower() if len(sys.argv) > 1 else ""
home_dir = os.path.expanduser("~")
candidates = [
    os.path.join(home_dir, "Projects"),
    os.path.join(home_dir, "Documents/dev"),
    os.path.join(home_dir, "dev"),
    os.path.join(home_dir, "src"),
    os.path.join(home_dir, "Code"),
    "/etc/nixos"
]
search_roots = [p for p in candidates if os.path.isdir(p)]

projects = []
seen = set()

def check_project(path):
    if path in seen:
        return
    git_dir = os.path.join(path, ".git")
    if os.path.isdir(git_dir) or os.path.isfile(git_dir):
        seen.add(path)
        if not term or term in path.lower():
            try:
                mtime = os.stat(path).st_mtime
            except OSError:
                mtime = 0
            projects.append((mtime, path))

for root_dir in search_roots:
    if not os.path.isdir(root_dir):
        continue
    check_project(root_dir)
    for root, dirs, _ in os.walk(root_dir, followlinks=False):
        rel = os.path.relpath(root, root_dir)
        depth = 0 if rel == "." else rel.count(os.sep) + 1
        if depth >= 3:
            dirs.clear()
            continue
        if ".git" in dirs:
            check_project(root)
            dirs.remove(".git")

projects.sort(key=lambda x: x[0], reverse=True)
for _, p in projects[:30]:
    print(p)
PYEOF
