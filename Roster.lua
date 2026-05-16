local FRM = FocusRollManager

local wowGetNumRaidMembers = GetNumRaidMembers
local wowGetNumPartyMembers = GetNumPartyMembers
local wowUnitName = UnitName
local wowUnitClass = UnitClass

function FRM:GetNumRaidMembers()
    local db = self:GetDB()
    if db.settings and db.settings.debugLiveRaid then
        return #(self.debugRaidRoster or {})
    end
    return wowGetNumRaidMembers and wowGetNumRaidMembers() or 0
end

function FRM:GetNumPartyMembers()
    return wowGetNumPartyMembers and wowGetNumPartyMembers() or 0
end

function FRM:GetUnitName(unit)
    local db = self:GetDB()
    if db.settings and db.settings.debugLiveRaid then
        local index = tonumber(string.match(unit or "", "^raid(%d+)$"))
        if index and self.debugRaidRoster and self.debugRaidRoster[index] then
            return self.debugRaidRoster[index].name
        end
    end
    return wowUnitName and wowUnitName(unit) or nil
end

function FRM:GetUnitClass(unit)
    local db = self:GetDB()
    if db.settings and db.settings.debugLiveRaid then
        local index = tonumber(string.match(unit or "", "^raid(%d+)$"))
        if index and self.debugRaidRoster and self.debugRaidRoster[index] then
            local class = self.debugRaidRoster[index].class
            return class, class
        end
    end
    if wowUnitClass then
        return wowUnitClass(unit)
    end
    return nil, "UNKNOWN"
end

local function getClassForUnit(manager, unit)
    local _, class = manager:GetUnitClass(unit)
    return class or "UNKNOWN"
end

function FRM:RefreshRoster()
    local db = self:GetDB()
    db.roster = {}

    if self:GetNumRaidMembers() > 0 then
        for i = 1, self:GetNumRaidMembers() do
            local name = self:GetUnitName("raid" .. i)
            if name then
                db.roster[name] = {
                    class = getClassForUnit(self, "raid" .. i)
                }
            end
        end
    elseif self:GetNumPartyMembers() > 0 then
        local player = self:GetUnitName("player")
        if player then
            db.roster[player] = { class = getClassForUnit(self, "player") }
        end
        for i = 1, self:GetNumPartyMembers() do
            local name = self:GetUnitName("party" .. i)
            if name then
                db.roster[name] = {
                    class = getClassForUnit(self, "party" .. i)
                }
            end
        end
    else
        local player = self:GetUnitName("player")
        if player then
            db.roster[player] = { class = getClassForUnit(self, "player") }
        end
    end
end

function FRM:BuildRosterExport()
    self:RefreshRoster()
    local db = self:GetDB()
    local out = {"FRMROSTER1"}
    for name, p in pairs(db.roster) do
        table.insert(out, self:EscapeField(name) .. ";" .. self:EscapeField(p.class or "UNKNOWN"))
    end
    return table.concat(out, "|")
end

function FRM:PrintRosterExport()
    local rosterString = self:BuildRosterExport()
    self:Print("Rosterstring im Kopierfenster geoeffnet.")
    self:ShowCopyBox("FRM Roster Export", rosterString)
end

function FRM:RAID_ROSTER_UPDATE()
    local db = self:GetDB()
    if db.settings and db.settings.debugLiveRaid then
        db.settings.debugLastRosterEvent = "RAID_ROSTER_UPDATE"
    end
    self:RefreshRoster()
    self:RefreshUI()
end

function FRM:PARTY_MEMBERS_CHANGED()
    self:RefreshRoster()
    self:RefreshUI()
end

function FRM:GetMissingFocus()
    self:RefreshRoster()
    local db = self:GetDB()
    local missing = {}
    for name, r in pairs(db.roster) do
        local p = db.players[name]
        if not p or ((p.focus1 or "") == "" and (p.focus2 or "") == "") then
            table.insert(missing, name)
        end
    end
    table.sort(missing)
    return missing
end

function FRM:PrintMissingFocus()
    local missing = self:GetMissingFocus()
    if #missing == 0 then
        self:Print("Alle aktuellen Raider haben Focus-Einträge.")
        return
    end
    self:Print("Fehlende Focus-Einträge:")
    for _, name in ipairs(missing) do
        self:Print("- " .. name)
    end
end
