from dataclasses import dataclass, asdict
from typing import Optional

@dataclass
class PlayerFocus:
    ts_name: str
    name: str
    class_name: str = "UNKNOWN"
    focus1: str = ""
    focus2: str = ""
    status: str = "active"
    strikes: int = 0
    confidence: int = 0

    def to_export_dict(self):
        return {
            "name": self.name,
            "class": self.class_name,
            "focus1": self.focus1,
            "focus2": self.focus2,
            "status": self.status,
            "strikes": self.strikes,
        }
