import sys
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QTextEdit, QPushButton,
    QTableWidget, QTableWidgetItem, QFileDialog, QMessageBox, QLabel,
    QListWidget
)
from PyQt6.QtGui import QGuiApplication

from parser import FocusParser
from identity_manager import IdentityManager
from roster_importer import import_roster_text, load_roster_file
from exporter import Exporter
from desktop_pipeline import import_roster_if_present, parse_focus_players
from strich_view import StrichlisteWindow
from live_sync import LiveSyncCoordinator
from config import AppConfig, fill_defaults

class FocusRollManagerDesk(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("FocusRollManagerDesk")
        self.resize(1100, 760)

        self.parser = FocusParser()
        self.identity = IdentityManager()
        self.roster = []
        self.players = []
        self.strich_window = None
        self.config = fill_defaults(AppConfig.load())
        self.coordinator: LiveSyncCoordinator | None = None

        layout = QVBoxLayout(self)

        self.roster_info = QLabel("Roster: nicht geladen")
        layout.addWidget(self.roster_info)

        self.input = QTextEdit()
        self.input.setPlaceholderText("TS/Discord Focus-Rolls hier einfügen...")
        layout.addWidget(self.input)

        buttons = QHBoxLayout()
        layout.addLayout(buttons)

        parse_btn = QPushButton("Analysieren")
        parse_btn.clicked.connect(self.parse)
        buttons.addWidget(parse_btn)

        sample_btn = QPushButton("FR Beispiel")
        sample_btn.clicked.connect(self.insert_sample_focus)
        buttons.addWidget(sample_btn)

        roster_btn = QPushButton("Roster importieren")
        roster_btn.clicked.connect(self.import_roster_dialog)
        buttons.addWidget(roster_btn)

        roster_clipboard_btn = QPushButton("Roster einfügen")
        roster_clipboard_btn.clicked.connect(self.import_roster_clipboard)
        buttons.addWidget(roster_clipboard_btn)

        copy_btn = QPushButton("Addon Import kopieren")
        copy_btn.clicked.connect(self.copy_addon)
        buttons.addWidget(copy_btn)

        alias_btn = QPushButton("Alias speichern")
        alias_btn.clicked.connect(self.save_selected_alias)
        buttons.addWidget(alias_btn)

        link_alias_btn = QPushButton("Auswahl verlinken")
        link_alias_btn.clicked.connect(self.link_selected_alias)
        buttons.addWidget(link_alias_btn)

        json_btn = QPushButton("JSON anzeigen")
        json_btn.clicked.connect(self.show_json)
        buttons.addWidget(json_btn)

        lua_btn = QPushButton("Lua anzeigen")
        lua_btn.clicked.connect(self.show_lua)
        buttons.addWidget(lua_btn)

        readback_btn = QPushButton("TS Leseliste")
        readback_btn.setToolTip("Sortierte Leseliste für TS-Readback (Klasse / Focus / Name)")
        readback_btn.clicked.connect(self.show_readback)
        buttons.addWidget(readback_btn)

        strich_btn = QPushButton("Strichliste Live")
        strich_btn.setStyleSheet(
            "QPushButton { background-color: #2a3340; color: #FFD96B; "
            "font-weight: bold; padding: 6px 14px; }"
        )
        strich_btn.clicked.connect(self.open_strichliste)
        buttons.addWidget(strich_btn)

        self.table = QTableWidget(0, 8)
        self.table.setHorizontalHeaderLabels([
            "TS Name", "WoW Name", "Klasse", "Focus1", "Focus2", "Status", "Striche", "Confidence"
        ])
        layout.addWidget(self.table)

        mapping_layout = QHBoxLayout()
        layout.addLayout(mapping_layout)

        unmatched_layout = QVBoxLayout()
        mapping_layout.addLayout(unmatched_layout)
        unmatched_layout.addWidget(QLabel("Nicht zugeordnete TS-Namen"))
        self.unmatched_list = QListWidget()
        unmatched_layout.addWidget(self.unmatched_list)

        roster_layout = QVBoxLayout()
        mapping_layout.addLayout(roster_layout)
        roster_layout.addWidget(QLabel("WoW-Namen aus Roster"))
        self.roster_list = QListWidget()
        roster_layout.addWidget(self.roster_list)

        self.missing = QTextEdit()
        self.missing.setReadOnly(True)
        self.missing.setPlaceholderText("Fehlende Focuses / nicht zugeordnete Namen erscheinen hier...")
        layout.addWidget(self.missing)

    def import_roster_dialog(self):
        path, _ = QFileDialog.getOpenFileName(self, "Roster laden", "", "Text/JSON/CSV (*.txt *.json *.csv);;Alle Dateien (*)")
        if not path:
            return
        self.roster = load_roster_file(path)
        self.roster_info.setText(f"Roster: {len(self.roster)} Spieler geladen")
        self.refresh_mapping_lists([])
        QMessageBox.information(self, "Roster", f"{len(self.roster)} Spieler importiert.")

    def import_roster_clipboard(self):
        text = QGuiApplication.clipboard().text().strip()
        if not text:
            QMessageBox.warning(self, "Roster", "Die Zwischenablage ist leer.")
            return

        roster = import_roster_text(text)
        if not roster:
            QMessageBox.warning(self, "Roster", "Kein gültiger Roster in der Zwischenablage gefunden.")
            return

        self.roster = roster
        self.roster_info.setText(f"Roster: {len(self.roster)} Spieler geladen")
        self.refresh_mapping_lists([])
        QMessageBox.information(self, "Roster", f"{len(self.roster)} Spieler aus der Zwischenablage importiert.")

    def insert_sample_focus(self):
        self.input.setPlainText("alex: dbw hc > sts hc\nhealbot: phyl hc\nTanky off")

    def parse(self):
        text = self.input.toPlainText()
        roster = import_roster_if_present(text)
        if roster is not None:
            self.roster = roster
            self.roster_info.setText(f"Roster: {len(self.roster)} Spieler geladen")
            self.refresh_mapping_lists([])
            QMessageBox.information(self, "Roster", f"{len(self.roster)} Spieler importiert.")
            return

        self.players, unmatched = parse_focus_players(text, self.roster, self.parser, self.identity)
        self.refresh_table()
        self.refresh_warnings(unmatched)

    def refresh_table(self):
        self.table.setRowCount(len(self.players))
        for r, p in enumerate(self.players):
            values = [
                p.get("ts_name", ""),
                p.get("name", ""),
                p.get("class", "UNKNOWN"),
                p.get("focus1", ""),
                p.get("focus2", ""),
                p.get("status", "active"),
                str(p.get("strikes", 0)),
                str(p.get("confidence", 0)),
            ]
            for c, value in enumerate(values):
                self.table.setItem(r, c, QTableWidgetItem(value))

    def table_value(self, row, column):
        item = self.table.item(row, column)
        return item.text().strip() if item else ""

    def export_players(self):
        players = []
        for row in range(self.table.rowCount()):
            name = self.table_value(row, 1)
            if not name:
                continue
            strikes_text = self.table_value(row, 6)
            try:
                strikes = int(strikes_text or "0")
            except ValueError:
                strikes = 0
            players.append({
                "name": name,
                "class": self.table_value(row, 2) or "UNKNOWN",
                "focus1": self.table_value(row, 3),
                "focus2": self.table_value(row, 4),
                "status": self.table_value(row, 5) or "active",
                "strikes": strikes,
            })
        return players

    def save_selected_alias(self):
        row = self.table.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Alias", "Bitte zuerst eine Tabellenzeile auswählen.")
            return

        ts_name = self.table_value(row, 0)
        wow_name = self.table_value(row, 1)
        if not ts_name or not wow_name:
            QMessageBox.warning(self, "Alias", "TS Name und WoW Name müssen gefüllt sein.")
            return

        self.identity.add_alias(ts_name, wow_name)
        QMessageBox.information(self, "Alias", f"Alias gespeichert: {ts_name} -> {wow_name}")

    def link_selected_alias(self):
        ts_item = self.unmatched_list.currentItem()
        roster_item = self.roster_list.currentItem()
        if not ts_item or not roster_item:
            QMessageBox.warning(self, "Alias", "Bitte links einen TS-Namen und rechts einen WoW-Namen auswählen.")
            return

        ts_name = ts_item.text()
        wow_name = roster_item.text()
        self.identity.add_alias(ts_name, wow_name)

        roster_by_name = {r["name"]: r for r in self.roster}
        class_name = roster_by_name.get(wow_name, {}).get("class", "UNKNOWN")
        for player in self.players:
            if player.get("ts_name") == ts_name:
                player["name"] = wow_name
                player["class"] = class_name
                player["confidence"] = 100

        unmatched = [
            p["ts_name"]
            for p in self.players
            if p.get("name") == p.get("ts_name") and p.get("confidence", 0) == 0
        ]
        self.refresh_table()
        self.refresh_warnings(unmatched)
        QMessageBox.information(self, "Alias", f"Alias gespeichert: {ts_name} -> {wow_name}")

    def refresh_warnings(self, unmatched):
        player_names = {p["name"] for p in self.players if p.get("focus1") or p.get("focus2")}
        missing = [r["name"] for r in self.roster if r["name"] not in player_names]
        self.refresh_mapping_lists(unmatched)

        lines = []
        if unmatched:
            lines.append("Nicht zugeordnet:")
            lines += [f"- {x}" for x in unmatched]
            lines.append("")

        if missing:
            lines.append("Roster-Spieler ohne Focus:")
            lines += [f"- {x}" for x in missing]
        else:
            lines.append("Keine fehlenden Focuses im geladenen Roster.")

        self.missing.setText("\n".join(lines))

    def refresh_mapping_lists(self, unmatched):
        self.unmatched_list.clear()
        for name in sorted(set(unmatched)):
            self.unmatched_list.addItem(name)

        self.roster_list.clear()
        for row in sorted(self.roster, key=lambda r: r.get("name", "")):
            name = row.get("name", "")
            if name:
                self.roster_list.addItem(name)

    def copy_addon(self):
        text = Exporter.addon_string(self.export_players())
        QGuiApplication.clipboard().setText(text)
        QMessageBox.information(self, "Kopiert", "Addon Import String wurde in die Zwischenablage kopiert.")

    def show_json(self):
        self.show_output("JSON Export", Exporter.json_text(self.export_players()))

    def show_lua(self):
        self.show_output("Lua Export", Exporter.lua_text(self.export_players()))

    def show_readback(self):
        players = self.export_players()
        if not players:
            QMessageBox.warning(self, "TS Leseliste", "Keine Spieler geladen. Erst analysieren.")
            return
        self.show_output("TS Leseliste", Exporter.readback_text(players))

    def show_output(self, title, text):
        win = QTextEdit()
        win.setWindowTitle(title)
        win.resize(900, 600)
        win.setText(text)
        win.show()
        win._keepalive = win

    def open_strichliste(self):
        players = self.export_players()
        if not players:
            QMessageBox.warning(
                self,
                "Strichliste",
                "Keine Spieler geladen. Erst Roster importieren und TS-Log analysieren.",
            )
            return
        if self.strich_window is None:
            self.strich_window = StrichlisteWindow(players)
        else:
            self.strich_window.update_players(players)

        self._ensure_live_sync(players)

        self.strich_window.show()
        self.strich_window.raise_()
        self.strich_window.activateWindow()

    def _ensure_live_sync(self, seed_players):
        """Start (or restart) the chat-log + savedvars coordinator and bind
        it to the open Strichliste window."""
        chat = self.config.chatlog_path
        sv = self.config.savedvars_path

        if not chat and not sv:
            self.strich_window.set_status(
                "Kein Pfad konfiguriert — extern bleibt manuell", ok=False
            )
            return

        if self.coordinator is not None:
            self.coordinator.stop()

        self.coordinator = LiveSyncCoordinator(chatlog_path=chat, savedvars_path=sv)
        self.coordinator.players_changed.connect(self.strich_window.apply_full_state)
        self.coordinator.award_received.connect(self.strich_window.apply_award)
        self.coordinator.status_changed.connect(
            lambda txt: self.strich_window.set_status(txt, ok=True)
        )
        self.coordinator.set_players(seed_players)
        ok = self.coordinator.start()
        if not ok:
            self.strich_window.set_status(
                "Sync-Quellen nicht erreichbar — paste-only", ok=False
            )

if __name__ == "__main__":
    app = QApplication(sys.argv)
    w = FocusRollManagerDesk()
    w.show()
    sys.exit(app.exec())
