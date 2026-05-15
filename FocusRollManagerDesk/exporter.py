import csv
import json
from pathlib import Path

class Exporter:
    @staticmethod
    def safe(value):
        return str(value or "").replace("|", "/").replace(";", ",")

    @classmethod
    def addon_string(cls, players):
        parts = ["FRM1"]
        for p in players:
            parts.append(";".join([
                cls.safe(p["name"]),
                cls.safe(p.get("class", "UNKNOWN")),
                cls.safe(p.get("focus1", "")),
                cls.safe(p.get("focus2", "")),
                cls.safe(p.get("status", "active")),
                cls.safe(p.get("strikes", 0)),
            ]))
        return "|".join(parts)

    @staticmethod
    def json_text(players):
        return json.dumps({"players": players}, indent=2, ensure_ascii=False)

    @staticmethod
    def lua_text(players):
        lines = ["FocusRollManagerImport = {", "  players = {"]
        for p in players:
            name = p["name"].replace('"', '\"')
            lines.append(f'    ["{name}"] = {{')
            lines.append(f'      class = "{p.get("class", "UNKNOWN")}",')
            lines.append(f'      focus1 = "{p.get("focus1", "")}",')
            lines.append(f'      focus2 = "{p.get("focus2", "")}",')
            lines.append(f'      status = "{p.get("status", "active")}",')
            lines.append(f'      strikes = {int(p.get("strikes", 0))},')
            lines.append("    },")
        lines.extend(["  }", "}"])
        return "\n".join(lines)

    @staticmethod
    def save_csv(players, path):
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=["name", "class", "focus1", "focus2", "status", "strikes"])
            writer.writeheader()
            writer.writerows(players)
