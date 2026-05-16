"""Live sync coordinator.

Merges two input streams into a single ``players_changed`` view used by the
Strichliste window:

  * ``ChatLogTail`` — primary, ~200ms lag, drives ``AWARD`` / ``PLAYER`` /
    ``CLEAR`` events as the lootmaster clicks Award in-game.
  * ``SavedVariables`` mtime watcher — backup full sync that runs after the
    lootmaster hits the in-game *Reload* button between bosses.

The coordinator keeps an internal name->player dict so it can patch a single
player on ``AWARD`` and re-emit the whole sorted list to the UI.
"""

from __future__ import annotations

import os
import time
from typing import Dict, List, Optional

from PyQt6.QtCore import QFileSystemWatcher, QObject, QTimer, pyqtSignal

import lua_savedvars
from chatlog_tail import ChatLogTail


class LiveSyncCoordinator(QObject):
    players_changed = pyqtSignal(list)            # list[dict]
    award_received = pyqtSignal(str, str, int)    # name, item, strikes
    status_changed = pyqtSignal(str)              # human-readable status

    def __init__(self,
                 chatlog_path: str = "",
                 savedvars_path: str = "",
                 parent: QObject | None = None):
        super().__init__(parent)
        self.chatlog_path = chatlog_path
        self.savedvars_path = savedvars_path

        self._players: Dict[str, dict] = {}
        self._tail: Optional[ChatLogTail] = None

        self._sv_watcher = QFileSystemWatcher(self)
        self._sv_watcher.fileChanged.connect(self._on_savedvars_changed)
        self._sv_debounce = QTimer(self)
        self._sv_debounce.setSingleShot(True)
        self._sv_debounce.setInterval(300)
        self._sv_debounce.timeout.connect(self._reload_savedvars)

        self.last_chat_event_ts: float = 0.0
        self.last_full_sync_ts: float = 0.0

    # ---------- lifecycle ----------

    def start(self) -> bool:
        ok_chat = False
        ok_sv = False

        if self.chatlog_path:
            self._tail = ChatLogTail(self.chatlog_path, parent=self)
            self._tail.event.connect(self._on_chat_event)
            self._tail.status_changed.connect(self._on_chat_status)
            ok_chat = self._tail.start()

        if self.savedvars_path and os.path.isfile(self.savedvars_path):
            self._sv_watcher.addPath(self.savedvars_path)
            self._reload_savedvars()
            ok_sv = True

        if ok_chat or ok_sv:
            self.status_changed.emit(self._status_text())
            return True

        self.status_changed.emit("Keine Quelle erreichbar")
        return False

    def stop(self) -> None:
        if self._tail is not None:
            self._tail.stop()
            self._tail = None
        if self.savedvars_path in self._sv_watcher.files():
            self._sv_watcher.removePath(self.savedvars_path)

    # ---------- public API ----------

    def set_players(self, players: List[dict]) -> None:
        """Seed from the desktop pipeline before any live event arrives."""
        self._players = {self._key(p): dict(p) for p in players}
        self._emit_players()

    def players(self) -> List[dict]:
        return list(self._players.values())

    # ---------- chat events ----------

    def _on_chat_event(self, ev: dict) -> None:
        self.last_chat_event_ts = time.time()
        kind = ev.get("type")
        if kind == "AWARD":
            name = ev["player"]
            strikes = ev["strikes"]
            row = self._players.get(name)
            if row is None:
                # Unknown player — synthesise minimal row so the UI shows them.
                row = {"name": name, "class": "UNKNOWN",
                       "focus1": "", "focus2": "",
                       "status": "active", "strikes": 0}
                self._players[name] = row
            row["strikes"] = strikes
            self.award_received.emit(name, ev["item"], strikes)
            self._emit_players()

        elif kind == "PLAYER":
            name = ev["player"]
            self._players[name] = {
                "name": name,
                "class": ev.get("class", "UNKNOWN") or "UNKNOWN",
                "focus1": ev.get("focus1", ""),
                "focus2": ev.get("focus2", ""),
                "status": ev.get("status", "active") or "active",
                "strikes": ev.get("strikes", 0),
            }
            self._emit_players()

        elif kind == "CLEAR":
            self._players.clear()
            self._emit_players()

        elif kind == "HELLO":
            # Just a heartbeat — refresh status line.
            self.status_changed.emit(self._status_text())

    def _on_chat_status(self, status: str) -> None:
        self.status_changed.emit(f"Chatlog: {status}  ({self._status_text()})")

    # ---------- savedvars ----------

    def _on_savedvars_changed(self, _path: str) -> None:
        # Some editors atomic-replace the file; re-arm the watch if dropped.
        if (self.savedvars_path not in self._sv_watcher.files()
                and os.path.isfile(self.savedvars_path)):
            self._sv_watcher.addPath(self.savedvars_path)
        self._sv_debounce.start()

    def _reload_savedvars(self) -> None:
        try:
            data = lua_savedvars.load_file(self.savedvars_path)
        except (OSError, lua_savedvars.LuaParseError) as exc:
            self.status_changed.emit(f"Vollsync-Parse-Fehler: {exc}")
            return

        db = data.get("FocusRollManagerDB") or {}
        raw_players = db.get("players") or {}
        merged: Dict[str, dict] = {}
        for name, p in raw_players.items():
            if not isinstance(p, dict):
                continue
            merged[name] = {
                "name": name,
                "class": p.get("class", "UNKNOWN") or "UNKNOWN",
                "focus1": p.get("focus1", "") or "",
                "focus2": p.get("focus2", "") or "",
                "status": p.get("status", "active") or "active",
                "strikes": int(p.get("strikes", 0) or 0),
            }

        # Full sync wins over chat-state — file flush implies authoritative DB.
        self._players = merged
        self.last_full_sync_ts = time.time()
        self._emit_players()
        self.status_changed.emit(self._status_text())

    # ---------- helpers ----------

    @staticmethod
    def _key(player: dict) -> str:
        return player.get("name") or ""

    def _emit_players(self) -> None:
        self.players_changed.emit(list(self._players.values()))

    def _status_text(self) -> str:
        def fmt(ts: float) -> str:
            if not ts:
                return "—"
            delta = max(0, int(time.time() - ts))
            return f"{delta}s"
        return (f"Chat: {fmt(self.last_chat_event_ts)} | "
                f"Vollsync: {fmt(self.last_full_sync_ts)}")
