local FRM = FocusRollManager

function FRM:ImportString(str)
    str = self:Trim(str or "")
    if str == "" then
        self:Print("Kein Importstring angegeben.")
        return
    end

    local parts = self:Split(str, "|")
    if parts[1] ~= "FRM1" then
        self:Print("Ungültiges Format. Erwartet FRM1.")
        return
    end

    local imported = 0
    for i = 2, #parts do
        local fields = self:SplitSemi(parts[i])
        local name = self:Trim(fields[1])
        if name and name ~= "" then
            local class = self:Trim(fields[2] or "UNKNOWN")
            local focus1 = self:NormalizeItem(fields[3] or "")
            local focus2 = self:NormalizeItem(fields[4] or "")
            local status = self:Trim(fields[5] or "active")
            local strikes = tonumber(fields[6]) or 0
            self:UpsertPlayer(name, class, focus1, focus2, status, strikes)
            imported = imported + 1
        end
    end

    self:Print(imported .. " Focus-Einträge importiert.")
    self:RefreshUI()
end

function FRM:BuildExportString()
    local db = self:GetDB()
    local out = {"FRM1"}
    for name, p in pairs(db.players) do
        table.insert(out,
            self:EscapeField(name) .. ";" ..
            self:EscapeField(p.class or "UNKNOWN") .. ";" ..
            self:EscapeField(p.focus1 or "") .. ";" ..
            self:EscapeField(p.focus2 or "") .. ";" ..
            self:EscapeField(p.status or "active") .. ";" ..
            self:EscapeField(p.strikes or 0)
        )
    end
    return table.concat(out, "|")
end

function FRM:PrintExportString()
    local exportString = self:BuildExportString()
    self:Print("Exportstring im Kopierfenster geoeffnet.")
    self:ShowCopyBox("FRM Focus Export", exportString)
end
