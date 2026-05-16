from parser import FocusParser


def test_basic_focus_line():
    p = FocusParser()
    result = p.parse_line("<20:11:02> Blackpanther: focus DBW HC > STS HC")
    assert result["ts_name"] == "Blackpanther"
    assert result["focus1"] == "Deathbringer's Will Heroic"
    assert result["focus2"] == "Sharpened Twilight Scale Heroic"
    assert result["status"] == "active"


def test_off_only_line():
    p = FocusParser()
    result = p.parse_line("<20:11:14> Tanky off")
    assert result["ts_name"] == "Tanky"
    assert result["status"] == "off"
    assert result["focus1"] == ""


def test_ts_log_without_marker_returns_none():
    p = FocusParser()
    assert p.parse_line("<20:11:14> Blackpanther: hello there") is None


def test_clipboard_paste_without_marker_still_parses():
    """Outside a TS log timestamp wrapper the marker is optional."""
    p = FocusParser()
    result = p.parse_line("alex: dbw hc")
    assert result is not None
    assert result["focus1"] == "Deathbringer's Will Heroic"


def test_ersatz_in_item_name_does_not_flip_status():
    """Regression: 'ersatz-token' as item used to flip status to off."""
    p = FocusParser()
    result = p.parse_line("<20:00:00> alex: focus ersatz-token")
    assert result["status"] == "active"
    assert "ersatz" in result["focus1"].lower()


def test_off_keywords_in_prefix_still_work():
    p = FocusParser()
    assert p.parse_line("<20:00:00> alex bench")["status"] == "off"
    assert p.parse_line("<20:00:00> alex ist abgemeldet")["status"] == "off"


def test_long_form_off_phrases():
    p = FocusParser()
    assert p.parse_line("<20:00:00> alex meldet sich ab")["status"] == "off"
    assert p.parse_line("<20:00:00> alex ist heute nicht dabei")["status"] == "off"


def test_quoted_speaker_with_spaces():
    p = FocusParser()
    result = p.parse_line('<20:00:00> "Player With Space": focus DBW')
    assert result["ts_name"] == "Player With Space"
    assert result["focus1"] == "Deathbringer's Will"


def test_synonym_expansion_count():
    """Make sure the migrated ItemDB entries actually load."""
    p = FocusParser()
    keys = [k for k in p.synonyms.keys() if not k.startswith("_")]
    assert len(keys) > 100, f"Expected expanded synonym table, got {len(keys)}"


def test_synonym_examples():
    p = FocusParser()
    assert p.normalize_item("bryn") == "Bryntroll, the Bone Arbiter"
    assert p.normalize_item("sff") == "Sindragosa's Flawless Fang"
    assert p.normalize_item("wdt") == "Wille des Todesbringers"
    assert p.normalize_item("nib") == "Nibelung"


def test_status_keyword_inside_focus_remains_active():
    p = FocusParser()
    assert p.parse_line("<20:00:00> alex: focus Officer-Token")["status"] == "active"


def test_diacritic_speaker():
    p = FocusParser()
    result = p.parse_line('<20:00:00> Blàckpanther: focus dbw')
    assert result["ts_name"] == "Blàckpanther"
    assert result["focus1"] == "Deathbringer's Will"


def test_parse_text_skips_noise():
    p = FocusParser()
    text = "\n".join([
        "<20:00:00> *** System Message",
        "<20:00:01> alex: focus dbw",
        "<20:00:02> bob: hi",
        "Ende des Chat Protokolls",
    ])
    result = p.parse_text(text)
    assert len(result) == 1
    assert result[0]["ts_name"] == "alex"


# --- Third-person assignment patterns ---

def test_assign_two_fr_an_name():
    """'2 fr an Name' assigns FRs to Name, not the speaker."""
    p = FocusParser()
    results = p.parse_line_multi("<20:00:00> Raidleiter: 2 fr an Alex")
    assert len(results) == 1
    assert results[0]["ts_name"] == "Alex"
    assert results[0]["status"] == "active"


def test_assign_one_fr_each_two_names():
    """'1fr an Alex 1fr an Bob' → two separate records."""
    p = FocusParser()
    results = p.parse_line_multi("<20:00:00> Raidleiter: 1fr an Alex 1fr an Bob")
    assert len(results) == 2
    names = {r["ts_name"] for r in results}
    assert names == {"Alex", "Bob"}


def test_assign_fr_item_fuer_name():
    """'FR DBW für Alex' → Alex gets focus on DBW."""
    p = FocusParser()
    results = p.parse_line_multi("<20:00:00> Raidleiter: FR DBW für Alex")
    assert len(results) == 1
    assert results[0]["ts_name"] == "Alex"
    assert results[0]["focus1"] == "Deathbringer's Will"
    assert results[0]["focus2"] == ""


def test_assign_fr_item_fuer_with_synonym():
    """'FR bryn für Bob' → focus1 resolved via synonym."""
    p = FocusParser()
    results = p.parse_line_multi("<20:00:00> RL: FR bryn für Bob")
    assert results[0]["ts_name"] == "Bob"
    assert results[0]["focus1"] == "Bryntroll, the Bone Arbiter"


def test_assign_count_fuer_name():
    """'2 fr für Alex' → Alex gets 2 FRs, no specific item."""
    p = FocusParser()
    results = p.parse_line_multi("<20:00:00> RL: 2 fr für Alex")
    assert len(results) == 1
    assert results[0]["ts_name"] == "Alex"
    assert results[0]["focus1"] == ""


def test_assign_1fr_compact_an_name():
    """'1fr an Alex' (no space between count and fr)."""
    p = FocusParser()
    results = p.parse_line_multi("<20:00:00> RL: 1fr an Alex")
    assert len(results) == 1
    assert results[0]["ts_name"] == "Alex"


def test_parse_text_flattens_assignment():
    """parse_text flattens multi-record assignment lines correctly."""
    p = FocusParser()
    text = "\n".join([
        "<20:00:00> Raidleiter: 1fr an Alex 1fr an Bob",
        "<20:00:01> Raidleiter: FR DBW für Carla",
    ])
    result = p.parse_text(text)
    assert len(result) == 3
    names = {r["ts_name"] for r in result}
    assert names == {"Alex", "Bob", "Carla"}


def test_self_report_not_treated_as_assignment():
    """Normal self-report 'alex: fr DBW > STS' must NOT trigger assignment path."""
    p = FocusParser()
    result = p.parse_line("<20:00:00> alex: fr DBW > STS")
    assert result is not None
    assert result["ts_name"] == "alex"
    assert result["focus1"] == "Deathbringer's Will"
