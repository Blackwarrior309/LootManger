# FocusRollManager Full Package

Dieses Paket enthält:

1. `FocusRollManager/`  
   Neues WotLK 3.3.5 Ingame-Addon

2. `FocusRollManagerDesk/`  
   Externes Python-Tool mit GUI, Parser, Alias-System und Export

---

## Workflow

### 1. Addon installieren

Ordner kopieren nach:

`World of Warcraft/Interface/AddOns/FocusRollManager`

Dann im Spiel:

`/reload`

### 2. Raidroster exportieren

Im Raid:

`/frm roster`

Die Ausgabe beginnt mit:

`FRMROSTER1|...`

Diesen Text kopieren und im externen Tool als Roster importieren.

### 3. TS/Discord Focus Rolls einfügen

Im externen Tool Text einfügen:

```txt
alex: dbw hc > sts hc
healbot: phyl hc
Tanky off
```

### 4. Addon Import kopieren

Button:

`Addon Import kopieren`

Der String beginnt mit:

`FRM1|...`

### 5. Im Spiel importieren

`/frm import FRM1|...`

### 6. Live nutzen

Addon erkennt Loot über:

- `LOOT_OPENED`
- `CHAT_MSG_LOOT`

und zeigt passende Focus-Spieler an.

---

## Wichtige Slash Commands

```txt
/frm show
/frm roster
/frm import <string>
/frm export
/frm missing
/frm loot
/frm item <item>
/frm win <player> <item>
/frm clear
```

---

## Sicherheit

Dieses System nutzt keine unsauberen Methoden:

- kein Memory Reading
- keine DLL Injection
- keine Hooks
- keine Botfunktionen
- keine automatisierte Eingabe

Kommunikation läuft über:

- Copy/Paste
- Importstrings
- Chatlog/SavedVariables optional
