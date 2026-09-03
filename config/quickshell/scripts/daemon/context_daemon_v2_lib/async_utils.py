from __future__ import annotations

import asyncio
import logging
import sys


async def run_cmd(*args: str, cwd: str | None = None, timeout: float = 2.0, log: logging.Logger | None = None) -> tuple[int, str]:
    try:
        proc = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
            cwd=cwd,
        )
        try:
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
        except asyncio.TimeoutError:
            try:
                proc.terminate()
                await asyncio.wait_for(proc.wait(), timeout=1.0)
            except Exception:
                pass
            return -1, ""
        return proc.returncode or 0, stdout.decode("utf-8", errors="replace")
    except FileNotFoundError:
        if log:
            log.debug("command not found: %r", args[0])
        return -1, ""
    except Exception as exc:
        if log:
            log.debug("run_cmd%s: %s", args, exc)
        return -1, ""


async def fire_and_forget(*args: str, log: logging.Logger | None = None) -> None:
    try:
        proc = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )
        asyncio.ensure_future(proc.wait())
    except FileNotFoundError:
        if log:
            log.debug("fire: not found: %r", args[0])
    except Exception as exc:
        if log:
            log.debug("fire_and_forget%s: %s", args, exc)


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "--self-test":
    print("ok")
    raise SystemExit(0)
