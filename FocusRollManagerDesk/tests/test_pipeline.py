from pathlib import Path

from desktop_pipeline import parse_focus_players, import_roster_if_present, export_addon_string
from identity_manager import IdentityManager
from parser import FocusParser
from roster_importer import import_roster_text


FIXTURE_DIR = Path(__file__).resolve().parent.parent


def test_full_pipeline_roundtrip(tmp_path):
    roster_text = (FIXTURE_DIR / "fake_roster_import.txt").read_text(encoding="utf-8")
    ts_text = (FIXTURE_DIR / "fake_ts_raid_import.txt").read_text(encoding="utf-8")

    roster = import_roster_text(roster_text)
    assert len(roster) == 10

    # Use isolated alias file so user state doesn't leak in.
    identity = IdentityManager(alias_file=str(tmp_path / "aliases.json"))
    players, unmatched = parse_focus_players(ts_text, roster, FocusParser(), identity)

    assert unmatched == []
    assert len(players) == 10

    by_name = {p["name"]: p for p in players}
    assert by_name["Tankyx"]["status"] == "off"
    assert by_name["Blackpanther"]["focus1"] == "Deathbringer's Will Heroic"


def test_import_roster_if_present_detects_marker():
    text = "FRMROSTER1|Bob;MAGE"
    assert import_roster_if_present(text) == [{"name": "Bob", "class": "MAGE"}]
    assert import_roster_if_present("foo bar") is None


def test_export_addon_string_starts_with_header(tmp_path):
    roster = [{"name": "Bob", "class": "MAGE"}]
    identity = IdentityManager(alias_file=str(tmp_path / "aliases.json"))
    players, _ = parse_focus_players(
        "<20:00:00> Bob: focus dbw", roster, FocusParser(), identity
    )
    s = export_addon_string(players)
    assert s.startswith("FRM1|")
    assert "Bob" in s
