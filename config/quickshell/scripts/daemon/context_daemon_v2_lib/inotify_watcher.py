from __future__ import annotations

import asyncio
import ctypes
import ctypes.util
import os
import struct
import sys
from pathlib import Path
from typing import Callable

_libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
_IN_MODIFY = 0x00000002
_IN_CLOSE_WRITE = 0x00000008
_IN_MOVED_TO = 0x00000080
_IN_CREATE = 0x00000100
_IN_NONBLOCK = 0o4000
_INOTIFY_HDR = struct.Struct("iIII")


class InotifyWatcher:
    def __init__(self, path: str, callback: Callable[[], None], log) -> None:
        self._path = path
        self._callback = callback
        self._log = log
        self._fd = -1
        self._wd = -1

    def start(self) -> None:
        parent = str(Path(self._path).parent)
        fd = _libc.inotify_init1(_IN_NONBLOCK)
        if fd < 0:
            self._log.warning("inotify_init1 failed; colors rely on mtime polling")
            return
        wd = _libc.inotify_add_watch(
            fd,
            parent.encode(),
            _IN_CLOSE_WRITE | _IN_MODIFY | _IN_MOVED_TO | _IN_CREATE,
        )
        if wd < 0:
            self._log.warning("inotify_add_watch(%s) failed; errno=%s", parent, ctypes.get_errno())
            os.close(fd)
            return
        self._fd, self._wd = fd, wd
        asyncio.get_event_loop().add_reader(fd, self._on_readable)
        self._log.info("inotify: watching %s/%s", parent, Path(self._path).name)

    def _on_readable(self) -> None:
        try:
            data = os.read(self._fd, 4096)
        except OSError:
            return
        target = Path(self._path).name.encode()
        offset = 0
        while offset + _INOTIFY_HDR.size <= len(data):
            _, mask, _, name_len = _INOTIFY_HDR.unpack_from(data, offset)
            fname = data[offset + _INOTIFY_HDR.size: offset + _INOTIFY_HDR.size + name_len]
            fname = fname.rstrip(b"\x00")
            offset += _INOTIFY_HDR.size + name_len
            if (mask & (_IN_MODIFY | _IN_CLOSE_WRITE | _IN_MOVED_TO | _IN_CREATE)) and (fname == target or not fname):
                self._log.debug("inotify: colors.json changed -> scheduling update")
                self._callback()
                break

    def close(self) -> None:
        if self._fd < 0:
            return
        try:
            asyncio.get_event_loop().remove_reader(self._fd)
        except Exception:
            pass
        try:
            _libc.inotify_rm_watch(self._fd, self._wd)
            os.close(self._fd)
        except OSError:
            pass
        self._fd = -1


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "--self-test":
    print("ok")
    raise SystemExit(0)
