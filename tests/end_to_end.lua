SlashCmdList = {}
FocusRollManagerDB = nil
UIParent = {}
Minimap = {}
RAID_CLASS_COLORS = {
    DRUID = { r = 1.0, g = 0.49, b = 0.04 },
    PRIEST = { r = 1.0, g = 1.0, b = 1.0 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    MAGE = { r = 0.41, g = 0.8, b = 0.94 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    ROGUE = { r = 1.0, g = 0.96, b = 0.41 },
}

local messages = {}
DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, msg)
        table.insert(messages, msg)
    end
}

function date()
    return "2026-05-15 20:00"
end

local function noop() end

function CreateFrame()
    return {
        RegisterEvent = noop,
        SetScript = noop,
    }
end

dofile("Core.lua")
dofile("Data.lua")
dofile("Utils.lua")
dofile("Synonyms.lua")
dofile("ImportExport.lua")
dofile("Roster.lua")
dofile("Loot.lua")
dofile("Rolls.lua")
dofile("Debug.lua")
dofile("UI.lua")

local FRM = FocusRollManager

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

FRM:ImportString("FRM1|Blàckpanther;DRUID;Deathbringer's Will Heroic;Sharpened Twilight Scale Heroic;active;0|Hêålbôt;PRIEST;Phylactery of the Nameless Lich Heroic;;active;0|Tankyx;WARRIOR;;;off;0|Mágéone;MAGE;Charred Twilight Scale Heroic;Tiny Abomination in a Jar Heroic;active;0|Svenn;PALADIN;Tier Token;;active;0|Màtze;ROGUE;Deathbringer's Will;;active;0")

local db = FRM:GetDB()
assertEqual(db.players["Blàckpanther"].class, "DRUID", "imports accented WoW name")
assertEqual(db.players["Tankyx"].status, "off", "imports off status")
assertEqual(db.players["Mágéone"].focus2, "Tiny Abomination in a Jar Heroic", "imports second focus")

local dbwInterested = FRM:FindInterested("DBW HC")
assertEqual(#dbwInterested, 1, "matches heroic DBW only to heroic focus")
assertEqual(dbwInterested[1].name, "Blàckpanther", "matches DBW HC interested player")

local normalDbwInterested = FRM:FindInterested("DBW")
assertEqual(#normalDbwInterested, 1, "matches normal DBW only to normal focus")
assertEqual(normalDbwInterested[1].name, "Màtze", "matches normal DBW interested player")

FRM:DebugBoss("Deathbringer Saurfang")
assertEqual(db.loot.lastBoss, "Deathbringer Saurfang", "stores simulated boss")

FRM:DebugItem("DBW HC")
assertEqual(#db.loot.items, 1, "stores simulated item")
assertEqual(db.loot.items[1].name, "Deathbringer's Will Heroic", "normalizes simulated item")

FRM:MarkWin("Blàckpanther", "Deathbringer's Will Heroic")
assertEqual(db.players["Blàckpanther"].strikes, 1, "winner gets strike")
assertEqual(#db.players["Blàckpanther"].wins, 1, "winner history stored")

FRM:CHAT_MSG_SYSTEM("Hêålbôt rolls 87 (1-100)")
FRM:CHAT_MSG_SYSTEM("Mágéone würfelt. Ergebnis: 92 (1-100)")
assertEqual(#db.rolls, 2, "captures English and German roll messages")
assertEqual(db.rolls[1].player, "Mágéone", "sorts highest roll first")
assertEqual(db.rolls[1].roll, 92, "stores highest roll value")

local exportString = FRM:BuildExportString()
assertTrue(string.find(exportString, "^FRM1|"), "export starts with FRM1")
assertTrue(string.find(exportString, "Blàckpanther;DRUID;Deathbringer's Will Heroic;Sharpened Twilight Scale Heroic;active;1", 1, true), "export includes updated winner strike")
assertTrue(string.find(exportString, "Tankyx;WARRIOR;;;off;0", 1, true), "export preserves empty focus fields")

print("end-to-end ok")
