#!/usr/bin/env python3
"""context_daemon_v2.py — Hyprland context daemon (asyncio + D-Bus + DDD).

Architecture:
  GitCollector       — project detection (LRU-cached), git branch/dirty (500ms CB)
  SystemMetrics      — systemd service monitor via D-Bus (dbus-fast)
  NetworkFixer       — NM enable/disable via D-Bus (dbus-fast, system bus)
  NetworkPublisher   — event-driven NM/BlueZ mapper -> Quickshell IPC JSON
  NotificationManager— DND state, D-Bus notify-send, dunst subprocess
  IpcServer          — hardened Unix socket: SO_PEERCRED + JSON allowlist
  IpcPublisher       — asyncio.Queue drained by single coroutine (zero threads)
  ColorWatcher       — inotify watcher on matugen colors.json (ctypes, no deps)
  ProcessCache       — TTL-bounded /proc/pid/cwd cache
  ContextCollector   — orchestrates all DDD sub-modules
  ContextEngine      — top-level; asyncio.Lock prevents update stampede

All blocking I/O eliminated; D-Bus replaces subprocess for systemd, NM, notify.
Circuit Breaker on git calls: 2 failures at 500ms timeout -> 30s silent fallback.
Graceful shutdown via SIGTERM/SIGINT with socket cleanup and task cancellation.
Structured logging via Python logging module (INFO/WARN/ERROR -> journalctl).
"""

import asyncio
import collections
import dataclasses
import functools
import json
import os
import signal
import socket as _socket_module
import struct
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, cast

from context_daemon_v2_lib.constants import (
    COLORS_FILE,
    COMMAND_SOCKET,
    DEBUG,
    HYPR_SIG,
    ICONS,
    MONITORED_SERVICES,
    QUICKSHELL_BIN,
    RUNTIME_DIR,
    WINDOW_CLASSES_WITH_CWD,
    _CMD_ALLOWED_ACTIONS,
    _CMD_ALLOWED_KEYS,
    _CMD_MAX_BYTES,
)
from context_daemon_v2_lib.async_utils import run_cmd, fire_and_forget
from context_daemon_v2_lib.ipc_protocol import sanitize_command
from context_daemon_v2_lib.inotify_watcher import InotifyWatcher
from context_daemon_v2_lib.logging_utils import setup_logging
from context_daemon_v2_lib.network_state import build_bluez_state, build_nm_state
from context_daemon_v2_lib.project_detection import detect_project_from_files

try:
    from dbus_fast.aio import MessageBus as _DbusMessageBus
    from dbus_fast import BusType as _DbusBusType

    _DBUS_AVAILABLE = True
except ImportError:
    _DbusMessageBus = None
    _DbusBusType = None
    _DBUS_AVAILABLE = False

# ─── Structured logging ───────────────────────────────────────────────────────
_log = setup_logging(DEBUG)


async def _run(
    *args: str, cwd: str | None = None, timeout: float = 2.0
) -> tuple[int, str]:
    return await run_cmd(*args, cwd=cwd, timeout=timeout, log=_log)


async def _fire(*args: str) -> None:
    await fire_and_forget(*args, log=_log)


# ─── Circuit Breaker ──────────────────────────────────────────────────────────
class CircuitBreaker:
    """Async circuit breaker with configurable failure threshold and recovery.

    Git calls use threshold=2, timeout_per_call=0.5s:
    Two consecutive git timeouts/failures -> breaker opens -> silent fallback for 30s.
    This protects the event loop from stalling on network mounts or huge repos.
    """

    def __init__(
        self,
        failure_threshold: int = 3,
        recovery_timeout: float = 30.0,
        name: str = "?",
    ) -> None:
        self._threshold = failure_threshold
        self._recovery = recovery_timeout
        self._name = name
        self._failures = 0
        self._last_fail = 0.0
        self._state = "CLOSED"

    async def call(self, coro):
        now = time.monotonic()
        if self._state == "OPEN":
            if now - self._last_fail >= self._recovery:
                self._state = "HALF-OPEN"
                _log.debug(f"CB[{self._name}] HALF-OPEN")
            else:
                return None
        try:
            result = await coro
            if self._state == "HALF-OPEN":
                self._state = "CLOSED"
                self._failures = 0
                _log.info(f"CB[{self._name}] CLOSED (recovered)")
            return result
        except Exception as exc:
            self._failures += 1
            self._last_fail = time.monotonic()
            if self._failures >= self._threshold:
                if self._state != "OPEN":
                    _log.warning(
                        f"CB[{self._name}] OPEN after {self._failures} failures: {exc}"
                    )
                self._state = "OPEN"
            return None


# ─── TTL-bounded LRU cache ─────────────────────────────────────────────────────
class _TTLCache:
    """OrderedDict LRU with per-entry TTL. Prevents unbounded growth."""

    __slots__ = ("_cache", "_maxsize", "_ttl")

    def __init__(self, maxsize: int = 64, ttl: float = 10.0) -> None:
        self._cache = collections.OrderedDict()
        self._maxsize = maxsize
        self._ttl = ttl

    def get(self, key) -> tuple[Any, bool]:
        entry = self._cache.get(key)
        if entry is None:
            return None, False
        value, ts = entry
        if time.monotonic() - ts > self._ttl:
            del self._cache[key]
            return None, False
        self._cache.move_to_end(key)
        return value, True

    def set(self, key, value) -> None:
        if key in self._cache:
            self._cache.move_to_end(key)
        self._cache[key] = (value, time.monotonic())
        while len(self._cache) > self._maxsize:
            self._cache.popitem(last=False)


# ─── Domain: Data ─────────────────────────────────────────────────────────────
@dataclass
class ContextSnapshot:
    context: str = "desktop"
    path: str = ""
    project_type: str = "generic"
    icon: str = ""
    git_branch: str = ""
    git_dirty: bool = False
    notes: str = ""
    diagnostics: dict = field(default_factory=lambda: {"errors": 0, "warnings": 0})
    services: list = field(default_factory=list)
    border_color: str = "rgb(a7c080)"
    timestamp: float = 0.0

    # ── IPC-only dict: only fields QML actually consumes ──
    _IPC_FIELDS = frozenset(
        {"path", "project_type", "icon", "git_branch", "notes", "services"}
    )

    def to_dict(self) -> dict:
        return dataclasses.asdict(self)

    def to_ipc_dict(self) -> dict:
        """Minimal payload: only fields the QML side binds to."""
        return {
            k: v for k, v in dataclasses.asdict(self).items() if k in self._IPC_FIELDS
        }

    def stable_payload(self) -> str:
        d = self.to_ipc_dict()
        return json.dumps(d, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


# ─── IPC Publisher ────────────────────────────────────────────────────────────
class IpcPublisher:
    """asyncio.Queue drained by a single coroutine. Zero threads."""

    _QUEUE_SIZE = 64
    _MIN_EMIT_INTERVAL = 0.18

    def __init__(self) -> None:
        self._queue = asyncio.Queue(maxsize=self._QUEUE_SIZE)
        self._last_stable = ""
        self._last_emit_ts = 0.0

    def start(self) -> None:
        asyncio.ensure_future(self._drain())

    def publish_if_changed(self, snapshot: ContextSnapshot) -> bool:
        # Single dict + single serialisation; stable_payload reuses to_ipc_dict
        stable = snapshot.stable_payload()
        if stable == self._last_stable:
            return False
        self._last_stable = stable
        payload = stable  # ipc_dict is already the minimal payload
        if self._queue.full():
            try:
                self._queue.get_nowait()
            except asyncio.QueueEmpty:
                pass
        try:
            self._queue.put_nowait(payload)
            return True
        except asyncio.QueueFull:
            return False

    async def _drain(self) -> None:
        while True:
            payload = await self._queue.get()
            while True:
                try:
                    payload = self._queue.get_nowait()
                except asyncio.QueueEmpty:
                    break

            remaining = self._MIN_EMIT_INTERVAL - (
                time.monotonic() - self._last_emit_ts
            )
            if remaining > 0:
                await asyncio.sleep(remaining)

            self._last_emit_ts = time.monotonic()
            rc, _ = await _run(
                QUICKSHELL_BIN,
                "ipc",
                "--any-display",
                "call",
                "ipcHandler",
                "updateContext",
                payload,
                timeout=1.5,
            )
            if rc != 0:
                _log.warning(f"IpcPublisher: ipc call failed rc={rc}")


# ─── DDD: GitCollector ────────────────────────────────────────────────────────
class GitCollector:
    """DDD: project detection + git branch/dirty.

    Circuit Breaker: threshold=2, call timeout=0.5s -> silent fallback for 30s.
    Language detection: @lru_cache(256) on frozenset of filenames.
    TTL cache: git results cached 10s, notes 30s (both bounded to 64 entries).
    """

    def __init__(self) -> None:
        self._branch_cb = CircuitBreaker(2, 30.0, "git-branch")
        self._status_cb = CircuitBreaker(2, 30.0, "git-status")
        self._git_cache = _TTLCache(maxsize=64, ttl=10.0)
        self._notes_cache = _TTLCache(maxsize=32, ttl=30.0)
        self._colors: dict = {}
        self._colors_mtime: float = 0.0

    def detect_project(self, path: str) -> tuple[str, str, str]:
        p = Path(path)
        try:
            files = frozenset(f.name for f in p.iterdir() if f.is_file())
        except OSError:
            return "desktop", "generic", ICONS["default"]
        ctx_type, proj_type = detect_project_from_files(files)
        if ctx_type == "directory" and (p / ".git").is_dir():
            ctx_type, proj_type = "project", "git"
        return ctx_type, proj_type, ICONS.get(proj_type, ICONS["default"])

    async def git_info(self, path: str) -> tuple[str, bool]:
        cached, hit = self._git_cache.get(path)
        if hit:
            return cached
        branch = await self._branch_cb.call(self._fetch_branch(path)) or ""
        # git_dirty removed: QML never consumes it, and `git status --porcelain`
        # is expensive on large repos (full working-tree scan).
        result = (branch, False)
        self._git_cache.set(path, result)
        return result

    async def _fetch_branch(self, path: str) -> str:
        rc, out = await _run("git", "branch", "--show-current", cwd=path, timeout=0.5)
        if rc != 0:
            raise RuntimeError(f"git branch rc={rc}")
        return out.strip()

    def read_notes(self, path: str) -> str:
        cached, hit = self._notes_cache.get(path)
        if hit:
            return cached
        try:
            f = Path(path) / ".project-notes"
            text = (
                f.read_text(encoding="utf-8", errors="replace")[:1024].strip()
                if f.exists()
                else ""
            )
        except OSError:
            text = ""
        self._notes_cache.set(path, text)
        return text

    def reload_colors(self) -> None:
        """Called by InotifyWatcher or on startup."""
        try:
            p = Path(COLORS_FILE)
            if not p.exists():
                return
            mtime = p.stat().st_mtime
            if mtime == self._colors_mtime:
                return
            data = json.loads(p.read_text())
            if "colors" in data:
                self._colors = data["colors"]
            self._colors_mtime = mtime
            _log.info("colors.json reloaded via inotify")
        except (OSError, json.JSONDecodeError) as exc:
            _log.debug(f"reload_colors: {exc}")

    def border_color(self) -> str:
        c = self._colors
        return c["primary"] if c and "primary" in c else "rgb(a7c080)"


# ─── DDD: SystemMetrics ───────────────────────────────────────────────────────
class SystemMetrics:
    """DDD: systemd user service monitor.

    Uses dbus-fast ListUnitsByNames (single D-Bus round-trip for all 6 services).
    Subprocess fallback on D-Bus unavailability or introspection failure.
    """

    def __init__(self) -> None:
        self._state: list = []
        self._last_check = 0.0
        self._interval = 5.0
        self._cb = CircuitBreaker(3, 15.0, "systemd-dbus")
        self._mgr = None
        self._dbus_ok = False

    async def connect(self) -> None:
        if not _DBUS_AVAILABLE or _DbusMessageBus is None or _DbusBusType is None:
            _log.warning("dbus-fast not available; systemd monitor uses subprocess")
            return
        try:
            bus = await _DbusMessageBus(bus_type=_DbusBusType.SESSION).connect()
            intr = await asyncio.wait_for(
                bus.introspect("org.freedesktop.systemd1", "/org/freedesktop/systemd1"),
                timeout=5.0,
            )
            proxy = bus.get_proxy_object(
                "org.freedesktop.systemd1", "/org/freedesktop/systemd1", intr
            )
            self._mgr = cast(
                Any, proxy.get_interface("org.freedesktop.systemd1.Manager")
            )
            self._dbus_ok = True
            _log.info("SystemMetrics: D-Bus systemd1 ready")
        except Exception as exc:
            _log.warning(f"SystemMetrics: D-Bus failed ({exc}); subprocess fallback")

    async def check(self) -> list:
        now = time.monotonic()
        if now - self._last_check < self._interval:
            return self._state
        self._last_check = now
        coro = self._check_dbus() if self._dbus_ok else self._check_subprocess()
        result = await self._cb.call(coro)
        if result is not None:
            self._state = result
        return self._state

    async def _check_dbus(self) -> list:
        names = list(MONITORED_SERVICES.keys())
        mgr = cast(Any, self._mgr)
        units = await mgr.call_list_units_by_names(names)
        by_name = {u[0]: u[3] for u in units}
        return [
            {"service": s, "label": l, "state": by_name.get(s, "unknown")}
            for s, l in MONITORED_SERVICES.items()
        ]

    async def _check_subprocess(self) -> list:
        cmd = (
            "systemctl",
            "--user",
            "show",
            "--property=Id,ActiveState",
            *list(MONITORED_SERVICES.keys()),
        )
        rc, out = await _run(*cmd, timeout=2.0)
        if rc != 0:
            return self._state
        states: dict[str, str] = {}
        cur = None
        for line in out.splitlines():
            if line.startswith("Id="):
                cur = line.split("=", 1)[1]
            elif line.startswith("ActiveState=") and cur:
                states[cur] = line.split("=", 1)[1]
        return [
            {"service": s, "label": l, "state": states.get(s, "unknown")}
            for s, l in MONITORED_SERVICES.items()
        ]

    async def restart_service(self, service: str) -> None:
        if service not in MONITORED_SERVICES:
            _log.warning(f"SystemMetrics: unknown service {service!r}")
            return
        if self._dbus_ok and self._mgr:
            try:
                mgr = cast(Any, self._mgr)
                await mgr.call_restart_unit(service, "replace")
                _log.info(f"SystemMetrics: restarted {service} via D-Bus")
                return
            except Exception as exc:
                _log.warning(f"D-Bus restart {service}: {exc}; subprocess fallback")
        await _fire("systemctl", "--user", "restart", service)


# ─── DDD: NetworkFixer ────────────────────────────────────────────────────────
class NetworkFixer:
    """DDD: NM enable/disable via D-Bus (system bus).

    D-Bus: org.freedesktop.NetworkManager.Enable(b)
    """

    def __init__(self) -> None:
        self._nm = None
        self._dbus_ok = False

    async def connect(self) -> None:
        if not _DBUS_AVAILABLE or _DbusMessageBus is None or _DbusBusType is None:
            _log.warning("NetworkFixer: dbus-fast unavailable; quick-fix disabled")
            return
        try:
            bus = await _DbusMessageBus(bus_type=_DbusBusType.SYSTEM).connect()
            intr = await asyncio.wait_for(
                bus.introspect(
                    "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager"
                ),
                timeout=5.0,
            )
            proxy = bus.get_proxy_object(
                "org.freedesktop.NetworkManager",
                "/org/freedesktop/NetworkManager",
                intr,
            )
            self._nm = cast(Any, proxy.get_interface("org.freedesktop.NetworkManager"))
            self._dbus_ok = True
            _log.info("NetworkFixer: D-Bus NM ready (system bus)")
        except Exception as exc:
            self._dbus_ok = False
            _log.warning(f"NetworkFixer: D-Bus failed ({exc}); quick-fix disabled")

    async def toggle(self) -> None:
        if not self._dbus_ok or self._nm is None:
            await self.connect()
        if not self._dbus_ok or self._nm is None:
            _log.warning("NetworkFixer: skip toggle; NetworkManager D-Bus unavailable")
            return
        nm = cast(Any, self._nm)
        try:
            await nm.call_enable(False)
            _log.info("NetworkFixer: NM disabled via D-Bus")
        except Exception as exc:
            self._dbus_ok = False
            _log.error(f"NetworkFixer: failed disabling NM via D-Bus: {exc}")
            return
        await asyncio.sleep(1)
        try:
            await nm.call_enable(True)
            _log.info("NetworkFixer: NM re-enabled via D-Bus")
        except Exception as exc:
            self._dbus_ok = False
            _log.error(f"NetworkFixer: failed enabling NM via D-Bus: {exc}")


# ─── DDD: NetworkPublisher ────────────────────────────────────────────────────
class NetworkPublisher:
    """DDD: event-driven connectivity mapper (NM + BlueZ -> IPC JSON).

    Strategy:
    - Listen to system-bus signals and coalesce bursts (RSSI/property storms).
    - Rebuild snapshot from ObjectManager GetManagedObjects.
    - Publish only changed payloads to Quickshell IPC (updateConnectivity).
    """

    _NM_OM_PATHS = ("/org/freedesktop", "/org/freedesktop/NetworkManager")
    _BLUEZ_OM_PATHS = ("/",)

    def __init__(self, debounce_s: float = 0.28) -> None:
        self._debounce_s = debounce_s
        self._dbus_ok = False
        self._bus = None
        self._nm_om = None
        self._bluez_om = None
        self._refresh_task: asyncio.Task | None = None
        self._heartbeat_task: asyncio.Task | None = None
        self._refresh_lock = asyncio.Lock()
        self._last_stable_payload = ""
        self._last_emit_ts = 0.0
        self._max_idle_emit_s = 35.0
        self._heartbeat_interval_s = 15.0

    @staticmethod
    def _build_nm_state(managed_raw: Any) -> dict[str, Any]:
        return build_nm_state(managed_raw)

    @staticmethod
    def _build_bluez_state(managed_raw: Any) -> dict[str, Any]:
        return build_bluez_state(managed_raw)

    async def _connect_object_manager(
        self, bus: Any, bus_name: str, paths: tuple[str, ...]
    ) -> Any:
        for path in paths:
            try:
                introspection = await asyncio.wait_for(
                    bus.introspect(bus_name, path), timeout=4.0
                )
                proxy = bus.get_proxy_object(bus_name, path, introspection)
                return cast(
                    Any, proxy.get_interface("org.freedesktop.DBus.ObjectManager")
                )
            except Exception:
                continue
        return None

    async def connect(self) -> None:
        if not _DBUS_AVAILABLE or _DbusMessageBus is None or _DbusBusType is None:
            _log.warning(
                "NetworkPublisher: dbus-fast unavailable; IPC connectivity stream disabled"
            )
            return

        try:
            bus = await _DbusMessageBus(bus_type=_DbusBusType.SYSTEM).connect()
        except Exception as exc:
            _log.warning(f"NetworkPublisher: failed connecting system bus ({exc})")
            return

        self._nm_om = await self._connect_object_manager(
            bus, "org.freedesktop.NetworkManager", self._NM_OM_PATHS
        )
        self._bluez_om = await self._connect_object_manager(
            bus, "org.bluez", self._BLUEZ_OM_PATHS
        )

        self._dbus_ok = bool(self._nm_om or self._bluez_om)
        if not self._dbus_ok:
            _log.warning("NetworkPublisher: no ObjectManager endpoints available")
            return

        self._bus = bus
        bus.add_message_handler(self._on_bus_message)
        _log.info(
            "NetworkPublisher: ready",
            extra={
                "nm": bool(self._nm_om),
                "bluez": bool(self._bluez_om),
            },
        )
        self._heartbeat_task = asyncio.create_task(self._heartbeat_loop())
        await self.refresh_and_publish(reason="startup")

    async def _heartbeat_loop(self) -> None:
        while self._dbus_ok:
            try:
                await asyncio.sleep(self._heartbeat_interval_s)
            except asyncio.CancelledError:
                return
            await self.refresh_and_publish(reason="heartbeat")

    def _on_bus_message(self, message: Any) -> None:
        if not self._dbus_ok:
            return

        member = str(getattr(message, "member", "") or "")
        interface = str(getattr(message, "interface", "") or "")
        path = str(getattr(message, "path", "") or "")

        if member == "":
            return

        nm_event = path.startswith("/org/freedesktop/NetworkManager") and (
            member
            in {
                "PropertiesChanged",
                "StateChanged",
                "DeviceAdded",
                "DeviceRemoved",
                "AccessPointAdded",
                "AccessPointRemoved",
                "InterfacesAdded",
                "InterfacesRemoved",
            }
            or interface.startswith("org.freedesktop.NetworkManager")
        )

        bluez_event = (path.startswith("/org/bluez") or path == "/") and (
            member
            in {
                "PropertiesChanged",
                "InterfacesAdded",
                "InterfacesRemoved",
                "DeviceAdded",
                "DeviceRemoved",
            }
            or interface.startswith("org.bluez")
        )

        if nm_event or bluez_event:
            self.request_refresh(f"{member}:{path}")

    def request_refresh(self, reason: str = "signal") -> None:
        if not self._dbus_ok:
            return
        if self._refresh_task is not None and not self._refresh_task.done():
            return
        self._refresh_task = asyncio.create_task(self._coalesced_refresh(reason))

    async def _coalesced_refresh(self, _reason: str) -> None:
        try:
            await asyncio.sleep(self._debounce_s)
            await self.refresh_and_publish(reason="coalesced")
        except asyncio.CancelledError:
            return

    async def _read_nm_state(self) -> dict[str, Any]:
        default = {
            "wifi": {
                "enabled": False,
                "connected": False,
                "ssid": "",
                "signal": 0,
                "networks": [],
                "local_ip": "",
                "gateway": "",
                "dns": [],
                "dns_text": "",
                "link_speed": "",
            },
            "vpn": {"active": False, "name": ""},
        }
        if self._nm_om is None:
            return default
        try:
            managed = await cast(Any, self._nm_om).call_get_managed_objects()
            return self._build_nm_state(managed)
        except Exception as exc:
            _log.debug(f"NetworkPublisher: NM snapshot failed ({exc})")
            return default

    async def _read_bluez_state(self) -> dict[str, Any]:
        default = {
            "enabled": False,
            "pairable": False,
            "discoverable": False,
            "scanning": False,
            "devices": [],
        }
        if self._bluez_om is None:
            return default
        try:
            managed = await cast(Any, self._bluez_om).call_get_managed_objects()
            return self._build_bluez_state(managed)
        except Exception as exc:
            _log.debug(f"NetworkPublisher: BlueZ snapshot failed ({exc})")
            return default

    async def refresh_and_publish(self, reason: str = "manual") -> None:
        if not self._dbus_ok:
            return
        if self._refresh_lock.locked():
            return

        async with self._refresh_lock:
            nm_state, bt_state = await asyncio.gather(
                self._read_nm_state(),
                self._read_bluez_state(),
                return_exceptions=False,
            )

            payload_dict = {
                "type": "network_update",
                "version": 1,
                "wifi": nm_state.get("wifi", {}),
                "vpn": nm_state.get("vpn", {}),
                "bluetooth": bt_state,
            }

            stable_payload = json.dumps(
                payload_dict, sort_keys=True, ensure_ascii=False, separators=(",", ":")
            )
            now = time.monotonic()
            unchanged = stable_payload == self._last_stable_payload
            if unchanged and (now - self._last_emit_ts) < self._max_idle_emit_s:
                return

            self._last_stable_payload = stable_payload
            payload_dict["timestamp"] = int(time.time() * 1000)
            payload = json.dumps(
                payload_dict, sort_keys=True, ensure_ascii=False, separators=(",", ":")
            )
            rc, _ = await _run(
                QUICKSHELL_BIN,
                "ipc",
                "--any-display",
                "call",
                "ipcHandler",
                "updateConnectivity",
                payload,
                timeout=1.5,
            )
            if rc != 0:
                _log.debug(
                    f"NetworkPublisher: ipc updateConnectivity failed rc={rc} reason={reason}"
                )
            else:
                self._last_emit_ts = now

    def shutdown(self) -> None:
        if self._refresh_task is not None and not self._refresh_task.done():
            self._refresh_task.cancel()
        if self._heartbeat_task is not None and not self._heartbeat_task.done():
            self._heartbeat_task.cancel()


# ─── DDD: NotificationManager ─────────────────────────────────────────────────
class NotificationManager:
    """DDD: DND state + D-Bus org.freedesktop.Notifications.

    notify-send replaced with D-Bus call_notify.
    DND (dunst set-paused) kept as subprocess: Quickshell has its own notif
    daemon and dunst D-Bus pause interface is non-standard across versions.
    """

    CODING_TYPES = frozenset(["rust", "c", "cpp", "go", "python", "nix", "node"])
    _DND_FILE = Path(RUNTIME_DIR) / "quickshell_dnd.state"

    def __init__(self) -> None:
        self._active = self._DND_FILE.exists()
        self._notif = None
        self._dbus_ok = False

    async def connect(self) -> None:
        if not _DBUS_AVAILABLE or _DbusMessageBus is None or _DbusBusType is None:
            return
        try:
            bus = await _DbusMessageBus(bus_type=_DbusBusType.SESSION).connect()
            intr = await asyncio.wait_for(
                bus.introspect(
                    "org.freedesktop.Notifications", "/org/freedesktop/Notifications"
                ),
                timeout=5.0,
            )
            proxy = bus.get_proxy_object(
                "org.freedesktop.Notifications",
                "/org/freedesktop/Notifications",
                intr,
            )
            self._notif = cast(
                Any, proxy.get_interface("org.freedesktop.Notifications")
            )
            self._dbus_ok = True
            _log.info("NotificationManager: D-Bus Notifications ready")
        except Exception as exc:
            _log.warning(
                f"NotificationManager: D-Bus failed ({exc}); notify-send fallback"
            )

    async def apply_policy(self, snapshot: ContextSnapshot) -> None:
        is_coding = (
            snapshot.context == "project" and snapshot.project_type in self.CODING_TYPES
        )
        if is_coding and not self._active:
            await self._set_dnd(True)
        elif not is_coding and self._active:
            await self._set_dnd(False)

    async def _set_dnd(self, enabled: bool) -> None:
        try:
            await _fire("dunstctl", "set-paused", "true" if enabled else "false")
            if enabled:
                await self.send_notification(
                    "Focus Mode", "Coding Context", "Notificações pausadas.", urgency=2
                )
                self._DND_FILE.touch()
            else:
                self._DND_FILE.unlink(missing_ok=True)
            self._active = enabled
            _log.info(f"NotificationManager: DND={'on' if enabled else 'off'}")
        except Exception as exc:
            _log.error(f"NotificationManager._set_dnd({enabled}): {exc}")

    async def send_notification(
        self, app: str, summary: str, body: str, urgency: int = 1
    ) -> None:
        if self._dbus_ok and self._notif:
            try:
                notif = cast(Any, self._notif)
                await notif.call_notify(app, 0, "", summary, body, [], {}, 5000)
                return
            except Exception as exc:
                _log.debug(f"D-Bus Notify failed ({exc}); notify-send fallback")
        lvl = ["low", "normal", "critical"][min(urgency, 2)]
        await _fire("notify-send", "-u", lvl, "-a", app, summary, body)


# ─── IpcServer (hardened command socket) ─────────────────────────────────────
def _sanitize_command(raw: str) -> dict | None:
    return sanitize_command(
        raw,
        max_bytes=_CMD_MAX_BYTES,
        allowed_keys=_CMD_ALLOWED_KEYS,
        allowed_actions=_CMD_ALLOWED_ACTIONS,
        log=_log,
    )


class IpcServer:
    """Hardened Unix socket command server.

    Layer 1 — chmod 0600   : OS-level user restriction
    Layer 2 — SO_PEERCRED  : UID verification (defence-in-depth)
    Layer 3 — JSON allowlist: only known keys/actions accepted
    Layer 4 — Size limit   : 4 KiB max (memory exhaustion guard)
    """

    def __init__(
        self,
        svc: SystemMetrics,
        net: NetworkFixer,
        notif: NotificationManager,
        on_update,
    ) -> None:
        self._svc = svc
        self._net = net
        self._notif = notif
        self._on_update = on_update

    async def start(self) -> None:
        sock_path = Path(COMMAND_SOCKET)
        if sock_path.exists():
            try:
                sock_path.unlink()
            except OSError:
                pass
        server = await asyncio.start_unix_server(self._handle, path=str(sock_path))
        os.chmod(str(sock_path), 0o600)
        asyncio.ensure_future(server.serve_forever())
        _log.info(f"IpcServer listening on {sock_path}")

    async def _handle(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) -> None:
        try:
            sock = writer.get_extra_info("socket")
            if sock is not None:
                try:
                    raw_cred = sock.getsockopt(
                        _socket_module.SOL_SOCKET,
                        _socket_module.SO_PEERCRED,
                        struct.calcsize("3i"),
                    )
                    _, uid, _ = struct.unpack("3i", raw_cred)
                    if uid != os.getuid():
                        _log.warning(f"IpcServer: rejected uid={uid}")
                        writer.close()
                        return
                except OSError:
                    pass
            data = await reader.read(_CMD_MAX_BYTES + 1)
            if len(data) > _CMD_MAX_BYTES:
                _log.warning("IpcServer: payload exceeds max size")
                return
            raw = data.decode("utf-8", errors="replace").strip()
            if not raw:
                return
            cmd = _sanitize_command(raw)
            if cmd is None:
                return
            await self._dispatch(cmd)
        except Exception as exc:
            _log.error(f"IpcServer._handle: {exc}")
        finally:
            try:
                writer.close()
                await writer.wait_closed()
            except Exception:
                pass

    async def _dispatch(self, cmd: dict) -> None:
        action, target = cmd["action"], cmd["target"]
        _log.info(f"IpcServer: dispatch action={action!r} target={target!r}")
        if action == "restart_service":
            await self._svc.restart_service(target)
            await asyncio.sleep(1)
            await self._on_update()
        elif action == "quick_fix":
            if target == "network":
                await self._net.toggle()
            elif target == "audio":
                await self._svc.restart_service("pipewire.service")
                await asyncio.sleep(0.5)
                await self._svc.restart_service("wireplumber.service")
            elif target == "portal":
                await self._svc.restart_service("xdg-desktop-portal.service")
                await asyncio.sleep(0.5)
                await self._svc.restart_service("xdg-desktop-portal-hyprland.service")
            elif target == "quickshell":
                await self._svc.restart_service("quickshell.service")
                return
            elif target == "hyprland":
                await _run("hyprctl", "reload", timeout=2)
            await self._on_update()


# ─── ProcessCache ─────────────────────────────────────────────────────────────
class ProcessCache:
    """TTL-bounded (128 entries, 2s) /proc/pid/cwd resolver."""

    def __init__(self) -> None:
        self._cache = _TTLCache(maxsize=128, ttl=2.0)

    async def get_cwd(self, pid: int) -> str:
        cached, hit = self._cache.get(pid)
        if hit:
            return cached
        cwd = await self._resolve(pid)
        self._cache.set(pid, cwd)
        return cwd

    async def _resolve(self, pid: int) -> str:
        home = str(Path.home())
        try:
            p = Path(f"/proc/{pid}")
            if not p.exists():
                return home
            try:
                comm = (p / "comm").read_text().strip()
            except OSError:
                comm = ""
            if comm in ("zsh", "bash", "fish", "nvim", "vim", "code"):
                return os.readlink(p / "cwd")
            # Read child PIDs from /proc instead of spawning pgrep subprocess
            try:
                children_text = (p / "task" / str(pid) / "children").read_text().strip()
                if children_text:
                    for child in children_text.split():
                        try:
                            return os.readlink(f"/proc/{child}/cwd")
                        except OSError:
                            pass
            except OSError:
                pass
            return os.readlink(p / "cwd")
        except (OSError, PermissionError):
            return home


# ─── ContextCollector ─────────────────────────────────────────────────────────
class ContextCollector:
    def __init__(self, git: GitCollector, svc: SystemMetrics) -> None:
        self._git = git
        self._svc = svc
        self._proc = ProcessCache()
        self._last_key: tuple[int | None, str, str] | None = None
        self._last_snapshot: ContextSnapshot | None = None
        self._last_snapshot_ts = 0.0

    async def collect(self) -> ContextSnapshot:
        pid, cls = await self._active_window()
        cwd = str(Path.home())
        if pid and pid > 0 and any(x in cls for x in WINDOW_CLASSES_WITH_CWD):
            cwd = await self._proc.get_cwd(pid)

        key = (pid, cls, cwd)
        now = time.monotonic()
        if (
            self._last_key == key
            and self._last_snapshot is not None
            and (now - self._last_snapshot_ts) < 0.5
        ):
            return self._last_snapshot

        ctx_type, proj_type, icon = self._git.detect_project(cwd)
        branch, dirty, notes = "", False, ""
        if ctx_type == "project":
            branch, dirty = await self._git.git_info(cwd)
            notes = self._git.read_notes(cwd)
        # diagnostics, border_color, timestamp stripped — QML never consumes them.
        snapshot = ContextSnapshot(
            context=ctx_type,
            path=cwd,
            project_type=proj_type,
            icon=icon,
            git_branch=branch,
            git_dirty=dirty,
            notes=notes,
        )
        self._last_key = key
        self._last_snapshot = snapshot
        self._last_snapshot_ts = now
        return snapshot

    async def _active_window(self) -> tuple[int | None, str]:
        # Fast path: query Hyprland UNIX control socket directly (<0.2ms, 0 subprocess forks)
        if HYPR_SIG:
            sock_path = str(Path(RUNTIME_DIR) / "hypr" / HYPR_SIG / ".socket.sock")
            try:
                reader, writer = await asyncio.open_unix_connection(sock_path)
                try:
                    writer.write(b"j/activewindow\n")
                    await writer.drain()
                    data = await asyncio.wait_for(reader.read(8192), timeout=0.5)
                    if data:
                        parsed = json.loads(data.decode("utf-8", errors="ignore"))
                        return parsed.get("pid"), parsed.get("class", "").lower()
                finally:
                    writer.close()
                    await writer.wait_closed()
            except Exception:
                pass

        # Fallback path (e.g. tests or when control socket is unavailable)
        rc, out = await _run("hyprctl", "activewindow", "-j", timeout=0.8)
        if rc == 0:
            try:
                data = json.loads(out)
                return data.get("pid"), data.get("class", "").lower()
            except json.JSONDecodeError:
                pass
        return None, ""


# ─── ContextEngine ────────────────────────────────────────────────────────────
class ContextEngine:
    """Top-level orchestrator. asyncio.Lock prevents thundering-herd stampede."""

    def __init__(self) -> None:
        self._git = GitCollector()
        self._svc = SystemMetrics()
        self._net = NetworkFixer()
        self._net_pub = NetworkPublisher()
        self._notif = NotificationManager()
        self._ipc = IpcPublisher()
        self._lock = asyncio.Lock()
        self._update_task: asyncio.Task | None = None
        self._debounce_task: asyncio.Task | None = None
        self._update_queued = False
        self._update_min_interval = 0.25
        self._last_update_ts = 0.0
        self._last_color_update_ts = 0.0
        self._collector = ContextCollector(self._git, self._svc)
        self._ipc_server = IpcServer(
            svc=self._svc,
            net=self._net,
            notif=self._notif,
            on_update=self.trigger_update,
        )
        self._color_watcher = InotifyWatcher(COLORS_FILE, self._on_colors_changed, _log)

    def _on_colors_changed(self) -> None:
        now = time.monotonic()
        if now - self._last_color_update_ts < 0.4:
            return
        self._last_color_update_ts = now
        self._git.reload_colors()

        # Trigger Quickshell ColorScheme reload with a small delay
        # to ensure matugen finished writing.
        async def delayed_reload():
            await asyncio.sleep(0.15)
            rc, _ = await _run(
                QUICKSHELL_BIN,
                "ipc",
                "--any-display",
                "call",
                "ipcHandler",
                "reloadColors",
                timeout=1.5,
            )
            if rc != 0:
                _log.debug("quickshell ipc reloadColors failed")
            await self.trigger_update()

        asyncio.ensure_future(delayed_reload())

    async def start(self) -> None:
        await asyncio.gather(
            self._svc.connect(),
            self._net.connect(),
            self._net_pub.connect(),
            self._notif.connect(),
            return_exceptions=True,
        )
        self._ipc.start()
        await self._ipc_server.start()
        self._git.reload_colors()
        self._color_watcher.start()
        await self.update()

    async def trigger_update(self) -> None:
        if self._update_task is not None and not self._update_task.done():
            self._update_queued = True
            return
        delay = self._update_min_interval - (time.monotonic() - self._last_update_ts)
        if delay > 0:
            self._update_queued = True
            if self._debounce_task is None or self._debounce_task.done():
                self._debounce_task = asyncio.create_task(
                    self._debounced_trigger(delay)
                )
            return
        self._update_task = asyncio.create_task(self._drain_updates())

    async def _debounced_trigger(self, delay: float) -> None:
        try:
            await asyncio.sleep(max(0.0, delay))
            if self._update_task is not None and not self._update_task.done():
                self._update_queued = True
                return
            self._update_task = asyncio.create_task(self._drain_updates())
        except asyncio.CancelledError:
            return

    async def _drain_updates(self) -> None:
        while True:
            self._update_queued = False
            self._last_update_ts = time.monotonic()
            await self.update()
            if not self._update_queued:
                return
            elapsed = time.monotonic() - self._last_update_ts
            if elapsed < self._update_min_interval:
                await asyncio.sleep(self._update_min_interval - elapsed)

    async def update(self) -> None:
        if self._lock.locked():
            return
        async with self._lock:
            try:
                snapshot = await self._collector.collect()
                snapshot.services = await self._svc.check()
                await self._notif.apply_policy(snapshot)
                self._ipc.publish_if_changed(snapshot)
            except Exception as exc:
                _log.error(f"ContextEngine.update: {exc}")

    def shutdown(self) -> None:
        if self._debounce_task is not None and not self._debounce_task.done():
            self._debounce_task.cancel()
        if self._update_task is not None and not self._update_task.done():
            self._update_task.cancel()
        self._net_pub.shutdown()
        self._color_watcher.close()
        try:
            Path(COMMAND_SOCKET).unlink(missing_ok=True)
        except OSError:
            pass
        _log.info("ContextEngine: shutdown complete")


# ─── Hyprland event loop ──────────────────────────────────────────────────────
async def _hyprland_event_loop(engine: ContextEngine) -> None:
    if not HYPR_SIG:
        return
    sock_path = str(Path(RUNTIME_DIR) / "hypr" / HYPR_SIG / ".socket2.sock")
    while True:
        try:
            reader, writer = await asyncio.open_unix_connection(sock_path)
            _log.info("Connected to Hyprland socket2")
            buffer = ""
            try:
                while True:
                    data = await reader.read(4096)
                    if not data:
                        _log.warning("Hyprland socket2 closed; reconnecting...")
                        break
                    buffer += data.decode("utf-8", errors="ignore")
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        if line.startswith("activewindow>>") or line.startswith(
                            "activewindowv2>>"
                        ):
                            await engine.trigger_update()
            finally:
                try:
                    writer.close()
                    await writer.wait_closed()
                except Exception:
                    pass
        except KeyboardInterrupt:
            raise
        except Exception as exc:
            _log.warning(f"Hyprland socket error: {exc}; reconnecting in 5s")
            await asyncio.sleep(5)


# ─── Entry point + graceful shutdown ─────────────────────────────────────────
async def _main() -> None:
    if not HYPR_SIG:
        _log.error("HYPRLAND_INSTANCE_SIGNATURE not set; exiting.")
        return
    sock_path = Path(RUNTIME_DIR) / "hypr" / HYPR_SIG / ".socket2.sock"
    if not sock_path.exists():
        _log.error(f"Hyprland socket2 not found: {sock_path}")
        return

    engine = ContextEngine()

    shutdown_event = asyncio.Event()

    def _handle_signal(sig: signal.Signals) -> None:
        _log.info(f"Signal {sig.name} received; graceful shutdown initiated")
        shutdown_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, functools.partial(_handle_signal, sig))

    await engine.start()
    hypr_task = asyncio.ensure_future(_hyprland_event_loop(engine))

    try:
        await shutdown_event.wait()
    finally:
        _log.info("Cancelling background tasks...")
        hypr_task.cancel()
        try:
            await hypr_task
        except asyncio.CancelledError:
            pass
        engine.shutdown()
        _log.info("Goodbye.")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        print("ok")
        raise SystemExit(0)
    try:
        asyncio.run(_main())
    except KeyboardInterrupt:
        pass
