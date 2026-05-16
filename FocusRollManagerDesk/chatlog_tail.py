"""Tail the WoW chat log for ``[FRM] ...`` lines emitted by the in-game addon.

The in-game side uses ``DEFAULT_CHAT_FRAME:AddMessage`` after the user enables
``LoggingChat(true)``. Each emit produces a single line in
``Logs/WoWChatLog.txt`` of the form::

    5/16 14:32:01.123  [FRM] AWARD|Bob|Bryntroll|3

The leading WoW timestamp varies by client locale — we only require the
``[FRM]`` marker followed by ``EVENT|payload``. Lines without the marker are
ignored, so other addons' chat noise is safe.
"""

from __future__ import annotations

import os
import re
from typing import Callable, Optional

from PyQt6.QtCore import QFileSystemWatcher, QObject, QTimer, pyqtSignal


_FRM_LINE_RE = re.compile(r"\[FRM\]\s+(\w+)(?:\|(.*))?$")


def unescape_field(s: str) -> str:
    """Reverse of the Lua/Python ``Exporter.safe`` escape.

    ``\\p`` -> ``|``, ``\\s`` -> ``;``, ``\\\\`` -> ``\\``.
    """
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            nx = s[i + 1]
            if nx == "p":
                out.append("|"); i += 2; continue
            if nx == "s":
                out.append(";"); i += 2; continue
            if nx == "\\":
                out.append("\\"); i += 2; continue
        out.append(c)
        i += 1
    return "".join(out)


def parse_line(line: str) -> Optional[dict]:
    """Return a normalised event dict or None if the line is not for us."""
    m = _FRM_LINE_RE.search(line)
    if not m:
        return None
    event = m.group(1)
    payload = m.group(2) or ""
    fields = [unescape_field(f) for f in payload.split("|")] if payload else []

    if event == "AWARD" and len(fields) >= 3:
        try:
            strikes = int(fields[2])
        except ValueError:
            strikes = 0
        return {"type": "AWARD", "player": fields[0], "item": fields[1], "strikes": strikes}

    if event == "PLAYER" and len(fields) >= 6:
        try:
            strikes = int(fields[5])
        except ValueError:
            strikes = 0
        return {
            "type": "PLAYER",
            "player": fields[0],
            "class": fields[1] or "UNKNOWN",
            "focus1": fields[2],
            "focus2": fields[3],
            "status": fields[4] or "active",
            "strikes": strikes,
        }

    if event == "CLEAR":
        return {"type": "CLEAR"}

    if event == "HELLO" and len(fields) >= 1:
        return {
            "type": "HELLO",
            "version": fields[0],
            "timestamp": fields[1] if len(fields) > 1 else "",
        }

    return {"type": event, "fields": fields}


class ChatLogTail(QObject):
    """Watches a chat log file and emits ``event`` signals for FRM lines."""

    event = pyqtSignal(dict)
    status_changed = pyqtSignal(str)   # "connected" / "missing" / "error: ..."

    def __init__(self, log_path: str, parent: QObject | None = None):
        super().__init__(parent)
        self.log_path = log_path
        self._fd: Optional[object] = None
        self._pos = 0
        self._buffer = ""
        self._watcher = QFileSystemWatcher(self)
        self._watcher.fileChanged.connect(self._on_file_changed)
        self._debounce = QTimer(self)
        self._debounce.setSingleShot(True)
        self._debounce.setInterval(80)
        self._debounce.timeout.connect(self._drain)

    # ---------- lifecycle ----------

    def start(self) -> bool:
        """Open the log and seek to the current end. Returns True on success."""
        if not os.path.isfile(self.log_path):
            self.status_changed.emit("missing")
            return False
        try:
            self._open_and_seek_end()
        except OSError as exc:
            self.status_changed.emit(f"error: {exc}")
            return False
        self._watcher.addPath(self.log_path)
        self.status_changed.emit("connected")
        return True

    def stop(self) -> None:
        if self.log_path in self._watcher.files():
            self._watcher.removePath(self.log_path)
        if self._fd is not None:
            try:
                self._fd.close()
            except OSError:
                pass
            self._fd = None

    # ---------- internals ----------

    def _open_and_seek_end(self) -> None:
        if self._fd is not None:
            try:
                self._fd.close()
            except OSError:
                pass
        # Open in binary so we can pick the encoding ourselves and handle
        # WoW's mixed UTF-8 / Win-1252 history gracefully.
        self._fd = open(self.log_path, "rb")
        self._fd.seek(0, os.SEEK_END)
        self._pos = self._fd.tell()
        self._buffer = ""

    def _on_file_changed(self, _path: str) -> None:
        # Some editors / Windows replace the file rather than append. If the
        # watch was lost (rename), QFileSystemWatcher drops the path silently
        # — re-arm it.
        if self.log_path not in self._watcher.files() and os.path.isfile(self.log_path):
            self._watcher.addPath(self.log_path)
        self._debounce.start()

    def _drain(self) -> None:
        if self._fd is None:
            return
        try:
            size = os.path.getsize(self.log_path)
        except OSError as exc:
            self.status_changed.emit(f"error: {exc}")
            return

        # File was truncated/rotated — re-open and read from start.
        if size < self._pos:
            try:
                self._fd.close()
            except OSError:
                pass
            self._fd = open(self.log_path, "rb")
            self._pos = 0
            self._buffer = ""

        try:
            self._fd.seek(self._pos)
            chunk = self._fd.read()
            self._pos = self._fd.tell()
        except OSError as exc:
            self.status_changed.emit(f"error: {exc}")
            return

        if not chunk:
            return

        text = self._decode(chunk)
        self._buffer += text
        # Process whole lines only; keep the trailing partial line buffered.
        while "\n" in self._buffer:
            line, self._buffer = self._buffer.split("\n", 1)
            line = line.rstrip("\r")
            if not line:
                continue
            ev = parse_line(line)
            if ev is not None:
                self.event.emit(ev)

    @staticmethod
    def _decode(chunk: bytes) -> str:
        try:
            return chunk.decode("utf-8")
        except UnicodeDecodeError:
            return chunk.decode("cp1252", errors="replace")


def feed_lines(lines, callback: Callable[[dict], None]) -> int:
    """Test helper: synchronously parse a sequence of lines.

    Returns the number of FRM events delivered to ``callback``.
    """
    n = 0
    for line in lines:
        ev = parse_line(line)
        if ev is not None:
            callback(ev)
            n += 1
    return n
