local FRM = FocusRollManager

function FRM:InitDB()
    FocusRollManagerDB = FocusRollManagerDB or {}
    FocusRollManagerDB.players = FocusRollManagerDB.players or {}
    FocusRollManagerDB.roster = FocusRollManagerDB.roster or {}
    FocusRollManagerDB.loot = FocusRollManagerDB.loot or { items = {}, lastBoss = "" }
    FocusRollManagerDB.rolls = FocusRollManagerDB.rolls or {}
    FocusRollManagerDB.settings = FocusRollManagerDB.settings or {}
end

function FRM:GetDB()
    self:InitDB()
    return FocusRollManagerDB
end

function FRM:UpsertPlayer(name, class, focus1, focus2, status, strikes)
    if not name or name == "" then return end
    local db = self:GetDB()
    db.players[name] = db.players[name] or { wins = {} }
    local p = db.players[name]
    p.class = class or p.class or "UNKNOWN"
    p.focus1 = focus1 or p.focus1 or ""
    p.focus2 = focus2 or p.focus2 or ""
    p.status = status or p.status or "active"
    p.strikes = tonumber(strikes) or tonumber(p.strikes) or 0
    p.wins = p.wins or {}
end

function FRM:ClearFocus()
    local db = self:GetDB()
    db.players = {}
    self:Print("Focusdaten gelöscht.")
    self:RefreshUI()
end

function FRM:ResetRaidData()
    local db = self:GetDB()
    db.loot = { items = {}, lastBoss = "" }
    db.rolls = {}
    self:Print("Raid-Livedaten zurückgesetzt.")
    self:RefreshUI()
end

function FRM:MarkWin(player, item)
    if not player or not item then
        self:Print("Nutzung: /frm win <player> <item>")
        return
    end
    local db = self:GetDB()
    local p = db.players[player]
    if not p then
        self:Print("Spieler nicht gefunden: " .. player)
        return
    end
    p.strikes = (tonumber(p.strikes) or 0) + 1
    p.wins = p.wins or {}
    table.insert(p.wins, {
        item = item,
        time = date("%Y-%m-%d %H:%M")
    })
    self:Print(player .. " gewinnt " .. item .. " (+1 Strich).")
    self:RefreshUI()
end
