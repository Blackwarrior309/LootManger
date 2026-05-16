import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "FocusRollManagerDesk"))

from desktop_pipeline import export_addon_string, parse_focus_players
from identity_manager import IdentityManager
from parser import FocusParser
from roster_importer import import_roster_text


class DesktopPipelineTests(unittest.TestCase):
    def test_roster_import_classes_are_used_for_focus_export(self):
        roster = import_roster_text(
            "FRMROSTER1|Blackpanther;DRUID|Healbot;PRIEST|Mageone;MAGE"
        )
        parser = FocusParser(str(ROOT / "FocusRollManagerDesk" / "synonyms.json"))
        identity = IdentityManager(str(ROOT / "FocusRollManagerDesk" / "aliases.json"))

        players, unmatched = parse_focus_players(
            "\n".join([
                "<20:11:02> blackpanther: focus DBW HC > STS HC",
                "<20:11:08> Healbot: fr Phyl HC",
                "<20:11:22> Mageone: fokus CTS HC / Tiny Abo HC",
            ]),
            roster,
            parser,
            identity,
        )

        self.assertEqual(unmatched, [])
        classes = {player["name"]: player["class"] for player in players}
        self.assertEqual(classes["Blackpanther"], "DRUID")
        self.assertEqual(classes["Healbot"], "PRIEST")
        self.assertEqual(classes["Mageone"], "MAGE")

        addon_string = export_addon_string(players)
        self.assertIn("Blackpanther;DRUID;Deathbringer's Will Heroic;Sharpened Twilight Scale Heroic;active;0", addon_string)
        self.assertIn("Healbot;PRIEST;Phylactery of the Nameless Lich Heroic;;active;0", addon_string)


if __name__ == "__main__":
    unittest.main()
