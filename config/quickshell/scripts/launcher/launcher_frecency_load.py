#!/usr/bin/env python3
import json
import sys
import tempfile
from pathlib import Path


def load_frecency(path):
    if not path.exists():
        return []

    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    if not isinstance(data, dict):
        return []

    items = []
    for app_id, raw_count in data.items():
        try:
            count = int(raw_count)
        except (TypeError, ValueError):
            continue
        if count < 0:
            continue
        items.append((str(app_id), count))

    items.sort(key=lambda item: (-item[1], item[0]))
    return items


def main(argv):
    if len(argv) >= 2 and argv[1] == "--self-test":
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as handle:
            json.dump({"alpha.desktop": 4, "beta.desktop": "oops", "gamma.desktop": -1}, handle)
            tmp_path = Path(handle.name)
        try:
            items = load_frecency(tmp_path)
            if items != [("alpha.desktop", 4)]:
                print("self-test failed", file=sys.stderr)
                return 1
            print("ok")
            return 0
        finally:
            tmp_path.unlink(missing_ok=True)

    if len(argv) < 2:
        print("Usage: launcher_frecency_load.py <cache-file>", file=sys.stderr)
        return 1

    path = Path(argv[1])
    try:
        items = load_frecency(path)
    except Exception as exc:
        print(f"[launcher_frecency_load] Failed to parse {path}: {exc}", file=sys.stderr)
        return 0

    for app_id, count in items:
        print(f"{app_id}\t{count}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
