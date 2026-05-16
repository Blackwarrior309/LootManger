"""Tiny parser for WoW SavedVariables files.

Supports the subset WoW emits when serialising a SavedVariables table:
  - Top-level ``Name = { ... }`` assignments.
  - Tables with ``["key"] = value`` entries.
  - Array-style positional entries ``value,``.
  - String literals in single or double quotes with the usual escapes.
  - Integer and float numbers (negative supported).
  - ``true`` / ``false`` / ``nil``.
  - Line comments ``-- ...`` and the trailing ``-- [N]`` index hints.

Not supported (and not produced by WoW for SavedVariables): function values,
multi-line ``[[...]]`` string blocks, metatables, hex literals.
"""

from __future__ import annotations

import re
from typing import Any, Dict


_COMMENT_RE = re.compile(r"--.*?$", re.MULTILINE)


class LuaParseError(Exception):
    pass


class _Tokenizer:
    __slots__ = ("text", "pos", "len")

    def __init__(self, text: str):
        # Strip line comments first — they may include `]` or `}` which would
        # confuse the parser otherwise.
        self.text = _COMMENT_RE.sub("", text)
        self.pos = 0
        self.len = len(self.text)

    def skip_ws(self) -> None:
        while self.pos < self.len and self.text[self.pos] in " \t\r\n":
            self.pos += 1

    def peek(self) -> str:
        self.skip_ws()
        return self.text[self.pos] if self.pos < self.len else ""

    def consume(self, expected: str) -> None:
        self.skip_ws()
        if not self.text.startswith(expected, self.pos):
            raise LuaParseError(
                f"expected {expected!r} at pos {self.pos}, "
                f"got {self.text[self.pos:self.pos+10]!r}"
            )
        self.pos += len(expected)

    def try_consume(self, expected: str) -> bool:
        self.skip_ws()
        if self.text.startswith(expected, self.pos):
            self.pos += len(expected)
            return True
        return False

    def read_string(self) -> str:
        self.skip_ws()
        if self.pos >= self.len:
            raise LuaParseError("unexpected EOF in string")
        quote = self.text[self.pos]
        if quote not in ("'", '"'):
            raise LuaParseError(f"expected string at pos {self.pos}")
        self.pos += 1
        out = []
        while self.pos < self.len:
            c = self.text[self.pos]
            if c == "\\" and self.pos + 1 < self.len:
                nx = self.text[self.pos + 1]
                if nx == "n":
                    out.append("\n")
                elif nx == "r":
                    out.append("\r")
                elif nx == "t":
                    out.append("\t")
                elif nx == "\\":
                    out.append("\\")
                elif nx == "'":
                    out.append("'")
                elif nx == '"':
                    out.append('"')
                else:
                    out.append(nx)
                self.pos += 2
                continue
            if c == quote:
                self.pos += 1
                return "".join(out)
            out.append(c)
            self.pos += 1
        raise LuaParseError("unterminated string")

    def read_number(self) -> float | int:
        self.skip_ws()
        start = self.pos
        if self.pos < self.len and self.text[self.pos] == "-":
            self.pos += 1
        while self.pos < self.len and self.text[self.pos] in "0123456789.eE+-":
            self.pos += 1
        raw = self.text[start:self.pos]
        if "." in raw or "e" in raw or "E" in raw:
            return float(raw)
        return int(raw)

    def read_ident(self) -> str:
        self.skip_ws()
        start = self.pos
        while self.pos < self.len and (
            self.text[self.pos].isalnum() or self.text[self.pos] == "_"
        ):
            self.pos += 1
        if start == self.pos:
            raise LuaParseError(f"expected identifier at pos {self.pos}")
        return self.text[start:self.pos]


def _parse_value(tk: _Tokenizer) -> Any:
    c = tk.peek()
    if c == "{":
        return _parse_table(tk)
    if c in ("'", '"'):
        return tk.read_string()
    if c == "-" or c.isdigit():
        return tk.read_number()
    # identifier: true / false / nil
    saved = tk.pos
    ident = tk.read_ident()
    if ident == "true":
        return True
    if ident == "false":
        return False
    if ident == "nil":
        return None
    tk.pos = saved
    raise LuaParseError(f"unexpected token {ident!r} at pos {saved}")


def _parse_table(tk: _Tokenizer) -> Dict[Any, Any] | list:
    """Parse a Lua table.

    Returns a dict for keyed tables, a list for purely positional tables.
    Mixed tables come back as dicts with integer keys for the positional
    entries — matches Python's natural representation.
    """
    tk.consume("{")
    entries: list[tuple[Any, Any]] = []
    array_idx = 1
    while True:
        if tk.try_consume("}"):
            break
        # Keyed entry: ["key"] = value  OR  key = value
        if tk.peek() == "[":
            tk.consume("[")
            key: Any
            c2 = tk.peek()
            if c2 in ("'", '"'):
                key = tk.read_string()
            else:
                key = tk.read_number()
            tk.consume("]")
            tk.consume("=")
            value = _parse_value(tk)
            entries.append((key, value))
        else:
            saved = tk.pos
            try:
                ident = tk.read_ident()
                if tk.try_consume("="):
                    value = _parse_value(tk)
                    entries.append((ident, value))
                else:
                    # Was actually a positional value (true/false/nil/bare ident)
                    tk.pos = saved
                    raise LuaParseError("not a keyed entry")
            except LuaParseError:
                tk.pos = saved
                value = _parse_value(tk)
                entries.append((array_idx, value))
                array_idx += 1
        # Optional separator
        if not (tk.try_consume(",") or tk.try_consume(";")):
            tk.consume("}")
            break
    # Decide: pure array vs dict
    if entries and all(isinstance(k, int) for k, _ in entries):
        keys = [k for k, _ in entries]
        if keys == list(range(1, len(keys) + 1)):
            return [v for _, v in entries]
    return {k: v for k, v in entries}


def loads(text: str) -> Dict[str, Any]:
    """Parse a SavedVariables file's contents.

    Returns a dict mapping each top-level variable name to its value.
    """
    tk = _Tokenizer(text)
    result: Dict[str, Any] = {}
    while True:
        tk.skip_ws()
        if tk.pos >= tk.len:
            break
        name = tk.read_ident()
        tk.consume("=")
        value = _parse_value(tk)
        result[name] = value
        # Optional trailing semicolon
        tk.try_consume(";")
    return result


def load_file(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return loads(f.read())
