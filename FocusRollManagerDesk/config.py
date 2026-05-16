"""Persistent app configuration: WoW chat-log path + SavedVariables path.

Stored next to the app in ``desktop_config.json``. First run probes a few
common locations relative to the addon folder before falling back to a
user-selected path dialog.
"""

from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Optional


APP_DIR = Path(__file__).resolve().parent
CONFIG_FILE = APP_DIR / "desktop_config.json"


@dataclass
class AppConfig:
    chatlog_path: str = ""
    savedvars_path: str = ""
    auto_start_sync: bool = False

    @classmethod
    def load(cls) -> "AppConfig":
        if not CONFIG_FILE.exists():
            return cls()
        try:
            data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return cls()
        cfg = cls()
        for k, v in data.items():
            if hasattr(cfg, k):
                setattr(cfg, k, v)
        return cfg

    def save(self) -> None:
        CONFIG_FILE.write_text(
            json.dumps(asdict(self), indent=2, ensure_ascii=False),
            encoding="utf-8",
        )


def autodetect_wow_root() -> Optional[Path]:
    """Walk up from the app directory looking for ``WTF`` and ``Logs`` folders.

    The desktop app ships inside the addon directory, so the WoW root is
    typically three levels up: ``Interface/AddOns/<addon>``.
    """
    cur = APP_DIR
    for _ in range(8):
        if (cur / "WTF").is_dir() and (cur / "Logs").is_dir():
            return cur
        if cur.parent == cur:
            break
        cur = cur.parent
    return None


def autodetect_paths() -> tuple[str, str]:
    """Return (chatlog_path, savedvars_path) best guesses (may be '')."""
    root = autodetect_wow_root()
    if not root:
        return "", ""

    chatlog = root / "Logs" / "WoWChatLog.txt"
    chatlog_str = str(chatlog) if chatlog.is_file() else str(chatlog)

    # SavedVariables: WTF/Account/<ACC>/SavedVariables/FocusRollManagerDB.lua
    savedvars_str = ""
    accounts = root / "WTF" / "Account"
    if accounts.is_dir():
        for acc_dir in accounts.iterdir():
            candidate = acc_dir / "SavedVariables" / "FocusRollManagerDB.lua"
            if candidate.is_file():
                savedvars_str = str(candidate)
                break
        if not savedvars_str:
            # Pre-create path for the first account so the watcher sees the
            # file as soon as WoW writes it after first /reload.
            first_acc = next(iter(accounts.iterdir()), None)
            if first_acc is not None:
                savedvars_str = str(
                    first_acc / "SavedVariables" / "FocusRollManagerDB.lua"
                )

    return chatlog_str, savedvars_str


def fill_defaults(cfg: AppConfig) -> AppConfig:
    """Fill empty fields with auto-detected paths."""
    if cfg.chatlog_path and cfg.savedvars_path:
        return cfg
    chat, sv = autodetect_paths()
    if not cfg.chatlog_path and chat:
        cfg.chatlog_path = chat
    if not cfg.savedvars_path and sv:
        cfg.savedvars_path = sv
    return cfg
