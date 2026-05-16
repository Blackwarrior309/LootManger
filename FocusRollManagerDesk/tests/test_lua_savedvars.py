import textwrap

import pytest

import lua_savedvars as lsv


def test_simple_assignment():
    out = lsv.loads('Foo = "bar"')
    assert out == {"Foo": "bar"}


def test_number_and_bool_nil():
    out = lsv.loads("A=1 B=2.5 C=true D=false E=nil")
    assert out == {"A": 1, "B": 2.5, "C": True, "D": False, "E": None}


def test_simple_table_keyed():
    text = """
        Tbl = {
            ["a"] = 1,
            ["b"] = "two",
        }
    """
    out = lsv.loads(text)
    assert out == {"Tbl": {"a": 1, "b": "two"}}


def test_positional_array():
    out = lsv.loads('Arr = { "x", "y", "z", }')
    assert out == {"Arr": ["x", "y", "z"]}


def test_nested_focus_db():
    text = textwrap.dedent("""
        FocusRollManagerDB = {
            ["players"] = {
                ["Bob"] = {
                    ["class"] = "MAGE",
                    ["focus1"] = "Deathbringer's Will Heroic",
                    ["focus2"] = "",
                    ["status"] = "active",
                    ["strikes"] = 3,
                    ["wins"] = {
                        {
                            ["item"] = "Bryntroll",
                            ["time"] = "2026-05-16 14:32",
                        },
                    },
                },
            },
            ["roster"] = {
            },
            ["loot"] = {
                ["items"] = {
                },
                ["lastBoss"] = "",
            },
            ["rolls"] = {
            },
            ["settings"] = {
            },
        }
    """)
    out = lsv.loads(text)
    db = out["FocusRollManagerDB"]
    assert db["players"]["Bob"]["class"] == "MAGE"
    assert db["players"]["Bob"]["strikes"] == 3
    assert db["players"]["Bob"]["wins"][0]["item"] == "Bryntroll"
    assert db["loot"]["lastBoss"] == ""


def test_string_escapes():
    text = r'X = "a\"b\\c\nd"'
    out = lsv.loads(text)
    assert out == {"X": 'a"b\\c\nd'}


def test_comments_stripped():
    text = """
        -- top comment
        Foo = {
            ["a"] = 1, -- [1]
            -- mid comment
            ["b"] = 2,
        }
    """
    out = lsv.loads(text)
    assert out == {"Foo": {"a": 1, "b": 2}}


def test_negative_numbers():
    out = lsv.loads("Foo = { ['n'] = -42, ['f'] = -3.14, }")
    assert out["Foo"]["n"] == -42
    assert out["Foo"]["f"] == pytest.approx(-3.14)


def test_empty_table():
    out = lsv.loads("X = {}")
    assert out == {"X": {}}


def test_diacritic_strings():
    out = lsv.loads('Foo = { ["name"] = "Blàckpanther", }')
    assert out["Foo"]["name"] == "Blàckpanther"


def test_invalid_raises():
    with pytest.raises(lsv.LuaParseError):
        lsv.loads("X = {")
