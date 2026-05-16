import csv
import json
from datetime import date


class Exporter:
    """Export helpers for the addon-import string, JSON, Lua and CSV."""

    # Characters with special meaning in the FRM1 addon string.
    _PIPE_ESCAPE = "\\p"
    _SEMI_ESCAPE = "\\s"
    _BSLASH_ESCAPE = "\\\\"

    @classmethod
    def safe(cls, value):
        """Escape a single field for the FRM1 pipe/semicolon-delimited format.

        Round-trip safe: a matching unescape on the Lua side restores the
        original characters. Replacements no longer destroy item links.
        """
        if value is None:
            return ""
        text = str(value)
        text = text.replace("\\", cls._BSLASH_ESCAPE)
        text = text.replace("|", cls._PIPE_ESCAPE)
        text = text.replace(";", cls._SEMI_ESCAPE)
        return text

    @staticmethod
    def _lua_escape(value):
        """Escape a string for inclusion inside a Lua double-quoted literal."""
        if value is None:
            return ""
        text = str(value)
        text = text.replace("\\", "\\\\")
        text = text.replace('"', '\\"')
        text = text.replace("\n", "\\n")
        text = text.replace("\r", "\\r")
        text = text.replace("\t", "\\t")
        return text

    @classmethod
    def addon_string(cls, players):
        parts = ["FRM1"]
        for p in players:
            name = (p.get("name") or "").strip()
            if not name:
                continue
            parts.append(";".join([
                cls.safe(name),
                cls.safe(p.get("class", "UNKNOWN") or "UNKNOWN"),
                cls.safe(p.get("focus1", "")),
                cls.safe(p.get("focus2", "")),
                cls.safe(p.get("status", "active") or "active"),
                cls.safe(p.get("strikes", 0)),
            ]))
        return "|".join(parts)

    @staticmethod
    def json_text(players):
        return json.dumps({"players": players}, indent=2, ensure_ascii=False)

    @classmethod
    def lua_text(cls, players):
        lines = ["FocusRollManagerImport = {", "  players = {"]
        for p in players:
            name = (p.get("name") or "").strip()
            if not name:
                continue
            try:
                strikes = int(p.get("strikes", 0) or 0)
            except (TypeError, ValueError):
                strikes = 0
            lines.append(f'    ["{cls._lua_escape(name)}"] = {{')
            lines.append(f'      class = "{cls._lua_escape(p.get("class", "UNKNOWN") or "UNKNOWN")}",')
            lines.append(f'      focus1 = "{cls._lua_escape(p.get("focus1", ""))}",')
            lines.append(f'      focus2 = "{cls._lua_escape(p.get("focus2", ""))}",')
            lines.append(f'      status = "{cls._lua_escape(p.get("status", "active") or "active")}",')
            lines.append(f'      strikes = {strikes},')
            lines.append("    },")
        lines.extend(["  },", "}"])
        return "\n".join(lines)

    _CLASS_ORDER = [
        "DEATH_KNIGHT", "DRUID", "HUNTER", "MAGE", "PALADIN",
        "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR", "UNKNOWN",
    ]

    @classmethod
    def readback_text(cls, players) -> str:
        """Human-readable TS readback list, sorted three ways (class / focus / player)."""
        today = date.today().strftime("%d.%m.%Y")
        sections = []

        def fmt_player(p):
            name = (p.get("name") or p.get("ts_name", "?")).strip()
            f1 = (p.get("focus1") or "").strip()
            f2 = (p.get("focus2") or "").strip()
            status = (p.get("status") or "active").strip()
            if status == "off":
                focuses = "(off)"
            elif f1 and f2:
                focuses = f"{f1} / {f2}"
            elif f1:
                focuses = f1
            else:
                focuses = "(kein Focus)"
            return name, focuses

        # --- Sort by class ---
        by_class: dict[str, list] = {}
        for p in players:
            cls_key = (p.get("class") or "UNKNOWN").upper()
            by_class.setdefault(cls_key, []).append(p)

        lines = [f"=== Focus Rolls – {today} ===", "(nach Klasse)", ""]
        order = cls._CLASS_ORDER + [k for k in sorted(by_class) if k not in cls._CLASS_ORDER]
        for cls_key in order:
            if cls_key not in by_class:
                continue
            lines.append(cls_key)
            for p in sorted(by_class[cls_key], key=lambda x: (x.get("name") or "").lower()):
                name, focuses = fmt_player(p)
                lines.append(f"  {name}: {focuses}")
            lines.append("")
        sections.append("\n".join(lines))

        # --- Sort by focus1 ---
        lines = ["(nach Focus-Item)", ""]
        no_focus = [p for p in players if not (p.get("focus1") or "").strip()]
        with_focus = [p for p in players if (p.get("focus1") or "").strip()]
        for p in sorted(with_focus, key=lambda x: (x.get("focus1") or "").lower()):
            name, focuses = fmt_player(p)
            lines.append(f"  {(p.get('name') or p.get('ts_name','?')).strip()}: {focuses}")
        for p in sorted(no_focus, key=lambda x: (x.get("name") or "").lower()):
            name, focuses = fmt_player(p)
            lines.append(f"  {name}: {focuses}")
        sections.append("\n".join(lines))

        # --- Sort by player name ---
        lines = ["(nach Spieler A-Z)", ""]
        for p in sorted(players, key=lambda x: (x.get("name") or x.get("ts_name") or "").lower()):
            name, focuses = fmt_player(p)
            cls_tag = (p.get("class") or "?").upper()
            lines.append(f"  [{cls_tag}] {name}: {focuses}")
        sections.append("\n".join(lines))

        return "\n\n".join(sections)

    @staticmethod
    def save_csv(players, path):
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(
                f,
                fieldnames=["name", "class", "focus1", "focus2", "status", "strikes"],
                extrasaction="ignore",
            )
            writer.writeheader()
            for p in players:
                if not (p.get("name") or "").strip():
                    continue
                writer.writerow({
                    "name": p.get("name", ""),
                    "class": p.get("class", "UNKNOWN") or "UNKNOWN",
                    "focus1": p.get("focus1", ""),
                    "focus2": p.get("focus2", ""),
                    "status": p.get("status", "active") or "active",
                    "strikes": p.get("strikes", 0) or 0,
                })
