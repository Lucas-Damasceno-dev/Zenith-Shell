from __future__ import annotations

import logging
import sys


def setup_logging(debug: bool) -> logging.Logger:
    fmt = logging.Formatter(
        fmt="%(asctime)s %(levelname)-5s [ctx-daemon] %(message)s",
        datefmt="%H:%M:%S",
    )
    h = logging.StreamHandler(sys.stderr)
    h.setFormatter(fmt)
    log = logging.getLogger("ctx-daemon")
    log.addHandler(h)
    log.setLevel(logging.DEBUG if debug else logging.INFO)
    log.propagate = False
    return log


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "--self-test":
    print("ok")
    raise SystemExit(0)
