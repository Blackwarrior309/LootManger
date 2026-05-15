import json
import re
from pathlib import Path

from unidecode import unidecode


class FocusParser:
    def __init__(self, synonym_file="synonyms.json"):
        self.synonym_file = Path(synonym_file)
        self.synonyms = {}
        if self.synonym_file.exists():
            self.synonyms = json.loads(self.synonym_file.read_text(encoding="utf-8"))

    def normalize_key(self, text: str) -> str:
        return unidecode(text or "").lower().strip()

    def normalize_item(self, text: str) -> str:
        raw = (text or "").strip()
        key = self.normalize_key(raw)
        return self.synonyms.get(key, raw)

    def extract_message(self, line: str):
        text = line.strip()
        is_ts_log = False

        timestamp = re.match(r"^<\d{1,2}:\d{2}:\d{2}>\s*(.*)$", text)
        if timestamp:
            text = timestamp.group(1).strip()
            is_ts_log = True

        if not text or text.startswith("***"):
            return None, None, is_ts_log

        if self.normalize_key(text).startswith("ende des chat protokolls"):
            return None, None, is_ts_log

        quoted = re.match(r'^"([^"]+)":\s*(.*)$', text)
        if quoted:
            return quoted.group(1).strip(), quoted.group(2).strip(), is_ts_log

        match = re.match(r"^([^\s:>;,/]+)", text)
        if not match:
            return None, None, is_ts_log

        return match.group(1).strip(), text[match.end():].strip(), is_ts_log

    def has_focus_marker(self, text: str) -> bool:
        normalized = self.normalize_key(text)
        return bool(re.search(r"\b(fr\s*2?|focus|fokus|sr|softres|rolls?)\b", normalized))

    def parse_line(self, line: str):
        ts_name, remainder, is_ts_log = self.extract_message(line)
        if not ts_name:
            return None

        lower = self.normalize_key(remainder)
        status = "active"
        if re.search(r"\b(off|abgemeldet|bench|ersatz)\b", lower) or "meldet sich ab" in lower or "nicht dabei" in lower:
            status = "off"

        if is_ts_log and status == "active" and not self.has_focus_marker(remainder):
            return None

        remainder = re.sub(r"(?i)\bfr\s*2\b", " > ", remainder)
        remainder = re.sub(r"(?i)\b(update|focus|fokus|fr|roll|rolls|sr|softres)\b", " ", remainder)
        remainder = remainder.replace(":", " ").replace("-", " ")

        parts = re.split(r"\s*(?:>|/|,|;)\s*", remainder)
        parts = [part.strip() for part in parts if part.strip()]

        focuses = []
        for part in parts:
            cleaned = re.sub(r"^[\s:\-]+", "", part).strip()
            if cleaned and self.normalize_key(cleaned) not in ["off", "abgemeldet", "bench", "ersatz"]:
                focuses.append(self.normalize_item(cleaned))

        return {
            "ts_name": ts_name,
            "focus1": focuses[0] if len(focuses) > 0 else "",
            "focus2": focuses[1] if len(focuses) > 1 else "",
            "status": status,
        }

    def parse_text(self, text: str):
        result = []
        for line in text.splitlines():
            parsed = self.parse_line(line)
            if parsed:
                result.append(parsed)
        return result
