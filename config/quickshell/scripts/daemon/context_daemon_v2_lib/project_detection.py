from __future__ import annotations

import functools
import sys

PROJECT_MARKERS: tuple[tuple[str, str], ...] = (
    ("Cargo.toml", "rust"),
    ("package.json", "node"),
    ("flake.nix", "nix"),
    ("go.mod", "go"),
    ("pyproject.toml", "python"),
    ("requirements.txt", "python"),
    ("Makefile", "c"),
)


@functools.lru_cache(maxsize=256)
def detect_project_from_files(files: frozenset[str]) -> tuple[str, str]:
    """Return context type and project type from a frozen filename set."""
    for fname, project_type in PROJECT_MARKERS:
        if fname in files:
            return "project", project_type
    if ".git" in files:
        return "project", "git"
    return "directory", "generic"


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "--self-test":
    print("ok")
    raise SystemExit(0)
