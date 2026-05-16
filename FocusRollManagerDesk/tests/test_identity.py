import tempfile
from pathlib import Path

from identity_manager import IdentityManager


def _mgr(tmp_path):
    return IdentityManager(alias_file=str(tmp_path / "aliases.json"))


def test_exact_match(tmp_path):
    m = _mgr(tmp_path)
    roster = [{"name": "Blackpanther", "class": "DRUID"}]
    name, conf = m.resolve("Blackpanther", roster)
    assert name == "Blackpanther"
    assert conf >= 95


def test_diacritic_match(tmp_path):
    m = _mgr(tmp_path)
    roster = [{"name": "Blàckpanther", "class": "DRUID"}]
    name, conf = m.resolve("Blackpanther", roster)
    assert name == "Blàckpanther"
    assert conf >= 80


def test_alias_overrides_fuzzy(tmp_path):
    m = _mgr(tmp_path)
    m.add_alias("alex", "Blackpanther")
    roster = [{"name": "Blackpanther", "class": "DRUID"},
              {"name": "Alexandros", "class": "MAGE"}]
    name, conf = m.resolve("alex", roster)
    assert name == "Blackpanther"
    assert conf == 100


def test_alias_persists(tmp_path):
    path = tmp_path / "aliases.json"
    m1 = IdentityManager(alias_file=str(path))
    m1.add_alias("alex", "Blackpanther")
    m2 = IdentityManager(alias_file=str(path))
    assert m2.aliases["alex"] == "Blackpanther"


def test_unknown_returns_none(tmp_path):
    m = _mgr(tmp_path)
    name, conf = m.resolve("Totally Unknown", [{"name": "Bob", "class": "MAGE"}])
    assert name is None
    assert conf == 0


def test_empty_roster(tmp_path):
    m = _mgr(tmp_path)
    name, conf = m.resolve("alex", [])
    assert name is None
    assert conf == 0
