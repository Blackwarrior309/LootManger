import json
from pathlib import Path
from unidecode import unidecode
from rapidfuzz import process

class IdentityManager:
    def __init__(self, alias_file="aliases.json"):
        self.alias_file = Path(alias_file)
        self.aliases = {}
        self.load()

    def load(self):
        if self.alias_file.exists():
            data = json.loads(self.alias_file.read_text(encoding="utf-8"))
            self.aliases = data.get("aliases", {})

    def save(self):
        self.alias_file.write_text(
            json.dumps({"aliases": self.aliases}, indent=2, ensure_ascii=False),
            encoding="utf-8"
        )

    def normalize(self, value: str) -> str:
        return unidecode(value or "").lower().strip()

    def add_alias(self, alias: str, wow_name: str):
        self.aliases[self.normalize(alias)] = wow_name
        self.save()

    def resolve(self, ts_name: str, roster: list[dict]):
        normalized = self.normalize(ts_name)

        if normalized in self.aliases:
            return self.aliases[normalized], 100

        roster_map = {self.normalize(r["name"]): r["name"] for r in roster}

        if normalized in roster_map:
            return roster_map[normalized], 95

        if roster_map:
            match = process.extractOne(normalized, list(roster_map.keys()))
            if match and match[1] >= 80:
                return roster_map[match[0]], int(match[1])

        return None, 0
