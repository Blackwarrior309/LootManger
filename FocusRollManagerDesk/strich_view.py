"""Live Strichliste view — large readable window for use during a raid.

Shows every player sorted by ``strikes`` ascending (fewer strikes = higher
priority, shown at the top). For each row the player name, both focus
rolls, and a big strike counter with ``+`` / ``-`` controls are rendered
in large fonts so the raid lead can read it across the desk.
"""

from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QColor, QFont
from PyQt6.QtWidgets import (
    QFrame,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QVBoxLayout,
    QWidget,
)


# WoW class -> player-name colour. Matches the in-game RAID_CLASS_COLORS so
# the strich list reads like the raid frame.
CLASS_COLORS = {
    "DEATHKNIGHT": "#C41F3B",
    "DRUID":       "#FF7D0A",
    "HUNTER":      "#ABD473",
    "MAGE":        "#69CCF0",
    "PALADIN":     "#F58CBA",
    "PRIEST":      "#FFFFFF",
    "ROGUE":       "#FFF569",
    "SHAMAN":      "#0070DE",
    "WARLOCK":     "#9482C9",
    "WARRIOR":     "#C79C6E",
    "UNKNOWN":     "#CCCCCC",
}


def _strich_color(strikes: int) -> str:
    """Traffic-light tint for the strike counter."""
    if strikes <= 0:
        return "#3DDC84"   # green — no strikes yet, top prio
    if strikes <= 2:
        return "#F0F0F0"   # neutral
    if strikes <= 4:
        return "#FFB347"   # amber
    return "#FF4D4D"       # red — repeated winner


class StrichRow(QFrame):
    """One row in the Strichliste — name, focuses, strike counter."""

    strikes_changed = pyqtSignal(str, int)  # (player_name, new_strikes)

    def __init__(self, rank: int, player: dict, parent=None):
        super().__init__(parent)
        self.player = player
        self.setFrameShape(QFrame.Shape.StyledPanel)
        self.setStyleSheet(
            "StrichRow { background-color: #1f2630; border-radius: 6px;"
            " margin: 2px 4px; }"
        )
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        self.setMinimumHeight(76)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(14, 8, 14, 8)
        layout.setSpacing(14)

        # Rank
        rank_lbl = QLabel(f"#{rank}")
        rank_lbl.setFont(QFont("Segoe UI", 18, QFont.Weight.DemiBold))
        rank_lbl.setStyleSheet("color: #8896A8;")
        rank_lbl.setFixedWidth(56)
        layout.addWidget(rank_lbl)

        # Name (class-coloured)
        name = player.get("name", "?") or "?"
        cls = (player.get("class") or "UNKNOWN").upper()
        colour = CLASS_COLORS.get(cls, CLASS_COLORS["UNKNOWN"])
        name_lbl = QLabel(name)
        name_lbl.setFont(QFont("Segoe UI", 26, QFont.Weight.Bold))
        name_lbl.setStyleSheet(f"color: {colour};")
        name_lbl.setMinimumWidth(260)
        layout.addWidget(name_lbl)

        # Focus rolls (two columns)
        focus_box = QVBoxLayout()
        f1 = player.get("focus1") or ""
        f2 = player.get("focus2") or ""
        f1_lbl = QLabel(f1 if f1 else "—")
        f1_lbl.setFont(QFont("Segoe UI", 18))
        f1_lbl.setStyleSheet("color: #FFD96B;" if f1 else "color: #555;")
        f2_lbl = QLabel(f2 if f2 else "—")
        f2_lbl.setFont(QFont("Segoe UI", 16))
        f2_lbl.setStyleSheet("color: #B0B6BE;" if f2 else "color: #555;")
        focus_box.addWidget(f1_lbl)
        focus_box.addWidget(f2_lbl)
        layout.addLayout(focus_box, stretch=1)

        # Status badge (off = grey badge on the right of the focuses)
        status = (player.get("status") or "active").lower()
        if status == "off":
            off_lbl = QLabel("ABWESEND")
            off_lbl.setFont(QFont("Segoe UI", 14, QFont.Weight.Bold))
            off_lbl.setStyleSheet(
                "color: #888; background-color: #2a2f3a; padding: 4px 8px;"
                " border-radius: 4px;"
            )
            layout.addWidget(off_lbl)

        # Strike counter (huge, colour-coded)
        try:
            strikes = int(player.get("strikes", 0) or 0)
        except (TypeError, ValueError):
            strikes = 0
        self.strikes = strikes

        self.strich_lbl = QLabel(str(strikes))
        self.strich_lbl.setFont(QFont("Segoe UI", 42, QFont.Weight.Black))
        self.strich_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.strich_lbl.setFixedWidth(96)
        self._apply_strich_colour()
        layout.addWidget(self.strich_lbl)

        # +/- buttons
        btn_box = QVBoxLayout()
        btn_box.setSpacing(4)
        plus = QPushButton("+")
        plus.setFont(QFont("Segoe UI", 18, QFont.Weight.Bold))
        plus.setFixedSize(46, 32)
        plus.clicked.connect(self._inc)
        minus = QPushButton("−")
        minus.setFont(QFont("Segoe UI", 18, QFont.Weight.Bold))
        minus.setFixedSize(46, 32)
        minus.clicked.connect(self._dec)
        btn_box.addWidget(plus)
        btn_box.addWidget(minus)
        layout.addLayout(btn_box)

    def _apply_strich_colour(self):
        c = _strich_color(self.strikes)
        self.strich_lbl.setStyleSheet(f"color: {c};")

    def _inc(self):
        self.strikes += 1
        self.strich_lbl.setText(str(self.strikes))
        self._apply_strich_colour()
        self.strikes_changed.emit(self.player.get("name", ""), self.strikes)

    def _dec(self):
        if self.strikes <= 0:
            return
        self.strikes -= 1
        self.strich_lbl.setText(str(self.strikes))
        self._apply_strich_colour()
        self.strikes_changed.emit(self.player.get("name", ""), self.strikes)


class StrichlisteWindow(QWidget):
    """Stand-alone large window. Receives a list of player dicts and rebuilds
    the row list. ``update_players`` may be called at any time (e.g. after the
    addon import string is pasted back from the in-game lootmaster).
    """

    def __init__(self, players=None, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Strichliste — Live")
        self.resize(1280, 880)
        self.setStyleSheet("background-color: #0f141b;")
        self._players = []

        root = QVBoxLayout(self)
        root.setContentsMargins(16, 16, 16, 16)
        root.setSpacing(12)

        # Header
        header = QLabel("STRICHLISTE")
        header.setFont(QFont("Segoe UI", 32, QFont.Weight.Black))
        header.setStyleSheet("color: #FFD96B; letter-spacing: 4px;")
        header.setAlignment(Qt.AlignmentFlag.AlignCenter)
        root.addWidget(header)

        hint = QLabel("Wenige Striche oben — Prio hoch.   +/− am Spieler aktualisiert Striche.")
        hint.setFont(QFont("Segoe UI", 14))
        hint.setStyleSheet("color: #8896A8;")
        hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        root.addWidget(hint)

        # Live-Sync status row (updated by LiveSyncCoordinator)
        self._status_lbl = QLabel("⚪ Sync inaktiv")
        self._status_lbl.setFont(QFont("Segoe UI", 13, QFont.Weight.DemiBold))
        self._status_lbl.setStyleSheet("color: #8896A8;")
        self._status_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        root.addWidget(self._status_lbl)

        # Column header
        col_hdr = QHBoxLayout()
        col_hdr.setContentsMargins(20, 4, 20, 4)
        for text, width in (
            ("#", 56),
            ("Spieler", 260),
            ("Focus 1 / Focus 2", None),
            ("Striche", 96),
            ("+/−", 52),
        ):
            lbl = QLabel(text)
            lbl.setFont(QFont("Segoe UI", 12, QFont.Weight.DemiBold))
            lbl.setStyleSheet("color: #6E7787;")
            if width:
                lbl.setFixedWidth(width)
            col_hdr.addWidget(lbl, stretch=1 if width is None else 0)
        root.addLayout(col_hdr)

        # Scroll area for rows
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setStyleSheet("QScrollArea { border: none; }")
        self._list_host = QWidget()
        self._list_layout = QVBoxLayout(self._list_host)
        self._list_layout.setContentsMargins(0, 0, 0, 0)
        self._list_layout.setSpacing(2)
        self._list_layout.addStretch()
        self.scroll.setWidget(self._list_host)
        root.addWidget(self.scroll, stretch=1)

        # Footer with refresh + close
        footer = QHBoxLayout()
        footer.addStretch()
        refresh = QPushButton("Neu sortieren")
        refresh.setFont(QFont("Segoe UI", 14, QFont.Weight.DemiBold))
        refresh.setMinimumWidth(160)
        refresh.setStyleSheet(
            "QPushButton { background-color: #2a3340; color: #FFD96B; "
            "padding: 8px 16px; border-radius: 4px; }"
            "QPushButton:hover { background-color: #354154; }"
        )
        refresh.clicked.connect(self._resort)
        footer.addWidget(refresh)
        root.addLayout(footer)

        if players:
            self.update_players(players)

    # ----- public API -----

    def update_players(self, players):
        """Replace the displayed player list. Off-status rows go to the
        bottom regardless of strikes so the visible top is always pickable
        priority players."""
        self._players = [dict(p) for p in (players or [])]
        self._rebuild()

    def _resort(self):
        self._rebuild()

    # ----- internal -----

    def _clear_rows(self):
        while self._list_layout.count():
            item = self._list_layout.takeAt(0)
            w = item.widget()
            if w is not None:
                w.deleteLater()

    def _rebuild(self):
        self._clear_rows()

        def sort_key(p):
            try:
                strikes = int(p.get("strikes", 0) or 0)
            except (TypeError, ValueError):
                strikes = 0
            off = (p.get("status") or "active").lower() == "off"
            return (1 if off else 0, strikes, (p.get("name") or "").lower())

        ordered = sorted(self._players, key=sort_key)

        for rank, player in enumerate(ordered, start=1):
            row = StrichRow(rank, player)
            row.strikes_changed.connect(self._on_strikes_changed)
            self._list_layout.addWidget(row)

        self._list_layout.addStretch()

    def _on_strikes_changed(self, name: str, new_value: int):
        for p in self._players:
            if p.get("name") == name:
                p["strikes"] = new_value
                break

    # ---------- live-sync hooks ----------

    def set_status(self, text: str, ok: bool = True) -> None:
        icon = "🟢" if ok else "🔴"
        self._status_lbl.setText(f"{icon} {text}")
        self._status_lbl.setStyleSheet(
            f"color: {'#3DDC84' if ok else '#FF4D4D'};"
        )

    def apply_award(self, name: str, item: str, strikes: int) -> None:
        """Patch the strike count for a single player and re-sort.

        Called by the coordinator on every chat-log AWARD event so the
        external monitor reflects the in-game click within ~200ms.
        """
        for p in self._players:
            if p.get("name") == name:
                p["strikes"] = int(strikes)
                break
        else:
            self._players.append({
                "name": name, "class": "UNKNOWN",
                "focus1": "", "focus2": "",
                "status": "active", "strikes": int(strikes),
            })
        self._rebuild()

    def apply_full_state(self, players: list) -> None:
        """Replace the entire list (savedvars reload or initial seed)."""
        self.update_players(players)
