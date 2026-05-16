from chatlog_tail import parse_line, unescape_field, feed_lines


def test_parse_award():
    ev = parse_line("5/16 14:32:01.123  [FRM] AWARD|Bob|Bryntroll, the Bone Arbiter|3")
    assert ev == {"type": "AWARD", "player": "Bob",
                  "item": "Bryntroll, the Bone Arbiter", "strikes": 3}


def test_parse_player():
    ev = parse_line(
        "[FRM] PLAYER|Bob|MAGE|Deathbringer's Will|Bryntroll|active|2"
    )
    assert ev == {
        "type": "PLAYER", "player": "Bob", "class": "MAGE",
        "focus1": "Deathbringer's Will", "focus2": "Bryntroll",
        "status": "active", "strikes": 2,
    }


def test_parse_clear():
    ev = parse_line("blah [FRM] CLEAR")
    assert ev == {"type": "CLEAR"}


def test_parse_hello():
    ev = parse_line("[FRM] HELLO|0.2.0|1715800000")
    assert ev == {"type": "HELLO", "version": "0.2.0", "timestamp": "1715800000"}


def test_ignores_non_frm_lines():
    assert parse_line("5/16 14:32:01.123  [PRIEST] Heal cast") is None
    assert parse_line("") is None
    assert parse_line("random chatter [FRM]") is None  # no event word


def test_unescape_roundtrip():
    raw = "A|B;C\\D"
    escaped = raw.replace("\\", "\\\\").replace("|", "\\p").replace(";", "\\s")
    assert unescape_field(escaped) == raw


def test_parse_award_with_escapes():
    # Item name with literal pipe and semicolon — escaped at the source.
    ev = parse_line("[FRM] AWARD|Bob|Foo\\pBar\\sBaz|5")
    assert ev["item"] == "Foo|Bar;Baz"
    assert ev["strikes"] == 5


def test_award_invalid_strikes_defaults_to_zero():
    ev = parse_line("[FRM] AWARD|Bob|Item|notanumber")
    assert ev["strikes"] == 0


def test_feed_lines_callback():
    received = []
    lines = [
        "noise",
        "[FRM] AWARD|Alice|Item1|1",
        "more noise",
        "[FRM] CLEAR",
    ]
    n = feed_lines(lines, received.append)
    assert n == 2
    assert received[0]["type"] == "AWARD"
    assert received[1]["type"] == "CLEAR"


def test_player_with_diacritic():
    ev = parse_line("[FRM] PLAYER|Blàckpanther|ROGUE|DBW||active|0")
    assert ev["player"] == "Blàckpanther"
    assert ev["focus2"] == ""
