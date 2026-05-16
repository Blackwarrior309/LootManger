# CLAUDE.md — FocusRollManager Project Notes

Context for Claude Code working in this repository.

## What this is

A two-piece system for managing ICC25 HC focus rolls on the Rising Gods WoW 3.3.5a private server:

1. **Ingame addon** — `LootManger-main/` root (called **FRM** / FocusRollManager, slash `/frm`). This is the **main addon**.
2. **External desktop app** — `FocusRollManagerDesk/` (PyQt6). Parses TS/Discord focus-roll logs into a structured player list, then exports an `FRM1|...` import string for the ingame addon.

> **`ICCFocusLoot/` is NOT the main addon.** It's an older self-contained addon kept in-tree as a data source / pattern reference (ItemDB, Sync, Striche system). Do not extend it as the primary target. Read it for copy/paste only.

The TS-log → ingame → external-live-display chain is the production flow:

```
[TS-Log] → Desktop parse → FRM1 string → /frm import (ingame)
                                             ↓
                                 Raid runs, LM clicks "Award" per item
                                             ↓
                          MarkWin → +1 strike → Sync.BroadcastAward
                                             ↓
                          DEFAULT_CHAT_FRAME:AddMessage("[FRM] AWARD|...")
                                             ↓
                          LoggingChat → Logs/WoWChatLog.txt
                                             ↓
                          [Python ChatLogTail] → StrichlisteWindow live (~200ms lag)
```

Backup path: lootmaster hits the "Reload Vollsync" button between bosses → `ReloadUI()` flushes SavedVariables → Python `lua_savedvars.py` parser picks up the file → full state push to the Strichliste window.

## Repository layout

```
LootManger-main/
├── LootManger-main.toc        load order
├── Core.lua                   slash command dispatcher (/frm ...)
├── Data.lua                   SavedVariables DB + UpsertPlayer/MarkWin/ClearFocus (with Sync hooks)
├── Utils.lua                  EscapeField/Trim/Split (FRM1 escape matches Python Exporter.safe)
├── Synonyms.lua               in-game item alias table (small; use external synonyms.json for big set)
├── ImportExport.lua           FRM1 import/export, UnescapeField mirrored to Python
├── Roster.lua                 raid roster import + missing-focus detection
├── Loot.lua                   LOOT_OPENED detection, db.loot.items
├── Rolls.lua                  CHAT_MSG_SYSTEM /roll parser (EN + DE)
├── Sync.lua                   Live broadcast via DEFAULT_CHAT_FRAME:AddMessage + LoggingChat
├── Debug.lua                  /frm debug helpers
├── UI.lua                     button-driven main window (sync toggle, reload, award per row, +/- strikes)
│
├── FocusRollManagerDesk/      Python PyQt6 external app
│   ├── main.py                FocusRollManagerDesk QWidget — entry point
│   ├── parser.py              FocusParser: TS log line → {ts_name, focus1, focus2, status}
│   ├── identity_manager.py    TS-alias → WoW name resolver (alias file + rapidfuzz)
│   ├── roster_importer.py     FRMROSTER1 / JSON / CSV roster formats
│   ├── exporter.py            FRM1 addon string + JSON + Lua + CSV (round-trip-safe escape)
│   ├── desktop_pipeline.py    parse_focus_players, import_roster_if_present
│   ├── strich_view.py         StrichlisteWindow: big external display, sorted by strikes asc
│   ├── live_sync.py           LiveSyncCoordinator: merges chatlog + savedvars
│   ├── chatlog_tail.py        QFileSystemWatcher tail of Logs/WoWChatLog.txt
│   ├── lua_savedvars.py       SavedVariables Lua subset parser
│   ├── config.py              AppConfig (chatlog_path, savedvars_path) persistence
│   ├── synonyms.json          item abbreviation table (165 entries, migrated from ItemDB.lua)
│   ├── aliases.json           TS→WoW name aliases (user-edited)
│   ├── fake_roster_import.txt sample roster (FRMROSTER1 format)
│   ├── fake_ts_raid_import.txt sample TS log
│   ├── requirements.txt       PyQt6, rapidfuzz, unidecode
│   └── tests/                 pytest suite (67 tests, all green)
│       ├── conftest.py
│       ├── test_parser.py
│       ├── test_exporter.py
│       ├── test_identity.py
│       ├── test_roster.py
│       ├── test_pipeline.py
│       ├── test_lua_savedvars.py
│       ├── test_chatlog_tail.py
│       └── test_live_sync.py
│
├── ICCFocusLoot/              reference-only sister addon (do not extend as main)
├── FocusRollManagerDesk.bat   Windows launcher
├── Start-Desktop-App.bat
└── README.md
```

## FRM1 wire format

Used by the addon-import string AND by the live `[FRM] PLAYER` chatlog event.

```
FRM1|<name>;<class>;<focus1>;<focus2>;<status>;<strikes>|<name>;...
```

Round-trip-safe escape (mirrored on both sides):

| Raw | Escaped |
|----|----|
| `\` | `\\` |
| `|` | `\p` |
| `;` | `\s` |

Order on encode: `\` first, then `|`, then `;`. Decode order: process `\p` and `\s` before `\\` collapse, OR scan single-pass char-by-char (see `ImportExport.lua:FRM:UnescapeField` and `chatlog_tail.py:unescape_field`).

## Live-sync chat-log event format

Each line printed via `DEFAULT_CHAT_FRAME:AddMessage("[FRM] " .. line)`. WoW writes the chat frame to `Logs/WoWChatLog.txt` when `LoggingChat(true)`.

```
[FRM] HELLO|<version>|<unixtime>
[FRM] AWARD|<player>|<item>|<strikes>
[FRM] PLAYER|<player>|<class>|<focus1>|<focus2>|<status>|<strikes>
[FRM] CLEAR
```

Fields use the same FRM1 escape scheme. Parser: `chatlog_tail.parse_line`.

## Key constraints

- **WoW 3.3.5a addon API** — no outbound HTTP/sockets. Out-of-process integration is one of: `SavedVariables.lua` file (flushed only on `/reload` or `/logout`), or `LoggingChat` chat-log tailing. No other options.
- **`/reload` is blocked in combat.** The UI Reload button checks `UnitAffectingCombat("player")` and refuses with a message; user policy is to only reload between bosses anyway.
- **`SavedVariables` only flushes at /reload or /logout.** Crashes lose all unsaved state — encourage frequent sync events.
- **No whisper-based focus registration on the main addon.** Focus comes exclusively from the external TS-log parse. (ICCFocusLoot has a whisper system but is not the main addon.)

## User preferences

- German UI strings throughout; logs / docs / commits in any language ok.
- No emojis in code or files unless explicitly requested.
- No confirmation popup on Award — single click awards. Confirmation IS shown on Live-Sync-Start (because it activates `/chatlog`) and on Reload.
- Interessenten-list sorting: fewest strikes first, then highest roll, then name.
- Strichliste-Window: fewest strikes at top = highest priority.
- Caveman mode often active in chat — but code/commits/PRs/docs always normal prose.

## Running tests

```
cd FocusRollManagerDesk
python -m pytest tests/ -q
```

Expected: 67 passed.

## Running desktop app

```
cd FocusRollManagerDesk
python main.py
```

Or use `Start-Desktop-App.bat`. Requires `pip install -r requirements.txt` (PyQt6 + rapidfuzz + unidecode).

## Done so far

- Exporter round-trip-safe escape (Lua + Python) — was destroying `|`/`;`.
- Parser off-detection scope-limited to prefix-before-focus-marker — item names like `ersatz-token` no longer flip status to off.
- pytest suite seeded with 67 tests covering parser/exporter/identity/roster/pipeline/lua_savedvars/chatlog_tail/live_sync.
- 165-entry `synonyms.json` migrated from ICCFocusLoot ItemDB.lua (was 16).
- Strichliste live window (`strich_view.py`) — big external display, class colors, color-graded strike counter, +/- inline.
- `Sync.lua` ingame — chatlog broadcast + `/chatlog` toggle + `/frm sync start|stop|push|status` + `/frm reload`.
- `Data.lua` hooks: BroadcastPlayer in UpsertPlayer, BroadcastAward in MarkWin, BroadcastClear in ClearFocus.
- UI.lua rewrite from text-blob to button layout: action row, sync toggle (with confirm), reload (with combat-check), active-roll section with `Verrollen` per loot item and `Award` per interested player, scrollable player list with inline strike +/- and off-toggle.
- `live_sync.py` coordinator merges chatlog (primary, ~200ms) + savedvars (backup, /reload-triggered).
- `config.py` auto-detects WoW root (Logs/, WTF/Account/*/SavedVariables/).

## TODO for next session

1. **Focus verschenken (transfer focus)** — allow a player to gift one of their focus slots to another. Whisper command on ICCFocusLoot side (`!focus give`) already exists as reference; mirror as a button workflow in FRM UI. Decide: gift entire focus slot, or a "this roll only" delegation?
2. **Test with real focus-roll data** — drop real TS chat logs from past raids into `FocusRollManagerDesk/` and run them through `parse_focus_players`. Note false-positives/false-negatives, add them as regression fixtures under `tests/`.
3. **Sorted FR-data export for TS readback** — generate a human-readable list (markdown / plain text / table) of parsed focuses to paste back into TS. Lets the raid eyeball-verify their entries before raid pull. Sort by class, by focus, by player — pick the most useful and add as a tab in the export window.
4. **Correct-misdetected-focus workflow** — when parser confidence < threshold, surface the line in a "review queue" with [Accept] [Edit] [Reject] buttons. Persist corrections so the same TS-line auto-resolves correctly next raid (extend `aliases.json` schema with line-pattern → item-name overrides).
5. **Abbreviation / anecdote auto-detection from real data** — mine real TS-log corpora for tokens that aren't in `synonyms.json` and propose new entries. Cluster similar mis-spellings via rapidfuzz, suggest canonical forms. Output: a candidates JSON for human review before merging into `synonyms.json`.

## Decisions made (don't re-litigate)

- Live sync uses `DEFAULT_CHAT_FRAME:AddMessage` + `LoggingChat`, not a custom channel. Reason: no `/join` clutter for other raiders, no server channel limits, works always.
- Award button is single-click (no confirm). Speed > safety; user can fix via `-` strike if mis-clicked.
- ICCFocusLoot stays in tree as reference. Don't delete; don't extend.
- Encoding: chat log decoded as UTF-8 first, fallback cp1252. Avoids Umlaut breakage on German clients.
