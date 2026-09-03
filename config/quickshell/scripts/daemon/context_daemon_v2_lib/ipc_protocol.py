from __future__ import annotations

import json
import sys
from typing import Any


def sanitize_command(
    raw: str,
    *,
    max_bytes: int,
    allowed_keys: frozenset[str],
    allowed_actions: frozenset[str],
    log: Any,
) -> dict[str, str] | None:
    """Validate command payload against strict size/key/action allowlists."""
    if len(raw.encode()) > max_bytes:
        log.warning("IpcServer: oversized payload rejected")
        return None

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        log.warning("IpcServer: invalid JSON rejected")
        return None

    if not isinstance(data, dict):
        return None

    extra = set(data.keys()) - allowed_keys
    if extra:
        log.warning("IpcServer: unknown keys %s", extra)
        return None

    action = data.get("action", "")
    if not isinstance(action, str) or action not in allowed_actions:
        log.warning("IpcServer: invalid action %r", action)
        return None

    target = data.get("target", "")
    if not isinstance(target, str) or len(target) > 256:
        log.warning("IpcServer: invalid target")
        return None

    return {"action": action, "target": target}


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "--self-test":
    print("ok")
    raise SystemExit(0)
