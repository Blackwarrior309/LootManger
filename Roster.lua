local FRM = FocusRollManager

local function getClassForUnit(unit)
    local _, class = UnitClass(unit)
    return class or "UNKNOWN"
end

function FRM:RefreshRoster()
    local db = self:GetDB()
    db.roster = {}

    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name = UnitName("raid" .. i)
            if name then
                db.roster[name] = {
                    class = getClassForUnit("raid" .. i)
                }
            end
        end
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
        local player = UnitName("player")
        if player then
            db.roster[player] = { class = getClassForUnit("player") }
        end
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party" .. i)
            if name then
                db.roster[name] = {
                    class = getClassForUnit("party" .. i)
                }
            end
        end
    else
        local player = UnitName("player")
        if player then
            db.roster[player] = { class = getClassForUnit("player") }
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
