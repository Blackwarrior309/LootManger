from roster_importer import import_roster_text


def test_frm_format():
    text = "FRMROSTER1|Bob;MAGE|Alice;PRIEST"
    result = import_roster_text(text)
    assert result == [
        {"name": "Bob", "class": "MAGE"},
        {"name": "Alice", "class": "PRIEST"},
    ]


def test_frm_format_missing_class_defaults_unknown():
    text = "FRMROSTER1|Bob|Alice;PRIEST"
    result = import_roster_text(text)
    assert result[0] == {"name": "Bob", "class": "UNKNOWN"}


def test_json_format():
    text = '[{"name": "Bob", "class": "MAGE"}, {"name": "Alice"}]'
    result = import_roster_text(text)
    assert len(result) == 2
    assert result[0]["class"] == "MAGE"
    assert result[1]["class"] == "UNKNOWN"


def test_plain_csv_semicolon():
    text = "Bob;MAGE\nAlice;PRIEST"
    result = import_roster_text(text)
    assert result == [
        {"name": "Bob", "class": "MAGE"},
        {"name": "Alice", "class": "PRIEST"},
    ]


def test_plain_csv_comma():
    text = "Bob,MAGE\nAlice,PRIEST"
    result = import_roster_text(text)
    assert result == [
        {"name": "Bob", "class": "MAGE"},
        {"name": "Alice", "class": "PRIEST"},
    ]


def test_plain_no_class():
    text = "Bob\nAlice"
    result = import_roster_text(text)
    assert all(r["class"] == "UNKNOWN" for r in result)
    assert [r["name"] for r in result] == ["Bob", "Alice"]


def test_empty_text():
    assert import_roster_text("") == []
    assert import_roster_text("   \n  ") == []


def test_diacritic_preserved():
    text = "FRMROSTER1|Blàckpanther;ROGUE"
    result = import_roster_text(text)
    assert result[0]["name"] == "Blàckpanther"
