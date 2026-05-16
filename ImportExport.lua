local FRM = FocusRollManager

-- Reverse of Exporter.safe in the desktop app:
--   \p -> |   \s -> ;   \\ -> \
function FRM:UnescapeField(s)
    if not s then return "" end
    local out, i, len = {}, 1, #s
    while i <= len do
        local c = s:sub(i, i)
        if c == "\\" and i < len then
            local nx = s:sub(i + 1, i + 1)
            if     nx == "p"  then out[#out + 1] = "|";  i = i + 2
            elseif nx == "s"  then out[#out + 1] = ";";  i = i + 2
            elseif nx == "\\" then out[#out + 1] = "\\"; i = i + 2
            else                   out[#out + 1] = c;    i = i + 1
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return table.concat(out)
end

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
        local name = self:Trim(self:UnescapeField(fields[1]))
        if name and name ~= "" then
            local class = self:Trim(self:UnescapeField(fields[2] or "UNKNOWN"))
            local focus1 = self:NormalizeItem(self:UnescapeField(fields[3] or ""))
            local focus2 = self:NormalizeItem(self:UnescapeField(fields[4] or ""))
            local status = self:Trim(self:UnescapeField(fields[5] or "active"))
            local strikes = tonumber(self:UnescapeField(fields[6])) or 0
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
