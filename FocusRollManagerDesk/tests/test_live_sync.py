"""Coordinator tests — drive events through the API directly without files."""

import sys

import pytest
from PyQt6.QtWidgets import QApplication

from live_sync import LiveSyncCoordinator


@pytest.fixture(scope="module")
def qapp():
    app = QApplication.instance() or QApplication(sys.argv)
    yield app


def _collect(signal):
    captured = []
    signal.connect(lambda *args: captured.append(args if len(args) > 1 else args[0]))
    return captured


def test_seed_players_emits(qapp):
    c = LiveSyncCoordinator()
    emitted = _collect(c.players_changed)
    c.set_players([{"name": "Bob", "strikes": 0}, {"name": "Alice", "strikes": 1}])
    assert len(emitted) == 1
    names = {p["name"] for p in emitted[0]}
    assert names == {"Bob", "Alice"}


def test_award_patches_existing_player(qapp):
    c = LiveSyncCoordinator()
    c.set_players([{"name": "Bob", "class": "MAGE",
                    "focus1": "DBW", "focus2": "", "status": "active", "strikes": 0}])

    emitted_players = _collect(c.players_changed)
    emitted_awards = _collect(c.award_received)

    c._on_chat_event({
        "type": "AWARD", "player": "Bob", "item": "Bryntroll", "strikes": 1
    })

    assert emitted_awards == [("Bob", "Bryntroll", 1)]
    assert emitted_players, "players_changed must fire on award"
    bob = next(p for p in emitted_players[-1] if p["name"] == "Bob")
    assert bob["strikes"] == 1
    assert bob["class"] == "MAGE"  # preserved


def test_award_for_unknown_player_creates_row(qapp):
    c = LiveSyncCoordinator()
    c._on_chat_event({
        "type": "AWARD", "player": "Ghost", "item": "X", "strikes": 1
    })
    names = {p["name"] for p in c.players()}
    assert "Ghost" in names


def test_player_event_replaces_row(qapp):
    c = LiveSyncCoordinator()
    c.set_players([{"name": "Bob", "class": "WARRIOR",
                    "focus1": "", "focus2": "", "status": "active", "strikes": 5}])
    c._on_chat_event({
        "type": "PLAYER", "player": "Bob", "class": "MAGE",
        "focus1": "DBW", "focus2": "STS", "status": "active", "strikes": 2,
    })
    bob = next(p for p in c.players() if p["name"] == "Bob")
    assert bob["class"] == "MAGE"
    assert bob["strikes"] == 2
    assert bob["focus1"] == "DBW"


def test_clear_event_wipes_players(qapp):
    c = LiveSyncCoordinator()
    c.set_players([{"name": "Bob", "strikes": 0}, {"name": "Alice", "strikes": 0}])
    c._on_chat_event({"type": "CLEAR"})
    assert c.players() == []


def test_savedvars_reload(tmp_path, qapp):
    sv = tmp_path / "FocusRollManagerDB.lua"
    sv.write_text(
        'FocusRollManagerDB = { ["players"] = { ["Bob"] = { '
        '["class"] = "MAGE", ["focus1"] = "DBW", ["focus2"] = "", '
        '["status"] = "active", ["strikes"] = 3, }, }, }',
        encoding="utf-8",
    )
    c = LiveSyncCoordinator(chatlog_path="", savedvars_path=str(sv))
    emitted = _collect(c.players_changed)
    c._reload_savedvars()
    assert emitted, "savedvars reload must emit players_changed"
    bob = next(p for p in emitted[-1] if p["name"] == "Bob")
    assert bob["strikes"] == 3
    assert bob["class"] == "MAGE"


def test_savedvars_parse_error_keeps_running(tmp_path, qapp):
    sv = tmp_path / "broken.lua"
    sv.write_text("FocusRollManagerDB = { broken", encoding="utf-8")
    c = LiveSyncCoordinator(chatlog_path="", savedvars_path=str(sv))
    statuses = _collect(c.status_changed)
    c._reload_savedvars()
    assert any("Parse-Fehler" in s for s in statuses)
