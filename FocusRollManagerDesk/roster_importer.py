import csv
import json
from pathlib import Path

def import_roster_text(text: str) -> list[dict]:
    text = text.strip()
    if not text:
        return []

    if text.startswith("FRMROSTER1|"):
        return import_frm_roster(text)

    try:
        data = json.loads(text)
        if isinstance(data, list):
            return [
                {"name": x.get("name", ""), "class": x.get("class", "UNKNOWN")}
                for x in data
                if x.get("name")
            ]
    except Exception:
        pass

    rows = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if ";" in line:
            name, cls = (line.split(";", 1) + ["UNKNOWN"])[:2]
        elif "," in line:
            name, cls = (line.split(",", 1) + ["UNKNOWN"])[:2]
        else:
            name, cls = line, "UNKNOWN"
        rows.append({"name": name.strip(), "class": cls.strip() or "UNKNOWN"})
    return rows

def import_frm_roster(text: str) -> list[dict]:
    parts = text.strip().split("|")
    result = []
    for part in parts[1:]:
        fields = part.split(";")
        if fields and fields[0].strip():
            result.append({
                "name": fields[0].strip(),
                "class": fields[1].strip() if len(fields) > 1 else "UNKNOWN"
            })
    return result

def load_roster_file(path: str) -> list[dict]:
    p = Path(path)
    content = p.read_text(encoding="utf-8")
    return import_roster_text(content)
