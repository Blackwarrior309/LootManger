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

    _FOCUS_MARKER_RE = re.compile(
        r"\b(fr\s*2?|focus|fokus|sr|softres|rolls?)\b", re.IGNORECASE
    )
    _OFF_RE = re.compile(r"\b(off|abgemeldet|bench|ersatz)\b", re.IGNORECASE)

    # Third-person assignment: "2 fr an Name" or "1fr an Alex 1fr an Bob"
    _ASSIGN_AN_RE = re.compile(
        r"(\d*)\s*fr\b\s+an\s+(\S+)",
        re.IGNORECASE,
    )
    # Third-person assignment: "FR ITEM für Name" or "2 fr für Name"
    # Handles: für, fuer, fur
    _ASSIGN_FUER_RE = re.compile(
        r"(?:(\d+)\s*)?fr\b\s*(.*?)\s*f(?:ü|ue|u)r\s+(\S+)\s*$",
        re.IGNORECASE,
    )

    def has_focus_marker(self, text: str) -> bool:
        normalized = self.normalize_key(text)
        return bool(self._FOCUS_MARKER_RE.search(normalized))

    def _split_at_focus_marker(self, text: str):
        """Return (prefix_before_marker, rest_after_marker_inclusive).

        If no marker is present, the whole text is treated as the prefix so
        off-keywords in pure status lines still apply.
        """
        normalized = self.normalize_key(text)
        m = self._FOCUS_MARKER_RE.search(normalized)
        if not m:
            return text, ""
        return text[: m.start()], text[m.start():]

    def _is_assignment(self, remainder: str) -> bool:
        return bool(
            self._ASSIGN_AN_RE.search(remainder)
            or self._ASSIGN_FUER_RE.search(remainder)
        )

    def _parse_assignments(self, remainder: str) -> list:
        """Parse third-person assignment lines into one or more player records."""
        # "FR ITEM für Name" or "N fr für Name" — item-specific or count
        m = self._ASSIGN_FUER_RE.search(remainder)
        if m:
            item_raw = (m.group(2) or "").strip()
            target = m.group(3).strip()
            focus1 = self.normalize_item(item_raw) if item_raw else ""
            return [{"ts_name": target, "focus1": focus1, "focus2": "", "status": "active"}]

        # "N fr an Name" — possibly repeated on one line
        results = []
        for m in self._ASSIGN_AN_RE.finditer(remainder):
            target = m.group(2).strip()
            if target:
                results.append({"ts_name": target, "focus1": "", "focus2": "", "status": "active"})
        return results

    def _parse_single(self, ts_name: str, remainder: str, is_ts_log: bool):
        """Original speaker-is-the-player parse path."""
        prefix, _item_part = self._split_at_focus_marker(remainder)
        prefix_lower = self.normalize_key(prefix)

        status = "active"
        if self._OFF_RE.search(prefix_lower) \
                or "meldet sich ab" in prefix_lower \
                or "nicht dabei" in prefix_lower \
                or "meldet sich ab" in self.normalize_key(remainder) \
                or "nicht dabei" in self.normalize_key(remainder):
            status = "off"

        if is_ts_log and status == "active" and not self.has_focus_marker(remainder):
            return None

        remainder = re.sub(r"(?i)\bfr\s*2\b", " > ", remainder)
        remainder = re.sub(
            r"(?i)\b(update|focus|fokus|fr|roll|rolls|sr|softres)\b", " ", remainder
        )
        remainder = re.sub(r"^[\s:\-]+", "", remainder)

        parts = re.split(r"\s*(?:>|/|,|;)\s*", remainder)
        parts = [part.strip() for part in parts if part.strip()]

        focuses = []
        for part in parts:
            cleaned = re.sub(r"^[\s:\-]+", "", part).strip()
            if cleaned and self.normalize_key(cleaned) not in {
                "off", "abgemeldet", "bench", "ersatz"
            }:
                focuses.append(self.normalize_item(cleaned))

        return {
            "ts_name": ts_name,
            "focus1": focuses[0] if len(focuses) > 0 else "",
            "focus2": focuses[1] if len(focuses) > 1 else "",
            "status": status,
        }

    def parse_line_multi(self, line: str) -> list:
        """Parse one TS-log line; may return multiple player records for assignment patterns."""
        ts_name, remainder, is_ts_log = self.extract_message(line)
        if not ts_name:
            return []

        if self._is_assignment(remainder):
            return self._parse_assignments(remainder)

        result = self._parse_single(ts_name, remainder, is_ts_log)
        return [result] if result else []

    def parse_line(self, line: str):
        """Parse one line; returns single record or None. Use parse_line_multi for assignment lines."""
        results = self.parse_line_multi(line)
        return results[0] if results else None

    def parse_text(self, text: str):
        result = []
        for line in text.splitlines():
            result.extend(self.parse_line_multi(line))
        return result
