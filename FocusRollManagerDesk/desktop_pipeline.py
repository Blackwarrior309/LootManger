from exporter import Exporter
from identity_manager import IdentityManager
from parser import FocusParser
from roster_importer import import_roster_text


def roster_class_for_name(roster: list[dict], name: str, identity: IdentityManager) -> str:
    normalized = identity.normalize(name)
    for row in roster:
        if identity.normalize(row.get("name", "")) == normalized:
            return row.get("class", "UNKNOWN") or "UNKNOWN"
    return "UNKNOWN"


def parse_focus_players(text: str, roster: list[dict], parser: FocusParser, identity: IdentityManager) -> tuple[list[dict], list[str]]:
    parsed_by_wow = {}
    unmatched = []

    for row in parser.parse_text(text):
        wow_name, confidence = identity.resolve(row["ts_name"], roster)
        if not wow_name:
            wow_name = row["ts_name"]
            unmatched.append(row["ts_name"])

        parsed_by_wow[wow_name] = {
            "ts_name": row["ts_name"],
            "name": wow_name,
            "class": roster_class_for_name(roster, wow_name, identity),
            "focus1": row["focus1"],
            "focus2": row["focus2"],
            "status": row["status"],
            "strikes": 0,
            "confidence": confidence,
        }

    return list(parsed_by_wow.values()), unmatched


def import_roster_if_present(text: str) -> list[dict] | None:
    stripped = (text or "").strip()
    if stripped.startswith("FRMROSTER1|"):
        return import_roster_text(stripped)
    return None


def export_addon_string(players: list[dict]) -> str:
    return Exporter.addon_string(players)
