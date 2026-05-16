from exporter import Exporter


def _player(**overrides):
    base = {
        "name": "Alex",
        "class": "MAGE",
        "focus1": "Deathbringer's Will",
        "focus2": "",
        "status": "active",
        "strikes": 0,
    }
    base.update(overrides)
    return base


def test_addon_string_basic():
    s = Exporter.addon_string([_player()])
    assert s.startswith("FRM1|")
    assert "Alex;MAGE;Deathbringer's Will;;active;0" in s


def test_addon_string_skips_missing_name():
    s = Exporter.addon_string([{"class": "MAGE"}, _player(name="Bob")])
    assert "Bob" in s
    assert s.count("|") == 1  # only header + Bob


def test_addon_string_escapes_delimiters():
    s = Exporter.addon_string([_player(name="A|B", focus1="X;Y")])
    assert "A\\pB" in s
    assert "X\\sY" in s
    # Real pipes/semicolons inside the field must be gone after escape.
    body = s.split("|", 1)[1]   # skip header
    assert body.count("|") == 0
    fields = body.split(";")
    assert len(fields) == 6


def test_addon_string_escapes_backslash():
    s = Exporter.addon_string([_player(name="A\\B")])
    assert "A\\\\B" in s


def test_lua_text_escapes_quotes():
    """Bug regression: ' was unescaped and produced invalid Lua."""
    s = Exporter.lua_text([_player(name='Bob"Quote', focus1='Item"With"Quote')])
    # Quote inside the value must be backslash-escaped.
    assert '["Bob\\"Quote"]' in s
    assert 'focus1 = "Item\\"With\\"Quote"' in s


def test_lua_text_escapes_backslash():
    s = Exporter.lua_text([_player(name="A\\B")])
    assert '["A\\\\B"]' in s


def test_lua_text_strikes_int_coercion():
    s = Exporter.lua_text([_player(strikes="3")])
    assert "strikes = 3," in s
    s2 = Exporter.lua_text([_player(strikes=None)])
    assert "strikes = 0," in s2


def test_safe_roundtrip_property():
    """Escape preserves all information."""
    raw = "A|B;C\\D"
    escaped = Exporter.safe(raw)
    # Manually reverse: \\ -> \, \p -> |, \s -> ; (order: handle \p and \s
    # first to avoid \\\\p being mis-decoded as \\ + p).
    unescaped = escaped
    out = []
    i = 0
    while i < len(unescaped):
        c = unescaped[i]
        if c == "\\" and i + 1 < len(unescaped):
            nx = unescaped[i + 1]
            if nx == "p":
                out.append("|"); i += 2; continue
            if nx == "s":
                out.append(";"); i += 2; continue
            if nx == "\\":
                out.append("\\"); i += 2; continue
        out.append(c)
        i += 1
    assert "".join(out) == raw


def test_json_text_valid():
    import json
    s = Exporter.json_text([_player()])
    parsed = json.loads(s)
    assert parsed["players"][0]["name"] == "Alex"


# --- readback_text ---

def test_readback_contains_class_header():
    s = Exporter.readback_text([_player()])
    assert "MAGE" in s


def test_readback_contains_player_and_focus():
    s = Exporter.readback_text([_player()])
    assert "Alex" in s
    assert "Deathbringer's Will" in s


def test_readback_off_player():
    s = Exporter.readback_text([_player(status="off", focus1="")])
    assert "(off)" in s


def test_readback_no_focus():
    s = Exporter.readback_text([_player(focus1="", focus2="")])
    assert "(kein Focus)" in s


def test_readback_two_focuses():
    s = Exporter.readback_text([_player(focus1="DBW", focus2="STS")])
    assert "DBW / STS" in s


def test_readback_class_sort_before_player_sort():
    """Class section appears before A-Z section."""
    players = [
        _player(name="Zorro", class_="WARRIOR", focus1="Bryn"),
        _player(name="Alex", class_="MAGE", focus1="DBW"),
    ]
    # fix key name: _player uses 'class'
    players = [
        {"name": "Zorro", "class": "WARRIOR", "focus1": "Bryn", "focus2": "", "status": "active", "strikes": 0},
        {"name": "Alex", "class": "MAGE", "focus1": "DBW", "focus2": "", "status": "active", "strikes": 0},
    ]
    s = Exporter.readback_text(players)
    assert s.index("nach Klasse") < s.index("nach Spieler")
    # MAGE comes before WARRIOR in class order
    assert s.index("MAGE") < s.index("WARRIOR")
